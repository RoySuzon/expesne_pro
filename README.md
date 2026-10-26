# Expense Pro

An offline personal expense tracker built with Flutter, Riverpod, and local SQLite storage.

## Features

- Add, edit, and delete expenses with a title, exact amount, category, date, payment method, and optional note.
- View spending by day, Monday-based calendar week, month, or year; navigate earlier/later periods or return to today.
- Search titles and notes, combine search with category filters, and browse entries grouped by date.
- See period totals, spending trends, category breakdowns, average expense, and largest expense.
- Set an optional monthly budget with remaining/over-budget progress.
- Choose BDT (default), USD, EUR, GBP, or INR as the display currency. Changing this setting relabels all entries; it does not convert existing amounts.
- Start with an empty database. No sample transactions, account, backend, or API keys are required.

The app has Android and iOS platform projects. Android builds and headless tests were verified in the cloud environment; iOS compilation requires macOS and Xcode.

## Run

Use Flutter 3.47.8 / Dart 3.13.7 and the committed `pubspec.lock`.

```bash
flutter pub get
flutter run -d <device-id>
```

In the prepared cloud environment, first activate the installed tools in each new Bash shell:

```bash
source /workspace/toolchains/activate.sh
cd /workspace/expesne_pro
flutter devices
```

An Android device or emulator is required to launch the mobile app. The cloud environment currently has neither. Chrome and Linux desktop are not app targets.

## Validate and build

```bash
flutter analyze
flutter test --concurrency=2
flutter build apk --debug --target-platform android-arm64
```

The ARM64 debug APK is written to `build/app/outputs/flutter-apk/app-debug.apk`. Use `flutter build apk --debug` to build a debug APK for all supported Android architectures. Debug builds are for testing; configure release signing before store distribution.

On macOS, install the iOS development prerequisites, run `flutter build ios --no-codesign`, and configure signing in Xcode for a physical device.

Tests cover domain validation, exact money parsing/formatting, calendar boundaries and leap years, real SQLite persistence after reopening, CRUD and literal search, settings persistence, provider refresh/recovery, UI add/edit/delete/filter/settings flows, and a 320px layout with enlarged text.

## Architecture

```text
lib/
  main.dart                          # Platform initialization + ProviderScope
  app.dart                           # Application composition and theme
  core/                              # Theme and exact money/date formatting
  features/expenses/
    domain/
      entities/                      # Pure Dart expenses, preferences, filters
      repositories/                  # Storage abstraction
      usecases/                      # Denomination-independent spending reports
    data/                            # SQLite schema and repository implementation
    presentation/
      providers/                     # Riverpod state and dependency injection
      screens/                       # Overview, Activity, Insights
      widgets/                       # Expense/settings editors and shared UI
```

Domain code has no Flutter or SQLite dependency. Providers inject the repository into presentation; tests can replace it without platform channels. Database tests use SQLite through FFI.

## Local data

The application database is `expense_pro.sqlite` in the platform's private application database directory. Amounts and budgets use integer minor units. Queries use inclusive period starts and exclusive ends; user search text is parameterized and SQL wildcard characters are treated literally.

The version-1 schema stores expenses, indexed dates/categories, and preferences. Preferences and expenses survive app restarts. Android automatic backup and device-transfer rules exclude app data. Uninstalling the app removes its local data; no export or cloud sync is included in this version.

The app uses the device's local calendar and timezone for dates and filtering. Each expense retains its date/time, while the date picker changes its calendar day.

The bundled Noto Sans Bengali fallback ensures the taka symbol renders across platforms. Its SIL Open Font License is included in `assets/fonts/OFL.txt`.
