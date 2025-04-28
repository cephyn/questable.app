import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/standard_game_system.dart';

/// Service for managing standardized game systems in Firestore
class GameSystemService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Only create file reference on platforms that support it
  final File? _errorLogFile =
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
          ? File('error.log')
          : null;

  /// Reference to the game_systems collection
  CollectionReference<Map<String, dynamic>> get gameSystems =>
      _firestore.collection('game_systems');

  /// Reference to the questCards collection (for migration and analysis)
  CollectionReference<Map<String, dynamic>> get questCards =>
      _firestore.collection('questCards');

  /// Log error with stack trace to file
  void _logError(String message, dynamic error, [StackTrace? stackTrace]) {
    final timestamp = DateTime.now();
    final errorMessage = '$message: $error';
    final fullMessage =
        stackTrace != null ? '$errorMessage\n$stackTrace' : errorMessage;

    debugPrint(errorMessage); // Use Flutter's logging system

    // Only write to file if platform supports it
    if (_errorLogFile != null) {
      try {
        _errorLogFile.writeAsStringSync('$timestamp: $fullMessage\n',
            mode: FileMode.append);
      } catch (e) {
        debugPrint('Failed to write to error log: $e');
      }
    }
  }

  /// Get all standardized game systems
  Future<List<StandardGameSystem>> getAllGameSystems() async {
    try {
      debugPrint('Fetching all game systems from Firestore...');
      final snapshot = await gameSystems.get();
      debugPrint('Received ${snapshot.docs.length} game system documents');

      return snapshot.docs
          .map((doc) => StandardGameSystem.fromFirestore(doc, null))
          .toList();
    } catch (e, stackTrace) {
      _logError('Error getting game systems', e, stackTrace);
      rethrow;
    }
  }

  /// Get a standardized game system by ID
  Future<StandardGameSystem?> getGameSystemById(String id) async {
    try {
      final doc = await gameSystems.doc(id).get();
      if (!doc.exists) {
        return null;
      }
      return StandardGameSystem.fromFirestore(doc, null);
    } catch (e, stackTrace) {
      _logError('Error getting game system by ID', e, stackTrace);
      rethrow;
    }
  }

  /// Find a standardized game system by name or alias
  Future<StandardGameSystem?> findGameSystemByName(String name) async {
    if (name.isEmpty) return null;

    try {
      // First try exact match on standardName
      var snapshot = await gameSystems
          .where('standardName', isEqualTo: name)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return StandardGameSystem.fromFirestore(snapshot.docs.first, null);
      }

      // Then try to find in aliases array
      snapshot = await gameSystems
          .where('aliases', arrayContains: name)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return StandardGameSystem.fromFirestore(snapshot.docs.first, null);
      }

      // If still not found, try case-insensitive search
      // Note: Firestore doesn't support case-insensitive searches directly
      // For a real implementation, we'd need to normalize the data or use Cloud Functions
      // Here we'll just fetch all and search in memory (not efficient for large datasets)
      final allSystems = await getAllGameSystems();
      final normalizedName = name.trim().toLowerCase();

      return allSystems.firstWhere(
        (system) =>
            system.standardName.toLowerCase() == normalizedName ||
            system.aliases.any((a) => a.toLowerCase() == normalizedName),
        orElse: () => throw Exception('Not found'),
      );
    } catch (e, stackTrace) {
      _logError('Error finding game system by name', e, stackTrace);
      return null;
    }
  }

  /// Create a new standardized game system
  Future<String> createGameSystem(StandardGameSystem gameSystem) async {
    try {
      final doc = await gameSystems.add(gameSystem.toFirestore());
      return doc.id;
    } catch (e, stackTrace) {
      _logError('Error creating game system', e, stackTrace);
      rethrow;
    }
  }

  /// Update an existing standardized game system
  Future<void> updateGameSystem(StandardGameSystem gameSystem) async {
    try {
      if (gameSystem.id == null) {
        throw ArgumentError(
            'Game system ID cannot be null for update operation');
      }
      await gameSystems.doc(gameSystem.id).update(gameSystem.toFirestore());
    } catch (e, stackTrace) {
      _logError('Error updating game system', e, stackTrace);
      rethrow;
    }
  }

  /// Delete a standardized game system
  Future<void> deleteGameSystem(String id) async {
    try {
      await gameSystems.doc(id).delete();
    } catch (e, stackTrace) {
      _logError('Error deleting game system', e, stackTrace);
      rethrow;
    }
  }

  /// Get all unique game system values currently in use
  /// Used for analysis phase to identify all variations
  Future<Map<String, int>> getUniqueGameSystemValues() async {
    try {
      final Map<String, int> gameSystemCounts = {};

      // Get all quest cards
      final snapshot = await questCards.get();
      if (_errorLogFile != null) {
        _errorLogFile.writeAsStringSync(
            '${DateTime.now()}: Found ${snapshot.docs.length} quest cards to analyze\n',
            mode: FileMode.append);
      }

      // Extract game system values and count occurrences
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final gameSystem = data['gameSystem'];

          if (gameSystem != null &&
              gameSystem is String &&
              gameSystem.isNotEmpty) {
            gameSystemCounts[gameSystem] =
                (gameSystemCounts[gameSystem] ?? 0) + 1;
          }
        } catch (e, stackTrace) {
          _logError('Error processing doc ${doc.id}', e, stackTrace);
        }
      }

      if (_errorLogFile != null) {
        _errorLogFile.writeAsStringSync(
            '${DateTime.now()}: Identified ${gameSystemCounts.length} unique game systems\n',
            mode: FileMode.append);
      }
      return gameSystemCounts;
    } catch (e, stackTrace) {
      _logError('Error getting unique game system values', e, stackTrace);
      rethrow;
    }
  }

  /// Generate a report of game system variations and suggested groupings
  Future<Map<String, List<Map<String, dynamic>>>>
      generateGameSystemVariationsReport() async {
    try {
      final gameSystemCounts = await getUniqueGameSystemValues();
      final Map<String, List<Map<String, dynamic>>> variationGroups = {};

      // Simple algorithm to group similar game systems
      // This is just a starting point - a more sophisticated NLP algorithm would be better
      final processedSystems = <String>{};

      gameSystemCounts.forEach((system, count) {
        // Skip if already processed
        if (processedSystems.contains(system)) return;

        // Mark as processed
        processedSystems.add(system);

        // Create a new group with this system as the key
        final normalizedSystem = system.toLowerCase();
        final group = <Map<String, dynamic>>[];

        // Add this system to its group
        group.add({
          'name': system,
          'count': count,
          'matchType': 'primary',
        });

        // Find variations
        gameSystemCounts.forEach((otherSystem, otherCount) {
          if (system != otherSystem &&
              !processedSystems.contains(otherSystem)) {
            final normalizedOther = otherSystem.toLowerCase();

            // Check for similar names
            bool isSimilar = false;

            // Check for substring match
            if (normalizedSystem.contains(normalizedOther) ||
                normalizedOther.contains(normalizedSystem)) {
              isSimilar = true;
            }

            // Check for acronyms
            // e.g., "Dungeons & Dragons" and "D&D"
            final systemWords = normalizedSystem.split(RegExp(r'[\s&]+'));
            final acronym = systemWords
                .map((word) => word.isNotEmpty ? word[0] : '')
                .join('');

            if (normalizedOther == acronym) {
              isSimilar = true;
            }

            if (isSimilar) {
              group.add({
                'name': otherSystem,
                'count': otherCount,
                'matchType': 'variation',
              });
              processedSystems.add(otherSystem);
            }
          }
        });

        // Only add groups with variations
        if (group.length > 1) {
          variationGroups[system] = group;
        }
      });

      if (_errorLogFile != null) {
        _errorLogFile.writeAsStringSync(
            '${DateTime.now()}: Generated ${variationGroups.length} variation groups\n',
            mode: FileMode.append);
      }
      return variationGroups;
    } catch (e, stackTrace) {
      _logError(
          'Error generating game system variations report', e, stackTrace);
      rethrow;
    }
  }

  /// Update a quest card with standardized game system information
  Future<void> updateQuestCardGameSystem(String questCardId,
      String originalGameSystem, StandardGameSystem standardSystem) async {
    try {
      await questCards.doc(questCardId).update({
        'gameSystem': originalGameSystem, // Keep original for reference
        'standardizedGameSystem': standardSystem.standardName,
        'systemMigrationStatus': 'completed',
        'systemMigrationTimestamp': FieldValue.serverTimestamp(),
      });
    } catch (e, stackTrace) {
      _logError('Error updating quest card game system', e, stackTrace);
      rethrow;
    }
  }
}
