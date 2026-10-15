import 'dart:typed_data';

import 'package:excel/excel.dart' as xlsx;

import 'models.dart';
import 'expenses.dart';
import 'report_analysis.dart';
import 'bank_details.dart';

String _two(int n) => n.toString().padLeft(2, '0');
String _period(DateTime d) => '${d.year}-${_two(d.month)}';
String _date(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}';
String _stamp(DateTime d) => '${_date(d)} ${_two(d.hour)}:${_two(d.minute)}';
double _decimal(Duration d) => d.inMicroseconds / 3600000000;
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
  List<Expense> expenses = const [],
}) => monthlyReportFromAnalysis(
  MonthlyAnalysis(entries, month, asOf: asOf),
  bankDetails: bankDetails,
  expenses: expenses,
);

String monthlyReportFromAnalysis(
  MonthlyAnalysis a, {
  BankDetails bankDetails = const BankDetails(),
  List<Expense> expenses = const [],
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
  if (expensesForMonth(expenses, a.month).isNotEmpty) ...[
    'Spesen',
    ...expensesForMonth(expenses, a.month).map(
      (e) =>
          '${_date(e.date)} | ${_clean(e.description)} | ${expenseAmount(e.cents)}',
    ),
    'Total Spesen: ${expenseAmount(expensesForMonth(expenses, a.month).fold<int>(0, (sum, e) => sum + e.cents))}',
    '',
  ],
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
        '${_review(r).isEmpty ? '' : ' · ${_review(r)}'}',
  ),
  '',
  'Completed sessions only. Times are clipped to the selected month; daily and weekly totals split at local midnight. Overlapping sessions remain in recorded totals.',
].join('\n');

Uint8List monthlyWorkbook(
  List<Entry> entries,
  DateTime month, {
  DateTime? asOf,
  BankDetails bankDetails = const BankDetails(),
  List<Expense> expenses = const [],
}) => monthlyWorkbookFromAnalysis(
  MonthlyAnalysis(entries, month, asOf: asOf),
  bankDetails: bankDetails,
  expenses: expenses,
);

Uint8List monthlyWorkbookFromAnalysis(
  MonthlyAnalysis analysis, {
  BankDetails bankDetails = const BankDetails(),
  List<Expense> expenses = const [],
}) {
  final book = xlsx.Excel.createExcel()..rename('Sheet1', 'Worktime');
  final sheet = book['Worktime'];
  sheet.appendRow([_text('Worktime · ${_period(analysis.month)}')]);
  sheet.appendRow([_text('')]);
  sheet.appendRow(
    ['Task', 'Category', 'From', 'To', 'Hours worked'].map(_text).toList(),
  );
  for (final row in analysis.rows) {
    sheet.appendRow([
      _text(row.entry.task),
      _text(row.category),
      xlsx.DateTimeCellValue.fromDateTime(row.start),
      xlsx.DateTimeCellValue.fromDateTime(row.end),
      xlsx.DoubleCellValue(_decimal(row.duration)),
    ]);
    for (final col in [2, 3]) {
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
  final categoryHeader = sheet.maxRows;
  sheet.appendRow([
    _text('Category totals'),
    null,
    null,
    null,
    _text('Hours worked'),
  ]);
  for (final category in analysis.categories) {
    sheet.appendRow([
      _text(category.category),
      null,
      null,
      null,
      xlsx.DoubleCellValue(_decimal(category.total)),
    ]);
  }
  final totalRow = sheet.maxRows;
  sheet.appendRow([
    _text('Total time worked'),
    null,
    null,
    null,
    xlsx.DoubleCellValue(_decimal(analysis.total)),
  ]);
  for (var row = 3; row <= totalRow; row++) {
    final cell = sheet.cell(
      xlsx.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
    );
    if (cell.value is xlsx.DoubleCellValue) {
      cell.cellStyle = xlsx.CellStyle(
        numberFormat: xlsx.CustomNumericNumFormat(formatCode: '0.00'),
      );
    }
  }
  final headers = [0, 2, categoryHeader, totalRow];
  if (!bankDetails.isEmpty) {
    sheet.appendRow([_text('')]);
    headers.add(sheet.maxRows);
    sheet.appendRow([_text('Bank details')]);
    for (final (label, value) in bankDetails.fields) {
      sheet.appendRow([_text(label), _text(value)]);
      final row = sheet.maxRows - 1;
      sheet.merge(
        xlsx.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
        xlsx.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
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
  // Keep exported values and row positions stable while styling the report.
  final navy = xlsx.ExcelColor.fromHexString('162536');
  final ink = xlsx.ExcelColor.fromHexString('243649');
  final muted = xlsx.ExcelColor.fromHexString('65788B');
  final pale = xlsx.ExcelColor.fromHexString('F2F6FA');
  final cyan = xlsx.ExcelColor.fromHexString('DDF2F5');
  final white = xlsx.ExcelColor.fromHexString('FFFFFF');
  final rule = xlsx.Border(
    borderStyle: xlsx.BorderStyle.Thin,
    borderColorHex: xlsx.ExcelColor.fromHexString('DCE4EC'),
  );

  for (var row = 0; row < sheet.maxRows; row++) {
    sheet.setRowHeight(row, 28);
    for (var col = 0; col < 5; col++) {
      final cell = sheet.cell(
        xlsx.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
      );
      cell.cellStyle = (cell.cellStyle ?? xlsx.CellStyle()).copyWith(
        bottomBorderVal: row >= 3 && row < categoryHeader - 1 ? rule : null,
        fontFamilyVal: 'Calibri',
        fontSizeVal: 11,
        fontColorHexVal: col == 2 || col == 3 ? muted : ink,
        verticalAlignVal: xlsx.VerticalAlign.Center,
        horizontalAlignVal: col == 4
            ? xlsx.HorizontalAlign.Right
            : xlsx.HorizontalAlign.Left,
        backgroundColorHexVal: row >= 3 && row < categoryHeader - 1 && row.isOdd
            ? pale
            : white,
        textWrappingVal: col <= 1
            ? xlsx.TextWrapping.WrapText
            : xlsx.TextWrapping.Clip,
      );
    }
    if (row >= 3 && row < categoryHeader - 1) {
      final entry = analysis.rows[row - 3].entry;
      // Estimate wrapped lines so long descriptions remain visible.
      int lines(String text, int width) => text
          .split('\n')
          .fold(
            0,
            (sum, line) => sum + ((line.length / width).ceil().clamp(1, 100)),
          );
      final lineCount = [
        lines(entry.task, 38),
        lines(entry.category ?? '', 26),
      ].reduce((a, b) => a > b ? a : b);
      sheet.setRowHeight(row, (lineCount * 15 + 14).toDouble());
    }
  }
  sheet.merge(
    xlsx.CellIndex.indexByString('A1'),
    xlsx.CellIndex.indexByString('E1'),
  );
  sheet.setRowHeight(0, 48);
  sheet.setRowHeight(1, 12);
  sheet.setRowHeight(categoryHeader - 1, 12);
  for (final row in headers) {
    final dark = row == 0 || row == 2;
    sheet.setRowHeight(row, row == 0 ? 48 : 34);
    for (var col = 0; col < 5; col++) {
      final cell = sheet.cell(
        xlsx.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
      );
      cell.cellStyle = (cell.cellStyle ?? xlsx.CellStyle()).copyWith(
        boldVal: true,
        fontSizeVal: row == 0
            ? 20
            : row == totalRow
            ? 13
            : 11,
        fontColorHexVal: dark ? white : ink,
        backgroundColorHexVal: dark ? navy : cyan,
      );
    }
  }
  // Summary labels span the unused columns, leaving the hours column clear.
  for (var row = categoryHeader; row <= totalRow; row++) {
    sheet.merge(
      xlsx.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      xlsx.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row),
    );
  }
  // Strong grand total, restrained category section, and readable bank footer.
  for (var col = 0; col < 5; col++) {
    final cell = sheet.cell(
      xlsx.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: totalRow),
    );
    cell.cellStyle = (cell.cellStyle ?? xlsx.CellStyle()).copyWith(
      backgroundColorHexVal: navy,
      fontColorHexVal: white,
      topBorderVal: rule,
      boldVal: true,
    );
  }
  sheet.setRowHeight(totalRow, 40);
  for (var row = categoryHeader + 1; row < totalRow; row++) {
    sheet.setRowHeight(row, 30);
    for (final col in [0, 4]) {
      final cell = sheet.cell(
        xlsx.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
      );
      cell.cellStyle = (cell.cellStyle ?? xlsx.CellStyle()).copyWith(
        bottomBorderVal: rule,
      );
    }
  }
  if (!bankDetails.isEmpty) {
    final bankHeader = headers.last;
    sheet.merge(
      xlsx.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: bankHeader),
      xlsx.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: bankHeader),
    );
    sheet.setRowHeight(bankHeader - 1, 18);
    for (var row = bankHeader + 1; row < sheet.maxRows; row++) {
      final label = sheet.cell(
        xlsx.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      );
      final value = sheet.cell(
        xlsx.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
      );
      label.cellStyle = (label.cellStyle ?? xlsx.CellStyle()).copyWith(
        boldVal: true,
        fontColorHexVal: muted,
      );
      value.cellStyle = (value.cellStyle ?? xlsx.CellStyle()).copyWith(
        textWrappingVal: xlsx.TextWrapping.WrapText,
      );
      final field = bankDetails.fields[row - bankHeader - 1];
      final lines = field.$2
          .split('\n')
          .fold<int>(
            0,
            (sum, line) => sum + (line.length / 115).ceil().clamp(1, 100),
          );
      sheet.setRowHeight(row, (lines * 15 + 15).toDouble());
    }
  }
  sheet.setColumnWidth(0, 42);
  sheet.setColumnWidth(1, 30);
  for (final col in [2, 3]) {
    sheet.setColumnWidth(col, 24);
  }
  sheet.setColumnWidth(4, 20);
  final monthExpenses = expensesForMonth(expenses, analysis.month);
  if (monthExpenses.isNotEmpty) {
    sheet.appendRow([_text('')]);
    sheet.appendRow([
      _text('Spesen'),
      _text('Datum'),
      null,
      null,
      _text('Betrag (CHF)'),
    ]);
    for (final expense in monthExpenses) {
      sheet.appendRow([
        _text(expense.description),
        _text(_date(expense.date)),
        null,
        null,
        xlsx.DoubleCellValue(expense.cents / 100),
      ]);
    }
    sheet.appendRow([
      _text('Total Spesen'),
      null,
      null,
      null,
      xlsx.DoubleCellValue(
        monthExpenses.fold<int>(0, (sum, e) => sum + e.cents) / 100,
      ),
    ]);
    for (
      var row = sheet.maxRows - monthExpenses.length - 1;
      row < sheet.maxRows;
      row++
    ) {
      sheet
          .cell(xlsx.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
          .cellStyle = xlsx.CellStyle(
        numberFormat: xlsx.CustomNumericNumFormat(formatCode: '0.00'),
      );
      sheet
          .cell(xlsx.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .cellStyle = xlsx.CellStyle(
        textWrapping: xlsx.TextWrapping.WrapText,
      );
    }
  }
  book.setDefaultSheet('Worktime');
  return Uint8List.fromList(book.encode()!);
}

xlsx.TextCellValue _text(String value) => xlsx.TextCellValue(value);
