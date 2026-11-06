import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:worktime/bank_details.dart';
import 'package:worktime/payroll.dart';
import 'package:worktime/payslip_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 66.98 h, as on the reference payslip of 02.11.2026.
  const worked = Duration(hours: 66, minutes: 58, seconds: 48);
  Payslip reference() => calculatePayslip(
    month: DateTime(2026, 10),
    worked: worked,
    effectiveExpensesCents: 2590,
    settings: const PayrollSettings(),
    date: DateTime(2026, 11, 2),
  );

  test('Reproduces the reference Lohnabrechnung to the Rappen', () {
    final payslip = reference();
    final lines = {
      for (final line in payslip.lines)
        line.code: (line.label, line.basis, line.rate, chf(line.amountCents)),
    };
    expect(payslip.hoursHundredths, 6698);
    expect(lines, {
      1005: ('Salaire horaire', '28.00', '66.98', "1'875.44"),
      1160: ('Indemnités de vacances', "1'875.44", '10.640%', '199.55'),
      5000: ('Salaire brut', '', '', "2'074.99"),
      5010: ('Contribution AVS/AI/APG', "2'074.99", '5.300%', '-109.97'),
      5020: ('Cotisation AC', "2'075.00", '1.100%', '-22.83'),
      5040: ('Cotisation AANP A1', "2'075.00", '2.238%', '-46.44'),
      5050: ('Cotisation LPP 9744223', '', '', '-46.85'),
      5900: ('Total des déductions', '', '', '-226.09'),
      6500: ('Salaire net', '', '', "1'848.90"),
      6030: ('Autres frais effectifs', '', '', '25.90'),
      6070: ('Autres frais forfaitaires', '', '', '9.90'),
      6600: ('Montant du paiement', '', '', "1'884.70"),
    });
    expect(payslip.lines.map((l) => l.code), [
      1005,
      1160,
      5000,
      5010,
      5020,
      5040,
      5050,
      5900,
      6500,
      6030,
      6070,
      6600,
    ]);
  });

  test('Lines without amounts are left out', () {
    final payslip = calculatePayslip(
      month: DateTime(2026, 10),
      worked: Duration.zero,
      effectiveExpensesCents: 0,
      settings: const PayrollSettings(bvgCents: 0, flatExpensesCents: 0),
      date: DateTime(2026, 11, 2),
    );
    expect(payslip.lines.map((l) => l.code), [
      1005,
      1160,
      5000,
      5010,
      5020,
      5040,
      5900,
      6500,
      6600,
    ]);
    expect(payslip.paymentCents, 0);
  });

  test('Formatting and parsing helpers', () {
    expect(chf(123456789), "1'234'567.89");
    expect(chf(-5), '-0.05');
    expect(percent(5300), '5.300%');
    expect(parseScaled('10,64', 3), 10640);
    expect(parseScaled("1'875.4", 2), 187540);
    expect(parseScaled('1.2345', 3), isNull);
    expect(parseScaled('-1', 2), isNull);
    expect(formatScaled(10640, 3), '10.64');
    expect(formatScaled(2800, 2), '28');
    expect(formatScaled(990, 2), '9.90');
    final settings = PayrollSettings.fromJson(
      const PayrollSettings(hourlyRateCents: 3150, nbuCode: 'B2').toJson(),
    );
    expect(settings.hourlyRateCents, 3150);
    expect(settings.nbuCode, 'B2');
    expect(PayrollSettings.fromJson(const {}).ahvRate, 5300);
  });

  test('Payslip PDF renders', () async {
    final bytes = await payslipPdf(
      reference(),
      bankDetails: const BankDetails(
        accountHolder: 'Test Person',
        accountNumber: 'CH00 0000 0000 0000 0000 0',
        bankName: 'Test Bank',
      ),
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    if (const bool.fromEnvironment('WORKTIME_PREVIEWS')) {
      final directory = await Directory('build/previews')
          .create(recursive: true);
      await File('${directory.path}/payslip.pdf').writeAsBytes(bytes);
    }
  });
}
