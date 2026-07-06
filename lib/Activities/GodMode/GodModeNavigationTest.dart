import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/AGANavigationSystem/aga_navigation_system.dart';

class GodModeNavigationTest extends StatefulWidget {
  const GodModeNavigationTest({super.key});

  @override
  State<GodModeNavigationTest> createState() => _GodModeNavigationTestState();
}

class _GodModeNavigationTestState extends State<GodModeNavigationTest> {
  late final NavigationController _controller;
  final _latCtrl = TextEditingController(text: '13.4767');
  final _lngCtrl = TextEditingController(text: '121.9032');

  static const _bg = Color(0xFFF8FAFC);
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _line = Color(0xFFE2E8F0);
  static const _blue = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    final config = NavigationConfig.defaults(
      osrmBaseUrl: 'https://router.project-osrm.org',
    );
    _controller = NavigationController(
      config: config,
      routingService: GoogleRoutesRoutingService(
        config: config,
        apiKey: 'AIzaSyATxZHc4q-S0Gjl7YMEqUdl-UEVZYfQfFU',
      ),
    );
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    if (lat == null || lng == null) {
      _snack('Enter valid destination coordinates.');
      return;
    }
    await _controller.startNavigation(
      destination: NavigationCoordinate(
        latitude: lat,
        longitude: lng,
        accuracyMeters: 0,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _stop() => _controller.stopNavigation();

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        title: const Text(
          'AGA Navigation Test',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final state = _controller.state;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _hero(),
              const SizedBox(height: 14),
              _destinationCard(),
              const SizedBox(height: 14),
              SizedBox(
                height: 260,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: _line),
                    ),
                    child: AgaNavigationMap(navigationState: state),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              AgaNavigationStatus(state: state),
            ],
          );
        },
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A2E5C), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Icon(Icons.route_rounded, color: Colors.white, size: 34),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Navigation System Sandbox',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Test GPS, OSRM route, ETA, off-route and arrival detection.',
                  style: TextStyle(
                    color: Color(0xFFE0F2FE),
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _destinationCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Destination',
            style: TextStyle(
              color: _ink,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _input(_latCtrl, 'Latitude')),
              const SizedBox(width: 10),
              Expanded(child: _input(_lngCtrl, 'Longitude')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _start,
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    minimumSize: const Size.fromHeight(46),
                  ),
                  icon: const Icon(Icons.navigation_rounded),
                  label: const Text('Start Test'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                onPressed: _stop,
                tooltip: 'Stop',
                icon: const Icon(Icons.stop_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Uses Google Routes API for traffic-aware ETA in this test screen.',
            style: TextStyle(
              color: _muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _input(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        signed: true,
        decimal: true,
      ),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
