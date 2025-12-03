import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Simple admin dashboard showing recent backfill runs and basic metrics.
class SearchBackfillDashboard extends StatefulWidget {
  const SearchBackfillDashboard({super.key});

  @override
  State<SearchBackfillDashboard> createState() => _SearchBackfillDashboardState();
}

class _SearchBackfillDashboardState extends State<SearchBackfillDashboard> {
  int? _totalRuns;
  int? _totalProcessed;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    try {
      final db = FirebaseFirestore.instance;
      final countSnapshot = await db.collection('backfill_runs').count().get();
      final total = countSnapshot.count;

      // Sum recent processed counts (last 50)
      final snapshot = await db.collection('backfill_runs').orderBy('startTime', descending: true).limit(50).get();
      int processedSum = 0;
      for (final d in snapshot.docs) {
        final data = d.data();
        if (data.containsKey('processed') && data['processed'] is int) {
          processedSum += data['processed'] as int;
        }
      }

      setState(() {
        _totalRuns = total;
        _totalProcessed = processedSum;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Backfill Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Backfill runs (most recent)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _loading ? const CircularProgressIndicator() : Text('Total runs: $_totalRuns'),
                    _loading ? const SizedBox() : Text('Processed (last 50): $_totalProcessed'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('backfill_runs')
                    .orderBy('startTime', descending: true)
                    .limit(50)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text('No backfill runs found'));
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final d = docs[index];
                      final data = d.data();
                      final status = data['status'] ?? 'unknown';
                      final processed = data['processed'] ?? 0;
                      final initiatedBy = data['initiatedBy'] ?? 'system';
                      final startTime = data['startTime'];
                      final endTime = data['endTime'];

                      return Card(
                        child: ListTile(
                          title: Text('Run ${d.id} — $status'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Processed: $processed'),
                              Text('Initiated by: $initiatedBy'),
                              Text('Start: ${startTime ?? 'N/A'}'),
                              Text('End: ${endTime ?? 'N/A'}'),
                              if (data.containsKey('error')) Text('Error: ${data['error']}', style: const TextStyle(color: Colors.red)),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
