import 'package:flutter/material.dart';
import '../util/utils.dart';

class QuestCardSearch extends StatelessWidget {
  const QuestCardSearch({super.key});

  @override
  Widget build(BuildContext context) {
    Utils.setBrowserTabTitle("Search Quests");
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search QuestCards'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Search Unavailable',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'The search functionality is currently unavailable. Please use the Browse tab to view quests.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
