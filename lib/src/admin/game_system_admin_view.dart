import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quest_cards/src/auth/user_context.dart';
import 'package:quest_cards/src/models/standard_game_system.dart';
import 'package:quest_cards/src/services/game_system_service.dart';
import 'package:quest_cards/src/admin/game_system_detail_view.dart';
import 'package:quest_cards/src/admin/game_system_batch_view.dart';
import 'package:quest_cards/src/admin/game_system_analytics_view.dart';
import 'package:quest_cards/src/admin/unstandardized_quests_view.dart'; // Import the new view

/// Game System Admin View
///
/// Main admin interface for managing game system standardization
class GameSystemAdminView extends StatefulWidget {
  const GameSystemAdminView({super.key});

  @override
  State<GameSystemAdminView> createState() => _GameSystemAdminViewState();
}

class _GameSystemAdminViewState extends State<GameSystemAdminView> {
  final GameSystemService _gameSystemService = GameSystemService();
  late Future<List<StandardGameSystem>> _gameSystems;
  bool _isLoading = false;
  String _searchQuery = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadGameSystems();
  }

  void _loadGameSystems() {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      // Add debug print
      debugPrint('Loading game systems...');

      _gameSystems = _gameSystemService.getAllGameSystems().then((systems) {
        debugPrint('Loaded ${systems.length} game systems');
        return systems;
      }).catchError((error) {
        debugPrint('Error loading game systems: $error');
        setState(() {
          _errorMessage = 'Failed to load game systems: $error';
        });
        return <StandardGameSystem>[];
      }).whenComplete(() {
        setState(() {
          _isLoading = false;
        });
      });
    });
  }

  void _navigateToAddSystem() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const GameSystemDetailView(),
      ),
    ).then((_) => _loadGameSystems());
  }

  void _navigateToEditSystem(StandardGameSystem system) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameSystemDetailView(gameSystem: system),
      ),
    ).then((_) => _loadGameSystems());
  }

  void _navigateToUnstandardizedQuests() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UnstandardizedQuestsView(),
      ),
    );
  }

  Future<void> _deleteSystem(StandardGameSystem system) async {
    final bool confirm = await showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Confirm Deletion'),
              content: Text(
                'Are you sure you want to delete "${system.standardName}"? '
                'This will not update any quest cards currently using this system. '
                'This action cannot be undone.',
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
                TextButton(
                  child: const Text('Delete'),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirm) {
      try {
        setState(() => _isLoading = true);
        await _gameSystemService.deleteGameSystem(system.id!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted ${system.standardName}')),
        );
        _loadGameSystems();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  List<StandardGameSystem> _getFilteredSystems(
      List<StandardGameSystem> systems) {
    if (_searchQuery.isEmpty) return systems;

    final query = _searchQuery.toLowerCase();
    return systems.where((system) {
      // Match on standard name
      if (system.standardName.toLowerCase().contains(query)) {
        return true;
      }

      // Match on aliases
      if (system.aliases.any((alias) => alias.toLowerCase().contains(query))) {
        return true;
      }

      // Match on publisher
      if (system.publisher != null &&
          system.publisher!.toLowerCase().contains(query)) {
        return true;
      }

      return false;
    }).toList();
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
        title: const Text('Game System Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.rule_folder_outlined), // Icon for unstandardized quests
            onPressed: _navigateToUnstandardizedQuests,
            tooltip: 'View Unstandardized Quests', // Tooltip for the new button
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const GameSystemAnalyticsView(),
              ),
            ),
            tooltip: 'Analytics Dashboard',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGameSystems,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search game systems...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            ),
          Expanded(
            child: FutureBuilder<List<StandardGameSystem>>(
              future: _gameSystems,
              builder: (context, snapshot) {
                // Add more debug info to the UI
                if (snapshot.connectionState == ConnectionState.waiting ||
                    _isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading game systems:',
                          style:
                              const TextStyle(color: Colors.red, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: Text('No data returned from game systems query.'),
                  );
                }

                if (snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.info_outline, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'No game systems found in the database.',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add Your First Game System'),
                          onPressed: _navigateToAddSystem,
                        ),
                      ],
                    ),
                  );
                }

                final filteredSystems = _getFilteredSystems(snapshot.data!);

                if (filteredSystems.isEmpty) {
                  return Center(
                    child: Text('No game systems match "$_searchQuery"'),
                  );
                }

                return ListView.builder(
                  itemCount: filteredSystems.length,
                  itemBuilder: (context, index) {
                    final system = filteredSystems[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ListTile(
                        title: Text(system.standardName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (system.publisher != null)
                              Text('Publisher: ${system.publisher}'),
                            if (system.aliases.isNotEmpty)
                              Text(
                                'Aliases: ${system.aliases.join(", ")}',
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.sync_alt),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => GameSystemBatchView(
                                    gameSystem: system,
                                  ),
                                ),
                              ),
                              tooltip: 'Batch Operations',
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _navigateToEditSystem(system),
                              tooltip: 'Edit System',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteSystem(system),
                              tooltip: 'Delete System',
                            ),
                          ],
                        ),
                        onTap: () => _navigateToEditSystem(system),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddSystem,
        tooltip: 'Add Game System',
        child: const Icon(Icons.add),
      ),
    );
  }
}
