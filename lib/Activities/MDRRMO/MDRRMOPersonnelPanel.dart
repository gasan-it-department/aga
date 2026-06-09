import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../Dialogs/ClassicDialog.dart';
import '../../Dialogs/LoadingDialog.dart';
import '../../FloatingMessages/SnackbarMessenger.dart';
import '../../Utility/Utility.dart';
import 'package:gasan_port_tracker/Activities/MDRRMO/Maps/MarinduqueBoundaries.dart';

// IMPORTANT: Ensure this path and filename exactly match your file.
// If your file is lowercase, change this to: import '../../Services/vehicle_location_stream_service.dart';
import '../../Services/VehicleLocationStreamService.dart';
import 'Animations/RippleAlertIcon.dart';

class MdrrmoPersonnelPanel extends StatefulWidget {
  const MdrrmoPersonnelPanel({super.key});

  @override
  State<MdrrmoPersonnelPanel> createState() => _MdrrmoPersonnelPanelState();
}

class _MdrrmoPersonnelPanelState extends State<MdrrmoPersonnelPanel> {
  final _supabase = Supabase.instance.client;
  final MapController _mapController = MapController();
  final _classicDialog = ClassicDialog();
  final _loadingDialog = LoadingDialog();

  final Color bgColor = const Color(0xFFF4F7FA);
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

  // --- LIVE TRACKING STATE ---
  String? _activelyTrackedVehicleId;
  Map<String, dynamic>? _activelyTrackedIncident;
  bool _isTrackingPanelExpanded = true;

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
    _recoverActiveDispatch();
  }

  // ============================================================================
  // GLOBAL ERROR HANDLER
  // ============================================================================
  void _showError(String message) {
    if (!mounted) return;
    try {
      Utility().printLog("ERROR LOG: $message");
      _classicDialog.setTitle("Something went wrong!");
      _classicDialog.setMessage(message);
      _classicDialog.setCancelable(false);
      _classicDialog.setPositiveMessage("Close");
      _classicDialog.showOnButtonDialog(context, () {
        _classicDialog.dismissDialog();
      });
    } catch (e) {
      Utility().printLog("Failed to show dialog: $e");
      SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, message);
    }
  }

  // ============================================================================
  // PERMISSION LOGIC (Web/Android/iOS Compatible)
  // ============================================================================
  Future<bool> _requestPermissions() async {
    try {
      // 1. Web Check: Bypass permission_handler as browsers handle this natively via Geolocation API
      if (kIsWeb) {
        Utility().printLog("Running on Web: Bypassing native permission_handler.");
        return true;
      }

      // 2. Mobile Check: Request standard permissions
      PermissionStatus locationStatus = await Permission.location.request();
      if (locationStatus.isDenied || locationStatus.isPermanentlyDenied) {
        _showError("Location permission is required for dispatch tracking. Please allow it in app settings.");
        return false;
      }

      PermissionStatus notificationStatus = await Permission.notification.request();
      if (notificationStatus.isDenied || notificationStatus.isPermanentlyDenied) {
        _showError("Notification permission is required to run the tracking service in the background.");
        return false;
      }

      // Safe catch for locationAlways as Android 11+ is strict about it being requested directly
      try {
        await Permission.locationAlways.request();
      } catch (e) {
        Utility().printLog("Background location request warning (non-fatal): $e");
      }

      return true;
    } catch (e) {
      _showError("Permission Request Error: $e");
      return false;
    }
  }

  // ============================================================================
  // CRASH / RESTART RECOVERY LOGIC
  // ============================================================================
  Future<void> _recoverActiveDispatch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedVehicleId = prefs.getString('active_vehicle_id');
      final savedIncidentId = prefs.getString('active_incident_id');

      if (savedVehicleId != null && savedIncidentId != null) {
        Utility().printLog("Recovering previous dispatch state...");

        try {
          final incidentResponse = await _supabase
              .from('incidents_reports')
              .select()
              .eq('ticket_id', savedIncidentId)
              .single();

          if (incidentResponse['ticket_status'].toString().toLowerCase() == 'being_responded') {
            if (mounted) {
              setState(() {
                _activelyTrackedVehicleId = savedVehicleId;
                _activelyTrackedIncident = incidentResponse;
                _isTrackingPanelExpanded = true;
              });
              Utility().printLog("State successfully restored!");

              if (!kIsWeb) {
                await VehicleLocationStreamService().startTracking(savedVehicleId);
              }
            }
          } else {
            await _clearLocalState();
            if (!kIsWeb) await VehicleLocationStreamService().stopTracking();
          }
        } catch (e) {
          Utility().printLog("Failed to recover incident state: $e");
          await _clearLocalState();
          if (!kIsWeb) await VehicleLocationStreamService().stopTracking();
        }
      }
    } catch (e) {
      _showError("System Recovery Error: $e");
    }
  }

  Future<void> _saveLocalState(String vehicleId, String incidentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_vehicle_id', vehicleId);
      await prefs.setString('active_incident_id', incidentId);
    } catch (e) {
      _showError("Failed to save session state: $e");
    }
  }

  Future<void> _clearLocalState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('active_vehicle_id');
      await prefs.remove('active_incident_id');
    } catch (e) {
      _showError("Failed to clear session state: $e");
    }
  }

  void _setupStreams() {
    try {
      // STREAM 1: FLEET
      _fleetSub = _supabase.from('vehicles').stream(primaryKey: ['vehicle_id']).listen((data) {
        try {
          if (mounted) {
            setState(() {
              _fleetData = data;
            });

            if (_activelyTrackedVehicleId != null) {
              final trackedVehicle = data.firstWhere((v) => v['vehicle_id'].toString() == _activelyTrackedVehicleId, orElse: () => <String, dynamic>{});
              if (trackedVehicle.isNotEmpty) {
                final coords = _parseCoordinates(trackedVehicle['vehicle_current_coordinates']);
                if (coords != null) {
                  _mapController.move(coords, 15.0);
                }
              }
            }
          }
        } catch (e) {
          Utility().printLog("Fleet Stream Data Parse Error: $e");
        }
      }, onError: (e) {
        _showError("Fleet Network Stream Error: $e");
      });

      // STREAM 2: INCIDENTS
      _incidentSub = _supabase
          .from('incidents_reports')
          .stream(primaryKey: ['ticket_id'])
          .listen((data) {
        try {
          if (mounted) {
            final filteredIncidents = data.where((incident) {
              final status = incident['ticket_status']?.toString().toLowerCase();
              return status == 'pending' || status == 'being_responded';
            }).toList();

            setState(() {
              _incidentData = filteredIncidents;
            });
          }
        } catch (e) {
          Utility().printLog("Incident Stream Data Parse Error: $e");
        }
      }, onError: (e) {
        _showError("Incident Network Stream Error: $e");
      });
    } catch (e) {
      _showError("Failed to initialize tracking streams: $e");
    }
  }

  Future<void> _initGeoJson() async {
    try {
      final polygons = await MarinduqueBoundaries.loadBoundaries();
      if (mounted) {
        setState(() {
          _boundaryPolygons = polygons;
          _isLoadingBoundaries = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingBoundaries = false);
      _showError("Failed to load map polygons: $e");
    }
  }

  @override
  void dispose() {
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

  // --- FINAL RESPOND ACTION ---
  Future<void> _respondToIncident(Map<String, dynamic> incident, Map<String, dynamic> selectedVehicle) async {
    try {
      bool hasPermissions = await _requestPermissions();
      if (!hasPermissions) return;

      if (!mounted) return;

      _classicDialog.setTitle("Confirm Dispatch");
      _classicDialog.setMessage("Dispatch ${selectedVehicle['vehicle_name']} (${selectedVehicle['vehicle_plate_number']}) to respond to the incident at ${incident['ticket_incidents_location']?.toString() ?? 'this location'}?");
      _classicDialog.setPositiveMessage("Confirm");
      _classicDialog.setNegativeMessage("Cancel");

      _classicDialog.showTwoButtonDialog(context, (negativeClick) {
        _classicDialog.dismissDialog();
      }, (positiveClicked) async {
        _classicDialog.dismissDialog();

        try {
          final vId = selectedVehicle['vehicle_id'].toString();
          final iId = incident['ticket_id'].toString();

          await _saveLocalState(vId, iId);

          if (mounted) {
            setState(() {
              _activelyTrackedVehicleId = vId;
              _activelyTrackedIncident = incident;
              _isTrackingPanelExpanded = true;
            });

            final coords = _parseCoordinates(selectedVehicle['vehicle_current_coordinates']);
            if (coords != null) {
              _mapController.move(coords, 15.0);
            }
          }

          _loadingDialog.showLoadingDialog(context);

          await _supabase
              .from('incidents_reports')
              .update({
            'ticket_status': 'being_responded',
            'ticket_responder_vehicle_id': selectedVehicle['vehicle_id']
          })
              .eq('ticket_id', incident['ticket_id']);

          await _supabase
              .from('vehicles')
              .update({'vehicle_status': 'dispatched'})
              .eq('vehicle_id', selectedVehicle['vehicle_id']);

          if (mounted) _loadingDialog.dismiss();

          if (mounted) {
            Utility().printLog("Successfully dispatched vehicle.");
            if (!kIsWeb) {
              await VehicleLocationStreamService().startTracking(vId);
            }
          }
        } catch (e) {
          if (mounted) _loadingDialog.dismiss();

          await _clearLocalState();
          if (mounted) {
            setState(() {
              _activelyTrackedVehicleId = null;
              _activelyTrackedIncident = null;
            });
          }
          _showError("Database Update Failed during dispatch: $e");
        }
      });
    } catch (e) {
      _showError("Critical Dispatch System Error: $e");
    }
  }

  // --- COMPLETE INCIDENT ACTION ---
  Future<void> _resolveIncident() async {
    try {
      if (_activelyTrackedIncident == null || _activelyTrackedVehicleId == null) return;

      _classicDialog.setTitle("Resolve Incident");
      _classicDialog.setMessage("Mark this incident as resolved and return the vehicle to available status?");
      _classicDialog.setPositiveMessage("Resolve");
      _classicDialog.setNegativeMessage("Cancel");

      _classicDialog.showTwoButtonDialog(context, (negativeClick) {
        _classicDialog.dismissDialog();
      }, (positiveClicked) async {
        _classicDialog.dismissDialog();

        try {
          _loadingDialog.showLoadingDialog(context);

          await _supabase
              .from('incidents_reports')
              .update({'ticket_status': 'resolved'})
              .eq('ticket_id', _activelyTrackedIncident!['ticket_id']);

          await _supabase
              .from('vehicles')
              .update({'vehicle_status': 'available'})
              .eq('vehicle_id', _activelyTrackedVehicleId!);

          await _clearLocalState();

          if (mounted) _loadingDialog.dismiss();

          if (!kIsWeb) {
            await VehicleLocationStreamService().stopTracking();
          }

          if (mounted) {
            setState(() {
              _activelyTrackedVehicleId = null;
              _activelyTrackedIncident = null;
            });
            _mapController.move(_defaultCenter, 10.5);
          }
        } catch (e) {
          if (mounted) _loadingDialog.dismiss();
          _showError("Failed to update database on resolution: $e");
        }
      });
    } catch (e) {
      _showError("System Error during resolution: $e");
    }
  }

  // --- OPEN NAVIGATION APP ---
  Future<void> _openNavigation() async {
    try {
      if (_activelyTrackedIncident == null) return;

      final coords = _parseCoordinates(_activelyTrackedIncident!['ticket_incidents_coordinates']);
      if (coords == null) {
        _showError("Cannot get the exact coordinates for this incident.");
        return;
      }

      final Uri googleMapsUrl = Uri.parse('http://maps.google.com/maps?daddr=${coords.latitude},${coords.longitude}');

      if (!await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication)) {
        if(mounted) _showError("Failed to open the map application.");
      }
    } catch (e) {
      _showError("Navigation Error: $e");
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
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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

              // THE MARKERS - WRAPPED IN BUILDER
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

          // OVERLAYS
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

          // ACTIVE TRACKING UI OVERLAY (EXPANDED OR COLLAPSED)
          if (_activelyTrackedVehicleId != null)
            Builder(
              builder: (context) {
                if (_isTrackingPanelExpanded) {
                  return _buildActiveTrackingPanel();
                }
                return const SizedBox.shrink();
              },
            ),

          // MINIMIZED FLOATING BUTTON (Shows when panel is collapsed)
          if (_activelyTrackedVehicleId != null && !_isTrackingPanelExpanded)
            Positioned(
              left: 16,
              bottom: 32,
              child: FloatingActionButton.extended(
                heroTag: "expand_tracking_panel",
                backgroundColor: primaryDark,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.gps_fixed_rounded, color: Colors.blueAccent),
                label: const Text("View Dispatch", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                onPressed: () {
                  setState(() {
                    _isTrackingPanelExpanded = true;
                  });
                },
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
    try {
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
                final isTrackedByMe = _activelyTrackedIncident != null && _activelyTrackedIncident!['ticket_id'] == incident['ticket_id'];

                polylines.add(
                  Polyline(
                    points: [vCoords, iCoords],
                    color: isTrackedByMe ? Colors.blueAccent : const Color(0xFFF59E0B),
                    strokeWidth: 4.0,
                  ),
                );
              }
            }
          }
        }
      }
    } catch (e) {
      Utility().printLog("Polyline rendering error: $e");
    }
    return polylines;
  }

  // --- MARKER GENERATOR ---
  List<Marker> _generateMarkers() {
    final mapMarkers = <Marker>[];
    try {
      // Vehicles
      for (var v in _fleetData) {
        final coords = _parseCoordinates(v['vehicle_current_coordinates']);
        if (coords == null) continue;

        final isTracked = _activelyTrackedVehicleId == v['vehicle_id'].toString();

        mapMarkers.add(_buildMarker(
          keyId: 'veh_${v['vehicle_id']}',
          point: coords,
          color: isTracked ? Colors.blueAccent : _getStatusColor(v['vehicle_status']?.toString() ?? ''),
          icon: _getTypeIcon(v['vehicle_type']?.toString() ?? ''),
          label: isTracked ? "RESPONDING" : v['vehicle_name']?.toString(),
          data: v,
          isIncident: false,
          isPulsing: isTracked,
        ));
      }

      // Incidents
      for (var i in _incidentData) {
        final coords = _parseCoordinates(i['ticket_incidents_coordinates']);
        if (coords == null) continue;

        final isTrackedIncident = _activelyTrackedIncident != null && _activelyTrackedIncident!['ticket_id'] == i['ticket_id'];
        final isRespondedByOther = i['ticket_status']?.toString().toLowerCase() == 'being_responded' && !isTrackedIncident;

        Color mColor = emergencyRed;
        IconData mIcon = Icons.crisis_alert_rounded;
        String mLabel = "ALERT";
        bool mPulse = false;

        if (isTrackedIncident) {
          mColor = Colors.blueAccent;
          mIcon = Icons.local_police_rounded;
          mLabel = "TARGET";
          mPulse = false;
        } else if (isRespondedByOther) {
          mColor = const Color(0xFFF59E0B); // Amber
          mIcon = Icons.directions_run_rounded;
          mLabel = "ALERT";
          mPulse = false;
        } else {
          mPulse = true;
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
    } catch (e) {
      Utility().printLog("Marker generation error: $e");
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
        onTap: () {
          try {
            if (isIncident) {
              final status = data['ticket_status']?.toString().toLowerCase();
              final isTrackedByMe = _activelyTrackedIncident != null && _activelyTrackedIncident!['ticket_id'] == data['ticket_id'];

              if (status == 'being_responded' && !isTrackedByMe) {
                final rId = data['ticket_responder_vehicle_id']?.toString();
                String plate = "Another unit";

                if (rId != null) {
                  final v = _fleetData.firstWhere((v) => v['vehicle_id'].toString() == rId, orElse: () => <String,dynamic>{});
                  if (v.isNotEmpty) plate = "Unit ${v['vehicle_plate_number']}";
                }

                SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "$plate is already responding to this alert.");
                return;
              }
            }
            _showDetailsSheet(data, isIncident);
          } catch (e) {
            _showError("Error accessing marker data: $e");
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            (isIncident || isPulsing)
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

  // --- BOTTOM SHEET UI ---
  void _showDetailsSheet(Map<String, dynamic> data, bool isIncident) {
    try {
      bool isMyActiveTarget = isIncident && _activelyTrackedIncident != null && data['ticket_id'] == _activelyTrackedIncident!['ticket_id'];
      bool isMyActiveVehicle = !isIncident && _activelyTrackedVehicleId != null && data['vehicle_id'].toString() == _activelyTrackedVehicleId;
      bool showCombinedActiveTrackingSheet = isMyActiveTarget || isMyActiveVehicle;

      if (!showCombinedActiveTrackingSheet && _activelyTrackedVehicleId != null && isIncident) {
        SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Please resolve the active dispatch first.");
        return;
      }

      final availableVehicles = _fleetData
          .where((v) => v['vehicle_status']?.toString().toLowerCase() == 'available')
          .toList();

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) {
          Map<String, dynamic>? selectedVehicle;

          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                return Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.85,
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: primaryDark.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, -8),
                      )
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 48, height: 4,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(10)),
                          ),
                        ),

                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ====================================================================
                                // COMBINED VIEW: Active Dispatch Details
                                // ====================================================================
                                if (showCombinedActiveTrackingSheet) ...[
                                  Builder(
                                    builder: (context) {
                                      Map<String, dynamic> iData = _activelyTrackedIncident!;
                                      Map<String, dynamic> vData = _fleetData.firstWhere(
                                              (v) => v['vehicle_id'].toString() == _activelyTrackedVehicleId,
                                          orElse: () => <String, dynamic>{}
                                      );

                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.blueAccent)),
                                                child: const Text("ACTIVE DISPATCH INFO", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueAccent, letterSpacing: 0.5)),
                                              )
                                            ],
                                          ),
                                          const SizedBox(height: 16),

                                          // --- TARGET DETAILS ---
                                          Row(
                                            children: [
                                              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: emergencyRed.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.crisis_alert, color: emergencyRed)),
                                              const SizedBox(width: 12),
                                              Expanded(child: Text("TARGET: ${iData['ticket_incidents_type']?.toString() ?? 'Emergency'}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: primaryDark))),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          _buildSheetRow(Icons.location_on, "Location", iData['ticket_incidents_location']?.toString() ?? 'Unknown Location'),
                                          _buildSheetRow(Icons.phone, "Contact", iData['ticket_incidents_contact_number']?.toString() ?? 'N/A'),
                                          const SizedBox(height: 4),
                                          const Text("Description", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                                          const SizedBox(height: 4),
                                          Text(iData['ticket_incidents_description']?.toString() ?? 'No description provided.', style: TextStyle(color: primaryDark, fontSize: 13)),

                                          const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 20),
                                            child: Divider(height: 1),
                                          ),

                                          // --- RESPONDER DETAILS ---
                                          Row(
                                            children: [
                                              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.directions_car, color: Colors.blueAccent)),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text("RESPONDER: ${vData['vehicle_name']?.toString() ?? 'Unit'}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: primaryDark)),
                                                    Text(vData['vehicle_plate_number']?.toString() ?? 'No Plate', style: TextStyle(fontWeight: FontWeight.bold, color: textSecondary, fontSize: 13)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              _buildChip("DISPATCHED", _getStatusColor('dispatched')),
                                              const SizedBox(width: 8),
                                              _buildChip((vData['vehicle_type'] ?? 'General').toString().toUpperCase(), primaryDark),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          _buildSheetRow(Icons.account_balance, "Municipality", vData['vehicle_municipal_owner']?.toString() ?? 'N/A'),
                                          _buildSheetRow(Icons.build, "Model", vData['vehicle_model']?.toString() ?? 'N/A'),
                                        ],
                                      );
                                    },
                                  )
                                ]

                                // ====================================================================
                                // STANDARD VIEW: Unhandled Incident
                                // ====================================================================
                                else if (isIncident) ...[
                                  Row(
                                    children: [
                                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: emergencyRed.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.crisis_alert, color: emergencyRed)),
                                      const SizedBox(width: 12),
                                      Expanded(child: Text(data['ticket_incidents_type']?.toString() ?? 'Emergency Alert', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: primaryDark))),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildSheetRow(Icons.location_on, "Location", data['ticket_incidents_location']?.toString() ?? 'Unknown Location'),
                                  _buildSheetRow(Icons.phone, "Contact", data['ticket_incidents_contact_number']?.toString() ?? 'N/A'),
                                  const Divider(height: 16),
                                  const Text("Description", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Text(data['ticket_incidents_description']?.toString() ?? 'No description provided.', style: TextStyle(color: primaryDark, fontSize: 13)),

                                  const Divider(height: 24),

                                  const Text("Dispatch Vehicle", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  const SizedBox(height: 8),

                                  if (availableVehicles.isEmpty)
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                                          SizedBox(width: 8),
                                          Expanded(child: Text("No vehicles available for dispatch.", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 13))),
                                        ],
                                      ),
                                    )
                                  else
                                    DropdownButtonFormField<Map<String, dynamic>>(
                                      value: selectedVehicle,
                                      isExpanded: true,
                                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: textSecondary),
                                      hint: Text("Select a vehicle to dispatch", style: TextStyle(color: textSecondary, fontSize: 13)),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: bgColor,
                                        prefixIcon: Icon(Icons.directions_car_rounded, color: textSecondary.withValues(alpha: 0.7)),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      ),
                                      items: availableVehicles.map((v) {
                                        final name = v['vehicle_name']?.toString() ?? 'Unit';
                                        final plate = v['vehicle_plate_number']?.toString() ?? 'No Plate';
                                        return DropdownMenuItem<Map<String, dynamic>>(
                                          value: v,
                                          child: Text("$name ($plate)", style: TextStyle(fontWeight: FontWeight.w700, color: primaryDark, fontSize: 13)),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        setModalState(() {
                                          selectedVehicle = val;
                                        });
                                      },
                                    ),

                                  const SizedBox(height: 16),

                                  SizedBox(
                                    width: double.infinity,
                                    height: 38,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: emergencyRed,
                                        disabledBackgroundColor: emergencyRed.withValues(alpha: 0.4),
                                        foregroundColor: Colors.white,
                                        disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: selectedVehicle == null ? null : () async {
                                        try {
                                          Navigator.pop(context);
                                          await _respondToIncident(data, selectedVehicle!);
                                        } catch (e) {
                                          _showError("Action failed: $e");
                                        }
                                      },
                                      icon: const Icon(Icons.local_shipping_rounded, size: 16),
                                      label: const Text(
                                        "DISPATCH UNIT",
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                                      ),
                                    ),
                                  )
                                ]

                                // ====================================================================
                                // STANDARD VIEW: Free Vehicle
                                // ====================================================================
                                else ...[
                                    Row(
                                      children: [
                                        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.directions_car, color: Colors.blue)),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(data['vehicle_name']?.toString() ?? 'Fleet Unit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: primaryDark)),
                                              Text(data['vehicle_plate_number']?.toString() ?? 'No Plate', style: TextStyle(fontWeight: FontWeight.bold, color: textSecondary, fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        _buildChip((data['vehicle_status'] ?? 'Unknown').toString().toUpperCase(), _getStatusColor(data['vehicle_status']?.toString() ?? '')),
                                        const SizedBox(width: 8),
                                        _buildChip((data['vehicle_type'] ?? 'General').toString().toUpperCase(), primaryDark),
                                      ],
                                    ),
                                    const Divider(height: 24),
                                    _buildSheetRow(Icons.account_balance, "Municipality", data['vehicle_municipal_owner']?.toString() ?? 'N/A'),
                                    _buildSheetRow(Icons.build, "Model", data['vehicle_model']?.toString() ?? 'N/A'),
                                  ],

                                const SizedBox(height: 4),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
          );
        },
      );
    } catch (e) {
      _showError("Failed to open details panel: $e");
    }
  }

  // --- PREMIUM ACTIVE TRACKING UI ---
  Widget _buildActiveTrackingPanel() {
    final trackedVehicle = _fleetData.firstWhere(
          (v) => v['vehicle_id'].toString() == _activelyTrackedVehicleId,
      orElse: () => <String, dynamic>{},
    );
    final vName = trackedVehicle['vehicle_name']?.toString() ?? 'Fleet Unit';
    final vPlate = trackedVehicle['vehicle_plate_number']?.toString() ?? 'No Plate';
    final vType = trackedVehicle['vehicle_type']?.toString().toUpperCase() ?? 'GENERAL';

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: primaryDark.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, -8),
            )
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.blueAccent, blurRadius: 6)],
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text("ACTIVE DISPATCH", style: TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isTrackingPanelExpanded = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                      child: Icon(Icons.keyboard_arrow_down_rounded, size: 24, color: textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: emergencyRed.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(Icons.crisis_alert_rounded, color: emergencyRed, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_activelyTrackedIncident?['ticket_incidents_type']?.toString() ?? "Emergency Response", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: primaryDark, letterSpacing: -0.5)),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on_rounded, size: 14, color: textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(_activelyTrackedIncident?['ticket_incidents_location']?.toString() ?? 'Unknown Destination', style: TextStyle(fontSize: 13, color: textSecondary, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.directions_car_rounded, color: Colors.blueAccent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(vName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: primaryDark)),
                          Text("$vPlate • $vType", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blueAccent,
                          side: const BorderSide(color: Colors.blueAccent, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _openNavigation,
                        icon: const Icon(Icons.navigation_rounded, size: 20),
                        label: const Text("NAVIGATE", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          shadowColor: const Color(0xFF10B981).withValues(alpha: 0.4),
                        ),
                        onPressed: _resolveIncident,
                        icon: const Icon(Icons.check_circle_rounded, size: 20),
                        label: const Text("RESOLVE", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.5))),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color)),
    );
  }

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
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)]
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
                      ],
                    )
                )
              ]
          )
      )
  );

  Widget _buildMapControls() => Positioned(
      right: 16,
      bottom: (_activelyTrackedVehicleId != null && _isTrackingPanelExpanded) ? 360 : 32,
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
