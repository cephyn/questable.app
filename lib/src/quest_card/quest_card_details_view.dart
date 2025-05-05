import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:quest_cards/src/navigation/root_navigator.dart';
import 'package:quest_cards/src/quest_card/quest_card_edit.dart';
import 'package:quest_cards/src/services/firestore_service.dart';
import 'package:quest_cards/src/util/utils.dart';
import 'package:quest_cards/src/widgets/game_system_mapping_feedback.dart'
    as feedback_widget; // Add alias
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:quest_cards/src/services/firebase_auth_service.dart'; // Import auth service
import 'package:quest_cards/src/auth/auth_dialog_helper.dart'; // Import auth dialog helper
import 'package:share_plus/share_plus.dart'; // Keep for fallback if needed
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:quest_cards/src/config/app_constants.dart';
import 'package:quest_cards/src/widgets/share_options_modal.dart'; // Import the modal

class QuestCardDetailsView extends StatefulWidget {
  final String docId;

  const QuestCardDetailsView({super.key, required this.docId});

  @override
  State<QuestCardDetailsView> createState() => _QuestCardDetailsViewState();
}

class _QuestCardDetailsViewState extends State<QuestCardDetailsView> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuthService _authService =
      FirebaseAuthService(); // Instantiate auth service
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance; // Analytics instance
  Map<String, dynamic>? _questCardData;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  // Separate tap gesture recognizer for each clickable element
  // to avoid memory leaks
  final Map<String, GestureRecognizer> _recognizers = {};

  @override
  void initState() {
    super.initState();
    _loadQuestCardData();
  }

  @override
  void dispose() {
    // Dispose of all gesture recognizers to prevent memory leaks
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    _recognizers.clear();
    super.dispose();
  }

  Future<void> _loadQuestCardData() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final data = await _firestoreService.getQuestCardById(widget.docId);

      if (mounted) {
        setState(() {
          if (data != null) {
            _questCardData = data;
            // Log data to help with debugging
            debugPrint('Loaded quest card data: ${data['title']}');
          } else {
            _hasError = true;
            _errorMessage = 'Quest card not found';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load quest details: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Utils.setBrowserTabTitle(_questCardData?['title'] ?? 'Quest Details');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isLoading
              ? 'Loading Quest...'
              : (_questCardData?['title'] ?? 'Quest Details'),
          style: const TextStyle(fontSize: 20),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Share button
          if (!_isLoading && !_hasError && _questCardData != null)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share Quest',
              onPressed: _shareQuest, // Call the share method
            ),
          // Show edit button if we have quest data
          if (!_isLoading && !_hasError)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Quest',
              onPressed: () {
                // Check if the user is logged in by checking currentUser
                if (_authService.auth.currentUser != null) {
                  // If logged in, navigate directly to edit screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditQuestCard(docId: widget.docId),
                    ),
                  );
                } else {
                  // If not logged in, show login prompt
                  final navigator = RootNavigator.of(context);
                  if (navigator != null) {
                    // Use RootNavigator if available (handles context better)
                    navigator.showLoginPrompt(context, 'edit',
                        docId: widget.docId);
                  } else {
                    // Fallback to AuthDialogHelper
                    AuthDialogHelper.showLoginPrompt(
                        context, 'edit this quest');
                  }
                }
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading quest details...'),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadQuestCardData,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_questCardData == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Quest not found'),
          ],
        ),
      );
    }

    // Display quest details with optimization for large content
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQuestHeader(),
            const Divider(height: 32),
            _buildQuestDescription(),
            const Divider(height: 32),
            _buildQuestProperties(),
            const Divider(height: 32),
            _buildGameSystemFeedback(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestHeader() {
    // Ensure data is not null before accessing
    if (_questCardData == null) return const SizedBox.shrink();

    final String? standardizedSystem =
        _questCardData!['standardizedGameSystem'];
    final String? originalSystem = _questCardData!['gameSystem'];
    final String displaySystemName =
        standardizedSystem ?? originalSystem ?? 'Any System';
    final bool showOriginal = standardizedSystem != null &&
        originalSystem != null &&
        standardizedSystem != originalSystem;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Utils.capitalizeTitle(
                  _questCardData!['title'] ?? 'Untitled Quest'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Game system with icon
            Row(
              children: [
                // Use standardized icon if available, fallback to original
                CircleAvatar(
                  backgroundImage: Utils.getSystemIcon(displaySystemName),
                  radius: 10, // Smaller icon
                  backgroundColor: Colors.transparent,
                ),
                const SizedBox(width: 8),
                // Display Standardized Name prominently
                Text(
                  displaySystemName,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Show original name in parentheses if different and standardized exists
                if (showOriginal)
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0),
                    child: Text(
                      '($originalSystem)', // Removed unnecessary !
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // Level range
            Row(
              children: [
                const Icon(Icons.trending_up, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Level: ${_questCardData!['level'] ?? 'Any Level'}',
                ),
              ],
            ),
            if (_questCardData!['edition'] != null &&
                _questCardData!['edition'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.bookmark, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Edition: ${_questCardData!['edition']}',
                    ),
                  ],
                ),
              ),
            // Page length if available
            if (_questCardData!['pageLength'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.description, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Pages: ${_questCardData!['pageLength']}',
                    ),
                  ],
                ),
              ),
            // Publication info
            if (_questCardData!['publicationYear'] != null &&
                _questCardData!['publicationYear'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Published: ${_questCardData!['publicationYear']}',
                    ),
                  ],
                ),
              ),
            // Last updated timestamp
            if (_questCardData!['timestamp'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.update, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Added: ${Utils.formatTimestamp(_questCardData!['timestamp'])}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestDescription() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            GptMarkdown(
              _questCardData!['summary'] ?? 'No summary available.',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestProperties() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quest Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Authors
            _buildDetailSection(
              'Authors',
              _questCardData!['authors'] ?? [],
              Icons.person,
            ),
            const SizedBox(height: 12),
            // Publisher
            if (_questCardData!['publisher'] != null &&
                _questCardData!['publisher'].toString().isNotEmpty)
              _buildDetailRow(
                'Publisher',
                _questCardData!['publisher'],
                Icons.business,
              ),
            const SizedBox(height: 12),
            // Product title
            if (_questCardData!['productTitle'] != null &&
                _questCardData!['productTitle'].toString().isNotEmpty)
              _buildDetailRow(
                'Product',
                Utils.capitalizeTitle(_questCardData!['productTitle']),
                Icons.book,
              ),
            const SizedBox(height: 12),
            // Setting
            if (_questCardData!['setting'] != null &&
                _questCardData!['setting'].toString().isNotEmpty)
              _buildDetailRow(
                'Setting',
                _questCardData!['setting'],
                Icons.location_city,
              ),
            const SizedBox(height: 12),
            // Environments
            _buildDetailSection(
              'Environments',
              _questCardData!['environments'] ?? [],
              Icons.terrain,
            ),
            const SizedBox(height: 12),
            // Boss/Villains
            _buildDetailSection(
              'Boss Villains',
              _questCardData!['bossVillains'] ?? [],
              Icons.face,
            ),
            const SizedBox(height: 12),
            // Common monsters
            _buildDetailSection(
              'Common Monsters',
              _questCardData!['commonMonsters'] ?? [],
              Icons.pest_control,
            ),
            const SizedBox(height: 12),
            // Notable items
            _buildDetailSection(
              'Notable Items',
              _questCardData!['notableItems'] ?? [],
              Icons.card_giftcard,
            ),
            const SizedBox(height: 12),
            // Link
            if (_questCardData!['link'] != null &&
                _questCardData!['link'].toString().isNotEmpty)
              GestureDetector(
                onTap: () => _launchURL(_questCardData!['link']),
                child: Row(
                  children: [
                    Icon(Icons.link,
                        size: 16, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Link: ${_questCardData!['link']}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            // Classification if available
            if (_questCardData!['classification'] != null &&
                _questCardData!['classification'].toString().isNotEmpty)
              _buildDetailRow(
                'Classification',
                _questCardData!['classification'],
                Icons.category,
              ),
            const SizedBox(height: 12),
            // Genre if available
            if (_questCardData!['genre'] != null &&
                _questCardData!['genre'].toString().isNotEmpty)
              _buildDetailRow(
                'Genre',
                _questCardData!['genre'],
                Icons.theater_comedy,
              ),
          ],
        ),
      ),
    );
  }

  // New method to build the game system feedback section
  Widget _buildGameSystemFeedback() {
    // Only show this section if we have game system data
    if (_questCardData == null || _questCardData!['gameSystem'] == null) {
      return const SizedBox.shrink();
    }

    return feedback_widget.GameSystemFeedbackWidget(
      // Corrected widget name
      // Use alias
      questId: widget.docId,
      originalSystem: _questCardData!['gameSystem'],
      standardizedSystem: _questCardData!['standardizedGameSystem'],
    );
  }

  Widget _buildDetailSection(String title, List<dynamic> items, IconData icon) {
    if (items.isEmpty) {
      return _buildDetailRow(title, 'None', icon);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: items
              .map(
                (item) => Chip(
                  label: Text(item),
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String title, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(value),
            ],
          ),
        ),
      ],
    );
  }

  // Method to handle sharing - now opens the modal
  Future<void> _shareQuest() async {
    if (_questCardData == null) return;

    final String questId = widget.docId;
    final String shareableUrl = '${AppConstants.baseUrl}/#/quests/$questId';
    final String questTitle =
        Utils.capitalizeTitle(_questCardData!['title'] ?? 'Untitled Quest');
    // Text primarily for system share fallback or if needed by modal logic
    final String shareText =
        'Check out this quest on Questable: "$questTitle" - $shareableUrl';

    try {
      // Log analytics event for initiating share - happens before modal shown
      await _analytics.logEvent(
        name: 'share_quest_initiated',
        parameters: {'quest_id': questId},
      );

      // Show the custom modal bottom sheet
      if (mounted) {
        showShareOptionsModal(
          context,
          shareText: shareText, // Pass text for potential fallback
          shareUrl: shareableUrl,
          questId: questId,
          questTitle: questTitle,
          analytics: _analytics,
        );
      }

      // Note: The Share.share() call is removed from here.
      // Platform-specific analytics logging is now handled within the modal.

    } catch (e) {
      // Catch errors related to *initiating* the share (e.g., logging analytics)
      // Errors during actual sharing (copy, launch URL) are handled in the modal
      debugPrint('Error initiating share action: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start sharing process.')),
        );
      }
      // Optionally log initiation error
      await _analytics.logEvent(
        name: 'share_quest_initiation_error',
        parameters: {'quest_id': questId, 'error': e.toString()},
      );
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await url_launcher.canLaunchUrl(uri)) {
      await url_launcher.launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open URL: $url')),
        );
      }
    }
  }
}
