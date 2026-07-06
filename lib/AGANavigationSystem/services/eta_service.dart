import 'dart:collection';

import '../config/navigation_config.dart';
import '../models/eta_result.dart';
import '../models/navigation_route.dart';
import '../models/route_match_result.dart';
import '../models/speed_sample.dart';

/// Blended ETA calculator using route, live speed, and progress sources.
class EtaService {
  final NavigationConfig config;
  final Queue<_ProgressPoint> _progress = Queue<_ProgressPoint>();
  Duration? _displayedEta;
  bool _forceNextEta = true;
  DateTime? _stoppedSince;

  EtaService({required this.config});

  void start() {
    _progress.clear();
    _displayedEta = null;
    _forceNextEta = true;
    _stoppedSince = null;
  }

  void resetAfterReroute() => start();

  EtaResult calculate({
    required NavigationRoute route,
    required RouteMatchResult match,
    required SpeedSample speed,
    required double gpsAccuracyMeters,
    required double distanceFromRouteMeters,
    bool forceAccept = false,
  }) {
    final now = DateTime.now();
    _progress.add(_ProgressPoint(match.traveledDistanceMeters, now));
    while (_progress.isNotEmpty &&
        now.difference(_progress.first.timestamp) >
            config.progressWindowDuration) {
      _progress.removeFirst();
    }

    final routeEta = _routeEta(route, match);
    final stopped =
        speed.smoothedSpeedMetersPerSecond <
        config.minimumEtaSpeedMetersPerSecond;
    if (stopped) {
      _stoppedSince ??= now;
    } else {
      _stoppedSince = null;
    }

    final adjustedRouteEta = stopped && _stoppedSince != null
        ? routeEta + now.difference(_stoppedSince!)
        : routeEta;
    final liveEta = _liveEta(match.remainingDistanceMeters, speed);
    final progressEta = _progressEta(match.remainingDistanceMeters, now);
    final estimates = <_WeightedEta>[];

    estimates.add(_WeightedEta(adjustedRouteEta, config.routeEtaWeight, 0.85));
    if (liveEta != null) {
      estimates.add(
        _WeightedEta(liveEta, config.liveSpeedEtaWeight, speed.confidence),
      );
    }
    if (progressEta != null) {
      estimates.add(_WeightedEta(progressEta, config.progressEtaWeight, 0.70));
    }

    if (stopped) {
      estimates.removeWhere((e) => e.eta == liveEta);
    }

    final activeWeight = estimates.fold<double>(0, (sum, e) => sum + e.weight);
    if (activeWeight <= 0) return EtaResult.unavailable;

    var rawMillis = 0.0;
    var confidence = 0.0;
    for (final estimate in estimates) {
      final normalized = estimate.weight / activeWeight;
      rawMillis += estimate.eta.inMilliseconds * normalized;
      confidence += estimate.confidence * normalized;
    }
    confidence *= _accuracyConfidence(gpsAccuracyMeters);
    confidence *= _routeMatchConfidence(distanceFromRouteMeters);
    confidence = confidence.clamp(0.0, 1.0);

    final raw = Duration(milliseconds: rawMillis.round());
    final displayed = _smooth(raw, forceAccept || _forceNextEta);
    _forceNextEta = false;

    return EtaResult(
      routeEta: adjustedRouteEta,
      liveSpeedEta: liveEta,
      progressEta: progressEta,
      rawEta: raw,
      displayedEta: displayed,
      confidence: confidence,
      source: estimates.length == 1 ? EtaSource.route : EtaSource.blended,
    );
  }

  Duration _routeEta(NavigationRoute route, RouteMatchResult match) {
    if (route.totalDistanceMeters <= 0) return Duration.zero;
    final ratio = (match.remainingDistanceMeters / route.totalDistanceMeters)
        .clamp(0.0, 1.0);
    return Duration(
      milliseconds: (route.originalDuration.inMilliseconds * ratio).round(),
    );
  }

  Duration? _liveEta(double remainingMeters, SpeedSample speed) {
    if (speed.source == SpeedSource.unavailable) return null;
    if (speed.confidence < 0.35) return null;
    final mps = speed.smoothedSpeedMetersPerSecond;
    if (mps < config.minimumEtaSpeedMetersPerSecond) return null;
    if (speed.confidence > 0 && speed.rawSpeedMetersPerSecond.isFinite) {
      return Duration(seconds: (remainingMeters / mps).round());
    }
    return null;
  }

  Duration? _progressEta(double remainingMeters, DateTime now) {
    if (_progress.length < 2) return null;
    final first = _progress.first;
    final last = _progress.last;
    final elapsed = last.timestamp.difference(first.timestamp);
    final distance = last.traveledMeters - first.traveledMeters;
    if (elapsed < config.minimumProgressSampleDuration) return null;
    if (distance < config.minimumProgressDistanceMeters) return null;
    final speed = distance / (elapsed.inMilliseconds / 1000.0);
    if (speed < config.minimumEtaSpeedMetersPerSecond) return null;
    return Duration(seconds: (remainingMeters / speed).round());
  }

  Duration _smooth(Duration raw, bool forceAccept) {
    final previous = _displayedEta;
    if (forceAccept || previous == null) {
      _displayedEta = raw;
      return raw;
    }
    final diff = (raw.inMilliseconds - previous.inMilliseconds).abs();
    if (diff > const Duration(minutes: 10).inMilliseconds) {
      _displayedEta = raw;
      return raw;
    }
    final smoothedMillis =
        config.etaSmoothingAlpha * raw.inMilliseconds +
        (1 - config.etaSmoothingAlpha) * previous.inMilliseconds;
    final delta = smoothedMillis - previous.inMilliseconds;
    final maxDelta = config.maximumNormalEtaChangePerUpdate.inMilliseconds;
    final limited = previous.inMilliseconds + delta.clamp(-maxDelta, maxDelta);
    _displayedEta = Duration(milliseconds: limited.round());
    return _displayedEta!;
  }

  double _accuracyConfidence(double accuracy) {
    return (1 - (accuracy / config.maximumLocationAccuracyMeters)).clamp(
      0.35,
      1.0,
    );
  }

  double _routeMatchConfidence(double offRouteMeters) {
    return (1 - (offRouteMeters / (config.offRouteThresholdMeters * 3))).clamp(
      0.2,
      1.0,
    );
  }
}

class _ProgressPoint {
  final double traveledMeters;
  final DateTime timestamp;
  const _ProgressPoint(this.traveledMeters, this.timestamp);
}

class _WeightedEta {
  final Duration eta;
  final double weight;
  final double confidence;
  const _WeightedEta(this.eta, this.weight, this.confidence);
}
