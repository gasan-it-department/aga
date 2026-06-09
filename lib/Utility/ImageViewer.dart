import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';

class ImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const ImageViewer({super.key, required this.imageUrls, required this.initialIndex});

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, TransformationController> _transformers = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _transformers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TransformationController _controllerFor(int index) {
    return _transformers.putIfAbsent(index, () => TransformationController());
  }

  void _onPageChanged(int index) {
    final prev = _currentIndex;
    setState(() => _currentIndex = index);
    final old = _transformers[prev];
    if (old != null) old.value = Matrix4.identity();
  }

  void _nextImage() {
    if (_currentIndex < widget.imageUrls.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _prevImage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  Widget _buildImage(String src) {
    if (src.startsWith('http')) {
      return Image.network(
        src,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        },
        errorBuilder: (_, __, ___) => _errorIcon(),
      );
    }
    final bytes = Utility.decodeHexImage(src);
    if (bytes == null) return _errorIcon();
    return Image.memory(bytes, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _errorIcon());
  }

  Widget _errorIcon() {
    return const Center(
      child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 32),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: widget.imageUrls.length,
            itemBuilder: (context, index) {
              final src = widget.imageUrls[index];
              return InteractiveViewer(
                transformationController: _controllerFor(index),
                minScale: 1.0,
                maxScale: 4.0,
                onInteractionEnd: (_) {
                  final ctrl = _transformers[index];
                  if (ctrl != null) {
                    final scale = ctrl.value.getMaxScaleOnAxis();
                    if (scale < 1.05) ctrl.value = Matrix4.identity();
                  }
                },
                child: Center(
                  child: Hero(
                    tag: 'hero_$src',
                    child: _buildImage(src),
                  ),
                ),
              );
            },
          ),
          if (widget.imageUrls.length > 1 && _currentIndex > 0)
            Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(left: 16.0), child: _buildNavButton(Icons.chevron_left_rounded, _prevImage))),
          if (widget.imageUrls.length > 1 && _currentIndex < widget.imageUrls.length - 1)
            Align(alignment: Alignment.centerRight, child: Padding(padding: const EdgeInsets.only(right: 16.0), child: _buildNavButton(Icons.chevron_right_rounded, _nextImage))),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                    child: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28), onPressed: () => Navigator.pop(context)),
                  ),
                  if (widget.imageUrls.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(20)),
                      child: Text("${_currentIndex + 1} / ${widget.imageUrls.length}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 1.0)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
