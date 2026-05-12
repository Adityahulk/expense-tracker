# Expense Tracker

Offline mobile expense tracker for material expenses (diesel, labour, machine, etc.). Built with Flutter + SQLite, packaged as an Android APK for sideloading.

## Features

- **No login.** All data is stored locally in SQLite on the device.
- **Add expense** — material, quality, quantity + unit, cost, date, note, person/org.
- **Settings** — define materials in advance; each material has its own list of qualities and units (e.g. Diesel -> qualities `Premium`/`Regular`, unit `Litre`).
- **Duplicate detection** — if you record an expense whose material, quality, quantity, unit, cost, date, and note all match an existing entry (regardless of who recorded it), the app asks "Duplicate Entry. Save anyway?".
- **Edit / Delete** — tap a row to edit, long-press to delete (with confirm).
- **Search & filter** — by material, quality, date range, cost range.
- **Excel export** — search results can be exported as `.xlsx` to `Downloads/expense-tracker/`.
- **Danger Zone** — wipe everything. Before deletion, a full backup (Excel + raw SQLite copy) is automatically written to `Downloads/expense-tracker/backup_<timestamp>/`.

## Installation (Android, sideloaded)

1. Transfer the APK that matches the device's CPU to the phone:
   - Most modern phones (Android 8+ with 64-bit ARM): `app-arm64-v8a-release.apk` (8.3 MB)
   - Older 32-bit phones: `app-armeabi-v7a-release.apk` (7.8 MB)
2. On the phone: open Files, tap the APK, allow "Install unknown apps" for the file manager once, then install.

The signed-with-debug-key APK works on every Android device 5.0+ (API 21+). For production distribution generate a release keystore — see `android/app/build.gradle`.

## Project layout

```
lib/
  main.dart
  db/                  - SQLite schema + open/upgrade
  models/              - typed Dart classes for rows
  repositories/        - DB queries (incl. findDuplicates, search)
  providers/           - Riverpod providers wrapping the repos
  screens/             - Home, Search, Settings, Add/Edit, Material detail
  services/            - Excel export, backup, file paths
  widgets/             - ExpenseTile, snackbar helpers
test/
  duplicate_detection_test.dart  - 16 tests for repo logic
```

## Local development

Toolchain (one-time setup, already done on this machine):

- Flutter 3.16.9 at `~/development/flutter`
- JDK 17 (Temurin) at `~/development/jdk-17.0.19+10`
- Android SDK at `~/Library/Android/sdk`

Source the env helper in every shell:

```sh
source .devenv.sh
```

Then:

```sh
flutter pub get
flutter analyze        # 0 issues
flutter test           # 16/16 tests pass
flutter run            # debug build on connected device
flutter build apk --release --split-per-abi   # release APKs
```

## Notes

- The schema lives in `lib/db/schema.dart` with a version constant. Adding columns later? Bump `kSchemaVersion` and add the `ALTER TABLE` to `migrationSteps[<new version>]` — existing data is preserved on upgrade.
- All DB writes go through repositories that wrap `sqflite`. Foreign keys are enabled on every connection.
- Duplicate detection compares material/quality/quantity/unit/cost/date/note (notes case-insensitive, whitespace-stripped) — the person/org field is excluded by design.
- The release build uses the debug signing key for convenience. For Play Store distribution you must generate a real keystore.
