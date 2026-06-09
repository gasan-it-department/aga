import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DictElguCard extends StatelessWidget {
  const DictElguCard({super.key});

  static const String _elguUrl = "https://elgu-gasan-marinduque.e.gov.ph/";

  Future<void> _open() async {
    final uri = Uri.parse(_elguUrl);
    final isAndroid = !kIsWeb && Platform.isAndroid;
    try {
      await launchUrl(
        uri,
        mode: isAndroid ? LaunchMode.inAppBrowserView : LaunchMode.externalApplication,
      );
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryBlue = const Color(0xFF2563EB);
    final accentBlue = const Color(0xFF1E40AF);
    final primaryDark = const Color(0xFF0F172A);
    final textSecondary = const Color(0xFF64748B);
    final cardBorder = const Color(0xFFE2E8F0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
            child: Row(children: [
              Container(width: 3, height: 16, decoration: BoxDecoration(color: primaryBlue, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text("FOR BUSINESS OWNERS", style: TextStyle(fontWeight: FontWeight.w900, color: primaryDark, fontSize: 12, letterSpacing: 1)),
            ]),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _open,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [accentBlue, primaryBlue], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder),
                  boxShadow: [BoxShadow(color: primaryBlue.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.25))),
                      child: const Icon(Icons.business_center_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withValues(alpha: 0.3))),
                            child: const Text("DICT · eLGU", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 9.5, letterSpacing: 0.8)),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Apply for Mayor's Permit Online",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: -0.2),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "File and renew your Business Mayor's Permit for Gasan, Marinduque online via the official DICT eLGU portal.",
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11.5, height: 1.4),
                          ),
                          const SizedBox(height: 8),
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.open_in_new_rounded, color: accentBlue, size: 13),
                                const SizedBox(width: 4),
                                Text("Open Portal", style: TextStyle(color: accentBlue, fontWeight: FontWeight.w900, fontSize: 11)),
                              ]),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.verified_rounded, color: textSecondary, size: 12),
            const SizedBox(width: 4),
            Expanded(child: Text("Official Government Service · elgu-gasan-marinduque.e.gov.ph", style: TextStyle(color: textSecondary, fontSize: 10.5, fontWeight: FontWeight.w600))),
          ]),
        ],
      ),
    );
  }
}
