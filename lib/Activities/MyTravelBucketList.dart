import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyTravelBucketList extends StatefulWidget {
  const MyTravelBucketList({super.key});

  @override
  State<MyTravelBucketList> createState() => _MyTravelBucketListState();
}

class _MyTravelBucketListState extends State<MyTravelBucketList>
    with SingleTickerProviderStateMixin {
  static const Color jungleDark = Color(0xFF0B3D2E);
  static const Color jungleMid = Color(0xFF145C44);
  static const Color leafGreen = Color(0xFF2F9E6E);
  static const Color mint = Color(0xFFB8E0C2);
  static const Color paper = Color(0xFFFBF5E6);
  static const Color paperDeep = Color(0xFFF1E6CB);
  static const Color amber = Color(0xFFE9A23B);
  static const Color sunset = Color(0xFFE76F51);
  static const Color coral = Color(0xFFEF8A6E);
  static const Color earth = Color(0xFF5C3A21);
  static const Color sky = Color(0xFFCFE9F5);
  static const Color ocean = Color(0xFF2A9D8F);

  static const String _doodle = 'assets/doodle_nature';
  static const double _maxContentWidth = 1100;

  final Set<int> _collected = {};
  String _activeFilter = 'All';
  late final AnimationController _floatCtrl;

  final Map<String, Widget> _imgCache = {};

  Widget _img(String name, double size, {double opacity = 1.0}) {
    final key = '$name|$size|$opacity';
    return _imgCache.putIfAbsent(key, () {
      Widget w = Image.asset(
        '$_doodle/$name',
        width: size,
        height: size,
        cacheWidth: (size * 2).round(),
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
      if (opacity < 1.0) w = Opacity(opacity: opacity, child: w);
      return w;
    });
  }

  late final List<Map<String, dynamic>> _bucketList = const [
    {'name': 'Poctoy White Beach', 'location': 'Torrijos', 'asset': 'icons8-beach-100.png', 'type': 'Beach', 'tint': Color(0xFFFFE0B2), 'rarity': 'Popular', 'difficulty': 1},
    {'name': 'Maniwaya Island', 'location': 'Santa Cruz', 'asset': 'icons8-island-100.png', 'type': 'Island', 'tint': Color(0xFFB3E5FC), 'rarity': 'Iconic', 'difficulty': 2},
    {'name': 'Tres Reyes Islands', 'location': 'Gasan', 'asset': 'icons8-island-100.png', 'type': 'Island', 'tint': Color(0xFFB3E5FC), 'rarity': 'Hidden Gem', 'difficulty': 3},
    {'name': 'Palad Sandbar', 'location': 'Santa Cruz', 'asset': 'icons8-sea-shell-100.png', 'type': 'Sandbar', 'tint': Color(0xFFFFECB3), 'rarity': 'Iconic', 'difficulty': 2},
    {'name': 'Natangco White Beach', 'location': 'Mogpog', 'asset': 'icons8-summer-100.png', 'type': 'Beach', 'tint': Color(0xFFFFE0B2), 'rarity': 'Hidden Gem', 'difficulty': 2},
    {'name': 'Mongpong Island', 'location': 'Santa Cruz', 'asset': 'icons8-island-100.png', 'type': 'Island', 'tint': Color(0xFFB3E5FC), 'rarity': 'Hidden Gem', 'difficulty': 2},
    {'name': 'Bellaroca Island', 'location': 'Buenavista', 'asset': 'icons8-aquarium-100.png', 'type': 'Resort', 'tint': Color(0xFFC8E6C9), 'rarity': 'Premium', 'difficulty': 1},
    {'name': 'Kawa-Kawa Falls', 'location': 'Santa Cruz', 'asset': 'icons8-water-resources-of-the-earth-100.png', 'type': 'Falls', 'tint': Color(0xFFB2EBF2), 'rarity': 'Iconic', 'difficulty': 3},
    {'name': 'Bagakawa Falls', 'location': 'Buenavista', 'asset': 'icons8-water-element-100.png', 'type': 'Falls', 'tint': Color(0xFFB2EBF2), 'rarity': 'Hidden Gem', 'difficulty': 4},
    {'name': 'Tabag Falls', 'location': 'Santa Cruz', 'asset': 'icons8-lake-100.png', 'type': 'Falls', 'tint': Color(0xFFB2EBF2), 'rarity': 'Hidden Gem', 'difficulty': 3},
    {'name': 'Malbog Hotspring', 'location': 'Buenavista', 'asset': 'icons8-hot-springs-100.png', 'type': 'Spring', 'tint': Color(0xFFFFCCBC), 'rarity': 'Popular', 'difficulty': 1},
    {'name': 'Mt. Malindig Summit', 'location': 'Buenavista', 'asset': 'icons8-alps-100.png', 'type': 'Peak', 'tint': Color(0xFFD7CCC8), 'rarity': 'Legendary', 'difficulty': 5, 'elevation': 1157},
    {'name': 'Bathala Caves', 'location': 'Santa Cruz', 'asset': 'icons8-shrooms-100.png', 'type': 'Cave', 'tint': Color(0xFFE1BEE7), 'rarity': 'Iconic', 'difficulty': 3},
    {'name': 'Pulang Lupa Shrine', 'location': 'Torrijos', 'asset': 'icons8-national-park-100.png', 'type': 'Heritage', 'tint': Color(0xFFC8E6C9), 'rarity': 'Heritage', 'difficulty': 1},
    {'name': 'Luzon Datum of 1911', 'location': 'Mogpog', 'asset': 'icons8-earth-element-100.png', 'type': 'Landmark', 'tint': Color(0xFFDCEDC8), 'rarity': 'Heritage', 'difficulty': 2},
    {'name': 'Boac Cathedral', 'location': 'Boac', 'asset': 'icons8-moon-and-sun-100.png', 'type': 'Heritage', 'tint': Color(0xFFFFE0B2), 'rarity': 'Heritage', 'difficulty': 1},
    {'name': 'Butterfly Farm', 'location': 'Boac', 'asset': 'icons8-butterfly-100.png', 'type': 'Nature', 'tint': Color(0xFFF8BBD0), 'rarity': 'Popular', 'difficulty': 1},
    {'name': 'Marinduque Museum', 'location': 'Boac', 'asset': 'icons8-national-park-100.png', 'type': 'Heritage', 'tint': Color(0xFFC8E6C9), 'rarity': 'Heritage', 'difficulty': 1},
    {'name': 'Dampulan Seawall', 'location': 'Torrijos', 'asset': 'icons8-seagull-100.png', 'type': 'Coast', 'tint': Color(0xFFB3E5FC), 'rarity': 'Popular', 'difficulty': 1},
    {'name': 'Panuluyan Farmstay', 'location': 'Torrijos', 'asset': 'icons8-wheat-100.png', 'type': 'Farm', 'tint': Color(0xFFFFF59D), 'rarity': 'Hidden Gem', 'difficulty': 1},
    {'name': 'Paadjao Falls', 'location': 'Mogpog', 'asset': 'icons8-water-resources-of-the-earth-100.png', 'type': 'Falls', 'tint': Color(0xFFB2EBF2), 'rarity': 'Hidden Gem', 'difficulty': 3},
    {'name': 'Cafe Tanawin', 'location': 'Mogpog', 'asset': 'icons8-natural-food-100.png', 'type': 'Cafe', 'tint': Color(0xFFFFCCBC), 'rarity': 'Popular', 'difficulty': 1},
    {'name': 'Bangumbungan Cave', 'location': 'Santa Cruz', 'asset': 'icons8-amanita-100.png', 'type': 'Cave', 'tint': Color(0xFFE1BEE7), 'rarity': 'Hidden Gem', 'difficulty': 4},
    {'name': 'Makulilis Peak', 'location': 'Buenavista', 'asset': 'icons8-alps-100.png', 'type': 'Peak', 'tint': Color(0xFFD7CCC8), 'rarity': 'Iconic', 'difficulty': 4, 'elevation': 1070},
  ];

  static const List<String> _sideDoodles = [
    'icons8-large-tree-100.png',
    'icons8-evergreen-100.png',
    'icons8-tree-100.png',
    'icons8-forest-100.png',
    'icons8-apple-tree-100.png',
    'icons8-flower-100.png',
    'icons8-sunflower-100.png',
    'icons8-shrooms-100.png',
    'icons8-clover-100.png',
    'icons8-butterfly-100.png',
    'icons8-bird-100.png',
    'icons8-maple-leaf-100.png',
    'icons8-oak-leaf-100.png',
    'icons8-sprout-100.png',
    'icons8-rose-100.png',
    'icons8-tulip-100.png',
  ];

  static const List<String> _filters = [
    'All','Beach','Island','Falls','Peak','Cave','Heritage','Nature','Farm','Cafe','Spring','Resort','Coast','Landmark','Sandbar'
  ];

  List<int> _filteredIndices() {
    if (_activeFilter == 'All') return List.generate(_bucketList.length, (i) => i);
    final out = <int>[];
    for (int i = 0; i < _bucketList.length; i++) {
      if (_bucketList[i]['type'] == _activeFilter) out.add(i);
    }
    return out;
  }

  Color _rarityColor(String rarity) {
    switch (rarity) {
      case 'Legendary': return const Color(0xFF8E44AD);
      case 'Iconic': return sunset;
      case 'Hidden Gem': return ocean;
      case 'Premium': return amber;
      case 'Heritage': return earth;
      default: return jungleMid;
    }
  }

  static const String _prefsKey = 'bucket_collected_keys';

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _loadCollected();
  }

  Future<void> _loadCollected() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_prefsKey) ?? const [];
      if (saved.isEmpty) return;
      final restored = <int>{};
      for (final key in saved) {
        // Saved as the unique journey name so reordering the list won't desync.
        final idx = _bucketList.indexWhere((m) => (m['name'] as String) == key);
        if (idx != -1) restored.add(idx);
      }
      if (mounted && restored.isNotEmpty) {
        setState(() {
          _collected
            ..clear()
            ..addAll(restored);
        });
      }
    } catch (_) {}
  }

  Future<void> _persistCollected() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = _collected.map((i) => _bucketList[i]['name'] as String).toList();
      await prefs.setStringList(_prefsKey, keys);
    } catch (_) {}
  }

  void _toggleCollected(int index) {
    setState(() {
      if (_collected.contains(index)) {
        _collected.remove(index);
      } else {
        _collected.add(index);
      }
    });
    _persistCollected();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final n in const ['icons8-forest-100.png','icons8-butterfly-100.png','icons8-large-tree-100.png','icons8-eco-100.png','icons8-national-park-100.png','icons8-nature-care-100.png','icons8-green-earth-100.png']) {
      precacheImage(AssetImage('$_doodle/$n'), context);
    }
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final collected = _collected.length;
    final total = _bucketList.length;
    final progress = total == 0 ? 0.0 : collected / total;
    final indices = _filteredIndices();

    final isWide = width >= 900;
    final isTablet = width >= 600 && width < 900;
    final hPad = isWide ? 32.0 : (isTablet ? 24.0 : 20.0);
    final gridExtent = isWide ? 240.0 : (isTablet ? 220.0 : 200.0);

    return Scaffold(
      backgroundColor: paper,
      body: Stack(
        children: [
          const Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _PaperPainter()),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(child: _SideScenery(imgBuilder: _img, width: width)),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildTopBar(collected, total, hPad)),
                    SliverToBoxAdapter(child: RepaintBoundary(child: _buildHero(progress, collected, total, hPad, isWide))),
                    if (isWide)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: hPad),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: RepaintBoundary(child: _buildFeatured(0))),
                              const SizedBox(width: 18),
                              Expanded(flex: 2, child: RepaintBoundary(child: _buildJourneyMap(0))),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      SliverToBoxAdapter(child: RepaintBoundary(child: _buildFeatured(hPad))),
                    ],
                    SliverToBoxAdapter(child: _buildFilters(hPad)),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 40),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: gridExtent,
                          mainAxisSpacing: 18,
                          crossAxisSpacing: 18,
                          childAspectRatio: 0.62,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => RepaintBoundary(child: _buildPostcard(indices[i])),
                          childCount: indices.length,
                        ),
                      ),
                    ),
                    if (!isWide)
                      SliverToBoxAdapter(child: RepaintBoundary(child: _buildJourneyMap(hPad))),
                    SliverToBoxAdapter(child: _buildFooter(hPad)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(int collected, int total, double hPad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: jungleDark),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              shape: const CircleBorder(),
              elevation: 2,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: jungleDark.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                _img('icons8-eco-100.png', 18),
                const SizedBox(width: 6),
                const Text("Marinduque",
                  style: TextStyle(color: jungleDark, fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [sunset, coral]),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 4),
                Text("$collected/$total",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(double progress, int collected, int total, double hPad, bool isWide) {
    final title = const Text("Discover\nMarinduque",
      style: TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: -1.8, height: 0.98),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 18),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [jungleDark, jungleMid, ocean], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [BoxShadow(color: jungleDark.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 12))],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(right: -16, top: -16, child: _img('icons8-forest-100.png', 110, opacity: 0.45)),
            Positioned(
              right: 70, top: 40,
              child: _FloatingWidget(
                controller: _floatCtrl,
                amplitude: const Offset(8, 6),
                child: _img('icons8-butterfly-100.png', 50, opacity: 0.55),
              ),
            ),
            Positioned(left: -20, bottom: -28, child: _img('icons8-large-tree-100.png', 90, opacity: 0.4)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: amber.withValues(alpha: 0.6)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, color: amber, size: 14),
                      SizedBox(width: 4),
                      Text("EXPLORER'S JOURNAL",
                        style: TextStyle(color: amber, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.8),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                title,
                const SizedBox(height: 8),
                const Text("Heart of the Philippines — chase falls, climb peaks, sail to hidden islands.",
                  style: TextStyle(color: mint, fontSize: 13.5, height: 1.5, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _heroStat(Icons.location_on_rounded, "$total", "Spots"),
                    const SizedBox(width: 10),
                    _heroStat(Icons.bookmark_added_rounded, "$collected", "Visited"),
                    const SizedBox(width: 10),
                    _heroStat(Icons.flag_rounded, "${total - collected}", "To Go"),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.route_rounded, color: amber, size: 16),
                          const SizedBox(width: 6),
                          const Text("Journey Progress",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                          const Spacer(),
                          Text("${(progress * 100).toStringAsFixed(0)}%",
                            style: const TextStyle(color: amber, fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Stack(
                        children: [
                          Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: progress.clamp(0.0, 1.0),
                            child: Container(
                              height: 10,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [amber, sunset]),
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroStat(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: amber, size: 18),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
            Text(label, style: const TextStyle(color: mint, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatured(double hPad) {
    final peaks = <int>[];
    for (int i = 0; i < _bucketList.length; i++) {
      if (_bucketList[i]['type'] == 'Peak') peaks.add(i);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.terrain_rounded, color: sunset, size: 20),
              SizedBox(width: 6),
              Text("Most Difficult Climbs",
                style: TextStyle(color: jungleDark, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.3),
              ),
              SizedBox(width: 6),
              Icon(Icons.local_fire_department_rounded, color: sunset, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          const Text("Conquer Marinduque's legendary peaks — only for the brave.",
            style: TextStyle(color: earth, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [BoxShadow(color: jungleDark.withValues(alpha: 0.14), blurRadius: 18, offset: const Offset(0, 10))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Stack(
                children: [
                  Container(
                    height: 220,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFDDE7F0), Color(0xFFE8DFD0), Colors.white],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(left: -10, bottom: -10, child: _img('icons8-evergreen-100.png', 80)),
                  Positioned(right: -10, bottom: -8, child: _img('icons8-large-tree-100.png', 80)),
                  Positioned(
                    right: 20, top: 14,
                    child: _FloatingWidget(
                      controller: _floatCtrl,
                      amplitude: const Offset(0, 4),
                      child: _img('icons8-moon-and-sun-100.png', 50),
                    ),
                  ),
                  Positioned(left: 30, top: 40, child: _img('icons8-alps-100.png', 130)),
                  Positioned(right: 60, top: 60, child: _img('icons8-alps-100.png', 110)),
                  Positioned(left: 140, top: 30, child: _img('icons8-bird-100.png', 30, opacity: 0.7)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 200, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _chip("PEAKS", jungleMid),
                            const SizedBox(width: 6),
                            _chip("EXTREME", const Color(0xFF8E44AD)),
                            const Spacer(),
                            const Icon(Icons.local_fire_department_rounded, size: 14, color: sunset),
                            const Icon(Icons.local_fire_department_rounded, size: 14, color: sunset),
                            const Icon(Icons.local_fire_department_rounded, size: 14, color: sunset),
                            const Icon(Icons.local_fire_department_rounded, size: 14, color: sunset),
                            const Icon(Icons.local_fire_department_rounded, size: 14, color: sunset),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text("The Twin Giants",
                          style: TextStyle(color: jungleDark, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.6),
                        ),
                        const SizedBox(height: 2),
                        const Text("Marinduque's hardest summits await.",
                          style: TextStyle(color: earth, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final idx in peaks) ...[
            _buildPeakRow(idx),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildPeakRow(int index) {
    final item = _bucketList[index];
    final tint = item['tint'] as Color;
    final diff = item['difficulty'] as int;
    final rarity = item['rarity'] as String;
    final isCollected = _collected.contains(index);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleCollected(index),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isCollected ? leafGreen : jungleDark.withValues(alpha: 0.08),
              width: isCollected ? 2 : 1,
            ),
            boxShadow: [BoxShadow(color: jungleDark.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 5))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Row(
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [tint, tint.withValues(alpha: 0.4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(left: -6, bottom: -6, child: _img('icons8-grass-100.png', 38, opacity: 0.4)),
                      Center(child: _img(item['asset'] as String, 68)),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _chip(rarity.toUpperCase(), _rarityColor(rarity)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: jungleDark,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.height_rounded, color: amber, size: 11),
                                  const SizedBox(width: 3),
                                  Text("${item['elevation']} MASL",
                                    style: const TextStyle(color: amber, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                                  ),
                                ],
                              ),
                            ),
                            if (isCollected)
                              const Icon(Icons.verified_rounded, color: leafGreen, size: 16),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item['name'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: jungleDark, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.place_rounded, size: 12, color: sunset),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                item['location'] as String,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: earth, fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ...List.generate(5, (i) => Icon(
                              i < diff ? Icons.local_fire_department_rounded : Icons.local_fire_department_outlined,
                              size: 11,
                              color: i < diff ? sunset : earth.withValues(alpha: 0.3),
                            )),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: jungleDark,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCollected ? Icons.check_rounded : Icons.arrow_forward_rounded,
                      color: amber,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
    );
  }

  Widget _buildFilters(double hPad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _img('icons8-national-park-100.png', 26),
              const SizedBox(width: 8),
              const Text("All Destinations",
                style: TextStyle(color: jungleDark, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5),
              ),
              const Spacer(),
              const Icon(Icons.touch_app_rounded, color: earth, size: 14),
              const SizedBox(width: 4),
              const Text("tap to collect",
                style: TextStyle(color: earth, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              cacheExtent: 600,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = _filters[i];
                final active = f == _activeFilter;
                return GestureDetector(
                  onTap: () => setState(() => _activeFilter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? jungleDark : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active ? jungleDark : jungleDark.withValues(alpha: 0.12)),
                    ),
                    child: Text(f,
                      style: TextStyle(
                        color: active ? amber : jungleDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostcard(int index) {
    final item = _bucketList[index];
    final isCollected = _collected.contains(index);
    final tint = item['tint'] as Color;
    final rarity = item['rarity'] as String;
    final rColor = _rarityColor(rarity);
    final diff = item['difficulty'] as int;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleCollected(index),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isCollected ? leafGreen : jungleDark.withValues(alpha: 0.08),
              width: isCollected ? 2.5 : 1,
            ),
            boxShadow: [
              BoxShadow(color: jungleDark.withValues(alpha: 0.1), blurRadius: 14, offset: const Offset(0, 6)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      height: 130,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [tint, tint.withValues(alpha: 0.55), Colors.white],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(left: -8, bottom: -10, child: _img('icons8-grass-100.png', 56, opacity: 0.4)),
                          Positioned(right: -6, top: -8, child: _img('icons8-clover-100.png', 44, opacity: 0.3)),
                          Center(child: _img(item['asset'] as String, 86)),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: rColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(rarity.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10, right: 10,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 26, height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isCollected ? leafGreen : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: jungleDark, width: 1.5),
                        ),
                        child: Icon(
                          isCollected ? Icons.check_rounded : Icons.bookmark_add_rounded,
                          color: isCollected ? Colors.white : jungleDark,
                          size: 14,
                        ),
                      ),
                    ),
                    if (isCollected)
                      Positioned(
                        right: 12, bottom: 12,
                        child: Transform.rotate(
                          angle: -0.25,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              border: Border.all(color: sunset, width: 2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text("VISITED",
                              style: TextStyle(color: sunset, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: jungleMid.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            (item['type'] as String).toUpperCase(),
                            style: const TextStyle(color: jungleMid, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item['name'] as String,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: jungleDark, fontSize: 14, fontWeight: FontWeight.w900, height: 1.15, letterSpacing: -0.3),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            const Icon(Icons.place_rounded, size: 12, color: sunset),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                item['location'] as String,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: earth, fontSize: 11.5, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        if (item['type'] == 'Peak') ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text("Climb",
                                style: TextStyle(color: earth.withValues(alpha: 0.7), fontSize: 9.5, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 4),
                              ...List.generate(5, (i) => Padding(
                                padding: const EdgeInsets.only(right: 1.5),
                                child: Icon(
                                  i < diff ? Icons.local_fire_department_rounded : Icons.local_fire_department_outlined,
                                  size: 10,
                                  color: i < diff ? sunset : earth.withValues(alpha: 0.3),
                                ),
                              )),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJourneyMap(double hPad) {
    const municipalities = ['Boac', 'Gasan', 'Buenavista', 'Torrijos', 'Santa Cruz', 'Mogpog'];
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: jungleDark.withValues(alpha: 0.08)),
          boxShadow: [BoxShadow(color: jungleDark.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _img('icons8-green-earth-100.png', 26),
                const SizedBox(width: 8),
                const Text("By Municipality",
                  style: TextStyle(color: jungleDark, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: -0.3),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final m in municipalities) ...[
              Builder(builder: (_) {
                int total = 0, visited = 0;
                for (int i = 0; i < _bucketList.length; i++) {
                  if (_bucketList[i]['location'] == m) {
                    total++;
                    if (_collected.contains(i)) visited++;
                  }
                }
                final p = total == 0 ? 0.0 : visited / total;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.place_rounded, size: 14, color: sunset),
                          const SizedBox(width: 4),
                          Text(m, style: const TextStyle(color: jungleDark, fontWeight: FontWeight.w800, fontSize: 13)),
                          const Spacer(),
                          Text("$visited / $total",
                            style: const TextStyle(color: earth, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: p,
                          minHeight: 6,
                          backgroundColor: paperDeep,
                          valueColor: AlwaysStoppedAnimation(p == 1.0 ? leafGreen : ocean),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(double hPad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 30),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [mint.withValues(alpha: 0.5), paperDeep.withValues(alpha: 0.5)]),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: leafGreen.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            _img('icons8-nature-care-100.png', 56),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Travel responsibly",
                    style: TextStyle(color: jungleDark, fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                  SizedBox(height: 3),
                  Text("Leave no trace. Respect locals, protect nature, take only memories.",
                    style: TextStyle(color: earth, fontSize: 12, height: 1.4, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingWidget extends StatelessWidget {
  final AnimationController controller;
  final Offset amplitude;
  final Widget child;
  const _FloatingWidget({required this.controller, required this.amplitude, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, c) {
        final t = controller.value * math.pi * 2;
        return Transform.translate(
          offset: Offset(math.sin(t) * amplitude.dx, math.cos(t) * amplitude.dy),
          child: c,
        );
      },
      child: child,
    );
  }
}

class _SideScenery extends StatelessWidget {
  final Widget Function(String name, double size, {double opacity}) imgBuilder;
  final double width;
  const _SideScenery({required this.imgBuilder, required this.width});

  @override
  Widget build(BuildContext context) {
    final rng = math.Random(11);
    final isNarrow = width < 600;
    final count = isNarrow ? 10 : 18;
    final items = <Widget>[];
    for (int i = 0; i < count; i++) {
      final left = i.isEven;
      final asset = _MyTravelBucketListState._sideDoodles[rng.nextInt(_MyTravelBucketListState._sideDoodles.length)];
      final size = 36.0 + rng.nextDouble() * 36;
      final top = 180.0 + i * 150.0 + rng.nextDouble() * 50;
      final offset = rng.nextDouble() * 18;
      final rot = (rng.nextDouble() - 0.5) * 0.4;
      items.add(Positioned(
        top: top,
        left: left ? offset : null,
        right: left ? null : offset,
        child: Transform.rotate(angle: rot, child: imgBuilder(asset, size, opacity: 0.5)),
      ));
    }
    return Stack(children: items);
  }
}

class _PaperPainter extends CustomPainter {
  const _PaperPainter();

  static const Color _paper = Color(0xFFFBF5E6);
  static const Color _deep = Color(0xFFF1E6CB);
  static const Color _sky = Color(0xFFCFE9F5);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_sky.withValues(alpha: 0.55), _paper.withValues(alpha: 0.0)],
        stops: const [0.0, 0.4],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), skyPaint);

    final dot = Paint()..color = _deep.withValues(alpha: 0.15);
    final rng = math.Random(3);
    for (int i = 0; i < 60; i++) {
      canvas.drawCircle(Offset(rng.nextDouble() * w, rng.nextDouble() * h), 1.2, dot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
