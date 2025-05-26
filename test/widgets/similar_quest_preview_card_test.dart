import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quest_cards/src/widgets/similar_quest_preview_card.dart';

void main() {
  group('SimilarQuestPreviewCard', () {
    testWidgets('displays quest information correctly',
        (WidgetTester tester) async {
      // Define mock data
      const String questId = 'testQuestId123'; // Added questId
      const String questName = 'The Lost Tomb of Ankhtep';
      const String questGenre = 'Dungeon Crawl';
      const double similarityScore = 0.855; // 85.5%

      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          // MaterialApp is needed for Theme.of(context)
          home: Scaffold(
            body: SimilarQuestPreviewCard(
              questId: questId, // Pass questId
              questName: questName,
              questGenre: questGenre,
              similarityScore: similarityScore,
            ),
          ),
        ),
      );

      // Verify that the quest name is displayed
      expect(find.text(questName), findsOneWidget);

      // Verify that the quest genre is displayed
      final expectedGenreText = 'Genre: $questGenre';
      expect(find.text(expectedGenreText), findsOneWidget);

      // Verify that the similarity score is displayed and formatted correctly
      // Calculate the expected string manually to avoid issues with interpolation in the expect() call
      final String scoreString = (similarityScore * 100).toStringAsFixed(1);
      final String expectedSimilarityText = 'Similarity: $scoreString%';
      expect(find.text(expectedSimilarityText), findsOneWidget);

      // Verify Card properties (e.g., elevation)
      final cardFinder = find.byType(Card);
      expect(cardFinder, findsOneWidget);
      final cardWidget = tester.widget<Card>(cardFinder);
      expect(cardWidget.elevation, 2.0);
    });
  });
}
