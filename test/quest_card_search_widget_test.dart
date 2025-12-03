import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quest_cards/src/quest_card/quest_card_search.dart';

void main() {
  testWidgets('QuestCardSearch shows search field and list', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: QuestCardSearch()));

    // Should contain a TextField
    expect(find.byType(TextField), findsOneWidget);

    // Should contain a ListView (PagedListView builds a list)
    expect(find.byType(Scrollable), findsWidgets);
  });
}
