import 'dart:async';
import 'package:flutter/material.dart';

class VesselBeacon extends StatefulWidget {
  const VesselBeacon({super.key});

  @override
  State<VesselBeacon> createState() => _VesselBeaconState();
}

class _VesselBeaconState extends State<VesselBeacon> with SingleTickerProviderStateMixin {
  // --- Theme Colors ---
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryDark = const Color(0xFF0A2E5C);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);
  final Color outlineColor = const Color(0xFFE2E8F0);

  // --- State Variables ---
  String? _selectedVesselId;
  bool _isBeaconing = false;
  String _lastPingTime = "--:--";

  // --- Animation Controller for the Radar Pulse ---
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Mock list of vessels (You can replace this with your Supabase fetch logic)
  final List<Map<String, dynamic>> _myVessels = [
    {'id': 'v1', 'name': 'MV Princess of Gasan'},
    {'id': 'v2', 'name': 'MV Marinduque Star'},
    {'id': 'v3', 'name': 'RoRo Express 1'},
  ];

  @override
  void initState() {
    super.initState();

    // Setup the pulsing animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleBeacon() {
    if (_selectedVesselId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select a vessel first!"), backgroundColor: Colors.redAccent)
      );
      return;
    }

    setState(() {
      _isBeaconing = !_isBeaconing;

      if (_isBeaconing) {
        _pulseController.repeat();
        _updatePingTime();
      } else {
        _pulseController.reset();
        _pulseController.stop();
        _lastPingTime = "--:--";
      }
    });
  }

  void _updatePingTime() {
    final now = DateTime.now();
    int h = now.hour;
    int m = now.minute;
    String period = h >= 12 ? "PM" : "AM";
    if (h == 0) h = 12;
    if (h > 12) h -= 12;
    setState(() {
      _lastPingTime = "$h:${m.toString().padLeft(2, '0')} $period";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Live Beacon"),
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: primaryDark, letterSpacing: -0.5),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- 1. INSTRUCTIONS & SELECTION ---
            Text("ASSIGNED VESSEL", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: textSecondary, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: outlineColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: primaryDark.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
                  ]
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedVesselId,
                  hint: Text("Select the vessel you are commanding", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textSecondary.withValues(alpha: 0.6))),
                  icon: Icon(Icons.directions_boat_rounded, color: primaryDark),
                  items: _myVessels.map((v) {
                    return DropdownMenuItem<String>(
                      value: v['id'].toString(),
                      child: Text(v['name'].toString(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textPrimary)),
                    );
                  }).toList(),
                  onChanged: _isBeaconing ? null : (val) {
                    setState(() => _selectedVesselId = val);
                  },
                ),
              ),
            ),

            if (_isBeaconing)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Row(
                  children: [
                    const Icon(Icons.lock_rounded, size: 14, color: Colors.orange),
                    const SizedBox(width: 6),
                    Text("Vessel selection is locked while transmitting.", style: TextStyle(fontSize: 12, color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

            // --- 2. THE BIG BUTTON AREA ---
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // The Pulsing Ring (Only visible when beaconing)
                        if (_isBeaconing)
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Container(
                                  width: 200,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF10B981).withValues(alpha: 1.5 - _pulseAnimation.value),
                                  ),
                                ),
                              );
                            },
                          ),

                        // The Main Button
                        GestureDetector(
                          onTap: _toggleBeacon,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isBeaconing ? const Color(0xFF10B981) : Colors.white,
                                border: Border.all(
                                  color: _isBeaconing ? const Color(0xFF059669) : outlineColor,
                                  width: 8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                      color: _isBeaconing ? const Color(0xFF10B981).withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                      offset: const Offset(0, 10)
                                  )
                                ]
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                    _isBeaconing ? Icons.satellite_alt_rounded : Icons.radar_rounded,
                                    size: 64,
                                    color: _isBeaconing ? Colors.white : primaryDark
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _isBeaconing ? "TRANSMITTING" : "START BEACON",
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: _isBeaconing ? Colors.white : primaryDark,
                                      letterSpacing: 1.0
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // --- 3. STATUS BOARD ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _isBeaconing ? const Color(0xFFECFDF5) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _isBeaconing ? const Color(0xFF6EE7B7) : outlineColor),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("SYSTEM STATUS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: textSecondary, letterSpacing: 1.0)),
                      Row(
                        children: [
                          Container(
                            height: 8, width: 8,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: _isBeaconing ? const Color(0xFF10B981) : Colors.redAccent),
                          ),
                          const SizedBox(width: 6),
                          Text(_isBeaconing ? "LIVE" : "OFFLINE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isBeaconing ? const Color(0xFF059669) : Colors.redAccent)),
                        ],
                      )
                    ],
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Last Ping Sent:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary)),
                      Text(_lastPingTime, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _isBeaconing ? const Color(0xFF059669) : textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
