import 'dart:math';
import 'package:flutter/material.dart';

class FloatingHeartParticle extends StatefulWidget {
  final VoidCallback onComplete;
  final Color color;

  const FloatingHeartParticle({
    super.key,
    required this.onComplete,
    required this.color,
  });

  @override
  State<FloatingHeartParticle> createState() => _FloatingHeartParticleState();
}

class _FloatingHeartParticleState extends State<FloatingHeartParticle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late double _randomXDrift;

  @override
  void initState() {
    super.initState();
    // Decide if it drifts left or right as it floats up
    _randomXDrift = (Random().nextDouble() - 0.5) * 60;

    _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1800) // Lifetime of the bubble
    );

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final double progress = _controller.value;

          // 🟢 THE FIX: We use 'bottom' now instead of 'top'.
          // 28px from bottom and 32px from right places it exactly behind the heart button!
          final double currentBottom = 28 + (progress * 100);
          final double currentRight = 32 + (progress * _randomXDrift);

          final double currentScale = 0.4 + (progress * 0.6);
          final double opacity = progress < 0.5 ? 1.0 : 1.0 - ((progress - 0.5) * 2);

          return Positioned(
            bottom: currentBottom,
            right: currentRight,
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: currentScale,
                child: Icon(Icons.favorite_rounded, color: widget.color.withValues(alpha: 0.8), size: 16),
              ),
            ),
          );
        }
    );
  }
}
