import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:quest_cards/src/services/game_system_client_service.dart';

/// A specialized autocomplete field for game systems that supports standardization
class GameSystemAutocompleteField extends StatefulWidget {
  /// Initial value for the field
  final String? initialValue;

  /// Callback when the value changes
  final void Function(String value, String? standardizedValue) onChanged;

  /// Whether the field is required
  final bool isRequired;

  /// Custom decoration for the field
  final InputDecoration? decoration;

  const GameSystemAutocompleteField({
    super.key,
    this.initialValue,
    required this.onChanged,
    this.isRequired = false,
    this.decoration,
  });

  @override
  State<GameSystemAutocompleteField> createState() =>
      _GameSystemAutocompleteFieldState();
}

class _GameSystemAutocompleteFieldState
    extends State<GameSystemAutocompleteField> {
  final GameSystemClientService _gameSystemService = GameSystemClientService();
  final TextEditingController _controller = TextEditingController();
  List<StandardGameSystemOption> _options = [];
  bool _isLoading = true;
  String? _standardizedValue;

  @override
  void initState() {
    super.initState();

    // Set initial value if provided
    if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
      _controller.text = widget.initialValue!;

      // Find standardized value for initial value
      _findStandardizedGameSystem(widget.initialValue!);
    }

    // Load options for autocomplete
    _loadGameSystemOptions();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Load all available game system options
  Future<void> _loadGameSystemOptions() async {
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
      debugPrint('Error loading game system options: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Find the standardized game system for a given input
  Future<void> _findStandardizedGameSystem(String value) async {
    // Immediately notify parent of the raw typed value so forms can save it
    // even if async lookup hasn't completed yet.
    if (value.isEmpty) {
      setState(() {
        _standardizedValue = null;
      });
      widget.onChanged(value, _standardizedValue);
      return;
    }

    // Notify parent immediately about the typed value (standardized may update later)
    widget.onChanged(value, _standardizedValue);

    // Check if the value matches any option
    for (var option in _options) {
      if (option.value.toLowerCase() == value.toLowerCase()) {
        final standardValue =
            option.isStandardized ? option.value : option.standardSystem;

        setState(() {
          _standardizedValue = standardValue;
        });

        // Notify parent of changes
        widget.onChanged(value, standardValue);
        return;
      }
    }

    // If not found in options, query the service
    final standardSystem = await _gameSystemService.findStandardizedName(value);

    setState(() {
      _standardizedValue = standardSystem;
    });

    // Notify parent of finalized standardized value
    widget.onChanged(value, standardSystem);
  }

  @override
  Widget build(BuildContext context) {
    final decoration = widget.decoration ??
        InputDecoration(
          labelText: 'Game System',
          border: OutlineInputBorder(),
          helperText: _standardizedValue != null
              ? 'Will be standardized as: $_standardizedValue'
              : null,
          helperStyle: TextStyle(
            color: Colors.blue[700],
            fontStyle: FontStyle.italic,
          ),
          suffixIcon: _standardizedValue != null
              ? Icon(Icons.check_circle, color: Colors.green)
              : null,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TypeAheadField<StandardGameSystemOption>(
          controller: _controller,
          builder: (context, controller, focusNode) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: decoration,
              onChanged: (value) => _findStandardizedGameSystem(value),
              validator: widget.isRequired
                  ? (value) => (value == null || value.isEmpty)
                      ? 'Please enter a game system'
                      : null
                  : null,
            );
          },
          suggestionsCallback: (pattern) {
            return _options
                .where((option) => option.displayText
                    .toLowerCase()
                    .contains(pattern.toLowerCase()))
                .toList();
          },
          itemBuilder: (context, suggestion) {
            return ListTile(
              title: Text(
                suggestion.displayText,
              ),
            );
          },
          onSelected: (suggestion) {
            _controller.text = suggestion.value;
            _standardizedValue = suggestion.isStandardized
                ? suggestion.value
                : suggestion.standardSystem;
            widget.onChanged(suggestion.value, _standardizedValue);
          },
        ),
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Loading game systems...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
