import 'package:flutter/material.dart';

class RippleAlertIcon extends StatefulWidget {
  final Color color;
  final IconData icon;

  const RippleAlertIcon({super.key, required this.color, required this.icon});

  @override
  State<RippleAlertIcon> createState() => _RippleAlertIconState();
}

class _RippleAlertIconState extends State<RippleAlertIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double scale = 1.0 + (_controller.value * 1.5);
            final double opacity = 1.0 - _controller.value;

            return Transform.scale(
              scale: scale,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withValues(alpha: opacity),
                    width: 2,
                  ),
                  color: widget.color.withValues(alpha: opacity * 0.4),
                ),
              ),
            );
          },
        ),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Icon(widget.icon, color: Colors.white, size: 16),
        ),
      ],
    );
  }
}
