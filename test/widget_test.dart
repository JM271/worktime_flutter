import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worktime/main.dart';

void main() {
  testWidgets('Timer saves an entry and survives restart', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const WorktimeApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Client work');
    await tester.tap(find.text('Start timer'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Stop & save'), findsOneWidget);
    await tester.tap(find.text('Stop & save'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('worktime'), contains('Client work'));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const WorktimeApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Client work'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Client work'), findsOneWidget);
  });
}
