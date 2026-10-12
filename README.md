# Worktime for Flutter

Android and iPhone work-time tracker with a start/stop timer, manual entries, daily/weekly totals, filters, deletion, and CSV export through the phone share sheet.

Entries and the active timer are saved locally on the device. The timer resumes from its recorded start time after the app closes. No account or network connection is needed for tracking. Existing web-browser entries are not imported or synced.

## Run

Install Flutter, then run `flutter pub get` and `flutter run` in this folder. Build Android with `flutter build apk`. iPhone builds require a full Xcode installation, CocoaPods, and Apple signing configuration; use `flutter build ios` and Xcode to install or distribute.

## Validation

Run `flutter test`. The widget test starts/stops the timer and verifies the entry remains after the app is recreated.

The APK supplied alongside this project, if present, is a debug build for personal testing, not an app-store release.

Use Calculate month to select any day in the month and review its report. Tap Open Excel to save the Excel (.xlsx) sheet locally and open it with the device's spreadsheet viewer or app. Tap Share Excel to share it or save a copy elsewhere. If no spreadsheet app is available, the report stays visible and can still be shared. The report lists all completed entries chronologically, totals per project, and the monthly total. Hours are numeric decimal values. Entries crossing month boundaries are split, and active timers are excluded until stopped. Weekly goal: 20 hours.
