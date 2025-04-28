import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'filter_state.dart';
import 'game_system_filter_widget.dart';

/// A drawer widget that allows users to apply filters to quest cards
class FilterDrawer extends StatefulWidget {
  final bool isAuthenticated;

  const FilterDrawer({
    super.key,
    this.isAuthenticated = false,
  });

  @override
  State<FilterDrawer> createState() => _FilterDrawerState();
}

class _FilterDrawerState extends State<FilterDrawer> {
  // Track expanded state for multi-select filters
  final Map<String, bool> _expandedFilters = {};

  // Controller for saved filter name input
  final TextEditingController _saveFilterNameController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load filter options when the drawer is first opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final filterProvider =
          Provider.of<FilterProvider>(context, listen: false);
      filterProvider.loadFilterOptions();
    });
  }

  @override
  void dispose() {
    _saveFilterNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filterProvider = Provider.of<FilterProvider>(context);

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDrawerHeader(context),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Saved Filters Section
                  _buildFilterSection(
                    context: context,
                    title: 'Saved Filters',
                    icon: Icons.bookmark,
                    children: _buildSavedFiltersSection(filterProvider),
                  ),

                  const Divider(),

                  // Game System Section
                  _buildFilterSection(
                    context: context,
                    title: 'Game System',
                    icon: Icons.games,
                    children: _buildGameSystemFilters(filterProvider),
                  ),

                  const Divider(),

                  // Content Type Section
                  _buildFilterSection(
                    context: context,
                    title: 'Content',
                    icon: Icons.category,
                    children: _buildContentFilters(filterProvider),
                  ),

                  const Divider(),

                  // Publication Section
                  _buildFilterSection(
                    context: context,
                    title: 'Publication',
                    icon: Icons.book,
                    children: _buildPublicationFilters(filterProvider),
                  ),

                  // Creator Section (authenticated only)
                  if (widget.isAuthenticated) ...[
                    const Divider(),
                    _buildFilterSection(
                      context: context,
                      title: 'Creator',
                      icon: Icons.person,
                      children: _buildCreatorFilters(filterProvider),
                    ),
                  ],
                ],
              ),
            ),

            // Bottom Action Buttons
            _buildActionButtons(context, filterProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.filter_list,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 16),
          Text(
            'Filter Quests',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return ExpansionTile(
      title: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      initiallyExpanded: true,
      childrenPadding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      children: children,
    );
  }

  List<Widget> _buildSavedFiltersSection(FilterProvider provider) {
    final savedFilters = provider.savedFilterSets;

    return [
      // List of saved filter sets
      if (savedFilters.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12.0),
          child: Text(
              'No saved filters yet. Apply filters and save them for quick access.'),
        )
      else
        ...savedFilters.entries.map(
            (entry) => _buildSavedFilterItem(provider, entry.key, entry.value)),

      const SizedBox(height: 16),

      // Save current filters button
      if (provider.filterState.hasFilters)
        ElevatedButton.icon(
          icon: const Icon(Icons.save),
          label: const Text('Save Current Filters'),
          onPressed: () => _showSaveFilterDialog(context, provider),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
    ];
  }

  Widget _buildSavedFilterItem(
      FilterProvider provider, String name, List<FilterCriteria> filters) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        title: Text(name),
        subtitle: Text(
          '${filters.length} filter${filters.length == 1 ? '' : 's'}',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        leading: const Icon(Icons.filter_list),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () =>
                  _confirmDeleteSavedFilter(context, provider, name),
              tooltip: 'Delete',
            ),
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              onPressed: () {
                provider.applySavedFilters(name);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Applied filter set: $name')),
                );
              },
              tooltip: 'Apply',
            ),
          ],
        ),
        onTap: () {
          provider.applySavedFilters(name);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Applied filter set: $name')),
          );
        },
      ),
    );
  }

  Future<void> _showSaveFilterDialog(
      BuildContext context, FilterProvider provider) async {
    _saveFilterNameController.clear();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Save Filter Set'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Give this filter set a name so you can easily apply it later.'),
              const SizedBox(height: 16),
              TextField(
                controller: _saveFilterNameController,
                decoration: const InputDecoration(
                  labelText: 'Filter Set Name',
                  hintText: 'e.g., "D&D 5e Adventures" or "Low Level Quests"',
                ),
                autofocus: true,
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('CANCEL'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('SAVE'),
              onPressed: () async {
                final name = _saveFilterNameController.text.trim();
                if (name.isNotEmpty) {
                  final success = await provider.saveCurrentFilters(name);
                  Navigator.of(context).pop();

                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Saved filter set: $name')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Failed to save filter set')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Please enter a name for the filter set')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteSavedFilter(
    BuildContext context,
    FilterProvider provider,
    String name,
  ) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Saved Filter?'),
          content: Text(
              'Are you sure you want to delete "$name"? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('CANCEL'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('DELETE'),
              onPressed: () async {
                final success = await provider.deleteSavedFilterSet(name);
                Navigator.of(context).pop();

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Deleted filter set: $name')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Failed to delete filter set')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildGameSystemFilters(FilterProvider provider) {
    // Use the specialized GameSystemFilterWidget
    return [
      const GameSystemFilterWidget(),
    ];
  }

  List<Widget> _buildContentFilters(FilterProvider provider) {
    return [
      // Level Range Filter
      _buildRangeFilter(
        provider: provider,
        field: 'level',
        label: 'Character Level',
      ),
      const SizedBox(height: 16),

      // Environment Filter (multi-select)
      _buildMultiSelectFilter(
        provider: provider,
        field: 'environments',
        label: 'Environments',
        options: provider.filterOptions['environments'] ?? [],
        placeholder: 'Select Environments',
      ),
      const SizedBox(height: 16),

      // Genre Filter
      _buildDropdownFilter(
        provider: provider,
        field: 'genre',
        label: 'Genre',
        options: provider.filterOptions['genre'] ?? [],
        placeholder: 'All Genres',
      ),
      const SizedBox(height: 16),

      // Setting Filter
      _buildDropdownFilter(
        provider: provider,
        field: 'setting',
        label: 'Setting',
        options: provider.filterOptions['setting'] ?? [],
        placeholder: 'All Settings',
      ),
    ];
  }

  List<Widget> _buildPublicationFilters(FilterProvider provider) {
    return [
      // Publisher Filter
      _buildDropdownFilter(
        provider: provider,
        field: 'publisher',
        label: 'Publisher',
        options: provider.filterOptions['publisher'] ?? [],
        placeholder: 'All Publishers',
      ),
      const SizedBox(height: 16),

      // Authors Filter
      _buildTextFilter(
        provider: provider,
        field: 'authors',
        label: 'Authors',
        hint: 'Filter by author name',
        operator: FilterOperator.arrayContains,
      ),

      // Publication Year Filter
      // Placeholder for future implementation
    ];
  }

  List<Widget> _buildCreatorFilters(FilterProvider provider) {
    return [
      // Creator Filter (simple text field for now)
      _buildTextFilter(
        provider: provider,
        field: 'uploadedBy',
        label: 'Creator Email',
        hint: 'Filter by creator email',
      ),
    ];
  }

  Widget _buildDropdownFilter({
    required FilterProvider provider,
    required String field,
    required String label,
    required List<dynamic> options,
    required String placeholder,
  }) {
    // Get current filter value if exists
    final currentFilter = provider.filterState.getFilterForField(field);
    final currentValue = currentFilter?.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: currentValue as String?,
          hint: Text(placeholder),
          isExpanded: true,
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          items: [
            // Add "All" option
            const DropdownMenuItem<String>(
              value: null,
              child: Text('All'),
            ),
            // Add all available options
            ...options.map((option) => DropdownMenuItem<String>(
                  value: option.toString(),
                  child: Text(option.toString()),
                )),
          ],
          onChanged: (value) {
            if (value == null) {
              // Remove filter if "All" is selected
              provider.removeFilter(field);
            } else {
              // Apply new filter
              provider.addFilter(field, value, FilterOperator.equals);
            }
          },
        ),
      ],
    );
  }

  Widget _buildRangeFilter({
    required FilterProvider provider,
    required String field,
    required String label,
  }) {
    // This is a placeholder for a future range filter implementation
    // For now, it's a simple text input for demonstration
    return _buildTextFilter(
      provider: provider,
      field: field,
      label: label,
      hint: 'e.g., 1-5, 5-10',
    );
  }

  Widget _buildTextFilter({
    required FilterProvider provider,
    required String field,
    required String label,
    required String hint,
    FilterOperator operator = FilterOperator.equals,
  }) {
    // Get current filter value if exists
    final currentFilter = provider.filterState.getFilterForField(field);
    final currentValue = currentFilter?.value as String?;

    final controller = TextEditingController(text: currentValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hint,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onSubmitted: (value) {
                  if (value.isEmpty) {
                    provider.removeFilter(field);
                  } else {
                    provider.addFilter(field, value, operator);
                  }
                },
              ),
            ),
            if (currentFilter != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  controller.clear();
                  provider.removeFilter(field);
                },
                tooltip: 'Clear',
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMultiSelectFilter({
    required FilterProvider provider,
    required String field,
    required String label,
    required List<dynamic> options,
    required String placeholder,
  }) {
    // Get current filter value if exists
    final currentFilter = provider.filterState.getFilterForField(field);
    final currentValues = (currentFilter?.value as List<String>?) ?? [];

    // Get expanded state for this filter, default to false if not set
    final isExpanded = _expandedFilters[field] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
            if (currentValues.isNotEmpty)
              TextButton(
                onPressed: () {
                  provider.removeFilter(field);
                },
                child: const Text('Clear'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () {
            setState(() {
              _expandedFilters[field] = !isExpanded;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (currentValues.isEmpty)
                      Text(
                        placeholder,
                        style: TextStyle(color: Colors.grey.shade600),
                      )
                    else
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: currentValues
                              .map((value) => Chip(
                                    label: Text(value),
                                    onDeleted: () {
                                      final newValues =
                                          List<String>.from(currentValues)
                                            ..remove(value);
                                      if (newValues.isEmpty) {
                                        provider.removeFilter(field);
                                      } else {
                                        provider.addFilter(field, newValues,
                                            FilterOperator.arrayContainsAny);
                                      }
                                    },
                                  ))
                              .toList(),
                        ),
                      ),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
                if (isExpanded) ...[
                  const Divider(),
                  ...options.map((option) => CheckboxListTile(
                        title: Text(option.toString()),
                        dense: true,
                        value: currentValues.contains(option.toString()),
                        onChanged: (checked) {
                          List<String> newValues;
                          if (checked == true) {
                            newValues = List<String>.from(currentValues)
                              ..add(option.toString());
                          } else {
                            newValues = List<String>.from(currentValues)
                              ..remove(option.toString());
                          }

                          if (newValues.isEmpty) {
                            provider.removeFilter(field);
                          } else {
                            provider.addFilter(field, newValues,
                                FilterOperator.arrayContainsAny);
                          }
                        },
                      )),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, FilterProvider provider) {
    final filterCount = provider.filterState.filterCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4.0,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: () {
              provider.clearFilters();
            },
            child: const Text('Clear All'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                  filterCount > 0 ? 'Apply Filters ($filterCount)' : 'Apply'),
            ),
          ),
        ],
      ),
    );
  }
}
