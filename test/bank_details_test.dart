import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worktime/bank_details.dart';
import 'package:worktime/bank_details_dialog.dart';
import 'package:worktime/main.dart';

void main() {
  testWidgets('Bank details can be edited, persisted and cleared', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const WorktimeApp());
    await tester.pumpAndSettle();

    Future<void> edit() async {
      await tester.scrollUntilVisible(
        find.text('Edit bank details'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Edit bank details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit bank details'));
      await tester.pumpAndSettle();
    }

    await edit();
    final fields = find.descendant(
      of: find.byType(BankDetailsDialog),
      matching: find.byType(TextField),
    );
    expect(fields, findsNWidgets(6));
    expect(
      tester.widget<TextField>(fields.at(0)).controller!.text,
      defaultBankDetails.accountHolder,
    );
    await tester.enterText(fields.at(0), 'Example Holder');
    await tester.enterText(fields.at(1), 'Example account 123');
    await tester.tap(find.text('Save details'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    final saved =
        jsonDecode(prefs.getString('worktime')!) as Map<String, dynamic>;
    expect(saved['bankDetails']['accountHolder'], 'Example Holder');
    expect(saved['bankDetails']['accountNumber'], 'Example account 123');
    expect(saved['entries'], isEmpty);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const WorktimeApp());
    await tester.pumpAndSettle();
    await edit();
    expect(
      tester.widget<TextField>(fields.at(0)).controller!.text,
      'Example Holder',
    );
    for (var i = 0; i < 6; i++) {
      await tester.enterText(fields.at(i), '');
    }
    await tester.tap(find.text('Save details'));
    await tester.pumpAndSettle();
    expect(find.text('Add bank details'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const WorktimeApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Add bank details'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Add bank details'), findsOneWidget);
  });
}
