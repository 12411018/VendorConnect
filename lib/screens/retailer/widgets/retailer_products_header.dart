import 'package:flutter/material.dart';

class RetailerProductsHeader extends StatelessWidget {
  const RetailerProductsHeader({
    super.key,
    required this.summaryText,
    required this.productCount,
    required this.searchController,
    required this.categoryValue,
    required this.categoryOptions,
    required this.typeValue,
    required this.typeOptions,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onTypeChanged,
    this.onActionPressed,
    this.actionLabel,
  });

  final String summaryText;
  final int productCount;
  final TextEditingController searchController;
  final String categoryValue;
  final List<String> categoryOptions;
  final String typeValue;
  final List<String> typeOptions;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onTypeChanged;
  final VoidCallback? onActionPressed;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search by product name or SKU',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildFilterDropdown(
                label: 'Category',
                value: categoryValue,
                values: categoryOptions,
                onChanged: onCategoryChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildFilterDropdown(
                label: 'Type',
                value: typeValue,
                values: typeOptions,
                onChanged: onTypeChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                summaryText,
                style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
              ),
            ),
            if (onActionPressed != null)
              IconButton.filledTonal(
                onPressed: onActionPressed,
                icon: const Icon(Icons.refresh),
                tooltip: actionLabel ?? 'Action',
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) {
    final selectedValue = values.contains(value) ? value : 'All';

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedValue,
          items: values
              .map(
                (item) =>
                    DropdownMenuItem<String>(value: item, child: Text(item)),
              )
              .toList(),
          onChanged: (selected) {
            if (selected == null) {
              return;
            }
            onChanged(selected);
          },
        ),
      ),
    );
  }
}
