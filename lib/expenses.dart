import 'package:flutter/material.dart';

class Expense {
  const Expense(this.description, this.date, this.cents);
  final String description;
  final DateTime date;
  final int cents;

  Map<String, dynamic> toJson() => {
    'description': description,
    'date': date.toIso8601String(),
    'cents': cents,
  };
  factory Expense.fromJson(Map<String, dynamic> json) {
    final description = (json['description'] as String).trim();
    final cents = json['cents'] as int;
    if (description.isEmpty || cents <= 0) {
      throw const FormatException('Ungültige Spesen.');
    }
    return Expense(description, DateTime.parse(json['date'] as String), cents);
  }
}

int? parseExpenseCents(String value) {
  final text = value.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,9}(\.\d{1,2})?$').hasMatch(text)) return null;
  final parts = text.split('.');
  final cents =
      int.parse(parts[0]) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
  return cents > 0 ? cents : null;
}

String expenseAmount(int cents) => 'CHF ${(cents / 100).toStringAsFixed(2)}';
List<Expense> expensesForMonth(List<Expense> expenses, DateTime month) =>
    expenses
        .where((e) => e.date.year == month.year && e.date.month == month.month)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

class ExpenseEditor extends StatefulWidget {
  const ExpenseEditor({super.key, this.expense});
  final Expense? expense;
  @override
  State<ExpenseEditor> createState() => _ExpenseEditorState();
}

class _ExpenseEditorState extends State<ExpenseEditor> {
  final form = GlobalKey<FormState>();
  late final description = TextEditingController(
    text: widget.expense?.description,
  );
  late final amount = TextEditingController(
    text: widget.expense == null
        ? ''
        : (widget.expense!.cents / 100).toStringAsFixed(2),
  );
  late DateTime date = widget.expense?.date ?? DateTime.now();
  @override
  void dispose() {
    description.dispose();
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
      24,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Form(
      key: form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.expense == null ? 'Spesen erfassen' : 'Spesen bearbeiten',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: description,
            decoration: const InputDecoration(
              labelText: 'Beschreibung',
              hintText: 'z. B. Zugticket oder Material',
            ),
            textCapitalization: TextCapitalization.sentences,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Beschreibung eingeben.' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: amount,
            decoration: const InputDecoration(labelText: 'Betrag (CHF)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => parseExpenseCents(v ?? '') == null
                ? 'Positiven Betrag mit maximal 2 Nachkommastellen eingeben.'
                : null,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              MaterialLocalizations.of(context).formatMediumDate(date),
            ),
            onPressed: () async {
              final selected = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (selected != null && mounted) setState(() => date = selected);
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(
                  context,
                  Expense(
                    description.text.trim(),
                    DateTime(date.year, date.month, date.day),
                    parseExpenseCents(amount.text)!,
                  ),
                );
              }
            },
            child: const Text('Spesen speichern'),
          ),
        ],
      ),
    ),
  );
}
