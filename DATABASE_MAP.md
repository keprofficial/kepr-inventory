# KEPR Inventory Database Map

Last updated: 24 July 2026  
Supabase project: `yyjauhgdqywysyzerdll`

This document maps the PostgreSQL schema, Supabase Auth identities, Storage
bucket, reporting views, RPC functions, request lifecycle and role access used
by KEPR Inventory.

## System overview

```mermaid
flowchart LR
    Society[Apartment user] -->|raises demand| Requests[(inventory_requests)]
    Requests -->|availability check| Inventory[Inventory and Warehouse]
    Inventory -->|forwards ticket| Finance[Finance]
    Finance -->|approves or rejects| Requests
    Requests -->|finance_approved| Inventory
    Inventory -->|issues stock| IssueRPC[inventory_issue_approved_stock]
    IssueRPC --> Warehouse[(warehouse stock)]
    IssueRPC --> ApartmentStock[(apartment stock)]
    IssueRPC --> MovementLog[(stock movements)]
    Society -->|records consumption| UsageRPC[inventory_record_usage]
    UsageRPC --> ApartmentStock
    UsageRPC --> Usage[(inventory_usage)]
    MovementLog --> Weekly[weekly insights]
    Usage --> Monthly[monthly usage]
    Usage --> Weekly
```

## Entity relationship diagram

```mermaid
erDiagram
    AUTH_USERS {
        uuid id PK
        text email
        timestamptz created_at
    }

    INVENTORY_USERS {
        uuid user_id PK,FK
        text role
        bigint apartment_id FK
        text display_name
        timestamptz created_at
    }

    INVENTORY_PRODUCTS {
        bigint id PK
        text name UK
        text unit
        numeric unit_price
        numeric reorder_level
        text notes
        timestamptz created_at
        timestamptz updated_at
    }

    INVENTORY_APARTMENTS {
        bigint id PK
        text name UK
        text contact
        timestamptz created_at
    }

    INVENTORY_STOCK_LEVELS {
        bigint id PK
        text location_type
        bigint apartment_id FK
        bigint product_id FK
        numeric quantity
        numeric monthly_use
        date audited_at
        timestamptz updated_at
    }

    INVENTORY_STOCK_MOVEMENTS {
        bigint id PK
        text reference
        text movement_type
        bigint product_id FK
        bigint apartment_id FK
        numeric quantity
        numeric unit_price
        date movement_date
        text note
        timestamptz created_at
    }

    INVENTORY_REQUESTS {
        bigint id PK
        text reference UK
        bigint apartment_id FK
        uuid requested_by FK
        text status
        text note
        text inventory_note
        text finance_note
        text invoice_reference
        uuid inventory_checked_by FK
        uuid finance_reviewed_by FK
        uuid fulfilled_by FK
        timestamptz requested_at
        timestamptz inventory_checked_at
        timestamptz finance_reviewed_at
        timestamptz fulfilled_at
    }

    INVENTORY_REQUEST_LINES {
        bigint id PK
        bigint request_id FK
        bigint product_id FK
        numeric quantity
    }

    INVENTORY_USAGE {
        bigint id PK
        bigint apartment_id FK
        bigint product_id FK
        numeric quantity
        date usage_date
        text note
        uuid recorded_by FK
        timestamptz created_at
    }

    INVENTORY_INVOICES {
        bigint id PK
        bigint request_id UK,FK
        text invoice_number
        date invoice_date
        text storage_path UK
        text original_filename
        text mime_type
        bigint size_bytes
        uuid uploaded_by FK
        timestamptz created_at
    }

    STORAGE_OBJECTS {
        uuid id PK
        text bucket_id
        text name
        uuid owner_id
        timestamptz created_at
    }

    AUTH_USERS ||--|| INVENTORY_USERS : "has role"
    INVENTORY_APARTMENTS ||--o{ INVENTORY_USERS : "maps apartment users"
    INVENTORY_APARTMENTS ||--o{ INVENTORY_STOCK_LEVELS : "holds stock"
    INVENTORY_PRODUCTS ||--o{ INVENTORY_STOCK_LEVELS : "stocked as"
    INVENTORY_PRODUCTS ||--o{ INVENTORY_STOCK_MOVEMENTS : "moved"
    INVENTORY_APARTMENTS ||--o{ INVENTORY_STOCK_MOVEMENTS : "receives"
    INVENTORY_APARTMENTS ||--o{ INVENTORY_REQUESTS : "raises"
    AUTH_USERS ||--o{ INVENTORY_REQUESTS : "requests or reviews"
    INVENTORY_REQUESTS ||--|{ INVENTORY_REQUEST_LINES : "contains"
    INVENTORY_PRODUCTS ||--o{ INVENTORY_REQUEST_LINES : "requested"
    INVENTORY_APARTMENTS ||--o{ INVENTORY_USAGE : "consumes"
    INVENTORY_PRODUCTS ||--o{ INVENTORY_USAGE : "used"
    AUTH_USERS ||--o{ INVENTORY_USAGE : "records"
    INVENTORY_REQUESTS ||--o| INVENTORY_INVOICES : "optionally maps"
    AUTH_USERS ||--o{ INVENTORY_INVOICES : "uploads"
    INVENTORY_INVOICES ||--|| STORAGE_OBJECTS : "storage_path maps name"
```

## Stock model

`inventory_stock_levels` stores both warehouse and apartment balances.

| `location_type` | `apartment_id` | Meaning |
|---|---:|---|
| `warehouse` | `NULL` | Main warehouse balance |
| `apartment` | Apartment ID | Balance currently issued to that apartment |

The unique constraint uses:

```text
(location_type, apartment_id, product_id) NULLS NOT DISTINCT
```

This guarantees one warehouse row per product and one row per
apartment/product pair.

Quantities move through locked PostgreSQL functions. The application must not
calculate or update both sides of a transfer independently.

## Demand lifecycle

```mermaid
stateDiagram-v2
    [*] --> pending_inventory: Apartment raises demand
    pending_inventory --> pending_finance: Inventory confirms availability
    pending_inventory --> rejected: Inventory rejects
    pending_finance --> finance_approved: Finance approves
    pending_finance --> rejected: Finance rejects
    finance_approved --> fulfilled: Warehouse issues stock
    fulfilled --> [*]
    rejected --> [*]
```

### Transaction boundary

Stock does **not** move when:

- an apartment creates a request;
- Inventory forwards it to Finance;
- Finance approves it.

Stock moves only when Inventory calls:

```text
inventory_issue_approved_stock(request_id)
```

That function locks the ticket and warehouse rows, validates every line,
deducts warehouse quantities, upserts apartment quantities, writes immutable
movement rows and marks the request `fulfilled` in one transaction.

## Role mapping

`inventory_users.role` supports:

| Role | Apartment mapping | Primary responsibility |
|---|---|---|
| `inventory_admin` | Must be `NULL` | Catalogue, warehouse, availability, fulfillment |
| `finance_admin` | Must be `NULL` | Ticket approval or rejection |
| `apartment` | Required | Own stock, demand and usage |

Authentication identity comes from `auth.users`. Application authorization
comes from `inventory_users`.

## RPC/function map

```mermaid
flowchart TB
    SaveProduct[inventory_save_product] --> Products[(inventory_products)]
    SaveProduct --> Stock[(inventory_stock_levels)]

    Receive[inventory_receive_stock] --> Stock
    Receive --> Movements[(inventory_stock_movements)]

    CreateRequest[inventory_create_request] --> Requests[(inventory_requests)]
    CreateRequest --> Lines[(inventory_request_lines)]

    Check[inventory_check_request] --> Requests
    Check --> Stock

    FinanceReview[inventory_finance_review] --> Requests

    Issue[inventory_issue_approved_stock] --> Requests
    Issue --> Stock
    Issue --> Movements

    RecordUsage[inventory_record_usage] --> Stock
    RecordUsage --> Usage[(inventory_usage)]

    IsAdmin[inventory_is_admin] --> Users[(inventory_users)]
    IsFinance[inventory_is_finance] --> Users
```

| Function | Intended caller | Writes |
|---|---|---|
| `inventory_save_product` | Inventory | Product and warehouse stock |
| `inventory_receive_stock` | Inventory | Warehouse stock and receipt movement |
| `inventory_create_request` | Apartment | Request and request lines |
| `inventory_check_request` | Inventory | Request status/check metadata |
| `inventory_finance_review` | Finance | Request finance status/metadata |
| `inventory_issue_approved_stock` | Inventory | Both stock balances, movement log, request |
| `inventory_record_usage` | Apartment | Apartment balance and usage |
| `inventory_is_admin` | RLS/functions | Boolean role check |
| `inventory_is_finance` | RLS/functions | Boolean role check |

### Legacy functions still present

The migrations also define older functions retained for compatibility:

- `inventory_transfer_stock`
- `inventory_review_request`
- overloaded `inventory_fulfill_request`

The Flutter application does not use these in the current staged workflow.
Before a strict production security review, revoke or drop unused legacy RPCs
so the approved workflow is the only callable stock path.

## Reporting view map

```mermaid
flowchart LR
    Products[(products)] --> ProductsView[inventory_products_view]
    Stock[(stock_levels)] --> ProductsView

    Apartments[(apartments)] --> ApartmentsView[inventory_apartments_view]
    Stock --> ApartmentsView
    Products --> ApartmentsView

    Apartments --> ApartmentStockView[inventory_apartment_stock_view]
    Stock --> ApartmentStockView
    Products --> ApartmentStockView

    Movements[(stock_movements)] --> TransferView[inventory_transfers_view]
    Movements --> MovementView[inventory_movement_log_view]

    Requests[(requests)] --> RequestView[inventory_request_summary_view]
    Lines[(request_lines)] --> RequestView
    Products --> RequestView
    Apartments --> RequestView

    Usage[(usage)] --> MonthlyView[inventory_monthly_usage_view]
    Usage --> WeeklyView[inventory_weekly_insights_view]
    Movements --> WeeklyView
    Requests --> WeeklyView

    Invoices[(invoices)] --> InvoiceView[inventory_invoice_register_view]
    Requests --> InvoiceView
    Apartments --> InvoiceView
```

| View | Purpose |
|---|---|
| `inventory_products_view` | Products with live warehouse quantity |
| `inventory_apartments_view` | Apartment item count and stock value |
| `inventory_apartment_stock_view` | Product-level apartment balances |
| `inventory_transfers_view` | Grouped transfer history |
| `inventory_movement_log_view` | Unified receipt/transfer audit log |
| `inventory_request_summary_view` | Ticket totals and approval state |
| `inventory_monthly_usage_view` | Monthly consumption by apartment/product |
| `inventory_weekly_insights_view` | Seven-day warehouse/apartment metrics |
| `inventory_invoice_register_view` | Searchable invoice metadata |

## Supabase Storage map

```mermaid
flowchart LR
    Bucket[Private bucket: inventory-invoices]
    Object[storage.objects row]
    Metadata[inventory_invoices row]
    Ticket[inventory_requests row]
    Apartment[inventory_apartments row]

    Bucket --> Object
    Object -->|name equals storage_path| Metadata
    Metadata -->|request_id| Ticket
    Ticket -->|apartment_id| Apartment
```

Bucket configuration:

| Property | Value |
|---|---|
| Bucket ID | `inventory-invoices` |
| Public | `false` |
| Maximum size | 10 MB |
| MIME types | PDF, JPEG, PNG, WebP |

Invoice files are optional in the current UI fulfillment path. The invoice
schema and register remain available for future bill attachment workflows.

## RLS/access summary

| Resource | Inventory | Finance | Apartment |
|---|---:|---:|---:|
| Own `inventory_users` profile | Read | Read | Read |
| Products/catalogue views | Read/write through app policies/RPC | Read | Read |
| Warehouse stock | Read/write through approved operations | Read | Read availability |
| Own apartment stock | Read | Read | Read mapped apartment |
| Requests | All workflow tickets | Finance-stage tickets | Own apartment |
| Request lines | Through visible request | Through visible request | Own request |
| Usage | All apartments | Reporting only if granted | Own apartment |
| Invoice metadata/files | Read/upload/delete | Read | Own request files |

The temporary anonymous policies from migration `17000` are removed by
migration `19000`. Current application access requires authenticated users.

## Indexes and integrity

Important constraints and indexes:

- Case-insensitive unique product name.
- Case-insensitive unique apartment name.
- Unique stock row by location/apartment/product.
- Non-negative stock, price, reorder and usage quantities.
- Positive movement, request-line and consumption quantities.
- Unique request reference.
- Unique product per request.
- One optional invoice per request.
- Unique invoice storage path.
- Movement reference and date indexes.
- Apartment/date usage index.
- Invoice date index.
- Foreign keys restrict deletion of referenced products and movements.

## Migration order

```text
20260723150000_inventory_schema.sql
20260723160000_fix_stock_levels_conflict.sql
20260723170000_temporary_anon_inventory_access.sql
20260723180000_stock_receipts_and_movement_log.sql
20260723190000_roles_requests_approvals_usage.sql
20260723200000_finance_approval_and_weekly_insights.sql
20260723210000_private_invoice_storage.sql
20260723220000_repair_invoice_bucket.sql
20260723230000_issue_stock_without_invoice.sql
```

After migrations, create Auth users and run:

```text
supabase/setup_demo_roles.sql
```

## Operational verification queries

### Users and roles

```sql
select au.email,iu.role,iu.display_name,a.name apartment
from public.inventory_users iu
join auth.users au on au.id=iu.user_id
left join public.inventory_apartments a on a.id=iu.apartment_id
order by au.email;
```

### Stock by location

```sql
select s.location_type,a.name apartment,p.name product,
  s.quantity,p.unit,s.updated_at
from public.inventory_stock_levels s
join public.inventory_products p on p.id=s.product_id
left join public.inventory_apartments a on a.id=s.apartment_id
order by s.location_type,a.name,p.name;
```

### Demand pipeline

```sql
select reference,apartment,status,line_count,total_quantity,total_value,
  requested_at,inventory_checked_at,finance_reviewed_at,fulfilled_at
from public.inventory_request_summary_view
order by id desc;
```

### Recent stock audit

```sql
select *
from public.inventory_movement_log_view
order by sort_id desc
limit 100;
```

### Invoice bucket

```sql
select id,name,public,file_size_limit,allowed_mime_types
from storage.buckets
where id='inventory-invoices';
```

