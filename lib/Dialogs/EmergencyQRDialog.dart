import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class EmergencyQRDialog {
  static void show(BuildContext context, {required String title, required String rawNumber, required String message}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _EmergencyQRDialogContent(
          title: title,
          rawNumber: rawNumber,
          message: message,
        );
      },
    );
  }
}

class _EmergencyQRDialogContent extends StatefulWidget {
  final String title;
  final String rawNumber;
  final String message;

  const _EmergencyQRDialogContent({
    required this.title,
    required this.rawNumber,
    required this.message,
  });

  @override
  State<_EmergencyQRDialogContent> createState() => _EmergencyQRDialogContentState();
}

class _EmergencyQRDialogContentState extends State<_EmergencyQRDialogContent> {
  bool _isTextTab = true;

  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);
  final Color activeColor = const Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    String cleanNumber = widget.rawNumber.replaceAll(RegExp(r'[^\d+]'), '');

    if (cleanNumber.startsWith('09') && cleanNumber.length == 11) {
      cleanNumber = '+63${cleanNumber.substring(1)}';
    }

    final String qrData;
    if (_isTextTab) {
      final String encodedMessage = Uri.encodeQueryComponent(widget.message);
      qrData = "sms:$cleanNumber?body=$encodedMessage";
    } else {
      qrData = "tel:$cleanNumber";
    }

    return Dialog(
      backgroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Title Header ---
            Text(
              "SCAN TO ${_isTextTab ? "TEXT" : "CALL"}",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: textSecondary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),

            // --- DISPLAY THE NUMBER ---
            Text(
              widget.rawNumber,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: activeColor,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 20),

            // --- Modern Segmented Tab Bar ---
            Container(
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9), // Slate background
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isTextTab = true),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _isTextTab ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _isTextTab
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "Text Message",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: _isTextTab ? activeColor : textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isTextTab = false),
                      child: Container(
                        decoration: BoxDecoration(
                          color: !_isTextTab ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: !_isTextTab
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "Phone Call",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: !_isTextTab ? activeColor : textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- The QR Code ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 180.0,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: activeColor,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- Instructions ---
            Text(
              _isTextTab
                  ? "Point any smartphone camera at this code to automatically draft an emergency text."
                  : "Point any smartphone camera at this code to automatically dial this emergency number.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: textSecondary,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
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
                  "Close",
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
