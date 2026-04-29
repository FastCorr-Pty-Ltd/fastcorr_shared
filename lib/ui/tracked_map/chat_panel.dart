import 'dart:developer' as developer;

import 'package:fastcorr_shared/models/chat_msg_model.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

/// Lightweight chat panel for the tracking screen.
///
/// Displays messages from a [Stream<List<ChatMsgModel>>] (typically the
/// per-app `ChatService.getChatStream`) and routes outgoing text through
/// the [onSend] callback. The chat infrastructure itself stays per-app —
/// this widget only renders.
///
/// `senderRole` / `senderName` describe the *current* user so the bubble
/// alignment is correct. Messages whose [ChatMsgModel.senderRole] equals
/// [currentUserRole] are right-aligned.
class ChatPanel extends StatefulWidget {
  const ChatPanel({
    super.key,
    required this.messages,
    required this.currentUserRole,
    required this.currentUserName,
    required this.onSend,
    this.title,
    this.composerHint = 'Type a message…',
  });

  final Stream<List<ChatMsgModel>> messages;
  final SenderRole currentUserRole;
  final String currentUserName;

  /// Called with the trimmed text the user typed. Should resolve when the
  /// message has been persisted (errors are caller's responsibility).
  final Future<void> Function(String text) onSend;

  /// Optional header shown above the message list (e.g. "Driver chat").
  final String? title;
  final String composerHint;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.onSend(text);
      _controller.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        if (widget.title != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Text(
              widget.title!,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        Expanded(
          child: StreamBuilder<List<ChatMsgModel>>(
            stream: widget.messages,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                final err = snapshot.error;
                developer.log(
                  'ChatPanel stream error: $err',
                  name: 'OrderChat',
                  error: err,
                  stackTrace: snapshot.stackTrace,
                );
                final detail = err is FirebaseException
                    ? '${err.code}: ${err.message ?? err.toString()}'
                    : err.toString();
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      'Could not load messages.\n$detail',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final msgs = snapshot.data ?? const <ChatMsgModel>[];
              if (msgs.isEmpty) {
                return Center(
                  child: Text(
                    'No messages yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                );
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemCount: msgs.length,
                itemBuilder: (context, index) {
                  final m = msgs[index];
                  final isMine = m.senderRole == widget.currentUserRole;
                  return _Bubble(message: m, isMine: isMine);
                },
              );
            },
          ),
        ),
        _Composer(
          controller: _controller,
          hint: widget.composerHint,
          sending: _sending,
          onSend: _handleSend,
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.isMine});

  final ChatMsgModel message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final txt = theme.textTheme;

    final bubbleColor = isMine
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest;
    final textColor = isMine ? colorScheme.onPrimary : colorScheme.onSurface;
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(12),
      topRight: const Radius.circular(12),
      bottomLeft: Radius.circular(isMine ? 12 : 2),
      bottomRight: Radius.circular(isMine ? 2 : 12),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (!isMine)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: Text(
                message.senderName,
                style: txt.labelSmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: bubbleColor, borderRadius: radius),
              child: Text(
                message.content,
                style: txt.bodyMedium?.copyWith(color: textColor),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(
              _formatTime(message.createdAt),
              style: txt.labelSmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.hint,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final String hint;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: sending ? null : (_) => onSend(),
              decoration: InputDecoration(
                hintText: hint,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send, size: 18),
            tooltip: 'Send',
          ),
        ],
      ),
    );
  }
}
