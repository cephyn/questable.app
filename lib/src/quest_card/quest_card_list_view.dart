import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart'; // Add this import

import 'package:quest_cards/src/filters/active_filter_chips.dart';
import 'package:quest_cards/src/filters/filter_drawer.dart';
import 'package:quest_cards/src/filters/filter_state.dart';
import 'package:quest_cards/src/quest_card/quest_card_details_view.dart';
import 'package:quest_cards/src/quest_card/quest_card_edit.dart';
import 'package:quest_cards/src/role_based_widgets/role_based_delete_documents_buttons.dart';
import 'package:quest_cards/src/services/firebase_auth_service.dart';
import 'package:quest_cards/src/services/firestore_service.dart';

import '../util/utils.dart';

class QuestCardListView extends StatefulWidget {
  final List<String> questCardList;

  const QuestCardListView({super.key, required this.questCardList});

  @override
  State<QuestCardListView> createState() => _QuestCardListViewState();
}

class _QuestCardListViewState extends State<QuestCardListView> {
  final FirestoreService firestoreService = FirestoreService();
  final FirebaseAuthService auth = FirebaseAuthService();
  final RoleBasedDeleteDocumentsButtons rbDeleteDocumentsButtons =
      RoleBasedDeleteDocumentsButtons();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int? _totalQuestCount;
  final bool _isLoading = false;
  bool _hasTrackedInitialFilters = false;

  @override
  void initState() {
    super.initState();
    _loadTotalCount();

    // Preload filter options for the filter drawer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final filterProvider =
          Provider.of<FilterProvider>(context, listen: false);
      _loadFilterOptions(filterProvider);

      // Set the analytics user ID for authenticated users
      _setupAnalytics(filterProvider);
    });
  }

  // Set up analytics with the current user ID
  void _setupAnalytics(FilterProvider provider) async {
    final user = auth.getCurrentUser();
    if (user.email != null) {
      await provider.setAnalyticsUserId(user.email);
    }
  }

  // Load distinct values for filter options
  Future<void> _loadFilterOptions(FilterProvider provider) async {
    try {
      // Load game systems
      final gameSystems =
          await firestoreService.getDistinctFieldValues('gameSystem');
      if (gameSystems.isNotEmpty) {
        provider.filterOptions['gameSystem'] = gameSystems;
      }

      // Load editions
      final editions = await firestoreService.getDistinctFieldValues('edition');
      if (editions.isNotEmpty) {
        provider.filterOptions['edition'] = editions;
      }

      // Load publishers
      final publishers =
          await firestoreService.getDistinctFieldValues('publisher');
      if (publishers.isNotEmpty) {
        provider.filterOptions['publisher'] = publishers;
      }

      // Notify listeners to update UI
      //provider.notifyListeners();
    } catch (e) {
      debugPrint('Error loading filter options: $e');
    }
  }

  // Load the total count of quests
  Future<void> _loadTotalCount() async {
    try {
      final filterProvider =
          Provider.of<FilterProvider>(context, listen: false);
      _totalQuestCount = await firestoreService.getQuestCardsCount(
        filterState: filterProvider.filterState,
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading quest count: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    Utils.setBrowserTabTitle("List Quests");
    final filterProvider = Provider.of<FilterProvider>(context);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text(
          'Quests',
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
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40.0),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _isLoading || _totalQuestCount == null
                    ? const CircularProgressIndicator()
                    : Text(
                        "$_totalQuestCount Quests${filterProvider.filterState.hasFilters ? ' (Filtered)' : ''}",
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
                      // Force refresh
                      setState(() {
                        _loadTotalCount();
                      });
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
      endDrawer: FilterDrawer(isAuthenticated: true),
      onEndDrawerChanged: (isOpen) {
        if (!isOpen) {
          // When drawer closes, refresh the quest count
          _loadTotalCount();

          // Track filter usage when drawer closes
          if (filterProvider.filterState.hasFilters) {
            filterProvider.trackFilterUsage();
          }

          // Refresh happens automatically due to stream
        }
      },
      body: Column(
        children: [
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
    );
  }

  Widget _buildQuestList(BuildContext context) {
    final filterProvider = Provider.of<FilterProvider>(context);

    return StreamBuilder<List<QueryDocumentSnapshot>>(
      stream: firestoreService.getQuestCardsStream(
        widget.questCardList,
        filterState: filterProvider.filterState,
      ),
      builder: (context, snapshot) {
        // Track filter usage when data is loaded (only once per filter combination)
        if (snapshot.connectionState == ConnectionState.active &&
            !_hasTrackedInitialFilters &&
            filterProvider.filterState.hasFilters) {
          // Use Future.microtask to avoid triggering during build
          Future.microtask(() {
            filterProvider.trackFilterUsage();
            _hasTrackedInitialFilters = true;
          });
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          // Enhanced error logging
          final error = snapshot.error;
          final stackTrace = snapshot.stackTrace;

          // Log to console for immediate visibility
          debugPrint('');
          debugPrint('====== QUEST LIST ERROR ======');
          debugPrint('Error: $error');
          debugPrint('StackTrace: $stackTrace');

          // Check if error contains a URL for better display
          String errorMessage = error.toString();
          final urlRegExp = RegExp(r'https?:\/\/[^\s]+');
          final match = urlRegExp.firstMatch(errorMessage);
          String? url;
          if (match != null) {
            url = match.group(0);
            debugPrint('Error URL: $url');
          }
          debugPrint('==============================');

          // Display a user-friendly error message with details
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Error Loading Quests',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    'An error occurred while applying filters. The error has been logged to the console and error.log file.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                if (filterProvider.filterState.hasFilters)
                  Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Clear All Filters'),
                      onPressed: () {
                        filterProvider.clearFilters();
                        // Force refresh
                        setState(() {
                          _loadTotalCount();
                        });
                      },
                    ),
                  ),
              ],
            ),
          );
        } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          List<QueryDocumentSnapshot> questCards = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: questCards.length,
            itemBuilder: (context, index) {
              DocumentSnapshot document = questCards[index];
              String docId = document.id;
              Map<String, dynamic> data =
                  document.data() as Map<String, dynamic>;
              String title = data['title'];

              return Card(
                margin:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: ListTile(
                  leading: CircleAvatar(
                    // Prioritize standardized system for icon
                    backgroundImage: Utils.getSystemIcon(
                        data['standardizedGameSystem'] ??
                            data['gameSystem'] ??
                            ''),
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
                    // Navigate using GoRouter
                    context.go('/quests/$docId');
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //     builder: (context) =>
                    //         QuestCardDetailsView(docId: docId),
                    //   ),
                    // );
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          // TODO: Update EditQuestCard navigation if needed (might need its own route)
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditQuestCard(
                                docId: docId,
                              ),
                            ),
                          );
                        },
                        tooltip: 'Edit Quest',
                      ),
                      rbDeleteDocumentsButtons.deleteQuestCardButton(
                        auth.getCurrentUser().uid,
                        docId,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        } else {
          return Center(
            child: filterProvider.filterState.hasFilters
                ? const Text("No quests match the current filters",
                    style: TextStyle(fontSize: 16))
                : const Text("No quests available",
                    style: TextStyle(fontSize: 16)),
          );
        }
      },
    );
  }
}
