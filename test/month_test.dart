import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart' as xlsx;
import 'package:worktime/models.dart';
import 'package:worktime/monthly_report.dart';
import 'package:worktime/report_analysis.dart';
import 'package:worktime/bank_details.dart';

double numericValue(xlsx.CellValue? value) => switch (value) {
  xlsx.IntCellValue() => value.value.toDouble(),
  xlsx.DoubleCellValue() => value.value,
  _ => throw StateError('Expected numeric Excel cell, got $value'),
};

List<xlsx.Data?> rowByLabel(xlsx.Sheet sheet, String label) => sheet.rows
    .firstWhere((row) => row.first?.value == xlsx.TextCellValue(label));

int rowIndexByLabel(xlsx.Sheet sheet, String label) => sheet.rows.indexWhere(
  (row) => row.first?.value == xlsx.TextCellValue(label),
);

void main() {
  test('Bank details survive storage and remain text in reports', () {
    const details = BankDetails(
      accountHolder: 'Example Account Holder',
      bankName: 'Example Bank',
      accountNumber: 'CH00 0000 0000 0000 0000 0',
      country: 'Switzerland',
      currency: 'CHF',
      bic: 'EXAMPLEXXX',
    );
    final restored = BankDetails.fromJson(details.toJson());
    final month = DateTime(2026, 10);
    final text = monthlyReport([], month, bankDetails: restored);
    final book = xlsx.Excel.decodeBytes(
      monthlyWorkbook([], month, bankDetails: restored),
    );
    final sheet = book['Worktime'];
    final totalIndex = rowIndexByLabel(sheet, 'Total time worked');
    expect(
      sheet.rows[totalIndex + 2][0]!.value,
      xlsx.TextCellValue('Bank details'),
    );
    for (final (label, value) in details.fields) {
      expect(text, contains('$label: $value'));
      final row = rowByLabel(sheet, label);
      expect(row[1]!.value, xlsx.TextCellValue(value));
      final number = rowIndexByLabel(sheet, label) + 1;
      expect(sheet.spannedItems, contains('B$number:F$number'));
    }
    final cleared = BankDetails.fromJson(const BankDetails().toJson());
    expect(cleared.isEmpty, isTrue);
    expect(
      monthlyReport([], month, bankDetails: cleared),
      isNot(contains('Bank details')),
    );
    final clearedBook = xlsx.Excel.decodeBytes(
      monthlyWorkbook([], month, bankDetails: cleared),
    );
    expect(
      clearedBook['Worktime'].rows
          .expand((row) => row)
          .map((cell) => cell?.value),
      isNot(contains(xlsx.TextCellValue('Bank details'))),
    );
  });
  test('Legacy entries without a category still load and serialize', () {
    final legacy = {
      'task': 'Client call',
      'project': 'Consulting',
      'start': DateTime(2026, 10, 5, 9).toIso8601String(),
      'end': DateTime(2026, 10, 5, 12).toIso8601String(),
    };
    final entry = Entry.fromJson(legacy);
    expect(entry.task, 'Client call');
    expect(entry.project, 'Consulting');
    expect(entry.category, isNull);
    expect(entry.toJson(), legacy);
    expect(monthlyTotal([entry], DateTime(2026, 10)), const Duration(hours: 3));
  });

  test('Category roundtrip preserves a separate task description', () {
    final entry = Entry(
      'Tighten rear brake cable',
      'Customer bicycle',
      DateTime(2026, 10, 5, 9),
      DateTime(2026, 10, 5, 10),
      'Bike Repair',
    );
    final restored = Entry.fromJson(entry.toJson());
    expect(restored.task, 'Tighten rear brake cable');
    expect(restored.category, 'Bike Repair');
    expect(restored.project, entry.project);
    expect(restored.start, entry.start);
    expect(restored.end, entry.end);
  });

  test('Monthly total clips boundaries and excludes running work', () {
    final entries = [
      Entry(
        'Previous month',
        'General',
        DateTime(2026, 9, 30, 23),
        DateTime(2026, 10, 1, 2),
        'Project Work',
      ),
      Entry(
        'This month',
        'General',
        DateTime(2026, 10, 12, 9),
        DateTime(2026, 10, 12, 14),
      ),
      Entry(
        'Next month',
        'General',
        DateTime(2026, 10, 31, 23),
        DateTime(2026, 11, 1, 2),
      ),
      Entry('Running', 'General', DateTime(2026, 10, 12, 15)),
    ];
    expect(monthlyTotal(entries, DateTime(2026, 10)), const Duration(hours: 8));
    expect(monthlyTotal([], DateTime(2026, 12)), Duration.zero);
  });
  test(
    'Text report summarizes categories and keeps completed task details',
    () {
      final report = monthlyReport(
        [
          Entry(
            'Boundary task',
            'Design',
            DateTime(2026, 9, 30, 23),
            DateTime(2026, 10, 1, 2),
            'Project Work',
          ),
          Entry(
            'Client call',
            'Consulting',
            DateTime(2026, 10, 5, 9),
            DateTime(2026, 10, 5, 12),
          ),
          Entry(
            'Layout',
            'Design',
            DateTime(2026, 10, 6, 9),
            DateTime(2026, 10, 6, 10),
          ),
          Entry('Active', 'Design', DateTime(2026, 10, 7)),
        ],
        DateTime(2026, 10),
        asOf: DateTime(2026, 11),
      );
      expect(report, contains('Total time worked: 6h 00m'));
      expect(report, contains('Category totals'));
      expect(report, contains('Project Work'));
      expect(report, contains('Uncategorized'));
      expect(report, contains('Task | Category | From | To | Time worked'));
      expect(report, contains('Boundary task | Project Work |'));
      expect(report, isNot(contains('Category | Project |')));
      expect(report, contains('01.10.2026 00:00'));
      for (final task in ['Boundary task', 'Client call', 'Layout']) {
        expect(report, contains('$task |'));
      }
      expect(report, isNot(contains('Active |')));
      expect(monthlyReport([], DateTime(2026, 10)), contains('No entries.'));
    },
  );
  test(
    'Excel keeps the original Worktime layout and saved project information',
    () {
      final month = DateTime(2026, 10);
      final entries = [
        Entry(
          'Overnight repair',
          'General',
          DateTime(2026, 10, 6, 23),
          DateTime(2026, 10, 7, 1),
          'Bike Repair',
        ),
        Entry.fromJson({
          'task': 'Meeting',
          'project': 'Website',
          'start': DateTime(2026, 10, 5, 9).toIso8601String(),
          'end': DateTime(2026, 10, 5, 10).toIso8601String(),
        }),
        Entry(
          'Design task',
          'Website',
          DateTime(2026, 9, 30, 23),
          DateTime(2026, 10, 1, 2),
          'Project Work',
        ),
        Entry('Running', 'Other', DateTime(2026, 10, 5, 11)),
      ];
      final bytes = monthlyWorkbook(entries, month, asOf: DateTime(2026, 11));
      final book = xlsx.Excel.decodeBytes(bytes);
      expect(book.tables.keys, ['Worktime']);
      final sheet = book['Worktime'];
      expect(sheet.maxColumns, 6);
      expect(sheet.rows[0][0]!.value, xlsx.TextCellValue('Worktime · 2026-10'));
      expect(sheet.rows[1][0]!.value, xlsx.TextCellValue(''));
      expect(
        sheet.rows[2].map((cell) => cell?.value),
        [
          'Task',
          'Category',
          'Project',
          'From',
          'To',
          'Hours worked',
        ].map(xlsx.TextCellValue.new),
      );
      expect(
        sheet.rows.sublist(3, 6).map((row) => row[0]!.value),
        [
          'Design task',
          'Meeting',
          'Overnight repair',
        ].map(xlsx.TextCellValue.new),
      );
      expect(sheet.rows[3][1]!.value, xlsx.TextCellValue('Project Work'));
      expect(sheet.rows[3][2]!.value, xlsx.TextCellValue('Website'));
      expect(
        sheet.rows[3][3]!.value,
        xlsx.DateCellValue(year: 2026, month: 10, day: 1),
      );
      expect(
        sheet.rows[3][4]!.value,
        xlsx.DateTimeCellValue.fromDateTime(DateTime(2026, 10, 1, 2)),
      );
      expect(sheet.rows[4][1]!.value, xlsx.TextCellValue(''));
      expect(sheet.rows[4][2]!.value, xlsx.TextCellValue('Website'));
      expect(sheet.rows[5][1]!.value, xlsx.TextCellValue('Bike Repair'));
      expect(sheet.rows[5][2]!.value, xlsx.TextCellValue('General'));
      expect(
        sheet.rows.sublist(3, 6).map((row) => numericValue(row[5]!.value)),
        [2, 1, 2],
      );
      expect(sheet.rows[6][0]!.value, xlsx.TextCellValue(''));
      expect(sheet.rows[7][0]!.value, xlsx.TextCellValue('Project totals'));
      expect(sheet.rows[7][5]!.value, xlsx.TextCellValue('Hours worked'));
      expect(
        sheet.rows.sublist(8, 10).map((row) => row[0]!.value),
        ['General', 'Website'].map(xlsx.TextCellValue.new),
      );
      expect(numericValue(rowByLabel(sheet, 'General')[5]!.value), 2);
      expect(numericValue(rowByLabel(sheet, 'Website')[5]!.value), 3);
      expect(numericValue(rowByLabel(sheet, 'Total time worked')[5]!.value), 5);
      expect(
        sheet.rows.expand((row) => row).map((cell) => cell?.value),
        isNot(contains(xlsx.TextCellValue('Running'))),
      );
    },
  );

  test('Excel clips both month boundaries and excludes invalid sessions', () {
    final month = DateTime(2026, 10);
    final entries = [
      Entry(
        'Start boundary',
        'Client',
        DateTime(2026, 9, 30, 23),
        DateTime(2026, 10, 1, 2),
      ),
      Entry(
        'End boundary',
        'Client',
        DateTime(2026, 10, 31, 23),
        DateTime(2026, 11, 1, 2),
      ),
      Entry(
        'Before month',
        'Client',
        DateTime(2026, 9, 30, 23),
        DateTime(2026, 10, 1),
      ),
      Entry(
        'After month',
        'Client',
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 1, 1),
      ),
      Entry(
        'Zero duration',
        'Client',
        DateTime(2026, 10, 3, 9),
        DateTime(2026, 10, 3, 9),
      ),
      Entry(
        'Reversed',
        'Client',
        DateTime(2026, 10, 4, 10),
        DateTime(2026, 10, 4, 9),
      ),
      Entry('Running', 'Client', DateTime(2026, 10, 5)),
    ];
    final sheet = xlsx.Excel.decodeBytes(
      monthlyWorkbook(entries, month),
    )['Worktime'];
    expect(
      sheet.rows.sublist(3, 5).map((row) => row[0]!.value),
      ['Start boundary', 'End boundary'].map(xlsx.TextCellValue.new),
    );
    expect(
      sheet.rows[3][3]!.value,
      xlsx.DateCellValue(year: 2026, month: 10, day: 1),
    );
    expect(
      sheet.rows[4][4]!.value,
      xlsx.DateCellValue(year: 2026, month: 11, day: 1),
    );
    expect(numericValue(sheet.rows[3][5]!.value), 2);
    expect(numericValue(sheet.rows[4][5]!.value), 1);
    expect(numericValue(rowByLabel(sheet, 'Client')[5]!.value), 3);
    expect(numericValue(rowByLabel(sheet, 'Total time worked')[5]!.value), 3);
    final values = sheet.rows.expand((row) => row).map((cell) => cell?.value);
    for (final task in [
      'Before month',
      'After month',
      'Zero duration',
      'Reversed',
      'Running',
    ]) {
      expect(values, isNot(contains(xlsx.TextCellValue(task))));
    }
  });

  test('Empty Excel report retains headers and a numeric zero grand total', () {
    final book = xlsx.Excel.decodeBytes(
      monthlyWorkbook([], DateTime(2026, 10), asOf: DateTime(2026, 11)),
    );
    expect(book.tables.keys, ['Worktime']);
    final sheet = book['Worktime'];
    expect(
      sheet.rows[2].map((cell) => cell?.value),
      [
        'Task',
        'Category',
        'Project',
        'From',
        'To',
        'Hours worked',
      ].map(xlsx.TextCellValue.new),
    );
    expect(sheet.rows[3][0]!.value, xlsx.TextCellValue(''));
    expect(sheet.rows[4][0]!.value, xlsx.TextCellValue('Project totals'));
    expect(sheet.rows[5][0]!.value, xlsx.TextCellValue('Total time worked'));
    expect(numericValue(sheet.rows[5][5]!.value), 0);
    expect(sheet.maxRows, 6);
  });

  test('Excel bank values remain exact text and omit empty fields', () {
    const details = BankDetails(
      accountNumber: '001234567890',
      bankName: '  Example Bank  ',
      accountHolder: '=Example account holder',
      currency: '   ',
    );
    final sheet = xlsx.Excel.decodeBytes(
      monthlyWorkbook([], DateTime(2026, 10), bankDetails: details),
    )['Worktime'];
    expect(
      rowByLabel(sheet, 'IBAN / Account number')[1]!.value,
      xlsx.TextCellValue('001234567890'),
    );
    expect(
      rowByLabel(sheet, 'Account holder')[1]!.value,
      xlsx.TextCellValue('=Example account holder'),
    );
    expect(
      rowByLabel(sheet, 'Bank')[1]!.value,
      xlsx.TextCellValue('Example Bank'),
    );
    expect(
      sheet.rows
          .skip(rowIndexByLabel(sheet, 'Bank details') + 1)
          .map((row) => row[0]!.value),
      [
        'Account holder',
        'Bank',
        'IBAN / Account number',
      ].map(xlsx.TextCellValue.new),
    );
  });

  test('Export from the app analysis preserves the original workbook data', () {
    final entries = [
      Entry(
        'Finished task',
        'Saved project',
        DateTime(2026, 10, 5, 9),
        DateTime(2026, 10, 5, 10, 30),
        'Project Work',
      ),
    ];
    final month = DateTime(2026, 10);
    final asOf = DateTime(2026, 10, 12);
    const details = BankDetails(accountNumber: 'CH00 0000 0000');
    final prepared = xlsx.Excel.decodeBytes(
      monthlyWorkbookFromAnalysis(
        MonthlyAnalysis(entries, month, asOf: asOf),
        bankDetails: details,
      ),
    );
    final direct = xlsx.Excel.decodeBytes(
      monthlyWorkbook(entries, month, asOf: asOf, bankDetails: details),
    );
    expect(prepared.tables.keys, direct.tables.keys);
    expect(
      prepared['Worktime'].rows.map((row) => row.map((cell) => cell?.value)),
      direct['Worktime'].rows.map((row) => row.map((cell) => cell?.value)),
    );
    expect(
      numericValue(
        rowByLabel(prepared['Worktime'], 'Total time worked')[5]!.value,
      ),
      1.5,
    );
  });
}
