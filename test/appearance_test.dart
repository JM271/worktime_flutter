import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worktime/main.dart';

void main() {
  String currentFont(WidgetTester tester) => tester
      .widget<MaterialApp>(find.byType(MaterialApp))
      .theme!
      .textTheme
      .bodyMedium!
      .fontFamily!;

  testWidgets('Fixed font ignores legacy choices and preserves active work', (
    tester,
  ) async {
    final now = DateTime.now();
    final completed = Entry(
      'Completed task',
      'Existing project',
      now.subtract(const Duration(hours: 2)),
      now.subtract(const Duration(hours: 1)),
    );
    final running = Entry(
      'Working task',
      'Current project',
      now.subtract(const Duration(minutes: 5)),
    );
    final savedWork = jsonEncode({
      'entries': [completed.toJson()],
      'running': running.toJson(),
    });
    SharedPreferences.setMockInitialValues({
      'worktime': savedWork,
      'worktime_font': 'Sora',
    });

    await tester.pumpWidget(const WorktimeApp());
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!.brightness,
      Brightness.light,
    );
    expect(clock(const Duration(hours: 2, minutes: 35, seconds: 59)), '02:35');
    expect(find.text('YOUR TIME, WELL SPENT'), findsNothing);
    expect(find.text('Make time count.'), findsNothing);
    expect(find.text('Track your work, one task at a time.'), findsNothing);
    expect(currentFont(tester), 'JetBrains Mono');
    expect(find.byTooltip('Choose font'), findsNothing);
    expect(find.text('Stop & save'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      running.task,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('worktime'), savedWork);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const WorktimeApp());
    await tester.pumpAndSettle();
    expect(currentFont(tester), 'JetBrains Mono');
    expect(find.text('Stop & save'), findsOneWidget);
    expect(prefs.getString('worktime'), savedWork);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      running.task,
    );

    await tester.scrollUntilVisible(
      find.text('Stop & save'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Stop & save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop & save'));
    await tester.pumpAndSettle();
    final updatedWork = jsonDecode(prefs.getString('worktime')!) as Map;
    final entries = updatedWork['entries'] as List;
    expect(updatedWork['running'], isNull);
    expect(entries, hasLength(2));
    expect(entries.first, completed.toJson());
    expect(entries.last['task'], running.task);
    expect(entries.last['project'], running.project);
    expect(entries.last['start'], running.start.toIso8601String());
    expect(entries.last['end'], isNotNull);
    expect(currentFont(tester), 'JetBrains Mono');
  });
}
