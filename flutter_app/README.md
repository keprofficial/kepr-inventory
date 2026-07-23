# KEPR Inventory — Flutter

Native Flutter application for Android and iOS with an on-device relational
SQLite database.

## Features

- Warehouse catalogue, quantities, prices, and reorder levels
- Apartment/customer locations
- Apartment consumption rates and days-of-stock coverage
- Atomic multi-product warehouse transfers
- Transfer audit references and history
- 15/30-day stock requirement forecasts
- Offline-first SQLite storage

## Generate platform runners

Flutter was not installed in the source environment, so generate the standard
platform runner files once:

```powershell
cd flutter_app
flutter create --platforms=android,ios .
flutter pub get
flutter analyze
flutter test
flutter run
```

`flutter create .` preserves the existing `lib/` source and `pubspec.yaml`.

## Android release

Configure your signing key in the generated Android project, then run:

```powershell
flutter build appbundle --release
```

Upload `build/app/outputs/bundle/release/app-release.aab` to Google Play Console.

## Database

The app creates `kepr_inventory.db` in its private application data directory.
Stock transfers run inside a SQLite transaction: all lines succeed together, or
the entire transfer rolls back. Foreign keys, non-negative constraints, unique
names, and immutable movement history protect inventory integrity.
