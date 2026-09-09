import 'package:flutter/material.dart';

/// A poll the user filled in and wants to send.
typedef PollDraft = ({
  String question,
  List<String> options,
  bool isAnonymous,
  bool allowMultipleAnswers,
});

/// Collects a new poll, resolving to its draft or null when cancelled.
Future<PollDraft?> showPollComposer(BuildContext context) {
  return showModalBottomSheet<PollDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => const _PollComposer(),
  );
}

class _PollComposer extends StatefulWidget {
  const _PollComposer();

  @override
  State<_PollComposer> createState() => _PollComposerState();
}

class _PollComposerState extends State<_PollComposer> {
  /// Telegram allows up to ten answers.
  static const int _maxOptions = 10;

  final TextEditingController _question = TextEditingController();
  final List<TextEditingController> _options = [
    TextEditingController(),
    TextEditingController(),
  ];

  bool _isAnonymous = true;
  bool _allowMultipleAnswers = false;

  @override
  void dispose() {
    _question.dispose();
    for (final option in _options) {
      option.dispose();
    }
    super.dispose();
  }

  /// Whether the poll has a question and at least two filled-in answers.
  bool get _isValid =>
      _question.text.trim().isNotEmpty && _filledOptions.length >= 2;

  List<String> get _filledOptions => [
        for (final option in _options)
          if (option.text.trim().isNotEmpty) option.text.trim(),
      ];

  void _addOption() {
    if (_options.length >= _maxOptions) return;
    setState(() => _options.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_options.length <= 2) return;
    setState(() => _options.removeAt(index).dispose());
  }

  void _submit() {
    Navigator.pop(context, (
      question: _question.text.trim(),
      options: _filledOptions,
      isAnonymous: _isAnonymous,
      allowMultipleAnswers: _allowMultipleAnswers,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lift the sheet above the keyboard so the field being typed in stays
      // visible.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text('New poll', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _question,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Question',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          for (final (index, option) in _options.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: option,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Answer ${index + 1}',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: 'Remove',
                    onPressed:
                        _options.length <= 2 ? null : () => _removeOption(index),
                  ),
                ],
              ),
            ),
          if (_options.length < _maxOptions)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addOption,
                icon: const Icon(Icons.add),
                label: const Text('Add an answer'),
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Anonymous voting'),
            value: _isAnonymous,
            onChanged: (value) => setState(() => _isAnonymous = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Multiple answers'),
            value: _allowMultipleAnswers,
            onChanged: (value) =>
                setState(() => _allowMultipleAnswers = value),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _isValid ? _submit : null,
            child: const Text('Create poll'),
          ),
        ],
      ),
    );
  }
}
