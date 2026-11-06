import 'package:flutter/material.dart';

import 'app_style.dart';
import 'payroll.dart';

class PayrollSettingsDialog extends StatefulWidget {
  const PayrollSettingsDialog({super.key, required this.settings});

  final PayrollSettings settings;

  @override
  State<PayrollSettingsDialog> createState() => _PayrollSettingsDialogState();
}

class _PayrollSettingsDialogState extends State<PayrollSettingsDialog> {
  final form = GlobalKey<FormState>();
  late final s = widget.settings;
  late final ahvNumber = TextEditingController(text: s.ahvNumber);
  late final hourly = TextEditingController(
    text: formatScaled(s.hourlyRateCents, 2),
  );
  late final vacation = TextEditingController(
    text: formatScaled(s.vacationRate, 3),
  );
  late final ahv = TextEditingController(text: formatScaled(s.ahvRate, 3));
  late final alv = TextEditingController(text: formatScaled(s.alvRate, 3));
  late final nbu = TextEditingController(text: formatScaled(s.nbuRate, 3));
  late final nbuCode = TextEditingController(text: s.nbuCode);
  late final bvg = TextEditingController(text: formatScaled(s.bvgCents, 2));
  late final bvgContract = TextEditingController(text: s.bvgContract);
  late final flat = TextEditingController(
    text: formatScaled(s.flatExpensesCents, 2),
  );

  late final controllers = [
    ahvNumber,
    hourly,
    vacation,
    ahv,
    alv,
    nbu,
    nbuCode,
    bvg,
    bvgContract,
    flat,
  ];

  @override
  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget field(
    String label,
    TextEditingController controller, {
    int? decimals,
    String? suffix,
  }) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: TextFormField(
      controller: controller,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: decimals == null
          ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      validator: decimals == null
          ? null
          : (v) => parseScaled(v ?? '', decimals) == null
                ? 'Zahl mit höchstens $decimals Nachkommastellen eingeben.'
                : null,
    ),
  );

  Widget pair(Widget a, Widget b) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: a),
      const SizedBox(width: 8),
      Expanded(child: b),
    ],
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Lohndaten'),
    content: SizedBox(
      width: 500,
      child: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Wird für die Lohnabrechnung beim Monatsabschluss verwendet. Nur auf diesem Gerät gespeichert.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              field('AHV-Nummer', ahvNumber),
              field('Stundenlohn', hourly, decimals: 2, suffix: 'CHF'),
              field('Ferienentschädigung', vacation, decimals: 3, suffix: '%'),
              field('AHV/IV/EO', ahv, decimals: 3, suffix: '%'),
              field('ALV', alv, decimals: 3, suffix: '%'),
              pair(
                field('NBU', nbu, decimals: 3, suffix: '%'),
                field('NBU-Code', nbuCode),
              ),
              pair(
                field('BVG pro Monat', bvg, decimals: 2, suffix: 'CHF'),
                field('BVG-Vertrag', bvgContract),
              ),
              field('Pauschalspesen', flat, decimals: 2, suffix: 'CHF'),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      FilledButton(
        onPressed: () {
          if (!form.currentState!.validate()) return;
          Navigator.pop(
            context,
            PayrollSettings(
              ahvNumber: ahvNumber.text.trim(),
              hourlyRateCents: parseScaled(hourly.text, 2)!,
              vacationRate: parseScaled(vacation.text, 3)!,
              ahvRate: parseScaled(ahv.text, 3)!,
              alvRate: parseScaled(alv.text, 3)!,
              nbuRate: parseScaled(nbu.text, 3)!,
              nbuCode: nbuCode.text.trim(),
              bvgCents: parseScaled(bvg.text, 2)!,
              bvgContract: bvgContract.text.trim(),
              flatExpensesCents: parseScaled(flat.text, 2)!,
            ),
          );
        },
        child: const Text('Speichern'),
      ),
    ],
  );
}
