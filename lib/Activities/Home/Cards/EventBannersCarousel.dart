import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _DragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class EventBannersCarousel extends StatefulWidget {
  final int zipCode;
  const EventBannersCarousel({super.key, required this.zipCode});

  @override
  State<EventBannersCarousel> createState() => _EventBannersCarouselState();
}

class _EventBannersCarouselState extends State<EventBannersCarousel> {
  final _supabase = Supabase.instance.client;
  final PageController _controller = PageController(viewportFraction: 0.92);
  Timer? _timer;

  List<Map<String, dynamic>> _banners = [];
  bool _loading = true;
  int _index = 0;

  final Color primaryDark = const Color(0xFF0F172A);
  final Color cardBorder = const Color(0xFFE2E8F0);
  final Color textSecondary = const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(covariant EventBannersCarousel old) {
    super.didUpdateWidget(old);
    if (old.zipCode != widget.zipCode) _fetch();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (widget.zipCode == 0) {
      if (mounted) setState(() { _banners = []; _loading = false; });
      return;
    }
    try {
      final res = await _supabase
          .from('tourism_event_banners')
          .select()
          .eq('banner_municipal_zipcode', widget.zipCode)
          .order('banner_date_added', ascending: false);
      if (!mounted) return;
      setState(() {
        _banners = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
      _startAuto();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startAuto() {
    _timer?.cancel();
    if (_banners.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_controller.hasClients) return;
      final next = (_index + 1) % _banners.length;
      _controller.animateToPage(next, duration: const Duration(milliseconds: 700), curve: Curves.easeInOutCubic);
    });
  }

  void _openDetail(Map<String, dynamic> b) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BannerDetailSheet(banner: b),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.zipCode == 0) return const SizedBox.shrink();
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: SizedBox(height: 170, child: Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: primaryDark))),
      );
    }
    if (_banners.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Row(
              children: [
                Icon(Icons.celebration_rounded, color: const Color(0xFFF59E0B), size: 18),
                const SizedBox(width: 8),
                Text("Local Events & Festivals", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: primaryDark, letterSpacing: -0.3)),
                const Spacer(),
                Text("${_banners.length}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: textSecondary)),
              ],
            ),
          ),
          SizedBox(
            height: 180,
            child: Listener(
              onPointerDown: (_) => _timer?.cancel(),
              child: ScrollConfiguration(
                behavior: _DragScrollBehavior(),
                child: PageView.builder(
                  controller: _controller,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (i) => setState(() => _index = i),
                  itemCount: _banners.length,
                  itemBuilder: (_, i) => _buildCard(_banners[i]),
                ),
              ),
            ),
          ),
          if (_banners.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_banners.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: active ? primaryDark : cardBorder,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> b) {
    final String name = b['banner_name'] ?? 'Event';
    final String? cover = b['banner_cover_image'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openDetail(b),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 6))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cover != null && cover.isNotEmpty)
                    Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback())
                  else
                    _fallback(),
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.25), Colors.black.withValues(alpha: 0.78)],
                          stops: const [0.35, 0.65, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_activity_rounded, color: Colors.white, size: 11),
                          SizedBox(width: 4),
                          Text("EVENT", style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.3, height: 1.15),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.info_outline_rounded, color: Colors.white, size: 11),
                                  SizedBox(width: 4),
                                  Text("Tap for details", style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFFF59E0B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(child: Icon(Icons.celebration_rounded, color: Colors.white, size: 56)),
    );
  }
}

class _BannerDetailSheet extends StatelessWidget {
  final Map<String, dynamic> banner;
  const _BannerDetailSheet({required this.banner});

  @override
  Widget build(BuildContext context) {
    final String name = (banner['banner_name'] ?? 'Event').toString();
    final String desc = (banner['banner_description'] ?? 'No description.').toString();
    final String? cover = banner['banner_cover_image']?.toString();
    final dynamic added = banner['banner_date_added'];
    String dateStr = '';
    try {
      final int ms = added is num ? added.toInt() : int.tryParse(added?.toString() ?? '') ?? 0;
      if (ms > 0) {
        final d = DateTime.fromMillisecondsSinceEpoch(ms);
        dateStr = "${d.month}/${d.day}/${d.year}";
      }
    } catch (_) {}

    final maxH = MediaQuery.of(context).size.height * 0.85;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(10)),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      if (cover != null && cover.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Image.network(
                                cover,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: const Color(0xFFF1F5F9),
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8), size: 36),
                                ),
                                loadingBuilder: (_, child, p) => p == null
                                    ? child
                                    : Container(color: const Color(0xFFF1F5F9), alignment: Alignment.center, child: const CircularProgressIndicator(strokeWidth: 2)),
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.4)),
                            if (dateStr.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF64748B)),
                                  const SizedBox(width: 6),
                                  Text("Posted $dateStr", style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),
                            Text(desc, style: const TextStyle(fontSize: 14.5, height: 1.55, color: Color(0xFF1E293B), fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

