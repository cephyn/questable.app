# Purchase Link AI Agent Integration Design

This document outlines the integration approach for the purchase link AI agent with the existing `quest_card_analyze.dart` workflow.

## Current Analysis Workflow

Based on our examination of `quest_card_analyze.dart`, the current workflow is:

1. User selects a file using FilePicker
2. `autoAnalyzeFile()` uploads the file to Firebase Storage
3. AI service determines if the file contains a single adventure or multiple adventures
4. Based on adventure type:
   - `analyzeSingleFile()` processes a single adventure
   - `analyzeMultiFile()` processes multiple adventures
5. For each adventure:
   - Extract metadata using AI
   - Check for duplicates
   - Store the QuestCard in Firestore
6. Return the document IDs for navigation

## Integration Points

We will modify the existing workflow to incorporate purchase link search at two key points:

### 1. Single Adventure Integration

In `analyzeSingleFile()`, we'll add purchase link search to run in parallel with AI metadata extraction:

```dart
Future<List<String>> analyzeSingleFile(String fileUrl) async {
  log("Analyze single quest file from URL: $fileUrl");
  try {
    // Start AI metadata extraction
    log('Calling AI service for single file analysis...');
    var metadataFuture = aiService.analyzeFile(fileUrl);
    
    // Start purchase link search based on preliminary metadata
    // (We'll implement a method to extract basic metadata for search)
    var basicMetadata = await _extractBasicMetadataForSearch(fileUrl);
    var purchaseLinkFuture = _searchForPurchaseLink(basicMetadata);
    
    // Continue with metadata processing
    Map<String, dynamic> questCardSchema = jsonDecode(await metadataFuture);
    QuestCard questCard = QuestCard.fromJson(questCardSchema);
    questCard.uploadedBy = auth.getCurrentUser().email;
    log('AI analysis complete. Title: ${questCard.title}');
    
    // Wait for purchase link search to complete and add to QuestCard
    String? purchaseLink = await purchaseLinkFuture;
    if (purchaseLink != null && purchaseLink.isNotEmpty) {
      questCard.link = purchaseLink;
      log('Purchase link found: ${questCard.link}');
    }
    
    // Continue with duplicate checking and storage as before
    // ...
  } catch (e, s) {
    log("Error in analyzeSingleFile: $e");
    log("Stacktrace: $s");
    rethrow;
  }
}
```

### 2. Multiple Adventure Integration

For `analyzeMultiFile()`, we'll modify the batch processing to include purchase links:

```dart
Future<List<String>> analyzeMultiFile(String fileUrl) async {
  // ... existing setup code ...
  
  try {
    // Analyze the file using AI service
    log('Calling AI service for multi-file analysis...');
    List<Map<String, dynamic>> questCardSchemas = 
        await aiService.analyzeMultiFileQueries(fileUrl);
    
    // Start purchase link searches in parallel for each adventure
    List<Future<PurchaseLinkResult>> purchaseLinkFutures = [];
    for (var schema in questCardSchemas) {
      if (schema['title'] != null && schema['publisher'] != null) {
        var searchData = {
          'title': schema['title'],
          'publisher': schema['publisher'],
          'gameSystem': schema['gameSystem'],
        };
        purchaseLinkFutures.add(_searchForPurchaseLink(searchData));
      } else {
        purchaseLinkFutures.add(Future.value(PurchaseLinkResult(null, null)));
      }
    }
    
    // Wait for all purchase link searches to complete
    List<PurchaseLinkResult> purchaseLinks = await Future.wait(purchaseLinkFutures);
    
    // Process results: identify duplicates and prepare new cards
    for (int i = 0; i < questCardSchemas.length; i++) {
      QuestCard q = QuestCard.fromJson(questCardSchemas[i]);
      
      // Apply purchase link if found
      if (i < purchaseLinks.length && purchaseLinks[i].url != null) {
        q.link = purchaseLinks[i].url;
        log('Purchase link found for ${q.title}: ${q.link}');
      }
      
      // Continue with duplicate checking and preparation
      // ...
    }
    
    // Continue with batch writes and notifications
    // ...
  } catch (e, s) {
    // ... error handling ...
  }
}
```

## Helper Methods

We'll add the following helper methods to the `_QuestCardAnalyzeState` class:

### Basic Metadata Extraction

```dart
Future<Map<String, String>> _extractBasicMetadataForSearch(String fileUrl) async {
  try {
    // Use a simplified AI request to extract just title, publisher, and game system
    var basicMetadata = await aiService.extractBasicMetadata(fileUrl);
    return {
      'title': basicMetadata['title'] ?? '',
      'publisher': basicMetadata['publisher'] ?? '',
      'gameSystem': basicMetadata['gameSystem'] ?? '',
    };
  } catch (e) {
    log('Error extracting basic metadata: $e');
    return {};
  }
}
```

### Purchase Link Search

```dart
Future<String?> _searchForPurchaseLink(Map<String, String> metadata) async {
  try {
    // Use a compute isolate to avoid blocking the main thread
    return compute(_isolatedPurchaseLinkSearch, metadata);
  } catch (e) {
    log('Error in purchase link search: $e');
    return null;
  }
}

// This function runs in a separate isolate
static Future<String?> _isolatedPurchaseLinkSearch(Map<String, String> metadata) async {
  // Initialize services needed for search
  final purchaseLinkService = PurchaseLinkService();
  
  // Create search query
  String query = purchaseLinkService.constructSearchQuery(metadata);
  
  // Execute search
  List<SearchResult> results = await purchaseLinkService.search(query);
  
  // Validate and prioritize results
  return purchaseLinkService.validateAndPrioritizeResults(results);
}
```

## Service Registration

We'll need to register our new services:

```dart
// In main.dart or a service_locator.dart file
void setupServiceLocator() {
  // Existing service registrations
  
  // Google PSE services
  GetIt.instance.registerLazySingleton<PurchaseLinkService>(
    () => PurchaseLinkService(
      searchClient: GooglePSEClient(
        apiKey: Config.googleApiKey,
        searchEngineId: Config.googleSearchEngineId,
      ),
      validator: PurchaseLinkValidator(
        publisherDomains: Config.publisherDomains,
        marketplaceDomains: Config.marketplaceDomains,
      ),
      cache: PurchaseLinkCache(),
    ),
  );
}
```

## Configuration

We'll add configuration values for the Google PSE integration:

```dart
// In config.dart
class Config {
  // Existing configuration values
  
  // Google PSE Configuration
  static const String googleApiKey = String.fromEnvironment('GOOGLE_API_KEY');
  static const String googleSearchEngineId = String.fromEnvironment('GOOGLE_SEARCH_ENGINE_ID');
  
  // Publisher domains for validation
  static const List<String> publisherDomains = [
    'wizardsofthecoast.com',
    'paizo.com',
    'koboldpress.com',
    'chaosium.com',
    'goodman-games.com',
    'montecookgames.com',
    'pelgranepress.com',
    'atlas-games.com',
  ];
  
  // Marketplace domains for validation
  static const List<String> marketplaceDomains = [
    'drivethrurpg.com',
    'dmsguild.com',
    'itch.io',
    'rpgnow.com',
    'drivethrucomics.com',
  ];
}
```

## Admin Backfill Implementation

For the admin interface to backfill existing QuestCards:

```dart
class PurchaseLinkBackfillScreen extends StatefulWidget {
  @override
  _PurchaseLinkBackfillScreenState createState() => _PurchaseLinkBackfillScreenState();
}

class _PurchaseLinkBackfillScreenState extends State<PurchaseLinkBackfillScreen> {
  final PurchaseLinkBackfillController _controller = PurchaseLinkBackfillController();
  BackfillStats? _stats;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Purchase Link Backfill')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status section
            if (_stats != null) ...[
              Text('Progress: ${_stats!.processed}/${_stats!.total} (${_stats!.successRate}%)'),
              LinearProgressIndicator(value: _stats!.processed / _stats!.total),
              SizedBox(height: 16),
              Text('Successful links found: ${_stats!.successful}'),
              Text('Failed searches: ${_stats!.failed}'),
              Text('Skipped (already has link): ${_stats!.skipped}'),
            ],
            
            // Controls
            SizedBox(height: 24),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _isProcessing ? null : _startBackfill,
                  child: Text('Start Processing'),
                ),
                SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isProcessing ? _pauseBackfill : null,
                  child: Text('Pause'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startBackfill() async {
    setState(() => _isProcessing = true);
    
    try {
      await for (var stats in _controller.processBackfill()) {
        setState(() => _stats = stats);
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }
  
  Future<void> _pauseBackfill() async {
    await _controller.pauseBackfill();
    setState(() => _isProcessing = false);
  }
}