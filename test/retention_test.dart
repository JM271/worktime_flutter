import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worktime/backup.dart';
import 'package:worktime/bank_details.dart';
import 'package:worktime/main.dart';
import 'package:worktime/retention.dart';

void main() {
  final now = DateTime(2026, 11, 6, 12);
  Entry entry(String task, DateTime start, Duration length) =>
      Entry(task, start, start.add(length), 'Bike Repair');

  test('Cutoff keeps the current month plus three full months', () {
    expect(entryRetentionCutoff(now), DateTime(2026, 8));
    expect(entryRetentionCutoff(DateTime(2026, 2, 10)), DateTime(2025, 11));
  });

  test('Only old entries that are in the confirmed backup are prunable', () {
    final old = entry(
      'Old',
      DateTime(2026, 7, 31, 9),
      const Duration(hours: 1),
    );
    final oldNotBackedUp = entry(
      'Old, edited after backup',
      DateTime(2026, 6, 3, 9),
      const Duration(hours: 1),
    );
    final spansCutoff = entry(
      'Overnight into August',
      DateTime(2026, 7, 31, 22),
      const Duration(hours: 4),
    );
    final recent = entry(
      'Recent',
      DateTime(2026, 8, 2, 9),
      const Duration(hours: 1),
    );
    final backup = jsonEncode(
      WorktimeBackup(
        [old, spansCutoff, recent],
        null,
        const BankDetails(),
      ).data,
    );
    final keys = backedUpEntryKeys(backup);

    expect(
      prunableEntries([old, oldNotBackedUp, spansCutoff, recent], keys, now),
      [old],
    );
    expect(prunableEntries([old], backedUpEntryKeys(null), now), isEmpty);
    expect(prunableEntries([old], backedUpEntryKeys('not json'), now), isEmpty);
  });

  testWidgets('Backed-up entries older than three months can be removed', (
    tester,
  ) async {
    final today = DateTime.now();
    final old = entry(
      'Old work',
      DateTime(today.year, today.month - 5, 3, 9),
      const Duration(hours: 2),
    );
    final recent = entry(
      'Recent work',
      DateTime(today.year, today.month, 1, 9),
      const Duration(hours: 1),
    );
    final data = jsonEncode(
      WorktimeBackup([old, recent], null, const BankDetails()).data,
    );
    SharedPreferences.setMockInitialValues({
      'worktime': data,
      'worktime-confirmed-backup': data,
    });

    await tester.pumpWidget(const WorktimeApp());
    await tester.pumpAndSettle();
    final button = find.text('Remove 1 backed-up entry older than 3 months');
    await tester.scrollUntilVisible(
      button,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Remove old time entries?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('worktime')!) as Map;
    expect((saved['entries'] as List).map((e) => e['task']), ['Recent work']);
    expect(
      prefs.getString('worktime-confirmed-backup'),
      jsonEncode(WorktimeBackup([recent], null, const BankDetails()).data),
    );
    expect(button, findsNothing);
    expect(find.text('Backup confirmed · up to date'), findsWidgets);
  });
}
