import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Cached search result
class CachedResult {
  final String url;
  final DateTime timestamp;

  CachedResult(this.url, this.timestamp);

  bool isExpired(Duration cacheDuration) {
    return DateTime.now().difference(timestamp) > cacheDuration;
  }
}

/// A class to cache purchase link search results
class PurchaseLinkCache {
  final Map<String, CachedResult> _cache = {};
  final Duration cacheDuration;

  /// Create a new PurchaseLinkCache
  ///
  /// [cacheDuration] is how long to keep entries in the cache
  PurchaseLinkCache({
    this.cacheDuration = const Duration(hours: 24),
  });

  /// Gets a cached purchase link
  ///
  /// [key] is a unique identifier for the quest card
  /// Returns the cached URL or null if not found or expired
  String? get(String key) {
    final cacheKey = _generateCacheKey(key);
    final cachedResult = _cache[cacheKey];

    if (cachedResult == null) {
      return null;
    }

    // Check if the cached result is expired
    if (cachedResult.isExpired(cacheDuration)) {
      _cache.remove(cacheKey);
      return null;
    }

    return cachedResult.url;
  }

  /// Stores a purchase link in the cache
  ///
  /// [key] is a unique identifier for the quest card
  /// [url] is the purchase link URL
  void set(String key, String url) {
    final cacheKey = _generateCacheKey(key);
    _cache[cacheKey] = CachedResult(url, DateTime.now());
  }

  /// Generates a cache key from the quest card data
  ///
  /// [key] is a string representing the quest card
  /// Returns a consistent hash for the key
  String _generateCacheKey(String key) {
    var bytes = utf8.encode(key);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Clears all expired entries from the cache
  void clearExpired() {
    final keysToRemove = _cache.entries
        .where((entry) => entry.value.isExpired(cacheDuration))
        .map((entry) => entry.key)
        .toList();

    for (final key in keysToRemove) {
      _cache.remove(key);
    }
  }

  /// Clears the entire cache
  void clear() {
    _cache.clear();
  }
}
