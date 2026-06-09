import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/Database/SupabaseUtility.dart';

class About extends StatelessWidget {
  const About({super.key});

  static const Color bgColor = Color(0xFFF1F5F9);
  static const Color primaryDark = Color(0xFF0A2E5C);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color outlineColor = Color(0xFFE2E8F0);

  Future<void> _launch(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildHero(context),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildSectionCard(
                      title: "OUR MISSION",
                      icon: Icons.flag_rounded,
                      child: const Text(
                        "AGA is the all-in-one community platform for Marinduque. "
                        "We bring the local marketplace, maritime port and vessel tracking, tourism, "
                        "and disaster-readiness services together in one place — making everyday life "
                        "more connected, informed, and safe for residents and visitors alike.",
                        style: TextStyle(fontSize: 14, color: textSecondary, height: 1.6, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: "WHAT YOU CAN DO",
                      icon: Icons.apps_rounded,
                      child: Column(
                        children: [
                          _feature(Icons.storefront_rounded, "Local Marketplace",
                              "Buy and sell products from shops near you, with variations, cart, and checkout.",
                              const Color(0xFFEE4D2D)),
                          _divider(),
                          _feature(Icons.directions_boat_rounded, "Maritime & Ports",
                              "Track port status, vessels, and schedules for safe, efficient travel.",
                              accentBlue),
                          _divider(),
                          _feature(Icons.travel_explore_rounded, "Tourism",
                              "Discover local events, destinations, and what's happening around Marinduque.",
                              const Color(0xFF10B981)),
                          _divider(),
                          _feature(Icons.health_and_safety_rounded, "Safety & MDRRMO",
                              "Emergency alerts, marine advisories, incident reports, and an Emergency QR.",
                              const Color(0xFFEF4444)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: "CONNECT WITH US",
                      icon: Icons.public_rounded,
                      child: Column(
                        children: [
                          _linkTile(
                            context,
                            icon: Icons.facebook_rounded,
                            label: "Follow AGA on Facebook",
                            color: const Color(0xFF1877F2),
                            url: "https://facebook.com/people/AGA-App/61583655513664/",
                          ),
                          _divider(),
                          _linkTile(
                            context,
                            icon: Icons.description_outlined,
                            label: "Terms & Conditions",
                            color: textSecondary,
                            url: "https://sites.google.com/view/terms-conditions-aga-app/home",
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: Text(
                        "© 2026 AGA Development",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textSecondary.withValues(alpha: 0.6)),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 280,
      backgroundColor: primaryDark,
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Text("About", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A2E5C), Color(0xFF1E5BA8)],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 12)),
                    ],
                  ),
                  child: Image.asset("assets/aga_gasan_app_logo_rounded.png", width: 76, height: 76),
                ),
                const SizedBox(height: 16),
                const Text("AGA",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _VersionTap(
                    child: Text(Utility().getCurrentGlobalVersion(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: outlineColor),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Icon(icon, size: 18, color: primaryDark),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: primaryDark, letterSpacing: 1)),
              ],
            ),
          ),
          const Divider(height: 1, color: outlineColor),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }

  Widget _feature(IconData icon, String title, String subtitle, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: textPrimary)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(fontSize: 12.5, color: textSecondary, height: 1.45, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _linkTile(BuildContext context,
      {required IconData icon, required String label, required Color color, required String url}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _launch(url, context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: textPrimary)),
              ),
              const Icon(Icons.arrow_outward_rounded, size: 18, color: Color(0xFFCBD5E1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() => const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: outlineColor));
}

class _VersionTap extends StatefulWidget {
  final Widget child;
  const _VersionTap({required this.child});

  @override
  State<_VersionTap> createState() => _VersionTapState();
}

class _VersionTapState extends State<_VersionTap> {
  int _taps = 0;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  void _onTap() {
    final now = DateTime.now();
    if (now.difference(_last) > const Duration(seconds: 2)) _taps = 0;
    _last = now;
    _taps++;
    if (_taps >= 3) {
      _taps = 0;
      _showDeveloperDialog();
    } else {
      final left = 3 - _taps;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          duration: const Duration(milliseconds: 800),
          behavior: SnackBarBehavior.floating,
          content: Text("$left tap${left == 1 ? '' : 's'} away from Developer Option"),
        ));
    }
  }

  void _showDeveloperDialog() {
    final codeCtrl = TextEditingController();
    String? error;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          title: Row(
            children: const [
              Icon(Icons.developer_mode_rounded, color: Color(0xFF0A2E5C)),
              SizedBox(width: 8),
              Text("Developer Option", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Enter the developer access code to enable test environment.",
                style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.5),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: "Access code",
                  errorText: error,
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              if (SupabaseUtility.isDeveloperMode) ...[
                const SizedBox(height: 10),
                Row(
                  children: const [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                    SizedBox(width: 6),
                    Expanded(child: Text("Developer mode is currently ON (test).",
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF10B981), fontWeight: FontWeight.w700))),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            if (SupabaseUtility.isDeveloperMode)
              TextButton(
                onPressed: () async {
                  await SupabaseUtility().setDeveloperMode(false);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showRestartDialog("Developer mode disabled.");
                },
                child: const Text("Disable", style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w800)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A2E5C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              ),
              onPressed: () async {
                if (codeCtrl.text.trim() == SupabaseUtility.developerAccessCode) {
                  await SupabaseUtility().setDeveloperMode(true);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showRestartDialog("Developer mode enabled.");
                } else {
                  setLocal(() => error = "Invalid access code.");
                }
              },
              child: const Text("Unlock", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showRestartDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: const [
            Icon(Icons.restart_alt_rounded, color: Color(0xFFF59E0B)),
            SizedBox(width: 8),
            Text("Restart Required", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        content: Text(
          "$message Please close and reopen the app to apply the changes.",
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.5),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A2E5C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: widget.child,
    );
  }
}
