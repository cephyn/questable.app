import 'dart:developer';
import 'package:flutter/material.dart';
import '../controllers/purchase_link_backfill_controller.dart';
import '../models/backfill_stats.dart';

/// Screen for backfilling purchase links for existing QuestCards
class PurchaseLinkBackfillScreen extends StatefulWidget {
  const PurchaseLinkBackfillScreen({super.key});

  @override
  _PurchaseLinkBackfillScreenState createState() =>
      _PurchaseLinkBackfillScreenState();
}

class _PurchaseLinkBackfillScreenState
    extends State<PurchaseLinkBackfillScreen> {
  final PurchaseLinkBackfillController _controller =
      PurchaseLinkBackfillController();
  BackfillStats? _stats;
  bool _isProcessing = false;
  String _statusMessage = '';
  int _batchSize = 20;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Purchase Link Backfill')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Backfill Purchase Links',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'This tool will search for purchase links for QuestCards that do not already have them.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),

            // Batch size selector
            Row(
              children: [
                const Text('Batch Size: '),
                DropdownButton<int>(
                  value: _batchSize,
                  items: [5, 10, 20, 50, 100].map((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text(value.toString()),
                    );
                  }).toList(),
                  onChanged: _isProcessing
                      ? null
                      : (int? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _batchSize = newValue;
                            });
                          }
                        },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Status and progress
            if (_statusMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(_statusMessage),
              ),

            if (_stats != null) ...[
              Text(
                  'Progress: ${_stats!.processed}/${_stats!.total} (${_stats!.successRate.toStringAsFixed(1)}%)'),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value:
                    _stats!.total > 0 ? _stats!.processed / _stats!.total : 0,
              ),
              const SizedBox(height: 16),
              Text('Successful links found: ${_stats!.successful}'),
              Text('Failed searches: ${_stats!.failed}'),
              Text('Skipped (already has link): ${_stats!.skipped}'),
              const SizedBox(height: 8),
              Text('API calls made: ${_stats!.apiCalls}'),
            ],

            // Controls
            const SizedBox(height: 24),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _isProcessing ? null : _startBackfill,
                  child: const Text('Start Processing'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isProcessing ? _pauseBackfill : null,
                  child: const Text('Pause'),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: _checkStats,
                  child: const Text('Check Status'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startBackfill() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Starting backfill process...';
    });

    try {
      await for (var stats
          in _controller.processBackfill(batchSize: _batchSize)) {
        if (mounted) {
          setState(() {
            _stats = stats;
            _statusMessage = 'Processing...';
          });
        }
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Backfill complete!';
        });
      }
    } catch (e) {
      log('Error during backfill: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _pauseBackfill() async {
    try {
      await _controller.pauseBackfill();
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Backfill paused. You can resume later.';
        });
      }
    } catch (e) {
      log('Error pausing backfill: $e');
    }
  }

  Future<void> _checkStats() async {
    setState(() {
      _statusMessage = 'Checking current status...';
    });

    try {
      final stats = await _controller.getCurrentStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _statusMessage = 'Status updated.';
        });
      }
    } catch (e) {
      log('Error checking stats: $e');
      if (mounted) {
        setState(() {
          _statusMessage = 'Error checking status: ${e.toString()}';
        });
      }
    }
  }
}
