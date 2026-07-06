import 'package:flutter/material.dart';

import '../models/navigation_state.dart';
import '../utils/navigation_formatters.dart';

/// Compact navigation status panel.
class AgaNavigationStatus extends StatelessWidget {
  final NavigationState state;

  const AgaNavigationStatus({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final eta = state.etaResult;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                state.status == NavigationStatus.arrived
                    ? Icons.flag_rounded
                    : state.isRerouting
                    ? Icons.sync_rounded
                    : Icons.navigation_rounded,
                color: const Color(0xFF2563EB),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  NavigationFormatters.status(state.status),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(NavigationFormatters.progress(state.progress)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _item('ETA', NavigationFormatters.duration(eta.displayedEta)),
              _item(
                'Arrive',
                NavigationFormatters.arrivalTime(state.estimatedArrivalTime),
              ),
              _item(
                'Left',
                NavigationFormatters.distance(
                  state.remainingRouteDistanceMeters,
                ),
              ),
              _item(
                'Speed',
                NavigationFormatters.speedKph(
                  state.smoothedSpeedMetersPerSecond,
                ),
              ),
              _item(
                'GPS',
                NavigationFormatters.accuracy(state.gpsAccuracyMeters),
              ),
              _item(
                'ETA confidence',
                NavigationFormatters.confidence(eta.confidence),
              ),
            ],
          ),
          if (state.isOffRoute || state.errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              state.errorMessage ??
                  (state.isOffRoute ? 'Off route. Rerouting may start.' : ''),
              style: const TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _item(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}
