import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:quest_cards/src/services/game_system_client_service.dart';

/// Widget for reporting incorrect game system mappings
class GameSystemFeedbackWidget extends StatefulWidget {
  /// ID of the quest card
  final String questId;

  /// Original game system name
  final String originalSystem;

  /// Current standardized game system name (if any)
  final String? standardizedSystem;

  const GameSystemFeedbackWidget({
    super.key,
    required this.questId,
    required this.originalSystem,
    this.standardizedSystem,
  });

  @override
  State<GameSystemFeedbackWidget> createState() =>
      _GameSystemFeedbackWidgetState();
}

class _GameSystemFeedbackWidgetState extends State<GameSystemFeedbackWidget> {
  final GameSystemClientService _gameSystemService = GameSystemClientService();
  List<StandardGameSystemOption> _options = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _showFeedbackForm = false;
  bool _submissionComplete = false;
  String? _selectedSystem;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadGameSystems();
  }

  /// Load all available game systems for the dropdown
  Future<void> _loadGameSystems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final options = await _gameSystemService.getGameSystemOptions();
      setState(() {
        _options = options;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load game systems: $e';
        _isLoading = false;
      });
    }
  }

  /// Submit feedback about an incorrect mapping
  Future<void> _submitFeedback() async {
    if (_selectedSystem == null) {
      setState(() {
        _errorMessage = 'Please select a game system';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // Call the Cloud Function to report the incorrect mapping
      final result = await FirebaseFunctions.instance
          .httpsCallable('report_incorrect_mapping')
          .call({
        'questId': widget.questId,
        'originalSystem': widget.originalSystem,
        'currentStandardizedSystem': widget.standardizedSystem,
        'suggestedSystem': _selectedSystem,
      });

      if (result.data['success'] == true) {
        setState(() {
          _submissionComplete = true;
          _isSubmitting = false;
        });
      } else {
        setState(() {
          _errorMessage = result.data['error'] ?? 'Failed to submit feedback';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If no standardized system yet, don't show the widget
    if (widget.standardizedSystem == null) {
      return const SizedBox.shrink();
    }

    // If submission is complete, show thank you message
    if (_submissionComplete) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'Thank you for your feedback!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Your input helps improve the game system standardization for everyone.',
                style: TextStyle(
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // If the feedback form is not expanded, show just the button
    if (!_showFeedbackForm) {
      return TextButton.icon(
        icon: Icon(Icons.feedback_outlined),
        label: Text('Report incorrect game system mapping'),
        onPressed: () {
          setState(() {
            _showFeedbackForm = true;
          });
        },
        style: TextButton.styleFrom(
          foregroundColor: Colors.blue[700],
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(vertical: 8.0),
        ),
      );
    }

    // Show the expanded feedback form
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report Incorrect Game System Mapping',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 16),
            Text('Original: ${widget.originalSystem}'),
            Text('Currently mapped to: ${widget.standardizedSystem}'),
            SizedBox(height: 16),
            Text('What is the correct game system?'),
            SizedBox(height: 8),
            _isLoading
                ? CircularProgressIndicator()
                : DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    hint: Text('Select the correct game system'),
                    value: _selectedSystem,
                    items: _options.map((option) {
                      return DropdownMenuItem<String>(
                        value: option.isStandardized
                            ? option.value
                            : option.standardSystem,
                        child: Text(
                          option.displayText,
                          overflow: TextOverflow.ellipsis,
                          style: option.isStandardized
                              ? TextStyle(fontWeight: FontWeight.bold)
                              : null,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSystem = value;
                        _errorMessage = null;
                      });
                    },
                  ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red),
                ),
              ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          setState(() {
                            _showFeedbackForm = false;
                            _selectedSystem = null;
                            _errorMessage = null;
                          });
                        },
                  child: Text('Cancel'),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitFeedback,
                  child: _isSubmitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('Submit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
