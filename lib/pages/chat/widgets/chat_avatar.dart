import 'dart:io';
import 'package:flutter/material.dart';

class ChatAvatar extends StatelessWidget {
  final Map<String, dynamic> chat;
  final double radius;

  const ChatAvatar({
    super.key,
    required this.chat,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    if (chat['photo']?['small'] == null) {
      final firstLetter = chat['title']!.isNotEmpty ? chat['title']![0].toUpperCase() : '?';
      final colors = [
        Colors.red,
        Colors.orange,
        Colors.yellow,
        Colors.green,
        Colors.blue,
        Colors.indigo,
        Colors.purple,
      ];
      final color = colors[chat['id']!.abs() % colors.length];

      return CircleAvatar(
        radius: radius,
        backgroundColor: color,
        child: Text(
          firstLetter,
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.7,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final path = chat['photo']?['small']['local']['path'];
    if (path != null && path.isNotEmpty) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: FileImage(File(path)),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey,
      child: Icon(
        Icons.person,
        color: Colors.white,
        size: radius,
      ),
    );
  }
}
