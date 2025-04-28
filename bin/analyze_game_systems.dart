import 'dart:convert';
import 'dart:io';

/// Command-line tool to analyze game systems in the database
/// This is a pure Dart script with no Flutter or Firebase dependencies

// Setup error logging to file
void logMessage(String message, {bool isError = false}) {
  if (isError) {
    print('ERROR: $message');
  } else {
    print(message);
  }

  final errorLog = File('error.log');
  final prefix = isError ? "ERROR: " : "";
  errorLog.writeAsStringSync('${DateTime.now()}: $prefix$message\n',
      mode: FileMode.append);
}

// Create directory if it doesn't exist
void ensureDirectoryExists(String path) {
  final dir = Directory(path);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
}

// Main function to perform analysis
Future<void> main() async {
  // Create or clear the error log file
  final errorLog = File('error.log');
  if (errorLog.existsSync()) {
    errorLog.writeAsStringSync(''); // Clear the file
  }
  errorLog.writeAsStringSync(
      '--- Game System Analysis Log ${DateTime.now()} ---\n');

  try {
    logMessage('Starting game system analysis...');

    // First try to run a Node.js script (which has better Firebase support)
    if (await _tryNodeJsAnalyzer()) {
      logMessage('Analysis completed successfully using Node.js!');
      return;
    }

    // Fall back to manual extraction from a Firestore export or other formats
    logMessage('Node.js analyzer not available, trying alternative methods...');

    // Check if there's a Firestore export file we can use
    if (await _tryAnalyzeFromExport()) {
      logMessage('Analysis completed successfully from export file!');
      return;
    }

    // Manual extraction - ask user for input
    logMessage('\nNo automated extraction method worked.');
    logMessage(
        'Please export your game systems data manually and place it in:');
    logMessage('  - analysis_reports/quest_cards_export.json');
    logMessage('\nThen run this command again.');
  } catch (e, stackTrace) {
    logMessage('Error during analysis: $e\n$stackTrace', isError: true);
  }
}

// Try to run a Node.js script to do the analysis
Future<bool> _tryNodeJsAnalyzer() async {
  try {
    // Create the Node.js script first
    final scriptPath = 'analysis_scripts';
    ensureDirectoryExists(scriptPath);

    // Create the analyzer script
    final analyzerScript = File('$scriptPath/analyze_game_systems.js');
    await analyzerScript.writeAsString("""
// Firebase Firestore game system analyzer
const fs = require('fs');
const path = require('path');
const { initializeApp } = require('firebase/app');
const { getFirestore, collection, getDocs } = require('firebase/firestore');

// Initialize Firebase with your config
const firebaseConfig = {
  // Your web app firebase config goes here
  // This will be read from a config file
};

async function loadConfig() {
  try {
    const configPath = path.join(__dirname, 'firebase_config.json');
    if (fs.existsSync(configPath)) {
      const configData = fs.readFileSync(configPath, 'utf8');
      return JSON.parse(configData);
    } else {
      console.error('Firebase config file not found. Create analysis_scripts/firebase_config.json');
      return null;
    }
  } catch (error) {
    console.error('Error loading config:', error);
    return null;
  }
}

async function analyzeGameSystems() {
  // Load Firebase config
  const config = await loadConfig();
  if (!config) {
    process.exit(1);
  }

  // Initialize Firebase
  const app = initializeApp(config);
  const db = getFirestore(app);
  
  // Map to store game system counts
  const gameSystemCounts = {};
  
  try {
    console.log('Fetching quest cards from Firestore...');
    
    // Get all documents from questCards collection
    const querySnapshot = await getDocs(collection(db, 'questCards'));
    
    console.log(`Found \${querySnapshot.size} quest cards to analyze`);
    
    // Process each document
    querySnapshot.forEach((doc) => {
      const data = doc.data();
      if (data.gameSystem && typeof data.gameSystem === 'string' && data.gameSystem.trim() !== '') {
        const gameSystem = data.gameSystem;
        gameSystemCounts[gameSystem] = (gameSystemCounts[gameSystem] || 0) + 1;
      }
    });
    
    // Generate variation groups
    console.log(`Identified \${Object.keys(gameSystemCounts).length} unique game systems`);
    const variationGroups = generateVariationGroups(gameSystemCounts);
    
    // Create analysis_reports directory if it doesn't exist
    const reportsDir = 'analysis_reports';
    if (!fs.existsSync(reportsDir)) {
      fs.mkdirSync(reportsDir);
    }
    
    // Save the reports
    fs.writeFileSync(
      `\${reportsDir}/game_system_frequency.json`, 
      JSON.stringify(gameSystemCounts, null, 2)
    );
    
    fs.writeFileSync(
      `\${reportsDir}/game_system_variations.json`, 
      JSON.stringify(variationGroups, null, 2)
    );
    
    console.log('Reports saved to analysis_reports directory');
    
  } catch (error) {
    console.error('Error analyzing game systems:', error);
  }
}

function generateVariationGroups(gameSystemCounts) {
  const variationGroups = {};
  const processedSystems = new Set();
  
  // For each game system
  Object.entries(gameSystemCounts).forEach(([system, count]) => {
    // Skip if already processed
    if (processedSystems.has(system)) return;
    
    // Mark as processed
    processedSystems.add(system);
    
    // Create new group
    const normalizedSystem = system.toLowerCase();
    const group = [];
    
    // Add this system as primary
    group.push({
      name: system,
      count: count,
      matchType: 'primary'
    });
    
    // Find variations
    Object.entries(gameSystemCounts).forEach(([otherSystem, otherCount]) => {
      if (system !== otherSystem && !processedSystems.has(otherSystem)) {
        const normalizedOther = otherSystem.toLowerCase();
        
        // Check for similar names
        let isSimilar = false;
        
        // Substring match
        if (normalizedSystem.includes(normalizedOther) || 
            normalizedOther.includes(normalizedSystem)) {
          isSimilar = true;
        }
        
        // Acronym check
        const systemWords = normalizedSystem.split(/[\\s&]+/);
        const acronym = systemWords
          .map(word => word.length > 0 ? word[0] : '')
          .join('');
        
        if (normalizedOther === acronym) {
          isSimilar = true;
        }
        
        if (isSimilar) {
          group.push({
            name: otherSystem,
            count: otherCount,
            matchType: 'variation'
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
  
  return variationGroups;
}

analyzeGameSystems().catch(console.error);
""");

    // Create a notice about creating config file
    logMessage(
        'Node.js analyzer script created. You need to create a Firebase config file.');
    logMessage('Please add your Firebase web app config to:');
    logMessage('  - analysis_scripts/firebase_config.json');

    // Try to create config template if it doesn't exist
    final configFile = File('$scriptPath/firebase_config.json');
    if (!configFile.existsSync()) {
      await configFile.writeAsString("""
{
  "apiKey": "YOUR_API_KEY",
  "authDomain": "YOUR_PROJECT_ID.firebaseapp.com",
  "projectId": "YOUR_PROJECT_ID",
  "storageBucket": "YOUR_PROJECT_ID.appspot.com",
  "messagingSenderId": "YOUR_MESSAGING_SENDER_ID",
  "appId": "YOUR_APP_ID",
  "measurementId": "YOUR_MEASUREMENT_ID"
}
""");
    }

    // Check if Node.js is installed
    try {
      final result = await Process.run('node', ['--version']);
      if (result.exitCode != 0) {
        logMessage(
            'Node.js not found. Please install Node.js to use this analyzer.',
            isError: true);
        return false;
      }

      // Install required npm packages if needed
      logMessage('Installing required npm packages...');
      final npmResult = await Process.run(
          'npm', ['install', 'firebase', '--prefix', scriptPath],
          runInShell: true);

      if (npmResult.exitCode != 0) {
        logMessage('Error installing npm packages: ${npmResult.stderr}',
            isError: true);
        return false;
      }

      // Check if config file has been updated
      final configContent = await configFile.readAsString();
      if (configContent.contains('YOUR_API_KEY')) {
        logMessage(
            'Please update the Firebase config file with your actual Firebase project details.',
            isError: true);
        return false;
      }

      // Run the Node.js script
      logMessage('Running Node.js analyzer...');
      final nodeResult = await Process.run(
          'node', ['$scriptPath/analyze_game_systems.js'],
          runInShell: true);

      // Log output
      if (nodeResult.stdout != null &&
          nodeResult.stdout.toString().isNotEmpty) {
        logMessage(nodeResult.stdout);
      }

      // Check for errors
      if (nodeResult.exitCode != 0 ||
          (nodeResult.stderr != null &&
              nodeResult.stderr.toString().isNotEmpty)) {
        logMessage('Error running Node.js analyzer: ${nodeResult.stderr}',
            isError: true);
        return false;
      }

      return true;
    } catch (e) {
      logMessage('Error running Node.js: $e', isError: true);
      return false;
    }
  } catch (e) {
    logMessage('Error setting up Node.js analyzer: $e', isError: true);
    return false;
  }
}

// Try to analyze from export file
Future<bool> _tryAnalyzeFromExport() async {
  try {
    final exportFile = File('analysis_reports/quest_cards_export.json');

    if (!exportFile.existsSync()) {
      return false;
    }

    logMessage('Found export file, analyzing...');

    // Parse the export file
    final jsonContent = await exportFile.readAsString();
    final jsonData = jsonDecode(jsonContent);

    // Map to store game system counts
    final Map<String, int> gameSystemCounts = {};

    // Process the data
    if (jsonData is List) {
      for (final item in jsonData) {
        if (item is Map && item.containsKey('gameSystem')) {
          final gameSystem = item['gameSystem'];
          if (gameSystem is String && gameSystem.isNotEmpty) {
            gameSystemCounts[gameSystem] =
                (gameSystemCounts[gameSystem] ?? 0) + 1;
          }
        }
      }
    } else if (jsonData is Map && jsonData.containsKey('documents')) {
      final documents = jsonData['documents'];
      if (documents is List) {
        for (final doc in documents) {
          if (doc is Map && doc.containsKey('fields') && doc['fields'] is Map) {
            final fields = doc['fields'];
            if (fields.containsKey('gameSystem')) {
              final gameSystem = fields['gameSystem'];
              final gameSystemValue =
                  gameSystem is Map && gameSystem.containsKey('stringValue')
                      ? gameSystem['stringValue']
                      : null;

              if (gameSystemValue is String && gameSystemValue.isNotEmpty) {
                gameSystemCounts[gameSystemValue] =
                    (gameSystemCounts[gameSystemValue] ?? 0) + 1;
              }
            }
          }
        }
      }
    }

    if (gameSystemCounts.isEmpty) {
      logMessage('No game system data found in export file.', isError: true);
      return false;
    }

    logMessage('Identified ${gameSystemCounts.length} unique game systems');

    // Generate variation groups
    final variationGroups = _generateVariationGroups(gameSystemCounts);

    // Create analysis_reports directory if it doesn't exist
    ensureDirectoryExists('analysis_reports');

    // Save the frequency report
    final frequencyReportFile =
        File('analysis_reports/game_system_frequency.json');
    await frequencyReportFile
        .writeAsString(JsonEncoder.withIndent('  ').convert(gameSystemCounts));

    // Save the variations report
    final variationsReportFile =
        File('analysis_reports/game_system_variations.json');
    await variationsReportFile
        .writeAsString(JsonEncoder.withIndent('  ').convert(variationGroups));

    logMessage('Reports saved to analysis_reports directory');

    return true;
  } catch (e) {
    logMessage('Error analyzing from export file: $e', isError: true);
    return false;
  }
}

// Generate variation groups from game system counts
Map<String, List<Map<String, dynamic>>> _generateVariationGroups(
    Map<String, int> gameSystemCounts) {
  final variationGroups = <String, List<Map<String, dynamic>>>{};
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
      if (system != otherSystem && !processedSystems.contains(otherSystem)) {
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
        final acronym =
            systemWords.map((word) => word.isNotEmpty ? word[0] : '').join('');

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

  return variationGroups;
}
