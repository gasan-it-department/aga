import 'package:flutter/material.dart';

import '../models/navigation_state.dart';

/// Lightweight route preview widget.
///
/// The navigation core works without a map. This widget intentionally avoids
/// Google Maps. Replace this with a MapLibre-backed renderer later if desired.
class AgaNavigationMap extends StatelessWidget {
  final NavigationState navigationState;
  final String? mapStyleUrl;
  final bool followUser;

  const AgaNavigationMap({
    super.key,
    required this.navigationState,
    this.mapStyleUrl,
    this.followUser = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _NavigationPreviewPainter(navigationState),
      child: const SizedBox.expand(),
    );
  }
}

class _NavigationPreviewPainter extends CustomPainter {
  final NavigationState state;

  _NavigationPreviewPainter(this.state);

  @override
  void paint(Canvas canvas, Size size) {
    final route = state.currentRoute;
    final geometry = route?.geometry ?? const [];
    final bg = Paint()..color = const Color(0xFFEFF6FF);
    canvas.drawRect(Offset.zero & size, bg);
    if (geometry.length < 2) return;

    final minLat = geometry
        .map((c) => c.latitude)
        .reduce((a, b) => a < b ? a : b);
    final maxLat = geometry
        .map((c) => c.latitude)
        .reduce((a, b) => a > b ? a : b);
    final minLon = geometry
        .map((c) => c.longitude)
        .reduce((a, b) => a < b ? a : b);
    final maxLon = geometry
        .map((c) => c.longitude)
        .reduce((a, b) => a > b ? a : b);
    final latSpan = (maxLat - minLat).abs() == 0 ? 1.0 : maxLat - minLat;
    final lonSpan = (maxLon - minLon).abs() == 0 ? 1.0 : maxLon - minLon;

    Offset project(double lat, double lon) {
      final x = ((lon - minLon) / lonSpan) * (size.width - 32) + 16;
      final y =
          size.height - (((lat - minLat) / latSpan) * (size.height - 32) + 16);
      return Offset(x, y);
    }

    final path = Path()
      ..moveTo(
        project(geometry.first.latitude, geometry.first.longitude).dx,
        project(geometry.first.latitude, geometry.first.longitude).dy,
      );
    for (final point in geometry.skip(1)) {
      final p = project(point.latitude, point.longitude);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF2563EB)
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    final current = state.currentCoordinate;
    final destination = state.destination;
    if (destination != null) {
      canvas.drawCircle(
        project(destination.latitude, destination.longitude),
        7,
        Paint()..color = const Color(0xFFDC2626),
      );
    }
    if (current != null) {
      canvas.drawCircle(
        project(current.latitude, current.longitude),
        7,
        Paint()..color = const Color(0xFF059669),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NavigationPreviewPainter oldDelegate) {
    return oldDelegate.state != state;
  }
}
