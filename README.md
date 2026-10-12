# Worktime for Flutter

Android and iPhone work-time tracker with a start/stop timer, manual entries, daily/weekly totals, filters, deletion, and CSV export through the phone share sheet.

Entries and the active timer are saved locally on the device. The timer resumes from its recorded start time after the app closes. No account or network connection is needed for tracking. Existing web-browser entries are not imported or synced.

Type a task description under "What are you working on?", then choose its category with the quick category buttons in the timer or Add time form: After Sales, Portfolio Management, Prospection, Order Delivery, Bike Build, Bike Repair, Recycling, Clean Workshop & Vehicles, Project Work, and Administration. A description and category are required for new entries; choosing a category keeps your typed description. Categories are disabled while the timer is running. The description and category are saved separately and included in the time entries, CSV and monthly Excel reports. Existing entries without a category remain readable, and older active timers can still be stopped and saved.

The dashboard uses a dark navy theme with cyan and lime accents and adapts to phone and wider screens. JetBrains Mono is the fixed typeface throughout the app and is bundled for offline use under the SIL Open Font License. Its license is in assets/fonts/licenses/JetBrainsMono-OFL.txt and is registered in Flutter's license registry.

## Run

Install Flutter, then run `flutter pub get` and `flutter run` in this folder. Build Android with `flutter build apk`. iPhone builds require a full Xcode installation, CocoaPods, and Apple signing configuration; use `flutter build ios` and Xcode to install or distribute.

## Validation

Run `flutter test`. The widget test starts/stops the timer and verifies the entry remains after the app is recreated.

The APK supplied alongside this project, if present, is a debug build for personal testing, not an app-store release.

Use Calculate month to select any day in the month and review its report. The report uses all recorded history for a previous-month comparison, and shows category shares, daily and weekly hours, session averages, busiest day and goal progress. Current-month comparisons use the same elapsed calendar cutoff in the previous month, capped at its end. The existing 20-hour weekly goal is prorated over calendar days; current-month progress uses elapsed days and time. Future-month goals are shown as planned targets without progress.

Tap Open Excel to save the Excel (.xlsx) workbook locally and open it with the device's spreadsheet viewer or app. Tap Share Excel to share it or save a copy elsewhere. If no spreadsheet app is available, the report stays visible and can still be shared. Excel uses the original single Worktime sheet: Task, Category, Project, From, To and numeric decimal Hours worked, followed by project totals and Total time worked. Bank details appear below the monthly total.

Report analysis runs locally and uses only recorded data. Entries crossing month/day/week boundaries are split for totals, and active timers are excluded until stopped. Checks identify overlaps, missing categories, invalid durations, sessions over 12 hours and future-dated entries. Overlapping sessions remain in recorded totals and are flagged for review. The workbook is a snapshot; regenerate it after updating entries.

Use Edit bank details in the monthly review card to change the account holder, IBAN/account number, bank name, country, currency and BIC/SWIFT. These details are saved locally and appear in the report preview, text report and Excel Worktime sheet. Clear the fields to omit bank details from subsequent reports.
