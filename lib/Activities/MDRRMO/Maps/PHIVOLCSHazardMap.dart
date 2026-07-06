import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:gasan_port_tracker/Activities/MDRRMO/Maps/MarinduqueBoundaries.dart';
import 'package:latlong2/latlong.dart';

class PHIVOLCSHazardMap extends StatefulWidget {
  const PHIVOLCSHazardMap({super.key});

  @override
  State<PHIVOLCSHazardMap> createState() => _PHIVOLCSHazardMapState();
}

class _PHIVOLCSHazardMapState extends State<PHIVOLCSHazardMap> {
  static const _activeFaultUrl =
      'https://ulap-hazards.georisk.gov.ph/arcgis/rest/services/PHIVOLCSPublic/ActiveFault/MapServer';
  static const _liquefactionUrl =
      'https://ulap-hazards.georisk.gov.ph/arcgis/rest/services/PHIVOLCSPublic/Liquefaction/MapServer';

  final MapController _mapController = MapController();
  final LatLng _marinduqueCenter = const LatLng(13.3941, 121.9564);

  final Color _primaryDark = const Color(0xFF0F172A);
  final Color _emergencyRed = const Color(0xFFEF4444);
  final Color _amber = const Color(0xFFF59E0B);
  final Color _cyan = const Color(0xFF06B6D4);
  final Color _surface = Colors.white;
  final Color _border = const Color(0xFFE2E8F0);
  final Color _muted = const Color(0xFF64748B);

  Timer? _overlayDebounce;
  LatLngBounds? _visibleBounds;
  String? _activeFaultImageUrl;
  String? _liquefactionImageUrl;
  String _lastOverlayKey = '';

  List<Polygon> _boundaryPolygons = [];
  bool _loadingBoundaries = true;
  bool _satellite = false;
  bool _showBoundaries = true;
  bool _showActiveFaults = true;
  bool _showLiquefaction = true;

  @override
  void initState() {
    super.initState();
    _loadBoundaries();
  }

  @override
  void dispose() {
    _overlayDebounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadBoundaries() async {
    final polygons = await MarinduqueBoundaries.loadBoundaries();
    if (!mounted) return;
    setState(() {
      _boundaryPolygons = polygons;
      _loadingBoundaries = false;
    });
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (camera.size.width <= 0 || camera.size.height <= 0) return;
    _overlayDebounce?.cancel();
    _overlayDebounce = Timer(
      hasGesture ? const Duration(milliseconds: 450) : Duration.zero,
      () => _updateArcGisOverlay(camera),
    );
  }

  void _updateArcGisOverlay(MapCamera camera) {
    final bounds = _expandedBounds(camera.visibleBounds);
    final width = camera.size.width.clamp(360, 1280).round();
    final height = camera.size.height.clamp(360, 1280).round();
    final key = [
      bounds.west.toStringAsFixed(4),
      bounds.south.toStringAsFixed(4),
      bounds.east.toStringAsFixed(4),
      bounds.north.toStringAsFixed(4),
      width,
      height,
    ].join(':');

    if (key == _lastOverlayKey) return;

    setState(() {
      _lastOverlayKey = key;
      _visibleBounds = bounds;
      _activeFaultImageUrl = _buildExportUrl(
        serviceUrl: _activeFaultUrl,
        bounds: bounds,
        width: width,
        height: height,
      );
      _liquefactionImageUrl = _buildExportUrl(
        serviceUrl: _liquefactionUrl,
        bounds: bounds,
        width: width,
        height: height,
      );
    });
  }

  LatLngBounds _expandedBounds(LatLngBounds bounds) {
    final latPad = (bounds.north - bounds.south).abs() * 0.12;
    final lngPad = (bounds.east - bounds.west).abs() * 0.12;
    return LatLngBounds.unsafe(
      north: math.min(90, bounds.north + latPad),
      south: math.max(-90, bounds.south - latPad),
      east: math.min(180, bounds.east + lngPad),
      west: math.max(-180, bounds.west - lngPad),
    );
  }

  String _buildExportUrl({
    required String serviceUrl,
    required LatLngBounds bounds,
    required int width,
    required int height,
  }) {
    final params = <String, String>{
      'bbox': '${bounds.west},${bounds.south},${bounds.east},${bounds.north}',
      'bboxSR': '4326',
      'imageSR': '4326',
      'size': '$width,$height',
      'format': 'png32',
      'transparent': 'true',
      'layers': 'show:0',
      'f': 'image',
    };
    return Uri.parse(
      '$serviceUrl/export',
    ).replace(queryParameters: params).toString();
  }

  void _resetMap() {
    _mapController.move(_marinduqueCenter, 10.5);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryDark,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _marinduqueCenter,
              initialZoom: 10.5,
              minZoom: 8,
              maxZoom: 16,
              onPositionChanged: _onPositionChanged,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: _satellite
                    ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                    : 'https://cartodb-basemaps-a.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.gasan_port_tracker',
              ),
              if (_showLiquefaction &&
                  _visibleBounds != null &&
                  _liquefactionImageUrl != null)
                OverlayImageLayer(
                  overlayImages: [
                    OverlayImage(
                      imageProvider: NetworkImage(_liquefactionImageUrl!),
                      bounds: _visibleBounds!,
                      opacity: 0.62,
                      gaplessPlayback: true,
                    ),
                  ],
                ),
              if (_showActiveFaults &&
                  _visibleBounds != null &&
                  _activeFaultImageUrl != null)
                OverlayImageLayer(
                  overlayImages: [
                    OverlayImage(
                      imageProvider: NetworkImage(_activeFaultImageUrl!),
                      bounds: _visibleBounds!,
                      opacity: 0.9,
                      gaplessPlayback: true,
                    ),
                  ],
                ),
              if (_showBoundaries && !_loadingBoundaries)
                PolygonLayer(
                  polygons: _boundaryPolygons.map((poly) {
                    return Polygon(
                      points: poly.points,
                      color: _satellite
                          ? Colors.transparent
                          : (poly.color ?? _cyan).withValues(alpha: 0.12),
                      borderColor: _satellite
                          ? Colors.cyanAccent
                          : poly.borderColor,
                      borderStrokeWidth: _satellite ? 2.6 : 1.8,
                    );
                  }).toList(),
                ),
              SimpleAttributionWidget(
                source: const Text('DOST-PHIVOLCS / GeoRiskPH'),
                backgroundColor: Colors.white.withValues(alpha: 0.88),
              ),
            ],
          ),
          _buildHeader(context),
          _buildLayerPanel(context),
          _buildMapActions(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPadding + 12,
      left: 16,
      right: 16,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _primaryDark.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                tooltip: 'Back',
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PHIVOLCS Hazard Map',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _surface,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Active faults and liquefaction overlays',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _emergencyRed.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _emergencyRed.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.public_rounded, color: _emergencyRed, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      'GeoRiskPH',
                      style: TextStyle(
                        color: _surface,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLayerPanel(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 560;
    return Positioned(
      left: 16,
      right: isCompact ? 16 : null,
      bottom: MediaQuery.of(context).padding.bottom + 20,
      child: Container(
        width: isCompact ? null : 360,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryDark.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.layers_rounded,
                    color: _primaryDark,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Hazard Layers',
                    style: TextStyle(
                      color: _primaryDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  'Official GIS',
                  style: TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildLayerSwitch(
              title: 'Active Faults',
              subtitle: 'PHIVOLCS active fault overlay',
              color: _emergencyRed,
              icon: Icons.timeline_rounded,
              value: _showActiveFaults,
              onChanged: (value) => setState(() => _showActiveFaults = value),
            ),
            const SizedBox(height: 8),
            _buildLayerSwitch(
              title: 'Liquefaction',
              subtitle: 'Ground liquefaction susceptibility',
              color: _amber,
              icon: Icons.water_drop_rounded,
              value: _showLiquefaction,
              onChanged: (value) => setState(() => _showLiquefaction = value),
            ),
            const SizedBox(height: 8),
            _buildLayerSwitch(
              title: 'Municipal Boundaries',
              subtitle: 'Local Marinduque reference layer',
              color: _cyan,
              icon: Icons.border_outer_rounded,
              value: _showBoundaries,
              onChanged: (value) => setState(() => _showBoundaries = value),
            ),
            const SizedBox(height: 12),
            Text(
              'For planning reference only. Verify critical decisions through official PHIVOLCS/GeoRiskPH channels.',
              style: TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayerSwitch({
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: value
              ? color.withValues(alpha: 0.08)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value ? color.withValues(alpha: 0.26) : _border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: value ? color.withValues(alpha: 0.14) : Colors.white,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: value ? color : _muted, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: _primaryDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              activeThumbColor: color,
              activeTrackColor: color.withValues(alpha: 0.25),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapActions() {
    return Positioned(
      right: 16,
      bottom: MediaQuery.of(context).padding.bottom + 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _roundAction(
            icon: _satellite ? Icons.map_rounded : Icons.satellite_alt_rounded,
            tooltip: _satellite ? 'Street map' : 'Satellite map',
            onTap: () => setState(() => _satellite = !_satellite),
          ),
          const SizedBox(height: 10),
          _roundAction(
            icon: Icons.my_location_rounded,
            tooltip: 'Reset map',
            onTap: _resetMap,
          ),
        ],
      ),
    );
  }

  Widget _roundAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _primaryDark.withValues(alpha: 0.9),
        shape: const CircleBorder(),
        elevation: 8,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, color: Colors.white, size: 21),
          ),
        ),
      ),
    );
  }
}
