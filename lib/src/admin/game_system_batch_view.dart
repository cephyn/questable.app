import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quest_cards/src/auth/user_context.dart';
import 'package:quest_cards/src/models/standard_game_system.dart';
import 'package:quest_cards/src/services/game_system_migration_service.dart';

/// Game System Batch Operations View
///
/// Allows administrators to perform batch standardization operations
/// on multiple quest cards at once
class GameSystemBatchView extends StatefulWidget {
  final StandardGameSystem gameSystem;

  const GameSystemBatchView({
    super.key,
    required this.gameSystem,
  });

  @override
  State<GameSystemBatchView> createState() => _GameSystemBatchViewState();
}

class _GameSystemBatchViewState extends State<GameSystemBatchView> {
  final GameSystemMigrationService _migrationService =
      GameSystemMigrationService();

  List<DocumentSnapshot> _affectedQuests = [];
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isMigrating = false;
  int _processedCount = 0;
  int _totalCount = 0;
  List<String> _matchedGameSystems = [];

  @override
  void initState() {
    super.initState();
    _loadAffectedQuests();
  }

  Future<void> _loadAffectedQuests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // First get quest cards that exactly match this game system
      final exact = await _migrationService.getQuestCardsByGameSystem(
        widget.gameSystem.standardName,
        limit: 1000,
      );

      // Then get cards that match aliases
      final aliases = widget.gameSystem.aliases;
      final aliasQuests = <DocumentSnapshot>[];
      final matchedSystems = <String>{widget.gameSystem.standardName};

      for (final alias in aliases) {
        final quests = await _migrationService.getQuestCardsByGameSystem(
          alias,
          limit: 1000,
        );
        aliasQuests.addAll(quests);
        if (quests.isNotEmpty) {
          matchedSystems.add(alias);
        }
      }

      // Combine results, ensuring no duplicates (by ID)
      final allQuests = <String, DocumentSnapshot>{};
      for (final quest in [...exact, ...aliasQuests]) {
        allQuests[quest.id] = quest;
      }

      setState(() {
        _affectedQuests = allQuests.values.toList();
        _totalCount = _affectedQuests.length;
        _matchedGameSystems = matchedSystems.toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading affected quests: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _applyStandardization() async {
    if (_affectedQuests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No quests to update')),
      );
      return;
    }

    setState(() {
      _isMigrating = true;
      _processedCount = 0;
    });

    try {
      final count = await _migrationService.applyStandardToQuests(
        widget.gameSystem,
        _affectedQuests,
      );

      setState(() {
        _processedCount = count;
        _isMigrating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully updated $count quests')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error applying standardization: $e';
        _isMigrating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $_errorMessage')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userContext = Provider.of<UserContext>(context);

    // Only accessible to admins
    if (!userContext.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
        ),
        body: const Center(
          child: Text('You must be an admin to access this page.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Batch Standardization: ${widget.gameSystem.standardName}'),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Error:',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_errorMessage, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAffectedQuests,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_affectedQuests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 48),
            const SizedBox(height: 16),
            Text(
              'No quest cards found for "${widget.gameSystem.standardName}" or its aliases',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadAffectedQuests,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Standard System: ${widget.gameSystem.standardName}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Aliases: ${widget.gameSystem.aliases.join(", ")}'),
              const SizedBox(height: 16),
              Text(
                'Found ${_affectedQuests.length} quest cards with these game systems:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _matchedGameSystems.map((system) {
                  return Chip(label: Text(system));
                }).toList(),
              ),
              const SizedBox(height: 8),
              const Divider(),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _affectedQuests.length,
            itemBuilder: (context, index) {
              final quest = _affectedQuests[index];
              final data = quest.data() as Map<String, dynamic>;
              final title = data['title'] ?? 'Untitled Quest';
              final gameSystem = data['gameSystem'] ?? 'Unknown System';
              final author = data['authors'] ?? 'Unknown Author';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  title: Text(title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Current System: $gameSystem'),
                      Text('Authors: $author'),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    if (_isMigrating) {
      return BottomAppBar(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Standardizing quest cards...',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('Please wait while the batch operation completes'),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_processedCount > 0) {
      return BottomAppBar(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Standardization Complete',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('Successfully updated $_processedCount quest cards'),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }

    return BottomAppBar(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text('${_affectedQuests.length} quest cards will be standardized'),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _applyStandardization,
            icon: const Icon(Icons.sync),
            label: const Text('Apply Standardization'),
          ),
        ],
      ),
    );
  }
}
