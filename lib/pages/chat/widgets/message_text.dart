import 'package:flutter/material.dart';

class MessageText extends StatelessWidget {
  final Map<String, dynamic> content;

  const MessageText({
    super.key,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final text = content['text'] ?? '';

    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 15,
      ),
    );
  }
}
