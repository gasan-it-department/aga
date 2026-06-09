import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:gasan_port_tracker/Activities/Tourism/TouristSpotDetails.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:supabase_flutter/supabase_flutter.dart';

class TouristSpotMap extends StatefulWidget {
  final int? municipalZipCode;

  const TouristSpotMap({
    super.key,
    this.municipalZipCode,
  });

  @override
  State<TouristSpotMap> createState() => _TouristSpotMapState();
}

class _TouristSpotMapState extends State<TouristSpotMap> with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final MapController _mapController = MapController();

  final Color primaryDark = const Color(0xFF0A2E5C);
  final Color gasanEmerald = const Color(0xFF10B981);

  LatLng _mapCenter = const LatLng(13.3240, 121.8380);
  bool _isSatellite = false;
  bool _isLoading = true;

  List<Map<String, dynamic>> _touristSpots = [];
  String? _selectedSpotLabel;

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _query = '';
  bool _showDropdown = false;
  AnimationController? _moveAnim;

  @override
  void initState() {
    super.initState();
    _fetchTourismSpots();
    _searchFocus.addListener(() {
      if (mounted && _searchFocus.hasFocus) {
        setState(() => _showDropdown = true);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _moveAnim?.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredSpots {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _touristSpots;
    return _touristSpots.where((s) {
      final label = (s['spot_label'] ?? '').toString().toLowerCase();
      final desc = (s['spot_description'] ?? '').toString().toLowerCase();
      return label.contains(q) || desc.contains(q);
    }).toList();
  }

  void _animateMapTo(LatLng dest, double destZoom) {
    try {
      _moveAnim?.stop();
      _moveAnim?.dispose();
    } catch (_) {}
    _moveAnim = null;

    LatLng startCenter;
    double startZoom;
    try {
      final camera = _mapController.camera;
      startCenter = camera.center;
      startZoom = camera.zoom;
    } catch (_) {
      startCenter = _mapCenter;
      startZoom = 14.0;
    }

    debugPrint("AnimStart from=$startCenter z=$startZoom to=$dest z=$destZoom");

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    final curved = CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic);

    void tick() {
      final t = curved.value;
      final lat = startCenter.latitude + (dest.latitude - startCenter.latitude) * t;
      final lng = startCenter.longitude + (dest.longitude - startCenter.longitude) * t;
      final z = startZoom + (destZoom - startZoom) * t;
      _mapController.move(LatLng(lat, lng), z);
    }

    controller.addListener(tick);
    controller.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _mapCenter = dest;
        controller.dispose();
        if (identical(_moveAnim, controller)) _moveAnim = null;
      }
    });
    _moveAnim = controller;
    controller.forward(from: 0);
  }

  void _selectSpotFromSearch(Map<String, dynamic> spot) {
    final coords = _parseCoordinates(spot['spot_coordinates']);
    debugPrint("Selected spot: ${spot['spot_label']} coords=$coords");
    if (coords == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No coordinates for ${spot['spot_label']}")),
      );
      return;
    }
    _searchFocus.unfocus();
    setState(() {
      _selectedSpotLabel = spot['spot_label'];
      _showDropdown = false;
    });
    _animateMapTo(coords, 16.0);
  }

  Future<void> _fetchTourismSpots() async {
    try {
      var query = _supabase
          .from('tourist_spots')
          .select();

      final zipCode = widget.municipalZipCode;
      if (zipCode != null && zipCode != 0) {
        query = query.eq('spot_municipality', zipCode.toString());
      }

      final response = await query;

      if (mounted) {
        setState(() {
          _touristSpots = List<Map<String, dynamic>>.from(response);
          _isLoading = false;

          if (_touristSpots.isNotEmpty) {
            final firstCoords = _parseCoordinates(_touristSpots.first['spot_coordinates']);
            if (firstCoords != null) {
              _mapCenter = firstCoords;
              _mapController.move(_mapCenter, 14.0);
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  LatLng? _parseCoordinates(dynamic jsonCoordinates) {
    if (jsonCoordinates == null) return null;
    try {
      final map = jsonCoordinates is String ? jsonDecode(jsonCoordinates) : jsonCoordinates;
      return LatLng(
        double.parse(map['latitude'].toString()),
        double.parse(map['longitude'].toString()),
      );
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> _getSpotStyling(String? label) {
    String lbl = (label ?? '').toLowerCase();
    if (lbl.contains('church') || lbl.contains('parish')) {
      return {'icon': Icons.church_rounded, 'color': Colors.amber.shade800};
    } else if (lbl.contains('park') || lbl.contains('garden')) {
      return {'icon': Icons.park_rounded, 'color': gasanEmerald};
    } else if (lbl.contains('beach') || lbl.contains('island')) {
      return {'icon': Icons.sailing_rounded, 'color': const Color(0xFF0284C7)};
    }
    return {'icon': Icons.place_rounded, 'color': primaryDark};
  }

  void _showSpotDetails(Map<String, dynamic> spot) {
    setState(() => _selectedSpotLabel = spot['spot_label']);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TouristSpotDetails(spotData: spot)),
    ).then((_) {
      if (mounted) setState(() => _selectedSpotLabel = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Explore Destinations",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 0,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: 14.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: (_, __) {
                if (_showDropdown || _searchFocus.hasFocus) {
                  _searchFocus.unfocus();
                  setState(() => _showDropdown = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _isSatellite
                    ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.gasan.porttracker',
              ),

              if (!_isLoading)
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    maxClusterRadius: 60,
                    size: const Size(48, 48),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(50),
                    maxZoom: 17,
                    spiderfyCircleRadius: 80,
                    spiderfySpiralDistanceMultiplier: 2,
                    circleSpiralSwitchover: 9,
                    markers: _touristSpots
                        .map((spot) => _buildSpotMarker(spot))
                        .whereType<Marker>()
                        .toList(),
                    builder: (context, markers) => _buildClusterBubble(markers.length),
                    onClusterTap: (cluster) {
                      final z = _mapController.camera.zoom + 2;
                      _animateMapTo(cluster.bounds.center, z.clamp(2.0, 18.0));
                    },
                  ),
                ),
            ],
          ),

          // Search Bar
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _buildSearchBar(),
          ),

          // Action Buttons
          Positioned(
            bottom: 100,
            right: 16,
            child: Column(
              children: [
                _buildMapAction(
                  icon: _isSatellite ? Icons.layers_outlined : Icons.layers_rounded,
                  onTap: () => setState(() => _isSatellite = !_isSatellite),
                ),
                const SizedBox(height: 12),
                _buildMapAction(
                  icon: Icons.gps_fixed_rounded,
                  iconColor: gasanEmerald,
                  onTap: () => _animateMapTo(_mapCenter, 14.0),
                ),
              ],
            ),
          ),

          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.white.withValues(alpha: 0.8),
                child: Center(child: CircularProgressIndicator(color: primaryDark)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final results = _filteredSpots;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 14, right: 8),
                child: Icon(Icons.search_rounded, color: primaryDark, size: 22),
              ),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  textAlignVertical: TextAlignVertical.center,
                  onChanged: (v) => setState(() {
                    _query = v;
                    _showDropdown = true;
                  }),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: "Search tourist spots...",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  style: TextStyle(fontSize: 14, color: primaryDark, fontWeight: FontWeight.w600),
                ),
              ),
              if (_query.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: primaryDark,
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _query = '';
                      _showDropdown = _searchFocus.hasFocus;
                    });
                  },
                ),
            ],
          ),
        ),
        if (_showDropdown)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      "No spots found",
                      style: TextStyle(color: primaryDark.withValues(alpha: 0.6), fontWeight: FontWeight.w600),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: results.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.withValues(alpha: 0.15)),
                    itemBuilder: (context, i) {
                      final spot = results[i];
                      final label = (spot['spot_label'] ?? 'Spot').toString();
                      final style = _getSpotStyling(label);
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                        onTap: () => _selectSpotFromSearch(spot),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 34, height: 34,
                                decoration: BoxDecoration(
                                  color: style['color'].withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(style['icon'], color: style['color'], size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.w700, color: primaryDark, fontSize: 13.5),
                                ),
                              ),
                              Icon(Icons.north_east_rounded, size: 16, color: primaryDark.withValues(alpha: 0.4)),
                            ],
                          ),
                        ),
                      ),
                      );
                    },
                  ),
          ),
      ],
    );
  }

  Marker? _buildSpotMarker(Map<String, dynamic> spot) {
    final coords = _parseCoordinates(spot['spot_coordinates']);
    if (coords == null) return null;

    final String spotLabel = spot['spot_label'] ?? 'Spot';

    String? firstImageUrl;
    final dynamic imagesData = spot['spot_images'];
    if (imagesData is List && imagesData.isNotEmpty) {
      firstImageUrl = imagesData[0].toString();
    } else if (imagesData is String && imagesData.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(imagesData);
        if (decoded.isNotEmpty) firstImageUrl = decoded[0].toString();
      } catch (_) {}
    }

    final bool isSelected = _selectedSpotLabel == spotLabel;
    final style = _getSpotStyling(spotLabel);

    return Marker(
      point: coords,
      width: 120,
      height: 110,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () => _showSpotDetails(spot),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isSelected ? style['color'] : Colors.white,
                    width: isSelected ? 3 : 1.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 6))
                ],
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    child: (firstImageUrl != null && firstImageUrl.isNotEmpty)
                        ? Image.network(
                            firstImageUrl,
                            height: 50,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => _buildPlaceholder(style),
                          )
                        : _buildPlaceholder(style),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Text(
                      spotLabel.toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w900, color: primaryDark),
                    ),
                  ),
                ],
              ),
            ),
            CustomPaint(
              painter: TrianglePainter(color: isSelected ? style['color'] : Colors.white),
              child: const SizedBox(width: 20, height: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClusterBubble(int count) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryDark, gasanEmerald],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: Colors.white, width: 2.5),
      ),
      alignment: Alignment.center,
      child: Text(
        "$count",
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
      ),
    );
  }

  Widget _buildPlaceholder(Map<String, dynamic> style) {
    return Container(
      height: 50,
      color: style['color'].withValues(alpha: 0.1),
      child: Center(child: Icon(style['icon'], color: style['color'], size: 22)),
    );
  }

  Widget _buildMapAction({required IconData icon, required VoidCallback onTap, Color? iconColor}) {
    return Container(
      height: 50, width: 50,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor ?? primaryDark, size: 24),
        onPressed: onTap,
      ),
    );
  }
}

// Triangle Painter for Pointer
class TrianglePainter extends CustomPainter {
  final Color color;
  TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final ui.Path path = ui.Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

