import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart' as xlsx;
import 'package:worktime/main.dart';

void main() {
  test('Monthly total clips boundaries and excludes running work', () {
    final entries = [
      Entry(
        'Previous month',
        'General',
        DateTime(2026, 9, 30, 23),
        DateTime(2026, 10, 1, 2),
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
  test('Text report includes projects, all entries, and correct totals', () {
    final report = monthlyReport([
      Entry(
        'Boundary task',
        'Design',
        DateTime(2026, 9, 30, 23),
        DateTime(2026, 10, 1, 2),
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
    ], DateTime(2026, 10));
    expect(report, contains('Total time worked: 6h 00m'));
    expect(report, contains('Design total: 3h 00m'));
    expect(report, contains('Consulting total: 3h 00m'));
    expect(report, contains('01.10.2026 00:00'));
    for (final task in ['Boundary task', 'Client call', 'Layout']) {
      expect(report, contains('$task |'));
    }
    expect(report, isNot(contains('Active |')));
    expect(monthlyReport([], DateTime(2026, 10)), contains('No entries.'));
  });
  test('Excel roundtrip preserves dates, project totals and numeric hours', () {
    final bytes = monthlyWorkbook([
      Entry(
        'Design task',
        'Website',
        DateTime(2026, 9, 30, 23),
        DateTime(2026, 10, 1, 2),
      ),
      Entry(
        'Meeting',
        'Website',
        DateTime(2026, 10, 5, 9),
        DateTime(2026, 10, 5, 10),
      ),
      Entry('Running', 'Other', DateTime(2026, 10, 5, 11)),
    ], DateTime(2026, 10));
    final sheet = xlsx.Excel.decodeBytes(bytes)['Worktime'];
    expect(sheet.rows[2][0]!.value, xlsx.TextCellValue('Task'));
    expect(sheet.rows[3][4]!.value, xlsx.IntCellValue(2));
    expect(sheet.rows[3][2]!.value, xlsx.DateCellValue(year: 2026, month: 10, day: 1));
    expect(sheet.rows[4][2]!.value, isA<xlsx.DateTimeCellValue>());
    expect(sheet.rows[sheet.maxRows - 2][4]!.value, xlsx.IntCellValue(3));
    expect(sheet.rows.last[4]!.value, xlsx.IntCellValue(3));
    final empty = xlsx.Excel.decodeBytes(
      monthlyWorkbook([], DateTime(2026, 10)),
    )['Worktime'];
    expect(empty.rows.last[4]!.value, xlsx.IntCellValue(0));
  });
}
