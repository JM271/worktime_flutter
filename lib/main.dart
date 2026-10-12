import 'dart:async';
import 'dart:convert';

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
import 'monthly_report.dart';
import 'bank_details.dart';
import 'bank_details_dialog.dart';

export 'models.dart';
export 'monthly_report.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      [appFontFamily],
      await rootBundle.loadString(
        'assets/fonts/licenses/JetBrainsMono-OFL.txt',
      ),
    );
  });
  runApp(const WorktimeApp());
}

class WorktimeApp extends StatelessWidget {
  const WorktimeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Worktime',
    debugShowCheckedModeBanner: false,
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
  Entry? running;
  Timer? ticker;
  SharedPreferences? prefs;
  bool ready = false;
  String filter = 'week';
  String? selectedCategory;
  String? taskError, categoryError;
  BankDetails bankDetails = defaultBankDetails;
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
    try {
      final raw = jsonDecode(prefs!.getString('worktime') ?? '{"entries":[]}');
      entries = (raw['entries'] as List).map((e) => Entry.fromJson(e)).toList();
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

  Future<void> save() async {
    try {
      final ok = await prefs!.setString(
        'worktime',
        jsonEncode({
          'entries': entries.map((e) => e.toJson()).toList(),
          'running': running?.toJson(),
          'bankDetails': bankDetails.toJson(),
        }),
      );
      if (!ok) throw Exception();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save. Please export your entries.'),
          ),
        );
      }
    }
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
        categoryError = taskCategories.contains(selectedCategory)
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
            running!.project,
            running!.start,
            DateTime.now(),
            running!.category,
          ),
        );
        running = null;
      } else {
        running = Entry(
          task.text.trim(),
          'General',
          DateTime.now(),
          null,
          selectedCategory,
        );
      }
    });
    save();
  }

  Future<void> manual() async {
    final result = await showModalBottomSheet<Entry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const ManualEntry(),
    );
    if (result != null) {
      setState(() => entries.add(result));
      await save();
    }
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

  Future<void> export() async {
    String cell(Object s) => '"${s.toString().replaceAll('"', '""')}"';
    final rows = [
      ['Task', 'Category', 'Project', 'Start', 'End', 'Hours'],
      ...entries.map(
        (e) => [
          e.task,
          e.category ?? '',
          e.project,
          e.start.toIso8601String(),
          e.end!.toIso8601String(),
          (e.end!.difference(e.start).inSeconds / 3600).toStringAsFixed(4),
        ],
      ),
    ];
    final csv = rows.map((r) => r.map(cell).join(',')).join('\r\n');
    final box = context.findRenderObject() as RenderBox?;
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(csv)),
              mimeType: 'text/csv',
            ),
          ],
          fileNameOverrides: ['worktime.csv'],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export could not be opened.')),
        );
      }
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
      );
      final bytes = monthlyWorkbookFromAnalysis(
        analysis,
        bankDetails: bankDetails,
      );
      await showDialog<void>(
        context: context,
        builder: (_) => MonthlyReportDialog(
          report: report,
          filename: filename,
          bytes: bytes,
          analysis: analysis,
          bankDetails: bankDetails,
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

  Widget sectionTitle(String eyebrow, String title, IconData icon) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.cyan.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cyan.withValues(alpha: 0.18)),
        ),
        child: Icon(icon, color: AppColors.cyan, size: 22),
      ),
      const SizedBox(width: 12),
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
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ],
  );

  Widget statusPill(String label, {Color color = AppColors.cyan}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 14),
            Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                hours(value),
                style: TextStyle(
                  color: color,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

  Widget timeEntry(Entry entry) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
    decoration: BoxDecoration(
      color: AppColors.background.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(16),
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
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  entry.task,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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
          entry.project,
          style: const TextStyle(color: AppColors.cyan, fontSize: 12),
        ),
        if (entry.category != null) ...[
          const SizedBox(height: 6),
          Text(
            'Category: ${entry.category}',
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 8,
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
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.lime.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                hours(entry.end!.difference(entry.start)),
                style: const TextStyle(
                  color: AppColors.lime,
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
      if (filter == 'all') return true;
      if (filter == 'month') {
        return e.start.isBefore(nextMonthStart) && e.end!.isAfter(monthStart);
      }
      return e.end!.isAfter(filter == 'today' ? today : monday);
    }).toList()..sort((a, b) => b.start.compareTo(a.start));

    final timerPanel = AppPanel(
      accent: running == null ? AppColors.cyan : AppColors.lime,
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
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                clock(
                  running == null
                      ? Duration.zero
                      : now.difference(running!.start),
                ),
                style: TextStyle(
                  fontSize: 70,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
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
          const SizedBox(height: 12),
          TextField(
            controller: task,
            enabled: running == null,
            minLines: 2,
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
          const SizedBox(height: 16),
          const Text(
            'QUICK CATEGORIES',
            style: TextStyle(
              color: AppColors.muted,
              letterSpacing: 1.8,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 8),
          TaskCategoryPicker(
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
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: toggle,
            style: FilledButton.styleFrom(
              backgroundColor: running == null
                  ? AppColors.cyan
                  : AppColors.lime,
              foregroundColor: AppColors.background,
              minimumSize: const Size.fromHeight(56),
            ),
            icon: Icon(
              running == null ? Icons.play_arrow_rounded : Icons.stop_rounded,
            ),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(running == null ? 'Start timer' : 'Stop & save'),
            ),
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
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
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
                      AppColors.lime,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          Text(
            'WEEKLY GOAL',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 8),
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
                style: const TextStyle(
                  color: AppColors.lime,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: (week.inMinutes / 1200).clamp(0.0, 1.0),
            minHeight: 7,
            color: AppColors.lime,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cyan.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cyan.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This month',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 6),
                Text(
                  hours(total(monthStart, now)),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
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

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.cyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.cyan.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: AppColors.cyan,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'WORKTIME',
                style: TextStyle(
                  fontSize: 16,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      body: !ready
          ? const Center(child: CircularProgressIndicator())
          : WorktimeBackground(
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      children: [
                        const Text(
                          'YOUR TIME, WELL SPENT',
                          style: TextStyle(
                            color: AppColors.cyan,
                            letterSpacing: 2.8,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Make time count.',
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1,
                              ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Track your work. Keep your momentum.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: statusPill(
                            'Saved on this device',
                            color: AppColors.lime,
                          ),
                        ),
                        const SizedBox(height: 22),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth >= 760) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 3, child: timerPanel),
                                  const SizedBox(width: 20),
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
                                'WORK LOG',
                                'Your time entries',
                                Icons.format_list_bulleted_rounded,
                              ),
                              const SizedBox(height: 20),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: export,
                                    icon: const Icon(
                                      Icons.ios_share_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Export'),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: manual,
                                    icon: const Icon(
                                      Icons.add_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Add time'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  for (final f in [
                                    'week',
                                    'today',
                                    'all',
                                    'month',
                                  ])
                                    ChoiceChip(
                                      label: Text(
                                        {
                                          'week': 'This week',
                                          'today': 'Today',
                                          'all': 'All time',
                                          'month': 'This month',
                                        }[f]!,
                                      ),
                                      selected: filter == f,
                                      onSelected: (_) =>
                                          setState(() => filter = f),
                                    ),
                                ],
                              ),
                              if (shown.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 30,
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.timelapse_rounded,
                                        color: AppColors.cyan.withValues(
                                          alpha: 0.5,
                                        ),
                                        size: 32,
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Start the timer or add work you’ve already done.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              for (final entry in shown) timeEntry(entry),
                            ],
                          ),
                        ),
                        AppPanel(
                          accent: AppColors.lime,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              sectionTitle(
                                'MONTHLY REVIEW',
                                'See the whole picture.',
                                Icons.table_chart_outlined,
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Review completed entries, project totals and bank details in Excel.',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 20),
                              FilledButton.tonalIcon(
                                onPressed: calculateMonth,
                                icon: const Icon(Icons.calculate_outlined),
                                label: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Text('Calculate month'),
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: editBankDetails,
                                icon: const Icon(
                                  Icons.account_balance_outlined,
                                ),
                                label: Text(
                                  bankDetails.isEmpty
                                      ? 'Add bank details'
                                      : 'Edit bank details',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Text(
                          'Saved on this device · Export to keep a backup',
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
  const ManualEntry({super.key});
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
  @override
  void dispose() {
    task.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
      24,
      MediaQuery.of(context).viewInsets.bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Add work time',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'What are you working on?',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          const Text(
            'QUICK CATEGORIES',
            style: TextStyle(
              color: AppColors.muted,
              letterSpacing: 1.8,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 8),
          TaskCategoryPicker(
            selectedCategory: selectedCategory,
            onSelected: (category) => setState(() {
              selectedCategory = category;
              error = null;
            }),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: day,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (d != null) setState(() => day = d);
            },
            child: Text(
              MaterialLocalizations.of(context).formatMediumDate(day),
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
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final a = DateTime(
                    day.year,
                    day.month,
                    day.day,
                    start.hour,
                    start.minute,
                  ),
                  b = DateTime(
                    day.year,
                    day.month,
                    day.day,
                    end.hour,
                    end.minute,
                  );
              if (task.text.trim().isEmpty || !b.isAfter(a)) {
                setState(
                  () => error = 'Enter a task description and an end time after the start.',
                );
                return;
              }
              if (!taskCategories.contains(selectedCategory)) {
                setState(() => error = 'Choose a quick category.');
                return;
              }
              Navigator.pop(
                context,
                Entry(task.text.trim(), 'General', a, b, selectedCategory),
              );
            },
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Save entry'),
            ),
          ),
        ],
      ),
    ),
  );
}
