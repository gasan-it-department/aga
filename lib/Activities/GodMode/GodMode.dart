import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Activities/GodMode/GodModeNavigationTest.dart';
import 'package:gasan_port_tracker/Activities/GodMode/GodModeSellers/GodModeSellerControl.dart';
import 'package:gasan_port_tracker/Activities/GodMode/GodModeSellers/GodModeSellerOrders.dart';
import 'package:gasan_port_tracker/Activities/GodMode/GodModeUserAccess/GodModeUserAccess.dart';
import 'package:gasan_port_tracker/Activities/MarketPlaceAdministrators.dart';
import 'package:gasan_port_tracker/Activities/MDRRMO/MDRRMOAdministrator.dart';
import 'package:gasan_port_tracker/Activities/MDRRMO/MDRRMOPersonnelPanel.dart';
import 'package:gasan_port_tracker/Activities/Maritime/MaritimeAdministrator.dart';
import 'package:gasan_port_tracker/Activities/Services.dart';
import 'package:gasan_port_tracker/Activities/Tourism/TourismAdministrator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GodMode extends StatefulWidget {
  const GodMode({super.key});

  static const ownerEmail = 'rizzabhb24024@gmail.com';

  static bool isOwner(User? user, {String? account}) {
    final emails = <String>{
      if (account != null) account.trim().toLowerCase(),
      if (user?.email != null) user!.email!.trim().toLowerCase(),
      if (user?.userMetadata?['email'] != null)
        user!.userMetadata!['email'].toString().trim().toLowerCase(),
      for (final identity in user?.identities ?? const <UserIdentity>[])
        if (identity.identityData?['email'] != null)
          identity.identityData!['email'].toString().trim().toLowerCase(),
    };
    return emails.contains(ownerEmail);
  }

  @override
  State<GodMode> createState() => _GodModeState();
}

class _GodModeState extends State<GodMode> {
  static const _bg = Color(0xFFF8FAFC);
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _line = Color(0xFFE2E8F0);
  static const _primary = Color(0xFF0A2E5C);
  static const _gold = Color(0xFFF59E0B);

  String _name = 'System Owner';
  String _email = GodMode.ownerEmail;
  bool _authorized = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAccess();
  }

  Future<void> _loadAccess() async {
    try {
      await Supabase.instance.client.auth.refreshSession();
    } catch (_) {}
    final user = Supabase.instance.client.auth.currentUser;
    final authEmail = user?.email?.trim().toLowerCase() ?? '';
    String accountEmail = authEmail;
    String name = 'System Owner';

    if (user != null) {
      try {
        final row = await Supabase.instance.client
            .from('user_data')
            .select('user_name, user_account')
            .eq('user_id', user.id)
            .maybeSingle();
        accountEmail = (row?['user_account'] ?? authEmail)
            .toString()
            .trim()
            .toLowerCase();
        name = (row?['user_name'] ?? name).toString();
      } catch (error) {
        debugPrint('God Mode access lookup failed: $error');
      }
    }

    if (!mounted) return;
    setState(() {
      _name = name;
      _email = accountEmail;
      _authorized = GodMode.isOwner(user, account: accountEmail);
      _loading = false;
    });
  }

  void _open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width >= 900 ? 28.0 : 16.0;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        elevation: 0,
        title: const Text(
          'God Mode',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : !_authorized
          ? _buildLocked()
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 36),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildHero(width),
                      const SizedBox(height: 18),
                      _buildNavigationTestCard(),
                      const SizedBox(height: 22),
                      _sectionTitle('System Access'),
                      const SizedBox(height: 10),
                      _buildGrid(width, [
                        _GodModeAction(
                          title: 'Maritime',
                          subtitle:
                              'Ports, vessels, shipping lines, status updates and maritime alerts.',
                          icon: Icons.directions_boat_rounded,
                          color: const Color(0xFF2563EB),
                          onTap: () => _open(const MaritimeAdministrator()),
                        ),
                        _GodModeAction(
                          title: 'Tourism',
                          subtitle:
                              'Tourist spots, destination content, events and tourism dashboard.',
                          icon: Icons.travel_explore_rounded,
                          color: const Color(0xFF059669),
                          onTap: () => _open(const TourismAdministrator()),
                        ),
                        _GodModeAction(
                          title: 'MDRRMO',
                          subtitle:
                              'Emergency response dashboard, broadcasts, personnel and live map.',
                          icon: Icons.emergency_rounded,
                          color: const Color(0xFFDC2626),
                          onTap: () => _open(const MdrrmoAdministrator()),
                        ),
                        _GodModeAction(
                          title: 'Responder Panel',
                          subtitle:
                              'Open MDRRMO personnel dispatch and response tools.',
                          icon: Icons.health_and_safety_rounded,
                          color: const Color(0xFFEA580C),
                          onTap: () => _open(const MdrrmoPersonnelPanel()),
                        ),
                        _GodModeAction(
                          title: 'Marketplace Shops',
                          subtitle:
                              'Approve, reject, suspend, hide and review all local shops.',
                          icon: Icons.storefront_rounded,
                          color: const Color(0xFF7C3AED),
                          onTap: () => _open(const MarketPlaceAdministrators()),
                        ),
                        _GodModeAction(
                          title: 'All Orders',
                          subtitle:
                              'View order activity across shops and monitor marketplace operations.',
                          icon: Icons.receipt_long_rounded,
                          color: const Color(0xFF0F766E),
                          onTap: () => _open(const GodModeSellerOrders()),
                        ),
                      ]),
                      const SizedBox(height: 22),
                      _sectionTitle('Operations'),
                      const SizedBox(height: 10),
                      _buildGrid(width, [
                        _GodModeAction(
                          title: 'User Access',
                          subtitle:
                              'Search users and set admin roles, ports, user type and municipality scope.',
                          icon: Icons.supervisor_account_rounded,
                          color: const Color(0xFFF59E0B),
                          onTap: () => _open(const GodModeUserAccess()),
                        ),
                        _GodModeAction(
                          title: 'Seller Control',
                          subtitle:
                              'Search every seller, review pending shops, view, hide, suspend and approve stores.',
                          icon: Icons.store_mall_directory_rounded,
                          color: const Color(0xFF9333EA),
                          onTap: () => _open(const GodModeSellerControl()),
                        ),
                        _GodModeAction(
                          title: 'Public Services',
                          subtitle:
                              'Business permit services and upcoming municipal services.',
                          icon: Icons.apps_rounded,
                          color: const Color(0xFF0284C7),
                          onTap: () => _open(const Services()),
                        ),
                      ]),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLocked() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded, color: _primary, size: 42),
              const SizedBox(height: 14),
              const Text(
                'Restricted Access',
                style: TextStyle(
                  color: _ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'God Mode is only available to ${GodMode.ownerEmail}. Current account: $_email',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(double width) {
    return Container(
      padding: EdgeInsets.all(width >= 700 ? 24 : 18),
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: _gold,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Owner Control Center',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _gold,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'GOD MODE',
                        style: TextStyle(
                          color: Color(0xFF422006),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Signed in as $_name. This page gives direct access to every major administration surface in AGA.',
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: _muted,
        fontWeight: FontWeight.w900,
        fontSize: 12,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildNavigationTestCard() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _open(const GodModeNavigationTest()),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFBFDBFE)),
            gradient: const LinearGradient(
              colors: [Colors.white, Color(0xFFEFF6FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.route_rounded,
                  color: Color(0xFF2563EB),
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AGA Navigation System Test',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Test OSRM routing, GPS speed, ETA, reroute and arrival detection.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _muted,
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward_rounded, color: Color(0xFF2563EB)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(double width, List<_GodModeAction> actions) {
    final columns = width >= 1100
        ? 3
        : width >= 720
        ? 2
        : 1;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 158,
      ),
      itemBuilder: (_, index) => _buildActionCard(actions[index]),
    );
  }

  Widget _buildActionCard(_GodModeAction action) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: action.onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: action.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(action.icon, color: action.color, size: 24),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: action.color,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                action.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                action.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GodModeAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _GodModeAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
