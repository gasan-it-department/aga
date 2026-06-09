import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

class ViewNotificationDialog {
  static void show(BuildContext context, Map<String, dynamic> notification) {
    final String title = notification['notification_title'] ?? 'Alert';
    final String message = notification['notification_message'] ?? 'No details provided.';
    final String type = notification['notification_source'] ?? 'maritime';
    final String displayDate = _formatDetailedDate(notification['notification_date']);

    // --- Theme Colors ---
    final Color textPrimary = const Color(0xFF1E293B);
    final Color textSecondary = const Color(0xFF64748B);
    final Color surfaceColor = const Color(0xFFF1F5F9);
    final Color accentBlue = const Color(0xFF3B82F6);

    // --- Determine Icon & Color based on Type ---
    IconData iconData;
    Color iconBgColor;
    Color iconColor;

    switch (type.toLowerCase()) {
      case 'emergency':
        iconData = Icons.warning_rounded;
        iconBgColor = const Color(0xFFFEF2F2);
        iconColor = const Color(0xFFDC2626);
        break;
      case 'warning':
        iconData = Icons.storm_rounded;
        iconBgColor = const Color(0xFFFFFBEB);
        iconColor = const Color(0xFFD97706);
        break;
      case 'success':
      case 'resolved':
        iconData = Icons.check_circle_rounded;
        iconBgColor = const Color(0xFFECFDF5);
        iconColor = const Color(0xFF10B981);
        break;
      case 'maritime':
        iconData = Icons.directions_boat_filled_rounded;
        iconBgColor = const Color(0xFFF3E8FF);
        iconColor = const Color(0xFF8B5CF6);
        break;
      case 'mdrrmo':
        iconData = Icons.campaign_rounded;
        iconBgColor = const Color(0xFFFEF2F2);
        iconColor = const Color(0xFFDC2626);
        break;
      default:
        iconData = Icons.info_rounded;
        iconBgColor = const Color(0xFFEFF6FF);
        iconColor = accentBlue;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
                        child: Icon(iconData, color: iconColor, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                                height: 1.2,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              displayDate,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                ),

                // --- MESSAGE BODY (Now with clickable links) ---
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                      child: Linkify(
                        onOpen: (link) async {
                          String urlString = link.url;
                          if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
                            urlString = 'https://$urlString';
                          }

                          final Uri url = Uri.parse(urlString);

                          try {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          } catch (e) {
                            debugPrint("Could not launch $url: $e");
                          }
                        },
                        text: message,
                        options: const LinkifyOptions(humanize: false),
                        style: TextStyle(
                          fontSize: 15,
                          color: textPrimary.withValues(alpha: 0.85),
                          height: 1.6,
                        ),
                        linkStyle: TextStyle(
                          fontSize: 15,
                          color: accentBlue,
                          height: 1.6,
                          fontWeight: FontWeight.normal,
                          decoration: TextDecoration.underline,
                          decorationColor: accentBlue,
                          decorationThickness: 2.0,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // --- FOOTER BUTTON ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: surfaceColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        "Close",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _formatDetailedDate(dynamic epochValue) {
    if (epochValue == null) return "Unknown Date & Time";
    int epoch = int.tryParse(epochValue.toString()) ?? 0;
    if (epoch == 0) return "Unknown Date & Time";

    final date = DateTime.fromMillisecondsSinceEpoch(epoch);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    String month = months[date.month - 1];
    String day = date.day.toString().padLeft(2, '0');
    String year = date.year.toString();

    int hour = date.hour;
    String period = hour >= 12 ? 'PM' : 'AM';
    if (hour == 0) hour = 12;
    if (hour > 12) hour -= 12;

    String strHour = hour.toString().padLeft(2, '0');
    String strMinute = date.minute.toString().padLeft(2, '0');

    return "$month $day, $year • $strHour:$strMinute $period";
  }
}
