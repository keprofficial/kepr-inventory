# KEPR Inventory — Codex Handoff

Last updated: 24 July 2026

## Objective

Build a professional Flutter inventory application for KEPR using Supabase.
The sibling project at `C:\Users\purus\OneDrive\Documents\A\kepr` is a
read-only design/architecture reference. Do not modify that inspection app.

The primary application is `flutter_app/`. The older Node/Next web application
is only a prototype/reference.

## Repository and local app

- Workspace: `C:\Users\purus\OneDrive\Documents\A\kepr_inventory_mnagment`
- GitHub: `https://github.com/keprofficial/kepr-inventory`
- Branch: `main`
- Latest known commit when this file was created: `286f3fe`
- Local Flutter web URL: `http://127.0.0.1:8085`
- Flutter SDK:
  `C:\Users\purus\OneDrive\Documents\A\flutter\bin\flutter.bat`

Do not deploy until the user confirms the local build. The intended future
deployment target is Vercel, not the old ChatGPT Sites deployment.

## Supabase

- Project reference: `yyjauhgdqywysyzerdll`
- URL: `https://yyjauhgdqywysyzerdll.supabase.co`
- Client configuration: `flutter_app/.env`
- Safe template: `flutter_app/.env.example`

The `.env` file is ignored by Git. Use only the publishable key in Flutter.
Never place a Supabase secret/service-role key in source, Flutter, Git, logs, or
documentation. A secret key was pasted in an earlier conversation and should
be rotated in Supabase.

Apply database changes with:

```powershell
cd C:\Users\purus\OneDrive\Documents\A\kepr_inventory_mnagment
supabase login
supabase link --project-ref yyjauhgdqywysyzerdll
supabase db push
```

Run `supabase/setup_demo_roles.sql` in Supabase SQL Editor after creating the
temporary Auth users.

## Temporary logins

The app first asks the user to select a workspace.

| Workspace | Username | Password | Supabase email |
|---|---|---|---|
| Inventory & Warehouse | `admin` | `admin123` | `admin@kepr.local` |
| Finance | `finance` | `finance123` | `finance@kepr.local` |
| Apartment | `society` | `society123` | `society@kepr.local` |

Apartment usernames map to `{username}@kepr.local`. Every apartment Auth user
must also have an `inventory_users` row mapped to the correct
`inventory_apartments.id`.

These credentials are temporary development credentials and must be replaced
before production.

## Required business workflow

Stock demand follows this exact chain:

1. Apartment/society raises a demand ticket.
2. Inventory manager checks current warehouse availability.
3. If stock is available, Inventory forwards the ticket to Finance.
4. Finance can only approve or reject the ticket. Finance cannot edit stock.
5. After Finance approval, Inventory/Warehouse enters an invoice or bill
   reference and fulfills the ticket.
6. Only fulfillment moves stock atomically from the warehouse to the apartment.
7. Apartment records actual stock consumption.
8. Immutable movement logs and weekly/monthly insights update.

Do not move stock when a demand is created, inventory-checked, or
finance-approved.

Request statuses:

```text
pending_inventory
pending_finance
finance_approved
fulfilled
rejected
```

## Role experiences

### Inventory & Warehouse

- Total warehouse value and product count
- Apartment availability
- Low-stock alerts
- Receive stock with supplier/invoice note
- Check apartment demand against warehouse availability
- Forward valid tickets to Finance
- Fulfill finance-approved tickets with mandatory invoice/bill reference
- Unified immutable stock movement log
- Seven-day stock received and issued insights

### Finance

- Ticket-only dashboard
- See inventory-checked demand tickets
- Review quantity and total value
- Approve or reject
- No direct product, quantity, apartment, or movement editing

### Apartment

- View only its mapped apartment stock
- Raise demand tickets
- Track request status
- Record actual consumption
- View monthly usage
- Seven-day consumed-stock and demand-raised insights

## Important source files

- `flutter_app/lib/main.dart` — role selection, authentication and UI
- `flutter_app/lib/database.dart` — Supabase repository and RPC calls
- `flutter_app/lib/models.dart` — application models
- `flutter_app/lib/supabase_config.dart` — dart-define configuration
- `flutter_app/assets/brand/kepr_icon.png` — header/login icon
- `flutter_app/assets/brand/kepr_lockup.png` — full KEPR lockup
- `supabase/migrations/` — ordered database schema and workflow migrations
- `supabase/setup_demo_roles.sql` — maps temporary Auth users to roles

The correct UI usage is the square `kepr_icon.png` beside readable KEPR text.
Do not crop the full lockup into a small square.

## Current migrations

Run migrations in filename order:

1. `20260723150000_inventory_schema.sql`
2. `20260723160000_fix_stock_levels_conflict.sql`
3. `20260723170000_temporary_anon_inventory_access.sql`
4. `20260723180000_stock_receipts_and_movement_log.sql`
5. `20260723190000_roles_requests_approvals_usage.sql`
6. `20260723200000_finance_approval_and_weekly_insights.sql`
7. `20260723210000_private_invoice_storage.sql`
8. `20260723220000_repair_invoice_bucket.sql`
9. `20260723230000_issue_stock_without_invoice.sql`

Migration 19000 removes the temporary anonymous policies and restores
authenticated role-based access.

## Invoice storage

- Private bucket: `inventory-invoices`
- Maximum size: 10 MB
- Accepted formats: PDF, JPG, PNG and WebP
- Warehouse fulfillment requires invoice number, invoice date and a file.
- `inventory_invoices` maps each file one-to-one to a fulfilled request.
- Admin and Finance can filter the invoice register by month or exact date.
- Files open through short-lived signed URLs; the bucket is not public.
- If fulfillment fails after upload, the Flutter repository removes the
  uploaded object to avoid orphaned files.

## Build and validation

From `flutter_app/`:

```powershell
& 'C:\Users\purus\OneDrive\Documents\A\flutter\bin\flutter.bat' pub get
& 'C:\Users\purus\OneDrive\Documents\A\flutter\bin\flutter.bat' analyze
& 'C:\Users\purus\OneDrive\Documents\A\flutter\bin\flutter.bat' test
& 'C:\Users\purus\OneDrive\Documents\A\flutter\bin\flutter.bat' build web --release --dart-define-from-file=.env
```

Latest validation before this handoff:

- `flutter analyze`: no issues
- Flutter tests: passed
- Flutter release web build: succeeded
- Local HTTP check: 200
- KEPR icon asset HTTP check: 200

If the browser shows an old Flutter build, use `Ctrl+Shift+R` because the
Flutter service worker may cache assets.

## Design direction

- Use the coral KEPR brand with neutral slate backgrounds.
- Keep screens role-focused and remove duplicate/unrelated actions.
- Use clear operational labels: `Raise demand`, `Send to Finance`,
  `Approve`, `Issue stock`, `Record usage`.
- Keep stock logs immutable.
- Prefer compact cards, clear status pills, strong hierarchy, responsive
  layouts, and minimal explanatory text.
- The supplied `inventory_management (1) (1).html` remains a useful reference
  for complete inventory flow and visual density.

## Next likely tasks

1. Apply all Supabase migrations to the new project.
2. Create the three temporary Auth users.
3. Run `supabase/setup_demo_roles.sql`.
4. Test the complete three-role workflow with real rows.
5. Improve responsive layouts if any ticket rows overflow on small screens.
6. Add invoice file upload if the user wants an actual bill attachment rather
   than only an invoice reference. (Implemented in migration 21000.)
7. After local approval, configure and deploy the Flutter web build to Vercel.
