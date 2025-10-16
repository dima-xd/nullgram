import 'dart:io';
import 'package:flutter/material.dart';

class ImageDetails extends StatefulWidget {
  final List<String> photoPaths;
  final int initialIndex;
  final String heroTag;

  const ImageDetails({
    super.key,
    required this.photoPaths,
    this.initialIndex = 0,
    required this.heroTag,
  });

  @override
  State<ImageDetails> createState() => _ImageDetailsState();
}

class _ImageDetailsState extends State<ImageDetails> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (page != _currentIndex) {
        setState(() {
          _currentIndex = page;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.photoPaths.length,
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Hero(
                    tag: index == widget.initialIndex ? widget.heroTag : 'photo_$index',
                    child: Image.file(
                      File(widget.photoPaths[index]),
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    if (widget.photoPaths.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${_currentIndex + 1}/${widget.photoPaths.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(width: 48),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
