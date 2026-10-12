import 'package:flutter/material.dart';

import 'app_style.dart';
import 'bank_details.dart';

class BankDetailsDialog extends StatefulWidget {
  const BankDetailsDialog({super.key, required this.details});

  final BankDetails details;

  @override
  State<BankDetailsDialog> createState() => _BankDetailsDialogState();
}

class _BankDetailsDialogState extends State<BankDetailsDialog> {
  late final holder = TextEditingController(text: widget.details.accountHolder);
  late final number = TextEditingController(text: widget.details.accountNumber);
  late final bank = TextEditingController(text: widget.details.bankName);
  late final bic = TextEditingController(text: widget.details.bic);
  late final country = TextEditingController(text: widget.details.country);
  late final currency = TextEditingController(text: widget.details.currency);

  @override
  void dispose() {
    holder.dispose();
    number.dispose();
    bank.dispose();
    bic.dispose();
    country.dispose();
    currency.dispose();
    super.dispose();
  }

  Widget field(String label, TextEditingController controller) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: TextField(
      controller: controller,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(labelText: label),
      textInputAction: controller == bic
          ? TextInputAction.done
          : TextInputAction.next,
    ),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Bank details'),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Saved on this device and included in monthly reports. Leave fields blank to omit them.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            field('Account holder', holder),
            field('IBAN / Account number', number),
            field('Bank name (optional)', bank),
            field('Country (optional)', country),
            field('Currency (optional)', currency),
            field('BIC / SWIFT (optional)', bic),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          BankDetails(
            accountHolder: holder.text.trim(),
            accountNumber: number.text.trim(),
            bankName: bank.text.trim(),
            bic: bic.text.trim(),
            country: country.text.trim(),
            currency: currency.text.trim(),
          ),
        ),
        child: const Text('Save details'),
      ),
    ],
  );
}
