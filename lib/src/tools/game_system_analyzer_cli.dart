import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../firebase_options.dart';

// Log to both console and file
void log(String message, {bool isError = false}) {
  print(message);
  final errorLog = File('error.log');
  errorLog.writeAsStringSync('${DateTime.now()}: $message\n',
      mode: FileMode.append);
}

// Log error with stack trace
void logError(String message, dynamic error, [StackTrace? stackTrace]) {
  final errorMessage =
      stackTrace != null ? '$message: $error\n$stackTrace' : '$message: $error';
  print('ERROR: $errorMessage');
  final errorLog = File('error.log');
  errorLog.writeAsStringSync('${DateTime.now()}: $errorMessage\n',
      mode: FileMode.append);
}

/// Pure Dart implementation of game system analyzer without Flutter dependencies
class GameSystemAnalyzerCli {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get a reference to the questCards collection
  CollectionReference<Map<String, dynamic>> get questCards =>
      _firestore.collection('questCards');

  /// Get a reference to the game_systems collection
  CollectionReference<Map<String, dynamic>> get gameSystems =>
      _firestore.collection('game_systems');

  /// Extract all unique game system values from the database
  Future<Map<String, int>> getUniqueGameSystemValues() async {
    try {
      final Map<String, int> gameSystemCounts = {};

      log('Fetching all quest cards from Firestore...');
      // Get all quest cards
      final snapshot = await questCards.get();
      log('Found ${snapshot.docs.length} quest cards to analyze');

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
          logError('Error processing doc ${doc.id}', e, stackTrace);
        }
      }

      log('Identified ${gameSystemCounts.length} unique game systems');
      return gameSystemCounts;
    } catch (e, stackTrace) {
      logError('Error getting unique game system values', e, stackTrace);
      rethrow;
    }
  }

  /// Generate a report of game system variations and suggested groupings
  Future<Map<String, List<Map<String, dynamic>>>>
      generateGameSystemVariationsReport() async {
    try {
      final gameSystemCounts = await getUniqueGameSystemValues();
      final Map<String, List<Map<String, dynamic>>> variationGroups = {};

      log('Generating variation groups...');
      // Simple algorithm to group similar game systems
      final processedSystems = <String>{};

      gameSystemCounts.forEach((system, cnt) {
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
          'count': cnt,
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

      log('Generated ${variationGroups.length} variation groups');
      return variationGroups;
    } catch (e, stackTrace) {
      logError('Error generating game system variations report', e, stackTrace);
      rethrow;
    }
  }

  /// Save analysis reports to files for later reference
  Future<void> saveReportsToFiles(Map<String, int> gameSystemCounts,
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
      await frequencyReport.writeAsString(
          JsonEncoder.withIndent('  ').convert(gameSystemCounts));

      // Save variations report
      final variationsReport =
          File('analysis_reports/game_system_variations.json');
      await variationsReport
          .writeAsString(JsonEncoder.withIndent('  ').convert(variationGroups));

      log('Reports saved to analysis_reports directory');
    } catch (e, stackTrace) {
      logError('Error saving reports', e, stackTrace);
    }
  }

  /// Run the full analysis process
  Future<void> analyzeGameSystems() async {
    try {
      log('Starting game system analysis...');

      final gameSystemCounts = await getUniqueGameSystemValues();
      final variationGroups = await generateGameSystemVariationsReport();

      // Print frequency report
      log('\nGame System Frequency Report:');
      log('==============================');

      // Sort by frequency (most common first)
      final sortedSystems = gameSystemCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (var entry in sortedSystems) {
        log('${entry.key}: ${entry.value} occurrences');
      }

      // Print variation groups
      log('\nSuggested Game System Groupings:');
      log('===============================');
      variationGroups.forEach((system, variations) {
        log('Group: $system');
        for (var variation in variations) {
          log('  - ${variation['name']} (${variation['count']} cards, ${variation['matchType']})');
        }
        log('');
      });

      // Save reports to files
      await saveReportsToFiles(gameSystemCounts, variationGroups);

      log('Analysis complete!');
    } catch (e, stackTrace) {
      logError('Error analyzing game systems', e, stackTrace);
      rethrow;
    }
  }

  /// Save initial standard systems to Firestore based on analysis
  Future<void> saveInitialStandardSystems() async {
    try {
      log('Not implemented yet - will be added in a separate PR');
      // This functionality will be implemented later to avoid potential errors
    } catch (e, stackTrace) {
      logError('Error saving initial standard systems', e, stackTrace);
      rethrow;
    }
  }
}

/// Command-line entry point
Future<void> main() async {
  try {
    // Setup error logging file
    final errorLog = File('error.log');
    if (errorLog.existsSync()) {
      errorLog.writeAsStringSync(''); // Clear the file
    }
    errorLog.writeAsStringSync(
        '--- Game System Analyzer CLI ${DateTime.now()} ---\n');

    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final analyzer = GameSystemAnalyzerCli();
    await analyzer.analyzeGameSystems();

    // Interactive prompting disabled for this version to avoid Flutter dependencies
    log('\nTo save standardized game systems to Firestore, implement that functionality in a future update.');
  } catch (e, stackTrace) {
    logError('Fatal error in analyzer', e, stackTrace);
  } finally {
    exit(0);
  }
}
