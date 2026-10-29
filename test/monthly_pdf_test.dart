import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:worktime/bank_details.dart';
import 'package:worktime/expenses.dart';
import 'package:worktime/models.dart';
import 'package:worktime/monthly_pdf.dart';
import 'package:worktime/report_analysis.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'PDF paginates monthly entries and embeds JPEG and legacy PNG receipts',
    () async {
      final receipt = img.Image(width: 450, height: 900);
      img.fill(receipt, color: img.ColorRgb8(255, 255, 255));
      img.drawString(
        receipt,
        'KASSENZETTEL',
        font: img.arial24,
        x: 30,
        y: 30,
        color: img.ColorRgb8(0, 0, 0),
      );
      img.drawString(
        receipt,
        'Material CHF 12.35',
        font: img.arial24,
        x: 30,
        y: 100,
        color: img.ColorRgb8(0, 0, 0),
      );
      final entries = [
        Entry(
          'Vormonat',
          DateTime(2026, 9, 1, 9),
          DateTime(2026, 9, 1, 10),
          'Alt',
        ),
        for (var i = 0; i < 55; i++)
          Entry(
            'Reparatur ${i + 1}: Überprüfung und Material für Fahrräder',
            DateTime(2026, 10, 1 + i % 28, 9),
            DateTime(2026, 10, 1 + i % 28, 11, 30),
            'Werkstatt',
          ),
      ];
      final bytes = await monthlyPdfFromAnalysis(
        MonthlyAnalysis(
          entries,
          DateTime(2026, 10),
          asOf: DateTime(2026, 11, 1),
        ),
        bankDetails: const BankDetails(
          accountHolder: 'Erika Muster',
          accountNumber: 'CH00 1234 5678 9012',
          bankName: 'Beispielbank',
        ),
        expenses: [
          Expense(
            'Material für Reparaturen',
            DateTime(2026, 10, 12),
            1235,
            receipt: img.encodeJpg(receipt, quality: 65),
          ),
          Expense(
            'Zugticket',
            DateTime(2026, 10, 13),
            450,
            receipt: img.encodePng(receipt),
          ),
          Expense('Ohne Beleg', DateTime(2026, 10, 14), 100),
          Expense(
            'Falscher Monat',
            DateTime(2026, 9, 30),
            999,
            receipt: img.encodePng(receipt),
          ),
        ],
      );
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      expect(bytes.length, greaterThan(1000));
      final output = Platform.environment['PDF_QA_DIR'];
      if (output != null) {
        await Directory(output).create(recursive: true);
        await File('$output/monthly.pdf').writeAsBytes(bytes);
      }
    },
  );
  test(
    'PDF supports an empty month without bank details or receipts',
    () async {
      final bytes = await monthlyPdfFromAnalysis(
        MonthlyAnalysis([], DateTime(2026, 10)),
      );
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      final output = Platform.environment['PDF_QA_DIR'];
      if (output != null) {
        await Directory(output).create(recursive: true);
        await File('$output/empty.pdf').writeAsBytes(bytes);
      }
    },
  );
}
