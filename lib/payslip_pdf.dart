import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'bank_details.dart';
import 'payroll.dart';

String _two(int n) => n.toString().padLeft(2, '0');
String _date(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}';

String payslipFilename(DateTime month) =>
    'lohnabrechnung-${month.year}-${_two(month.month)}.pdf';

Future<Uint8List> payslipPdf(
  Payslip payslip, {
  BankDetails bankDetails = const BankDetails(),
}) async {
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/SairaSemiExpanded-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/SairaSemiExpanded-SemiBold.ttf'),
  );
  final display = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Michroma-Regular.ttf'),
  );
  final logo = pw.MemoryImage(
    (await rootBundle.load('assets/brand/molenstraat.png')).buffer
        .asUint8List(),
  );
  const ink = PdfColor.fromInt(0xff1d3343);
  const muted = PdfColor.fromInt(0xff5b6b78);
  const tint = PdfColor.fromInt(0xffeff6f9);
  final period =
      '${germanMonths[payslip.month.month - 1]} ${payslip.month.year}';
  final document = pw.Document(
    title: 'Lohnabrechnung $period',
    author: bankDetails.accountHolder.trim().isEmpty
        ? 'Worktime'
        : bankDetails.accountHolder.trim(),
  );

  pw.TextStyle style({
    bool strong = false,
    double size = 10,
    PdfColor? color,
  }) => pw.TextStyle(
    font: strong ? bold : regular,
    fontSize: size,
    color: color ?? ink,
  );

  // Lohnart | Bezeichnung | Anteil/Basis | Ansatz/% | Betrag
  const flex = [12, 40, 18, 16, 16];
  pw.Widget row(
    List<String> cells, {
    bool strong = false,
    bool shaded = false,
    double vertical = 4,
  }) => pw.Container(
    color: shaded ? tint : null,
    padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: vertical),
    child: pw.Row(
      children: [
        for (var i = 0; i < cells.length; i++)
          pw.Expanded(
            flex: flex[i],
            child: pw.Text(
              cells[i],
              textAlign: i >= 2 ? pw.TextAlign.right : pw.TextAlign.left,
              style: style(strong: strong),
            ),
          ),
      ],
    ),
  );

  pw.Widget info(String label, String value) => pw.RichText(
    text: pw.TextSpan(
      children: [
        pw.TextSpan(text: '$label:  ', style: style(strong: true)),
        pw.TextSpan(text: value, style: style()),
      ],
    ),
  );

  final rows = <pw.Widget>[];
  for (final (i, line) in payslip.lines.indexed) {
    final previous = i == 0 ? null : payslip.lines[i - 1];
    // Breathing room around highlighted subtotals, as in the template.
    if (line.total || (previous?.total ?? false)) {
      rows.add(pw.SizedBox(height: 6));
    }
    rows.add(
      row(
        [
          '${line.code}',
          line.label,
          line.basis,
          line.rate,
          chf(line.amountCents),
        ],
        strong: line.total,
        shaded: line.total,
        vertical: line.total ? 7 : 4,
      ),
    );
  }

  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Image(logo, height: 34),
              pw.Spacer(),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'LOHNABRECHNUNG',
                    style: pw.TextStyle(
                      font: display,
                      fontSize: 13,
                      color: ink,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(period, style: style(color: muted)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 22),
          if (bankDetails.accountHolder.trim().isNotEmpty) ...[
            pw.Text(
              bankDetails.accountHolder.trim(),
              style: style(strong: true, size: 12),
            ),
            pw.SizedBox(height: 14),
          ],
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              info('Lohnabrechnungs Datum', _date(payslip.date)),
              info('Zahlungsdatum', _date(payslip.paymentDate)),
            ],
          ),
          pw.SizedBox(height: 22),
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: ink, width: 0.8)),
            ),
            child: row(
              ['Lohnart', 'Bezeichnung', 'Anteil/Basis', 'Ansatz/%', 'Betrag'],
              strong: true,
              vertical: 8,
            ),
          ),
          pw.SizedBox(height: 4),
          ...rows,
          if (bankDetails.accountNumber.trim().isNotEmpty) ...[
            pw.SizedBox(height: 26),
            pw.Text(
              'Auszahlung von CHF ${chf(payslip.paymentCents)} auf '
              '${bankDetails.accountNumber.trim()}'
              '${bankDetails.bankName.trim().isEmpty ? '' : ' · ${bankDetails.bankName.trim()}'}',
              style: style(size: 9, color: muted),
            ),
          ],
          pw.Spacer(),
          pw.Text(
            'Arbeitszeit ${chf(payslip.hoursHundredths)} h · erstellt mit Worktime',
            style: style(size: 8, color: muted),
          ),
        ],
      ),
    ),
  );
  return document.save();
}
