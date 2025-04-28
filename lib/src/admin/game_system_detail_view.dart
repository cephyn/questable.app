import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quest_cards/src/auth/user_context.dart';
import 'package:quest_cards/src/models/standard_game_system.dart';
import 'package:quest_cards/src/services/game_system_service.dart';
import 'package:quest_cards/src/services/game_system_migration_service.dart';
import 'package:quest_cards/src/admin/game_system_batch_view.dart';

/// Game System Detail View
///
/// Detailed view for editing a specific game system
/// Includes alias management and edition management interfaces
class GameSystemDetailView extends StatefulWidget {
  final StandardGameSystem? gameSystem;

  const GameSystemDetailView({super.key, this.gameSystem});

  @override
  State<GameSystemDetailView> createState() => _GameSystemDetailViewState();
}

class _GameSystemDetailViewState extends State<GameSystemDetailView> {
  final _formKey = GlobalKey<FormState>();
  final GameSystemService _gameSystemService = GameSystemService();
  final GameSystemMigrationService _migrationService =
      GameSystemMigrationService();
  bool _isLoading = false;
  bool _isEditing = false;
  int _affectedQuestsCount = 0;
  bool _isLoadingPreview = false;

  // Form fields
  late TextEditingController _nameController;
  late TextEditingController _publisherController;
  late TextEditingController _descriptionController;
  late TextEditingController _newAliasController;
  late TextEditingController _newEditionNameController;
  late TextEditingController _newEditionDescriptionController;
  late TextEditingController _newEditionYearController;

  List<String> _aliases = [];
  List<GameSystemEdition> _editions = [];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.gameSystem != null;
    _initControllers();

    if (_isEditing) {
      _loadExistingData();
      _loadAffectedQuestsPreview();
    }
  }

  void _initControllers() {
    _nameController = TextEditingController();
    _publisherController = TextEditingController();
    _descriptionController = TextEditingController();
    _newAliasController = TextEditingController();
    _newEditionNameController = TextEditingController();
    _newEditionDescriptionController = TextEditingController();
    _newEditionYearController = TextEditingController();
  }

  void _loadExistingData() {
    final system = widget.gameSystem!;
    _nameController.text = system.standardName;
    _publisherController.text = system.publisher ?? '';
    _descriptionController.text = system.description ?? '';
    _aliases = List.from(system.aliases);
    _editions = List.from(system.editions);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _publisherController.dispose();
    _descriptionController.dispose();
    _newAliasController.dispose();
    _newEditionNameController.dispose();
    _newEditionDescriptionController.dispose();
    _newEditionYearController.dispose();
    super.dispose();
  }

  Future<void> _saveGameSystem() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final standardName = _nameController.text.trim();
      final publisher = _publisherController.text.trim();
      final description = _descriptionController.text.trim();

      final gameSystem = StandardGameSystem(
        id: _isEditing ? widget.gameSystem!.id : null,
        standardName: standardName,
        aliases: _aliases,
        publisher: publisher.isNotEmpty ? publisher : null,
        description: description.isNotEmpty ? description : null,
        editions: _editions,
        createdAt: _isEditing ? widget.gameSystem!.createdAt : null,
      );

      if (_isEditing) {
        await _gameSystemService.updateGameSystem(gameSystem);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game system updated successfully')),
        );
      } else {
        final id = await _gameSystemService.createGameSystem(gameSystem);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game system created successfully')),
        );
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addAlias() {
    final alias = _newAliasController.text.trim();
    if (alias.isNotEmpty) {
      if (_aliases.contains(alias)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This alias already exists')),
        );
      } else {
        setState(() {
          _aliases.add(alias);
          _newAliasController.clear();
        });
      }
    }
  }

  void _removeAlias(String alias) {
    setState(() {
      _aliases.remove(alias);
    });
  }

  void _addEdition() {
    final name = _newEditionNameController.text.trim();
    final description = _newEditionDescriptionController.text.trim();
    final yearText = _newEditionYearController.text.trim();

    if (name.isEmpty) {
      return;
    }

    int? year;
    if (yearText.isNotEmpty) {
      year = int.tryParse(yearText);
      if (year == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Year must be a valid number')),
        );
        return;
      }
    }

    final edition = GameSystemEdition(
      name: name,
      description: description.isNotEmpty ? description : null,
      year: year,
    );

    setState(() {
      _editions.add(edition);
      _newEditionNameController.clear();
      _newEditionDescriptionController.clear();
      _newEditionYearController.clear();
    });
  }

  void _removeEdition(int index) {
    setState(() {
      _editions.removeAt(index);
    });
  }

  void _navigateToBatchOperations() {
    if (!_isEditing || widget.gameSystem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please save the game system first')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameSystemBatchView(
          gameSystem: widget.gameSystem!,
        ),
      ),
    );
  }

  Future<void> _loadAffectedQuestsPreview() async {
    if (!_isEditing || widget.gameSystem == null) {
      return;
    }

    setState(() {
      _isLoadingPreview = true;
    });

    try {
      // Load exact matches for the standard name
      final directMatches = await _migrationService.getQuestCardsByGameSystem(
        widget.gameSystem!.standardName,
      );

      // Load matches for each alias
      int aliasMatches = 0;
      for (final alias in _aliases) {
        final matches =
            await _migrationService.getQuestCardsByGameSystem(alias);
        aliasMatches += matches.length;
      }

      setState(() {
        _affectedQuestsCount = directMatches.length + aliasMatches;
        _isLoadingPreview = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingPreview = false;
      });
      debugPrint('Error loading affected quests preview: $e');
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
        title: Text(_isEditing ? 'Edit Game System' : 'Add Game System'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.sync_alt),
              onPressed: _navigateToBatchOperations,
              tooltip: 'Batch Operations',
            ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveGameSystem,
            tooltip: 'Save',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Standard Name *',
                        hintText: 'Official name of the game system',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a standard name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _publisherController,
                      decoration: const InputDecoration(
                        labelText: 'Publisher',
                        hintText:
                            'Company or person that publishes the game system',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Brief description of the game system',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),

                    // Aliases section
                    const Text(
                      'Aliases',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Alternative names or common variations used for this game system',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newAliasController,
                            decoration: const InputDecoration(
                              labelText: 'New Alias',
                              hintText: 'Add an alternative name',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _addAlias(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addAlias,
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _aliases.map((alias) {
                        return Chip(
                          label: Text(alias),
                          onDeleted: () => _removeAlias(alias),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Editions section
                    const Text(
                      'Editions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Different versions or editions of this game system',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Add New Edition',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _newEditionNameController,
                              decoration: const InputDecoration(
                                labelText: 'Edition Name *',
                                hintText: 'e.g., "5th Edition", "Revised"',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _newEditionDescriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                hintText: 'Brief description of this edition',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _newEditionYearController,
                              decoration: const InputDecoration(
                                labelText: 'Year Published',
                                hintText: 'e.g., 2014',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _addEdition,
                              child: const Text('Add Edition'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_editions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('No editions added yet'),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _editions.length,
                        itemBuilder: (context, index) {
                          final edition = _editions[index];
                          return Card(
                            child: ListTile(
                              title: Text(edition.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (edition.description != null)
                                    Text(edition.description!),
                                  if (edition.year != null)
                                    Text('Year: ${edition.year}'),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _removeEdition(index),
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 24),

                    // Preview of affected records section
                    if (_isEditing) ...[
                      const Text(
                        'Affected Quest Cards',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _isLoadingPreview
                          ? const Center(child: CircularProgressIndicator())
                          : Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          _affectedQuestsCount > 0
                                              ? Icons.check_circle
                                              : Icons.info_outline,
                                          color: _affectedQuestsCount > 0
                                              ? Colors.green
                                              : Colors.blue,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _affectedQuestsCount > 0
                                              ? Text(
                                                  'Found $_affectedQuestsCount quest cards that would be affected by standardization',
                                                )
                                              : const Text(
                                                  'No quest cards found that match this game system or its aliases',
                                                ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: _navigateToBatchOperations,
                                      icon: const Icon(Icons.sync_alt),
                                      label: const Text(
                                          'View & Standardize Quest Cards'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      const SizedBox(height: 16),
                    ],

                    // TODO: Add preview of affected quest cards section
                  ],
                ),
              ),
            ),
    );
  }
}
