# Purchase Link AI Agent Technical Design

## Overview
This document outlines the technical design for the AI agent that will search for RPG adventure purchase links after file scanning and data extraction in the Questable application.

## Architecture Components

### 1. Purchase Link Service
A dedicated service class that coordinates the search process:

```dart
class PurchaseLinkService {
  final GooglePSEClient _searchClient;
  final PurchaseLinkValidator _validator;
  final PurchaseLinkCache _cache;

  Future<String?> findPurchaseLink(QuestCard questCard) async {
    // Implementation
  }

  Future<String?> validateAndPrioritizeResults(List<SearchResult> results) async {
    // Implementation
  }
}
```

### 2. Google PSE Client
Handles API communication with Google Custom Search:

```dart
class GooglePSEClient {
  final String apiKey;
  final String searchEngineId;
  final http.Client _httpClient;

  Future<List<SearchResult>> search(String query) async {
    // Implementation
  }

  String generateQuery(QuestCard questCard) {
    // Implementation
  }
}
```

### 3. Purchase Link Validator
Validates and prioritizes search results:

```dart
class PurchaseLinkValidator {
  final List<String> publisherDomains;
  final List<String> marketplaceDomains;
  
  Future<ValidationResult> validate(String url) async {
    // Implementation
  }
  
  int getPriority(String url) {
    // Implementation
  }
}
```

### 4. Purchase Link Cache
Caches search results to minimize API calls:

```dart
class PurchaseLinkCache {
  final Duration cacheDuration;
  
  Future<String?> get(String key) async {
    // Implementation
  }
  
  Future<void> set(String key, String value) async {
    // Implementation
  }
}
```

### 5. Admin Backfill Controller
Manages batch processing of existing QuestCards:

```dart
class PurchaseLinkBackfillController {
  final PurchaseLinkService _purchaseLinkService;
  final FirestoreService _firestoreService;
  
  Future<BackfillStats> processBackfill({int batchSize = 20}) async {
    // Implementation
  }
  
  Future<void> pauseBackfill() async {
    // Implementation
  }
  
  Future<void> resumeBackfill() async {
    // Implementation
  }
}
```

## Integration with quest_card_analyze.dart

The `autoAnalyzeFile` method in `quest_card_analyze.dart` will be extended to include purchase link search:

```dart
Future<QuestCard> autoAnalyzeFile(File file) async {
  // Start AI metadata extraction
  final metadataFuture = extractMetadataFromFile(file);
  
  // Start purchase link search in parallel
  final purchaseLinkFuture = _startPurchaseLinkSearch(file);
  
  // Wait for metadata extraction to complete
  final questCard = await metadataFuture;
  
  // Wait for purchase link search to complete
  final purchaseLink = await purchaseLinkFuture;
  
  // Update QuestCard with purchase link if found
  if (purchaseLink != null) {
    questCard.link = purchaseLink;
  }
  
  return questCard;
}

Future<String?> _startPurchaseLinkSearch(File file) async {
  try {
    // First extract basic metadata needed for search
    final basicMetadata = await _extractBasicMetadata(file);
    
    // Create a temporary QuestCard with basic metadata
    final tempQuestCard = QuestCard(
      productTitle: basicMetadata['productTitle'],
      title: basicMetadata['title'],
      publisher: basicMetadata['publisher'],
      gameSystem: basicMetadata['gameSystem'],
    );
    
    // Run search in compute isolate to avoid blocking main thread
    return compute(_searchForPurchaseLink, tempQuestCard);
  } catch (e) {
    print('Error in purchase link search: $e');
    // Return null on error to avoid breaking main flow
    return null;
  }
}

// This function runs in a separate isolate
Future<String?> _searchForPurchaseLink(QuestCard questCard) async {
  final purchaseLinkService = GetIt.instance<PurchaseLinkService>();
  return await purchaseLinkService.findPurchaseLink(questCard);
}
```

## Asynchronous Processing

The purchase link search will run asynchronously using Dart's `compute` function to leverage isolates:

1. Extract basic metadata needed for search query creation
2. Create search query from metadata
3. Launch isolate for API communication and result processing
4. Continue with main thread metadata extraction in parallel
5. Join results when both processes complete

Flow diagram:
```
┌────────────────┐     ┌────────────────────┐
│ User uploads   │     │ Extract basic      │
│ adventure file ├────►│ metadata for search│
└────────────────┘     └──────────┬─────────┘
                                  │
                                  ▼
┌────────────────┐     ┌────────────────────┐
│ Complete       │     │ Launch search in   │
│ metadata       │◄────┤ separate isolate   │
│ extraction     │     │                    │
└───────┬────────┘     └───────┬────────────┘
        │                      │
        ▼                      ▼
┌────────────────┐     ┌────────────────────┐
│ Create         │     │ Get search results │
│ QuestCard      │     │ & validate links   │
└───────┬────────┘     └───────┬────────────┘
        │                      │
        │                      ▼
        │              ┌────────────────────┐
        │              │ Prioritize links   │
        │              │ (publisher first)  │
        │              └───────┬────────────┘
        │                      │
        ▼                      ▼
┌────────────────────────────────────────────┐
│ Update QuestCard with purchase link        │
└────────────────────────────────────────────┘
```

## Google PSE Configuration

Custom Search Engine configuration:

1. **Search Engine Name**: QuestableRPGProductSearch
2. **Search Sites**:
   - Priority 1: Major RPG publishers
     - wizardsofthecoast.com
     - paizo.com
     - koboldpress.com
     - goodman-games.com
     - chaosium.com
     - montecookgames.com
     - pelgranepress.com
     - atlas-games.com
   - Priority 2: RPG marketplaces
     - drivethrurpg.com
     - dmsguild.com
     - itch.io
     - rpgnow.com
     - drivethrucomics.com
     - drivethrumodules.com
   - Priority 3: General retailers
     - amazon.com
     - barnesandnoble.com

3. **Search Features**:
   - Image search: Disabled
   - Safe search: Enabled
   - Refinements: Disabled

4. **Custom Result Ranking**:
   - Boost direct publisher domains
   - Boost URLs containing "/product/" or "/store/"
   - Demote forum and social media domains

## Query Construction Algorithm

```dart
String constructSearchQuery(QuestCard questCard) {
  final components = <String>[];
  
  // Always include product title in quotes if available
  if (questCard.productTitle != null && questCard.productTitle!.isNotEmpty) {
    components.add('"${questCard.productTitle}"');
  } else if (questCard.title != null && questCard.title!.isNotEmpty) {
    components.add('"${questCard.title}"');
  }
  
  // Include publisher if available
  if (questCard.publisher != null && questCard.publisher!.isNotEmpty) {
    components.add('"${questCard.publisher}"');
  }
  
  // Include game system if available
  if (questCard.gameSystem != null && questCard.gameSystem!.isNotEmpty) {
    components.add(questCard.gameSystem!);
    
    // Include edition if available and not part of system name
    if (questCard.edition != null && 
        questCard.edition!.isNotEmpty && 
        !questCard.gameSystem!.contains(questCard.edition!)) {
      components.add(questCard.edition!);
    }
  }
  
  // Add purchase keywords
  components.add('buy OR purchase OR "official site"');
  
  // Add RPG keyword if not in title or system
  if (!(questCard.productTitle?.toLowerCase().contains('rpg') ?? false) && 
      !(questCard.gameSystem?.toLowerCase().contains('rpg') ?? false)) {
    components.add('rpg');
  }
  
  return components.join(' ');
}
```

## Link Validation Algorithm

```dart
Future<ValidationResult> validateLink(String url) async {
  // Check domain priority
  int priority = getDomainPriority(url);
  
  // Check URL structure score
  int structureScore = getUrlStructureScore(url);
  
  // Perform HTTP head request to verify accessibility
  bool isAccessible = await isUrlAccessible(url);
  
  // Calculate confidence score
  int confidenceScore = calculateConfidenceScore(priority, structureScore);
  
  return ValidationResult(
    url: url,
    priority: priority,
    isValid: isAccessible && structureScore > 0,
    confidenceScore: confidenceScore
  );
}
```

## Error Handling Strategy

1. **API Failures**:
   - Implement exponential backoff retry mechanism
   - Log detailed error information
   - Return null link on persistent failure

2. **Validation Failures**:
   - Skip invalid links
   - Try alternative search queries
   - Log validation failures for analysis

3. **Quota Exhaustion**:
   - Implement quota monitoring
   - Gracefully degrade to no link search when quota is low
   - Prioritize new file analysis over backfill operations

## Security Considerations

1. **API Key Protection**:
   - Store API key in secure environment variable
   - Implement key restrictions by referrer/IP
   - Avoid exposing key in client-side code

2. **URL Validation**:
   - Sanitize all URLs before storage
   - Validate domain against whitelist
   - Check for malicious redirects

## Performance Optimizations

1. **Caching**:
   - Cache search results for 24 hours
   - Use consistent cache keys based on metadata hash
   - Implement cache invalidation strategy for updated metadata

2. **Query Optimization**:
   - Prioritize precise, focused queries
   - Use exact match phrases for titles
   - Limit query length to improve relevance

3. **Batch Processing**:
   - Process backfill operations in small batches
   - Implement pause/resume capability
   - Schedule during off-peak hours

## Dependencies

1. **External Libraries**:
   - `http: ^1.1.0` - For API communication
   - `compute: ^1.0.0` - For isolate management
   - `crypto: ^3.0.3` - For generating cache keys
   - `get_it: ^7.6.0` - For service location

2. **Internal Dependencies**:
   - Access to `quest_card.dart`
   - Access to `quest_card_analyze.dart`
   - Firebase Firestore for data storage
