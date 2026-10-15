import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worktime/expenses.dart';
import 'package:worktime/backup.dart';
import 'package:worktime/bank_details.dart';
import 'package:worktime/monthly_report.dart';

void main() {
  test('Amounts accept comma and dot without rounding invalid input', () {
    expect(parseExpenseCents('12,35'), 1235);
    expect(parseExpenseCents('0.01'), 1);
    expect(parseExpenseCents('12.3'), 1230);
    for (final value in ['0', '-1', '1.234', 'NaN', 'abc', '']) {
      expect(parseExpenseCents(value), isNull);
    }
  });
  test('Backup retains expenses and reads old backups', () {
    final backup = WorktimeBackup([], null, const BankDetails(), [
      Expense('Zugticket', DateTime(2026, 10, 15), 1235),
    ]);
    expect(WorktimeBackup.decode(backup.encode()).data, backup.data);
    final old = jsonDecode(backup.encode());
    old['data'].remove('expenses');
    expect(WorktimeBackup.decode(jsonEncode(old)).expenses, isEmpty);
    old['data']['expenses'] = [
      {'description': 'Bad', 'date': '2026-10-15', 'cents': -1},
    ];
    expect(() => WorktimeBackup.decode(jsonEncode(old)), throwsFormatException);
  });
  test('Monthly Excel includes only selected month and exact total', () {
    final expenses = [
      Expense('Zugticket', DateTime(2026, 10, 15), 1235),
      Expense('Material', DateTime(2026, 10, 16), 100),
      Expense('Previous', DateTime(2026, 9, 30), 900),
    ];
    final book = Excel.decodeBytes(
      monthlyWorkbook([], DateTime(2026, 10), expenses: expenses),
    );
    expect(book.tables.keys, ['Worktime']);
    final rows = book['Worktime'].rows;
    expect(rows.any((r) => r.first?.value?.toString() == 'Previous'), isFalse);
    final total = rows.firstWhere(
      (r) => r.first?.value?.toString() == 'Total Spesen',
    );
    expect((total[4]!.value as DoubleCellValue).value, 13.35);
  });
  testWidgets('Editor validates and saves an expense', (tester) async {
    Expense? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<Expense>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const ExpenseEditor(),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spesen speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Beschreibung eingeben.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Zugticket');
    await tester.enterText(find.byType(TextFormField).at(1), '12,35');
    await tester.ensureVisible(find.text('Spesen speichern'));
    await tester.tap(find.text('Spesen speichern'));
    await tester.pumpAndSettle();
    expect(result?.cents, 1235);
    expect(result?.description, 'Zugticket');
  });
}
