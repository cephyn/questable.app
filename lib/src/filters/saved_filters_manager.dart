import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quest_cards/src/filters/filter_state.dart';

/// Direction of sync operation
enum SyncDirection {
  toFirestore, // Local -> Firestore
  fromFirestore // Firestore -> Local
}

/// A class to manage saved filter sets with names
class SavedFiltersManager extends ChangeNotifier {
  static const String _localPrefsKey = 'saved_filter_sets';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Map of filter set name to list of filter criteria
  final Map<String, List<FilterCriteria>> _savedFilterSets = {};

  // Flag to track if the manager has been initialized
  bool _initialized = false;

  /// Get all saved filter sets
  Map<String, List<FilterCriteria>> get savedFilterSets =>
      Map.unmodifiable(_savedFilterSets);

  /// Check if the manager has been initialized
  bool get isInitialized => _initialized;

  /// Check if the user is authenticated
  bool get isUserAuthenticated => _auth.currentUser != null;

  /// Initialize the manager and load saved filters
  Future<void> initialize() async {
    if (_initialized) return;

    await _loadLocalFilters();

    // If user is authenticated, also try to load from Firestore
    if (isUserAuthenticated) {
      try {
        await _syncWithFirestore(direction: SyncDirection.fromFirestore);
      } catch (e) {
        debugPrint('Error syncing filters from Firestore: $e');
      }
    }

    _initialized = true;
    notifyListeners();
  }

  /// Save the current filter set with a name
  Future<bool> saveFilterSet(String name, List<FilterCriteria> filters) async {
    if (name.trim().isEmpty) return false;

    // Update local storage
    _savedFilterSets[name] = List.from(filters);
    await _saveLocalFilters();

    // If user is authenticated, also save to Firestore
    if (isUserAuthenticated) {
      try {
        await _saveToFirestore(name, filters);
      } catch (e) {
        debugPrint('Error saving filters to Firestore: $e');
        // Continue even if Firestore sync fails
      }
    }

    notifyListeners();
    return true;
  }

  /// Delete a saved filter set by name
  Future<bool> deleteFilterSet(String name) async {
    if (!_savedFilterSets.containsKey(name)) return false;

    // Remove from local storage
    _savedFilterSets.remove(name);
    await _saveLocalFilters();

    // If user is authenticated, also delete from Firestore
    if (isUserAuthenticated) {
      try {
        await _deleteFromFirestore(name);
      } catch (e) {
        debugPrint('Error deleting filters from Firestore: $e');
        // Continue even if Firestore sync fails
      }
    }

    notifyListeners();
    return true;
  }

  /// Update a filter set name or contents
  Future<bool> updateFilterSet(
      String oldName, String newName, List<FilterCriteria> filters) async {
    if (newName.trim().isEmpty) return false;
    if (!_savedFilterSets.containsKey(oldName)) return false;

    // If name is being changed
    if (oldName != newName) {
      _savedFilterSets.remove(oldName);
    }

    // Update the filter set
    _savedFilterSets[newName] = List.from(filters);
    await _saveLocalFilters();

    // If user is authenticated, also update in Firestore
    if (isUserAuthenticated) {
      try {
        if (oldName != newName) {
          // Delete the old entry and create a new one
          await _deleteFromFirestore(oldName);
        }
        await _saveToFirestore(newName, filters);
      } catch (e) {
        debugPrint('Error updating filters in Firestore: $e');
        // Continue even if Firestore sync fails
      }
    }

    notifyListeners();
    return true;
  }

  /// Get a specific filter set by name
  List<FilterCriteria>? getFilterSetByName(String name) {
    if (!_savedFilterSets.containsKey(name)) return null;
    return List.from(_savedFilterSets[name]!);
  }

  /// Load filters from SharedPreferences
  Future<void> _loadLocalFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedFiltersJson = prefs.getString(_localPrefsKey);

      if (savedFiltersJson != null && savedFiltersJson.isNotEmpty) {
        final Map<String, dynamic> savedFilters = jsonDecode(savedFiltersJson);

        _savedFilterSets.clear();

        savedFilters.forEach((name, filtersList) {
          final List<FilterCriteria> filters = [];

          if (filtersList is List) {
            for (var filterMap in filtersList) {
              if (filterMap is Map<String, dynamic>) {
                filters.add(FilterCriteria.fromMap(
                    Map<String, dynamic>.from(filterMap)));
              }
            }
          }

          _savedFilterSets[name] = filters;
        });
      }
    } catch (e) {
      debugPrint('Error loading saved filters from SharedPreferences: $e');
    }
  }

  /// Save filters to SharedPreferences
  Future<void> _saveLocalFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final Map<String, dynamic> savedFilters = {};

      _savedFilterSets.forEach((name, filters) {
        savedFilters[name] = filters.map((filter) => filter.toMap()).toList();
      });

      await prefs.setString(_localPrefsKey, jsonEncode(savedFilters));
    } catch (e) {
      debugPrint('Error saving filters to SharedPreferences: $e');
    }
  }

  /// Save a filter set to Firestore
  Future<void> _saveToFirestore(
      String name, List<FilterCriteria> filters) async {
    if (!isUserAuthenticated) return;

    final userId = _auth.currentUser!.uid;
    final filterSetRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('saved_filters')
        .doc(name);

    await filterSetRef.set({
      'name': name,
      'filters': filters.map((filter) => filter.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete a filter set from Firestore
  Future<void> _deleteFromFirestore(String name) async {
    if (!isUserAuthenticated) return;

    final userId = _auth.currentUser!.uid;
    final filterSetRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('saved_filters')
        .doc(name);
    await filterSetRef.delete();
  }

  /// Sync filters with Firestore (either direction)
  Future<void> _syncWithFirestore({required SyncDirection direction}) async {
    if (!isUserAuthenticated) return;

    final userId = _auth.currentUser!.uid;
    final filtersRef =
        _firestore.collection('users').doc(userId).collection('saved_filters');

    switch (direction) {
      case SyncDirection.fromFirestore:
        // Load from Firestore to local
        final querySnapshot = await filtersRef.get();

        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          final String name = doc.id;
          final List<dynamic>? filtersList = data['filters'] as List<dynamic>?;

          if (filtersList != null) {
            final List<FilterCriteria> filters = [];

            for (var filterMap in filtersList) {
              if (filterMap is Map<String, dynamic>) {
                filters.add(FilterCriteria.fromMap(filterMap));
              }
            }

            _savedFilterSets[name] = filters;
          }
        }

        // Save to local storage to ensure everything is in sync
        await _saveLocalFilters();
        break;

      case SyncDirection.toFirestore:
        // Upload all local filters to Firestore
        final batch = _firestore.batch();

        // First, delete existing documents
        final querySnapshot = await filtersRef.get();
        for (var doc in querySnapshot.docs) {
          batch.delete(doc.reference);
        }

        // Then, add all local filters
        _savedFilterSets.forEach((name, filters) {
          final docRef = filtersRef.doc(name);
          batch.set(docRef, {
            'name': name,
            'filters': filters.map((filter) => filter.toMap()).toList(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });

        await batch.commit();
        break;
    }
  }

  /// Sync all filters to Firestore (for use when user logs in)
  Future<void> syncToFirestore() async {
    if (!isUserAuthenticated) return;
    await _syncWithFirestore(direction: SyncDirection.toFirestore);
  }

  /// Sync all filters from Firestore (for use when user logs in)
  Future<void> syncFromFirestore() async {
    if (!isUserAuthenticated) return;
    await _syncWithFirestore(direction: SyncDirection.fromFirestore);
    notifyListeners();
  }
}
