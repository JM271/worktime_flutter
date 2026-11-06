import 'package:flutter/material.dart';

import 'app_style.dart';

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

/// Columns for [count] category tiles in [width] logical pixels (already
/// divided by the text scale). Tiles need ~140px so names don't break
/// mid-word; among fitting layouts, one that fills every row is preferred.
int categoryColumns(int count, double width) {
  final most = (width / 140).floor().clamp(1, 3);
  for (var columns = most; columns >= 2 && columns >= most - 1; columns--) {
    if (count % columns == 0) return columns;
  }
  return most;
}

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
    builder: (context, constraints) {
      const gap = 8.0;
      final columns = categoryColumns(
        categories.length,
        constraints.maxWidth / MediaQuery.textScalerOf(context).scale(1),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var row = 0; row < categories.length; row += columns)
            Padding(
              padding: EdgeInsets.only(top: row == 0 ? 0 : gap),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // A short last row stretches its tiles to fill the width.
                    for (
                      var i = row;
                      i < row + columns && i < categories.length;
                      i++
                    ) ...[
                      if (i > row) const SizedBox(width: gap),
                      Expanded(
                        child: CategoryTile(
                          label: categories[i],
                          selected: selectedCategory == categories[i],
                          onTap: enabled
                              ? () => onSelected(categories[i])
                              : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// One selectable quick category: an even, finger-sized tile that turns
/// black with a check mark when selected.
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final foreground = selected
        ? Colors.white
        : enabled
        ? AppColors.text
        : AppColors.muted;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected
            ? AppColors.text
            : enabled
            ? AppColors.surface
            : AppColors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected ? AppColors.text : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  if (selected) ...[
                    const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
      16,
      16,
      16,
      MediaQuery.viewInsetsOf(context).bottom + 16,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Edit quick categories',
            style: TextStyle(fontFamily: appDisplayFontFamily, fontSize: 17),
          ),
          const SizedBox(height: 8),
          const Text(
            'Existing time entries keep their recorded category names.',
          ),
          const SizedBox(height: 10),
          for (final field in fields)
            Padding(
              key: ObjectKey(field),
              padding: const EdgeInsets.only(bottom: 8),
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
          const SizedBox(height: 8),
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
