import 'dart:typed_data';

import 'package:excel/excel.dart' as xlsx;

import 'models.dart';
import 'report_analysis.dart';
import 'bank_details.dart';

String _two(int n) => n.toString().padLeft(2, '0');
String _period(DateTime d) => '${d.year}-${_two(d.month)}';
String _date(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}';
String _stamp(DateTime d) => '${_date(d)} ${_two(d.hour)}:${_two(d.minute)}';
double _decimal(Duration d) => d.inMicroseconds / 3600000000;
bool _legacyProject(Entry e) =>
    e.project.trim().isNotEmpty && e.project.trim() != 'General';
String _clean(String value) => value.replaceAll(RegExp(r'[\r\n\t|]+'), ' ');

String _review(AnalyzedEntry row) => [
  ...row.flags,
  if (row.start != row.entry.start.toLocal() ||
      row.end != row.entry.end!.toLocal())
    'Clipped to month; original ${_stamp(row.entry.start.toLocal())}–${_stamp(row.entry.end!.toLocal())}',
].join('; ');

String monthlyReport(
  List<Entry> entries,
  DateTime month, {
  DateTime? asOf,
  BankDetails bankDetails = const BankDetails(),
}) => monthlyReportFromAnalysis(
  MonthlyAnalysis(entries, month, asOf: asOf),
  bankDetails: bankDetails,
);

String monthlyReportFromAnalysis(
  MonthlyAnalysis a, {
  BankDetails bankDetails = const BankDetails(),
}) => [
  _period(a.month),
  'Generated: ${_stamp(a.asOf)} (local time)',
  '',
  'Total time worked: ${hours(a.total)}',
  '${a.sessionCount} sessions · ${a.activeDays} active days',
  'Average session: ${hours(a.averageSession)}',
  'Average active day: ${hours(a.averageActiveDay)}',
  'Longest session in month: ${hours(a.longestSession)}',
  '',
  'Category totals',
  ...a.categories.map(
    (c) =>
        '${_clean(c.category)}: ${hours(c.total)} · ${(c.share * 100).toStringAsFixed(1)}% · ${c.sessionCount} sessions',
  ),
  '',
  a.comparisonLabel,
  'Selected period: ${hours(a.comparisonTotal)} · Previous period: ${hours(a.comparisonPreviousTotal)}',
  a.goalLabel,
  'Target: ${hours(a.goal)}${a.isFutureMonth ? '' : ' · ${(a.goalProgress * 100).toStringAsFixed(1)}% reached'}',
  if (!bankDetails.isEmpty) ...[
    '',
    'Bank details',
    ...bankDetails.fields.map((field) => '${field.$1}: ${_clean(field.$2)}'),
  ],
  '',
  'Insights',
  ...a.insights,
  '',
  'Review checks',
  ...a.checks,
  '',
  'Task | Category | From | To | Time worked',
  if (a.rows.isEmpty) 'No entries.',
  ...a.rows.map(
    (r) =>
        '${_clean(r.entry.task)} | ${_clean(r.category)} | ${_stamp(r.start)} | ${_stamp(r.end)} | ${hours(r.duration)}'
        '${_review(r).isEmpty ? '' : ' · ${_review(r)}'}'
        '${_legacyProject(r.entry) ? ' · Legacy project: ${_clean(r.entry.project)}' : ''}',
  ),
  '',
  'Completed sessions only. Times are clipped to the selected month; daily and weekly totals split at local midnight. Overlapping sessions remain in recorded totals.',
].join('\n');

Uint8List monthlyWorkbook(
  List<Entry> entries,
  DateTime month, {
  DateTime? asOf,
  BankDetails bankDetails = const BankDetails(),
}) => monthlyWorkbookFromAnalysis(
  MonthlyAnalysis(entries, month, asOf: asOf),
  bankDetails: bankDetails,
);

Uint8List monthlyWorkbookFromAnalysis(
  MonthlyAnalysis analysis, {
  BankDetails bankDetails = const BankDetails(),
}) {
  final book = xlsx.Excel.createExcel()..rename('Sheet1', 'Worktime');
  final sheet = book['Worktime'];
  sheet.appendRow([_text('Worktime · ${_period(analysis.month)}')]);
  sheet.appendRow([_text('')]);
  sheet.appendRow(
    [
      'Task',
      'Category',
      'Project',
      'From',
      'To',
      'Hours worked',
    ].map(_text).toList(),
  );
  final projects = <String, Duration>{};
  for (final row in analysis.rows) {
    projects.update(
      row.entry.project,
      (value) => value + row.duration,
      ifAbsent: () => row.duration,
    );
    sheet.appendRow([
      _text(row.entry.task),
      _text(row.entry.category ?? ''),
      _text(row.entry.project),
      xlsx.DateTimeCellValue.fromDateTime(row.start),
      xlsx.DateTimeCellValue.fromDateTime(row.end),
      xlsx.DoubleCellValue(_decimal(row.duration)),
    ]);
    for (final col in [3, 4]) {
      sheet
          .cell(
            xlsx.CellIndex.indexByColumnRow(
              columnIndex: col,
              rowIndex: sheet.maxRows - 1,
            ),
          )
          .cellStyle = xlsx.CellStyle(
        numberFormat: xlsx.CustomDateTimeNumFormat(
          formatCode: 'dd.mm.yyyy hh:mm',
        ),
      );
    }
  }
  sheet.appendRow([_text('')]);
  final projectHeader = sheet.maxRows;
  sheet.appendRow([
    _text('Project totals'),
    null,
    null,
    null,
    null,
    _text('Hours worked'),
  ]);
  final names = projects.keys.toList()..sort();
  for (final name in names) {
    sheet.appendRow([
      _text(name),
      null,
      null,
      null,
      null,
      xlsx.DoubleCellValue(_decimal(projects[name]!)),
    ]);
  }
  final totalRow = sheet.maxRows;
  sheet.appendRow([
    _text('Total time worked'),
    null,
    null,
    null,
    null,
    xlsx.DoubleCellValue(_decimal(analysis.total)),
  ]);
  for (var row = 3; row <= totalRow; row++) {
    final cell = sheet.cell(
      xlsx.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row),
    );
    if (cell.value is xlsx.DoubleCellValue) {
      cell.cellStyle = xlsx.CellStyle(
        numberFormat: xlsx.CustomNumericNumFormat(formatCode: '0.00'),
      );
    }
  }
  final headers = [0, 2, projectHeader, totalRow];
  if (!bankDetails.isEmpty) {
    sheet.appendRow([_text('')]);
    headers.add(sheet.maxRows);
    sheet.appendRow([_text('Bank details')]);
    for (final (label, value) in bankDetails.fields) {
      sheet.appendRow([_text(label), _text(value)]);
      final row = sheet.maxRows - 1;
      sheet.merge(
        xlsx.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
        xlsx.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row),
      );
      sheet.setRowHeight(row, 30);
      for (final col in [0, 1]) {
        sheet
            .cell(
              xlsx.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
            )
            .cellStyle = xlsx.CellStyle(
          bold: col == 0,
          textWrapping: xlsx.TextWrapping.WrapText,
          verticalAlign: xlsx.VerticalAlign.Center,
        );
      }
    }
  }
  for (final row in headers) {
    for (var col = 0; col < 6; col++) {
      final cell = sheet.cell(
        xlsx.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
      );
      cell.cellStyle = (cell.cellStyle ?? xlsx.CellStyle()).copyWith(
        boldVal: true,
        backgroundColorHexVal: xlsx.ExcelColor.fromHexString('E9EFDF'),
      );
    }
  }
  for (final col in [0, 1, 2]) {
    sheet.setColumnWidth(col, 30);
  }
  for (final col in [3, 4]) {
    sheet.setColumnWidth(col, 23);
  }
  sheet.setColumnWidth(5, 18);
  book.setDefaultSheet('Worktime');
  return Uint8List.fromList(book.encode()!);
}

xlsx.TextCellValue _text(String value) => xlsx.TextCellValue(value);
