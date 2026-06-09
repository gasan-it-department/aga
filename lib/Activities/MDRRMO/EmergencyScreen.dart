import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Dialogs/EmergencyQRDialog.dart';
import 'package:gasan_port_tracker/Dialogs/DownloadEmergencyQRDialog.dart';
import 'package:gasan_port_tracker/Utility/ImageDirectory.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/FloatingMessages/SnackbarMessenger.dart';

import '../../Dialogs/Bottomsheets/CreateEmergencyResponseTicket.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryColor = const Color(0xFF0A2E5C);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);

  bool _isFetchingLocation = false;
  Position? _cachedPosition;

  final List<Map<String, dynamic>> _emergencyContacts = [
    {
      "title": "GASAN DRRM",
      "number": "0909-109-992",
      "icon": Image.asset(ImageDirectory().getGasanLogo(), width: 30, height: 30,),
      "color": const Color(0xFFDC2626),
      "bgColor": const Color(0xFFFEF2F2),
    },
    {
      "title": "SANTA CRUZ DRRM",
      "number": "0951-733-3357",
      "icon": Image.asset(ImageDirectory().getSantaCruzLogo(), width: 30, height: 30,),
      "color": const Color(0xFFDC2626),
      "bgColor": const Color(0xFFFEF2F2),
    },
    {
      "title": "BUENAVISTA DRRM",
      "number": "0947-761-3187",
      "icon": Image.asset(ImageDirectory().getBuenavistaLogo(), width: 30, height: 30),
      "color": const Color(0xFFDC2626),
      "bgColor": const Color(0xFFFEF2F2),
    },
    {
      "title": "TORRIJOS DRRM",
      "number": "0967-306-7372",
      "icon": Image.asset(ImageDirectory().getTorrijosLogo(), width: 30, height: 30),
      "color": const Color(0xFFDC2626),
      "bgColor": const Color(0xFFFEF2F2),
    },
    {
      "title": "BOAC DRRM",
      "number": "0960-585-8800",
      "icon": Image.asset(ImageDirectory().getBoacLogo(), width: 30, height: 30),
      "color": const Color(0xFFDC2626),
      "bgColor": const Color(0xFFFEF2F2),
    },
    {
      "title": "MOGPOG DRRM",
      "number": "0917-813-7880",
      "icon": Image.asset(ImageDirectory().getMogpogLogo(), width: 30, height: 30),
      "color": const Color(0xFFDC2626),
      "bgColor": const Color(0xFFFEF2F2),
    },
    {
      "title": "MARINDUQUE PROV. DRRM",
      "number": "0968-226-5727",
      "icon": Image.asset(ImageDirectory().getBuenavistaLogo(), width: 30, height: 30),
      "color": const Color(0xFFDC2626),
      "bgColor": const Color(0xFFFEF2F2),
    },
  ];

  @override
  void initState() {
    super.initState();
    _preloadLocation();
  }

  Future<void> _preloadLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      _cachedPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      debugPrint("Location pre-loaded successfully.");
    } catch (e) {
      debugPrint("Pre-loading location failed: $e");
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri launchUri = Uri(scheme: 'tel', path: cleanNumber);

    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        final bool launched = await launchUrl(launchUri, mode: LaunchMode.externalApplication);
        if (!launched && mounted) {
          SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Cannot launch phone dialer.");
        }
      }
    } catch (e) {
      if (mounted) SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Error making call: $e");
    }
  }

  Future<void> _handleEmergencyText(String phoneNumber) async {
    setState(() => _isFetchingLocation = true);
    String finalMessage = "AGA EMERGENCY:\n"
        "I NEED IMMEDIATE HELP!\n"
        "Please send rescue to my location.";
    Position? positionToUse = _cachedPosition;

    if (positionToUse == null) {
      if (mounted) {
        SnackbarMessenger().showSnackbar(context, SnackbarMessenger.neutral, "Securing live location...");
      }
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) throw Exception("GPS is disabled.");

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) throw Exception("Location permission denied.");
        }
        if (permission == LocationPermission.deniedForever) {
          throw Exception("Location permissions permanently denied.");
        }

        positionToUse = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (e) {
        debugPrint("Live fetch failed: $e");
      }
    }

    if (positionToUse != null) {
      finalMessage += "\n\nMy Exact Location: http://maps.google.com/maps?q=${positionToUse.latitude},${positionToUse.longitude}";
    }

    setState(() => _isFetchingLocation = false);
    await _sendSMS(phoneNumber, finalMessage);
  }

  Future<void> _sendSMS(String phoneNumber, String message) async {
    final String encodedMessage = Uri.encodeComponent(message);

    String uriString;
    if (kIsWeb) {
      uriString = 'sms:$phoneNumber?body=$encodedMessage';
    } else if (Platform.isIOS) {
      uriString = 'sms:$phoneNumber&body=$encodedMessage';
    } else {
      uriString = 'sms:$phoneNumber?body=$encodedMessage';
    }

    final Uri launchUri = Uri.parse(uriString);

    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        final bool launched = await launchUrl(launchUri, mode: LaunchMode.externalApplication);
        if (!launched && mounted) {
          SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Cannot open messaging app.");
        }
      }
    } catch (e) {
      if (mounted) SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Error sending message: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "Emergency Hotlines",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5, fontSize: 20),
        ),
      ),

      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Utility().getMaxScreenSize()),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 16),

                  // RESPONSE TICKET CARD
                  _buildTicketCard(),

                  const SizedBox(height: 24),

                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 12),
                    child: Text(
                      "QUICK ACTION",
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),

                  ..._emergencyContacts.map((contact) => _buildEmergencyCard(contact)),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF991B1B), Color(0xFFDC2626)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
          )
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -20,
            top: -10,
            child: Icon(
              Icons.emergency_share_rounded,
              size: 140,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sensors_rounded, color: Color(0xFFDC2626), size: 16),
                      SizedBox(width: 6),
                      Text(
                        "SOS ALERT",
                        style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  "EMERGENCY DISPATCH",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.only(left: 14),
                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: Color(0xFFFBBF24),
                        width: 4,
                      ),
                    ),
                  ),
                  child: Text(
                    "Only use for true emergencies. Tapping 'TEXT' will instantly transmit your exact GPS coordinates to Marinduque responders.",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- RESPONSE TICKET CARD ---
  Widget _buildTicketCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // Trigger the Bottom Sheet here
            CreateEmergencyResponseTicket.show(context);
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.assignment_late_rounded, color: primaryColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Create Response Ticket",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: primaryColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Submit an incident report or request non-urgent assistance.",
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecondary,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_forward_ios_rounded, color: primaryColor.withValues(alpha: 0.6), size: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyCard(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    height: 56,
                    width: 56,
                    decoration: BoxDecoration(color: data['bgColor'], shape: BoxShape.circle),
                    child: Center(child: data["icon"] as Image),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                data['title'],
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textPrimary),
                              ),
                            ),

                            const SizedBox(width: 8),

                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Download QR Button
                                Material(
                                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () async {
                                      bool hasAccess = false;

                                      if (kIsWeb) {
                                        hasAccess = true;
                                      } else if (Platform.isAndroid) {
                                        bool isStorageGranted = await Permission.storage.isGranted;
                                        bool isPhotosGranted = await Permission.photos.isGranted;

                                        if (!isStorageGranted && !isPhotosGranted) {
                                          Map<Permission, PermissionStatus> statuses = await [
                                            Permission.storage,
                                            Permission.photos,
                                          ].request();

                                          isStorageGranted = statuses[Permission.storage]?.isGranted ?? false;
                                          isPhotosGranted = statuses[Permission.photos]?.isGranted ?? false;
                                        }

                                        hasAccess = isStorageGranted || isPhotosGranted;

                                      } else if (Platform.isIOS) {
                                        bool isPhotosGranted = await Permission.photos.isGranted || await Permission.photos.isLimited;

                                        if (!isPhotosGranted) {
                                          PermissionStatus status = await Permission.photos.request();
                                          isPhotosGranted = status.isGranted || status.isLimited;
                                        }
                                        hasAccess = isPhotosGranted;
                                      }

                                      if (!hasAccess) {
                                        if (mounted) {
                                          if (await Permission.storage.isPermanentlyDenied || await Permission.photos.isPermanentlyDenied) {
                                            if(mounted) SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Permission permanently denied. Please enable in Settings.");
                                            await openAppSettings();
                                          } else {
                                            if(mounted) SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Storage permission is required to save the QR code.");
                                          }
                                        }
                                        return;
                                      }

                                      if (mounted) {
                                        DownloadEmergencyQRDialog.show(
                                          context,
                                          title: data['title'],
                                          rawNumber: data['number'],
                                        );
                                      }
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(6.0),
                                      child: Icon(Icons.download_rounded, size: 18, color: Color(0xFF3B82F6)),
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 6),

                                // View QR Button
                                Material(
                                  color: data['color'].withValues(alpha: 0.1),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () {
                                      String qrMessage = "AGA EMERGENCY:\nI NEED IMMEDIATE HELP!\nPlease send rescue to my location.";
                                      if (_cachedPosition != null) {
                                        qrMessage += "\n\nMy Exact Location: http://maps.google.com/maps?q=${_cachedPosition!.latitude},${_cachedPosition!.longitude}";
                                      }

                                      EmergencyQRDialog.show(
                                        context,
                                        title: data['title'],
                                        rawNumber: data['number'],
                                        message: qrMessage,
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(6.0),
                                      child: Icon(Icons.qr_code_2_rounded, size: 18, color: data['color']),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        Text(
                            data['number'],
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: data['color'], letterSpacing: 0.5)
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: data['color'],
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20))),
                      ),
                      onPressed: _isFetchingLocation ? null : () => _handleEmergencyText(data['number']),
                      icon: _isFetchingLocation
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.message, size: 18),
                      label: Text(_isFetchingLocation ? "LOCATING..." : "TEXT", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    ),
                  ),
                  Container(width: 1, height: 30, color: const Color(0xFFE2E8F0)),
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: data['color'],
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomRight: Radius.circular(20))),
                      ),
                      onPressed: () => _makePhoneCall(data['number']),
                      icon: const Icon(Icons.call_rounded, size: 18),
                      label: const Text("CALL", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
