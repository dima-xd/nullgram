import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nullgram/pages/chat/utils/voice_recorder.dart';
import 'package:nullgram/pages/chat/widgets/bot_commands_sheet.dart';
import 'package:nullgram/pages/chat/widgets/emoji_panel.dart';
import 'package:nullgram/pages/home/widgets/chat_list_item.dart';
import 'package:nullgram/theme/motion.dart';
import 'package:nullgram/l10n/l10n.dart';

/// The message composer: text field, attachments, emoji panel and the
/// hold-to-record voice button.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.replyTo,
    required this.editing,
    required this.onSend,
    required this.onSendOptions,
    required this.onVoice,
    required this.chatId,
    required this.onSticker,
    required this.onGif,
    required this.onInlineGif,
    required this.onAttach,
    required this.onFormat,
    required this.onInsertLink,
    this.botCommands = const [],
    this.onBotCommand,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// The message being replied to, or null. Cleared by the preview's close
  /// button.
  final ValueNotifier<Map<String, dynamic>?> replyTo;

  /// The message being edited, or null.
  final ValueNotifier<Map<String, dynamic>?> editing;

  final VoidCallback onSend;

  /// Called when the send button is held, to offer silent and scheduled
  /// delivery.
  final VoidCallback onSendOptions;

  /// Called with a finished recording, or with null when it was cancelled or
  /// too short to send.
  final void Function(VoiceRecording? recording) onVoice;

  /// The chat being composed for, which the GIF search is scoped to.
  final int chatId;

  final void Function(int fileId) onSticker;

  /// Called with the file id of the saved GIF to send.
  final void Function(int fileId) onGif;

  /// Called with a GIF an inline bot returned, sent by query id.
  final void Function(int queryId, String resultId) onInlineGif;
  final VoidCallback onAttach;

  /// Wraps the current selection in MarkdownV2 markers.
  final void Function(String left, String right) onFormat;

  /// Prompts for a URL and wraps the selection in a markdown link.
  final VoidCallback onInsertLink;

  /// The `botCommand` objects the chat's bots advertise, empty when there are
  /// none. Drives the slash button, which is hidden while this is empty.
  final List<Map<String, dynamic>> botCommands;

  /// Called with a chosen command, slash included.
  final ValueChanged<String>? onBotCommand;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  /// How far left the finger must travel during a hold to cancel the note.
  static const double _cancelThreshold = 90;

  final VoiceRecorder _recorder = VoiceRecorder();
  final ValueNotifier<bool> _isRecording = ValueNotifier(false);
  final ValueNotifier<bool> _willCancel = ValueNotifier(false);
  final ValueNotifier<Duration> _elapsed = ValueNotifier(Duration.zero);
  final ValueNotifier<bool> _showEmoji = ValueNotifier(false);
  final ValueNotifier<String> _text = ValueNotifier('');

  Timer? _elapsedTimer;

  @override
  void initState() {
    super.initState();
    _text.value = widget.controller.text;
    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    _elapsedTimer?.cancel();
    _isRecording.dispose();
    _willCancel.dispose();
    _elapsed.dispose();
    _showEmoji.dispose();
    _text.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _onTextChanged() => _text.value = widget.controller.text;

  /// The emoji panel and the keyboard compete for the same space, so opening
  /// the keyboard closes the panel.
  void _onFocusChanged() {
    if (widget.focusNode.hasFocus) _showEmoji.value = false;
  }

  void _toggleEmoji() {
    if (_showEmoji.value) {
      _showEmoji.value = false;
      widget.focusNode.requestFocus();
      return;
    }
    widget.focusNode.unfocus();
    _showEmoji.value = true;
  }

  void _insertEmoji(String emoji) {
    final controller = widget.controller;
    final selection = controller.selection;
    final text = controller.text;
    // A field that never had focus reports an invalid selection; append then.
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;

    controller.value = TextEditingValue(
      text: text.replaceRange(start, end, emoji),
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  void _backspace() {
    final controller = widget.controller;
    final selection = controller.selection;
    final text = controller.text;
    if (text.isEmpty) return;

    if (selection.isValid && !selection.isCollapsed) {
      controller.value = TextEditingValue(
        text: text.replaceRange(selection.start, selection.end, ''),
        selection: TextSelection.collapsed(offset: selection.start),
      );
      return;
    }

    final caret = selection.isValid ? selection.start : text.length;
    if (caret == 0) return;
    // Step back over a surrogate pair as a unit, so deleting an emoji doesn't
    // leave half of it behind as a broken code unit.
    final lastUnit = text.codeUnitAt(caret - 1);
    final isLowSurrogate = lastUnit >= 0xDC00 && lastUnit <= 0xDFFF;
    final removed = (isLowSurrogate && caret >= 2) ? 2 : 1;
    controller.value = TextEditingValue(
      text: text.replaceRange(caret - removed, caret, ''),
      selection: TextSelection.collapsed(offset: caret - removed),
    );
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.microphonePermissionRequired)),
        );
      }
      return;
    }
    if (!await _recorder.start()) return;

    HapticFeedback.mediumImpact();
    _isRecording.value = true;
    _willCancel.value = false;
    _elapsed.value = Duration.zero;
    _elapsedTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _elapsed.value = _recorder.elapsed,
    );
  }

  Future<void> _finishRecording({required bool cancelled}) async {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    if (!_isRecording.value) return;
    _isRecording.value = false;

    if (cancelled) {
      await _recorder.cancel();
      widget.onVoice(null);
      return;
    }
    widget.onVoice(await _recorder.stop());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Everything below the message list has to clear the navigation bar: the
    // app draws edge to edge, and neither the composer nor the emoji panel
    // scrolls, so anything left under the bar would be unreachable.
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSize(
                  duration: Motion.fast,
                  curve: Motion.standard,
                  alignment: Alignment.topCenter,
                  child: _buildPendingPreview(),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: _isRecording,
                  builder: (context, isRecording, child) =>
                      isRecording ? _buildRecordingRow() : _buildComposerRow(),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _showEmoji,
            builder: (context, show, child) => AnimatedSize(
              duration: Motion.fast,
              curve: Motion.standard,
              alignment: Alignment.topCenter,
              child: show
                  ? EmojiPanel(
                      chatId: widget.chatId,
                      onEmoji: _insertEmoji,
                      onSticker: widget.onSticker,
                      onGif: widget.onGif,
                      onInlineGif: widget.onInlineGif,
                      onBackspace: _backspace,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  /// Offers the bot's commands and writes the chosen one into the field.
  ///
  /// The command is inserted rather than sent, because plenty of them take an
  /// argument and sending straight away would make those unusable.
  Future<void> _pickBotCommand() async {
    final command = await showBotCommandsSheet(
      context,
      commands: widget.botCommands,
    );
    if (command == null) return;

    widget.controller.text = command.endsWith(' ') ? command : '$command ';
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: widget.controller.text.length),
    );
    widget.focusNode.requestFocus();
    widget.onBotCommand?.call(command);
  }

  Widget _buildComposerRow() {
    return Row(
      children: [
        if (widget.botCommands.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.smart_toy_outlined),
            tooltip: context.l10n.botCommands,
            onPressed: _pickBotCommand,
          ),
        ValueListenableBuilder<bool>(
          valueListenable: _showEmoji,
          builder: (context, show, child) => IconButton(
            icon: Icon(
              show ? Icons.keyboard_outlined : Icons.emoji_emotions_outlined,
            ),
            tooltip: show ? 'Keyboard' : 'Emoji and stickers',
            onPressed: _toggleEmoji,
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    maxLines: 5,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    contextMenuBuilder: _contextMenu,
                    decoration: InputDecoration(
                      hintText: context.l10n.writeAMessage,
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: widget.onAttach,
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.attach_file, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
        ValueListenableBuilder<String>(
          valueListenable: _text,
          builder: (context, text, child) {
            // Non-empty text shows a send button; an empty field falls back to
            // the voice recorder. The two morph via an AnimatedSwitcher.
            return AnimatedSwitcher(
              duration: Motion.fast,
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: text.trim().isNotEmpty
                  ? GestureDetector(
                      key: const ValueKey('send'),
                      onLongPress: widget.onSendOptions,
                      child: IconButton.filled(
                        onPressed: widget.onSend,
                        tooltip: context.l10n.sendHoldForOptions,
                        icon: const Icon(Icons.send),
                      ),
                    )
                  : _buildRecordButton(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecordButton() {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      key: const ValueKey('record'),
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.holdToRecord),
          duration: Duration(seconds: 2),
        ),
      ),
      onLongPressStart: (_) => _startRecording(),
      onLongPressMoveUpdate: (details) {
        _willCancel.value = details.localOffsetFromOrigin.dx < -_cancelThreshold;
      },
      onLongPressEnd: (_) => _finishRecording(cancelled: _willCancel.value),
      onLongPressCancel: () => _finishRecording(cancelled: true),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: scheme.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.mic_none, color: scheme.onPrimary),
      ),
    );
  }

  /// The row shown in place of the composer while recording: a timer, a live
  /// hint about the slide-to-cancel gesture, and the pulsing microphone.
  Widget _buildRecordingRow() {
    final scheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<bool>(
      valueListenable: _willCancel,
      builder: (context, willCancel, child) {
        return Row(
          children: [
            const SizedBox(width: 12),
            Icon(Icons.fiber_manual_record, size: 14, color: scheme.error),
            const SizedBox(width: 12),
            ValueListenableBuilder<Duration>(
              valueListenable: _elapsed,
              builder: (context, elapsed, child) => Text(
                _formatElapsed(elapsed),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  willCancel ? 'Release to cancel' : '‹ Slide to cancel',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: willCancel
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: willCancel ? scheme.error : scheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                willCancel ? Icons.delete_outline : Icons.mic,
                color: willCancel ? scheme.onError : scheme.onPrimary,
              ),
            ),
          ],
        );
      },
    );
  }

  static String _formatElapsed(Duration elapsed) {
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// The edit or reply preview above the composer, whichever is pending.
  Widget _buildPendingPreview() {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: widget.editing,
      builder: (context, editing, child) {
        if (editing != null) {
          return _PendingPreview(
            icon: Icons.edit,
            label: context.l10n.editMessage,
            preview: messagePreviewText(editing),
            onClose: () {
              widget.editing.value = null;
              widget.controller.clear();
            },
          );
        }
        return ValueListenableBuilder<Map<String, dynamic>?>(
          valueListenable: widget.replyTo,
          builder: (context, replyTo, child) {
            if (replyTo == null) return const SizedBox.shrink();
            return _PendingPreview(
              icon: Icons.reply,
              label: context.l10n.reply,
              preview: messagePreviewText(replyTo),
              onClose: () => widget.replyTo.value = null,
            );
          },
        );
      },
    );
  }

  /// Builds the composer's text-selection menu: a single compact, horizontally
  /// scrolling bar (Telegram-style) with copy/paste plus formatting actions
  /// that wrap the selection with MarkdownV2 markers.
  ///
  /// A custom bar is used instead of [AdaptiveTextSelectionToolbar] because the
  /// platform toolbar overflows its many items into a vertical menu that can
  /// exceed the screen height and crash during layout.
  Widget _contextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    final selection = widget.controller.selection;
    final hasSelection = selection.isValid && !selection.isCollapsed;

    void act(VoidCallback apply) {
      editableTextState.hideToolbar();
      apply();
    }

    final items = <_SelectionAction>[
      if (hasSelection)
        _SelectionAction(
          'Copy',
          () => act(
            () => editableTextState.copySelection(SelectionChangedCause.toolbar),
          ),
        ),
      _SelectionAction(
        'Paste',
        () => act(
          () => editableTextState.pasteText(SelectionChangedCause.toolbar),
        ),
      ),
      if (hasSelection) ...[
        _SelectionAction('Bold', () => act(() => widget.onFormat('*', '*'))),
        _SelectionAction('Italic', () => act(() => widget.onFormat('_', '_'))),
        _SelectionAction(
          'Underline',
          () => act(() => widget.onFormat('__', '__')),
        ),
        _SelectionAction('Strike', () => act(() => widget.onFormat('~', '~'))),
        _SelectionAction('Mono', () => act(() => widget.onFormat('`', '`'))),
        _SelectionAction('Link', () => act(widget.onInsertLink)),
      ],
    ];

    return _SelectionFormatBar(
      anchor: editableTextState.contextMenuAnchors.primaryAnchor,
      topInset: MediaQuery.of(context).padding.top,
      items: items,
    );
  }
}

/// A compact preview of the message being replied to or edited.
class _PendingPreview extends StatelessWidget {
  const _PendingPreview({
    required this.icon,
    required this.label,
    required this.preview,
    required this.onClose,
  });

  final IconData icon;
  final String label;
  final String preview;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            iconSize: 20,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// A labelled action in the composer's selection bar.
class _SelectionAction {
  final String label;
  final VoidCallback onPressed;

  const _SelectionAction(this.label, this.onPressed);
}

/// A compact selection toolbar anchored just above the text selection, with its
/// actions in a single horizontally scrolling row so it never overflows.
class _SelectionFormatBar extends StatelessWidget {
  final Offset anchor;
  final double topInset;
  final List<_SelectionAction> items;

  const _SelectionFormatBar({
    required this.anchor,
    required this.topInset,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top =
        (anchor.dy - 54).clamp(topInset + 8, MediaQuery.of(context).size.height);

    return Stack(
      children: [
        Positioned(
          left: 8,
          right: 8,
          top: top,
          child: Center(
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(8),
              color: theme.colorScheme.surfaceContainerHighest,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final item in items)
                      TextButton(
                        onPressed: item.onPressed,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: theme.colorScheme.onSurface,
                        ),
                        child: Text(item.label),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
