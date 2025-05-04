import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quest_cards/src/auth/auth_dialog_helper.dart';
import 'package:quest_cards/src/filters/active_filter_chips.dart';
import 'package:quest_cards/src/filters/filter_drawer.dart';
import 'package:quest_cards/src/filters/filter_state.dart';
import 'package:quest_cards/src/navigation/root_navigator.dart';
import 'package:quest_cards/src/quest_card/quest_card_details_view.dart';
import 'package:quest_cards/src/services/firestore_service.dart';
import '../util/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// A version of QuestCardListView that works without authentication.
/// Shows quest cards to non-authenticated users and replaces edit/delete
/// buttons with login prompts.
class PublicQuestCardListView extends StatefulWidget {
  const PublicQuestCardListView({super.key});

  @override
  State<PublicQuestCardListView> createState() =>
      _PublicQuestCardListViewState();
}

class _PublicQuestCardListViewState extends State<PublicQuestCardListView> {
  final FirestoreService _firestoreService = FirestoreService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Cache for quest data to improve performance
  final Map<String, dynamic> _questCache = {};

  // Store the scroll position for navigation back
  final ScrollController _scrollController = ScrollController();

  // Pagination settings for better performance
  static const int _pageSize = 15;
  final List<QueryDocumentSnapshot> _questCards = [];
  bool _isLoading = false;
  bool _hasMoreQuests = true;
  DocumentSnapshot? _lastDocument;
  int? _totalQuestCount;

  // Cache settings
  static const String _cacheKey = 'public_quest_cards_cache';
  static const String _cacheTimestampKey = 'public_quest_cards_cache_timestamp';
  static const Duration _cacheDuration = Duration(minutes: 15);

  @override
  void initState() {
    super.initState();

    // Load initial data
    _loadCachedData();

    // Get total count for the app bar
    _loadTotalCount();

    // Add scroll listener for pagination
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  // Load the total count of quests
  Future<void> _loadTotalCount() async {
    try {
      final filterProvider =
          Provider.of<FilterProvider>(context, listen: false);
      _totalQuestCount = await _firestoreService.getPublicQuestCardCount(
        filterState: filterProvider.filterState,
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading quest count: $e');
    }
  }

  // Load more quests when scrolling
  void _scrollListener() {
    if (_scrollController.position.extentAfter < 500 &&
        !_isLoading &&
        _hasMoreQuests) {
      _loadMoreQuests();
    }
  }

  // Load a batch of quest cards
  Future<void> _loadMoreQuests() async {
    if (_isLoading || !_hasMoreQuests) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final filterProvider =
          Provider.of<FilterProvider>(context, listen: false);

      // Track filter usage with analytics when loading more cards with filters
      if (filterProvider.filterState.hasFilters) {
        await filterProvider.trackFilterUsage();
      }

      final snapshots = await _firestoreService.getPublicQuestCardsBatch(
        _pageSize,
        _lastDocument,
        filterState: filterProvider.filterState,
      );

      if (snapshots.isEmpty) {
        setState(() {
          _hasMoreQuests = false;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _questCards.addAll(snapshots);
        _lastDocument = snapshots.last;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading more quests: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheTimestamp = prefs.getInt(_cacheTimestampKey);

      // Check if cache exists and is still valid
      if (cacheTimestamp != null &&
          DateTime.now().millisecondsSinceEpoch - cacheTimestamp <
              _cacheDuration.inMilliseconds) {
        final cachedData = prefs.getString(_cacheKey);

        if (cachedData != null) {
          // No need to decode the data since we're not using it directly
          // We'll load fresh data from Firestore instead

          if (mounted) {
            setState(() {
              // Clear existing data and indicate we're loading fresh data
              _questCards.clear();
            });
          }

          // Immediately load fresh data from Firestore
          _refreshQuestCards(useCache: true);
          return;
        }
      }

      // No valid cache, load from Firestore
      _refreshQuestCards();
    } catch (e) {
      debugPrint('Error loading cached data: $e');
      // If cache loading fails, fallback to network
      _refreshQuestCards();
    }
  }

  Future<void> _cacheData() async {
    if (_questCards.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert Firestore documents to serializable maps
      final List<Map<String, dynamic>> serializableData =
          _questCards.map((doc) {
        Map<String, dynamic> data =
            Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);

        // Handle Timestamp conversion
        data.forEach((key, value) {
          if (value is Timestamp) {
            // Convert Timestamp to millisecondsSinceEpoch (int) for JSON serialization
            data[key] = value.millisecondsSinceEpoch;
          }
        });

        // Include document ID in the cached data
        data['_documentId'] = doc.id;
        return data;
      }).toList();

      final jsonData = json.encode(serializableData);
      await prefs.setString(_cacheKey, jsonData);
      await prefs.setInt(
          _cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // Cache error is non-fatal, just log it
      debugPrint('Failed to cache quest cards: $e');
    }
  }

  Future<void> _refreshQuestCards({bool useCache = false}) async {
    if (_isLoading && !useCache) return;

    try {
      setState(() {
        _isLoading = true;
        if (!useCache) {
          _questCards.clear();
          _hasMoreQuests = true;
          _lastDocument = null;
        }
      });

      final filterProvider =
          Provider.of<FilterProvider>(context, listen: false);

      // Track filter usage when refreshing the quest list with filters
      if (filterProvider.filterState.hasFilters) {
        await filterProvider.trackFilterUsage();
      }

      final cards = await _firestoreService.getPublicQuestCardsBatch(
        _pageSize,
        null, // Reset pagination when refreshing
        filterState: filterProvider.filterState,
      );

      // Update the total count when filters change
      _loadTotalCount();

      if (mounted) {
        setState(() {
          if (!useCache) {
            _questCards.clear();
          }
          _questCards.addAll(cards);
          if (cards.isNotEmpty) {
            _lastDocument = cards.last;
          }
          _isLoading = false;
          _hasMoreQuests = cards.length >= _pageSize;
        });

        // Cache the first batch of data
        _cacheData();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_questCards.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to load quests: ${e.toString()}'),
                action: SnackBarAction(
                  label: 'Retry',
                  onPressed: _refreshQuestCards,
                ),
              ),
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Utils.setBrowserTabTitle("Browse Quests");
    final filterProvider = Provider.of<FilterProvider>(context);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text(
          'Browse Quests',
          style: TextStyle(
            fontSize: 20,
          ),
        ),
        actions: [
          // Add filter button to app bar
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.filter_list),
                if (filterProvider.filterState.hasFilters)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${filterProvider.filterState.filterCount}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            tooltip: 'Filter Quests',
          ),

          // Add login button to app bar
          ElevatedButton.icon(
            icon: const Icon(Icons.login),
            label: const Text('Sign In'),
            onPressed: () => AuthDialogHelper.navigateToAuthScreen(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          const SizedBox(width: 16),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40.0),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _totalQuestCount != null
                      ? "$_totalQuestCount Quests${filterProvider.filterState.hasFilters ? ' (Filtered)' : ''}"
                      : "Loading quests...",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (filterProvider.filterState.hasFilters)
                  TextButton.icon(
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Clear Filters'),
                    onPressed: () {
                      filterProvider.clearFilters();
                      _refreshQuestCards();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      endDrawer: FilterDrawer(isAuthenticated: false),
      onEndDrawerChanged: (isOpen) {
        if (!isOpen) {
          // When drawer closes, refresh the quest list with new filters
          _refreshQuestCards();
        }
      },
      body: Column(
        children: [
          // Welcome banner for non-authenticated users
          _buildWelcomeBanner(context),

          // Show active filters if any
          Consumer<FilterProvider>(
            builder: (context, filterProvider, child) {
              return filterProvider.filterState.hasFilters
                  ? const ActiveFilterChips()
                  : const SizedBox.shrink();
            },
          ),

          // Quest list takes remaining space
          Expanded(
            child: _buildQuestList(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Get root navigator and show login prompt for creating new quests
          final navigator = RootNavigator.of(context);
          if (navigator != null) {
            navigator.showLoginPrompt(context, 'create');
          } else {
            // Fallback to auth dialog helper if navigator not found
            AuthDialogHelper.showLoginPrompt(context, 'create new quests');
          }
        },
        tooltip: 'Add Quest',
        child: const Icon(Icons.add),
      ),
    );
  }

  // Welcome banner for new users
  Widget _buildWelcomeBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome to Questable!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Browse quest cards for tabletop role-playing games. Sign in to create, edit or contribute to the collection.',
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => AuthDialogHelper.navigateToAuthScreen(context),
                child: const Text('Sign In'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => AuthDialogHelper.navigateToAuthScreen(context,
                    isSignUp: true),
                child: const Text('Create Account'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // List of quest cards with pagination and caching
  Widget _buildQuestList(BuildContext context) {
    if (_questCards.isEmpty && !_isLoading) {
      if (!_hasMoreQuests) {
        return const Center(child: Text('No quests available'));
      }
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: _questCards.length + (_isLoading || !_hasMoreQuests ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _questCards.length) {
          // Show loading indicator at the bottom while loading more
          return _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              : const SizedBox(); // End of the list
        }

        DocumentSnapshot document = _questCards[index];
        String docId = document.id;
        Map<String, dynamic> data = document.data() as Map<String, dynamic>;

        // Cache the data for quicker access later
        _questCache[docId] = data;

        String title = data['title'];
        return Hero(
          tag: 'quest_card_$docId',
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                // Prioritize standardized system for icon
                backgroundImage: Utils.getSystemIcon(
                    data['standardizedGameSystem'] ?? data['gameSystem'] ?? ''),
                backgroundColor: Colors.transparent,
              ),
              title: AutoSizeText(
                Utils.capitalizeTitle(title),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                // Prioritize standardized system name, fallback to original
                "${data['standardizedGameSystem'] ?? data['gameSystem'] ?? 'Unknown'} • Level ${data['level'] ?? '?'} • ${data['pageLength'] ?? '?'} pages",
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => QuestCardDetailsView(docId: docId),
                  ),
                );
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Edit button with login prompt
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      final navigator = RootNavigator.of(context);
                      if (navigator != null) {
                        navigator.showLoginPrompt(context, 'edit',
                            docId: docId);
                      } else {
                        AuthDialogHelper.showLoginPrompt(
                            context, 'edit quests');
                      }
                    },
                    tooltip: 'Edit (requires login)',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
