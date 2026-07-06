/// Runtime configuration for AGA navigation.
class NavigationConfig {
  final String osrmBaseUrl;
  final Duration desiredLocationInterval;
  final Duration staleLocationThreshold;
  final double maximumLocationAccuracyMeters;
  final double maximumReasonableSpeedMetersPerSecond;
  final double minimumEtaSpeedMetersPerSecond;
  final int minimumSpeedSampleCount;
  final double speedSmoothingAlpha;
  final double etaSmoothingAlpha;
  final Duration maximumNormalEtaChangePerUpdate;
  final double routeEtaWeight;
  final double liveSpeedEtaWeight;
  final double progressEtaWeight;
  final Duration minimumProgressSampleDuration;
  final double minimumProgressDistanceMeters;
  final Duration progressWindowDuration;
  final double offRouteThresholdMeters;
  final double offRouteAccuracyMultiplier;
  final int offRouteRequiredSamples;
  final Duration minimumRerouteInterval;
  final double arrivalRadiusMeters;
  final int arrivalRequiredSamples;
  final Duration routingTimeout;
  final bool stopTrackingAfterArrival;

  NavigationConfig({
    required this.osrmBaseUrl,
    required this.desiredLocationInterval,
    required this.staleLocationThreshold,
    required this.maximumLocationAccuracyMeters,
    required this.maximumReasonableSpeedMetersPerSecond,
    required this.minimumEtaSpeedMetersPerSecond,
    required this.minimumSpeedSampleCount,
    required this.speedSmoothingAlpha,
    required this.etaSmoothingAlpha,
    required this.maximumNormalEtaChangePerUpdate,
    required this.routeEtaWeight,
    required this.liveSpeedEtaWeight,
    required this.progressEtaWeight,
    required this.minimumProgressSampleDuration,
    required this.minimumProgressDistanceMeters,
    required this.progressWindowDuration,
    required this.offRouteThresholdMeters,
    required this.offRouteAccuracyMultiplier,
    required this.offRouteRequiredSamples,
    required this.minimumRerouteInterval,
    required this.arrivalRadiusMeters,
    required this.arrivalRequiredSamples,
    required this.routingTimeout,
    required this.stopTrackingAfterArrival,
  }) {
    _validate();
  }

  factory NavigationConfig.defaults({
    String osrmBaseUrl = 'https://router.project-osrm.org',
  }) {
    return NavigationConfig(
      osrmBaseUrl: osrmBaseUrl,
      desiredLocationInterval: const Duration(seconds: 1),
      staleLocationThreshold: const Duration(seconds: 10),
      maximumLocationAccuracyMeters: 50,
      maximumReasonableSpeedMetersPerSecond: 55,
      minimumEtaSpeedMetersPerSecond: 0.8,
      minimumSpeedSampleCount: 3,
      speedSmoothingAlpha: 0.25,
      etaSmoothingAlpha: 0.20,
      maximumNormalEtaChangePerUpdate: const Duration(seconds: 10),
      routeEtaWeight: 0.60,
      liveSpeedEtaWeight: 0.25,
      progressEtaWeight: 0.15,
      minimumProgressSampleDuration: const Duration(seconds: 30),
      minimumProgressDistanceMeters: 100,
      progressWindowDuration: const Duration(seconds: 90),
      offRouteThresholdMeters: 35,
      offRouteAccuracyMultiplier: 2.0,
      offRouteRequiredSamples: 3,
      minimumRerouteInterval: const Duration(seconds: 20),
      arrivalRadiusMeters: 25,
      arrivalRequiredSamples: 2,
      routingTimeout: const Duration(seconds: 15),
      stopTrackingAfterArrival: true,
    );
  }

  void _validate() {
    final uri = Uri.tryParse(osrmBaseUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw ArgumentError('Invalid OSRM base URL.');
    }
    for (final alpha in [speedSmoothingAlpha, etaSmoothingAlpha]) {
      if (alpha < 0 || alpha > 1) throw ArgumentError('Alpha must be 0..1.');
    }
    if (maximumReasonableSpeedMetersPerSecond <=
        minimumEtaSpeedMetersPerSecond) {
      throw ArgumentError('Maximum speed must be greater than minimum speed.');
    }
    final total = routeEtaWeight + liveSpeedEtaWeight + progressEtaWeight;
    if ((total - 1.0).abs() > 0.001) {
      throw ArgumentError('ETA weights must total 1.0.');
    }
    if (minimumSpeedSampleCount <= 0 ||
        offRouteRequiredSamples <= 0 ||
        arrivalRequiredSamples <= 0) {
      throw ArgumentError('Sample counts must be positive.');
    }
    if (maximumLocationAccuracyMeters <= 0 ||
        offRouteThresholdMeters <= 0 ||
        arrivalRadiusMeters <= 0 ||
        minimumProgressDistanceMeters < 0) {
      throw ArgumentError('Thresholds must be positive.');
    }
  }
}
