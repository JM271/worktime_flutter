import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart' as xlsx;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worktime/main.dart';
import 'package:worktime/monthly_report_dialog.dart';

class ReportPaths extends PathProviderPlatform {
  ReportPaths(this.path);
  final String? path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getTemporaryPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
  late Directory directory;
  late PathProviderPlatform originalPaths;
  final month = DateTime(2026, 10);
  final entries = [
    Entry(
      'Client work',
      'Website',
      DateTime(2026, 10, 12, 9),
      DateTime(2026, 10, 12, 11),
    ),
  ];

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('worktime-report-test-');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = ReportPaths(directory.path);
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPaths;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, null);
    await directory.delete(recursive: true);
  });

  Future<void> showReport(
    WidgetTester tester,
    Future<OpenResult> Function(String) openFile,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonthlyReportDialog(
            report: monthlyReport(entries, month),
            filename: 'worktime-2026-10.xlsx',
            bytes: monthlyWorkbook(entries, month),
            openFile: openFile,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Calculate month shows the report before opening or sharing', (
    tester,
  ) async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'worktime': jsonEncode({
        'entries': [
          Entry(
            'Current task',
            'General',
            DateTime(now.year, now.month, 1, 9),
            DateTime(now.year, now.month, 1, 11),
          ).toJson(),
        ],
      }),
    });
    var shareCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (_) async {
          shareCalls++;
          return '';
        });
    await tester.pumpWidget(const WorktimeApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Calculate month'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Calculate month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calculate month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Monthly report'), findsOneWidget);
    expect(find.text('Open Excel'), findsOneWidget);
    expect(find.text('Share Excel'), findsOneWidget);
    expect(find.textContaining('Total time worked: 2h 00m'), findsOneWidget);
    expect(shareCalls, 0);
  });

  testWidgets('Open Excel saves a readable workbook before launching it', (
    tester,
  ) async {
    late Completer<String> opened;
    await showReport(tester, (path) async {
      opened.complete(path);
      return OpenResult();
    });
    late String path;
    await tester.runAsync(() async {
      opened = Completer<String>();
      await tester.tap(find.text('Open Excel'));
      path = await opened.future.timeout(const Duration(seconds: 5));
    });
    await tester.pumpAndSettle();
    expect(path, '${directory.path}/worktime-2026-10.xlsx');
    final bytes = await tester.runAsync(() => File(path).readAsBytes());
    final sheet = xlsx.Excel.decodeBytes(bytes!)['Worktime'];
    expect(sheet.rows[3][0]!.value, xlsx.TextCellValue('Client work'));
    expect(sheet.rows.last[4]!.value, xlsx.IntCellValue(2));
    expect(find.text('Monthly report'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Open Excel'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'No spreadsheet app keeps the report and allows sharing the same workbook',
    (tester) async {
      late Completer<void> opened;
      late Completer<MethodCall> shared;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(shareChannel, (call) async {
            shared.complete(call);
            return '';
          });
      await showReport(tester, (_) async {
        opened.complete();
        return OpenResult(type: ResultType.noAppToOpen);
      });
      await tester.runAsync(() async {
        opened = Completer<void>();
        await tester.tap(find.text('Open Excel'));
        await opened.future.timeout(const Duration(seconds: 5));
      });
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No spreadsheet app is available.'),
        findsOneWidget,
      );
      late MethodCall call;
      await tester.runAsync(() async {
        shared = Completer<MethodCall>();
        await tester.tap(find.text('Share Excel'));
        call = await shared.future.timeout(const Duration(seconds: 5));
      });
      await tester.pumpAndSettle();
      final arguments = call.arguments as Map;
      final path = (arguments['paths'] as List).single as String;
      expect(path, endsWith('/worktime-2026-10.xlsx'));
      final bytes = await tester.runAsync(() => File(path).readAsBytes());
      expect(bytes, monthlyWorkbook(entries, month));
      expect(arguments['originWidth'], greaterThan(0));
      expect(arguments['originHeight'], greaterThan(0));
      expect(find.text('Monthly report'), findsOneWidget);
    },
  );

  testWidgets('Saving failure leaves the report and both actions available', (
    tester,
  ) async {
    PathProviderPlatform.instance = ReportPaths(null);
    var opened = false;
    await showReport(tester, (_) async {
      opened = true;
      return OpenResult();
    });
    await tester.tap(find.text('Open Excel'));
    await tester.pumpAndSettle();
    expect(opened, isFalse);
    expect(
      find.textContaining('The Excel sheet could not be opened.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Open Excel'))
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Share Excel'),
          )
          .onPressed,
      isNotNull,
    );
  });
}
