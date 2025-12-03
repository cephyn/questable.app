import 'package:flutter/foundation.dart';
import 'package:quest_cards/src/models/standard_game_system.dart';
import 'package:quest_cards/src/services/game_system_service.dart';

/// Result of a mapping operation with confidence score
class MappingResult {
  final StandardGameSystem? system;
  final double confidence;
  final String matchType;
  final bool isExactMatch;

  MappingResult({
    this.system,
    required this.confidence,
    required this.matchType,
    this.isExactMatch = false,
  });
}

/// Service for mapping non-standard game system names to standard systems
///
/// This service handles:
/// - Exact match mapping
/// - Fuzzy matching for similar names
/// - Confidence scoring for suggested matches
/// - Learning from manual mappings
class GameSystemMapper {
  final GameSystemService _gameSystemService;

  // Constructor with dependency injection
  GameSystemMapper({GameSystemService? gameSystemService})
      : _gameSystemService = gameSystemService ?? GameSystemService();

  // Cache of standard game systems to avoid repeated Firestore calls
  List<StandardGameSystem>? _cachedSystems;
  DateTime? _cacheTimestamp;
  final Duration _cacheDuration = const Duration(minutes: 15);

  /// Log error messages for debugging
  void _logError(String message, dynamic error, [StackTrace? stackTrace]) {
    debugPrint('$message: $error');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }

  /// Find the best matching standard game system for a given name
  ///
  /// Returns a MappingResult with the matched system and confidence score
  Future<MappingResult> findBestMatch(String gameSystemName) async {
    try {
      if (gameSystemName.isEmpty) {
        return MappingResult(
          confidence: 0.0,
          matchType: 'empty',
        );
      }

      // Normalize the input
      final normalizedName = _normalizeGameSystemName(gameSystemName);

      // 1. Try exact match first (most efficient)
      final exactMatch = await _findExactMatch(normalizedName);
      if (exactMatch != null) {
        return MappingResult(
          system: exactMatch,
          confidence: 1.0,
          matchType: 'exact',
          isExactMatch: true,
        );
      }

      // 2. Try fuzzy matching if no exact match
      return await _findFuzzyMatch(normalizedName);
    } catch (e, stackTrace) {
      _logError(
          'Error finding best match for "$gameSystemName"', e, stackTrace);
      return MappingResult(
        confidence: 0.0,
        matchType: 'error',
      );
    }
  }

  /// Find an exact match for a game system name
  ///
  /// Checks both standard names and aliases for exact matches
  Future<StandardGameSystem?> _findExactMatch(String normalizedName) async {
    try {
      // Use the service's findGameSystemByName which handles exact matches
      return await _gameSystemService.findGameSystemByName(normalizedName);
    } catch (e) {
      // Not found, return null (not an error condition)
      return null;
    }
  }

  /// Find fuzzy matches for a game system name
  ///
  /// Uses various string similarity algorithms to find close matches
  Future<MappingResult> _findFuzzyMatch(String normalizedName) async {
    try {
      // Get all game systems (using cache if available)
      final allSystems = await _getAllGameSystems();

      StandardGameSystem? bestMatch;
      double bestScore = 0.0;
      String matchType = 'none';

      for (final system in allSystems) {
        // Check standard name
        double score = _calculateSimilarity(
            normalizedName, _normalizeGameSystemName(system.standardName));
        if (score > bestScore) {
          bestScore = score;
          bestMatch = system;
          matchType = 'name_similarity';
        }
        

        // Check for containing/contained relationship
        if (_isSubstringOf(normalizedName,
                _normalizeGameSystemName(system.standardName)) ||
            _isSubstringOf(_normalizeGameSystemName(system.standardName),
                normalizedName)) {
          double substringScore = 0.85; // High confidence but not exact
          
          if (substringScore > bestScore) {
            bestScore = substringScore;
            bestMatch = system;
            matchType = 'substring';
          }
        }

        // Check for acronym match (e.g., "D&D" for "Dungeons & Dragons")
        if (_isAcronymOf(normalizedName,
                _normalizeGameSystemName(system.standardName)) ||
            _isAcronymOf(_normalizeGameSystemName(system.standardName),
                normalizedName)) {
          double acronymScore = 0.9; // Very high confidence
          
          if (acronymScore > bestScore) {
            bestScore = acronymScore;
            bestMatch = system;
            matchType = 'acronym';
          }
        }

        // Check aliases with the same approach
        for (final alias in system.aliases) {
          final normalizedAlias = _normalizeGameSystemName(alias);

          // Simple similarity
          score = _calculateSimilarity(normalizedName, normalizedAlias);
          
          if (score > bestScore) {
            bestScore = score;
            bestMatch = system;
            matchType = 'alias_similarity';
          }

          // Substring relationship
          if (_isSubstringOf(normalizedName, normalizedAlias) ||
              _isSubstringOf(normalizedAlias, normalizedName)) {
            double substringScore = 0.85;
            
            if (substringScore > bestScore) {
              bestScore = substringScore;
              bestMatch = system;
              matchType = 'alias_substring';
            }
          }

          // Acronym match
          if (_isAcronymOf(normalizedName, normalizedAlias) ||
              _isAcronymOf(normalizedAlias, normalizedName)) {
            double acronymScore = 0.9;
            
            if (acronymScore > bestScore) {
              bestScore = acronymScore;
              bestMatch = system;
              matchType = 'alias_acronym';
            }
          }
        }
      }
      

      // Apply confidence threshold
      if (bestScore < 0.6) {
        return MappingResult(
          system: null,
          confidence: bestScore,
          matchType: 'low_confidence',
        );
      }

      return MappingResult(
        system: bestMatch,
        confidence: bestScore,
        matchType: matchType,
      );
    } catch (e, stackTrace) {
      _logError('Error in fuzzy matching', e, stackTrace);
      return MappingResult(
        confidence: 0.0,
        matchType: 'error',
      );
    }
  }

  /// Get all game systems (with caching for performance)
  Future<List<StandardGameSystem>> _getAllGameSystems() async {
    final now = DateTime.now();
    if (_cachedSystems != null &&
        _cacheTimestamp != null &&
        now.difference(_cacheTimestamp!) < _cacheDuration) {
      return _cachedSystems!;
    }

    _cachedSystems = await _gameSystemService.getAllGameSystems();
    _cacheTimestamp = now;
    return _cachedSystems ?? [];
  }

  /// Normalize a game system name for comparison
  String _normalizeGameSystemName(String name) {
    return name.trim().toLowerCase();
  }

  /// Calculate similarity between two strings
  ///
  /// Uses a combination of string distance algorithms for better results
  double _calculateSimilarity(String str1, String str2) {
    // If strings are equal, return perfect score
    if (str1 == str2) return 1.0;

    // Calculate Levenshtein distance (edit distance)
    final distance = _levenshteinDistance(str1, str2);
    final maxLength = str1.length > str2.length ? str1.length : str2.length;

    // Convert distance to similarity score between 0 and 1
    // A distance of 0 means identical strings (similarity = 1.0)
    // A distance equal to max length means completely different (similarity = 0.0)
    double similarity = 1.0 - (distance / maxLength);

    // Check for common prefixes or suffixes to boost score
    if (str1.startsWith(str2) ||
        str2.startsWith(str1) ||
        str1.endsWith(str2) ||
        str2.endsWith(str1)) {
      similarity = (similarity + 0.85) / 2; // Boost but don't make it perfect
    }

    // Check for word overlap to boost score
    final stopWords = {'and', '&', 'the', 'of', 'for', 'a', 'an'};
    final words1 = str1
      .split(RegExp(r'\s+'))
      .map((w) => w.replaceAll(RegExp(r'[^a-z0-9]'), ''))
      .map((w) => w.length > 1 && w.endsWith('s') ? w.substring(0, w.length - 1) : w)
      .where((w) => w.isNotEmpty && !stopWords.contains(w))
      .toList();
    final words2 = str2
      .split(RegExp(r'\s+'))
      .map((w) => w.replaceAll(RegExp(r'[^a-z0-9]'), ''))
      .map((w) => w.length > 1 && w.endsWith('s') ? w.substring(0, w.length - 1) : w)
      .where((w) => w.isNotEmpty && !stopWords.contains(w))
      .toList();
    final commonWords =
      words1.where((word) => words2.contains(word)).length;

    if (commonWords > 0) {
      final wordSimilarity = 2 * commonWords / (words1.length + words2.length);

      // Increase weight of word overlap to improve fuzzy matching for similar names
      similarity = (similarity * 0.5) + (wordSimilarity * 0.5);
    }

    return similarity;
  }

  /// Calculate Levenshtein distance between two strings
  int _levenshteinDistance(String str1, String str2) {
    // Create a matrix of size (str1.length+1) x (str2.length+1)
    final rows = str1.length + 1;
    final cols = str2.length + 1;
    List<List<int>> distance = List.generate(rows, (_) => List.filled(cols, 0));

    // Initialize the matrix
    for (int i = 0; i < rows; i++) {
      distance[i][0] = i;
    }
    for (int j = 0; j < cols; j++) {
      distance[0][j] = j;
    }

    // Fill the matrix
    for (int i = 1; i < rows; i++) {
      for (int j = 1; j < cols; j++) {
        final cost = str1[i - 1] == str2[j - 1] ? 0 : 1;
        distance[i][j] = [
          distance[i - 1][j] + 1, // deletion
          distance[i][j - 1] + 1, // insertion
          distance[i - 1][j - 1] + cost, // substitution
        ].reduce((min, val) => min < val ? min : val);
      }
    }

    return distance[rows - 1][cols - 1];
  }

  /// Check if one string is an acronym of another
  bool _isAcronymOf(String potential, String full) {
    // Generate acronym from full string
    final words = full.split(RegExp(r'[\s\-&]+'));
    final acronym =
      words.where((word) => word.isNotEmpty).map((word) => word[0]).join('');

    // Normalize both strings by removing non-alphanumeric characters
    final normalize = (String s) => s.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();

    return normalize(acronym) == normalize(potential);
  }

  /// Check if one string is a substring of another (case-insensitive)
  bool _isSubstringOf(String potential, String full) {
    // Convert both strings to lowercase for case-insensitive comparison
    return full.toLowerCase().contains(potential.toLowerCase());
  }

  /// Learn from manual mapping to improve future suggestions
  ///
  /// Records successful mappings to improve future matching
  Future<void> learnFromManualMapping(
      String originalName, StandardGameSystem standardSystem) async {
    try {
      // If the system doesn't already have this as an alias, add it
      if (!standardSystem.aliases.any((alias) =>
          _normalizeGameSystemName(alias) ==
          _normalizeGameSystemName(originalName))) {
        final updatedSystem = standardSystem.copyWith(
          aliases: [...standardSystem.aliases, originalName],
        );

        await _gameSystemService.updateGameSystem(updatedSystem);

        // Update cache
        if (_cachedSystems != null) {
          _cachedSystems = _cachedSystems!
              .map((system) =>
                  system.id == standardSystem.id ? updatedSystem : system)
              .toList();
        }
      }
    } catch (e, stackTrace) {
      _logError('Error learning from manual mapping', e, stackTrace);
    }
  }

  /// Get confidence level description for a given score
  String getConfidenceLevelDescription(double score) {
    if (score >= 0.95) return "Very High";
    if (score >= 0.85) return "High";
    if (score >= 0.75) return "Good";
    if (score >= 0.6) return "Moderate";
    if (score >= 0.4) return "Low";
    return "Very Low";
  }

  /// Clear the cache to force fresh data on next request
  void clearCache() {
    _cachedSystems = null;
    _cacheTimestamp = null;
  }
}
