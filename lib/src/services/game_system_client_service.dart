import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:quest_cards/src/models/standard_game_system.dart';

/// Client-side service for working with standardized game systems
class GameSystemClientService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all standard game systems
  Future<List<StandardGameSystem>> getAllGameSystems() async {
    try {
      final snapshot = await _firestore.collection('game_systems').get();
      return snapshot.docs
          .map(
              (doc) => StandardGameSystem.fromFirestore(doc, SnapshotOptions()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching game systems: $e');
      return [];
    }
  }

  /// Get standard game systems for autocomplete
  Future<List<StandardGameSystemOption>> getGameSystemOptions() async {
    try {
      List<StandardGameSystemOption> options = [];
      final systems = await getAllGameSystems();

      for (var system in systems) {
        // Add the standard name as an option
        options.add(StandardGameSystemOption(
          displayText: system.standardName,
          value: system.standardName,
          isStandardized: true,
        ));

        // Add each alias as an option
        for (var alias in system.aliases) {
          options.add(StandardGameSystemOption(
            displayText: '$alias (→ ${system.standardName})',
            value: alias,
            standardSystem: system.standardName,
            isStandardized: false,
          ));
        }
      }

      // Sort options alphabetically for better user experience
      options.sort((a, b) => a.displayText.compareTo(b.displayText));

      return options;
    } catch (e) {
      debugPrint('Error preparing game system options: $e');
      return [];
    }
  }

  /// Find the standardized name for a given game system
  Future<String?> findStandardizedName(String gameSystem) async {
    if (gameSystem.isEmpty) {
      return null;
    }

    try {
      // First check for exact match by standard name
      final standardQuery = await _firestore
          .collection('game_systems')
          .where('standardName', isEqualTo: gameSystem)
          .limit(1)
          .get();

      if (standardQuery.docs.isNotEmpty) {
        return standardQuery.docs.first.data()['standardName'];
      }

      // Then check all systems and their aliases
      final systems = await getAllGameSystems();

      for (var system in systems) {
        // Check standard name (case insensitive)
        if (system.standardName.toLowerCase() == gameSystem.toLowerCase()) {
          return system.standardName;
        }

        // Check aliases
        for (var alias in system.aliases) {
          if (alias.toLowerCase() == gameSystem.toLowerCase()) {
            return system.standardName;
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error finding standardized name: $e');
      return null;
    }
  }
}

/// Option for game system autocomplete
class StandardGameSystemOption {
  /// The text to display in the dropdown
  final String displayText;

  /// The value to use (original system name)
  final String value;

  /// The standard system name (if an alias)
  final String? standardSystem;

  /// Whether this is a standardized name
  final bool isStandardized;

  StandardGameSystemOption({
    required this.displayText,
    required this.value,
    this.standardSystem,
    required this.isStandardized,
  });
}
