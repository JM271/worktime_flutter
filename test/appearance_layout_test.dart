import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worktime/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final font = FontLoader('JetBrains Mono')
      ..addFont(rootBundle.load('assets/fonts/JetBrainsMono.ttf'));
    await font.load();
  });

  for (final scenario in [
    (name: 'phone', width: 390.0, height: 844.0, scale: 1.0),
    (name: 'compact', width: 320.0, height: 760.0, scale: 1.5),
    (name: 'wide', width: 960.0, height: 900.0, scale: 1.0),
  ]) {
    testWidgets(
      'Dashboard and sheets fit ${scenario.name} with bundled fonts',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(scenario.width, scenario.height);
        tester.platformDispatcher.textScaleFactorTestValue = scenario.scale;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final now = DateTime.now();
        SharedPreferences.setMockInitialValues({
          'worktime': jsonEncode({
            'entries': [
              Entry(
                'Clean the delivery van and workshop',
                'Bike workshop',
                DateTime(now.year, now.month, now.day, 9),
                DateTime(now.year, now.month, now.day, 11),
                'Clean Workshop & Vehicles',
              ).toJson(),
            ],
          }),
        });
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(key: boundaryKey, child: const WorktimeApp()),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester
              .widget<MaterialApp>(find.byType(MaterialApp))
              .theme!
              .textTheme
              .bodyMedium!
              .fontFamily,
          'JetBrains Mono',
        );

        Future<void> snapshot(String name) async {
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (!const bool.fromEnvironment('WORKTIME_PREVIEWS')) return;
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final rendered = await boundary.toImage(pixelRatio: 1.5);
            final bytes = await rendered.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final directory = await Directory('build/previews')
                .create(recursive: true);
            await File('${directory.path}/${scenario.name}-$name.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            rendered.dispose();
          });
        }

        await snapshot('dashboard');
        await tester.scrollUntilVisible(
          find.text('Add time'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.widgetWithText(FilledButton, 'Add time'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add time'));
        await tester.pumpAndSettle();
        final description = find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(TextField),
            )
            .first;
        await tester.enterText(description, 'Replace the brake pads');
        await tester.pumpAndSettle();
        await snapshot('manual');
        final save = find.widgetWithText(FilledButton, 'Save entry');
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text('Choose a quick category.'), findsOneWidget);
        final repair = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.widgetWithText(ChoiceChip, 'Bike Repair'),
        );
        await tester.ensureVisible(repair);
        await tester.pumpAndSettle();
        await tester.tap(repair);
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(description).controller!.text,
          'Replace the brake pads',
        );
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);

        await tester.scrollUntilVisible(
          find.text('Your time entries'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await snapshot('entries');
        await tester.scrollUntilVisible(
          find.text('Calculate month'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.widgetWithText(FilledButton, 'Calculate month'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Calculate month'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(find.text('Monthly report'), findsOneWidget);
        await snapshot('report');
        await tester.scrollUntilVisible(
          find.text('Account information'),
          400,
          scrollable: find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await snapshot('report-bank');
      },
    );
  }
}
