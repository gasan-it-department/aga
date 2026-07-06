import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Activities/MDRRMO/Maps/MarinduqueBoundaries.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;

class MDRRMOLiveMap extends StatefulWidget {
  const MDRRMOLiveMap({super.key});

  @override
  State<MDRRMOLiveMap> createState() => _MDRRMOLiveMapState();
}

class _MDRRMOLiveMapState extends State<MDRRMOLiveMap> {
  final _supabase = Supabase.instance.client;
  final MapController _mapController = MapController();

  final Color primaryDark = const Color(0xFF0F172A);
  final Color textSecondary = const Color(0xFF64748B);
  final Color emergencyRed = const Color(0xFFEF4444);
  final Color cardBorder = const Color(0xFFE2E8F0);

  final LatLng _defaultCenter = const LatLng(13.3941, 121.9564);

  List<Map<String, dynamic>> _fleetData = [];
  List<Map<String, dynamic>> _incidentData = [];

  StreamSubscription? _fleetSub;
  StreamSubscription? _incidentSub;

  List<Polygon> _boundaryPolygons = [];
  bool _isLoadingBoundaries = true;
  bool _isSatelliteView = false;
  bool _showBoundaries = true;

  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _alertTimer;
  Set<String> _knownPendingIds = {};
  bool _isFirstLoad = true;
  bool _isAlertDialogOpen = false;

  int? _pingMs;
  Timer? _pingTimer;

  // --- MUNICIPALITY CENTERS ---
  final List<Map<String, dynamic>> _municipalities = [
    {"name": "BOAC", "coords": const LatLng(13.4474, 121.8465)},
    {"name": "MOGPOG", "coords": const LatLng(13.4866, 121.8601)},
    {"name": "SANTA CRUZ", "coords": const LatLng(13.4735, 122.0298)},
    {"name": "TORRIJOS", "coords": const LatLng(13.3204, 122.0528)},
    {"name": "BUENAVISTA", "coords": const LatLng(13.2503, 121.9565)},
    {"name": "GASAN", "coords": const LatLng(13.3211, 121.8496)},
  ];

  @override
  void initState() {
    super.initState();
    _initGeoJson();
    _setupStreams();
    _startPingMonitor();

    // Set audio to loop continuously until stopped
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
  }

  void _startPingMonitor() {
    _measurePing();
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _measurePing());
  }

  static const List<String> _pingEndpoints = [
    'https://api.ipify.org?format=text',
    'https://www.gstatic.com/generate_204',
    'https://cloudflare.com/cdn-cgi/trace',
  ];

  Future<void> _measurePing() async {
    for (final url in _pingEndpoints) {
      final sw = Stopwatch()..start();
      try {
        final res = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 4));
        sw.stop();
        if (res.statusCode < 500) {
          if (mounted) setState(() => _pingMs = sw.elapsedMilliseconds);
          return;
        }
      } catch (_) {
        sw.stop();
      }
    }
    if (mounted) setState(() => _pingMs = null);
  }

  void _setupStreams() {
    _fleetSub = _supabase.from('vehicles').stream(primaryKey: ['vehicle_id']).listen((data) {
      if (mounted) {
        setState(() {
          _fleetData = data;
        });
      }
    });

    _incidentSub = _supabase
        .from('incidents_reports')
        .stream(primaryKey: ['ticket_id'])
        .listen((data) {
      if (mounted) {
        final filteredIncidents = data.where((incident) {
          final status = incident['ticket_status']?.toString().toLowerCase();
          return status == 'pending' || status == 'being_responded';
        }).toList();

        // --- NEW ALERT DETECTION LOGIC ---
        bool triggerAlarm = false;
        String latestAlertTitle = "Emergency Alert";
        String latestAlertLocation = "Unknown Location";
        final currentPendingIds = <String>{};

        for (var incident in filteredIncidents) {
          if (incident['ticket_status']?.toString().toLowerCase() == 'pending') {
            final id = incident['ticket_id'].toString();
            currentPendingIds.add(id);

            // If it's a new ID we haven't seen yet (and it's not the first load flurry)
            if (!_isFirstLoad && !_knownPendingIds.contains(id)) {
              triggerAlarm = true;
              latestAlertTitle = incident['ticket_incidents_type']?.toString() ?? latestAlertTitle;
              latestAlertLocation = incident['ticket_incidents_location']?.toString() ?? latestAlertLocation;
            }
          }
        }

        // If it's the very first load and there are pending alerts, alert the admin immediately
        if (_isFirstLoad) {
          if (currentPendingIds.isNotEmpty) {
            triggerAlarm = true;
            // Grab the first one to show in the dialog
            final firstPending = filteredIncidents.firstWhere((i) => i['ticket_status']?.toString().toLowerCase() == 'pending');
            latestAlertTitle = firstPending['ticket_incidents_type']?.toString() ?? latestAlertTitle;
            latestAlertLocation = firstPending['ticket_incidents_location']?.toString() ?? latestAlertLocation;
          }
          _isFirstLoad = false;
        }

        // Update known IDs
        _knownPendingIds = currentPendingIds;

        // Fire the alarm if a new incident was found
        if (triggerAlarm) {
          _triggerAlert(latestAlertTitle, latestAlertLocation);
        }

        setState(() {
          _incidentData = filteredIncidents;
        });
      }
    });
  }

  // --- ALERT EXECUTION ---
  void _triggerAlert(String title, String location) async {
    // 1. Play the sound
    await _audioPlayer.play(AssetSource('alert_sound.mp3'));

    // 2. Set/Reset the 1-minute auto-kill timer
    _alertTimer?.cancel();
    _alertTimer = Timer(const Duration(minutes: 1), () {
      _stopAlertSound();
    });

    // 3. Show the Dialog (if one isn't already showing)
    if (!_isAlertDialogOpen) {
      _isAlertDialogOpen = true;
      showDialog(
          context: context,
          barrierDismissible: false, // Force them to acknowledge it
          builder: (context) {
            return AlertDialog(
              backgroundColor: primaryDark,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: emergencyRed, width: 2)
              ),
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: emergencyRed, size: 32),
                  const SizedBox(width: 10),
                  Text("NEW ALERT!", style: TextStyle(color: emergencyRed, fontWeight: FontWeight.w900)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("A new emergency has been reported:", style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 12),
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on, color: textSecondary, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text(location, style: TextStyle(color: textSecondary, fontSize: 14))),
                    ],
                  ),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: emergencyRed,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      _stopAlertSound();
                      Navigator.of(context).pop();
                    },
                    child: const Text("ACKNOWLEDGE & DISMISS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  ),
                )
              ],
            );
          }
      ).then((_) {
        // When dialog closes for any reason, mark as closed
        _isAlertDialogOpen = false;
      });
    }
  }

  void _stopAlertSound() async {
    _alertTimer?.cancel();
    await _audioPlayer.stop();
  }

  Future<void> _initGeoJson() async {
    final polygons = await MarinduqueBoundaries.loadBoundaries();
    if (mounted) {
      setState(() {
        _boundaryPolygons = polygons;
        _isLoadingBoundaries = false;
      });
    }
  }

  @override
  void dispose() {
    _alertTimer?.cancel();
    _pingTimer?.cancel();
    _audioPlayer.dispose();
    _fleetSub?.cancel();
    _incidentSub?.cancel();
    _mapController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryDark,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: 10.5,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: _isSatelliteView
                    ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                    : 'https://cartodb-basemaps-a.global.ssl.fastly.net/light_nolabels/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.gasan_port_tracker',
              ),

              if (_showBoundaries && !_isLoadingBoundaries)
                PolygonLayer(
                  polygons: _boundaryPolygons.map((poly) {
                    return Polygon(
                      points: poly.points,
                      color: _isSatelliteView ? null : poly.color,
                      borderColor: _isSatelliteView ? Colors.cyanAccent : (poly.borderColor),
                      borderStrokeWidth: _isSatelliteView ? 3.0 : 2.0,
                    );
                  }).toList(),
                ),

              // THE DYNAMIC POLYLINES
              PolylineLayer(polylines: _generatePolylines()),

              // THE MUNICIPALITY LABELS
              Builder(
                builder: (innerContext) {
                  final camera = MapCamera.of(innerContext);
                  final bool showLabels = camera.zoom >= 11.2 && _showBoundaries;

                  return IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: showLabels ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: MarkerLayer(
                        markers: _municipalities.map((m) {
                          return Marker(
                            point: m["coords"],
                            width: 160,
                            height: 40,
                            alignment: Alignment.center,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: primaryDark.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.6), width: 1.2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.account_balance_rounded, color: Colors.blueAccent, size: 12),
                                    const SizedBox(width: 6),
                                    Text(
                                      m["name"],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),

              // THE MARKERS - WRAPPED IN BUILDER TO ACCESS INNER CONTEXT
              Builder(
                  builder: (innerContext) {
                    return MarkerClusterLayer(
                      mapCamera: MapCamera.of(innerContext),
                      mapController: MapController.of(innerContext),
                      options: MarkerClusterLayerOptions(
                        maxClusterRadius: 45,
                        size: const Size(40, 40),
                        markers: _generateMarkers(),
                        builder: (context, markers) {
                          bool hasAlert = markers.any((m) => (m.key as ValueKey).value.toString().startsWith('inc_'));
                          return Container(
                            decoration: BoxDecoration(
                              color: hasAlert ? emergencyRed : primaryDark,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                "${markers.length}",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }
              ),
            ],
          ),

          // HEADER OVERLAY
          _buildHeader(
              _fleetData.length,
              _incidentData.length,
              Container(
                decoration: BoxDecoration(
                  color: primaryDark.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: const BackButton(color: Colors.white),
              )
          ),

          _buildMapControls(),


          // --- VIEW INCIDENTS BUTTON (ALWAYS VISIBLE) ---
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton.extended(
                heroTag: "view_incidents_list",
                // Change color to Grey if there are no incidents
                backgroundColor: _incidentData.isNotEmpty ? emergencyRed : Colors.grey.shade800,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.list_alt_rounded),
                label: Text(
                  // Change text based on whether there are incidents
                  _incidentData.isNotEmpty
                      ? "View ${_incidentData.length} Incidents"
                      : "No Active Incidents",
                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                // Disable the button tap if there are no incidents
                onPressed: _incidentData.isNotEmpty ? _showIncidentsListSheet : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("There are no active incidents right now.")),
                  );
                },
                elevation: _incidentData.isNotEmpty ? 6 : 0,
              ),
            ),
          ),

          if (_isLoadingBoundaries)
            const Positioned(bottom: 20, left: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ),
    );
  }

  // --- POLYLINES GENERATOR ---
  List<Polyline> _generatePolylines() {
    final polylines = <Polyline>[];

    for (var incident in _incidentData) {
      if (incident['ticket_status']?.toString().toLowerCase() == 'being_responded') {
        final responderId = incident['ticket_responder_vehicle_id']?.toString();

        if (responderId != null && responderId.isNotEmpty) {
          final vehicle = _fleetData.firstWhere(
                  (v) => v['vehicle_id'].toString() == responderId,
              orElse: () => <String, dynamic>{}
          );

          if (vehicle.isNotEmpty) {
            final vCoords = _parseCoordinates(vehicle['vehicle_current_coordinates']);
            final iCoords = _parseCoordinates(incident['ticket_incidents_coordinates']);

            if (vCoords != null && iCoords != null) {
              polylines.add(
                Polyline(
                  points: [vCoords, iCoords],
                  color: const Color(0xFFF59E0B),
                  strokeWidth: 4.0,
                ),
              );
            }
          }
        }
      }
    }
    return polylines;
  }

  // --- MARKER GENERATOR ---
  List<Marker> _generateMarkers() {
    final mapMarkers = <Marker>[];

    // Vehicles
    for (var v in _fleetData) {
      final coords = _parseCoordinates(v['vehicle_current_coordinates']);
      if (coords == null) continue;

      mapMarkers.add(_buildMarker(
        keyId: 'veh_${v['vehicle_id']}',
        point: coords,
        color: _getStatusColor(v['vehicle_status']?.toString() ?? ''),
        icon: _getTypeIcon(v['vehicle_type']?.toString() ?? ''),
        label: v['vehicle_name']?.toString() ?? v['vehicle_plate_number']?.toString(),
        data: v,
        isIncident: false,
        isPulsing: false,
      ));
    }

    // Incidents
    for (var i in _incidentData) {
      final coords = _parseCoordinates(i['ticket_incidents_coordinates']);
      if (coords == null) continue;

      final isBeingResponded = i['ticket_status']?.toString().toLowerCase() == 'being_responded';

      Color mColor = emergencyRed;
      IconData mIcon = Icons.crisis_alert_rounded;
      String mLabel = "ALERT";
      bool mPulse = true;

      if (isBeingResponded) {
        mColor = const Color(0xFFF59E0B); // Amber
        mIcon = Icons.directions_run_rounded;
        mLabel = "ALERT";
        mPulse = false; // Stop pulsing once someone is handling it
      }

      mapMarkers.add(_buildMarker(
        keyId: 'inc_${i['ticket_id']}',
        point: coords,
        color: mColor,
        icon: mIcon,
        label: mLabel,
        data: i,
        isIncident: true,
        isPulsing: mPulse,
      ));
    }

    return mapMarkers;
  }

  Marker _buildMarker({required String keyId, required LatLng point, required Color color, required IconData icon, required String? label, required Map<String, dynamic> data, required bool isIncident, required bool isPulsing}) {
    return Marker(
      key: ValueKey(keyId),
      point: point,
      width: 70, height: 70,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () => _showDetailsSheet(data, isIncident),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            isPulsing
                ? RippleAlertIcon(color: color, icon: icon)
                : Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            if (label != null)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(4)),
                child: Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color)),
              )
          ],
        ),
      ),
    );
  }

  // --- INCIDENTS LIST BOTTOM SHEET ---
  void _showIncidentsListSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 40, height: 5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
              ),
              Row(
                children: [
                  Icon(Icons.crisis_alert_rounded, color: emergencyRed, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Active Incidents",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: primaryDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _incidentData.isEmpty
                    ? Center(child: Text("No active incidents currently.", style: TextStyle(color: textSecondary)))
                    : ListView.separated(
                  itemCount: _incidentData.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final incident = _incidentData[index];
                    final type = incident['ticket_incidents_type']?.toString() ?? 'Emergency';
                    final location = incident['ticket_incidents_location']?.toString() ?? 'Unknown Location';
                    final status = incident['ticket_status']?.toString().toUpperCase() ?? 'UNKNOWN';
                    final isBeingResponded = status.toLowerCase() == 'being_responded';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isBeingResponded ? const Color(0xFFF59E0B).withValues(alpha: 0.1) : emergencyRed.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isBeingResponded ? Icons.directions_run_rounded : Icons.warning_rounded,
                          color: isBeingResponded ? const Color(0xFFF59E0B) : emergencyRed,
                        ),
                      ),
                      title: Text(type, style: TextStyle(fontWeight: FontWeight.bold, color: primaryDark, fontSize: 16)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(location, style: TextStyle(fontSize: 13, color: textSecondary)),
                      ),
                      trailing: _buildChip(status, isBeingResponded ? const Color(0xFFF59E0B) : emergencyRed),
                      onTap: () {
                        // Close the list sheet
                        Navigator.pop(context);

                        // Extract coordinates and move map
                        final coords = _parseCoordinates(incident['ticket_incidents_coordinates']);
                        if (coords != null) {
                          _mapController.move(coords, 14.5);
                        }

                        // Show details for this incident
                        _showDetailsSheet(incident, true);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- DETAILS BOTTOM SHEET ---
  void _showDetailsSheet(Map<String, dynamic> data, bool isIncident) {
    // 1. EXTRACT AND DECODE THE IMAGES IF THIS IS AN INCIDENT
    List<String> imageUrls = [];
    if (isIncident && data['ticket_images'] != null) {
      try {
        final parsedList = jsonDecode(data['ticket_images'].toString());
        imageUrls = List<String>.from(parsedList);
      } catch (e) {
        debugPrint("Failed to parse images: $e");
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 5,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                  ),
                ),

                if (isIncident) ...[
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: emergencyRed.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.crisis_alert, color: emergencyRed)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(data['ticket_incidents_type']?.toString() ?? 'Emergency Alert', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: primaryDark))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSheetRow(Icons.location_on, "Location", data['ticket_incidents_location']?.toString() ?? 'Unknown Location'),
                  _buildSheetRow(Icons.phone, "Contact", data['ticket_incidents_contact_number']?.toString() ?? 'N/A'),

                  // Show responding vehicle in Admin view if assigned
                  if (data['ticket_status']?.toString().toLowerCase() == 'being_responded') ...[
                    Builder(
                        builder: (context) {
                          String respondingDetails = "Unknown Unit";
                          final rId = data['ticket_responder_vehicle_id']?.toString();
                          if (rId != null && rId.isNotEmpty) {
                            final v = _fleetData.firstWhere((v) => v['vehicle_id'].toString() == rId, orElse: () => <String,dynamic>{});
                            if (v.isNotEmpty) respondingDetails = "${v['vehicle_name']} (${v['vehicle_plate_number']})";
                          }
                          return _buildSheetRow(Icons.local_shipping_rounded, "Assigned Responder", respondingDetails);
                        }
                    )
                  ],

                  const Divider(height: 32),
                  const Text("Description", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(data['ticket_incidents_description']?.toString() ?? 'No description provided.', style: TextStyle(color: primaryDark)),

                  // --- 2. DISPLAY THE UPLOADED IMAGES ---
                  if (imageUrls.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text("Attached Evidence", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: imageUrls.map((url) {
                        return GestureDetector(
                          onTap: () {
                            _showFullScreenImage(context, url);
                          },
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: cardBorder, width: 1.5),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                url,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)));
                                },
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image_rounded, color: Colors.grey),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                ] else ...[
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.directions_car, color: Colors.blue)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['vehicle_name']?.toString() ?? 'Fleet Unit', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: primaryDark)),
                            Text(data['vehicle_plate_number']?.toString() ?? 'No Plate', style: TextStyle(fontWeight: FontWeight.bold, color: textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildChip((data['vehicle_status'] ?? 'Unknown').toString().toUpperCase(), _getStatusColor(data['vehicle_status']?.toString() ?? '')),
                      const SizedBox(width: 8),
                      _buildChip((data['vehicle_type'] ?? 'General').toString().toUpperCase(), primaryDark),
                    ],
                  ),
                  const Divider(height: 32),
                  _buildSheetRow(Icons.account_balance, "Municipality", data['vehicle_municipal_owner']?.toString() ?? 'N/A'),
                  _buildSheetRow(Icons.build, "Model", data['vehicle_model']?.toString() ?? 'N/A'),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: textSecondary)),
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.5))),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color)),
    );
  }

  // Helper to view image in full screen when tapped
  void _showFullScreenImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.cancel, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(context),
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- HELPERS & CONTROLS ---
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available': return const Color(0xFF10B981);
      case 'dispatched': return const Color(0xFFF59E0B);
      default: return const Color(0xFF64748B);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'medical': return Icons.medical_services_rounded;
      case 'rescue': return Icons.emergency_rounded;
      default: return Icons.directions_car_rounded;
    }
  }

  Widget _buildHeader(int f, int i, Widget backButtonWidget) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          backButtonWidget,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.directions_car_rounded, color: primaryDark, size: 20),
                const SizedBox(width: 6),
                Text("$f", style: TextStyle(fontWeight: FontWeight.w900, color: primaryDark, fontSize: 15)),
                const SizedBox(width: 12),
                Container(height: 16, width: 1.5, color: cardBorder),
                const SizedBox(width: 12),
                Icon(Icons.crisis_alert_rounded, color: emergencyRed, size: 20),
                const SizedBox(width: 6),
                Text("$i", style: TextStyle(fontWeight: FontWeight.w900, color: emergencyRed, fontSize: 15)),
                const SizedBox(width: 12),
                Container(height: 16, width: 1.5, color: cardBorder),
                const SizedBox(width: 12),
                _buildPingInline(),
              ],
            ),
          )
        ],
      ),
    ),
  );

  Widget _buildPingInline() {
    final ms = _pingMs;
    Color color;
    IconData icon;
    String label;
    if (ms == null) {
      color = Colors.grey.shade700;
      icon = Icons.signal_wifi_off_rounded;
      label = "Offline";
    } else if (ms < 150) {
      color = const Color(0xFF10B981);
      icon = Icons.network_wifi_rounded;
      label = "${ms}ms";
    } else if (ms < 400) {
      color = const Color(0xFFF59E0B);
      icon = Icons.network_wifi_3_bar_rounded;
      label = "${ms}ms";
    } else {
      color = emergencyRed;
      icon = Icons.network_wifi_1_bar_rounded;
      label = "${ms}ms";
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 13)),
      ],
    );
  }

  Widget _buildPingChip() {
    final ms = _pingMs;
    Color color;
    IconData icon;
    String label;
    if (ms == null) {
      color = Colors.grey.shade700;
      icon = Icons.signal_wifi_off_rounded;
      label = "Offline";
    } else if (ms < 150) {
      color = const Color(0xFF10B981);
      icon = Icons.network_wifi_rounded;
      label = "${ms}ms";
    } else if (ms < 400) {
      color = const Color(0xFFF59E0B);
      icon = Icons.network_wifi_3_bar_rounded;
      label = "${ms}ms";
    } else {
      color = emergencyRed;
      icon = Icons.network_wifi_1_bar_rounded;
      label = "${ms}ms";
    }
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(20),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapControls() => Positioned(
      right: 16, bottom: 32,
      child: Column(
          children: [
            FloatingActionButton.small(heroTag: "btn1", backgroundColor: Colors.white, foregroundColor: primaryDark, onPressed: () => setState(() => _showBoundaries = !_showBoundaries), child: const Icon(Icons.layers)),
            const SizedBox(height: 8),
            FloatingActionButton.small(heroTag: "btn2", backgroundColor: Colors.white, foregroundColor: primaryDark, onPressed: () => setState(() => _isSatelliteView = !_isSatelliteView), child: const Icon(Icons.satellite_alt)),
            const SizedBox(height: 8),
            FloatingActionButton(heroTag: "recenter", backgroundColor: Colors.white, foregroundColor: primaryDark, onPressed: () => _mapController.move(_defaultCenter, 10.5), child: const Icon(Icons.my_location)),
          ]
      )
  );
}

// ============================================================================
// ANIMATED RIPPLE MARKER WIDGET
// ============================================================================
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
