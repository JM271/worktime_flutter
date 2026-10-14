import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worktime/main.dart';
import 'package:worktime/backup.dart';
import 'package:worktime/bank_details.dart';

void main() {
  testWidgets('Status reflects missing, confirmed, and changed backup data', (
    tester,
  ) async {
    final original = WorktimeBackup([], null, const BankDetails());
    for (final mode in ['missing', 'confirmed', 'changed']) {
      final current = mode == 'changed'
          ? WorktimeBackup(
              [
                Entry(
                  'New work',
                  'General',
                  DateTime(2026, 10, 13, 9),
                  DateTime(2026, 10, 13, 10),
                  'Bike Repair',
                ),
              ],
              null,
              const BankDetails(),
            )
          : original;
      SharedPreferences.setMockInitialValues({
        'worktime': jsonEncode(current.data),
        if (mode != 'missing')
          'worktime-confirmed-backup': jsonEncode(original.data),
      });
      await tester.pumpWidget(const WorktimeApp());
      await tester.pumpAndSettle();
      expect(
        find.text(switch (mode) {
          'missing' => 'No confirmed backup',
          'confirmed' => 'Backup confirmed · up to date',
          _ => 'Changes since last backup',
        }),
        findsWidgets,
      );
      await tester.pumpWidget(const SizedBox());
    }
  });
}
