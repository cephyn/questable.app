import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quest_cards/src/auth/user_context.dart';
import 'package:quest_cards/src/quest_card/quest_card.dart';
import 'package:quest_cards/src/services/game_system_service.dart';
import 'package:quest_cards/src/models/standard_game_system.dart';
import 'package:collection/collection.dart'; // Import for groupBy

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
      }).catchError((error) {
        debugPrint('Error loading unstandardized quests: $error');
        if (mounted) {
          // Check if widget is still mounted
          setState(() {
            _errorMessage = 'Failed to load quests: $error';
          });
        }
        return <QuestCard>[]; // Return empty list on error
      }).whenComplete(() {
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
          content: Text('Navigate to edit quest: ${quest.title ?? 'N/A'}')),
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
    final exists = _standardGameSystems.any((sys) =>
        sys.standardName.toLowerCase() == gameSystemName.toLowerCase());
    if (exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '"$gameSystemName" already exists as a standard game system.')),
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
            content: Text('"$gameSystemName" added as a new standard system.')),
      );
      await _loadStandardGameSystems(); // Refresh standard systems list
      // Optionally: Automatically apply this new standard to the current quest
      // await _gameSystemService.updateQuestStandardizedSystem(quest.id!, newSystem.id!, gameSystemName);
      _loadQuests(); // Refresh the list of unstandardized quests
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding new system: $e')),
        );
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
            content: Text('Quest has no game system name to use as alias.')),
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
            content: Text('No standard systems found to add alias to.')),
      );
      // Attempt to reload standard systems if empty
      await _loadStandardGameSystems();
      if (_standardGameSystems.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Still no standard systems found after reload.')),
        );
        return;
      }
      // If still empty after reload, exit
      if (_standardGameSystems.isEmpty) return;
    }

    // Sort systems alphabetically for the dialog
    final sortedSystems = List<StandardGameSystem>.from(_standardGameSystems)
      ..sort((a, b) =>
          a.standardName.toLowerCase().compareTo(b.standardName.toLowerCase()));

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
                final aliasExists = system.aliases.any(
                        (a) => a.toLowerCase() == aliasName.toLowerCase()) ||
                    system.standardName.toLowerCase() ==
                        aliasName.toLowerCase();
                return ListTile(
                  title: Text(system.standardName),
                  subtitle: aliasExists
                      ? const Text('Alias already exists here',
                          style: TextStyle(color: Colors.orange))
                      : null,
                  onTap: aliasExists
                      ? null
                      : () => Navigator.of(context)
                          .pop(system), // Disable if alias exists
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
        final aliasExists = selectedSystem.aliases
                .any((a) => a.toLowerCase() == aliasName.toLowerCase()) ||
            selectedSystem.standardName.toLowerCase() ==
                aliasName.toLowerCase();
        if (aliasExists) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Alias "$aliasName" already exists for "${selectedSystem.standardName}".')),
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
                  'Added "$aliasName" as alias to "${selectedSystem.standardName}".')),
        );
        await _loadStandardGameSystems(); // Refresh standard systems list
        // Optionally: Update the current quest to use the standardized system
        // await _gameSystemService.updateQuestStandardizedSystem(quest.id!, selectedSystem.id!, aliasName);
        _loadQuests(); // Refresh the list of unstandardized quests
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding alias: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  // --- End New Methods ---

  @override
  Widget build(BuildContext context) {
    final userContext = Provider.of<UserContext>(context);

    // Ensure user is admin
    if (!userContext.isAdmin) {
      return const Center(
          child: Text('Access Denied. Admin privileges required.'));
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
                  child: Text(_errorMessage,
                      style: const TextStyle(color: Colors.red)))
              : FutureBuilder<List<QuestCard>>(
                  future: _unstandardizedQuests,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !_isLoading) {
                      // Show loading indicator only if not already handled by _isLoading
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(
                          child: SelectableText('Error: ${snapshot.error}'));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                          child: Text('No unstandardized quests found.'));
                    }

                    final quests = snapshot.data!;
                    // Group quests by game system name (case-insensitive, handle null/empty)
                    final groupedQuests = groupBy<QuestCard, String>(
                      quests,
                      (quest) => (quest.gameSystem?.trim().toLowerCase() ??
                                  'unknown system')
                              .isEmpty
                          ? 'unknown system'
                          : quest.gameSystem!.trim().toLowerCase(),
                    );

                    // Sort group keys alphabetically
                    final sortedKeys = groupedQuests.keys.toList()
                      ..sort((a, b) => a.compareTo(b));

                    return ListView.builder(
                      itemCount: sortedKeys.length,
                      itemBuilder: (context, index) {
                        final gameSystemKey = sortedKeys[index];
                        final questsInGroup = groupedQuests[gameSystemKey]!;
                        // Use the first quest's gameSystem name for display, handling potential null/empty
                        final displayGameSystem =
                            questsInGroup.first.gameSystem?.trim();
                        final displayTitle = (displayGameSystem == null ||
                                displayGameSystem.isEmpty)
                            ? 'Unknown System'
                            : displayGameSystem;

                        return ExpansionTile(
                          title:
                              Text('$displayTitle (${questsInGroup.length})'),
                          // Add actions for the group
                          trailing: PopupMenuButton<String>(
                            onSelected: (String result) {
                              // Use the first quest as representative for the action
                              final representativeQuest = questsInGroup.first;
                              if (result == 'add_new') {
                                _addAsNewStandardSystem(representativeQuest);
                              } else if (result == 'add_alias') {
                                _addAsAlias(representativeQuest);
                              }
                            },
                            itemBuilder: (BuildContext context) =>
                                <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(
                                value: 'add_new',
                                child: Text('Create New Standard System'),
                              ),
                              PopupMenuItem<String>(
                                value: 'add_alias',
                                enabled: !_isLoadingStandardSystems &&
                                    _standardGameSystems
                                        .isNotEmpty, // Disable if systems loading or empty
                                child: Text(_isLoadingStandardSystems
                                    ? 'Loading systems...'
                                    : 'Add as Alias to Existing'),
                              ),
                            ],
                            icon: const Icon(Icons.more_vert),
                            tooltip: 'Standardize System',
                          ),
                          children: questsInGroup.map((quest) {
                            // Use null-safe access for quest properties
                            final title = quest.title ?? 'No Title';
                            final productTitle =
                                quest.productTitle ?? 'Unknown Product';
                            final status =
                                quest.systemMigrationStatus ?? 'Unknown Status';
                            final gameSystemDisplay = quest.gameSystem ??
                                'No System'; // Display original case here

                            return ListTile(
                              title: Text(title),
                              subtitle: Text(
                                  'Product: $productTitle\nSystem: $gameSystemDisplay\nStatus: $status'),
                              isThreeLine: true,
                              onTap: () => _navigateToEditQuest(
                                  quest), // Navigate to edit on tap
                            );
                          }).toList(),
                        );
                      },
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
