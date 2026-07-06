import 'dart:convert';
import 'dart:io' show Platform; // --- NEW: To check Android vs iOS ---
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gasan_port_tracker/FloatingMessages/SnackbarMessenger.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:universal_html/html.dart' as html;
import 'package:permission_handler/permission_handler.dart'; // --- NEW: Permission handling ---

class DownloadEmergencyQRDialog {
  static void show(
    BuildContext context, {
    required String title,
    required String rawNumber,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (BuildContext context) {
        return _DownloadQRDialogContent(title: title, rawNumber: rawNumber);
      },
    );
  }
}

class _DownloadQRDialogContent extends StatefulWidget {
  final String title;
  final String rawNumber;

  const _DownloadQRDialogContent({
    required this.title,
    required this.rawNumber,
  });

  @override
  State<_DownloadQRDialogContent> createState() =>
      _DownloadQRDialogContentState();
}

class _DownloadQRDialogContentState extends State<_DownloadQRDialogContent> {
  final GlobalKey _qrBoundaryKey = GlobalKey();

  bool _isSaving = false;

  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);
  final Color activeColor = const Color(0xFFDC2626);
  final Color primaryDark = const Color(0xFF0A2E5C);

  String get _qrData {
    return widget.rawNumber.replaceAll(RegExp(r'[^\d+]'), '');
  }

  Future<void> _captureAndSaveQR() async {
    setState(() => _isSaving = true);

    try {
      if (!kIsWeb) {
        PermissionStatus status;

        if (Platform.isIOS) {
          status = await Permission.photosAddOnly.request();
          if (status.isDenied) status = await Permission.photos.request();
        } else {
          // Android saves through MediaStore and selects images through the
          // system Photo Picker, so broad storage/media access is unnecessary.
          status = PermissionStatus.granted;
        }

        if (!status.isGranted && !status.isLimited) {
          setState(() => _isSaving = false);
          if (mounted) {
            SnackbarMessenger().showSnackbar(
              context,
              SnackbarMessenger.failed,
              "Permission is denied. Please enable it in the settings.",
            );
          }
          return;
        }
      }

      RenderRepaintBoundary boundary =
          _qrBoundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      bool success = false;
      final String fileName =
          "AGA_Emergency_${widget.title.replaceAll(' ', '_')}.png";

      if (kIsWeb) {
        final base64data = base64Encode(pngBytes);
        final a = html.AnchorElement(href: 'data:image/png;base64,$base64data');
        a.download = fileName;
        a.click();
        a.remove();
        success = true;
      } else {
        final result = await ImageGallerySaverPlus.saveImage(
          pngBytes,
          quality: 100,
          name: fileName.replaceAll('.png', ''),
        );
        if (result != null && result['isSuccess'] == true) {
          success = true;
        }
      }

      if (mounted) {
        setState(() => _isSaving = false);

        if (success) {
          Navigator.pop(context);
          SnackbarMessenger().showSnackbar(
            context,
            SnackbarMessenger.success,
            kIsWeb ? "QR Code downloaded" : "QR Code saved to gallery",
          );
        } else {
          throw Exception("Could not write file to storage.");
        }
      }
    } catch (e) {
      debugPrint("Error saving QR: $e");
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to save. Please check permissions."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Save QR Code",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              kIsWeb
                  ? "Download this card to your device to access this emergency contact offline."
                  : "Download this card to your gallery to access this emergency contact offline.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: textSecondary,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 24),

            RepaintBoundary(
              key: _qrBoundaryKey,
              child: Container(
                width: 250,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: activeColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "AGA EMERGENCY",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(20),
                      child: QrImageView(
                        data: _qrData, // Plain number
                        version: QrVersions.auto,
                        size: 160.0,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: primaryDark,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: textPrimary,
                        ),
                      ),
                    ),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(18),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "EMERGENCY HOTLINE",
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.rawNumber,
                            style: TextStyle(
                              color: primaryDark,
                              fontSize: 16,
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

            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6), // accentBlue
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _isSaving ? null : _captureAndSaveQR,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.download_rounded, size: 18),
                      label: Text(
                        _isSaving ? "Saving..." : "Save",
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
