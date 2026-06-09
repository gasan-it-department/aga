
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class FacebookFollowDialog extends StatelessWidget {
  final String pageUrl;
  final String pageName;

  const FacebookFollowDialog({
    super.key,
    required this.pageUrl,
    this.pageName = "AGA",
  });

  /// Easily trigger the dialog from anywhere
  static void show(BuildContext context, {required String url, String pageName = "AGA"}) {
    showDialog(
      context: context,
      barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.7), // Premium dark overlay
      builder: (context) => FacebookFollowDialog(pageUrl: url, pageName: pageName),
    );
  }

  Future<void> _launchFacebook(BuildContext context) async {
    final Uri url = Uri.parse(pageUrl);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Could not open Facebook. Please check your connection."),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error opening link: $e"),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }

    // Close the dialog after attempting to open the link
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color facebookBlue = Color(0xFF1877F2);
    const Color textPrimary = Color(0xFF1E293B);
    const Color textSecondary = Color(0xFF64748B);

    final screenW = MediaQuery.of(context).size.width;
    final double inset = screenW < 360 ? 16 : 24;
    final double maxW = screenW >= 600 ? 420 : double.infinity;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: inset, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          // MAIN CARD
          Container(
            margin: const EdgeInsets.only(top: 40), // Space for the floating icon
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Follow $pageName on Facebook",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "Stay updated with $pageName for the latest news, announcements, and community alerts straight to your feed.",
                  style: const TextStyle(
                    fontSize: 14,
                    color: textSecondary,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // FOLLOW BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: facebookBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: facebookBlue.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => _launchFacebook(context),
                    icon: const Icon(Icons.facebook_rounded, size: 24),
                    label: const Text(
                      "FOLLOW ON FACEBOOK",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // CANCEL BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: textSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      "Maybe Later",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // FLOATING FACEBOOK ICON
          Positioned(
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: facebookBlue.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: facebookBlue,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.facebook_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
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
