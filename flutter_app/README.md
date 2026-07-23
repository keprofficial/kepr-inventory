# KEPR Inventory — Flutter + Supabase

The primary KEPR inventory application is Flutter and uses Supabase as its
single source of truth. Its structure follows the sibling `A\kepr` inspection
application: Supabase is initialized at startup, authenticated staff sign in,
and screens access data through a repository.

## 1. Create the Supabase tables

The easiest option is Supabase Dashboard → SQL Editor → New query. Paste and
run the contents of:

```text
../supabase/migrations/20260723150000_inventory_schema.sql
```

Alternatively, with the Supabase CLI:

```powershell
cd C:\Users\purus\OneDrive\Documents\A\kepr_inventory_mnagment
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

The schema creates products, apartments, stock levels, movement history,
read-only reporting views, row-level security, and atomic product-save and
stock-transfer functions.

Create each staff login under Supabase Dashboard → Authentication → Users.

## 2. Generate the Flutter platform folders

Flutter was not available in the build environment. On a computer with Flutter:

```powershell
cd C:\Users\purus\OneDrive\Documents\A\kepr_inventory_mnagment\flutter_app
flutter create --platforms=android,ios,web .
flutter pub get
flutter analyze
flutter test
```

## 3. Run

Copy the Project URL and Publishable key from Supabase Dashboard → Project
Settings → API:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Do not place the service-role key in the Flutter application.

## Android release

```powershell
flutter build appbundle --release `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

The release bundle is written to
`build/app/outputs/bundle/release/app-release.aab`.
