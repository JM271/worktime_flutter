import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worktime/main.dart';
import 'package:worktime/task_categories.dart';

void main() {
  testWidgets('Timer saves an entry and survives restart', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const WorktimeApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Client work');
    await tester.pumpAndSettle();
    final category = find.widgetWithText(CategoryTile, 'Bike Repair');
    await tester.ensureVisible(category);
    await tester.pumpAndSettle();
    await tester.tap(category);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Client work',
    );
    expect(tester.widget<CategoryTile>(category).selected, isTrue);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Start timer'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start timer'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Stop & save'), findsOneWidget);
    expect(tester.widget<CategoryTile>(category).onTap, isNull);
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Stop & save'),
    );
    await tester.pump();
    await tester.tap(find.text('Stop & save'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    final stored = jsonDecode(prefs.getString('worktime')!) as Map;
    final entry = Entry.fromJson(
      Map<String, dynamic>.from((stored['entries'] as List).single as Map),
    );
    expect(entry.task, 'Client work');
    expect(entry.category, 'Bike Repair');
    expect(entry.end, isNotNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const WorktimeApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work log'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Client work'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Client work'), findsOneWidget);
    expect(find.text('Bike Repair'), findsWidgets);
    expect(find.text('General'), findsNothing);
    expect(find.text('Category: Bike Repair'), findsNothing);
  });

  testWidgets('Editing replaces an entry, persists it, and cancel keeps it', (
    tester,
  ) async {
    final now = DateTime.now();
    final original = Entry(
      'Original task',
      DateTime(now.year, now.month, now.day, 23, 30, 12, 345),
      DateTime(now.year, now.month, now.day + 1, 1, 15, 23, 456),
      'Bike Repair',
    );
    SharedPreferences.setMockInitialValues({
      'worktime': jsonEncode({
        'entries': [original.toJson()],
      }),
    });
    await tester.pumpWidget(const WorktimeApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work log'));
    await tester.pumpAndSettle();
    final edit = find.byTooltip('Edit entry');
    await tester.scrollUntilVisible(
      edit,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(edit);
    await tester.pumpAndSettle();
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(find.text('Edit work time'), findsOneWidget);
    final editor = find.byType(ManualEntry);
    final description = find.descendant(
      of: editor,
      matching: find.byType(TextField),
    );
    expect(
      tester.widget<TextField>(description).controller!.text,
      'Original task',
    );
    await tester.enterText(description, 'Corrected task');
    final category = find.descendant(
      of: editor,
      matching: find.widgetWithText(CategoryTile, 'Administration'),
    );
    await tester.ensureVisible(category);
    await tester.tap(category);
    await tester.pumpAndSettle();
    final save = find.text('Save entry');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    final stored = jsonDecode(prefs.getString('worktime')!) as Map;
    final entries = stored['entries'] as List;
    expect(entries, hasLength(1));
    final updated = Entry.fromJson(
      Map<String, dynamic>.from(entries.single as Map),
    );
    expect(updated.task, 'Corrected task');
    expect(updated.category, 'Administration');
    expect(updated.start, original.start);
    expect(updated.end, original.end);

    await tester.scrollUntilVisible(
      edit,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(edit);
    await tester.pumpAndSettle();
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.enterText(description, 'Discard this');
    Navigator.of(tester.element(editor)).pop();
    await tester.pumpAndSettle();
    expect(prefs.getString('worktime'), jsonEncode(stored));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const WorktimeApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work log'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Corrected task'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Corrected task'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('The +5 min button adds five minutes to the running timer', (
    tester,
  ) async {
    final start = DateTime.now().subtract(const Duration(minutes: 10));
    SharedPreferences.setMockInitialValues({
      'worktime': jsonEncode({
        'entries': [],
        'running': Entry('Client work', start, null, 'Bike Repair').toJson(),
      }),
    });
    await tester.pumpWidget(const WorktimeApp());
    await tester.pumpAndSettle();
    expect(find.text('00:10'), findsOneWidget);
    final addFive = find.widgetWithText(OutlinedButton, '5 min');
    await tester.ensureVisible(addFive);
    await tester.pumpAndSettle();
    await tester.tap(addFive);
    await tester.pumpAndSettle();
    expect(find.text('00:15'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    final stored = jsonDecode(prefs.getString('worktime')!) as Map;
    final running = Entry.fromJson(
      Map<String, dynamic>.from(stored['running'] as Map),
    );
    expect(running.start, start.subtract(const Duration(minutes: 5)));
    expect(running.task, 'Client work');
    expect(running.category, 'Bike Repair');
    expect(running.end, isNull);

    await tester.ensureVisible(find.text('Stop & save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop & save'));
    await tester.pumpAndSettle();
    expect(addFive, findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  test('A month splits into four weeks, the last one running to month end', () {
    expect(monthWeekBounds(DateTime(2026, 2, 17, 13, 30)), [
      DateTime(2026, 2, 1),
      DateTime(2026, 2, 8),
      DateTime(2026, 2, 15),
      DateTime(2026, 2, 22),
      DateTime(2026, 3, 1),
    ]);
    expect(monthWeekBounds(DateTime(2026, 12, 31)).last, DateTime(2027, 1, 1));
  });

  testWidgets('The timer page shows hours worked per week of the month', (
    tester,
  ) async {
    final now = DateTime.now();
    Entry worked(int day, int minutes) {
      final start = DateTime(now.year, now.month, day, 9);
      return Entry(
        'Client work',
        start,
        start.add(Duration(minutes: minutes)),
        'Bike Repair',
      );
    }

    SharedPreferences.setMockInitialValues({
      'worktime': jsonEncode({
        'entries': [
          worked(2, 120).toJson(),
          worked(7, 30).toJson(),
          worked(8, 90).toJson(),
          worked(23, 45).toJson(),
        ],
      }),
    });
    await tester.pumpWidget(const WorktimeApp());
    await tester.pumpAndSettle();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    for (final (index, value, days) in [
      (0, '2h 30m', '1–7'),
      (1, '1h 30m', '8–14'),
      (2, '–', '15–21'),
      (3, '0h 45m', '22–$lastDay'),
    ]) {
      final week = find.byKey(ValueKey('month-week-$index'));
      expect(
        find.descendant(of: week, matching: find.text(value)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: week, matching: find.text(days)),
        findsOneWidget,
      );
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('A new timer needs both a description and a category', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const WorktimeApp());
    await tester.pumpAndSettle();

    Future<void> tryStart() async {
      final start = find.widgetWithText(FilledButton, 'Start timer');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(start);
      await tester.pumpAndSettle();
      expect(start.hitTestable(), findsOneWidget);
      await tester.tap(start);
      await tester.pumpAndSettle();
    }

    await tester.enterText(find.byType(TextField).first, 'Client work');
    await tryStart();
    expect(find.text('Stop & save'), findsNothing);
    expect(find.text('Choose a quick category.'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, '');
    final category = find.widgetWithText(CategoryTile, 'Bike Repair');
    await tester.ensureVisible(category);
    await tester.pumpAndSettle();
    await tester.tap(category);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      isEmpty,
    );
    await tryStart();
    expect(find.text('Stop & save'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byType(TextField).first)
          .decoration!
          .errorText,
      'Type what you are working on.',
    );

    await tester.enterText(find.byType(TextField).first, 'Client work');
    await tryStart();
    expect(find.text('Stop & save'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
