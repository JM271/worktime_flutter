/// Swiss hourly-wage payslip (Lohnabrechnung).
///
/// All money is held in Rappen (cents) and every percentage in thousandths of
/// a percent (10.640 % → 10640), so the arithmetic is exact and each line
/// rounds half-up to the Rappen like a payroll system does.
library;

class PayrollSettings {
  const PayrollSettings({
    this.hourlyRateCents = 2800,
    this.vacationRate = 10640,
    this.ahvRate = 5300,
    this.alvRate = 1100,
    this.nbuRate = 2238,
    this.nbuCode = 'A1',
    this.bvgCents = 4685,
    this.bvgContract = '9744223',
    this.flatExpensesCents = 990,
  });

  final int hourlyRateCents;

  /// Ferienentschädigung, AHV/IV/EO, ALV and NBU in thousandths of a percent.
  final int vacationRate, ahvRate, alvRate, nbuRate;
  final String nbuCode;

  /// Fixed monthly BVG (LPP) employee contribution.
  final int bvgCents;
  final String bvgContract;

  /// Monthly flat expense allowance (Pauschalspesen).
  final int flatExpensesCents;

  Map<String, Object> toJson() => {
    'hourlyRateCents': hourlyRateCents,
    'vacationRate': vacationRate,
    'ahvRate': ahvRate,
    'alvRate': alvRate,
    'nbuRate': nbuRate,
    'nbuCode': nbuCode.trim(),
    'bvgCents': bvgCents,
    'bvgContract': bvgContract.trim(),
    'flatExpensesCents': flatExpensesCents,
  };

  factory PayrollSettings.fromJson(Map<String, dynamic> json) {
    const d = PayrollSettings();
    int read(String key, int fallback) =>
        json[key] is int && (json[key] as int) >= 0
        ? json[key] as int
        : fallback;
    return PayrollSettings(
      hourlyRateCents: read('hourlyRateCents', d.hourlyRateCents),
      vacationRate: read('vacationRate', d.vacationRate),
      ahvRate: read('ahvRate', d.ahvRate),
      alvRate: read('alvRate', d.alvRate),
      nbuRate: read('nbuRate', d.nbuRate),
      nbuCode: json['nbuCode'] as String? ?? d.nbuCode,
      bvgCents: read('bvgCents', d.bvgCents),
      bvgContract: json['bvgContract'] as String? ?? d.bvgContract,
      flatExpensesCents: read('flatExpensesCents', d.flatExpensesCents),
    );
  }
}

class PayslipLine {
  const PayslipLine(
    this.code,
    this.label,
    this.amountCents, {
    this.basis = '',
    this.rate = '',
    this.total = false,
  });

  final int code;
  final String label;
  final String basis;
  final String rate;
  final int amountCents;

  /// Subtotal rows (Brutto, Abzüge, Netto, Auszahlung) are highlighted.
  final bool total;
}

class Payslip {
  const Payslip({
    required this.month,
    required this.date,
    required this.paymentDate,
    required this.hoursHundredths,
    required this.lines,
    required this.grossCents,
    required this.deductionsCents,
    required this.netCents,
    required this.paymentCents,
  });

  final DateTime month, date, paymentDate;
  final int hoursHundredths;
  final List<PayslipLine> lines;
  final int grossCents, deductionsCents, netCents, paymentCents;
}

/// Rounds `value * rate / 100000` half-up (rate in thousandths of a percent).
int _percentOf(int cents, int rate) => (cents * rate + 50000) ~/ 100000;

/// Social-insurance bases for ALV and NBU are rounded to 5 Rappen.
int _roundTo5Rappen(int cents) => (cents + 2) ~/ 5 * 5;

Payslip calculatePayslip({
  required DateTime month,
  required Duration worked,
  required int effectiveExpensesCents,
  required PayrollSettings settings,
  required DateTime date,
  DateTime? paymentDate,
}) {
  final hours = (worked.inMicroseconds + 18000000) ~/ 36000000;
  final salary = (settings.hourlyRateCents * hours + 50) ~/ 100;
  final vacation = _percentOf(salary, settings.vacationRate);
  final gross = salary + vacation;
  final roundedGross = _roundTo5Rappen(gross);
  final ahv = _percentOf(gross, settings.ahvRate);
  final alv = _percentOf(roundedGross, settings.alvRate);
  final nbu = _percentOf(roundedGross, settings.nbuRate);
  final deductions = ahv + alv + nbu + settings.bvgCents;
  final net = gross - deductions;
  final payment = net + effectiveExpensesCents + settings.flatExpensesCents;
  final nbuLabel = 'Cotisation AANP ${settings.nbuCode.trim()}'.trim();
  final bvgLabel = 'Cotisation LPP ${settings.bvgContract.trim()}'.trim();

  return Payslip(
    month: DateTime(month.year, month.month),
    date: date,
    paymentDate: paymentDate ?? date,
    hoursHundredths: hours,
    grossCents: gross,
    deductionsCents: deductions,
    netCents: net,
    paymentCents: payment,
    lines: [
      PayslipLine(
        1005,
        'Salaire horaire',
        salary,
        basis: chf(settings.hourlyRateCents),
        rate: chf(hours),
      ),
      PayslipLine(
        1160,
        'Indemnités de vacances',
        vacation,
        basis: chf(salary),
        rate: percent(settings.vacationRate),
      ),
      PayslipLine(5000, 'Salaire brut', gross, total: true),
      PayslipLine(
        5010,
        'Contribution AVS/AI/APG',
        -ahv,
        basis: chf(gross),
        rate: percent(settings.ahvRate),
      ),
      PayslipLine(
        5020,
        'Cotisation AC',
        -alv,
        basis: chf(roundedGross),
        rate: percent(settings.alvRate),
      ),
      PayslipLine(
        5040,
        nbuLabel,
        -nbu,
        basis: chf(roundedGross),
        rate: percent(settings.nbuRate),
      ),
      if (settings.bvgCents > 0)
        PayslipLine(5050, bvgLabel, -settings.bvgCents),
      PayslipLine(5900, 'Total des déductions', -deductions, total: true),
      PayslipLine(6500, 'Salaire net', net, total: true),
      if (effectiveExpensesCents > 0)
        PayslipLine(6030, 'Autres frais effectifs', effectiveExpensesCents),
      if (settings.flatExpensesCents > 0)
        PayslipLine(
          6070,
          'Autres frais forfaitaires',
          settings.flatExpensesCents,
        ),
      PayslipLine(6600, 'Montant du paiement', payment, total: true),
    ],
  );
}

/// Swiss number format with apostrophe thousands: 187544 → 1'875.44.
String chf(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  final whole = (abs ~/ 100).toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => "'",
  );
  return '$sign$whole.${(abs % 100).toString().padLeft(2, '0')}';
}

/// 10640 → 10.640%
String percent(int rate) =>
    '${rate ~/ 1000}.${(rate % 1000).toString().padLeft(3, '0')}%';

/// Parses a non-negative decimal ("28", "28.5", "10,64") into an integer
/// scaled by 10^[decimals]; null when malformed or too precise.
int? parseScaled(String value, int decimals) {
  final text = value.trim().replaceAll(',', '.').replaceAll("'", '');
  if (!RegExp('^\\d{1,9}(\\.\\d{1,$decimals})?\$').hasMatch(text)) return null;
  final parts = text.split('.');
  var scale = 1;
  for (var i = 0; i < decimals; i++) {
    scale *= 10;
  }
  return int.parse(parts[0]) * scale +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(decimals, '0')));
}

/// 10640 → "10.64" for editing (trailing zeros dropped).
String formatScaled(int value, int decimals) {
  var scale = 1;
  for (var i = 0; i < decimals; i++) {
    scale *= 10;
  }
  final fraction = (value % scale)
      .toString()
      .padLeft(decimals, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  final whole = value ~/ scale;
  return fraction.isEmpty ? '$whole' : '$whole.${fraction.padRight(2, '0')}';
}

const germanMonths = [
  'Januar',
  'Februar',
  'März',
  'April',
  'Mai',
  'Juni',
  'Juli',
  'August',
  'September',
  'Oktober',
  'November',
  'Dezember',
];
