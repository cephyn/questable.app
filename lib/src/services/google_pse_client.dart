import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import '../config/config.dart';

/// A class to handle communication with Google Programmable Search Engine
class GooglePSEClient {
  final String apiKey;
  final String searchEngineId;
  final http.Client _httpClient;

  /// Create a new GooglePSEClient
  ///
  /// [apiKey] is the Google API key
  /// [searchEngineId] is the Custom Search Engine ID
  GooglePSEClient({
    required this.apiKey,
    required this.searchEngineId,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Performs a search using Google PSE
  ///
  /// [query] is the search query string
  /// Returns a list of search results
  Future<List<SearchResult>> search(String query) async {
    try {
      final encodedQuery = Uri.encodeQueryComponent(query);
      final url = Uri.parse(
          'https://www.googleapis.com/customsearch/v1?key=$apiKey&cx=$searchEngineId&q=$encodedQuery');

      log('Searching for: $query');
      //log('Request URL: $url');
      final response = await _httpClient.get(url);

      if (response.statusCode != 200) {
        log('Error response: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to search: ${response.statusCode}');
      }

      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

      // Check if there are search results
      if (!jsonResponse.containsKey('items') || jsonResponse['items'] == null) {
        log('No search results found');
        return [];
      }

      final items = jsonResponse['items'] as List<dynamic>;
      return items.map((item) => SearchResult.fromJson(item)).toList();
    } catch (e) {
      log('Error during search: $e');
      // Implement retry logic here in the future
      rethrow;
    }
  }

  /// Creates a search query from a QuestCard's metadata
  ///
  /// [metadata] contains the quest card metadata
  /// Returns a formatted search query
  String generateQuery(Map<String, String> metadata) {
    final components = <String>[];

    // Add title in quotes if available
    if (metadata['title'] != null && metadata['title']!.isNotEmpty) {
      components.add('"${metadata['title']}"');
    }

    // Add publisher in quotes if available
    if (metadata['publisher'] != null && metadata['publisher']!.isNotEmpty) {
      components.add('"${metadata['publisher']}"');
    }

    // Add game system if available
    if (metadata['gameSystem'] != null && metadata['gameSystem']!.isNotEmpty) {
      components.add(metadata['gameSystem']!);
    }

    // Add purchase keywords
    components.add('buy OR purchase OR "official site"');

    // Add RPG keyword if not already in title or game system
    final titleLower = metadata['title']?.toLowerCase() ?? '';
    final systemLower = metadata['gameSystem']?.toLowerCase() ?? '';
    if (!titleLower.contains('rpg') && !systemLower.contains('rpg')) {
      components.add('rpg');
    }

    return components.join(' ');
  }

  /// Closes the HTTP client
  void dispose() {
    _httpClient.close();
  }
}

/// Represents a search result from Google PSE
class SearchResult {
  final String title;
  final String link;
  final String snippet;
  final String? displayLink;
  final Map<String, dynamic> raw;

  SearchResult({
    required this.title,
    required this.link,
    required this.snippet,
    this.displayLink,
    required this.raw,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      title: json['title'] ?? '',
      link: json['link'] ?? '',
      snippet: json['snippet'] ?? '',
      displayLink: json['displayLink'],
      raw: json,
    );
  }

  @override
  String toString() => 'SearchResult(title: $title, link: $link)';
}
