import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gasan_port_tracker/Activities/Home/Home.dart';
import 'package:gasan_port_tracker/Activities/Tourism/TouristSpotMap.dart';
import 'package:gasan_port_tracker/Activities/MyAccount.dart';
import 'package:gasan_port_tracker/Activities/Services.dart';
import 'package:gasan_port_tracker/Services/OrderNotificationService.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  static final ValueNotifier<bool> drawerOpen = ValueNotifier<bool>(false);
  static final ValueNotifier<int> selectedTab = ValueNotifier<int>(0);

  static void resetForNewSession() {
    drawerOpen.value = false;
    selectedTab.value = 0;
  }

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  int _currentIndex = 0;
  int _municipalZipCode = 0;

  // Track which tabs have been visited
  final List<bool> _loadedTabs = [true, false, false, false];

  // Animation controllers for each tab
  late final List<AnimationController> _animControllers;
  late final List<Animation<double>> _scaleAnimations;
  late final List<Animation<double>> _fadeAnimations;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MainNavigation.selectedTab.addListener(_selectRequestedTab);
    _loadPreferences();

    _animControllers = List.generate(
      _navItems.length,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
        value: i == 0 ? 1.0 : 0.0,
      ),
    );

    _scaleAnimations = _animControllers.map((c) {
      return Tween<double>(begin: 1.0, end: 1.18).animate(
        CurvedAnimation(parent: c, curve: Curves.easeOutBack),
      );
    }).toList();

    _fadeAnimations = _animControllers.map((c) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeOut),
      );
    }).toList();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    MainNavigation.selectedTab.removeListener(_selectRequestedTab);
    for (final c in _animControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      OrderNotificationService.instance.refresh();
    }
  }

  void _selectRequestedTab() {
    final index = MainNavigation.selectedTab.value.clamp(
      0,
      _navItems.length - 1,
    );
    if (!mounted || index == _currentIndex) return;
    _switchTab(index);
  }

  void _switchTab(int index) {
    if (index == _currentIndex) return;
    // Deselect old
    _animControllers[_currentIndex].reverse();
    // Select new
    _animControllers[index].forward();
    setState(() {
      _currentIndex = index;
      _loadedTabs[index] = true;
    });
    MainNavigation.selectedTab.value = index;
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
    _NavItem(
      icon: Icons.home_rounded,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _NavItem(
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore_rounded,
      label: 'Explore',
    ),
    _NavItem(
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
      label: 'Services',
    ),
    _NavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Account',
    ),
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
          _loadedTabs[1]
              ? TouristSpotMap(municipalZipCode: _municipalZipCode)
              : const SizedBox.shrink(),
          _loadedTabs[2] ? const Services() : const SizedBox.shrink(),
          _loadedTabs[3] ? const MyAccount() : const SizedBox.shrink(),
        ],
      ),
      // Bottom nav stays visible even when the drawer opens.
      bottomNavigationBar: Material(
        color: Colors.white,
        elevation: 12,
        shadowColor: _primaryDark.withValues(alpha: 0.18),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: List.generate(_navItems.length, (i) {
                  return Expanded(child: _buildNavItem(i));
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final item = _navItems[index];

    return AnimatedBuilder(
      animation: _animControllers[index],
      builder: (context, child) {
        final t = _fadeAnimations[index].value;
        final scale = _scaleAnimations[index].value;
        final iconColor = Color.lerp(_idleColor, _accentBlue, t)!;
        final labelColor = Color.lerp(_idleColor, _primaryDark, t)!;
        final bgOpacity = t * 0.08;
        final fontWeight = t > 0.5 ? FontWeight.w900 : FontWeight.w700;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (MainNavigation.drawerOpen.value) {
              MainNavigation.drawerOpen.value = false;
              Navigator.of(context).maybePop();
            }
            if (_currentIndex == index) return;
            HapticFeedback.selectionClick();
            _switchTab(index);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              color: _accentBlue.withValues(alpha: bgOpacity),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.scale(
                  scale: scale,
                  child: Icon(
                    t > 0.5 ? item.activeIcon : item.icon,
                    size: 24,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    color: labelColor,
                    fontWeight: fontWeight,
                    fontSize: 10,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}
