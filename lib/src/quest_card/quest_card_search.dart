import 'package:algolia_helper_flutter/algolia_helper_flutter.dart';
import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:quest_cards/src/quest_card/quest_card.dart';
import '../search/hits_page.dart';
import '../services/firestore_service.dart';
import '../util/utils.dart';
import 'quest_card_details_view.dart';

class QuestCardSearch extends StatefulWidget {
  const QuestCardSearch({super.key});

  @override
  State<QuestCardSearch> createState() => _QuestCardSearchState();
}

class _QuestCardSearchState extends State<QuestCardSearch> {
  final FirestoreService firestoreService = FirestoreService();
  final _questCardSearcher = HitsSearcher(
      applicationID: 'XDZDKQL54G',
      apiKey: 'd2137698a7e4631b3e06c2e839a72bac',
      indexName: 'questCards');
  final _filterState = FilterState();
  late final _facetList = _questCardSearcher.buildFacetList(
    filterState: _filterState,
    attribute: 'gameSystem',
  );
  final GlobalKey<ScaffoldState> _mainScaffoldKey = GlobalKey();

  final _searchTextController = TextEditingController();

  final PagingController<int, QuestCard> _pagingController =
      PagingController(firstPageKey: 0);

  Stream<SearchMetadata> get searchMetadata =>
      _questCardSearcher.responses.map(SearchMetadata.fromResponse);
  Stream<HitsPage> get _searchPage =>
      _questCardSearcher.responses.map(HitsPage.fromResponse);

  @override
  void initState() {
    super.initState();
    _searchTextController.addListener(
      () => _questCardSearcher.applyState(
        (state) => state.copyWith(
          query: _searchTextController.text,
          page: 0,
        ),
      ),
    );
    _searchPage.listen((page) {
      if (page.pageKey == 0) {
        _pagingController.refresh();
      }
      _pagingController.appendPage(page.items, page.nextPageKey);
    }).onError((error) => _pagingController.error = error);
    _pagingController.addPageRequestListener(
        (pageKey) => _questCardSearcher.applyState((state) => state.copyWith(
              page: pageKey,
            )));

    _questCardSearcher.connectFilterState(_filterState);
    _filterState.filters.listen((_) => _pagingController.refresh());
  }

  @override
  void dispose() {
    _searchTextController.dispose();
    _questCardSearcher.dispose();
    _pagingController.dispose();
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
          IconButton(
              onPressed: () => _mainScaffoldKey.currentState?.openEndDrawer(),
              icon: const Icon(Icons.filter_list_sharp))
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
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter a search term',
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
              ),
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
            Expanded(
              child: _hits(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hits(BuildContext context) => PagedListView<int, QuestCard>(
        pagingController: _pagingController,
        builderDelegate: PagedChildBuilderDelegate<QuestCard>(
          noItemsFoundIndicatorBuilder: (_) => const Center(
            child: Text('No results found'),
          ),
          itemBuilder: (_, item, __) => Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: ListTile(
              leading: Icon(Icons.book, color: Colors.indigo),
              title: Text(
                item.title!,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QuestCardDetailsView(),
                    settings:
                        RouteSettings(arguments: {'docId': item.objectId}),
                  ),
                );
              },
            ),
          ),
        ),
      );

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
