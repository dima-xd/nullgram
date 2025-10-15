import 'dart:io';
import 'package:flutter/material.dart';

class ImageDetails extends StatelessWidget {
  final String photoPath;
  final List<int>? miniThumbnail;
  final String heroTag;

  const ImageDetails({
    super.key,
    required this.photoPath,
    this.miniThumbnail,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Hero(
                tag: heroTag,
                child: Image.file(
                  File(photoPath),
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
          SafeArea(
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
