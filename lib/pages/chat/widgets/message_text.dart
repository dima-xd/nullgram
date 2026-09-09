import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:nullgram/services/link_resolver.dart';
import 'package:nullgram/theme/app_theme.dart';

/// Renders a TDLib `formattedText` map (`{text, entities}`) with its rich-text
/// entities applied: bold, italic, underline, strikethrough, monospace,
/// tap-to-reveal spoilers and tappable links, mentions and hashtags.
class MessageText extends StatefulWidget {
  final Map<String, dynamic> content;

  const MessageText({
    super.key,
    required this.content,
  });

  @override
  State<MessageText> createState() => _MessageTextState();
}

class _MessageTextState extends State<MessageText> {
  final List<TapGestureRecognizer> _recognizers = [];

  /// Character offsets of spoilers the reader has revealed.
  final Set<int> _revealedSpoilers = {};

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.content['text']?.toString() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final baseStyle = (theme.textTheme.bodyLarge ?? const TextStyle())
        .copyWith(color: theme.colorScheme.onSurface);

    final entities = widget.content['entities'] as List? ?? const [];
    if (entities.isEmpty) {
      return Text(text, style: baseStyle);
    }

    _disposeRecognizers();
    final spans = _buildSpans(
      text: text,
      entities: entities,
      baseStyle: baseStyle,
      linkColor: context.chatColors.bubbleLink,
      codeBackground: context.chatColors.codeBackground,
    );
    return Text.rich(TextSpan(children: spans));
  }

  /// Splits [text] at every entity boundary and emits one [TextSpan] per
  /// segment, merging the styles of all entities that cover it so overlapping
  /// formatting (e.g. bold + italic) combines correctly.
  List<InlineSpan> _buildSpans({
    required String text,
    required List entities,
    required TextStyle baseStyle,
    required Color linkColor,
    required Color codeBackground,
  }) {
    final boundaries = <int>{0, text.length};
    for (final entity in entities) {
      final offset = entity['offset'] as int? ?? 0;
      final length = entity['length'] as int? ?? 0;
      boundaries.add(offset.clamp(0, text.length));
      boundaries.add((offset + length).clamp(0, text.length));
    }
    final points = boundaries.toList()..sort();

    final spans = <InlineSpan>[];
    for (var i = 0; i < points.length - 1; i++) {
      final start = points[i];
      final end = points[i + 1];
      if (start >= end) continue;

      var style = baseStyle;
      var underline = false;
      var strike = false;
      String? linkTarget;
      String? mention;
      int? spoilerStart;

      for (final entity in entities) {
        final offset = entity['offset'] as int? ?? 0;
        final length = entity['length'] as int? ?? 0;
        if (offset > start || offset + length < end) continue;

        final type = entity['type'] as Map<String, dynamic>?;
        switch (type?['@type']) {
          case 'TextEntityTypeBold':
            style = style.copyWith(fontWeight: FontWeight.w700);
          case 'TextEntityTypeItalic':
            style = style.copyWith(fontStyle: FontStyle.italic);
          case 'TextEntityTypeUnderline':
            underline = true;
          case 'TextEntityTypeStrikethrough':
            strike = true;
          case 'TextEntityTypeCode':
          case 'TextEntityTypePre':
          case 'TextEntityTypePreCode':
            style = style.copyWith(
              fontFamily: 'monospace',
              backgroundColor: codeBackground,
            );
          case 'TextEntityTypeSpoiler':
            spoilerStart = offset;
          case 'TextEntityTypeTextUrl':
            linkTarget = type?['url'] as String?;
            style = style.copyWith(color: linkColor);
          case 'TextEntityTypeUrl':
          case 'TextEntityTypeEmailAddress':
          case 'TextEntityTypePhoneNumber':
            linkTarget = text.substring(start, end);
            style = style.copyWith(color: linkColor);
          case 'TextEntityTypeMention':
            mention = text.substring(start, end);
            style = style.copyWith(color: linkColor);
          case 'TextEntityTypeMentionName':
            style = style.copyWith(color: linkColor);
          case 'TextEntityTypeHashtag':
          case 'TextEntityTypeCashtag':
          case 'TextEntityTypeBotCommand':
            style = style.copyWith(color: linkColor);
        }
      }

      if (underline || strike) {
        style = style.copyWith(
          decoration: TextDecoration.combine([
            if (underline) TextDecoration.underline,
            if (strike) TextDecoration.lineThrough,
          ]),
        );
      }

      // A hidden spoiler paints its text in its own background colour, so the
      // characters occupy the right space but can't be read until tapped.
      final isHiddenSpoiler =
          spoilerStart != null && !_revealedSpoilers.contains(spoilerStart);
      if (isHiddenSpoiler) {
        final cover = Theme.of(context).colorScheme.onSurfaceVariant;
        style = style.copyWith(
          color: cover,
          backgroundColor: cover,
          decoration: TextDecoration.none,
        );
      }

      final recognizer = _recognizerFor(
        isHiddenSpoiler: isHiddenSpoiler,
        spoilerStart: spoilerStart,
        linkTarget: linkTarget,
        mention: mention,
      );

      spans.add(TextSpan(
        text: text.substring(start, end),
        style: style,
        recognizer: recognizer,
      ));
    }
    return spans;
  }

  /// The tap handler for a span, if it has one. A hidden spoiler takes
  /// precedence over its link, so the first tap always reveals the text.
  TapGestureRecognizer? _recognizerFor({
    required bool isHiddenSpoiler,
    required int? spoilerStart,
    required String? linkTarget,
    required String? mention,
  }) {
    void Function()? onTap;

    if (isHiddenSpoiler) {
      final offset = spoilerStart!;
      onTap = () => setState(() => _revealedSpoilers.add(offset));
    } else if (linkTarget != null) {
      final target = linkTarget;
      onTap = () => openLink(context, target);
    } else if (mention != null) {
      final username = mention;
      onTap = () => openUsername(context, username);
    }

    if (onTap == null) return null;
    final recognizer = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(recognizer);
    return recognizer;
  }
}
