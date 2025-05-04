import 'package:flutter/material.dart';
import 'dart:developer' as developer;

/// A widget to collect user feedback on game system standardization.
class GameSystemFeedbackWidget extends StatefulWidget {
  final String questId;
  final String? originalSystem;
  final String? standardizedSystem;

  const GameSystemFeedbackWidget({
    super.key,
    required this.questId,
    this.originalSystem,
    this.standardizedSystem,
  });

  @override
  State<GameSystemFeedbackWidget> createState() =>
      _GameSystemFeedbackWidgetState();
}

class _GameSystemFeedbackWidgetState extends State<GameSystemFeedbackWidget> {
  bool _feedbackSubmitted = false;
  bool _isLoading = false;

  // Function to submit feedback (initially just logs, can be expanded)
  Future<void> _submitFeedback(bool isCorrect) async {
    if (_feedbackSubmitted || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Log feedback details
      developer.log(
          'Game System Feedback Submitted: '
          'QuestID=${widget.questId}, '
          'Original=${widget.originalSystem}, '
          'Standardized=${widget.standardizedSystem}, '
          'UserReportedCorrect=$isCorrect',
          name: 'GameSystemFeedback');

      // --- Optional: Store feedback in Firestore ---
      /*
      await FirebaseFirestore.instance.collection('game_system_feedback').add({
        'questId': widget.questId,
        'originalSystem': widget.originalSystem,
        'standardizedSystem': widget.standardizedSystem,
        'isCorrect': isCorrect,
        'timestamp': FieldValue.serverTimestamp(),
        // 'userId': FirebaseAuth.instance.currentUser?.uid, // If auth is available
      });
      */
      // --- End Optional Firestore ---

      setState(() {
        _feedbackSubmitted = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback!')),
        );
      }
    } catch (e) {
      developer.log('Error submitting feedback: $e',
          name: 'GameSystemFeedback', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting feedback: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show if no standardization has occurred or original is missing
    if (widget.standardizedSystem == null ||
        widget.originalSystem == null ||
        widget.originalSystem == widget.standardizedSystem) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 1,
      color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Game System Mapping',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
                children: [
                  const TextSpan(text: 'We mapped the original system '),
                  TextSpan(
                    text: '"${widget.originalSystem}"',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                  const TextSpan(text: ' to '),
                  TextSpan(
                    text: '"${widget.standardizedSystem}"',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: '. Is this correct?'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_feedbackSubmitted)
              const Center(
                child: Text(
                  'Feedback received. Thank you!',
                  style: TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold),
                ),
              )
            else if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Yes, Correct'),
                    onPressed: () => _submitFeedback(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('No, Incorrect'),
                    onPressed: () => _submitFeedback(false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
