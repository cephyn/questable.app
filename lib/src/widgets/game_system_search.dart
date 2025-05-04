import 'package:flutter/material.dart';
import 'package:quest_cards/src/models/standard_game_system.dart';
import 'package:quest_cards/src/services/game_system_service.dart';
import 'package:quest_cards/src/util/utils.dart'; // Import Utils
import 'dart:async'; // For Debouncer

/// A widget that allows searching for StandardGameSystems by name or alias.
class GameSystemSearch extends StatefulWidget {
  /// Callback function when a game system is selected.
  final ValueChanged<StandardGameSystem> onSelected;

  const GameSystemSearch({super.key, required this.onSelected});

  @override
  State<GameSystemSearch> createState() => _GameSystemSearchState();
}

class _GameSystemSearchState extends State<GameSystemSearch> {
  final GameSystemService _gameSystemService = GameSystemService();
  final TextEditingController _searchController = TextEditingController();
  List<StandardGameSystem> _allGameSystems = [];
  List<StandardGameSystem> _filteredGameSystems = [];
  bool _isLoading = true;
  String _errorMessage = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadGameSystems();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadGameSystems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      _allGameSystems = await _gameSystemService.getAllGameSystems();
      // Sort alphabetically by standard name initially
      _allGameSystems.sort((a, b) => a.standardName.compareTo(b.standardName));
      _filteredGameSystems = _allGameSystems; // Initially show all
    } catch (e) {
      _errorMessage = 'Error loading game systems: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _filterGameSystems(_searchController.text);
    });
  }

  void _filterGameSystems(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredGameSystems = _allGameSystems;
      });
      return;
    }

    final lowerCaseQuery = query.trim().toLowerCase();
    if (lowerCaseQuery.isEmpty) {
      setState(() {
        _filteredGameSystems = _allGameSystems;
      });
      return;
    }

    final filtered = _allGameSystems.where((system) {
      // Check standard name
      if (system.standardName.toLowerCase().contains(lowerCaseQuery)) {
        return true;
      }
      // Check aliases
      if (system.aliases
          .any((alias) => alias.toLowerCase().contains(lowerCaseQuery))) {
        return true;
      }
      return false;
    }).toList();

    if (mounted) {
      setState(() {
        _filteredGameSystems = filtered;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search Game Systems (Name or Alias)',
              hintText: 'e.g., D&D, Pathfinder, Shadowdark...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        // _filterGameSystems(''); // Listener handles this
                      },
                    )
                  : null,
            ),
          ),
        ),
        if (_isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child:
                Text(_errorMessage, style: const TextStyle(color: Colors.red)),
          )
        else if (_filteredGameSystems.isEmpty &&
            _searchController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
                'No game systems found matching "${_searchController.text}".'),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _filteredGameSystems.length,
              itemBuilder: (context, index) {
                final system = _filteredGameSystems[index];
                return ListTile(
                  leading: CircleAvatar(
                    // Use Utils.getSystemIcon
                    backgroundImage: Utils.getSystemIcon(
                        system.standardName), // Pass only standardName
                    backgroundColor:
                        Colors.transparent, // Make background transparent
                  ),
                  title: Text(system.standardName),
                  subtitle: system.aliases.isNotEmpty
                      ? Text('Aliases: ${system.aliases.join(', ')}',
                          style: TextStyle(color: Colors.grey[600]))
                      : null,
                  onTap: () {
                    widget.onSelected(system);
                    // Optionally clear search or close a dialog if used within one
                    // _searchController.clear();
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
