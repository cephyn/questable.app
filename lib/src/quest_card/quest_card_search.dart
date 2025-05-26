import 'package:algolia_helper_flutter/algolia_helper_flutter.dart';
import 'package:flutter/material.dart';
import 'package:quest_cards/src/quest_card/quest_card.dart';
import 'dart:async'; // Import for Timer
import '../search/hits_page.dart';
import '../services/firestore_service.dart';
import '../util/utils.dart';
import '../config/config.dart'; // Import configuration file
import 'package:go_router/go_router.dart'; // Import go_router

class QuestCardSearch extends StatefulWidget {
  const QuestCardSearch({super.key});

  @override
  State<QuestCardSearch> createState() => _QuestCardSearchState();
}

class _QuestCardSearchState extends State<QuestCardSearch> {
  final FirestoreService firestoreService = FirestoreService();

  final _questCardSearcher = HitsSearcher(
      applicationID: Config.algoliaAppId,
      apiKey: Config.algoliaApiKey,
      indexName: Config.algoliaQuestCardsIndex);

  final _filterState = FilterState();
  late final _facetList = _questCardSearcher.buildFacetList(
    filterState: _filterState,
    attribute: 'gameSystem',
  );
  final GlobalKey<ScaffoldState> _mainScaffoldKey = GlobalKey();

  final _searchTextController = TextEditingController();
  Timer? _debounce; // Add debounce timer

  // State for manual pagination
  int _currentPage = 0;
  int _totalPages = 0;
  List<QuestCard> _currentPageItems = [];
  bool _isLoading = false;
  String? _lastQuery;
  String? _errorMessage; // Add error message state variable

  Stream<SearchMetadata> get searchMetadata =>
      _questCardSearcher.responses.map(SearchMetadata.fromResponse);
  Stream<HitsPage> get _searchPage =>
      _questCardSearcher.responses.map(HitsPage.fromResponse);

  @override
  void initState() {
    super.initState();
    _initSearch();
  }

  void _initSearch() {
    _searchTextController.addListener(_onSearchTextChanged);
    _search(_searchTextController.text, 0); // Initial search on page 0
    _searchPage.listen(_onSearchPageUpdated,
        onError: _handleSearchError // Add error handler
        );
  }

  // Handle search errors
  void _handleSearchError(dynamic error) {
    setState(() {
      _isLoading = false;

      // Parse the error message to display a more user-friendly message
      if (error.toString().contains("Index quest_cards does not exist") ||
          error.toString().contains("404")) {
        _errorMessage = "Search index not found. Please contact support.";
      } else if (error.toString().contains("403")) {
        _errorMessage = "Authentication error. Please contact support.";
      } else if (error.toString().contains("Network")) {
        _errorMessage =
            "Network error. Please check your connection and try again.";
      } else {
        _errorMessage = "Search failed: ${error.toString()}";
      }
    });

    // Log the detailed error for debugging
    debugPrint("Algolia search error: $error");
  }

  // Helper method to trigger search
  void _search(String query, int page) {
    setState(() {
      _isLoading = true;
      _lastQuery = query; // Store the last query for pagination
    });
    _questCardSearcher.applyState(
      (state) => state.copyWith(
        query: query,
        page: page,
        hitsPerPage: 20, // Keep hitsPerPage or adjust as needed
      ),
    );
  }

  void _onSearchTextChanged() {
    // Implement debouncing for search
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchTextController.text != _lastQuery) {
        _search(_searchTextController.text, 0);
      }
    });
  }

  void _onSearchPageUpdated(HitsPage page) {
    setState(() {
      _currentPageItems = page.items;
      _currentPage = page.pageKey;
      _totalPages = page.totalPages; // Make sure HitsPage includes totalPages
      _isLoading = false;
      _errorMessage = null; // Clear any error messages on successful search
    });
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      // Use Algolia's native pagination
      _questCardSearcher.applyState(
        (state) => state.copyWith(
          page: _currentPage + 1,
        ),
      );
      setState(() {
        _isLoading = true;
      });
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      // Use Algolia's native pagination
      _questCardSearcher.applyState(
        (state) => state.copyWith(
          page: _currentPage - 1,
        ),
      );
      setState(() {
        _isLoading = true;
      });
    }
  }

  @override
  void dispose() {
    _searchTextController.dispose();
    _questCardSearcher.dispose();
    _filterState.dispose();
    _facetList.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Utils.setBrowserTabTitle("Search Quests");
    return Scaffold(
      key: _mainScaffoldKey,
      appBar: AppBar(
        title: const Text('Search QuestCards'),
        actions: [
          StreamBuilder<List<SelectableItem<Facet>>>(
            stream: _facetList.facets,
            builder: (context, snapshot) {
              // Check if any filters are selected
              final hasActiveFilters = snapshot.hasData &&
                  snapshot.data!.any((facet) => facet.isSelected);

              return Badge(
                isLabelVisible: hasActiveFilters,
                child: IconButton(
                  onPressed: () =>
                      _mainScaffoldKey.currentState?.openEndDrawer(),
                  icon: const Icon(Icons.filter_list_sharp),
                  tooltip: 'Filter search results',
                ),
              );
            },
          )
        ],
      ),
      endDrawer: Drawer(
        child: _filters(context),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _searchTextController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter a search term',
                labelText: 'Search quests',
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                // Combine label and hint for screen readers if needed, or just use the label.
              ),
              // The labelText and hintText provide semantic information.
              // semanticsLabel is not a direct property of TextField.
            ),
            StreamBuilder<SearchMetadata>(
              stream: searchMetadata,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('${snapshot.data!.nbHits} hits'),
                );
              },
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Expanded(
              child: _hits(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hits(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _search(_lastQuery ?? '', _currentPage),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Search'),
            ),
          ],
        ),
      );
    }

    if (_currentPageItems.isEmpty) {
      return const Center(child: Text('No quests found matching your search'));
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              _search(_lastQuery ?? '', _currentPage);
            },
            child: ListView.builder(
              itemCount: _currentPageItems.length,
              itemBuilder: (context, index) {
                final item = _currentPageItems[index];
                final questId = item.objectId ?? item.id; // Get the quest ID
                return Card(
                  margin:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  elevation: 4,
                  child: InkWell(
                    onTap: () {
                      if (questId != null) {
                        // Use go_router to navigate
                        context.push('/quests/$questId');
                      } else {
                        // Handle cases where questId might be null, perhaps show a snackbar
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Error: Quest ID is missing.')),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Utils.capitalizeTitle(item.title ?? 'No Title'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Game System: ${item.gameSystem ?? 'N/A'}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              if (item.level != null)
                                Text(
                                  'Level: ${item.level}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // Pagination Controls
        if (_totalPages > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _currentPage == 0 ? null : _previousPage,
                  child: const Text('Back'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('Page ${_currentPage + 1} of $_totalPages'),
                ),
                ElevatedButton(
                  onPressed: _currentPage >= _totalPages - 1 ? null : _nextPage,
                  child: const Text('Next'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _filters(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Filters'),
        ),
        body: StreamBuilder<List<SelectableItem<Facet>>>(
          stream: _facetList.facets,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox.shrink();
            }
            final selectableFacets = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: selectableFacets.length,
              itemBuilder: (_, index) {
                final selectableFacet = selectableFacets[index];
                return CheckboxListTile(
                  value: selectableFacet.isSelected,
                  title: Text(
                    "${selectableFacet.item.value} (${selectableFacet.item.count})",
                    style: TextStyle(color: Colors.black87),
                  ),
                  onChanged: (_) {
                    _facetList.toggle(selectableFacet.item.value);
                  },
                );
              },
            );
          },
        ),
      );
}

class SearchMetadata {
  final int nbHits;

  const SearchMetadata(this.nbHits);

  factory SearchMetadata.fromResponse(SearchResponse response) =>
      SearchMetadata(response.nbHits);
}
