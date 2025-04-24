import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'filter_state.dart';

/// A widget that displays currently active filters as chips.
/// Each chip can be tapped to remove its filter.
class ActiveFilterChips extends StatelessWidget {
  const ActiveFilterChips({super.key});

  @override
  Widget build(BuildContext context) {
    final filterProvider = Provider.of<FilterProvider>(context);
    final filterState = filterProvider.filterState;

    if (!filterState.hasFilters) {
      return const SizedBox.shrink(); // Hide when no filters are active
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Filters',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              TextButton.icon(
                icon: Icon(Icons.clear_all, size: 16),
                label: const Text('Clear All'),
                onPressed: () => filterProvider.clearFilters(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: filterState.filters.map((criteria) {
              // Get human-readable display name for the field
              String fieldDisplay =
                  FilterProvider.fieldDisplayNames[criteria.field] ??
                      criteria.field.replaceFirst(
                          criteria.field[0], criteria.field[0].toUpperCase());

              // Format the value for display
              String valueDisplay = _formatValueForDisplay(criteria.value);

              return FilterChip(
                label: Text('$fieldDisplay: $valueDisplay'),
                onSelected: (_) => filterProvider.removeFilter(criteria.field),
                onDeleted: () => filterProvider.removeFilter(criteria.field),
                deleteIcon: const Icon(Icons.close, size: 16),
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _formatValueForDisplay(dynamic value) {
    if (value is List) {
      if (value.isEmpty) return '';
      return value.join(', ');
    } else if (value is DateTime) {
      return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    } else {
      return value.toString();
    }
  }
}
