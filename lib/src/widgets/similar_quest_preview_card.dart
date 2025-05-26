import 'package:flutter/material.dart';

class SimilarQuestPreviewCard extends StatelessWidget {
  final String questId; // Added questId
  final String questName;
  final String questGenre;
  final double similarityScore;
  final VoidCallback? onTap; // Added onTap callback

  const SimilarQuestPreviewCard({
    Key? key,
    required this.questId, // Added questId
    required this.questName,
    required this.questGenre,
    required this.similarityScore,
    this.onTap, // Added onTap callback
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0,
      child: InkWell(
        // Wrapped with InkWell for tap functionality
        onTap: onTap, // Use the onTap callback
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                questName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8.0),
              Text(
                'Genre: $questGenre',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8.0),
              Text(
                'Similarity: ${(similarityScore * 100).toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
