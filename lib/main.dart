import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import 'backup.dart';
import 'expenses.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import 'monthly_report_dialog.dart';
import 'task_categories.dart';
import 'app_style.dart';
import 'models.dart';
import 'report_analysis.dart';
import 'retention.dart';
import 'payroll.dart';
import 'payroll_dialog.dart';
import 'monthly_report.dart';
import 'bank_details.dart';
import 'bank_details_dialog.dart';

export 'models.dart';
export 'monthly_report.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      ['JetBrains Mono'],
      await rootBundle.loadString(
        'assets/fonts/licenses/JetBrainsMono-OFL.txt',
      ),
    );
    yield LicenseEntryWithLineBreaks([
      appFontFamily,
    ], await rootBundle.loadString('assets/fonts/licenses/Saira-OFL.txt'));
    yield LicenseEntryWithLineBreaks([
      appDisplayFontFamily,
    ], await rootBundle.loadString('assets/fonts/licenses/Michroma-OFL.txt'));
  });
  runApp(const WorktimeApp());
}

class WorktimeApp extends StatelessWidget {
  const WorktimeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Worktime',
    debugShowCheckedModeBanner: false,
    themeMode: ThemeMode.light,
    theme: buildWorktimeTheme(),
    home: const Tracker(),
  );
}

class Tracker extends StatefulWidget {
  const Tracker({super.key});
  @override
  State<Tracker> createState() => _TrackerState();
}

class _TrackerState extends State<Tracker> {
  final task = TextEditingController();
  List<Entry> entries = [];
  List<String> categories = List.of(taskCategories);
  List<Expense> expenses = [];
  Entry? running;
  Timer? ticker;
  SharedPreferences? prefs;
  bool ready = false;
  String filter = 'week';
  int tab = 0;
  String? selectedCategory;
  String? taskError, categoryError;
  bool backupBusy = false;
  String? _confirmedBackup;
  Set<String> _backedUpEntryKeys = const {};
  String? get confirmedBackup => _confirmedBackup;
  set confirmedBackup(String? data) {
    _confirmedBackup = data;
    _backedUpEntryKeys = backedUpEntryKeys(data);
  }

  List<Entry> get oldBackedUpEntries =>
      prunableEntries(entries, _backedUpEntryKeys, DateTime.now());
  String get currentBackupData =>
      jsonEncode(WorktimeBackup(entries, running, bankDetails, expenses).data);
  String get backupStatus => confirmedBackup == null
      ? 'No confirmed backup'
      : confirmedBackup == currentBackupData
      ? 'Backup confirmed · up to date'
      : 'Changes since last backup';
  BankDetails bankDetails = defaultBankDetails;
  PayrollSettings payrollSettings = const PayrollSettings();
  @override
  void initState() {
    super.initState();
    load();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && running != null) setState(() {});
    });
  }

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    categories =
        prefs!.getStringList('worktime-categories') ?? List.of(taskCategories);
    confirmedBackup = prefs!.getString('worktime-confirmed-backup');
    try {
      final payroll = prefs!.getString('worktime-payroll');
      if (payroll != null) {
        payrollSettings = PayrollSettings.fromJson(
          Map<String, dynamic>.from(jsonDecode(payroll) as Map),
        );
      }
    } catch (_) {
      // Unreadable payroll settings fall back to the defaults.
    }
    try {
      final raw = jsonDecode(prefs!.getString('worktime') ?? '{"entries":[]}');
      entries = (raw['entries'] as List).map((e) => Entry.fromJson(e)).toList();
      expenses = (raw['expenses'] as List? ?? [])
          .map((e) => Expense.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (raw['bankDetails'] is Map<String, dynamic>) {
        bankDetails = BankDetails.fromJson(raw['bankDetails']);
      }
      if (raw['running'] != null) {
        running = Entry.fromJson(raw['running']);
        task.text = running!.task;
        selectedCategory = running!.category;
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved data could not be read.')),
        );
      }
    }
    if (mounted) setState(() => ready = true);
  }

  Future<bool> save({List<Expense>? updatedExpenses}) async {
    try {
      final ok = await prefs!.setString(
        'worktime',
        jsonEncode({
          'expenses': (updatedExpenses ?? expenses)
              .map((e) => e.toJson())
              .toList(),
          'entries': entries.map((e) => e.toJson()).toList(),
          'running': running?.toJson(),
          'bankDetails': bankDetails.toJson(),
        }),
      );
      if (!ok) throw Exception();
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save. Please export your entries.'),
          ),
        );
      }
    }
    return false;
  }

  @override
  void dispose() {
    ticker?.cancel();
    task.dispose();
    super.dispose();
  }

  DateTime get today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime get monday => today.subtract(Duration(days: today.weekday - 1));
  Duration total(DateTime from, DateTime to) {
    int ms = 0;
    for (final e in [...entries, ?running]) {
      final a = e.start.isAfter(from) ? e.start : from;
      final end = e.end ?? DateTime.now();
      final b = end.isBefore(to) ? end : to;
      if (b.isAfter(a)) ms += b.difference(a).inMilliseconds;
    }
    return Duration(milliseconds: ms);
  }

  void toggle() {
    if (running == null) {
      setState(() {
        taskError = task.text.trim().isEmpty
            ? 'Type what you are working on.'
            : null;
        categoryError = categories.contains(selectedCategory)
            ? null
            : 'Choose a quick category.';
      });
      if (taskError != null || categoryError != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(taskError ?? categoryError!)));
        return;
      }
    }
    setState(() {
      if (running != null) {
        entries.add(
          Entry(
            running!.task,
            running!.start,
            DateTime.now(),
            running!.category,
          ),
        );
        running = null;
      } else {
        running = Entry(
          task.text.trim(),
          DateTime.now(),
          null,
          selectedCategory,
        );
      }
    });
    save();
  }

  Future<void> manual([Entry? existing]) async {
    final result = await showModalBottomSheet<Entry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ManualEntry(entry: existing, categories: categories),
    );
    if (result != null && mounted) {
      setState(() {
        if (existing == null) {
          entries.add(result);
        } else {
          final index = entries.indexOf(existing);
          if (index != -1) entries[index] = result;
        }
      });
      await save();
    }
  }

  Future<void> editCategories() async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CategoryEditor(categories: categories),
    );
    if (result == null || !mounted) return;
    final saved = await prefs!.setStringList('worktime-categories', result);
    if (!mounted) return;
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Categories could not be saved.')),
      );
      return;
    }
    setState(() {
      categories = result;
      if (running == null && !categories.contains(selectedCategory)) {
        selectedCategory = null;
      }
      categoryError = null;
    });
  }

  Future<void> editExpense([Expense? existing]) async {
    final result = await showModalBottomSheet<Expense>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ExpenseEditor(expense: existing),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (existing == null) {
        expenses.add(result);
      } else {
        expenses[expenses.indexOf(existing)] = result;
      }
    });
    await save();
  }

  bool settlingExpense = false;

  Future<void> toggleExpenseSettled(Expense expense) async {
    if (settlingExpense) return;
    final index = expenses.indexOf(expense);
    if (index < 0) return;
    final updated = List<Expense>.of(expenses);
    updated[index] = Expense(
      expense.description,
      expense.date,
      expense.cents,
      receipt: expense.receipt,
      isSettled: !expense.isSettled,
    );
    setState(() => settlingExpense = true);
    final saved = await save(updatedExpenses: updated);
    if (!mounted) return;
    setState(() {
      if (saved) expenses = updated;
      settlingExpense = false;
    });
  }

  Future<void> deleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Spesen löschen?'),
        content: Text(expense.description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => expenses.remove(expense));
    await save();
  }

  Future<void> remove(Entry e) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text(e.task),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes == true) {
      setState(() => entries.remove(e));
      await save();
    }
  }

  Future<void> calculateMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      helpText: 'Choose any day in the month to calculate',
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    final month = DateTime(picked.year, picked.month);
    final filename =
        'worktime-${month.year}-${month.month.toString().padLeft(2, '0')}.xlsx';
    try {
      final analysis = MonthlyAnalysis(
        [...entries, ?running],
        month,
        asOf: DateTime.now(),
      );
      final report = monthlyReportFromAnalysis(
        analysis,
        bankDetails: bankDetails,
        expenses: expenses,
      );
      final bytes = monthlyWorkbookFromAnalysis(
        analysis,
        bankDetails: bankDetails,
        expenses: expenses,
      );
      await showDialog<void>(
        context: context,
        builder: (_) => MonthlyReportDialog(
          report: report,
          filename: filename,
          bytes: bytes,
          analysis: analysis,
          expenses: expenses,
          bankDetails: bankDetails,
          payrollSettings: payrollSettings,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The monthly Excel report could not be created. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> editBankDetails() async {
    final details = await showDialog<BankDetails>(
      context: context,
      builder: (_) => BankDetailsDialog(details: bankDetails),
    );
    if (details == null || !mounted) return;
    setState(() => bankDetails = details);
    await save();
  }

  Future<void> removeOldEntries() async {
    final old = prunableEntries(entries, _backedUpEntryKeys, DateTime.now());
    if (old.isEmpty || !mounted) return;
    final cutoff = MaterialLocalizations.of(context)
        .formatMediumDate(entryRetentionCutoff(DateTime.now()));
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove old time entries?'),
        content: Text(
          '${old.length} ${old.length == 1 ? 'entry' : 'entries'} from before $cutoff '
          '${old.length == 1 ? 'is' : 'are'} already in your confirmed Drive backup. '
          'Remove ${old.length == 1 ? 'it' : 'them'} from this device? '
          'Reports for those months will then need the backup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final wasUpToDate = confirmedBackup == currentBackupData;
    final previous = List.of(entries);
    final removed = Set<Entry>.identity()..addAll(old);
    setState(() => entries.removeWhere(removed.contains));
    if (!await save()) {
      if (mounted) setState(() => entries = previous);
      return;
    }
    // Everything still on the device remains covered by the Drive backup, so
    // keep the status "up to date" and shrink the stored snapshot with it.
    if (wasUpToDate) {
      final data = currentBackupData;
      if (await prefs!.setString('worktime-confirmed-backup', data) &&
          mounted) {
        setState(() => confirmedBackup = data);
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Removed ${old.length} old ${old.length == 1 ? 'entry' : 'entries'}.',
        ),
      ),
    );
  }

  Future<void> editPayrollSettings() async {
    final settings = await showDialog<PayrollSettings>(
      context: context,
      builder: (_) => PayrollSettingsDialog(settings: payrollSettings),
    );
    if (settings == null || !mounted) return;
    final saved = await prefs!.setString(
      'worktime-payroll',
      jsonEncode(settings.toJson()),
    );
    if (!mounted) return;
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lohndaten konnten nicht gespeichert werden.'),
        ),
      );
      return;
    }
    setState(() => payrollSettings = settings);
  }

  Future<void> createBackup() async {
    setState(() => backupBusy = true);
    var backupConfirmed = false;
    try {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Save to Google Drive'),
          content: const Text(
            'In the next share menu, choose Drive, select your Google account and folder, then tap Save. The backup is uploaded only after you save it in Drive. If Drive is missing, install or sign in to the Google Drive app.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
      final snapshot = WorktimeBackup(
        List.of(entries),
        running,
        bankDetails,
        List.of(expenses),
      );
      final snapshotData = jsonEncode(snapshot.data);
      final text = snapshot.encode();
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(text)),
              mimeType: 'application/json',
            ),
          ],
          fileNameOverrides: [
            'worktime-backup-${DateTime.now().toIso8601String().replaceAll(':', '-')}.json',
          ],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Did you save the backup to Drive?'),
          content: const Text(
            'Confirm only after Google Drive finishes saving the file. Worktime cannot verify the upload through the share menu.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Not saved'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Yes, saved to Drive'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        if (!await prefs!.setString(
          'worktime-confirmed-backup',
          snapshotData,
        )) {
          throw StateError('Backup confirmation could not be saved.');
        }
        if (mounted) setState(() => confirmedBackup = snapshotData);
        backupConfirmed = true;
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup could not be shared. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => backupBusy = false);
    }
    if (backupConfirmed && mounted) await removeOldEntries();
  }

  Future<void> restoreBackup() async {
    setState(() => backupBusy = true);
    try {
      final picked = await FilePicker.pickFiles(type: FileType.any);
      if (picked.isEmpty || !mounted) return;
      final bytes = await picked.single.readAsBytes();
      if (!mounted) return;
      final backup = WorktimeBackup.decode(utf8.decode(bytes));
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Restore backup?'),
          content: Text(
            'Replace current data with ${backup.entries.length} completed entries, ${backup.running == null ? "no active timer" : "one active timer"}, ${backup.expenses.length} expenses, and saved bank details? A recovery copy of your current data will be kept on this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final original = prefs!.getString('worktime');
      if (original != null &&
          !await prefs!.setString('worktime-before-restore', original)) {
        throw const FormatException(
          'Could not save a recovery copy. Nothing was restored.',
        );
      }
      if (!await prefs!.setString('worktime', jsonEncode(backup.data))) {
        throw const FormatException('Restore could not be saved.');
      }
      if (!mounted) return;
      setState(() {
        entries = backup.entries;
        expenses = backup.expenses;
        running = backup.running;
        bankDetails = backup.bankDetails;
        task.text = running?.task ?? '';
        selectedCategory = running?.category;
        taskError = null;
        categoryError = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Backup restored.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException
                  ? error.message
                  : 'Backup could not be restored. Current data was kept.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => backupBusy = false);
    }
  }

  Widget sectionTitle(String eyebrow, String title, IconData icon) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.text,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontFamily: appDisplayFontFamily,
                fontSize: 14,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget statusPill(String label, {Color color = AppColors.cyan}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget metric(String label, Duration value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: AppColors.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                hours(value),
                style: TextStyle(
                  fontFamily: appDisplayFontFamily,
                  color: color,
                  fontSize: 19,
                ),
              ),
            ),
          ],
        ),
      );

  Widget timeEntry(Entry entry) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.fromLTRB(12, 6, 4, 10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  entry.task,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Edit entry',
              onPressed: () => manual(entry),
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
            IconButton(
              tooltip: 'Delete entry',
              onPressed: () => remove(entry),
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
        Text(
          entry.category?.trim().isNotEmpty == true
              ? entry.category!.trim()
              : 'Uncategorized',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              MaterialLocalizations.of(context).formatShortDate(entry.start),
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
            Text(
              '${TimeOfDay.fromDateTime(entry.start).format(context)} – ${TimeOfDay.fromDateTime(entry.end!).format(context)}',
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.text,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                hours(entry.end!.difference(entry.start)),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final week = total(monday, now);
    final monthStart = DateTime(now.year, now.month);
    final nextMonthStart = DateTime(now.year, now.month + 1);
    final shown = entries.where((e) {
      if (filter == 'month') {
        return e.start.isBefore(nextMonthStart) && e.end!.isAfter(monthStart);
      }
      return e.end!.isAfter(filter == 'today' ? today : monday);
    }).toList()..sort((a, b) => b.start.compareTo(a.start));

    final timerPanel = AppPanel(
      accent: running == null ? null : AppColors.text,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'FOCUS TIMER',
                style: TextStyle(
                  letterSpacing: 2,
                  fontSize: 11,
                  color: AppColors.muted,
                ),
              ),
              statusPill(
                running == null ? 'Ready when you are' : 'Focus in progress',
                color: running == null ? AppColors.cyan : AppColors.lime,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                clock(
                  running == null
                      ? Duration.zero
                      : now.difference(running!.start),
                ),
                style: TextStyle(
                  fontFamily: appDisplayFontFamily,
                  fontSize: 48,
                  letterSpacing: 2,
                  color: running == null ? AppColors.text : AppColors.lime,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const Text(
            'What are you working on?',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: task,
            enabled: running == null,
            minLines: 1,
            maxLines: 4,
            onChanged: (_) {
              if (taskError != null) setState(() => taskError = null);
            },
            decoration: InputDecoration(
              labelText: 'Task description',
              hintText: 'e.g. Replace brake pads',
              alignLabelWithHint: true,
              errorText: taskError,
              errorMaxLines: 2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'QUICK CATEGORIES',
                  style: TextStyle(
                    color: AppColors.muted,
                    letterSpacing: 1.8,
                    fontSize: 10,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: editCategories,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit categories'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TaskCategoryPicker(
            categories: categories,
            selectedCategory: selectedCategory,
            enabled: running == null,
            onSelected: (category) => setState(() {
              selectedCategory = category;
              categoryError = null;
            }),
          ),
          if (categoryError != null) ...[
            const SizedBox(height: 8),
            Text(
              categoryError!,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: toggle,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.text,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(46),
            ),
            icon: Icon(
              running == null ? Icons.play_arrow_rounded : Icons.stop_rounded,
            ),
            label: Text(running == null ? 'Start timer' : 'Stop & save'),
          ),
        ],
      ),
    );

    final statsPanel = AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sectionTitle(
            'YOUR MOMENTUM',
            'Your working week',
            Icons.insights_rounded,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: tileWidth,
                    child: metric(
                      'Today',
                      total(today, now),
                      Icons.wb_sunny_outlined,
                      AppColors.cyan,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: metric(
                      'This week',
                      week,
                      Icons.view_week_outlined,
                      AppColors.cyan,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            'WEEKLY GOAL',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                '${(week.inMinutes / 60).toStringAsFixed(1)} / 20 hours',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${(week.inMinutes / 1200 * 100).round()}%',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: (week.inMinutes / 1200).clamp(0.0, 1.0),
            minHeight: 5,
            color: AppColors.text,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This month',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  hours(total(monthStart, now)),
                  style: const TextStyle(
                    fontFamily: appDisplayFontFamily,
                    fontSize: 19,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Calculate month to review your Excel report.',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final shownTotal = shown.fold(
      Duration.zero,
      (sum, e) => sum + e.end!.difference(e.start),
    );
    final workLogHeader = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sectionTitle(
          'WORK LOG',
          'Your time entries',
          Icons.format_list_bulleted_rounded,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final f in ['today', 'week', 'month'])
              ChoiceChip(
                label: Text(
                  {
                    'today': 'Today',
                    'week': 'This week',
                    'month': 'This month',
                  }[f]!,
                ),
                selected: filter == f,
                onSelected: (_) => setState(() => filter = f),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Text(
              '${shown.length} ${shown.length == 1 ? 'entry' : 'entries'} · ${hours(shownTotal)}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            FilledButton.tonalIcon(
              onPressed: manual,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add time'),
            ),
          ],
        ),
        if (shown.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Icon(Icons.timelapse_rounded, color: AppColors.muted, size: 24),
                SizedBox(height: 6),
                Text(
                  'Start the timer or add work you’ve already done.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
      ],
    );

    Widget page(Widget scrollable) => WorktimeBackground(
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: scrollable,
          ),
        ),
      ),
    );

    final workLogPage = page(
      ListView.builder(
        key: const PageStorageKey('work-log'),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        itemCount: shown.length + 1,
        itemBuilder: (context, i) =>
            i == 0 ? workLogHeader : timeEntry(shown[i - 1]),
      ),
    );

    final sortedExpenses = List<Expense>.of(expenses)
      ..sort((a, b) => b.date.compareTo(a.date));
    final expensesHeader = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sectionTitle('SPESEN', 'Spesen', Icons.receipt_long_outlined),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Text(
              'Diesen Monat: ${expenseAmount(expensesForMonth(expenses, DateTime.now()).fold<int>(0, (sum, e) => sum + e.cents))}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            FilledButton.tonalIcon(
              onPressed: () => editExpense(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Spesen erfassen'),
            ),
          ],
        ),
        if (expenses.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Noch keine Spesen erfasst.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
      ],
    );

    Widget expenseTile(Expense expense) => Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        visualDensity: VisualDensity.compact,
        title: Text(
          expense.description,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        leading: expense.receipt == null
            ? null
            : const Icon(Icons.receipt_long, semanticLabel: 'Beleg angehängt'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${MaterialLocalizations.of(context).formatShortDate(expense.date)} · ${expenseAmount(expense.cents)} · ${expense.isSettled ? 'Abgerechnet' : 'Offen'}',
            ),
            TextButton.icon(
              onPressed: settlingExpense
                  ? null
                  : () => toggleExpenseSettled(expense),
              icon: Icon(
                expense.isSettled
                    ? Icons.check_circle
                    : Icons.check_circle_outline,
              ),
              label: Text(
                expense.isSettled ? 'Als offen markieren' : 'Abgerechnet',
              ),
            ),
          ],
        ),
        onTap: settlingExpense ? null : () => editExpense(expense),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: 'Spesen löschen',
          icon: const Icon(Icons.delete_outline),
          onPressed: settlingExpense ? null : () => deleteExpense(expense),
        ),
      ),
    );

    final expensesPage = page(
      ListView.builder(
        key: const PageStorageKey('expenses'),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        itemCount: sortedExpenses.length + 1,
        itemBuilder: (context, i) =>
            i == 0 ? expensesHeader : expenseTile(sortedExpenses[i - 1]),
      ),
    );

    final reviewPage = page(
      ListView(
        key: const PageStorageKey('review'),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        children: [
          AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                sectionTitle(
                  'MONTHLY REVIEW',
                  'See the whole picture.',
                  Icons.table_chart_outlined,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Review completed entries, category totals and bank details in Excel, and get your Lohnabrechnung as PDF.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: calculateMonth,
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('Calculate month'),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: editBankDetails,
                  icon: const Icon(Icons.account_balance_outlined),
                  label: Text(
                    bankDetails.isEmpty
                        ? 'Add bank details'
                        : 'Edit bank details',
                  ),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: editPayrollSettings,
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Lohndaten bearbeiten'),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final logoHeight = ((MediaQuery.sizeOf(context).width - 32) * 203 / 1600)
        .clamp(0.0, 64.0);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        automaticallyImplyLeading: false,
        toolbarHeight: logoHeight + 12,
        title: Image.asset(
          'assets/brand/molenstraat.png',
          width: double.infinity,
          height: logoHeight,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          semanticLabel: 'Molenstraat Fatbikes',
        ),
      ),
      bottomNavigationBar: !ready
          ? null
          : DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: NavigationBar(
                selectedIndex: tab,
                onDestinationSelected: (i) => setState(() => tab = i),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.timer_outlined),
                    selectedIcon: Icon(Icons.timer),
                    label: 'Timer',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.format_list_bulleted_rounded),
                    label: 'Work log',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long),
                    label: 'Spesen',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.table_chart_outlined),
                    selectedIcon: Icon(Icons.table_chart),
                    label: 'Review',
                  ),
                ],
              ),
            ),
      body: !ready
          ? const Center(child: CircularProgressIndicator())
          : tab == 1
          ? workLogPage
          : tab == 2
          ? expensesPage
          : tab == 3
          ? reviewPage
          : WorktimeBackground(
              child: SafeArea(
                bottom: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: ListView(
                      key: const PageStorageKey('dashboard'),
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: statusPill(
                            backupStatus,
                            color: confirmedBackup == currentBackupData
                                ? AppColors.text
                                : AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth >= 760) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 3, child: timerPanel),
                                  const SizedBox(width: 10),
                                  Expanded(flex: 2, child: statsPanel),
                                ],
                              );
                            }
                            return Column(children: [timerPanel, statsPanel]);
                          },
                        ),
                        AppPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              sectionTitle(
                                'YOUR DATA',
                                'Google Drive backup',
                                Icons.backup_outlined,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Tap Back up to Google Drive, then choose Drive in the share menu and save the file. To restore, choose Drive in the file picker and select your backup. Includes entries, expenses, your active timer and bank details.',
                              ),
                              const SizedBox(height: 10),
                              FilledButton.tonalIcon(
                                onPressed: backupBusy ? null : createBackup,
                                icon: const Icon(Icons.save_alt),
                                label: const Text('Back up to Google Drive'),
                              ),
                              const SizedBox(height: 6),
                              OutlinedButton.icon(
                                onPressed: backupBusy ? null : restoreBackup,
                                icon: const Icon(Icons.restore),
                                label: const Text('Restore from Google Drive'),
                              ),
                              if (oldBackedUpEntries.length case final count
                                  when count > 0) ...[
                                const SizedBox(height: 6),
                                TextButton.icon(
                                  onPressed: backupBusy
                                      ? null
                                      : removeOldEntries,
                                  icon: const Icon(Icons.cleaning_services),
                                  label: Text(
                                    'Remove $count backed-up '
                                    '${count == 1 ? 'entry' : 'entries'} '
                                    'older than $entryRetentionMonths months',
                                  ),
                                ),
                              ],
                              if (backupBusy)
                                const Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: LinearProgressIndicator(),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          backupStatus,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class ManualEntry extends StatefulWidget {
  const ManualEntry({super.key, this.entry, this.categories = taskCategories});
  final List<String> categories;
  final Entry? entry;
  @override
  State<ManualEntry> createState() => _ManualEntryState();
}

class _ManualEntryState extends State<ManualEntry> {
  final task = TextEditingController();
  DateTime day = DateTime.now();
  TimeOfDay start = const TimeOfDay(hour: 9, minute: 0),
      end = const TimeOfDay(hour: 10, minute: 0);
  String? error;
  String? selectedCategory;
  late DateTime endDay;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    if (entry != null) {
      task.text = entry.task;
      day = entry.start;
      start = TimeOfDay.fromDateTime(entry.start);
      end = TimeOfDay.fromDateTime(entry.end!);
      selectedCategory = entry.category;
    }
    endDay = entry?.end ?? day;
  }

  @override
  void dispose() {
    task.dispose();
    super.dispose();
  }

  DateTime timestamp(DateTime date, TimeOfDay time, DateTime? original) {
    final keepPrecision =
        original != null && time == TimeOfDay.fromDateTime(original);
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
      keepPrecision ? original.second : 0,
      keepPrecision ? original.millisecond : 0,
      keepPrecision ? original.microsecond : 0,
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      16,
      16,
      16,
      MediaQuery.of(context).viewInsets.bottom + 16,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.entry == null ? 'Add work time' : 'Edit work time',
            style: const TextStyle(
              fontFamily: appDisplayFontFamily,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'What are you working on?',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: task,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Task description',
              hintText: 'e.g. Replace brake pads',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'QUICK CATEGORIES',
            style: TextStyle(
              color: AppColors.muted,
              letterSpacing: 1.8,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          TaskCategoryPicker(
            categories: {
              ...widget.categories,
              if (widget.entry?.category != null) widget.entry!.category!,
            }.toList(),
            selectedCategory: selectedCategory,
            onSelected: (category) => setState(() {
              selectedCategory = category;
              error = null;
            }),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: day,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (d != null && mounted) {
                setState(() {
                  endDay = DateTime(
                    d.year,
                    d.month,
                    d.day +
                        DateTime.utc(endDay.year, endDay.month, endDay.day)
                            .difference(
                              DateTime.utc(day.year, day.month, day.day),
                            )
                            .inDays,
                  );
                  day = d;
                });
              }
            },
            child: Text(
              MaterialLocalizations.of(context).formatMediumDate(day),
            ),
          ),
          const SizedBox(height: 6),
          OutlinedButton(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: endDay,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (d != null && mounted) setState(() => endDay = d);
            },
            child: Text(
              'End date: ${MaterialLocalizations.of(context).formatMediumDate(endDay)}',
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: start,
                    );
                    if (t != null) setState(() => start = t);
                  },
                  child: Text('Start: ${start.format(context)}'),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: end,
                    );
                    if (t != null) setState(() => end = t);
                  },
                  child: Text('End: ${end.format(context)}'),
                ),
              ),
            ],
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () {
              final a = timestamp(day, start, widget.entry?.start);
              final b = timestamp(endDay, end, widget.entry?.end);
              if (task.text.trim().isEmpty || !b.isAfter(a)) {
                setState(
                  () => error = 'Enter a task description and an end time after the start.',
                );
                return;
              }
              if (!widget.categories.contains(selectedCategory) &&
                  !(widget.entry != null &&
                      selectedCategory == widget.entry!.category)) {
                setState(() => error = 'Choose a quick category.');
                return;
              }
              Navigator.pop(
                context,
                Entry(task.text.trim(), a, b, selectedCategory),
              );
            },
            child: const Text('Save entry'),
          ),
        ],
      ),
    ),
  );
}
