import 'dart:developer';
import '../config/config.dart';
import 'google_pse_client.dart';
import 'purchase_link_validator.dart';
import 'purchase_link_cache.dart';

/// Class for search result with metadata
class PurchaseLinkResult {
  final String? url;
  final Map<String, dynamic> metadata;

  PurchaseLinkResult(this.url, this.metadata);
}

/// A service to find purchase links for RPG adventures
class PurchaseLinkService {
  final GooglePSEClient _searchClient;
  final PurchaseLinkValidator _validator;
  final PurchaseLinkCache _cache;

  /// Create a new PurchaseLinkService
  PurchaseLinkService({
    GooglePSEClient? searchClient,
    PurchaseLinkValidator? validator,
    PurchaseLinkCache? cache,
  })  : _searchClient = searchClient ??
            GooglePSEClient(
              apiKey: Config.googleApiKey,
              searchEngineId: Config.googleSearchEngineId,
            ),
        _validator = validator ??
            PurchaseLinkValidator(
              publisherDomains: Config.publisherDomains,
              marketplaceDomains: Config.marketplaceDomains,
            ),
        _cache = cache ?? PurchaseLinkCache() {
    // log('PurchaseLinkService constructor: Config.googleApiKey at time of GooglePSEClient init is "${Config.googleApiKey}"');
    // log('PurchaseLinkService constructor: Config.googleSearchEngineId at time of GooglePSEClient init is "${Config.googleSearchEngineId}"');
    // Validate configuration on initialization
    if (Config.googleApiKey.isEmpty || Config.googleSearchEngineId.isEmpty) {
      log('WARNING: Google API Key or Search Engine ID is not configured properly');
    }
  }

  /// Finds a purchase link for an RPG adventure
  ///
  /// [metadata] contains the quest card metadata to search for
  /// Returns the best purchase link URL or null if none found
  Future<String?> findPurchaseLink(Map<String, dynamic> metadata) async {
    if (metadata['productTitle']?.isEmpty ??
        true && metadata['title']?.isEmpty ??
        true) {
      log('Cannot search without a product title');
      return null;
    }

    try {
      // Validate configuration
      if (Config.googleApiKey.isEmpty ||
          Config.googleApiKey.contains("YOUR_API_KEY") ||
          Config.googleSearchEngineId.isEmpty ||
          Config.googleSearchEngineId.contains("YOUR_SEARCH_ENGINE_ID")) {
        throw Exception('Google API credentials are missing or invalid');
      }

      String title = metadata['productTitle'] ?? '';
      if (title.isEmpty) {
        title = metadata['title'] ?? '';
      }
      String publisher = metadata['publisher'] ?? '';
      String gameSystem = metadata['gameSystem'] ?? '';

      // Generate the search query
      String query = 'Where can I buy $title';

      if (gameSystem.isNotEmpty) {
        query += ' for $gameSystem';
      }

      if (publisher.isNotEmpty) {
        query += ' by $publisher';
      }

      log('Searching for: $query');

      // Execute the search
      final result = await _searchClient.search(query);
      log('Search returned ${result.length} results');

      if (result.isEmpty) {
        log('No search results found');
        return null;
      }

      // Log first few results for debugging
      for (int i = 0; i < result.length && i < 3; i++) {
        log('Result $i: ${result[i].title} - ${result[i].link}');
      }

      // Process results and find the most likely purchase link
      var link = await _extractPurchaseLink(result, title, publisher);
      log(link != null
          ? 'Final purchase link selected: $link'
          : 'No valid purchase link found after validation');

      return link;
    } catch (e) {
      log('Error in findPurchaseLink: $e');
      // Rethrow to make errors visible
      rethrow;
    }
  }

  /// Validates and prioritizes search results
  ///
  /// [results] is a list of search results
  /// [metadata] contains the quest card metadata for context
  /// Returns the best purchase link URL or null if none found
  Future<String?> validateAndPrioritizeResults(
    List<SearchResult> results,
    Map<String, String> metadata,
  ) async {
    if (results.isEmpty) {
      return null;
    }

    // Process each result and get validation data
    final validationResults = <ValidationResult>[];

    for (final result in results) {
      try {
        final validationResult =
            await _validator.validate(result.link, metadata);
        if (validationResult.isValid) {
          validationResults.add(validationResult);
        }
      } catch (e) {
        log('Error validating URL ${result.link}: $e');
      }
    }

    if (validationResults.isEmpty) {
      return null;
    }

    // Sort by priority (lower is better) and then by confidence score (higher is better)
    validationResults.sort((a, b) {
      final priorityComparison = a.priority.compareTo(b.priority);
      if (priorityComparison != 0) {
        return priorityComparison;
      }
      return b.confidenceScore.compareTo(a.confidenceScore);
    });

    // Return the URL of the best result
    final bestResult = validationResults.first;
    log('Best purchase link for ${metadata['title']}: ${bestResult.url} '
        '(priority: ${bestResult.priority}, score: ${bestResult.confidenceScore})');

    return bestResult.url;
  }

  /// Extracts a purchase link from search results
  ///
  /// [results] is a list of search results
  /// [title] is the title of the RPG adventure
  /// [publisher] is the publisher of the RPG adventure
  Future<String?> _extractPurchaseLink(
      List<SearchResult> results, String title, String publisher) async {
    if (results.isEmpty) {
      return null;
    }

    // Limit to top 5 results
    final topResults = results.length > 5 ? results.sublist(0, 5) : results;
    log('Processing only top ${topResults.length} search results');

    // Process each result and get validation data
    final validationResults = <ValidationResult>[];
    final metadata = {
      'title': title,
      'publisher': publisher,
    };

    for (final result in topResults) {
      try {
        final validationResult =
            await _validator.validate(result.link, metadata);
        if (validationResult.isValid) {
          validationResults.add(validationResult);
        }
      } catch (e) {
        log('Error validating URL ${result.link}: $e');
      }
    }

    if (validationResults.isEmpty) {
      return null;
    }

    // Sort by priority (lower is better) and then by confidence score (higher is better)
    validationResults.sort((a, b) {
      final priorityComparison = a.priority.compareTo(b.priority);
      if (priorityComparison != 0) {
        return priorityComparison;
      }
      return b.confidenceScore.compareTo(a.confidenceScore);
    });

    // Return the URL of the best result
    final bestResult = validationResults.first;
    log('Selected purchase link: ${bestResult.url} (priority: ${bestResult.priority}, score: ${bestResult.confidenceScore})');

    return bestResult.url;
  }

  /// Generates a cache key from metadata
  String _generateCacheKey(Map<String, String> metadata) {
    final title = metadata['title'] ?? '';
    final publisher = metadata['publisher'] ?? '';
    final gameSystem = metadata['gameSystem'] ?? '';

    return '$title|$publisher|$gameSystem';
  }

  /// Disposes resources
  void dispose() {
    _searchClient.dispose();
    _validator.dispose();
  }
}
