import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import '../models/standard_game_system.dart';
import '../services/game_system_service.dart';

/// A tool for analyzing game system data and generating standardization reports
class GameSystemAnalyzer {
  final GameSystemService _gameSystemService = GameSystemService();
  final File _errorLogFile = File('error.log');

  /// Log both to console and error log file
  void _log(String message, {bool isError = false}) {
    log(message);
    if (isError) {
      _errorLogFile.writeAsStringSync('${DateTime.now()}: $message\n',
          mode: FileMode.append);
    }
  }

  /// Log error with stack trace
  void _logError(String message, dynamic error, StackTrace stackTrace) {
    final errorMessage = '$message: $error\n$stackTrace';
    log(errorMessage);
    _errorLogFile.writeAsStringSync('${DateTime.now()}: $errorMessage\n',
        mode: FileMode.append);
  }

  /// Extract all unique game system values from the database and print a report
  Future<void> analyzeGameSystems() async {
    try {
      _log('Starting game system analysis...');

      // Get unique game system values with counts
      final gameSystemCounts =
          await _gameSystemService.getUniqueGameSystemValues();

      _log('Found ${gameSystemCounts.length} unique game system values');

      // Sort by frequency (most common first)
      final sortedSystems = gameSystemCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Print frequency report
      _log('\nGame System Frequency Report:');
      _log('==============================');
      for (var entry in sortedSystems) {
        _log('${entry.key}: ${entry.value} occurrences');
      }

      // Generate variation groups
      final variationGroups =
          await _gameSystemService.generateGameSystemVariationsReport();

      _log('\nSuggested Game System Groupings:');
      _log('===============================');
      variationGroups.forEach((system, variations) {
        _log('Group: $system');
        for (var variation in variations) {
          _log(
              '  - ${variation['name']} (${variation['count']} cards, ${variation['matchType']})');
        }
        _log('');
      });

      // Save reports to files
      await _saveReportsToFiles(gameSystemCounts, variationGroups);

      _log('Analysis complete!');
    } catch (e, stackTrace) {
      _logError('Error analyzing game systems', e, stackTrace);
      rethrow;
    }
  }

  /// Save analysis reports to files for later reference
  Future<void> _saveReportsToFiles(Map<String, int> gameSystemCounts,
      Map<String, List<Map<String, dynamic>>> variationGroups) async {
    try {
      // Create reports directory if it doesn't exist
      final reportsDir = Directory('analysis_reports');
      if (!reportsDir.existsSync()) {
        reportsDir.createSync();
      }

      // Save frequency report
      final frequencyReport =
          File('analysis_reports/game_system_frequency.json');
      await frequencyReport.writeAsString(jsonEncode(gameSystemCounts));

      // Save variations report
      final variationsReport =
          File('analysis_reports/game_system_variations.json');
      await variationsReport.writeAsString(jsonEncode(variationGroups));

      _log('Reports saved to analysis_reports directory');
    } catch (e, stackTrace) {
      _logError('Error saving reports', e, stackTrace);
    }
  }

  /// Generate an initial list of standardized game systems based on analysis
  Future<List<StandardGameSystem>> generateInitialStandardSystems() async {
    try {
      final variationGroups =
          await _gameSystemService.generateGameSystemVariationsReport();
      final standardSystems = <StandardGameSystem>[];

      // Create a standard system for each variation group
      variationGroups.forEach((system, variations) {
        final standardName = system;
        final aliases = <String>[];

        // Add variations as aliases
        for (var variation in variations) {
          if (variation['matchType'] == 'variation') {
            aliases.add(variation['name'] as String);
          }
        }

        // Create the standard system
        final standardSystem = StandardGameSystem(
          standardName: standardName,
          aliases: aliases,
          description: 'Auto-generated from analysis',
          editions: [],
        );

        standardSystems.add(standardSystem);
      });

      // Add standalone systems (those without variations)
      final gameSystemCounts =
          await _gameSystemService.getUniqueGameSystemValues();

      for (var entry in gameSystemCounts.entries) {
        final system = entry.key;

        // Check if this system is already included in one of the variation groups
        bool alreadyIncluded = false;
        for (var standardSystem in standardSystems) {
          if (standardSystem.standardName == system ||
              standardSystem.aliases.contains(system)) {
            alreadyIncluded = true;
            break;
          }
        }

        // If not already included, create a new standard system for it
        if (!alreadyIncluded) {
          standardSystems.add(StandardGameSystem(
            standardName: system,
            aliases: [],
            description: 'Auto-generated from analysis',
            editions: [],
          ));
        }
      }

      return standardSystems;
    } catch (e, stackTrace) {
      _logError('Error generating initial standard systems', e, stackTrace);
      rethrow;
    }
  }

  /// Save initial standard systems to Firestore
  Future<void> saveInitialStandardSystems() async {
    try {
      _log('Generating initial standard game systems...');

      final standardSystems = await generateInitialStandardSystems();

      _log('Generated ${standardSystems.length} standard systems');

      // Save to Firestore
      int successful = 0;
      for (var system in standardSystems) {
        try {
          await _gameSystemService.createGameSystem(system);
          successful++;
        } catch (e, stackTrace) {
          _logError(
              'Error saving system "${system.standardName}"', e, stackTrace);
        }
      }

      _log(
          'Initial standard systems saved to Firestore ($successful/${standardSystems.length} successful)');
    } catch (e, stackTrace) {
      _logError('Error saving initial standard systems', e, stackTrace);
      rethrow;
    }
  }
}

// Entry point for running the analyzer from the command line
Future<void> main() async {
  try {
    final errorLog = File('error.log');
    if (errorLog.existsSync()) {
      errorLog.writeAsStringSync(''); // Clear the file
    }
    errorLog.writeAsStringSync(
        '--- Game System Analyzer Tool ${DateTime.now()} ---\n');

    final analyzer = GameSystemAnalyzer();
    await analyzer.analyzeGameSystems();

    // Prompt user for confirmation before saving to Firestore
    stdout.write(
        'Would you like to save these standard systems to Firestore? (y/n): ');
    final response = stdin.readLineSync();

    if (response?.toLowerCase() == 'y') {
      await analyzer.saveInitialStandardSystems();
      log('Initial standard systems saved to Firestore');
    } else {
      log('Operation cancelled');
    }
  } catch (e, stackTrace) {
    final errorLog = File('error.log');
    errorLog.writeAsStringSync('${DateTime.now()}: Error: $e\n$stackTrace\n',
        mode: FileMode.append);
    log('Error: $e');
  } finally {
    exit(0);
  }
}
