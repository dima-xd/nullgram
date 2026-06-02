import 'package:flutter/material.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

/// A poll message: the question, each option with a result bar, and the total
/// vote count. Tapping an option submits a vote via [TDLibClient.setPollAnswer];
/// the updated results arrive live through `UpdateMessageContent`.
///
/// Single-answer voting only — once the user has voted (or the poll is closed),
/// results are shown and further taps are ignored.
class MessagePoll extends StatelessWidget {
  final Map<String, dynamic> poll;
  final int chatId;
  final int messageId;

  const MessagePoll({
    super.key,
    required this.poll,
    required this.chatId,
    required this.messageId,
  });

  /// Poll text fields are formatted text (`{text: ...}`) on newer TDLib but were
  /// plain strings historically; accept either.
  String _text(dynamic field) {
    if (field is Map) return field['text']?.toString() ?? '';
    return field?.toString() ?? '';
  }

  bool get _hasVoted {
    final options = poll['options'] as List? ?? const [];
    return options.any((o) => o['isChosen'] == true);
  }

  bool get _isClosed => poll['isClosed'] == true;

  bool get _showResults => _hasVoted || _isClosed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final options = poll['options'] as List? ?? const [];
    final totalVoters = poll['totalVoterCount'] as int? ?? 0;
    final isQuiz = poll['type']?['@type'] == 'PollTypeQuiz';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _text(poll['question']),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          isQuiz ? 'Quiz' : (poll['isAnonymous'] == true ? 'Anonymous Poll' : 'Poll'),
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < options.length; i++)
          _buildOption(context, options[i] as Map<String, dynamic>, i),
        const SizedBox(height: 4),
        Text(
          totalVoters == 1 ? '1 vote' : '$totalVoters votes',
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildOption(BuildContext context, Map<String, dynamic> option, int index) {
    final scheme = Theme.of(context).colorScheme;
    final isChosen = option['isChosen'] == true;
    final percentage = option['votePercentage'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: _showResults ? null : () => _vote(index),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _showResults
                    ? (isChosen ? Icons.check_circle : Icons.circle_outlined)
                    : Icons.radio_button_unchecked,
                size: 18,
                color: isChosen ? scheme.primary : scheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(_text(option['text']))),
                        if (_showResults)
                          Text(
                            '$percentage%',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                    if (_showResults) ...[
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percentage / 100,
                          minHeight: 4,
                          backgroundColor: scheme.surfaceContainerHighest,
                          color: isChosen ? scheme.primary : scheme.secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _vote(int optionId) {
    TDLibClient.setPollAnswer(
      chatId: chatId,
      messageId: messageId,
      optionIds: [optionId],
    );
  }
}
