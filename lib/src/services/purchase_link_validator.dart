import 'dart:developer';
import 'package:http/http.dart' as http;
import '../config/config.dart';

/// Priority levels for domains
class DomainPriority {
  static const int publisher = 1;
  static const int marketplace = 2;
  static const int retailer = 3;
  static const int unknown = 4;
}

/// Validation result for a purchase link
class ValidationResult {
  final String url;
  final int priority;
  final bool isValid;
  final int confidenceScore;

  ValidationResult({
    required this.url,
    required this.priority,
    required this.isValid,
    required this.confidenceScore,
  });

  @override
  String toString() => 'ValidationResult('
      'url: $url, '
      'priority: $priority, '
      'isValid: $isValid, '
      'confidenceScore: $confidenceScore)';
}

/// A class to validate and prioritize purchase links
class PurchaseLinkValidator {
  final List<String> publisherDomains;
  final List<String> marketplaceDomains;
  final List<String> retailerDomains;
  final http.Client _httpClient;

  /// Create a new PurchaseLinkValidator
  ///
  /// [publisherDomains] is a list of publisher domains
  /// [marketplaceDomains] is a list of marketplace domains
  /// [retailerDomains] is a list of general retailer domains
  PurchaseLinkValidator({
    required this.publisherDomains,
    required this.marketplaceDomains,
    this.retailerDomains = const ['amazon.com', 'barnesandnoble.com'],
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Validates a URL as a purchase link
  ///
  /// [url] is the URL to validate
  /// [metadata] contains the quest card metadata for context
  /// Returns a ValidationResult
  Future<ValidationResult> validate(
      String url, Map<String, String> metadata) async {
    try {
      log('Validating URL: $url');

      // Check if the URL uses HTTP/HTTPS protocol
      final urlLower = url.toLowerCase();
      if (!urlLower.startsWith('http://') && !urlLower.startsWith('https://')) {
        log('URL rejected: Not an HTTP/HTTPS link: $url');
        return ValidationResult(
          url: url,
          priority: DomainPriority.unknown,
          isValid: false,
          confidenceScore: 0,
        );
      }

      // Get domain priority
      int priority = getDomainPriority(url);
      log('Domain priority: $priority');

      // Check URL structure
      int structureScore = getUrlStructureScore(url);
      log('URL structure score: $structureScore');

      // Verify URL accessibility (with timeout)
      bool isAccessible = await isUrlAccessible(url);
      log('URL accessible: $isAccessible');

      // Check if URL matches title and publisher
      bool titleMatches = checkUrlMatchesTitle(url, metadata);
      bool publisherMatches = checkUrlMatchesPublisher(url, metadata);
      log('URL matches title: $titleMatches');
      log('URL matches publisher: $publisherMatches');

      // Calculate confidence score (0-100)
      int confidenceScore = calculateDetailedConfidenceScore(
          priority: priority,
          structureScore: structureScore,
          isAccessible: isAccessible,
          titleMatches: titleMatches,
          publisherMatches: publisherMatches);
      log('Final confidence score: $confidenceScore');

      // Modified validation logic: URL is valid if confidence score is high enough,
      // even if the accessibility check fails when other indicators are strong
      bool isValid =
          (isAccessible || (confidenceScore >= 60)) && confidenceScore > 30;
      log('URL validation result: ${isValid ? 'Valid' : 'Invalid'} (score: $confidenceScore)');

      return ValidationResult(
        url: url,
        priority: priority,
        isValid: isValid,
        confidenceScore: confidenceScore,
      );
    } catch (e) {
      log('Error validating URL $url: $e');
      return ValidationResult(
        url: url,
        priority: DomainPriority.unknown,
        isValid: false,
        confidenceScore: 0,
      );
    }
  }

  /// Returns the priority of a domain
  ///
  /// [url] is the URL to check
  /// Returns a priority value (lower is better)
  int getDomainPriority(String url) {
    try {
      final uri = Uri.parse(url);
      final domain = uri.host.toLowerCase();

      // Check for publisher domains
      for (final publisherDomain in publisherDomains) {
        if (domain == publisherDomain || domain.endsWith('.$publisherDomain')) {
          return DomainPriority.publisher;
        }
      }

      // Check for marketplace domains
      for (final marketplaceDomain in marketplaceDomains) {
        if (domain == marketplaceDomain ||
            domain.endsWith('.$marketplaceDomain')) {
          return DomainPriority.marketplace;
        }
      }

      // Check for retailer domains
      for (final retailerDomain in retailerDomains) {
        if (domain == retailerDomain || domain.endsWith('.$retailerDomain')) {
          return DomainPriority.retailer;
        }
      }

      // Unknown domain
      return DomainPriority.unknown;
    } catch (_) {
      return DomainPriority.unknown;
    }
  }

  /// Returns a score for the URL's structure
  ///
  /// [url] is the URL to check
  /// Returns a score (higher is better)
  int getUrlStructureScore(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path.toLowerCase();
      int score = 0;

      // Good path patterns
      if (path.contains('/product/')) score += 20;
      if (path.contains('/item/')) score += 20;
      if (path.contains('/store/')) score += 15;
      if (path.contains('/shop/')) score += 15;
      if (path.contains('/buy/')) score += 15;

      // Bad path patterns
      if (path.contains('/search')) score -= 15;
      if (path.contains('/category/')) score -= 10;
      if (path.contains('/tag/')) score -= 10;
      if (path.contains('/list/')) score -= 10;
      if (path.isEmpty || path == '/') score -= 20;

      // Query parameters
      if (uri.queryParameters.containsKey('search')) score -= 10;
      if (uri.queryParameters.containsKey('q')) score -= 10;
      if (uri.queryParameters.containsKey('s')) score -= 5;

      // Path length - too short paths are usually not product pages
      if (path.length > 5) score += 5;
      if (path.length > 10) score += 5;

      return score;
    } catch (_) {
      return 0;
    }
  }

  /// Checks if a URL is accessible
  ///
  /// [url] is the URL to check
  /// Returns true if the URL is accessible
  Future<bool> isUrlAccessible(String url) async {
    try {
      // Parse the URL
      final uri = Uri.parse(url);

      // Add a user agent to avoid being blocked
      final headers = {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      };

      // Try a HEAD request first (faster, less bandwidth)
      try {
        final response = await _httpClient
            .head(uri, headers: headers)
            .timeout(const Duration(seconds: 5));

        log('URL accessibility HEAD check: ${response.statusCode}');

        // If we get a successful response, we're good
        if (response.statusCode >= 200 && response.statusCode < 400) {
          return true;
        }
      } catch (_) {
        // HEAD request failed, we'll try GET next
        log('HEAD request failed for $url, trying GET');
      }

      // If HEAD failed or returned an error, try a GET request
      // Some servers don't properly support HEAD requests
      final response = await _httpClient
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 5));

      log('URL accessibility GET check: ${response.statusCode}');
      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (e) {
      log('URL accessibility check failed: $e');
      return false;
    }
  }

  /// Checks if a URL likely matches the product title
  ///
  /// [url] is the URL to check
  /// [metadata] contains the quest card metadata
  /// Returns true if the URL likely matches the title
  bool checkUrlMatchesTitle(String url, Map<String, String> metadata) {
    try {
      final urlLower = url.toLowerCase();

      // Check both productTitle and title fields (one might be empty)
      final title = metadata['productTitle']?.toLowerCase() ??
          metadata['title']?.toLowerCase() ??
          '';

      log('DEBUG: checkUrlMatchesTitle');
      log('DEBUG: URL: $urlLower');
      log('DEBUG: Title: $title');

      if (title.isEmpty) {
        log('DEBUG: Title is empty');
        return false;
      }

      // Check if title is in the URL
      // Split into words and check if major words appear in URL
      final titleWords = title
          .split(' ')
          .where((word) => word.length > 3) // Skip short words
          .toList();

      log('DEBUG: Title words to match: $titleWords');

      if (titleWords.isEmpty) {
        log('DEBUG: No significant title words found (all words are too short)');
        return false;
      }

      int matchCount = 0;
      log('DEBUG: Checking title words in URL:');
      for (final word in titleWords) {
        final wordInUrl = urlLower.contains(word);
        log('DEBUG:   "$word" in URL: ${wordInUrl ? "YES" : "NO"}');
        if (wordInUrl) {
          matchCount++;
        }
      }

      // Calculate threshold for matching
      final threshold = titleWords.length / 2;
      log('DEBUG: Match count: $matchCount out of ${titleWords.length}');
      log('DEBUG: Threshold: $threshold');

      // If more than half of the significant title words are in the URL,
      // it's likely a match
      final isMatch = matchCount >= threshold;
      log('DEBUG: Title words match is ${isMatch ? "ABOVE" : "BELOW"} threshold');
      return isMatch;
    } catch (e) {
      log('DEBUG: Error in checkUrlMatchesTitle: $e');
      return false;
    }
  }

  /// Checks if a URL likely matches the publisher
  ///
  /// [url] is the URL to check
  /// [metadata] contains the quest card metadata
  /// Returns true if the URL likely matches the publisher
  bool checkUrlMatchesPublisher(String url, Map<String, String> metadata) {
    try {
      final urlLower = url.toLowerCase();
      final publisher = metadata['publisher']?.toLowerCase() ?? '';

      log('DEBUG: checkUrlMatchesPublisher');
      log('DEBUG: URL: $urlLower');
      log('DEBUG: Publisher: $publisher');

      if (publisher.isEmpty) {
        log('DEBUG: Publisher is empty');
        return false;
      }

      // First try direct string match
      final publisherInUrl = urlLower.contains(publisher);
      log('DEBUG: Publisher "$publisher" in URL (direct match): ${publisherInUrl ? "YES" : "NO"}');

      if (publisherInUrl) {
        log('DEBUG: Publisher match is TRUE (direct)');
        return true;
      }

      // If direct match failed, normalize publisher by removing spaces and try again
      final normalizedPublisher =
          publisher.replaceAll(' ', '').replaceAll('-', '');
      final normalizedUrl = urlLower.replaceAll('-', '');
      final normalizedMatch = normalizedUrl.contains(normalizedPublisher);

      log('DEBUG: Normalized publisher: "$normalizedPublisher"');
      log('DEBUG: Normalized URL: "$normalizedUrl"');
      log('DEBUG: Publisher in URL (normalized): ${normalizedMatch ? "YES" : "NO"}');

      if (normalizedMatch) {
        log('DEBUG: Publisher match is TRUE (normalized)');
        return true;
      }

      // Try matching parts of multi-word publishers
      if (publisher.contains(' ')) {
        final publisherWords = publisher
            .split(' ')
            .where((word) => word.length > 3) // Skip short words
            .toList();

        log('DEBUG: Publisher words to match: $publisherWords');

        if (publisherWords.isNotEmpty) {
          int matchCount = 0;
          for (final word in publisherWords) {
            if (urlLower.contains(word)) {
              log('DEBUG: Publisher word "$word" found in URL');
              matchCount++;
            }
          }

          // If we match at least half of the publisher words, it's likely a match
          final wordThreshold = publisherWords.length / 2;
          log('DEBUG: Publisher word match count: $matchCount out of ${publisherWords.length}');
          log('DEBUG: Publisher word threshold: $wordThreshold');

          if (matchCount >= wordThreshold) {
            log('DEBUG: Publisher words match is ABOVE threshold');
            return true;
          }
        }
      }

      log('DEBUG: No publisher match found');
      return false;
    } catch (e) {
      log('DEBUG: Error in checkUrlMatchesPublisher: $e');
      return false;
    }
  }

  /// Legacy method that calls both title and publisher matching
  ///
  /// [url] is the URL to check
  /// [metadata] contains the quest card metadata
  /// Returns true if either the title or publisher likely matches
  @Deprecated(
      'Use checkUrlMatchesTitle and checkUrlMatchesPublisher separately')
  bool checkUrlLikelyMatches(String url, Map<String, String> metadata) {
    final titleMatches = checkUrlMatchesTitle(url, metadata);
    final publisherMatches = checkUrlMatchesPublisher(url, metadata);
    return titleMatches || publisherMatches;
  }

  /// Calculates a confidence score for a purchase link
  ///
  /// [priority] is the domain priority
  /// [structureScore] is the URL structure score
  /// [isAccessible] is whether the URL is accessible
  /// [likelyMatches] is whether the URL likely matches the product
  /// Returns a confidence score (0-100)
  int calculateConfidenceScore({
    required int priority,
    required int structureScore,
    required bool isAccessible,
    required bool likelyMatches,
  }) {
    // Legacy method using combined likelyMatches
    // Use the new calculateDetailedConfidenceScore instead
    return calculateDetailedConfidenceScore(
        priority: priority,
        structureScore: structureScore,
        isAccessible: isAccessible,
        titleMatches: likelyMatches,
        publisherMatches: likelyMatches);
  }

  /// Calculates a detailed confidence score for a purchase link
  ///
  /// [priority] is the domain priority
  /// [structureScore] is the URL structure score
  /// [isAccessible] is whether the URL is accessible
  /// [titleMatches] is whether the URL matches the title
  /// [publisherMatches] is whether the URL matches the publisher
  /// Returns a confidence score (0-100)
  int calculateDetailedConfidenceScore({
    required int priority,
    required int structureScore,
    required bool isAccessible,
    required bool titleMatches,
    required bool publisherMatches,
  }) {
    int score = 0;

    // Domain priority (0-30 points)
    switch (priority) {
      case DomainPriority.publisher:
        score += 30;
        break;
      case DomainPriority.marketplace:
        score += 25;
        break;
      case DomainPriority.retailer:
        score += 20;
        break;
      case DomainPriority.unknown:
        score += 10;
        break;
    }

    // URL structure (0-20 points)
    // Normalize structureScore to 0-20 range
    score += (structureScore.clamp(-20, 40) + 20) * 20 ~/ 60;

    // Accessibility (0 points)
    if (isAccessible) score += 0;

    // Title matches (0-25 points)
    if (titleMatches) score += 25;

    // Publisher matches (0-25 points)
    if (publisherMatches) score += 25;

    return score.clamp(0, 100);
  }

  /// Disposes of resources
  void dispose() {
    _httpClient.close();
  }
}
