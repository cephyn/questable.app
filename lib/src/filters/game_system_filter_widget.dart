import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quest_cards/src/filters/filter_state.dart';
import 'package:quest_cards/src/models/standard_game_system.dart';

/// A specialized filter widget for game systems that supports the standardization process
///
/// This widget provides a hierarchical view of game systems and their editions,
/// with special handling for standardized game systems.
class GameSystemFilterWidget extends StatefulWidget {
  const GameSystemFilterWidget({super.key});

  @override
  State<GameSystemFilterWidget> createState() => _GameSystemFilterWidgetState();
}

class _GameSystemFilterWidgetState extends State<GameSystemFilterWidget> {
  bool _isExpanded = false;
  String? _selectedGameSystem;
  List<String>? _selectedEditions;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filterProvider = Provider.of<FilterProvider>(context);
    final standardSystems = filterProvider.standardGameSystems;

    // Check for any existing game system filter
    final existingSystemFilter =
        filterProvider.filterState.getFilterForField('gameSystem');
    if (existingSystemFilter != null && _selectedGameSystem == null) {
      _selectedGameSystem = existingSystemFilter.value is List
          ? null // Multiple systems selected, don't show a single selected system
          : existingSystemFilter.value.toString();
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with expand/collapse functionality
            InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Game System',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                ],
              ),
            ),

            // Current selection summary (when collapsed)
            if (!_isExpanded && existingSystemFilter != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  children: [
                    Chip(
                      label: Text(
                        existingSystemFilter.value is List
                            ? '${(existingSystemFilter.value as List).length} systems selected'
                            : existingSystemFilter.value.toString(),
                        style: const TextStyle(fontSize: 12),
                      ),
                      onDeleted: () {
                        filterProvider.removeFilter('gameSystem');
                        setState(() {
                          _selectedGameSystem = null;
                          _selectedEditions = null;
                        });
                      },
                    ),
                  ],
                ),
              ),

            // Expanded filter options
            if (_isExpanded) ...[
              const SizedBox(height: 8),
              // Search bar for filtering systems
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search game systems...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                ),
              ),
              const SizedBox(height: 16),

              // Game Systems List with Icons
              ...buildGameSystemsList(standardSystems, filterProvider),

              const SizedBox(height: 16),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      // Clear game system filters
                      filterProvider.removeFilter('gameSystem');
                      setState(() {
                        _selectedGameSystem = null;
                        _selectedEditions = null;
                      });
                    },
                    child: const Text('Clear'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isExpanded = false;
                      });
                    },
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build the list of game systems with their editions
  List<Widget> buildGameSystemsList(
      List<StandardGameSystem> systems, FilterProvider filterProvider) {
    // Filter systems based on search query
    final filteredSystems = systems.where((system) {
      if (_searchQuery.isEmpty) return true;

      // Check if system name contains the search query
      if (system.standardName.toLowerCase().contains(_searchQuery)) {
        return true;
      }

      // Check if any alias contains the search query
      for (final alias in system.aliases) {
        if (alias.toLowerCase().contains(_searchQuery)) {
          return true;
        }
      }

      // Check if any edition contains the search query
      for (final edition in system.editions) {
        if (edition.name.toLowerCase().contains(_searchQuery)) {
          return true;
        }
      }

      return false;
    }).toList();

    if (filteredSystems.isEmpty) {
      return [
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No game systems found'),
          ),
        ),
      ];
    }

    return filteredSystems.map((system) {
      final isSelected = _selectedGameSystem == system.standardName;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Game System Row
          InkWell(
            onTap: () {
              setState(() {
                if (_selectedGameSystem == system.standardName) {
                  // Deselect if already selected
                  _selectedGameSystem = null;
                  _selectedEditions = null;
                  filterProvider.removeFilter('gameSystem');
                } else {
                  // Select this system
                  _selectedGameSystem = system.standardName;
                  _selectedEditions = null;

                  // Apply filter for this game system
                  filterProvider.addFilter(
                    'gameSystem',
                    system.standardName,
                    FilterOperator.equals,
                  );
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  // Game system icon if available
                  if (system.icon != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Image.asset(
                        'assets/icons/${system.icon}',
                        width: 24,
                        height: 24,
                        errorBuilder: (context, error, stackTrace) {
                          return const SizedBox(width: 24, height: 24);
                        },
                      ),
                    ),

                  Expanded(
                    child: Text(
                      system.standardName,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),

                  // Selection indicator
                  if (isSelected)
                    const Icon(Icons.check, color: Colors.green)
                  else if (system.editions.isNotEmpty)
                    const Icon(Icons.arrow_forward_ios, size: 16)
                ],
              ),
            ),
          ),

          // Show editions if this system is selected and has editions
          if (isSelected && system.editions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: buildEditionsList(system, filterProvider),
            ),

          const Divider(),
        ],
      );
    }).toList();
  }

  /// Build the list of editions for a selected game system
  Widget buildEditionsList(
      StandardGameSystem system, FilterProvider filterProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Text(
            'Editions:',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        ...system.editions.map((edition) {
          final isSelected = _selectedEditions?.contains(edition.name) ?? false;

          return InkWell(
            onTap: () {
              setState(() {
                _selectedEditions ??= [];

                if (isSelected) {
                  // Remove this edition
                  _selectedEditions!.remove(edition.name);
                  if (_selectedEditions!.isEmpty) {
                    _selectedEditions = null;
                  }
                } else {
                  // Add this edition
                  _selectedEditions!.add(edition.name);
                }

                // Apply filter for editions if we have selections
                if (_selectedEditions != null &&
                    _selectedEditions!.isNotEmpty) {
                  filterProvider.addFilter(
                    'edition',
                    _selectedEditions,
                    FilterOperator.whereIn,
                  );
                } else {
                  filterProvider.removeFilter('edition');
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      edition.name +
                          (edition.year != null ? ' (${edition.year})' : ''),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),

                  // Selection checkbox
                  Icon(
                    isSelected
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 18,
                    color: isSelected ? Colors.green : Colors.grey,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// Widget to display a game system with its icon
class GameSystemWithIcon extends StatelessWidget {
  final StandardGameSystem system;
  final bool selected;
  final VoidCallback onTap;

  const GameSystemWithIcon({
    super.key,
    required this.system,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            // Game system icon
            if (system.icon != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Image.asset(
                  'assets/icons/${system.icon}',
                  width: 24,
                  height: 24,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox(width: 24, height: 24);
                  },
                ),
              ),

            // Game system name
            Expanded(
              child: Text(
                system.standardName,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),

            // Selection indicator
            if (selected) const Icon(Icons.check, color: Colors.green)
          ],
        ),
      ),
    );
  }
}
