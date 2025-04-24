import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quest_cards/src/services/firestore_service.dart';
import 'package:quest_cards/src/filters/saved_filters_manager.dart';
import 'package:quest_cards/src/filters/filter_analytics.dart';
import 'package:url_launcher/url_launcher.dart';

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
  static const String _prefsKey = 'quest_card_filters';

  /// All currently active filters
  UnmodifiableListView<FilterCriteria> get filters =>
      UnmodifiableListView<FilterCriteria>(_filters.toList());

  /// Number of active filters
  int get filterCount => _filters.length;

  /// Whether there are any active filters
  bool get hasFilters => _filters.isNotEmpty;

  /// Add a new filter criteria
  void addFilter(FilterCriteria criteria) {
    // Remove any existing filter for the same field to avoid conflicts
    _filters.removeWhere((filter) => filter.field == criteria.field);
    _filters.add(criteria);
    notifyListeners();
    saveFilters(); // Save filters when updated
  }

  /// Remove a specific filter criteria
  void removeFilter(FilterCriteria criteria) {
    _filters.remove(criteria);
    notifyListeners();
    saveFilters(); // Save filters when updated
  }

  /// Remove all filters for a specific field
  void removeFilterByField(String field) {
    _filters.removeWhere((filter) => filter.field == field);
    notifyListeners();
    saveFilters(); // Save filters when updated
  }

  /// Clear all active filters
  void clearFilters() {
    _filters.clear();
    notifyListeners();
    saveFilters(); // Save filters when updated
  }

  /// Check if a field is currently being filtered
  bool hasFilterForField(String field) {
    return _filters.any((filter) => filter.field == field);
  }

  /// Get the current filter for a specific field, if it exists
  FilterCriteria? getFilterForField(String field) {
    try {
      return _filters.firstWhere((filter) => filter.field == field);
    } catch (e) {
      return null;
    }
  }

  /// Convert active filters to Firestore query constraints
  List<Query Function(Query)> toFirestoreQueryConstraints() {
    List<Query Function(Query)> constraints = [];

    for (var filter in _filters) {
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
          // Firestore doesn't have a direct "contains" operator for strings
          // This would need a different implementation or custom indexing
          break;
      }
    }

    return constraints;
  }

  /// Apply active filters to a Firestore query
  Query applyFiltersToQuery(Query query) {
    // Always start by applying the isPublic filter
    Query filteredQuery = query.where('isPublic', isEqualTo: true);

    try {
      for (var filter in _filters) {
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
            filteredQuery = filteredQuery.where(filter.field,
                arrayContainsAny: filter.value as List);
            break;
          case FilterOperator.whereIn:
            filteredQuery = filteredQuery.where(filter.field,
                whereIn: filter.value as List);
            break;
          case FilterOperator.contains:
            // Firestore doesn't directly support string contains
            // For production, you might want to implement a custom solution
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
            '[$timestamp] Filter Error: $e\n$stackTrace\n\n',
            mode: FileMode.append);
      } catch (logError) {
        debugPrint('Failed to write error to log file: $logError');
      }

      // Create a proper error dialog with clickable URL
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final errorUrl = e.toString();

        // Check if the error is a URL or contains a URL
        final urlRegExp = RegExp(r'https?:\/\/[^\s]+');
        final match = urlRegExp.firstMatch(errorUrl);

        String? url;
        if (match != null) {
          url = match.group(0);
        }

        showErrorDialog(errorUrl, url);
      });

      // Return the original query with just the isPublic filter
      // to avoid completely failing the filtering operation
      return query.where('isPublic', isEqualTo: true);
    }

    return filteredQuery;
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

  /// Save the current filters to shared preferences
  Future<void> saveFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final filtersList = _filters.map((filter) => filter.toMap()).toList();
      await prefs.setString(_prefsKey, jsonEncode(filtersList));
    } catch (e) {
      debugPrint('Error saving filters: $e');
    }
  }

  /// Load filters from shared preferences
  Future<void> loadFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? filtersJson = prefs.getString(_prefsKey);

      if (filtersJson != null && filtersJson.isNotEmpty) {
        final List<dynamic> filtersList = jsonDecode(filtersJson);
        _filters.clear();

        for (var filterMap in filtersList) {
          if (filterMap is Map<String, dynamic>) {
            _filters.add(FilterCriteria.fromMap(filterMap));
          }
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading filters: $e');
    }
  }
}

/// A provider for filter-related data and operations.
class FilterProvider extends ChangeNotifier {
  final FilterState filterState = FilterState();
  final SavedFiltersManager savedFiltersManager = SavedFiltersManager();
  final FilterAnalytics _analytics = FilterAnalytics.instance;
  bool _initialized = false;
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoadingFilterOptions = false;

  FilterProvider() {
    _initializeFilters();
  }

  Future<void> _initializeFilters() async {
    if (!_initialized) {
      await filterState.loadFilters();
      await savedFiltersManager.initialize();
      _initialized = true;
      notifyListeners();
    }
  }

  /// Common filter fields for quest cards - used for UI organization
  static const List<String> gameSystemFields = ['gameSystem', 'edition'];
  static const List<String> difficultyFields = ['level'];
  static const List<String> contentFields = [
    'classification',
    'genre',
    'setting',
    'environment' // Changed from 'environments' to 'environment'
  ];
  static const List<String> publicationFields = [
    'publisher',
    'publicationYear',
    'authors'
  ];

  /// For authenticated users only
  static const List<String> creatorFields = ['uploadedBy'];

  /// Map of field names to human-readable display names
  static Map<String, String> fieldDisplayNames = {
    'gameSystem': 'Game System',
    'edition': 'Edition',
    'level': 'Level Range',
    'classification': 'Type',
    'genre': 'Genre',
    'setting': 'Setting',
    'environment':
        'Environments', // Changed from 'environments' to 'environment'
    'publisher': 'Publisher',
    'publicationYear': 'Year Published',
    'authors': 'Authors',
    'uploadedBy': 'Created By',
  };

  /// Initialize common filter options that may be provided from Firestore
  Map<String, List<dynamic>> filterOptions = {
    'gameSystem': [],
    'edition': [],
    'classification': ['Adventure', 'Rulebook', 'Supplement', 'Other'],
    'publisher': [],
    'genre': [],
  };

  /// Whether filter options are currently being loaded
  bool get isLoadingFilterOptions => _isLoadingFilterOptions;

  /// Load filter options from Firestore
  Future<void> loadFilterOptions() async {
    if (_isLoadingFilterOptions) return; // Prevent multiple concurrent loads

    _isLoadingFilterOptions = true;
    notifyListeners();

    try {
      // Keep the static classification options and load the rest from Firestore
      final staticClassifications = filterOptions['classification']!;

      // Load distinct field values from Firestore for relevant fields
      final gameSystems =
          await _firestoreService.getDistinctFieldValues('gameSystem');
      final editions =
          await _firestoreService.getDistinctFieldValues('edition');
      final publishers =
          await _firestoreService.getDistinctFieldValues('publisher');
      final genres = await _firestoreService.getDistinctFieldValues('genre');
      // Changed 'environment' to 'environments' to match the field name in Firestore
      final environments =
          await _firestoreService.getDistinctFieldValues('environments');
      final settings =
          await _firestoreService.getDistinctFieldValues('setting');

      // Update filter options with loaded values
      filterOptions = {
        'gameSystem': gameSystems
            .where((item) => item != null && item.toString().isNotEmpty)
            .toList(),
        'edition': editions
            .where((item) => item != null && item.toString().isNotEmpty)
            .toList(),
        'classification': staticClassifications,
        'publisher': publishers
            .where((item) => item != null && item.toString().isNotEmpty)
            .toList(),
        'genre': genres
            .where((item) => item != null && item.toString().isNotEmpty)
            .toList(),
        // Store the environment values in the 'environment' key for the UI to access
        'environment': environments
            .where((item) => item != null && item.toString().isNotEmpty)
            .toList(),
        'setting': settings
            .where((item) => item != null && item.toString().isNotEmpty)
            .toList(),
      };
    } catch (e) {
      debugPrint('Error loading filter options: $e');
    } finally {
      _isLoadingFilterOptions = false;
      notifyListeners();
    }
  }

  /// Save current filters as a named set
  Future<bool> saveCurrentFilters(String name) async {
    if (name.trim().isEmpty) return false;

    final success = await savedFiltersManager.saveFilterSet(
        name, filterState.filters.toList());
    if (success) {
      // Track the saved filter set in analytics
      await _analytics.trackFilterSetSaved(name, filterState.filterCount);
      notifyListeners();
    }
    return success;
  }

  /// Apply a saved filter set by name
  bool applySavedFilters(String name) {
    final savedFilters = savedFiltersManager.getFilterSetByName(name);
    if (savedFilters == null) return false;

    // Clear existing filters and apply the saved ones
    filterState.clearFilters();
    for (var filter in savedFilters) {
      filterState.addFilter(filter);
    }

    // Track application of saved filter set
    _analytics.trackSavedFilterApplied(name, savedFilters.length);

    notifyListeners();
    return true;
  }

  /// Delete a saved filter set by name
  Future<bool> deleteSavedFilterSet(String name) async {
    final success = await savedFiltersManager.deleteFilterSet(name);
    if (success) {
      notifyListeners();
    }
    return success;
  }

  /// Get all saved filter sets
  Map<String, List<FilterCriteria>> get savedFilterSets =>
      savedFiltersManager.savedFilterSets;

  /// Apply a filter and notify listeners
  void addFilter(String field, dynamic value, FilterOperator operator) {
    final filter =
        FilterCriteria(field: field, value: value, operator: operator);
    filterState.addFilter(filter);

    // Track the filter application in analytics
    _analytics.trackFilterApplied(filter);

    notifyListeners();
  }

  /// Remove a filter and notify listeners
  void removeFilter(String field) {
    filterState.removeFilterByField(field);

    // Track filter removal in analytics
    _analytics.trackFilterRemoved(field);

    notifyListeners();
  }

  /// Clear all filters and notify listeners
  void clearFilters() {
    filterState.clearFilters();

    // Track clearing of filters
    _analytics.trackFilterCleared();

    notifyListeners();
  }

  /// Set user ID for analytics tracking
  Future<void> setAnalyticsUserId(String? userId) async {
    await _analytics.setUserId(userId);
  }

  /// Track the current filter combination (typically called when executing a search)
  Future<void> trackFilterUsage() async {
    if (filterState.hasFilters) {
      await _analytics.trackFilterCombination(filterState.filters.toList());
    }
  }

  /// Get popular filter combinations for suggestions
  List<Map<String, dynamic>> getPopularFilterCombinations({int limit = 5}) {
    return _analytics.getPopularFilterCombinations(limit: limit);
  }

  /// Save filter preferences explicitly
  Future<void> saveFilterPreferences() async {
    await filterState.saveFilters();
  }
}
