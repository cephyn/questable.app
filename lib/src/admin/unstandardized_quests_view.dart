import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quest_cards/src/auth/user_context.dart';
import 'package:quest_cards/src/quest_card/quest_card.dart';
import 'package:quest_cards/src/services/game_system_service.dart';
import 'package:quest_cards/src/models/standard_game_system.dart';
import 'package:collection/collection.dart'; // Import for groupBy
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';

/// Unstandardized Quests View
///
/// Displays quest cards that are missing a standardized game system
/// or have a migration status indicating they need review.
/// Allows admins to standardize game systems directly from this view.
class UnstandardizedQuestsView extends StatefulWidget {
  const UnstandardizedQuestsView({super.key});

  @override
  State<UnstandardizedQuestsView> createState() =>
      _UnstandardizedQuestsViewState();
}

class _UnstandardizedQuestsViewState extends State<UnstandardizedQuestsView> {
  final GameSystemService _gameSystemService = GameSystemService();
  late Future<List<QuestCard>> _unstandardizedQuests;
  List<StandardGameSystem> _standardGameSystems =
      []; // Added state for standard systems
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isLoadingStandardSystems =
      false; // Added loading state for standard systems
  bool _isBatchUpdating = false;
  String _batchUpdateStatus = '';

  @override
  void initState() {
    super.initState();
    _loadQuests();
    _loadStandardGameSystems(); // Load standard systems on init
  }

  void _loadQuests() {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      debugPrint('Loading unstandardized quests...');

      _unstandardizedQuests = _gameSystemService
          .getQuestCardsNeedingReview() // Fetch quests needing review
          .then((quests) {
            debugPrint('Loaded ${quests.length} unstandardized quests');
            return quests;
          })
          .catchError((error) {
            debugPrint('Error loading unstandardized quests: $error');
            if (mounted) {
              // Check if widget is still mounted
              setState(() {
                _errorMessage = 'Failed to load quests: $error';
              });
            }
            return <QuestCard>[]; // Return empty list on error
          })
          .whenComplete(() {
            if (mounted) {
              // Check if widget is still mounted
              setState(() {
                _isLoading = false;
              });
            }
          });
    });
  }

  // Added method to load standard game systems for the alias dialog
  Future<void> _loadStandardGameSystems() async {
    if (!mounted) return; // Check mounted at the beginning
    setState(() {
      _isLoadingStandardSystems = true;
    });
    try {
      _standardGameSystems = await _gameSystemService.getAllGameSystems();
    } catch (e) {
      debugPrint('Error loading standard game systems: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading standard systems: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStandardSystems = false;
        });
      }
    }
  }

  // Placeholder for navigation to edit a quest card
  void _navigateToEditQuest(QuestCard quest) {
    // TODO: Implement navigation to QuestCardDetailView or similar editor
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigate to edit quest: ${quest.title ?? 'N/A'}'),
      ),
    );
    // Example:
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => QuestCardDetailView(questCard: quest),
    //   ),
    // ).then((_) => _loadQuests()); // Reload after editing
  }

  // --- New Methods for Standardization ---

  Future<void> _addAsNewStandardSystem(QuestCard quest) async {
    final gameSystemName = quest.gameSystem?.trim();
    if (gameSystemName == null || gameSystemName.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quest has no game system name.')),
      );
      return;
    }

    // Check if a system with this name already exists (case-insensitive)
    final exists = _standardGameSystems.any(
      (sys) => sys.standardName.toLowerCase() == gameSystemName.toLowerCase(),
    );
    if (exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"$gameSystemName" already exists as a standard game system.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final newSystem = StandardGameSystem(
        standardName: gameSystemName,
        aliases: [],
        editions: [],
        // publisher and description can be added later via edit
      );
      await _gameSystemService.createGameSystem(newSystem);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$gameSystemName" added as a new standard system.'),
        ),
      );
      await _loadStandardGameSystems(); // Refresh standard systems list
      // Optionally: Automatically apply this new standard to the current quest
      // await _gameSystemService.updateQuestStandardizedSystem(quest.id!, newSystem.id!, gameSystemName);
      _loadQuests(); // Refresh the list of unstandardized quests
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding new system: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addAsAlias(QuestCard quest) async {
    final aliasName = quest.gameSystem?.trim();
    if (aliasName == null || aliasName.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quest has no game system name to use as alias.'),
        ),
      );
      return;
    }

    if (_isLoadingStandardSystems) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Standard systems still loading...')),
      );
      return;
    }
    if (_standardGameSystems.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No standard systems found to add alias to.'),
        ),
      );
      // Attempt to reload standard systems if empty
      await _loadStandardGameSystems();
      if (_standardGameSystems.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Still no standard systems found after reload.'),
          ),
        );
        return;
      }
      // If still empty after reload, exit
      if (_standardGameSystems.isEmpty) return;
    }

    // Sort systems alphabetically for the dialog
    final sortedSystems = List<StandardGameSystem>.from(_standardGameSystems)
      ..sort(
        (a, b) => a.standardName.toLowerCase().compareTo(
          b.standardName.toLowerCase(),
        ),
      );

    if (!mounted) return; // Check before showing dialog
    final selectedSystem = await showDialog<StandardGameSystem>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add "$aliasName" as Alias To:'),
          content: SizedBox(
            // Constrain the size of the dialog content
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true, // Make ListView take minimum space
              itemCount: sortedSystems.length,
              itemBuilder: (context, index) {
                final system = sortedSystems[index];
                // Check if alias already exists (case-insensitive)
                final aliasExists =
                    system.aliases.any(
                      (a) => a.toLowerCase() == aliasName.toLowerCase(),
                    ) ||
                    system.standardName.toLowerCase() ==
                        aliasName.toLowerCase();
                return ListTile(
                  title: Text(system.standardName),
                  subtitle: aliasExists
                      ? Text(
                          'Alias already exists here',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                        )
                      : null,
                  onTap: aliasExists
                      ? null
                      : () => Navigator.of(
                          context,
                        ).pop(system), // Disable if alias exists
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );

    if (selectedSystem != null) {
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        // Check again if alias already exists before updating
        final aliasExists =
            selectedSystem.aliases.any(
              (a) => a.toLowerCase() == aliasName.toLowerCase(),
            ) ||
            selectedSystem.standardName.toLowerCase() ==
                aliasName.toLowerCase();
        if (aliasExists) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Alias "$aliasName" already exists for "${selectedSystem.standardName}".',
              ),
            ),
          );
          return; // Exit if alias was added while dialog was open
        }

        // Create a deep copy and add the new alias
        final updatedSystem = selectedSystem.copyWith(
          aliases: [...selectedSystem.aliases, aliasName], // Add new alias
        );

        await _gameSystemService.updateGameSystem(updatedSystem);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added "$aliasName" as alias to "${selectedSystem.standardName}".',
            ),
          ),
        );
        await _loadStandardGameSystems(); // Refresh standard systems list
        // Optionally: Update the current quest to use the standardized system
        // await _gameSystemService.updateQuestStandardizedSystem(quest.id!, selectedSystem.id!, aliasName);
        _loadQuests(); // Refresh the list of unstandardized quests
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error adding alias: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  // --- End New Methods ---

  /// Batch update all quests in a group to a standardized system
  Future<void> _batchUpdateQuestsToSystem(
    List<QuestCard> questsToUpdate,
    String targetSystemName,
  ) async {
    if (questsToUpdate.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No quests to update.')));
      return;
    }

    if (!mounted) return;
    setState(() {
      _isBatchUpdating = true;
      _batchUpdateStatus =
          'Starting batch update (${questsToUpdate.length} quests)...';
    });

    final firestore = FirebaseFirestore.instance;
    const batchSize = 400;
    int batchCounter = 0;
    WriteBatch batch = firestore.batch();
    int updatedCount = 0;

    try {
      for (int i = 0; i < questsToUpdate.length; i++) {
        final quest = questsToUpdate[i];
        if (quest.id == null) {
          log('Quest has no ID, skipping...');
          continue;
        }

        if (!mounted) return;
        setState(() {
          _batchUpdateStatus =
              'Processing ${i + 1}/${questsToUpdate.length} quests...';
        });

        final docRef = firestore.collection('questCards').doc(quest.id);
        batch.update(docRef, {
          'gameSystem': targetSystemName,
          'standardizedGameSystem': targetSystemName,
          'gameSystem_lowercase': targetSystemName.toLowerCase(),
        });
        batchCounter++;
        updatedCount++;

        if (batchCounter >= batchSize) {
          if (!mounted) return;
          setState(() {
            _batchUpdateStatus =
                'Committing batch (${i + 1}/${questsToUpdate.length}, Updated: $updatedCount)...';
          });
          log('Committing batch update...');
          await batch.commit();
          log('Batch committed.');
          batch = firestore.batch();
          batchCounter = 0;
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      // Commit final batch
      if (batchCounter > 0) {
        if (!mounted) return;
        setState(() {
          _batchUpdateStatus = 'Committing final batch...';
        });
        log('Committing final batch ($batchCounter operations)...');
        await batch.commit();
        log('Final batch committed.');
      }

      if (mounted) {
        setState(() {
          _isBatchUpdating = false;
          _batchUpdateStatus = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully updated $updatedCount quests to "$targetSystemName"',
            ),
          ),
        );
        _loadQuests(); // Refresh the list
      }
    } catch (e, s) {
      log('Error during batch update: $e', stackTrace: s);
      if (mounted) {
        setState(() {
          _isBatchUpdating = false;
          _batchUpdateStatus = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during batch update: $e')),
        );
      }
    }
  }

  /// Show dialog to select target standardized system for batch update
  Future<void> _showBatchUpdateDialog(List<QuestCard> questsInGroup) async {
    final String gameSystemName =
        questsInGroup.first.gameSystem?.trim() ?? 'Unknown';

    if (_isLoadingStandardSystems) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Standard systems still loading...')),
      );
      return;
    }

    if (!mounted) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Batch Update $gameSystemName'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quests to update: ${questsInGroup.length}'),
                const SizedBox(height: 16),
                const Text(
                  'Select target standardized system:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _standardGameSystems.length,
                    itemBuilder: (context, index) {
                      final system = _standardGameSystems[index];
                      return ListTile(
                        title: Text(system.standardName),
                        onTap: () => Navigator.of(context).pop({
                          'system': system.standardName,
                          'action': 'select',
                        }),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const Text(
                  'Or create new:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: Text('Create "$gameSystemName" as New Standard'),
                  onTap: () => Navigator.of(
                    context,
                  ).pop({'system': gameSystemName, 'action': 'create'}),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      final targetSystem = result['system'] as String;
      final action = result['action'] as String;

      if (action == 'create') {
        // Create new standard system first
        try {
          final newSystem = StandardGameSystem(
            standardName: targetSystem,
            aliases: [],
            editions: [],
          );
          await _gameSystemService.createGameSystem(newSystem);
          await _loadStandardGameSystems();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error creating system: $e')),
            );
          }
          return;
        }
      }

      // Now do the batch update
      if (mounted) {
        await _batchUpdateQuestsToSystem(questsInGroup, targetSystem);
      }
    }
  }

  // --- End Batch Update Methods ---
  @override
  Widget build(BuildContext context) {
    final userContext = Provider.of<UserContext>(context);

    // Ensure user is admin
    if (!userContext.isAdmin) {
      return const Center(
        child: Text('Access Denied. Admin privileges required.'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unstandardized Quests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading
                ? null
                : () {
                    _loadQuests();
                    _loadStandardGameSystems();
                  },
            tooltip: 'Refresh Lists',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(
              child: Text(
                _errorMessage,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            )
          : FutureBuilder<List<QuestCard>>(
              future: _unstandardizedQuests,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !_isLoading) {
                  // Show loading indicator only if not already handled by _isLoading
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: SelectableText('Error: ${snapshot.error}'),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('No unstandardized quests found.'),
                  );
                }

                final quests = snapshot.data!;
                // Group quests by game system name (case-insensitive, handle null/empty)
                final groupedQuests = groupBy<QuestCard, String>(
                  quests,
                  (quest) =>
                      (quest.gameSystem?.trim().toLowerCase() ??
                              'unknown system')
                          .isEmpty
                      ? 'unknown system'
                      : quest.gameSystem!.trim().toLowerCase(),
                );

                // Sort group keys alphabetically
                final sortedKeys = groupedQuests.keys.toList()
                  ..sort((a, b) => a.compareTo(b));

                return Column(
                  children: [
                    if (_batchUpdateStatus.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isBatchUpdating
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(
                                    context,
                                  ).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_batchUpdateStatus),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: sortedKeys.length,
                        itemBuilder: (context, index) {
                          final gameSystemKey = sortedKeys[index];
                          final questsInGroup = groupedQuests[gameSystemKey]!;
                          final displayGameSystem = questsInGroup
                              .first
                              .gameSystem
                              ?.trim();
                          final displayTitle =
                              (displayGameSystem == null ||
                                  displayGameSystem.isEmpty)
                              ? 'Unknown System'
                              : displayGameSystem;

                          return ExpansionTile(
                            title: Text(
                              '$displayTitle (${questsInGroup.length})',
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (String result) {
                                final representativeQuest = questsInGroup.first;
                                if (result == 'add_new') {
                                  _addAsNewStandardSystem(representativeQuest);
                                } else if (result == 'add_alias') {
                                  _addAsAlias(representativeQuest);
                                } else if (result == 'batch_update') {
                                  _showBatchUpdateDialog(questsInGroup);
                                }
                              },
                              itemBuilder: (BuildContext context) =>
                                  <PopupMenuEntry<String>>[
                                    const PopupMenuItem<String>(
                                      value: 'batch_update',
                                      child: Text('Batch Update to System'),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'add_new',
                                      child: Text('Create New Standard System'),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'add_alias',
                                      enabled:
                                          !_isLoadingStandardSystems &&
                                          _standardGameSystems.isNotEmpty,
                                      child: Text(
                                        _isLoadingStandardSystems
                                            ? 'Loading systems...'
                                            : 'Add as Alias to Existing',
                                      ),
                                    ),
                                  ],
                              icon: const Icon(Icons.more_vert),
                              tooltip: 'Standardize System',
                            ),
                            children: questsInGroup.map((quest) {
                              final title = quest.title ?? 'No Title';
                              final productTitle =
                                  quest.productTitle ?? 'Unknown Product';
                              final status =
                                  quest.systemMigrationStatus ??
                                  'Unknown Status';
                              final gameSystemDisplay =
                                  quest.gameSystem ?? 'No System';

                              return ListTile(
                                title: Text(title),
                                subtitle: Text(
                                  'Product: $productTitle\nSystem: $gameSystemDisplay\nStatus: $status',
                                ),
                                isThreeLine: true,
                                onTap: () => _navigateToEditQuest(quest),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

// --- CopyWith Extension ---
// Ensure this extension is defined correctly, potentially outside the State class if needed elsewhere

extension StandardGameSystemCopyWith on StandardGameSystem {
  StandardGameSystem copyWith({
    String? id,
    String? standardName,
    String? publisher,
    String? description,
    List<String>? aliases,
    List<GameSystemEdition>? editions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StandardGameSystem(
      id: id ?? this.id,
      standardName: standardName ?? this.standardName,
      publisher: publisher ?? this.publisher,
      description: description ?? this.description,
      // Deep copy aliases list
      aliases: aliases ?? List<String>.from(this.aliases),
      // Deep copy editions list using the GameSystemEdition.copyWith
      editions: editions ?? this.editions.map((e) => e.copyWith()).toList(),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
