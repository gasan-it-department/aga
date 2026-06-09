import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gasan_port_tracker/Activities/Home/Home.dart';
import 'package:gasan_port_tracker/Activities/StoreItemsGallery.dart';
import 'package:gasan_port_tracker/Activities/Tourism/TouristSpotMap.dart';
import 'package:gasan_port_tracker/Activities/MyAccount.dart';
import 'package:gasan_port_tracker/Services/OrderNotificationService.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  static final ValueNotifier<bool> drawerOpen = ValueNotifier<bool>(false);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _municipalZipCode = 0;

  // Track which tabs have been visited
  final List<bool> _loadedTabs = [true, false, false, false];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPreferences();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Realtime websocket can drop while backgrounded; force a fresh
      // subscription so subsequent order status updates pop.
      OrderNotificationService.instance.refresh();
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _municipalZipCode = prefs.getInt('current_zip_code') ?? 0;
      });
    }
  }

  static const Color _primaryDark = Color(0xFF0A2E5C);
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _idleColor = Color(0xFF94A3B8);

  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.home_rounded, label: 'Home'),
    _NavItem(icon: Icons.storefront_rounded, label: 'Market'),
    _NavItem(icon: Icons.travel_explore_rounded, label: 'Explore'),
    _NavItem(icon: Icons.person_rounded, label: 'Account'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,
      resizeToAvoidBottomInset: false,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const Home(),
          _loadedTabs[1] ? const StoreItemsGallery(isTab: true) : const SizedBox.shrink(),
          _loadedTabs[2] ? TouristSpotMap(municipalZipCode: _municipalZipCode) : const SizedBox.shrink(),
          _loadedTabs[3] ? const MyAccount() : const SizedBox.shrink(),
        ],
      ),
      // Bottom nav stays visible even when the drawer opens.
      bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: const Color(0xFFE2E8F0), width: 1)),
            boxShadow: [
              BoxShadow(
                color: _primaryDark.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_navItems.length, (i) {
                  return Expanded(child: _buildNavItem(i));
                }),
              ),
            ),
          ),
        ),
    );
  }

  Widget _buildNavItem(int index) {
    final item = _navItems[index];
    final bool isActive = _currentIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_currentIndex == index) return;
        HapticFeedback.selectionClick();
        setState(() {
          _currentIndex = index;
          _loadedTabs[index] = true;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 16 : 10,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: [_primaryDark, _accentBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(22),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: _accentBlue.withValues(alpha: 0.42),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: _primaryDark.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: isActive ? 1 : 0),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              builder: (context, t, child) {
                return Transform.scale(
                  scale: 1 + (t * 0.08),
                  child: Icon(
                    item.icon,
                    size: 22,
                    color: Color.lerp(_idleColor, Colors.white, t),
                  ),
                );
              },
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              child: isActive
                  ? Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 0.2,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
