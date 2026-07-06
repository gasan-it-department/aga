import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gasan_port_tracker/FloatingMessages/SnackbarMessenger.dart';

class MapLocationPicker extends StatefulWidget {
  final LatLng? initialLocation;

  const MapLocationPicker({
    super.key,
    this.initialLocation,
  });

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  LatLng? _currentLocation;
  bool _isLoading = false;
  bool _isSatellite = false; // Added: State to track map type
  final MapController _mapController = MapController();

  final LatLng _defaultFallback = const LatLng(13.3941, 121.9564);

  @override
  void initState() {
    super.initState();
    // Always fetch and pan to the user's current location, regardless of initialLocation.
    _currentLocation = widget.initialLocation;
    _fetchCurrentLocation(panTo: true);
  }

  Future<void> _fetchCurrentLocation({bool panTo = false}) async {
    setState(() => _isLoading = _currentLocation == null);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception("Location services are disabled.");

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception("Location permissions are denied.");
      }

      if (permission == LocationPermission.deniedForever) throw Exception("Location permissions are permanently denied.");

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final liveLatLng = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _currentLocation = liveLatLng;
          _isLoading = false;
        });
        if (panTo) {
          try { _mapController.move(liveLatLng, 16); } catch (_) {}
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentLocation ??= _defaultFallback;
          _isLoading = false;
        });
        SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Failed to get live location. Using default center.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0A2E5C),
        elevation: 0,
        title: const Text("Pin Location", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
      ),
      body: _isLoading || _currentLocation == null
          ? const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF0A2E5C)),
            SizedBox(height: 16),
            Text("Detecting your location...", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ],
        ),
      )
          : Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation!,
              initialZoom: 14.5,
              interactionOptions: const InteractionOptions(
                // Locked rotation as per previous preference
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) {
                  setState(() {
                    _currentLocation = camera.center;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                // Switch between OSM and Esri Satellite
                urlTemplate: _isSatellite
                    ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                    : 'https://cartodb-basemaps-a.global.ssl.fastly.net/light_nolabels/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.gasan.port_tracker',
              ),
            ],
          ),

          // Satellite Toggle Button
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 4))
                  ]
              ),
              child: IconButton(
                tooltip: _isSatellite ? "Switch to Standard" : "Switch to Satellite",
                icon: Icon(
                  _isSatellite ? Icons.layers_outlined : Icons.layers_rounded,
                  color: const Color(0xFF0A2E5C),
                ),
                onPressed: () {
                  setState(() {
                    _isSatellite = !_isSatellite;
                  });
                },
              ),
            ),
          ),

          // Centered Pin Icon
          Center(
            child: Transform.translate(
              offset: const Offset(0, -22.5),
              child: const Icon(Icons.location_pin, color: Colors.red, size: 45),
            ),
          ),

          // Floating Confirm Button
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))
                    ]
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        "Lat: ${_currentLocation!.latitude.toStringAsFixed(5)}, Lon: ${_currentLocation!.longitude.toStringAsFixed(5)}",
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A2E5C),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pop(context, _currentLocation);
                        },
                        child: const Text("CONFIRM LOCATION", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
