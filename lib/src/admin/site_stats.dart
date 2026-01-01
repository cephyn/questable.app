import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SiteStatsAdminView extends StatefulWidget {
  const SiteStatsAdminView({super.key});

  @override
  State<SiteStatsAdminView> createState() => _SiteStatsAdminViewState();
}

class _SiteStatsAdminViewState extends State<SiteStatsAdminView> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('get_site_stats');
      final resp = await callable.call();
      final data = Map<String, dynamic>.from(resp.data ?? {});
      setState(() {
        _stats = data;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildCard(String title, String value) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopUploaders() {
    final List<dynamic> uploads = _stats['topUploaders'] ?? [];
    if (uploads.isEmpty) return const Text('No upload data');
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Top Uploaders', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...uploads.map((u) {
              final uploader = u['uploader'] ?? 'unknown';
              final count = u['count'] ?? 0;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(uploader.toString()),
                trailing: Text(count.toString()),
              );
            }).toList()
          ],
        ),
      ),
    );
  }

  Widget _buildMostOwned() {
    final List<dynamic> owned = _stats['mostOwnedQuests'] ?? [];
    if (owned.isEmpty) return const Text('No ownership data');
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Most Owned Quests', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...owned.map((o) {
              final title = o['title'] ?? o['questId'] ?? 'Unknown';
              final count = o['count'] ?? 0;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(title.toString()),
                trailing: Text(count.toString()),
              );
            }).toList()
          ],
        ),
      ),
    );
  }

  Widget _buildUsersPerDay() {
    final Map<String, dynamic> usersPerDay = Map<String, dynamic>.from(_stats['usersPerDay'] ?? {});
    if (usersPerDay.isEmpty) return const Text('No user creation data');
    final entries = usersPerDay.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Users By Day', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...entries.map((e) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(e.key),
              trailing: Text(e.value.toString()),
            ))
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Site Statistics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchStats,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('Error: $_error'))
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildCard('Total Users', (_stats['totalUsers'] ?? 0).toString())),
                            const SizedBox(width: 12),
                            Expanded(child: _buildCard('Total Quests', (_stats['totalQuests'] ?? 0).toString())),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTopUploaders(),
                        const SizedBox(height: 16),
                        _buildMostOwned(),
                        const SizedBox(height: 16),
                        _buildUsersPerDay(),
                      ],
                    ),
                  ),
      ),
    );
  }
}
