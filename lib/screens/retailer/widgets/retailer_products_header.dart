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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0B1325), Color(0xFF172554)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1E3A8A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$productCount products live in marketplace',
                style: const TextStyle(
                  color: Color(0xFFBFDBFE),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                summaryText,
                style: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search by product name, category, or type',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF1E293B)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF1E293B)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF3B82F6),
                width: 1.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
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
