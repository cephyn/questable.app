import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quest_cards/src/filters/saved_filters_manager.dart';
import 'package:quest_cards/src/filters/filter_analytics.dart';
import 'package:quest_cards/src/services/game_system_service.dart';
import 'package:quest_cards/src/models/standard_game_system.dart';
import 'package:collection/collection.dart'; // Add collection import

// Define a constant for the special ownership filter field
const String ownershipFilterField = '__ownership__';

/// Enum to represent the ownership filter status
enum OwnershipFilterStatus { all, owned, unowned }

/// Represents a filter criteria that can be applied to quest cards.
class FilterCriteria {
  final String field;
  final dynamic value;
  final FilterOperator operator;

  FilterCriteria({
    required this.field,
    required this.value,
    this.operator = FilterOperator.equals,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterCriteria &&
          runtimeType == other.runtimeType &&
          field == other.field &&
          value == other.value &&
          operator == other.operator;

  @override
  int get hashCode => field.hashCode ^ value.hashCode ^ operator.hashCode;

  @override
  String toString() {
    return 'FilterCriteria(field: $field, value: $value, operator: $operator)';
  }

  /// Convert this filter criteria to a human-readable display string
  String toDisplayString() {
    // Handle special ownership filter display
    if (field == ownershipFilterField) {
      if (value == 'owned') return 'Status: Owned';
      if (value == 'unowned') return 'Status: Unowned';
      // Should not happen if managed correctly, but good fallback
      return 'Status: All';
    }

    String displayValue = value is List ? value.join(', ') : value.toString();
    switch (operator) {
      case FilterOperator.equals:
        return '$field: $displayValue';
      case FilterOperator.contains:
        return '$field contains: $displayValue';
      case FilterOperator.greaterThan:
        return '$field > $displayValue';
      case FilterOperator.lessThan:
        return '$field < $displayValue';
      case FilterOperator.greaterThanOrEqual:
        return '$field ≥ $displayValue';
      case FilterOperator.lessThanOrEqual:
        return '$field ≤ $displayValue';
      case FilterOperator.arrayContains:
        return '$field has: $displayValue';
      case FilterOperator.arrayContainsAny:
        return '$field has any: $displayValue';
      case FilterOperator.whereIn:
        return '$field in: $displayValue';
    }
  }

  /// Convert filter criteria to a map for storage
  Map<String, dynamic> toMap() {
    return {
      'field': field,
      'value': value is List ? jsonEncode(value) : value.toString(),
      'operator': operator.index,
      'valueType': value is List ? 'list' : 'string',
    };
  }

  /// Create filter criteria from stored map
  static FilterCriteria fromMap(Map<String, dynamic> map) {
    dynamic parsedValue = map['value'];
    if (map['valueType'] == 'list') {
      try {
        parsedValue = jsonDecode(map['value']);
      } catch (e) {
        parsedValue = [map['value']]; // Fallback if parsing fails
      }
    }

    return FilterCriteria(
      field: map['field'],
      value: parsedValue,
      operator: FilterOperator.values[map['operator']],
    );
  }
}

/// Defines the supported filter operators for quest card filtering.
enum FilterOperator {
  equals,
  contains,
  greaterThan,
  lessThan,
  greaterThanOrEqual,
  lessThanOrEqual,
  arrayContains,
  arrayContainsAny,
  whereIn
}

/// Manages the state of all active filters for quest cards.
class FilterState extends ChangeNotifier {
  final Set<FilterCriteria> _filters = HashSet<FilterCriteria>();
  OwnershipFilterStatus _ownershipStatus =
      OwnershipFilterStatus.all; // Add ownership status
  static const String _prefsKey = 'quest_card_filters';
  static const String _ownershipPrefsKey =
      'quest_card_ownership_filter'; // Key for saving ownership status

  // Private constructor for cloning
  FilterState._internal(Set<FilterCriteria> clonedFilters,
      OwnershipFilterStatus ownershipStatus) {
    _filters.clear();
    _filters.addAll(clonedFilters);
    _ownershipStatus = ownershipStatus;
  }

  // Default constructor
  FilterState();

  /// Clone the current filter state
  FilterState clone() {
    final Set<FilterCriteria> clonedFiltersSet = HashSet<FilterCriteria>();
    for (var filter in _filters) {
      // Assuming FilterCriteria.fromMap(toMap()) correctly creates a new instance
      clonedFiltersSet.add(FilterCriteria.fromMap(filter.toMap()));
    }
    return FilterState._internal(clonedFiltersSet, _ownershipStatus);
  }

  /// All currently active filters (excluding the internal ownership one)
  UnmodifiableListView<FilterCriteria> get filters =>
      UnmodifiableListView<FilterCriteria>(_filters
          .where((f) => f.field != ownershipFilterField)
          .toList()); // Exclude ownership filter from public list

  /// Current ownership filter status
  OwnershipFilterStatus get ownershipStatus => _ownershipStatus;

  /// Number of active filters (including ownership if not 'all')
  int get filterCount {
    // Count non-ownership filters
    int count = _filters.where((f) => f.field != ownershipFilterField).length;
    // Add 1 if ownership status is not 'all'
    if (_ownershipStatus != OwnershipFilterStatus.all) {
      count++;
    }
    return count;
  }

  /// Whether there are any active filters (including ownership if not 'all')
  bool get hasFilters =>
      _filters.isNotEmpty || _ownershipStatus != OwnershipFilterStatus.all;

  /// Add a new filter criteria
  void addFilter(FilterCriteria criteria) {
    // Special handling for ownership filter - use setOwnershipStatus instead
    if (criteria.field == ownershipFilterField) {
      developer.log(
          'Warning: Use setOwnershipStatus to manage ownership filters.',
          name: 'FilterState');
      return;
    }

    // Remove any existing filter for the same field to avoid conflicts
    _filters.removeWhere((filter) => filter.field == criteria.field);
    _filters.add(criteria);
    notifyListeners();
    saveFilters(); // Save filters when updated
  }

  /// Set the ownership filter status
  void setOwnershipStatus(OwnershipFilterStatus status) {
    if (_ownershipStatus == status) return; // No change

    _ownershipStatus = status;

    // Remove any existing internal ownership criteria first
    _filters.removeWhere((f) => f.field == ownershipFilterField);

    // Add new internal criteria if needed
    if (status == OwnershipFilterStatus.owned) {
      _filters.add(FilterCriteria(
          field: ownershipFilterField,
          value: 'owned',
          operator: FilterOperator.equals));
    } else if (status == OwnershipFilterStatus.unowned) {
      _filters.add(FilterCriteria(
          field: ownershipFilterField,
          value: 'unowned',
          operator: FilterOperator.equals));
    }

    notifyListeners();
    saveFilters(); // Save filters when updated
  }

  /// Remove a specific filter criteria
  void removeFilter(FilterCriteria criteria) {
    if (criteria.field == ownershipFilterField) {
      // If removing the ownership filter, reset the status
      setOwnershipStatus(OwnershipFilterStatus.all);
    } else {
      _filters.remove(criteria);
      notifyListeners();
      saveFilters(); // Save filters when updated
    }
  }

  /// Remove all filters for a specific field
  void removeFilterByField(String field) {
    if (field == ownershipFilterField) {
      // If removing the ownership filter, reset the status
      setOwnershipStatus(OwnershipFilterStatus.all);
    } else {
      _filters.removeWhere((filter) => filter.field == field);
      notifyListeners();
      saveFilters(); // Save filters when updated
    }
  }

  /// Clear all active filters
  void clearFilters() {
    _filters.clear();
    _ownershipStatus = OwnershipFilterStatus.all; // Reset ownership status
    notifyListeners();
    saveFilters(); // Save filters when updated
  }

  /// Check if a field is currently being filtered
  bool hasFilterForField(String field) {
    if (field == ownershipFilterField) {
      return _ownershipStatus != OwnershipFilterStatus.all;
    }
    return _filters.any((filter) => filter.field == field);
  }

  /// Get the current filter for a specific field, if it exists
  FilterCriteria? getFilterForField(String field) {
    try {
      // Return the internal ownership filter if requested
      if (field == ownershipFilterField &&
          _ownershipStatus != OwnershipFilterStatus.all) {
        // Find the specific ownership filter (owned or unowned)
        return _filters.firstWhere((f) => f.field == ownershipFilterField);
      }
      // Otherwise, find the regular filter, ensuring it's not the ownership one
      return _filters.firstWhere((filter) =>
          filter.field == field && filter.field != ownershipFilterField);
    } catch (e) {
      // If no filter is found (including ownership when status is 'all'), return null
      return null;
    }
  }

  /// Convert active filters to Firestore query constraints
  /// Note: This does NOT handle the special ownership filter.
  /// Ownership filtering needs to be handled separately, likely involving
  /// fetching owned IDs and using whereIn/whereNotIn.
  List<Query Function(Query)> toFirestoreQueryConstraints() {
    List<Query Function(Query)> constraints = [];

    for (var filter in _filters) {
      // Skip the special ownership filter here
      if (filter.field == ownershipFilterField) continue;

      switch (filter.operator) {
        case FilterOperator.equals:
          constraints.add(
              (query) => query.where(filter.field, isEqualTo: filter.value));
          break;
        case FilterOperator.greaterThan:
          constraints.add((query) =>
              query.where(filter.field, isGreaterThan: filter.value));
          break;
        case FilterOperator.lessThan:
          constraints.add(
              (query) => query.where(filter.field, isLessThan: filter.value));
          break;
        case FilterOperator.greaterThanOrEqual:
          constraints.add((query) =>
              query.where(filter.field, isGreaterThanOrEqualTo: filter.value));
          break;
        case FilterOperator.lessThanOrEqual:
          constraints.add((query) =>
              query.where(filter.field, isLessThanOrEqualTo: filter.value));
          break;
        case FilterOperator.arrayContains:
          constraints.add((query) =>
              query.where(filter.field, arrayContains: filter.value));
          break;
        case FilterOperator.arrayContainsAny:
          constraints.add((query) => query.where(filter.field,
              arrayContainsAny: filter.value as List));
          break;
        case FilterOperator.whereIn:
          constraints.add((query) =>
              query.where(filter.field, whereIn: filter.value as List));
          break;
        case FilterOperator.contains:
          // Firestore doesn't directly support 'contains' for strings.
          // This requires specific handling, potentially using >= and <=
          // with a special character, or relying on external search services.
          // For now, we'll log a warning and skip this filter.
          developer.log(
              'Warning: Firestore does not directly support string \'contains\' filter for field: ${filter.field}. Skipping.',
              name: 'FilterState');
          break;
      }
    }
    return constraints;
  }

  /// Apply active filters to a Firestore query
  Query applyFiltersToQuery(Query query) {
    // Always start by applying the isPublic filter, as per existing logic
    Query filteredQuery = query.where('isPublic', isEqualTo: true);

    try {
      for (var filter in _filters) {
        // Skip the special ownership filter here
        if (filter.field == ownershipFilterField) continue;

        // Special handling for the old 'gameSystem' field (if still used)
        if (filter.field == 'gameSystem') {
          filteredQuery = _applyGameSystemFilter(filteredQuery, filter);
          continue;
        }

        // Specific handling for 'standardizedGameSystem'
        if (filter.field == 'standardizedGameSystem') {
          if (filter.value is String) {
            String systemName = filter.value as String;
            if (systemName.isNotEmpty) {
              // Assuming 'equals' is the primary operator for a single string value from the widget
              if (filter.operator == FilterOperator.equals) {
                filteredQuery =
                    filteredQuery.where(filter.field, isEqualTo: systemName);
                developer.log(
                    'Applying standardizedGameSystem filter (from String): isEqualTo "$systemName"',
                    name: 'FilterState');
              } else {
                // Log if a different operator is used with a single string, though current UI setup implies 'equals'
                developer.log(
                    'Warning: Operator ${filter.operator} used with String value for standardizedGameSystem. Value: "$systemName". Applying as isEqualTo.',
                    name: 'FilterState');
                // Default to isEqualTo for a single string if operator is not explicitly handled or is unexpected
                filteredQuery =
                    filteredQuery.where(filter.field, isEqualTo: systemName);
              }
            } else {
              developer.log(
                  'Warning: standardizedGameSystem filter (from String) received an empty string. Skipping filter.',
                  name: 'FilterState');
            }
          } else if (filter.value is List &&
              (filter.value as List).isNotEmpty) {
            List<dynamic> systemValueList = filter.value as List;

            // Case 1: filter.value is List<String>.
            // This could be parts of a single system (e.g., ['Pathfinder', '2nd Edition'])
            // OR a list of multiple selected system names (e.g., ['Cypher System', 'D&D 5e']) if operator is whereIn.
            if (systemValueList.every((item) => item is String)) {
              List<String> stringListValue = systemValueList.cast<String>();

              if (filter.operator == FilterOperator.whereIn) {
                // If operator is whereIn, this list of strings is assumed to be a list of game system names.
                // Each string is a distinct system name.
                if (stringListValue.isNotEmpty) {
                  // Firestore 'whereIn' requires a non-empty list and limits to 30 elements.
                  if (stringListValue.length > 30) {
                    developer.log(
                        'Warning: standardizedGameSystem whereIn filter (from List<String>) has ${stringListValue.length} values. Firestore limits this to 30. The query may fail.',
                        name: 'FilterState');
                  }
                  filteredQuery = filteredQuery.where(filter.field,
                      whereIn: stringListValue);
                  developer.log(
                      'Applying standardizedGameSystem filter (from List<String>): whereIn $stringListValue',
                      name: 'FilterState');
                } else {
                  developer.log(
                      'Warning: standardizedGameSystem whereIn filter (from List<String>) received an empty list. Value: $stringListValue. Skipping filter.',
                      name: 'FilterState');
                }
              } else {
                // Operator is not whereIn (e.g., equals).
                // Value might be ['Pathfinder'] or ['Pathfinder', '2nd Edition'].
                // Since 'edition' is a separate field, we only use the first element for 'standardizedGameSystem'.
                if (stringListValue.isNotEmpty) {
                  String nameToQuery = stringListValue[
                      0]; // Use the first element as the system name.
                  filteredQuery =
                      filteredQuery.where(filter.field, isEqualTo: nameToQuery);
                  developer.log(
                      'Applying standardizedGameSystem filter (from List<String>, non-whereIn): isEqualTo "$nameToQuery" (using first element). Assumes other parts like edition are separate filters.',
                      name: 'FilterState');
                } else {
                  developer.log(
                      'Warning: standardizedGameSystem filter (from List<String>, non-whereIn) received an empty list. Value: $stringListValue. Skipping filter.',
                      name: 'FilterState');
                }
              }
            } else if (systemValueList.every((item) =>
                item is List && item.every((subItem) => subItem is String))) {
              if (filter.operator == FilterOperator.whereIn) {
                List<List<String>> listOfParts = systemValueList
                    .map((e) => (e as List).cast<String>())
                    .toList();
                List<String> namesForWhereIn = listOfParts
                    .map((parts) => parts.join(
                        ' ')) // Convert each list of parts to a name string
                    .toList();
                if (namesForWhereIn.isNotEmpty) {
                  // Firestore 'whereIn' requires a non-empty list.
                  // Firestore also limits 'whereIn' array to 30 elements.
                  if (namesForWhereIn.length > 30) {
                    developer.log(
                        'Warning: standardizedGameSystem whereIn filter has ${namesForWhereIn.length} values. Firestore limits this to 30. The query may fail.',
                        name: 'FilterState');
                  }
                  filteredQuery = filteredQuery.where(filter.field,
                      whereIn: namesForWhereIn);
                  developer.log(
                      'Applying standardizedGameSystem filter: whereIn $namesForWhereIn',
                      name: 'FilterState');
                } else {
                  developer.log(
                      'Warning: standardizedGameSystem whereIn filter resulted in an empty list of names. Value: $systemValueList. Skipping filter.',
                      name: 'FilterState');
                }
              } else {
                developer.log(
                    'Warning: Operator ${filter.operator} used with List<List<String>> for standardizedGameSystem. Expected whereIn. Value: $systemValueList. Skipping filter.',
                    name: 'FilterState');
              }
            } else {
              developer.log(
                  'Warning: Unsupported value structure for standardizedGameSystem. Value: $systemValueList. Skipping filter.',
                  name: 'FilterState');
            }
          } else {
            developer.log(
                'Warning: Empty or invalid value for standardizedGameSystem (not a String or non-empty List). Value: ${filter.value}. Skipping filter.',
                name: 'FilterState');
          }
          continue; // Processed standardizedGameSystem, skip general switch
        }

        // General filter handling for other fields
        switch (filter.operator) {
          case FilterOperator.equals:
            filteredQuery =
                filteredQuery.where(filter.field, isEqualTo: filter.value);
            break;
          case FilterOperator.greaterThan:
            filteredQuery =
                filteredQuery.where(filter.field, isGreaterThan: filter.value);
            break;
          case FilterOperator.lessThan:
            filteredQuery =
                filteredQuery.where(filter.field, isLessThan: filter.value);
            break;
          case FilterOperator.greaterThanOrEqual:
            filteredQuery = filteredQuery.where(filter.field,
                isGreaterThanOrEqualTo: filter.value);
            break;
          case FilterOperator.lessThanOrEqual:
            filteredQuery = filteredQuery.where(filter.field,
                isLessThanOrEqualTo: filter.value);
            break;
          case FilterOperator.arrayContains:
            filteredQuery =
                filteredQuery.where(filter.field, arrayContains: filter.value);
            break;
          case FilterOperator.arrayContainsAny:
            if (filter.value is List && (filter.value as List).isNotEmpty) {
              filteredQuery = filteredQuery.where(filter.field,
                  arrayContainsAny: filter.value as List);
            } else {
              developer.log(
                  'Warning: Value for arrayContainsAny on field ${filter.field} is not a List or is empty. Value: ${filter.value}. Skipping.',
                  name: 'FilterState');
            }
            break;
          case FilterOperator.whereIn:
            // This is for fields other than standardizedGameSystem
            if (filter.value is List && (filter.value as List).isNotEmpty) {
              filteredQuery = filteredQuery.where(filter.field,
                  whereIn: filter.value as List);
            } else {
              developer.log(
                  'Warning: Value for whereIn on field ${filter.field} is not a List or is empty. Value: ${filter.value}. Skipping.',
                  name: 'FilterState');
            }
            break;
          case FilterOperator.contains:
            // Firestore doesn't directly support string contains
            developer.log(
                'Warning: Firestore does not directly support string \'contains\' filter for field: ${filter.field}. Skipping.',
                name: 'FilterState');
            break;
        }
      }
    } catch (e, stackTrace) {
      // Log the error to developer console with detailed information
      developer.log('Error applying filter: $e',
          name: 'Questable', error: e, stackTrace: stackTrace);

      // Log to file with stacktrace for debugging
      try {
        final logFile = File('error.log');
        final timestamp = DateTime.now().toString();
        logFile.writeAsStringSync(
            '[$timestamp] Filter Error: $e\\n$stackTrace\\n\\n',
            mode: FileMode.append);
      } catch (logError) {
        developer.log('Failed to write error to log file: $logError',
            name: 'Questable', error: logError);
      }

      // Create a proper error dialog with clickable URL if one is present in the error message
      try {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final errorString = e.toString();
          // Corrected RegExp for URL matching (match until whitespace)
          final urlRegExp = RegExp(r'https?://[^\\s]+');
          final match = urlRegExp.firstMatch(errorString);
          String? url;
          if (match != null) {
            url = match.group(0);
          }
          // Ensure showErrorDialog is robust or also wrapped in try-catch if it can throw
          try {
            showErrorDialog(errorString, url);
          } catch (showDialogError) {
            developer.log('Error calling showErrorDialog: $showDialogError',
                name: 'Questable', error: showDialogError);
          }
        });
      } catch (uiError) {
        developer.log('Error in showErrorDialog callback scheduling: $uiError',
            name: 'Questable', error: uiError);
      }

      // Return the original query with just the isPublic filter
      // to avoid completely failing the filtering operation, as per existing logic.
      return query.where('isPublic', isEqualTo: true);
    }

    return filteredQuery;
  }

  /// Special handling for game system filters to support standardization
  Query _applyGameSystemFilter(Query query, FilterCriteria filter) {
    // For transition period, search both original and standardized fields
    switch (filter.operator) {
      case FilterOperator.equals:
        // Get the standardId for the selected game system
        String systemValue = filter.value.toString();

        // For exact match, create a compound query that checks both fields
        return query.where(Filter.or(
            Filter('gameSystem', isEqualTo: systemValue),
            Filter('standardizedGameSystem', isEqualTo: systemValue)));

      case FilterOperator.whereIn:
        // For whereIn operations (multiple systems selected)
        List<dynamic> systems = filter.value as List;
        return query.where(Filter.or(Filter('gameSystem', whereIn: systems),
            Filter('standardizedGameSystem', whereIn: systems)));

      default:
        // Fallback to just using the standardized field for other operators
        return query.where('standardizedGameSystem', isEqualTo: filter.value);
    }
  }

  /// Show an error dialog with clickable URL if one is present in the error message
  void showErrorDialog(String errorMessage, String? url) {
    // We don't have reliable access to a context here, so we'll focus on:
    // 1. Properly logging the error
    // 2. Making sure the URL is easily visible in the log

    // Log the error with the URL highlighted
    String logMessage = 'Filter Error: $errorMessage';
    if (url != null) {
      logMessage += '\nClickable Error URL: $url';
    }

    developer.log(logMessage, name: 'Questable', level: 2000 // Error level
        );

    // Print to console for immediate visibility during debugging
    debugPrint('');
    debugPrint('====== FILTER ERROR ======');
    debugPrint(errorMessage);
    if (url != null) {
      debugPrint('');
      debugPrint('ERROR URL: $url');
      debugPrint('(URL has been logged to error.log)');
    }
    debugPrint('==========================');
    debugPrint('');

    // We'll leave it to the UI components to display this error
    // as they have access to proper BuildContext
  }

  /// Save current filters to SharedPreferences
  Future<void> saveFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Save regular filters
      final List<Map<String, dynamic>> filterMaps = _filters
          .where((f) => f.field != ownershipFilterField) // Exclude ownership
          .map((f) => f.toMap())
          .toList();
      await prefs.setString(_prefsKey, jsonEncode(filterMaps));
      // Save ownership status separately
      await prefs.setInt(_ownershipPrefsKey, _ownershipStatus.index);
      developer.log('Filters saved successfully. Ownership: $_ownershipStatus',
          name: 'FilterState');
    } catch (e) {
      developer.log('Error saving filters: $e', name: 'FilterState', error: e);
    }
  }

  /// Load filters from SharedPreferences
  Future<void> loadFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Load regular filters
      final String? savedFiltersJson = prefs.getString(_prefsKey);
      _filters.clear(); // Clear existing before loading
      if (savedFiltersJson != null) {
        final List<dynamic> filterList = jsonDecode(savedFiltersJson);
        _filters.addAll(filterList
            .map((map) => FilterCriteria.fromMap(map as Map<String, dynamic>))
            .where((f) =>
                f.field !=
                ownershipFilterField)); // Ensure no ownership filter loaded here
      }
      // Load ownership status
      final int? savedOwnershipIndex = prefs.getInt(_ownershipPrefsKey);
      if (savedOwnershipIndex != null &&
          savedOwnershipIndex >= 0 &&
          savedOwnershipIndex < OwnershipFilterStatus.values.length) {
        _ownershipStatus = OwnershipFilterStatus.values[savedOwnershipIndex];
        // Re-add the internal ownership criteria if needed
        // Make sure not to add duplicates if loadFilters is called multiple times
        _filters.removeWhere(
            (f) => f.field == ownershipFilterField); // Remove existing first
        if (_ownershipStatus == OwnershipFilterStatus.owned) {
          _filters.add(FilterCriteria(
              field: ownershipFilterField,
              value: 'owned',
              operator: FilterOperator.equals));
        } else if (_ownershipStatus == OwnershipFilterStatus.unowned) {
          _filters.add(FilterCriteria(
              field: ownershipFilterField,
              value: 'unowned',
              operator: FilterOperator.equals));
        }
      } else {
        _ownershipStatus =
            OwnershipFilterStatus.all; // Default if not found or invalid
        _filters.removeWhere((f) =>
            f.field ==
            ownershipFilterField); // Ensure no ownership filter if status is all
      }

      notifyListeners();
      developer.log('Filters loaded successfully. Ownership: $_ownershipStatus',
          name: 'FilterState');
    } catch (e) {
      developer.log('Error loading filters: $e', name: 'FilterState', error: e);
      // Optionally clear filters on load error
      // _filters.clear();
      // _ownershipStatus = OwnershipFilterStatus.all;
      // notifyListeners();
    }
  }

  /// Apply a saved filter set
  void applySavedFilters(List<FilterCriteria> savedFilters) {
    _filters.clear();
    _ownershipStatus = OwnershipFilterStatus.all; // Reset ownership first

    for (var criteria in savedFilters) {
      if (criteria.field == ownershipFilterField) {
        // Handle ownership from saved filter
        if (criteria.value == 'owned') {
          setOwnershipStatus(OwnershipFilterStatus.owned);
        } else if (criteria.value == 'unowned') {
          setOwnershipStatus(OwnershipFilterStatus.unowned);
        }
      } else {
        // Add regular filters, ensuring no duplicates for the same field
        _filters.removeWhere((f) => f.field == criteria.field);
        _filters.add(criteria);
      }
    }
    notifyListeners();
    saveFilters(); // Save the newly applied filters
  }

  /// Convert the current filter state to a map (for saving filter sets)
  Map<String, dynamic> toMap() {
    // Include the actual internal ownership filter criteria if status is not 'all'
    final List<Map<String, dynamic>> filterMaps =
        _filters.map((f) => f.toMap()).toList();
    return {'filters': filterMaps};
  }

  /// Create a FilterState from a map (for loading filter sets)
  static FilterState fromMap(Map<String, dynamic> map) {
    final state = FilterState();
    if (map['filters'] != null) {
      final List<dynamic> filterList = map['filters'];
      final loadedFilters = filterList
          .map((m) => FilterCriteria.fromMap(m as Map<String, dynamic>))
          .toList();
      state.applySavedFilters(
          loadedFilters); // Use applySavedFilters to correctly set state
    }
    return state;
  }
}

/// Provides filter state and manages filter options and saved filters.
class FilterProvider extends ChangeNotifier {
  final FilterState _filterState = FilterState();
  final Map<String, List<dynamic>> _filterOptions = {};
  final SavedFiltersManager _savedFiltersManager = SavedFiltersManager();
  // Use the singleton instance for FilterAnalytics
  final FilterAnalytics _filterAnalytics = FilterAnalytics.instance;
  final GameSystemService _gameSystemService =
      GameSystemService(); // Add GameSystemService

  // Cache for standard game systems
  List<StandardGameSystem> _standardGameSystems = [];

  FilterState get filterState => _filterState;
  Map<String, List<dynamic>> get filterOptions => _filterOptions;
  // Access saved filters directly from the manager's getter
  Map<String, List<FilterCriteria>> get savedFilterSets =>
      _savedFiltersManager.savedFilterSets;

  // Getter for cached standard game systems
  List<StandardGameSystem> get standardGameSystems => _standardGameSystems;

  FilterProvider() {
    _filterState.addListener(_notifyAndUpdateAnalytics);
    loadFilters(); // Load filters on initialization
    // Load options AND standard systems on initialization
    loadFilterOptionsAndSystems();
    // Initialize the SavedFiltersManager instead of calling loadSavedFilters
    _savedFiltersManager.initialize().then((_) {
      // Optionally notify listeners after initialization if needed,
      // though SavedFiltersManager might notify itself.
      // notifyListeners();
    });
    // Saved filters are loaded within initialize, listen for changes if needed or access via getter
    // loadSavedFilters(); // Remove this direct call
  }

  @override
  void dispose() {
    _filterState.removeListener(_notifyAndUpdateAnalytics);
    _filterState.dispose();
    super.dispose();
  }

  void _notifyAndUpdateAnalytics() {
    notifyListeners();
    // Optionally trigger analytics update here if needed immediately on change
    // _filterAnalytics.updateActiveFilters(_filterState.filters);
  }

  /// Load available options for filterable fields AND standard game systems
  Future<void> loadFilterOptionsAndSystems() async {
    bool optionsChanged = false;
    bool systemsChanged = false;

    // --- Fetch Standard Game Systems First ---
    try {
      final fetchedSystems = await _gameSystemService.getAllGameSystems();
      // Use ListEquality for comparison
      if (!const ListEquality().equals(_standardGameSystems, fetchedSystems)) {
        _standardGameSystems = fetchedSystems;
        systemsChanged = true;
        developer.log('Standard game systems updated.', name: 'FilterProvider');

        // Update filter options for standardGameSystem based on the fetched list
        final standardSystemNames =
            _standardGameSystems.map((s) => s.standardName).toList()..sort();
        if (_filterOptions['standardizedGameSystem'] == null ||
            !_listEquals(_filterOptions['standardizedGameSystem']!,
                standardSystemNames)) {
          _filterOptions['standardizedGameSystem'] = standardSystemNames;
          optionsChanged = true; // Mark options as changed too
        }
      }
    } catch (e) {
      developer.log('Error fetching standard game systems: $e',
          name: 'FilterProvider', error: e);
      // Optionally clear cache on error?
      // _standardGameSystems = [];
      // systemsChanged = true;
    }

    // --- Fetch Options for Other Fields ---
    const List<String> fields = [
      'gameSystem', // Keep fetching original gameSystem for now
      'environments',
      'genre',
      'setting',
      'publisher',
      // Add other fields as needed
    ];

    for (String field in fields) {
      final newOptions = await _fetchOptionsForField(field);
      if (_filterOptions[field] == null ||
          !_listEquals(_filterOptions[field]!, newOptions)) {
        _filterOptions[field] = newOptions;
        optionsChanged = true;
      }
    }

    // --- Notify if anything changed ---
    if (optionsChanged || systemsChanged) {
      notifyListeners(); // Notify if any options or systems were updated
      developer.log('Filter options/systems loaded/updated.',
          name: 'FilterProvider');
    }
  }

  /// Helper to fetch distinct values for a field
  Future<List<dynamic>> _fetchOptionsForField(String field) async {
    developer.log('Fetching options for field: $field', name: 'FilterProvider');
    try {
      // Correct the collection name to questCards
      final snapshot = await FirebaseFirestore.instance
          .collection('questCards') // Corrected collection name
          .where('isPublic',
              isEqualTo: true) // Only consider public quests for options
          .get(const GetOptions(
              source: Source.serverAndCache)); // Keep serverAndCache for now

      developer.log(
          'Fetched ${snapshot.docs.length} documents for field: $field',
          name: 'FilterProvider');

      Set<dynamic> uniqueOptions = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        // Check and extract the field directly from data
        if (data.containsKey(field)) {
          final value = data[field];
          if (value is List) {
            // If the field is an array, add all its elements
            uniqueOptions.addAll(
                value.map((item) => item?.toString()).whereType<String>());
          } else if (value != null) {
            // Otherwise, add the single value
            uniqueOptions.add(value.toString());
          }
        }
      }
      // Sort options alphabetically
      List<dynamic> sortedOptions = uniqueOptions.toList()..sort();
      developer.log(
          'Found ${sortedOptions.length} unique options for field: $field',
          name: 'FilterProvider');
      return sortedOptions;
    } catch (e, stackTrace) {
      // Add stackTrace
      developer.log('Error fetching options for field $field: $e',
          name: 'FilterProvider',
          error: e,
          stackTrace: stackTrace); // Log stackTrace
      return []; // Return empty list on error
    }
  }

  /// Helper to compare lists
  bool _listEquals(List<dynamic> list1, List<dynamic> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  /// Load saved filter sets from storage
  // This might not be needed if initialize handles loading and notifies
  // Future<void> loadSavedFilters() async {
  //   await _savedFiltersManager.initialize(); // Ensure initialized
  //   notifyListeners(); // Notify after loading/initialization
  // }

  /// Save the current filter state as a named set
  Future<bool> saveCurrentFilters(String name) async {
    if (name.isEmpty || !_filterState.hasFilters) return false;
    final success = await _savedFiltersManager.saveFilterSet(
        name, _filterState.filters.toList());
    if (success) {
      notifyListeners(); // Update UI with the new saved filter
    }
    return success;
  }

  /// Delete a saved filter set by name
  Future<bool> deleteSavedFilterSet(String name) async {
    final success = await _savedFiltersManager.deleteFilterSet(name);
    if (success) {
      notifyListeners(); // Update UI
    }
    return success;
  }

  /// Apply a previously saved filter set by name
  void applySavedFilters(String name) {
    // Get the filter set directly from the manager's map
    final filtersToApply =
        _savedFiltersManager.savedFilterSets[name]; // Corrected access
    if (filtersToApply != null) {
      _filterState.applySavedFilters(filtersToApply);
      // No need to call notifyListeners, _filterState listener handles it
    }
  }

  /// Add a filter criteria to the current state
  void addFilter(String field, dynamic value, FilterOperator operator) {
    // Use the FilterState's method directly
    _filterState.addFilter(
        FilterCriteria(field: field, value: value, operator: operator));
    // No need to call notifyListeners here, _filterState listener handles it
  }

  /// Remove a filter criteria by field name
  void removeFilter(String field) {
    // Use the FilterState's method directly
    _filterState.removeFilterByField(field);
    // No need to call notifyListeners here, _filterState listener handles it
  }

  /// Clear all active filters
  void clearFilters() {
    _filterState.clearFilters();
    // No need to call notifyListeners here, _filterState listener handles it
  }

  /// Set the ownership filter status
  void setOwnershipStatus(OwnershipFilterStatus status) {
    _filterState.setOwnershipStatus(status);
    // No need to call notifyListeners here, _filterState listener handles it
  }

  /// Load filters from storage
  Future<void> loadFilters() async {
    await _filterState.loadFilters();
    // No need to call notifyListeners here, _filterState listener handles it
  }

  /// Set the user ID for analytics tracking
  Future<void> setAnalyticsUserId(String? userId) async {
    await _filterAnalytics.setUserId(userId);
  }

  /// Track the usage of the current filters
  void trackFilterUsage() {
    // Use trackFilterCombination instead of trackFilterEvent/trackFilterSetUsage
    // Pass the full list including the internal ownership filter
    _filterAnalytics.trackFilterCombination(
        _filterState.filters.toList()); // Corrected method name
  }

  /// Get standardized game systems for filtering (returns cached list)
  // This method is now just a getter: standardGameSystems
  // Future<List<StandardGameSystem>> getStandardGameSystems() async {
  //   // Use getAllGameSystems instead of getStandardGameSystems
  //   return await _gameSystemService
  //       .getAllGameSystems(); // Corrected method name
  // }

  /// Get a specific standard game system by its standard name from the cache.
  StandardGameSystem? getSystemByName(String name) {
    try {
      // Use firstWhereOrNull from collection package
      return _standardGameSystems
          .firstWhereOrNull((system) => system.standardName == name);
    } catch (e) {
      // Should not happen with firstWhereOrNull, but good practice
      // Corrected logging statement syntax
      developer.log('Error finding system by name \'$name\': $e',
          name: 'FilterProvider');
      return null;
    }
  }
}
