import 'package:flutter/material.dart';

const taskCategories = [
  'After Sales',
  'Portfolio Management',
  'Prospection',
  'Order Delivery',
  'Bike Build',
  'Bike Repair',
  'Recycling',
  'Clean Workshop & Vehicles',
  'Project Work',
  'Administration',
];

class TaskCategoryPicker extends StatelessWidget {
  const TaskCategoryPicker({
    super.key,
    required this.selectedCategory,
    required this.onSelected,
    this.enabled = true,
    this.categories = taskCategories,
  });

  final String? selectedCategory;
  final ValueChanged<String> onSelected;
  final bool enabled;
  final List<String> categories;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final category in categories)
          ChoiceChip(
            showCheckmark: false,
            label: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: (constraints.maxWidth - 40).clamp(
                  1.0,
                  double.infinity,
                ),
              ),
              child: Text(category, maxLines: 3, softWrap: true),
            ),
            selected: selectedCategory == category,
            onSelected: enabled ? (_) => onSelected(category) : null,
          ),
      ],
    ),
  );
}

class CategoryEditor extends StatefulWidget {
  const CategoryEditor({super.key, required this.categories});
  final List<String> categories;

  @override
  State<CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<CategoryEditor> {
  late final List<TextEditingController> fields;
  final retired = <TextEditingController>[];
  String? error;

  @override
  void initState() {
    super.initState();
    fields = widget.categories
        .map((name) => TextEditingController(text: name))
        .toList();
  }

  @override
  void dispose() {
    for (final field in [...fields, ...retired]) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
      24,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Edit quick categories',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Existing time entries keep their recorded category names.',
          ),
          const SizedBox(height: 16),
          for (final field in fields)
            Padding(
              key: ObjectKey(field),
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: field,
                      decoration: const InputDecoration(
                        labelText: 'Category name',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove category',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() {
                      fields.remove(field);
                      retired.add(field);
                      error = null;
                    }),
                  ),
                ],
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => setState(() {
              fields.add(TextEditingController());
              error = null;
            }),
            icon: const Icon(Icons.add),
            label: const Text('Add category'),
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              final names = fields.map((field) => field.text.trim()).toList();
              if (names.isEmpty || names.any((name) => name.isEmpty)) {
                setState(
                  () => error =
                      'Enter at least one category and fill in every name.',
                );
                return;
              }
              if (names.map((name) => name.toLowerCase()).toSet().length !=
                  names.length) {
                setState(() => error = 'Category names must be unique.');
                return;
              }
              Navigator.pop(context, names);
            },
            child: const Text('Save categories'),
          ),
        ],
      ),
    ),
  );
}
