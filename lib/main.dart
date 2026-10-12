import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as xlsx;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

void main() => runApp(const WorktimeApp());

class WorktimeApp extends StatelessWidget {
  const WorktimeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Worktime',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff304a36)),
      scaffoldBackgroundColor: const Color(0xfff5f6f2),
    ),
    home: const Tracker(),
  );
}

class Entry {
  final String task, project;
  final DateTime start;
  final DateTime? end;
  Entry(this.task, this.project, this.start, [this.end]);
  Map<String, dynamic> toJson() => {
    'task': task,
    'project': project,
    'start': start.toIso8601String(),
    'end': end?.toIso8601String(),
  };
  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
    j['task'],
    j['project'],
    DateTime.parse(j['start']),
    j['end'] == null ? null : DateTime.parse(j['end']),
  );
}

String hours(Duration d) {
  final m = d.inMinutes;
  return '${m ~/ 60}h ${(m % 60).toString().padLeft(2, '0')}m';
}

String clock(Duration d) =>
    '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

Duration monthlyTotal(List<Entry> entries, DateTime month) {
  final from = DateTime(month.year, month.month);
  final to = DateTime(month.year, month.month + 1);
  var total = Duration.zero;
  for (final entry in entries) {
    if (entry.end == null) continue;
    final start = entry.start.isAfter(from) ? entry.start : from;
    final end = entry.end!.isBefore(to) ? entry.end! : to;
    if (end.isAfter(start)) total += end.difference(start);
  }
  return total;
}

String monthlyReport(List<Entry> entries, DateTime month) {
  final from = DateTime(month.year, month.month);
  final to = DateTime(month.year, month.month + 1);
  String two(int n) => n.toString().padLeft(2, '0');
  String stamp(DateTime d) =>
      '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  String clean(String value) => value.replaceAll(RegExp(r'[\r\n\t|]+'), ' ');
  final selected =
      entries
          .where(
            (e) =>
                e.end != null && e.start.isBefore(to) && e.end!.isAfter(from),
          )
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  final projects = <String, Duration>{};
  final details = <String>[];
  for (final entry in selected) {
    final start = entry.start.isAfter(from) ? entry.start : from;
    final end = entry.end!.isBefore(to) ? entry.end! : to;
    if (!end.isAfter(start)) continue;
    final elapsed = end.difference(start);
    projects.update(
      entry.project,
      (value) => value + elapsed,
      ifAbsent: () => elapsed,
    );
    details.add(
      '${clean(entry.task)} | ${clean(entry.project)} | ${stamp(start)} | ${stamp(end)} | ${hours(elapsed)}',
    );
  }
  final names = projects.keys.toList()..sort();
  return [
    '${from.year}-${two(from.month)}',
    '',
    'Task | Project | From | To | Time worked',
    if (details.isEmpty) 'No entries.' else ...details,
    '',
    ...names.map((name) => '${clean(name)} total: ${hours(projects[name]!)}'),
    'Total time worked: ${hours(monthlyTotal(entries, from))}',
    '',
  ].join('\n');
}

Uint8List monthlyWorkbook(List<Entry> entries, DateTime month) {
  final book = xlsx.Excel.createExcel();
  book.rename('Sheet1', 'Worktime');
  final sheet = book['Worktime'];
  final from = DateTime(month.year, month.month);
  final to = DateTime(month.year, month.month + 1);
  sheet.appendRow([
    xlsx.TextCellValue(
      'Worktime · ${month.year}-${month.month.toString().padLeft(2, '0')}',
    ),
  ]);
  sheet.appendRow([xlsx.TextCellValue('')]);
  sheet.appendRow(
    [
      'Task',
      'Project',
      'From',
      'To',
      'Hours worked',
    ].map(xlsx.TextCellValue.new).toList(),
  );
  final selected =
      entries
          .where(
            (e) =>
                e.end != null && e.start.isBefore(to) && e.end!.isAfter(from),
          )
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  final projects = <String, Duration>{};
  for (final entry in selected) {
    final start = entry.start.isAfter(from) ? entry.start : from;
    final end = entry.end!.isBefore(to) ? entry.end! : to;
    if (!end.isAfter(start)) continue;
    final elapsed = end.difference(start);
    projects.update(entry.project, (v) => v + elapsed, ifAbsent: () => elapsed);
    sheet.appendRow([
      xlsx.TextCellValue(entry.task),
      xlsx.TextCellValue(entry.project),
      xlsx.DateTimeCellValue.fromDateTime(start),
      xlsx.DateTimeCellValue.fromDateTime(end),
      xlsx.DoubleCellValue(elapsed.inMicroseconds / 3600000000),
    ]);
    final row = sheet.maxRows - 1;
    for (final col in [2, 3]) {
      sheet
          .cell(
            xlsx.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
          )
          .cellStyle = xlsx.CellStyle(
        numberFormat: xlsx.CustomDateTimeNumFormat(formatCode: 'dd.mm.yyyy hh:mm'),
      );
    }
  }
  sheet.appendRow([xlsx.TextCellValue('')]);
  final projectHeader = sheet.maxRows;
  sheet.appendRow([
    xlsx.TextCellValue('Project totals'),
    null,
    null,
    null,
    xlsx.TextCellValue('Hours worked'),
  ]);
  final names = projects.keys.toList()..sort();
  for (final name in names) {
    sheet.appendRow([
      xlsx.TextCellValue(name),
      null,
      null,
      null,
      xlsx.DoubleCellValue(projects[name]!.inMicroseconds / 3600000000),
    ]);
  }
  sheet.appendRow([
    xlsx.TextCellValue('Total time worked'),
    null,
    null,
    null,
    xlsx.DoubleCellValue(
      monthlyTotal(entries, month).inMicroseconds / 3600000000,
    ),
  ]);
  for (var row = 3; row < sheet.maxRows; row++) {
    final cell = sheet.cell(
      xlsx.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
    );
    if (cell.value is xlsx.DoubleCellValue)
      cell.cellStyle = xlsx.CellStyle(
        numberFormat: xlsx.CustomNumericNumFormat(formatCode: '0.00'),
      );
  }
  for (final row in [0, 2, projectHeader, sheet.maxRows - 1]) {
    for (var col = 0; col < 5; col++) {
      final cell = sheet.cell(
        xlsx.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
      );
      cell.cellStyle = (cell.cellStyle ?? xlsx.CellStyle()).copyWith(
        boldVal: true,
        backgroundColorHexVal: xlsx.ExcelColor.fromHexString('E9EFDF'),
      );
    }
  }
  for (final col in [0, 1]) {
    sheet.setColumnWidth(col, 30);
  }
  for (final col in [2, 3]) {
    sheet.setColumnWidth(col, 23);
  }
  sheet.setColumnWidth(4, 18);
  return Uint8List.fromList(book.encode()!);
}

class Tracker extends StatefulWidget {
  const Tracker({super.key});
  @override
  State<Tracker> createState() => _TrackerState();
}

class _TrackerState extends State<Tracker> {
  final task = TextEditingController(), project = TextEditingController();
  List<Entry> entries = [];
  Entry? running;
  Timer? ticker;
  SharedPreferences? prefs;
  bool ready = false;
  String filter = 'week';
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
      if (raw['running'] != null) {
        running = Entry.fromJson(raw['running']);
        task.text = running!.task;
        project.text = running!.project;
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved data could not be read.')),
        );
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
        }),
      );
      if (!ok) throw Exception();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save. Please export your entries.'),
          ),
        );
    }
  }

  @override
  void dispose() {
    ticker?.cancel();
    task.dispose();
    project.dispose();
    super.dispose();
  }

  DateTime get today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime get monday => today.subtract(Duration(days: today.weekday - 1));
  Duration total(DateTime from, DateTime to) {
    int ms = 0;
    for (final e in [...entries, if (running != null) running!]) {
      final a = e.start.isAfter(from) ? e.start : from;
      final end = e.end ?? DateTime.now();
      final b = end.isBefore(to) ? end : to;
      if (b.isAfter(a)) ms += b.difference(a).inMilliseconds;
    }
    return Duration(milliseconds: ms);
  }

  void toggle() {
    setState(() {
      if (running != null) {
        entries.add(
          Entry(
            running!.task,
            running!.project,
            running!.start,
            DateTime.now(),
          ),
        );
        running = null;
      } else {
        running = Entry(
          task.text.trim().isEmpty ? 'Focused work' : task.text.trim(),
          project.text.trim().isEmpty ? 'General' : project.text.trim(),
          DateTime.now(),
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
      ['Task', 'Project', 'Start', 'End', 'Hours'],
      ...entries.map(
        (e) => [
          e.task,
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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export could not be opened.')),
        );
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
    final report = monthlyReport(entries, month);
    final filename =
        'worktime-${month.year}-${month.month.toString().padLeft(2, '0')}.xlsx';
    final box = context.findRenderObject() as RenderBox?;
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              monthlyWorkbook(entries, month),
              mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ),
          ],
          fileNameOverrides: [filename],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Monthly report'),
          content: SingleChildScrollView(child: SelectableText(report)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }
  }

  Widget panel(Widget child, {Color? color}) => Card(
    elevation: 0,
    color: color ?? Colors.white,
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(padding: const EdgeInsets.all(22), child: child),
  );
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final week = total(monday, now);
    final shown =
        entries
            .where(
              (e) =>
                  filter == 'all' ||
                  e.end!.isAfter(filter == 'today' ? today : monday),
            )
            .toList()
          ..sort((a, b) => b.start.compareTo(a.start));
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '◷ worktime',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xfff5f6f2),
      ),
      body: !ready
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'YOUR TIME, WELL SPENT',
                        style: TextStyle(letterSpacing: 2, fontSize: 11),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Make time count.',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Track your work, one task at a time.'),
                      ),
                      panel(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              running == null
                                  ? 'Ready when you are'
                                  : '● Focus time in progress',
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: FittedBox(
                                child: Text(
                                  clock(
                                    running == null
                                        ? Duration.zero
                                        : now.difference(running!.start),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 56,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            TextField(
                              controller: task,
                              enabled: running == null,
                              decoration: const InputDecoration(
                                labelText: 'What are you working on?',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: project,
                              enabled: running == null,
                              decoration: const InputDecoration(
                                labelText: 'Project',
                                hintText: 'General',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: toggle,
                              icon: Icon(
                                running == null ? Icons.play_arrow : Icons.stop,
                              ),
                              label: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Text(
                                  running == null
                                      ? 'Start timer'
                                      : 'Stop & save',
                                ),
                              ),
                            ),
                          ],
                        ),
                        color: const Color(0xffe9efdf),
                      ),
                      panel(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your working week',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Today'),
                                      Text(
                                        hours(total(today, now)),
                                        style: const TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('This week'),
                                      Text(
                                        hours(week),
                                        style: const TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '${(week.inMinutes / 60).toStringAsFixed(1)} / 20 hours',
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: (week.inMinutes / 1200).clamp(0.0, 1.0),
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ],
                        ),
                      ),
                      panel(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Your time entries',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: export,
                                    icon: const Icon(Icons.ios_share),
                                    label: const Text('Export'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton.tonalIcon(
                                    onPressed: manual,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add time'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final f in ['week', 'today', 'all'])
                                  ChoiceChip(
                                    label: Text(
                                      {
                                        'week': 'This week',
                                        'today': 'Today',
                                        'all': 'All time',
                                      }[f]!,
                                    ),
                                    selected: filter == f,
                                    onSelected: (_) =>
                                        setState(() => filter = f),
                                  ),
                              ],
                            ),
                            if (shown.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 30),
                                child: Text(
                                  'Start the timer or add work you’ve already done.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            for (final e in shown)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(e.task),
                                subtitle: Text(
                                  '${e.project} · ${MaterialLocalizations.of(context).formatShortDate(e.start)}\n${TimeOfDay.fromDateTime(e.start).format(context)} – ${TimeOfDay.fromDateTime(e.end!).format(context)}',
                                ),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(hours(e.end!.difference(e.start))),
                                    IconButton(
                                      tooltip: 'Delete entry',
                                      onPressed: () => remove(e),
                                      icon: const Icon(Icons.close, size: 20),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: calculateMonth,
                        icon: const Icon(Icons.calculate_outlined),
                        label: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Calculate month'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Saved on this device · Export to keep a backup',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                    ],
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
  final task = TextEditingController(), project = TextEditingController();
  DateTime day = DateTime.now();
  TimeOfDay start = const TimeOfDay(hour: 9, minute: 0),
      end = const TimeOfDay(hour: 10, minute: 0);
  String? error;
  @override
  void dispose() {
    task.dispose();
    project.dispose();
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
          TextField(
            controller: task,
            decoration: const InputDecoration(labelText: 'Task'),
          ),
          TextField(
            controller: project,
            decoration: const InputDecoration(
              labelText: 'Project',
              hintText: 'General',
            ),
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
                  () => error = 'Enter a task and an end time after the start.',
                );
                return;
              }
              Navigator.pop(
                context,
                Entry(
                  task.text.trim(),
                  project.text.trim().isEmpty ? 'General' : project.text.trim(),
                  a,
                  b,
                ),
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
