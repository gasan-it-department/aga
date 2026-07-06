/// ETA source used by the current result.
enum EtaSource { route, liveSpeed, progress, blended, fallback, unavailable }

/// ETA components and final displayed ETA.
class EtaResult {
  final Duration? routeEta;
  final Duration? liveSpeedEta;
  final Duration? progressEta;
  final Duration? rawEta;
  final Duration? displayedEta;
  final double confidence;
  final EtaSource source;

  const EtaResult({
    this.routeEta,
    this.liveSpeedEta,
    this.progressEta,
    this.rawEta,
    this.displayedEta,
    required this.confidence,
    required this.source,
  });

  static const unavailable = EtaResult(
    confidence: 0,
    source: EtaSource.unavailable,
  );
}
