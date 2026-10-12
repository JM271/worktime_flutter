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
  });

  final String? selectedCategory;
  final ValueChanged<String> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final category in taskCategories)
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
