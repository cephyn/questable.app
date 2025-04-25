import 'dart:convert';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'filter_state.dart';

/// A service to track filter usage and analytics
class FilterAnalytics {
  static final FilterAnalytics _instance = FilterAnalytics._internal();
  static FilterAnalytics get instance => _instance;

  // Private constructor for singleton pattern
  FilterAnalytics._internal();

  // Firebase Analytics instance
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Cache of recently tracked filter combinations to avoid duplicate events
  final Map<String, DateTime> _recentlyTrackedFilters = {};

  // Storage of popular filter combinations
  final Map<String, int> _popularFilterCombinations = {};

  /// Track when a filter is applied
  Future<void> trackFilterApplied(FilterCriteria filter) async {
    try {
      // Log individual filter application
      await _analytics.logEvent(
        name: 'filter_applied',
        parameters: {
          'filter_field': filter.field,
          'filter_value': _sanitizeValue(filter.value),
          'filter_operator': filter.operator.toString(),
        },
      );

      debugPrint(
          'Analytics: Filter applied - ${filter.field}: ${filter.value}');
    } catch (e) {
      debugPrint('Error tracking filter applied: $e');
    }
  }

  /// Track when a filter is removed
  Future<void> trackFilterRemoved(String field) async {
    try {
      await _analytics.logEvent(
        name: 'filter_removed',
        parameters: {
          'filter_field': field,
        },
      );

      debugPrint('Analytics: Filter removed - $field');
    } catch (e) {
      debugPrint('Error tracking filter removed: $e');
    }
  }

  /// Track when filters are cleared
  Future<void> trackFilterCleared() async {
    try {
      await _analytics.logEvent(name: 'filters_cleared');

      debugPrint('Analytics: All filters cleared');
    } catch (e) {
      debugPrint('Error tracking filters cleared: $e');
    }
  }

  /// Track a set of active filters when a search or query is executed
  Future<void> trackFilterCombination(List<FilterCriteria> filters) async {
    if (filters.isEmpty) return;

    try {
      // Create a sorted, stringified representation of the filters for consistency
      List<Map<String, dynamic>> filterMaps =
          filters.map((filter) => filter.toMap()).toList();

      // Sort by field name for consistency
      filterMaps.sort(
          (a, b) => (a['field'] as String).compareTo(b['field'] as String));
      String filterKey = jsonEncode(filterMaps);

      // Check if we've tracked this exact combination recently (within 5 minutes)
      final now = DateTime.now();
      if (_recentlyTrackedFilters.containsKey(filterKey)) {
        final lastTracked = _recentlyTrackedFilters[filterKey]!;
        if (now.difference(lastTracked).inMinutes < 5) {
          // Skip tracking this combination since it was tracked recently
          return;
        }
      }

      // Update recently tracked filters
      _recentlyTrackedFilters[filterKey] = now;

      // Clean up old entries in the recently tracked filters map
      _cleanupRecentlyTrackedFilters();

      // Track for popular combinations
      _popularFilterCombinations[filterKey] =
          (_popularFilterCombinations[filterKey] ?? 0) + 1;

      // Create map of field:value pairs for analytics
      Map<String, dynamic> parameters = {};
      for (int i = 0; i < filters.length; i++) {
        parameters['field_${i + 1}'] = filters[i].field;
        parameters['value_${i + 1}'] = _sanitizeValue(filters[i].value);
      }
      parameters['filter_count'] = filters.length;

      // Log the filter combination
      await _analytics.logEvent(
        name: 'filter_combination_used',
        parameters: parameters.cast<String, Object>(),
      );

      debugPrint(
          'Analytics: Filter combination tracked - ${parameters.toString()}');
    } catch (e) {
      debugPrint('Error tracking filter combination: $e');
    }
  }

  /// Track when a saved filter set is applied
  Future<void> trackSavedFilterApplied(String name, int filterCount) async {
    try {
      await _analytics.logEvent(
        name: 'saved_filter_applied',
        parameters: {
          'filter_name': name,
          'filter_count': filterCount,
        },
      );

      debugPrint(
          'Analytics: Saved filter applied - $name ($filterCount filters)');
    } catch (e) {
      debugPrint('Error tracking saved filter applied: $e');
    }
  }

  /// Track when a filter set is saved
  Future<void> trackFilterSetSaved(String name, int filterCount) async {
    try {
      await _analytics.logEvent(
        name: 'filter_set_saved',
        parameters: {
          'filter_name': name,
          'filter_count': filterCount,
        },
      );

      debugPrint('Analytics: Filter set saved - $name ($filterCount filters)');
    } catch (e) {
      debugPrint('Error tracking filter set saved: $e');
    }
  }

  /// Get the most popular filter combinations
  List<Map<String, dynamic>> getPopularFilterCombinations({int limit = 5}) {
    final entries = _popularFilterCombinations.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final result = <Map<String, dynamic>>[];
    for (int i = 0; i < limit && i < entries.length; i++) {
      try {
        final filters = jsonDecode(entries[i].key) as List<dynamic>;
        result.add({
          'filters': filters,
          'count': entries[i].value,
        });
      } catch (e) {
        debugPrint('Error parsing filter combination: $e');
      }
    }

    return result;
  }

  /// Set the user ID for analytics (for authenticated users)
  Future<void> setUserId(String? userId) async {
    if (userId != null && userId.isNotEmpty) {
      try {
        await _analytics.setUserId(id: userId);
        debugPrint('Analytics: User ID set - $userId');
      } catch (e) {
        debugPrint('Error setting analytics user ID: $e');
      }
    }
  }

  /// Remove old entries from recently tracked filters map
  void _cleanupRecentlyTrackedFilters() {
    final now = DateTime.now();
    _recentlyTrackedFilters
        .removeWhere((key, timestamp) => now.difference(timestamp).inHours > 1);
  }

  /// Convert filter value to a string representation suitable for analytics
  dynamic _sanitizeValue(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return value;
    if (value is List) {
      if (value.length > 5) {
        return '${value.take(5).join(", ")}... (${value.length} items)';
      }
      return value.join(", ");
    }
    return value.toString();
  }
}
