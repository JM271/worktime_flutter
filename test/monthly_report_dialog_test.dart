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
import 'package:worktime/bank_details.dart';
import 'package:worktime/main.dart';
import 'package:worktime/monthly_report_dialog.dart';
import 'package:worktime/report_analysis.dart';

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
  final asOf = DateTime(2026, 10, 12, 12);
  const bankDetails = BankDetails(
    accountHolder: 'Example Account Holder',
    accountNumber: '001234567890',
    bankName: 'Example Bank',
  );
  final entries = [
    Entry(
      'Client work',
      DateTime(2026, 10, 12, 9),
      DateTime(2026, 10, 12, 11),
      'Bike Repair',
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

  Future<Uint8List> showReport(
    WidgetTester tester,
    Future<OpenResult> Function(String) openFile, {
    bool intelligent = false,
    Future<OpenResult> Function(String)? openPdfFile,
    BankDetails bankDetails = const BankDetails(),
  }) async {
    final bytes = monthlyWorkbook(
      entries,
      month,
      asOf: asOf,
      bankDetails: bankDetails,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonthlyReportDialog(
            report: monthlyReport(
              entries,
              month,
              asOf: asOf,
              bankDetails: bankDetails,
            ),
            filename: 'worktime-2026-10.xlsx',
            bytes: bytes,
            analysis: intelligent
                ? MonthlyAnalysis(entries, month, asOf: asOf)
                : null,
            bankDetails: bankDetails,
            openFile: openFile,
            openPdfFile: openPdfFile ?? openMonthlyPdf,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return bytes;
  }

  testWidgets('Intelligent report stays readable on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(330, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await showReport(
      tester,
      (_) async => OpenResult(),
      intelligent: true,
      bankDetails: bankDetails,
    );

    expect(find.text('Monthly report'), findsOneWidget);
    expect(find.textContaining('Total time worked: 2h 00m'), findsOneWidget);
    expect(find.text('How this month compares'), findsOneWidget);
    expect(find.text('Where your time went'), findsOneWidget);
    expect(find.text('Bike Repair'), findsWidgets);
    expect(find.text('Account information'), findsOneWidget);
    expect(find.textContaining('001234567890'), findsOneWidget);
    expect(find.text('Open Excel'), findsOneWidget);
    expect(find.text('Share Excel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Calculate month shows the report before opening or sharing', (
    tester,
  ) async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'worktime': jsonEncode({
        'entries': [
          Entry(
            'Current task',
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

  testWidgets(
    'Open Excel opens a fresh category workbook beside an old report',
    (tester) async {
      final previous = xlsx.Excel.createExcel();
      previous['Sheet1'].appendRow([xlsx.TextCellValue('Project')]);
      final previousPath = '${directory.path}/worktime-2026-10.xlsx';
      await tester.runAsync(
        () => File(previousPath).writeAsBytes(previous.encode()!),
      );
      late Completer<String> opened;
      await showReport(tester, (path) async {
        opened.complete(path);
        return OpenResult();
      }, bankDetails: bankDetails);
      late String path;
      await tester.runAsync(() async {
        opened = Completer<String>();
        await tester.tap(find.text('Open Excel'));
        path = await opened.future.timeout(const Duration(seconds: 5));
      });
      await tester.pumpAndSettle();
      expect(path, startsWith('${directory.path}/worktime-2026-10-'));
      expect(path, endsWith('.xlsx'));
      expect(path, isNot(previousPath));
      final bytes = await tester.runAsync(() => File(path).readAsBytes());
      final book = xlsx.Excel.decodeBytes(bytes!);
      expect(book.tables.keys, ['Worktime']);
      final sheet = book['Worktime'];
      expect(
        sheet.rows[2].map((cell) => cell?.value),
        [
          'Task',
          'Category',
          'From',
          'To',
          'Hours worked',
        ].map(xlsx.TextCellValue.new),
      );
      expect(
        sheet.rows.expand((row) => row).map((cell) => cell?.value),
        isNot(contains(xlsx.TextCellValue('Project'))),
      );
      expect(
        sheet.rows.expand((row) => row).map((cell) => cell?.value),
        isNot(contains(xlsx.TextCellValue('Project totals'))),
      );
      expect(sheet.rows[3][0]!.value, xlsx.TextCellValue('Client work'));
      expect(sheet.rows[3][1]!.value, xlsx.TextCellValue('Bike Repair'));
      expect(
        sheet.rows[3][2]!.value,
        xlsx.DateTimeCellValue.fromDateTime(DateTime(2026, 10, 12, 9)),
      );
      final total = sheet.rows.firstWhere(
        (row) => row.first?.value == xlsx.TextCellValue('Total time worked'),
      );
      expect(total[4]!.value, xlsx.IntCellValue(2));
      final account = sheet.rows.firstWhere(
        (row) =>
            row.first?.value == xlsx.TextCellValue('IBAN / Account number'),
      );
      expect(account[1]!.value, xlsx.TextCellValue('001234567890'));
      expect(find.text('Monthly report'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Open Excel'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

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
      final preparedBytes = await showReport(tester, (_) async {
        opened.complete();
        return OpenResult(type: ResultType.noAppToOpen);
      }, bankDetails: bankDetails);
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
      expect(bytes, preparedBytes);
      expect(arguments['originWidth'], greaterThan(0));
      expect(arguments['originHeight'], greaterThan(0));
      expect(find.text('Monthly report'), findsOneWidget);
    },
  );

  testWidgets('PDF opens and shares the same document with a PDF filename', (
    tester,
  ) async {
    final opened = Completer<String>();
    final shared = Completer<MethodCall>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (call) async {
          shared.complete(call);
          return '';
        });
    await showReport(
      tester,
      (_) async => OpenResult(),
      intelligent: true,
      bankDetails: bankDetails,
      openPdfFile: (path) async {
        opened.complete(path);
        return OpenResult(type: ResultType.noAppToOpen);
      },
    );
    late String path;
    await tester.runAsync(() async {
      await tester.tap(find.text('PDF ansehen'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    for (var i = 0; i < 50 && !opened.isCompleted; i++) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    expect(opened.isCompleted, isTrue);
    path = await opened.future;
    await tester.pumpAndSettle();
    expect(path, endsWith('.pdf'));
    expect(find.textContaining('Keine PDF-App verfügbar'), findsOneWidget);
    final openedBytes = await tester.runAsync(() => File(path).readAsBytes());
    expect(ascii.decode(openedBytes!.take(5).toList()), '%PDF-');
    late MethodCall call;
    await tester.runAsync(() async {
      await tester.tap(find.text('PDF teilen'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    for (var i = 0; i < 50 && !shared.isCompleted; i++) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    expect(shared.isCompleted, isTrue);
    call = await shared.future;
    await tester.pumpAndSettle();
    final arguments = call.arguments as Map;
    final sharedPath = (arguments['paths'] as List).single as String;
    expect(sharedPath, endsWith('/worktime-2026-10.pdf'));
    final sharedBytes = await tester.runAsync(
      () => File(sharedPath).readAsBytes(),
    );
    expect(sharedBytes, openedBytes);
    expect(arguments['originWidth'], greaterThan(0));
    expect(tester.takeException(), isNull);
  });

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
