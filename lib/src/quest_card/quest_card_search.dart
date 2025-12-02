import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../util/utils.dart';

class QuestCardSearch extends StatefulWidget {
  const QuestCardSearch({super.key});

  @override
  State<QuestCardSearch> createState() => _QuestCardSearchState();
}

class _QuestCardSearchState extends State<QuestCardSearch> {
  final TextEditingController _controller = TextEditingController();

  static const int _pageSize = 10;

  String _currentQuery = '';
  bool _isSearching = false;
  Timer? _debounce;

  // Simple paging state
  int _currentPage = 1;
  int _total = 0;
  final List<Map<String, dynamic>> _hits = [];

  // Suggestions
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    Utils.setBrowserTabTitle('Search Quests');

    // no special listeners; use explicit _fetchPage
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchPage(int pageKey) async {
    if (_currentQuery.isEmpty) {
      setState(() {
        _hits.clear();
        _total = 0;
        _currentPage = 1;
      });
      return;
    }

    try {
      setState(() => _isSearching = true);

      final callable = FirebaseFunctions.instance.httpsCallable('search_quests');
      final resp = await callable.call({
        'query': _currentQuery,
        'page': pageKey,
        'pageSize': _pageSize,
      });

      final data = Map<String, dynamic>.from(resp.data ?? {});
      final total = data['total'] as int? ?? 0;
      final hits = (data['hits'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [];

      if (pageKey == 1) {
        _hits.clear();
      }
      _hits.addAll(hits);
      setState(() {
        _total = total;
        _currentPage = pageKey;
      });
    } catch (e, st) {
      debugPrint('Search fetch error: $e\n$st');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<List<String>> _suggestionsFor(String pattern) async {
    if (pattern.trim().isEmpty) return [];
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('search_quests');
      final resp = await callable.call({'query': pattern, 'page': 1, 'pageSize': 5});
      final data = Map<String, dynamic>.from(resp.data);
      final hits = (data['hits'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [];
      return hits.map((h) => h['title']?.toString() ?? '').toList();
    } catch (e) {
      debugPrint('Suggestion fetch error: $e');
      return [];
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _currentQuery = value.trim();
        _currentPage = 1;
        _fetchPage(1);
      });
    });
  }

  Widget _buildResultTile(Map<String, dynamic> hit) {
    final title = hit['title'] ?? 'Untitled';
    final snippet = hit['snippet'] ?? '';
    final score = hit['score'] ?? 0;

    return ListTile(
      title: Text(title),
      subtitle: snippet.isNotEmpty ? Text(snippet) : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 18, color: Colors.grey[600]),
          const SizedBox(height: 2),
          Text(score.toStringAsFixed(2), style: TextStyle(fontSize: 12)),
        ],
      ),
      onTap: () {
        // Navigate to quest details
        final id = hit['id'];
        if (id != null) {
            try {
              context.go('/quests/$id');
            } catch (_) {
              // ignore if go is not available
            }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search QuestCards'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Use a simple TextField and suggestions below for compatibility
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                  labelText: 'Search quests',
                  border: const OutlineInputBorder(),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            _onQueryChanged('');
                          },
                        ),
                ),
                onChanged: (v) {
                  _onQueryChanged(v);
                  // also fetch inline suggestions
                  _suggestionsFor(v).then((s) => setState(() => _suggestions = s));
                },
                onSubmitted: (v) {
                  _currentQuery = v.trim();
                  _currentPage = 1;
                  _fetchPage(1);
                },
              ),
            // suggestions list
            if (_suggestions.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (context, idx) {
                    final s = _suggestions[idx];
                    return ListTile(
                      title: Text(s),
                      onTap: () {
                        _controller.text = s;
                        _onQueryChanged(s);
                        _suggestions = [];
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: _isSearching && _hits.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _hits.isEmpty
                      ? const Center(child: Text('No results'))
                      : ListView.builder(
                          itemCount: _hits.length + 1,
                          itemBuilder: (context, idx) {
                            if (idx < _hits.length) {
                              final item = _hits[idx];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
                                child: _buildResultTile(item),
                              );
                            }

                            // Load more row
                            final hasMore = _hits.length < _total;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Center(
                                child: hasMore
                                    ? ElevatedButton(
                                        onPressed: _isSearching
                                            ? null
                                            : () {
                                                _fetchPage(_currentPage + 1);
                                              },
                                        child: const Text('Load more'))
                                    : const Text('End of results'),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
