import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'bank_details.dart';
import 'expenses.dart';
import 'report_analysis.dart';

String _two(int n) => n.toString().padLeft(2, '0');
String _date(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}';
String _stamp(DateTime d) => '${_date(d)} ${_two(d.hour)}:${_two(d.minute)}';
String _hours(Duration d) => (d.inMicroseconds / 3600000000).toStringAsFixed(2);

Future<Uint8List> monthlyPdfFromAnalysis(
  MonthlyAnalysis analysis, {
  BankDetails bankDetails = const BankDetails(),
  List<Expense> expenses = const [],
}) async {
  final font = pw.Font.ttf(
    await rootBundle.load('assets/fonts/JetBrainsMono.ttf'),
  );
  final theme = pw.ThemeData.withFont(base: font, bold: font);
  final period = '${analysis.month.year}-${_two(analysis.month.month)}';
  final document = pw.Document(title: 'Worktime $period', author: 'Worktime');
  final monthExpenses = expensesForMonth(expenses, analysis.month);
  final receipts = monthExpenses.where((e) => e.receipt != null).toList();
  const navy = PdfColor.fromInt(0xff162536);
  const pale = PdfColor.fromInt(0xfff2f6fa);

  pw.Widget heading(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 18, bottom: 8),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 13,
        fontWeight: pw.FontWeight.bold,
        color: navy,
      ),
    ),
  );
  pw.Widget table(
    List<String> headers,
    List<List<String>> rows, {
    Map<int, pw.TableColumnWidth>? widths,
  }) => pw.TableHelper.fromTextArray(
    headers: headers,
    data: rows,
    columnWidths: widths,
    headerStyle: pw.TextStyle(
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    ),
    headerDecoration: const pw.BoxDecoration(color: navy),
    cellStyle: const pw.TextStyle(fontSize: 8),
    cellPadding: const pw.EdgeInsets.all(6),
    cellAlignment: pw.Alignment.topLeft,
    oddRowDecoration: const pw.BoxDecoration(color: pale),
    border: null,
  );
  pw.Widget footer(pw.Context context) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 12),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Worktime $period',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
        pw.Text(
          'Seite ${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ],
    ),
  );
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      theme: theme,
      maxPages: 1000,
      header: (_) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 12),
        child: pw.Text(
          'Worktime · $period',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: navy,
          ),
        ),
      ),
      footer: footer,
      build: (_) => [
        heading('Arbeitszeiten'),
        if (analysis.rows.isEmpty)
          pw.Text(
            'Keine abgeschlossenen Einträge.',
            style: const pw.TextStyle(fontSize: 9),
          )
        else
          table(
            ['Tätigkeit', 'Kategorie', 'Von', 'Bis', 'Stunden'],
            [
              for (final row in analysis.rows)
                [
                  row.entry.task,
                  row.category,
                  _stamp(row.start),
                  _stamp(row.end),
                  _hours(row.duration),
                ],
            ],
            widths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
              4: const pw.FlexColumnWidth(1.2),
            },
          ),
        pw.NewPage(freeSpace: 110),
        heading('Kategoriesummen'),
        table(
          ['Kategorie', 'Stunden'],
          [
            for (final category in analysis.categories)
              [category.category, _hours(category.total)],
            ['Total Arbeitszeit', _hours(analysis.total)],
          ],
        ),
        if (!bankDetails.isEmpty) ...[
          pw.NewPage(freeSpace: 110),
          heading('Bankangaben'),
          table(
            ['Angabe', 'Wert'],
            [
              for (final field in bankDetails.fields) [field.$1, field.$2],
            ],
          ),
        ],
        pw.NewPage(freeSpace: 110),
        heading('Spesen'),
        if (monthExpenses.isEmpty)
          pw.Text(
            'Keine Spesen in diesem Monat.',
            style: const pw.TextStyle(fontSize: 9),
          )
        else
          table(
            ['Beschreibung', 'Datum', 'Betrag (CHF)', 'Beleg'],
            [
              for (final expense in monthExpenses)
                [
                  expense.description,
                  _date(expense.date),
                  (expense.cents / 100).toStringAsFixed(2),
                  expense.receipt == null
                      ? '-'
                      : 'Beleg ${receipts.indexOf(expense) + 1}',
                ],
              [
                'Total Spesen',
                '',
                (monthExpenses.fold<int>(0, (sum, e) => sum + e.cents) / 100)
                    .toStringAsFixed(2),
                '',
              ],
            ],
            widths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(1.5),
            },
          ),
      ],
    ),
  );
  for (var i = 0; i < receipts.length; i++) {
    final expense = receipts[i];
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: theme,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            heading('Beleg ${i + 1}'),
            pw.Text(
              '${_date(expense.date)} · ${expenseAmount(expense.cents)}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 16),
            pw.Expanded(
              child: pw.Image(
                pw.MemoryImage(expense.receipt!),
                fit: pw.BoxFit.contain,
              ),
            ),
            footer(context),
          ],
        ),
      ),
    );
  }
  return document.save();
}
