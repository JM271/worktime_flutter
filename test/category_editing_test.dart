import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worktime/main.dart';
import 'package:worktime/task_categories.dart';

void main() {
  testWidgets('Custom categories persist and are used by both entry forms', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const WorktimeApp());
    await tester.pumpAndSettle();
    final manage = find.text('Edit categories');
    await tester.ensureVisible(manage);
    await tester.pumpAndSettle();
    await tester.tap(manage);
    await tester.pumpAndSettle();
    final editor = find.byType(CategoryEditor);
    final fields = find.descendant(
      of: editor,
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.first, 'Customer Support');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final save = find.text('Save categories');
    await tester.scrollUntilVisible(
      save.hitTestable(),
      200,
      scrollable: find
          .descendant(of: editor, matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('worktime-categories')!.first,
      'Customer Support',
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const WorktimeApp());
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, 'Customer Support'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'After Sales'), findsNothing);
    final picker = tester.widget<TaskCategoryPicker>(
      find.byType(TaskCategoryPicker),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ManualEntry(categories: picker.categories)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, 'Customer Support'), findsOneWidget);
  });

  testWidgets('Category editor adds, removes, and validates names', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CategoryEditor(categories: ['Repair', 'Sales'])),
      ),
    );
    await tester.enterText(find.byType(TextField).last, 'repair');
    await tester.tap(find.text('Save categories'));
    await tester.pumpAndSettle();
    expect(find.text('Category names must be unique.'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove category').last);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.text('Add category'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    await tester.tap(find.text('Save categories'));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter at least one category and fill in every name.'),
      findsOneWidget,
    );
  });
}
