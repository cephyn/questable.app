import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../services/game_system_migration_service.dart';
import '../services/game_system_service.dart';
import '../models/standard_game_system.dart';

/// Analytics dashboard for game system standardization
class GameSystemAnalyticsView extends StatefulWidget {
  const GameSystemAnalyticsView({super.key});

  @override
  State<GameSystemAnalyticsView> createState() =>
      _GameSystemAnalyticsViewState();
}

class _GameSystemAnalyticsViewState extends State<GameSystemAnalyticsView> {
  final GameSystemMigrationService _migrationService =
      GameSystemMigrationService();
  final GameSystemService _gameSystemService = GameSystemService();

  Map<String, int> _standardizationStats = {};
  List<Map<String, dynamic>> _recentMigrations = [];
  List<StandardGameSystem> _topGameSystems = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  /// Load all analytics data needed for the dashboard
  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load stats in parallel for better performance
      final statsRequest = _migrationService.getStandardizationStats();
      final migrationsRequest =
          _migrationService.getRecentMigrations(limit: 10);
      final systemsRequest = _gameSystemService.getAllGameSystems();

      final stats = await statsRequest;
      final migrations = await migrationsRequest;
      final systems = await systemsRequest;

      // Sort systems by usage frequency
      systems.sort((a, b) =>
          (migrations
              .where((m) => m['standardName'] == b.standardName)
              .length) -
          (migrations
              .where((m) => m['standardName'] == a.standardName)
              .length));

      setState(() {
        _standardizationStats = stats;
        _recentMigrations = migrations;
        _topGameSystems = systems.take(10).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load analytics data: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game System Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(_error!, style: TextStyle(color: Colors.red)))
              : _buildDashboard(),
    );
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(),
          const SizedBox(height: 24),
          _buildProgressChart(),
          const SizedBox(height: 24),
          _buildMigrationHistory(),
          const SizedBox(height: 24),
          _buildTopSystemsTable(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final total = _standardizationStats['total'] ?? 0;
    final standardized = _standardizationStats['standardized'] ?? 0;
    final pending = _standardizationStats['pending'] ?? 0;
    final failed = _standardizationStats['failed'] ?? 0;

    final standardizedPercent =
        total > 0 ? (standardized / total * 100).toStringAsFixed(1) : '0';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Standardization Progress',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(
                  'Standardized',
                  '$standardized',
                  '$standardizedPercent%',
                  Colors.green,
                  Icons.check_circle,
                ),
                _buildStatCard(
                  'Pending',
                  '$pending',
                  pending > 0 ? 'Needs Review' : 'All Clear',
                  Colors.orange,
                  Icons.pending,
                ),
                _buildStatCard(
                  'Failed',
                  '$failed',
                  failed > 0 ? 'Needs Attention' : 'All Clear',
                  failed > 0 ? Colors.red : Colors.green,
                  failed > 0 ? Icons.error : Icons.check_circle,
                ),
                _buildStatCard(
                  'Total',
                  '$total',
                  '100%',
                  Colors.blue,
                  Icons.analytics,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, String subtitle, Color color, IconData icon) {
    return SizedBox(
      width: 150,
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressChart() {
    final total = _standardizationStats['total'] ?? 0;
    if (total == 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: Text('No data available for visualization')),
        ),
      );
    }

    final standardized = _standardizationStats['standardized'] ?? 0;
    final pending = _standardizationStats['pending'] ?? 0;
    final failed = _standardizationStats['failed'] ?? 0;
    final unprocessed = _standardizationStats['unprocessed'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Standardization Distribution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: standardized.toDouble(),
                      title:
                          '${(standardized / total * 100).toStringAsFixed(1)}%',
                      color: Colors.green,
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      value: pending.toDouble(),
                      title: pending > 0
                          ? '${(pending / total * 100).toStringAsFixed(1)}%'
                          : '',
                      color: Colors.orange,
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      value: failed.toDouble(),
                      title: failed > 0
                          ? '${(failed / total * 100).toStringAsFixed(1)}%'
                          : '',
                      color: Colors.red,
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      value: unprocessed.toDouble(),
                      title: unprocessed > 0
                          ? '${(unprocessed / total * 100).toStringAsFixed(1)}%'
                          : '',
                      color: Colors.grey,
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  startDegreeOffset: -90,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildLegendItem('Standardized', Colors.green),
                _buildLegendItem('Pending', Colors.orange),
                _buildLegendItem('Failed', Colors.red),
                _buildLegendItem('Unprocessed', Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }

  Widget _buildMigrationHistory() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Migration Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('System Name')),
                  DataColumn(label: Text('Affected')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Success Rate')),
                ],
                rows: _recentMigrations.map((migration) {
                  final timestamp = migration['timestamp'] as Timestamp?;
                  final date = timestamp != null
                      ? DateFormat('yyyy-MM-dd HH:mm')
                          .format(timestamp.toDate())
                      : 'Unknown';

                  final affected = migration['affectedCount'] as int? ?? 0;
                  final success = migration['successCount'] as int? ?? 0;
                  final successRate = affected > 0
                      ? '${(success / affected * 100).toStringAsFixed(1)}%'
                      : 'N/A';

                  Color statusColor;
                  switch (migration['status']) {
                    case 'completed':
                      statusColor = Colors.green;
                      break;
                    case 'in_progress':
                      statusColor = Colors.blue;
                      break;
                    case 'undone':
                      statusColor = Colors.orange;
                      break;
                    default:
                      statusColor = Colors.grey;
                  }

                  return DataRow(
                    cells: [
                      DataCell(Text(date)),
                      DataCell(Text(
                          migration['standardName'] as String? ?? 'Unknown')),
                      DataCell(Text('$affected')),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: statusColor),
                          ),
                          child: Text(
                            (migration['status'] as String? ?? 'unknown')
                                .toUpperCase(),
                            style: TextStyle(color: statusColor, fontSize: 12),
                          ),
                        ),
                      ),
                      DataCell(Text(successRate)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSystemsTable() {
    if (_topGameSystems.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: Text('No game systems available')),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Game Systems',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('System Name')),
                  DataColumn(label: Text('Aliases')),
                  DataColumn(label: Text('Publisher')),
                  DataColumn(label: Text('Editions')),
                  DataColumn(label: Text('Last Modified')),
                ],
                rows: _topGameSystems.map((system) {
                  final aliases = system.aliases.join(', ');
                  final editions =
                      system.editions.map((e) => e.name).join(', ');
                  final dateString = system.updatedAt != null
                      ? DateFormat('yyyy-MM-dd').format(system.updatedAt!)
                      : 'N/A';

                  return DataRow(
                    cells: [
                      DataCell(Text(system.standardName)),
                      DataCell(Text(aliases)),
                      DataCell(Text(system.publisher ?? 'Unknown')),
                      DataCell(Text(editions.isNotEmpty ? editions : 'None')),
                      DataCell(Text(dateString)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
