import 'package:algolia_helper_flutter/algolia_helper_flutter.dart';
import 'package:quest_cards/src/quest_card/quest_card.dart';

class HitsPage {
  const HitsPage(this.items, this.pageKey, this.nextPageKey, this.totalPages);

  final List<QuestCard> items;
  final int pageKey;
  final int? nextPageKey;
  final int totalPages; // Added totalPages

  factory HitsPage.fromResponse(SearchResponse response) {
    final items = response.hits.map(QuestCard.fromSearchJson).toList();
    // nbPages is 1-based index of total pages
    final totalPages = response.nbPages;
    final isLastPage = response.page >= totalPages - 1; // page is 0-based
    final nextPageKey = isLastPage ? null : response.page + 1;
    return HitsPage(items, response.page, nextPageKey, totalPages);
  }
}
