import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/firestore_service.dart';
import '../util/utils.dart';
import 'quest_card.dart';
import 'quest_card_edit.dart';

/// Displays detailed information about a SampleItem.
class QuestCardDetailsView extends StatelessWidget {
  const QuestCardDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    Utils.setBrowserTabTitle("Quest Details");
    QuestCard questCard = QuestCard();
    final FirestoreService firestoreService = FirestoreService();

    if (ModalRoute.of(context)?.settings.arguments != null) {
      final Map<String, dynamic> args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      if (args['docId'] != null) {
        return StreamBuilder<DocumentSnapshot>(
            stream: firestoreService.getQuestCardStream(args['docId']),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                Map<String, dynamic> data =
                    snapshot.data!.data() as Map<String, dynamic>;
                questCard = QuestCard.fromJson(data);
              } else {
                return const CircularProgressIndicator();
              }
              return Scaffold(
                appBar: AppBar(
                  title: Text('Quest Card Details'),
                ),
                body: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ListView(
                        children: [
                          Text(
                            'Title: ${Utils.capitalizeTitle(questCard.title)}',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo),
                          ),
                          SizedBox(height: 16),
                          Divider(),
                          _buildInfoRow('Game System', questCard.gameSystem),
                          _buildInfoRow('Edition', questCard.edition),
                          _buildInfoRow('Level', questCard.level),
                          _buildInfoRow(
                              'Page Length', questCard.pageLength!.toString()),
                          _buildInfoRow(
                              'Authors', questCard.authors?.join(', ')),
                          _buildInfoRow('Publisher', questCard.publisher),
                          _buildInfoRow(
                              'Publication Year', questCard.publicationYear),
                          _buildInfoRow('Genre', questCard.genre),
                          _buildInfoRow('Setting', questCard.setting),
                          _buildInfoRow('Environments',
                              questCard.environments?.join(', ')),
                          _buildInfoLinkRow(
                              'Product Link', questCard.title!, questCard.link),
                          _buildInfoRow('Boss Villains',
                              questCard.bossVillains?.join(', ')),
                          _buildInfoRow('Common Monsters',
                              questCard.commonMonsters?.join(', ')),
                          _buildInfoRow('Notable Items',
                              questCard.notableItems?.join(', ')),
                          SizedBox(height: 16),
                          Text(
                            'Summary:',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo),
                          ),
                          SizedBox(height: 8),
                          Text(
                            questCard.summary ?? 'N/A',
                            style:
                                TextStyle(fontSize: 16, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                floatingActionButton: FloatingActionButton(
                  tooltip: 'Edit',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditQuestCard(
                          docId: args['docId'],
                        ),
                      ),
                    );
                  },
                  child: const Icon(Icons.edit),
                ),
              );
            });
      } else {
        return Scaffold(body: Placeholder());
      }
    } else {
      return Scaffold(body: Placeholder());
    }
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value ?? 'N/A',
              //style: TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoLinkRow(String label, String text, String? url) {
    if (url == null || url.isEmpty) {
      return _buildInfoRow(
          label, url); // Return an empty widget if the URL is null or empty
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: Colors.black,
                  height: 1.5, // Better line height for readability
                ),
                children: <TextSpan>[
                  TextSpan(
                    text: text,
                    style: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        _launchURL(url);
                      },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    Uri uri = Uri.parse(url);
    await launchUrl(uri);
  }
}
