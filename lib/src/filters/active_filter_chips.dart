import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'filter_state.dart';
import '../models/standard_game_system.dart'; // Import StandardGameSystem

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
              // Generate human-readable display name by capitalizing the field
              String fieldDisplay = criteria.field.replaceFirst(
                  criteria.field[0], criteria.field[0].toUpperCase());

              // Format the value for display - Special handling for gameSystem
              String valueDisplay;
              String? tooltipMessage;

              // Use standardizedGameSystem field name consistently for display
              if (criteria.field == 'gameSystem' ||
                  criteria.field == 'standardizedGameSystem') {
                fieldDisplay = 'Game System'; // Use consistent display name

                if (criteria.value is String) {
                  // Attempt to find the standard system based on the filter value
                  StandardGameSystem? system =
                      filterProvider.getSystemByName(criteria.value);
                  if (system != null) {
                    // Always display the standard name if found
                    valueDisplay = system.standardName;
                    // Provide tooltip showing original value if it differs from standard name
                    if (system.standardName != criteria.value) {
                      tooltipMessage =
                          'Original: ${criteria.value}\nStandard: ${system.standardName}';
                    } else {
                      tooltipMessage = system
                          .standardName; // Tooltip shows standard name if no difference
                    }
                  } else {
                    // If no standard system found, display the original value and indicate it
                    valueDisplay = criteria.value;
                    tooltipMessage =
                        'Original value (not standardized): ${criteria.value}';
                  }
                } else if (criteria.value is List) {
                  // Handle list of game systems (e.g., from whereIn)
                  List<String> systemNames =
                      (criteria.value as List).cast<String>();
                  valueDisplay = '${systemNames.length} systems';
                  // Tooltip lists all selected systems
                  tooltipMessage = systemNames.map((name) {
                    StandardGameSystem? system =
                        filterProvider.getSystemByName(name);
                    return system?.standardName ??
                        name; // Show standard name if possible
                  }).join(', ');
                } else {
                  // Fallback for unexpected value types
                  valueDisplay = _formatValueForDisplay(criteria.value);
                  tooltipMessage = valueDisplay;
                }
              } else {
                // Handle non-game system filters
                valueDisplay = _formatValueForDisplay(criteria.value);
                tooltipMessage =
                    '$fieldDisplay: $valueDisplay'; // Default tooltip
              }

              return Tooltip(
                // Wrap FilterChip in a Tooltip
                message:
                    tooltipMessage, // Tooltip message is always non-null here
                child: FilterChip(
                  label: Text('$fieldDisplay: $valueDisplay'),
                  onSelected: (_) =>
                      filterProvider.removeFilter(criteria.field),
                  // Use onDeleted for the visual delete icon action
                  onDeleted: () => filterProvider.removeFilter(criteria.field),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
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
      // Limit displayed items in chip for lists
      const maxItemsToShow = 2;
      if (value.length > maxItemsToShow) {
        return '${value.take(maxItemsToShow).join(', ')}... (${value.length})';
      }
      return value.join(', ');
    } else if (value is DateTime) {
      return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    } else {
      return value.toString();
    }
  }
}
