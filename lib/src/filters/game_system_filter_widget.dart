import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quest_cards/src/filters/filter_state.dart';
import 'package:quest_cards/src/models/standard_game_system.dart';
import 'package:quest_cards/src/util/utils.dart'; // Import Utils for icons
import 'package:collection/collection.dart'; // Import for listEquals, firstWhereOrNull

// Enum to represent checkbox state (for tristate)
enum CheckboxState { selected, partial, unselected }

/// A specialized filter widget for game systems that supports the standardization process
///
/// This widget provides a hierarchical view of game systems and their editions,
/// using standardized game system data.
class GameSystemFilterWidget extends StatefulWidget {
  const GameSystemFilterWidget({super.key});

  @override
  State<GameSystemFilterWidget> createState() => _GameSystemFilterWidgetState();
}

class _GameSystemFilterWidgetState extends State<GameSystemFilterWidget> {
  // Store selected system name and edition names
  List<String> _selectedSystemNames = [];
  // Track expanded state for each system
  Map<String, bool> _systemExpansionState = {}; // Removed final

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

    // Initialize selection state from FilterProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialSelection();
    });
  }

  void _loadInitialSelection() {
    if (!mounted) return;
    final filterProvider = Provider.of<FilterProvider>(context, listen: false);
    final filters = filterProvider.filterState.filters;

    final systemFilter =
        filters.firstWhereOrNull((f) => f.field == 'standardizedGameSystem');
    final editionFilter = filters.firstWhereOrNull((f) => f.field == 'edition');

    List<String> newSelectedNames = [];
    Map<String, bool> newSystemExpansionState = {};

    if (systemFilter != null &&
        systemFilter.value is String &&
        editionFilter != null &&
        editionFilter.value is String) {
      // Case: System AND Edition are selected
      String systemName = systemFilter.value as String;
      String editionShortNameValue = editionFilter.value as String;

      final systemData = filterProvider.getSystemByName(systemName);
      if (systemData != null) {
        newSelectedNames.add(systemName); // Add parent system name

        // Try to find the full edition name based on the short name
        final editionData = systemData.editions.firstWhereOrNull((ed) {
          String currentEditionShortName = ed.name;
          if (ed.name.startsWith(systemName)) {
            currentEditionShortName =
                ed.name.substring(systemName.length).trim();
          }
          return currentEditionShortName == editionShortNameValue;
        });

        if (editionData != null) {
          newSelectedNames.add(editionData.name); // Add full edition name
          newSystemExpansionState[systemName] = true; // Expand parent
        }
      }
    } else if (systemFilter != null) {
      // Case: Only system(s) selected (value could be String for 'equals' or List for 'whereIn')
      if (systemFilter.value is String) {
        final systemName = systemFilter.value as String;
        newSelectedNames.add(systemName);
        // Check if this system (which might be an edition's full name) should expand its parent
        for (var system_iter in filterProvider.standardGameSystems) {
          if (system_iter.editions.any((ed) => ed.name == systemName)) {
            newSystemExpansionState[system_iter.standardName] = true;
            break;
          }
        }
      } else if (systemFilter.value is List) {
        newSelectedNames = List<String>.from(systemFilter.value as List);
        for (var nameInSelection in newSelectedNames) {
          // Check if this name (which might be an edition's full name) should expand its parent
          for (var system_iter in filterProvider.standardGameSystems) {
            if (system_iter.editions.any((ed) => ed.name == nameInSelection)) {
              newSystemExpansionState[system_iter.standardName] = true;
              break;
            }
          }
        }
      }
    }

    // Deduplicate newSelectedNames just in case
    newSelectedNames = newSelectedNames.toSet().toList();

    setState(() {
      _selectedSystemNames = newSelectedNames;
      _systemExpansionState = newSystemExpansionState;
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
    // Access the cached list directly using the getter
    final standardSystems = filterProvider.standardGameSystems;

    // Re-check selection state if filters change externally
    // Use the correct getter
    final currentFilter = filterProvider.filterState.filters
        .firstWhereOrNull((f) => f.field == 'standardizedGameSystem');
    List<String> currentSelectedNames = [];
    if (currentFilter != null && currentFilter.value is List) {
      currentSelectedNames = List<String>.from(currentFilter.value);
    }
    // Basic check to see if external state differs from internal
    // Use the imported listEquals from package:collection
    if (!const ListEquality()
        .equals(_selectedSystemNames, currentSelectedNames)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadInitialSelection();
      });
    }

    // Filter systems based on search query
    final filteredSystems = standardSystems.where((system) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery;
      // Check standard name, aliases, and editions
      return system.standardName.toLowerCase().contains(query) ||
          system.aliases.any((alias) => alias.toLowerCase().contains(query)) ||
          system.editions
              .any((edition) => edition.name.toLowerCase().contains(query));
    }).toList();

    // Sort systems alphabetically for display
    filteredSystems.sort((a, b) => a.standardName.compareTo(b.standardName));

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1, // Reduced elevation
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Game System',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600, // Slightly bolder title
                  ),
            ),
            const SizedBox(height: 8),

            // Search bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search systems or editions...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  // Lighter border when enabled
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  // Theme color border when focused
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                isDense: true, // Make it more compact
              ),
            ),
            const SizedBox(height: 12),

            // Game Systems List
            // Removed isLoadingFilterOptions check
            if (standardSystems
                .isEmpty) // Check if systems list is empty as a proxy
              const Center(child: CircularProgressIndicator())
            else if (filteredSystems.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No game systems found'),
                ),
              )
            else
              // Use a constrained box for the list if it gets too long
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.of(context).size.height * 0.4, // Limit height
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: filteredSystems.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final system = filteredSystems[index];
                    return buildGameSystemTile(system, filterProvider);
                  },
                ),
              ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.end, // Align buttons to the right
              children: [
                TextButton(
                  // Use TextButton for less emphasis on Clear
                  onPressed: (_selectedSystemNames.isEmpty)
                      ? null
                      : () {
                          // Disable if nothing selected
                          // Clear game system filters using the correct method
                          filterProvider.removeFilter('standardizedGameSystem');
                          filterProvider.removeFilter(
                              'edition'); // Also remove edition filter
                          // _selectedSystemNames will be cleared by _loadInitialSelection due to provider update
                        },
                  child: const Text('Clear Selection'),
                ),
                // Apply button removed - selection applies instantly via checkboxes
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build a tile for a single game system, potentially expandable for editions.
  Widget buildGameSystemTile(
      StandardGameSystem system, FilterProvider filterProvider) {
    final bool isSelected = _selectedSystemNames.contains(system.standardName);
    final bool hasEditions = system.editions.isNotEmpty;
    final bool isExpanded = _systemExpansionState[system.standardName] ?? false;

    // Determine checkbox state: selected, partially selected (editions), or unselected
    CheckboxState checkboxState = CheckboxState.unselected;
    int selectedEditionCount = 0;
    if (hasEditions) {
      selectedEditionCount = system.editions
          .where((ed) => _selectedSystemNames.contains(ed.name))
          .length;
    }

    if (isSelected) {
      // Main system is selected
      if (!hasEditions || selectedEditionCount == system.editions.length) {
        checkboxState = CheckboxState
            .selected; // Selected, and no editions or all editions selected
      } else {
        checkboxState = CheckboxState
            .partial; // Selected, but not all editions selected (or none explicitly)
      }
    } else {
      // Main system not selected
      if (hasEditions && selectedEditionCount > 0) {
        checkboxState =
            CheckboxState.partial; // Not selected, but some editions are
      } else {
        checkboxState =
            CheckboxState.unselected; // Not selected, no editions selected
      }
    }

    Widget titleWidget = Row(
      children: [
        // Icon
        CircleAvatar(
          backgroundImage: Utils.getSystemIcon(system.standardName),
          radius: 12,
          backgroundColor:
              Colors.transparent, // Avoid default color if icon fails
        ),
        const SizedBox(width: 12),
        // Name
        Expanded(
          child: Text(
            system.standardName,
            style: TextStyle(
              // Adjust font weight based on any selection (system or edition)
              fontWeight: (checkboxState != CheckboxState.unselected)
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
        ),
      ],
    );

    // Define the action for tapping the main checkbox/row
    VoidCallback toggleSystemSelection = () {
      setState(() {
        bool currentlySelectedOrPartial =
            checkboxState != CheckboxState.unselected;
        if (currentlySelectedOrPartial) {
          // Deselect system and all its editions
          _selectedSystemNames.remove(system.standardName);
          for (var edition in system.editions) {
            _selectedSystemNames.remove(edition.name);
          }
          _systemExpansionState
              .remove(system.standardName); // Collapse on deselect
        } else {
          // Select system
          _selectedSystemNames.add(system.standardName);
          // Select all editions when selecting the parent?
          // Let's keep it simple: only select the parent system itself.
          // User can expand and select editions individually.
          // for (var edition in system.editions) {
          //    if (!_selectedSystemNames.contains(edition.name)) {
          //       _selectedSystemNames.add(edition.name);
          //    }
          // }
          if (hasEditions) {
            _systemExpansionState[system.standardName] =
                true; // Expand on select
          }
        }
        _applyFilters(filterProvider);
      });
    };

    if (!hasEditions) {
      // Simple CheckboxListTile if no editions
      return CheckboxListTile(
        value: isSelected,
        onChanged: (bool? value) {
          toggleSystemSelection(); // Use the defined toggle action
        },
        title: titleWidget,
        controlAffinity: ListTileControlAffinity.leading, // Checkbox on left
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      );
    } else {
      // Use ExpansionTile if editions exist
      return ExpansionTile(
        key: PageStorageKey(system.standardName), // Preserve state on scroll
        title: titleWidget,
        initiallyExpanded: isExpanded,
        onExpansionChanged: (expanding) {
          // Only toggle expansion state, don't change selection here
          setState(() {
            _systemExpansionState[system.standardName] = expanding;
          });
        },
        leading: Checkbox(
          value: checkboxState == CheckboxState.selected
              ? true
              : (checkboxState == CheckboxState.partial ? null : false),
          tristate: true, // Allow partial state
          onChanged: (bool? value) {
            // Toggling the main checkbox selects/deselects the system and its editions
            toggleSystemSelection();
          },
        ),
        // Use expansion arrow for visual cue, handle expansion via onExpansionChanged
        // trailing: const SizedBox.shrink(), // Keep default trailing icon
        tilePadding: const EdgeInsets.only(
            left: 0, right: 16, top: 0, bottom: 0), // Adjust padding
        childrenPadding: const EdgeInsets.only(
            left: 40, bottom: 8, right: 16), // Indent editions
        children: system.editions.map((GameSystemEdition edition) {
          return buildEditionTile(system, edition, filterProvider);
        }).toList(),
      );
    }
  }

  /// Build a tile for a single edition under a game system.
  // Ensure GameSystemEdition type is correctly referenced from the imported model
  Widget buildEditionTile(StandardGameSystem system, GameSystemEdition edition,
      FilterProvider filterProvider) {
    final bool isSelected = _selectedSystemNames.contains(edition.name);

    return CheckboxListTile(
      value: isSelected,
      onChanged: (bool? value) {
        setState(() {
          if (value == true) {
            // Select edition
            _selectedSystemNames.add(edition.name);
            // Ensure parent system is added if not already selected
            if (!_selectedSystemNames.contains(system.standardName)) {
              _selectedSystemNames.add(system.standardName);
            }
          } else {
            // Deselect edition
            _selectedSystemNames.remove(edition.name);
            // Check if this was the last selected item for this parent (edition or parent itself)
            bool anyOtherEditionSelected = system.editions
                .any((ed) => _selectedSystemNames.contains(ed.name));
            if (!anyOtherEditionSelected &&
                !_selectedSystemNames.contains(system.standardName)) {
              // If deselecting the last edition AND the parent isn't selected, ensure parent is removed
              // This case shouldn't happen with current logic, but good for robustness
              _selectedSystemNames.remove(system.standardName);
            }
            // If the parent IS selected, deselecting the last edition makes the parent state partial (handled by checkboxState logic)
          }
          _applyFilters(filterProvider);
        });
      },
      title: Text(
        edition.name + (edition.year != null ? ' (${edition.year})' : ''),
        style: const TextStyle(fontSize: 14),
      ),
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
    );
  }

  /// Apply the current selections to the FilterProvider.
  void _applyFilters(FilterProvider filterProvider) {
    filterProvider.removeFilter('standardizedGameSystem');
    filterProvider.removeFilter('edition');

    // Use a Set for uniqueSeletedNames to avoid processing duplicates
    final uniqueSelectedNames = _selectedSystemNames.toSet();

    if (uniqueSelectedNames.isEmpty) {
      // Notifying listeners is handled by FilterProvider/FilterState methods
      return;
    }

    Set<String> involvedParentSystems = {};
    // Map: ParentSystemName -> List of ShortEditionNames
    Map<String, List<String>> specificEditions = {};
    List<StandardGameSystem> allSystems = filterProvider.standardGameSystems;

    for (String selectedName in uniqueSelectedNames) {
      bool foundAsEdition = false;
      for (var system in allSystems) {
        // Check if selectedName is an edition of the current system
        var editionMatch =
            system.editions.firstWhereOrNull((ed) => ed.name == selectedName);

        if (editionMatch != null) {
          involvedParentSystems.add(system.standardName);

          // Derive short edition name
          String shortEditionName = selectedName; // Default to the full name
          if (selectedName.startsWith(system.standardName)) {
            // If full name starts with parent name, strip parent name part
            shortEditionName =
                selectedName.substring(system.standardName.length).trim();
          }

          // Only add to specificEditions if a non-empty short name is derived
          if (shortEditionName.isNotEmpty) {
            specificEditions
                .putIfAbsent(system.standardName, () => [])
                .add(shortEditionName);
          }
          // If shortEditionName is empty (e.g., edition name was identical to system name),
          // it's not added as a specific edition filter, but the parent system is still included.

          foundAsEdition = true;
          break; // Found as edition, no need to check other systems for this selectedName
        }
      }

      if (!foundAsEdition) {
        // If not found as an edition, check if it's a known main system name
        if (allSystems.any((sys) => sys.standardName == selectedName)) {
          involvedParentSystems.add(selectedName);
        }
      }
    }

    if (involvedParentSystems.isEmpty) {
      // No known systems or editions were part of the selection
      return;
    }

    if (involvedParentSystems.length == 1) {
      String parentSystem = involvedParentSystems.first;
      filterProvider.addFilter(
          'standardizedGameSystem', parentSystem, FilterOperator.equals);

      // Check if there are specific editions selected for this single parent system
      if (specificEditions.containsKey(parentSystem)) {
        List<String> editionsForThisParent = specificEditions[parentSystem]!;
        if (editionsForThisParent.length == 1) {
          filterProvider.addFilter(
              'edition', editionsForThisParent.first, FilterOperator.equals);
        } else if (editionsForThisParent.length > 1) {
          filterProvider.addFilter(
              'edition', editionsForThisParent, FilterOperator.whereIn);
        }
        // If editionsForThisParent is empty (e.g., all derived short names were empty), no edition filter is added.
      }
    } else {
      // involvedParentSystems.length > 1
      // Multiple parent systems involved, use OR logic for systems
      filterProvider.addFilter('standardizedGameSystem',
          involvedParentSystems.toList(), FilterOperator.whereIn);
      // No specific 'edition' filter is applied when ORing across multiple different game systems.
    }
    // FilterProvider methods now notify listeners via FilterState listener
  }
}

// Helper function for comparing lists (moved outside the class)
// Use ListEquality from package:collection instead
// bool listEquals<T>(List<T>? a, List<T>? b) {
//   if (a == null) return b == null;
//   if (b == null || a.length != b.length) return false;
//   if (identical(a, b)) return true;
//   for (int index = 0; index < a.length; index += 1) {
//     if (a[index] != b[index]) return false;
//   }
//   return true;
// }
