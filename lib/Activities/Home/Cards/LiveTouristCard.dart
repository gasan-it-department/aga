import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gasan_port_tracker/Activities/Tourism/TouristSpotDetails.dart';
import '../../Tourism/TouristSpotMap.dart';

// 1. THIS IS THE WRAPPER THAT HOME.DART CALLS
class LiveTourismCard {
  Widget buildTourismCard(Color primaryDark, BuildContext context, List<Map<String, dynamic>> spots, String? municipalName, int municipalZipCode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Discover ${municipalName ?? "Marinduque"}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: primaryDark, letterSpacing: -0.7)),
                  Text("Explore the heartbeat of Marinduque", style: TextStyle(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryDark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TouristSpotMap(municipalZipCode: municipalZipCode,)),
                  );
                },
                icon: const Icon(Icons.map, size: 16),
                label: const Text("View Map", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              )
            ],
          ),
        ),
        SizedBox(
          height: 270,
          child: spots.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: spots.length,
            itemBuilder: (context, index) {
              // This correctly calls TourismView and passes the spot!
              return TourismView(spot: spots[index]);
            },
          ),
        ),
      ],
    );
  }
}

// 2. THIS IS THE INDIVIDUAL ITEM THAT REQUIRES THE SPOT
class TourismView extends StatefulWidget {
  final Map<String, dynamic> spot;
  const TourismView({super.key, required this.spot});

  @override
  State<TourismView> createState() => _TourismViewState();
}

class _TourismViewState extends State<TourismView> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Alignment> _panAnimation;

  final List<Widget> _floatingHearts = [];
  final Color gasanEmerald = const Color(0xFF10B981);
  Timer? _heartTimer;

  // Counters
  int _likeCount = 0;
  bool _isLoadingCount = true;

  @override
  void initState() {
    super.initState();
    final random = Random();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 7000 + random.nextInt(4000)),
    );

    _scaleAnimation = Tween<double>(begin: 1.1, end: 1.35).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    final alignments = [
      Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft,
      Alignment.bottomRight, Alignment.topCenter, Alignment.bottomCenter,
    ];

    _panAnimation = AlignmentTween(
      begin: alignments[random.nextInt(alignments.length)],
      end: alignments[random.nextInt(alignments.length)],
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine));

    _controller.value = random.nextDouble();
    _controller.repeat(reverse: true);
    _startAmbientHearts();

    // Fetch likes automatically
    _fetchLikeCount();
  }

  Future<void> _fetchLikeCount() async {
    try {
      final spotId = widget.spot['spot_id'].toString();

      final count = await Supabase.instance.client
          .from('tourist_spot_likes')
          .count(CountOption.exact)
          .eq('like_spot_id', spotId);

      if (mounted) {
        setState(() {
          _likeCount = count;
          _isLoadingCount = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching like count: $e");
      if (mounted) setState(() => _isLoadingCount = false);
    }
  }

  void _startAmbientHearts() {
    _heartTimer = Timer(Duration(milliseconds: 3000 + Random().nextInt(4000)), () {
      if (mounted) {
        _spawnHeart();
        _startAmbientHearts();
      }
    });
  }

  void _spawnHeart() {
    final id = UniqueKey();
    setState(() {
      _floatingHearts.add(
          FloatingHeartParticle(
            key: id, color: gasanEmerald,
            onComplete: () {
              if (mounted) setState(() => _floatingHearts.removeWhere((w) => w.key == id));
            },
          )
      );
    });
  }

  @override
  void dispose() {
    _heartTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    String imageUrl = "";
    if (widget.spot['spot_images'] != null) {
      final decoded = widget.spot['spot_images'] is String
          ? jsonDecode(widget.spot['spot_images'])
          : widget.spot['spot_images'];
      if (decoded is List && decoded.isNotEmpty) imageUrl = decoded[0];
    }

    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 18, bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0A2E5C).withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: imageUrl.isNotEmpty
                        ? Image.network(imageUrl, fit: BoxFit.cover, alignment: _panAnimation.value)
                        : Container(color: Colors.grey[200]),
                  );
                },
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TouristSpotDetails(
                        spotData: widget.spot,
                      ),
                    ),
                  ).then((_) {
                    _fetchLikeCount();
                  });
                },
                child: Stack(
                  children: [
                    Positioned(
                      bottom: 10, left: 10, right: 10,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                          widget.spot['spot_label'] ?? "Scenic Spot",
                                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -0.4),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                          widget.spot['spot_type'] ?? "Nature",
                                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.w700)
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // --- UPDATED HEART ICON WITH COUNTER ---
                                InkWell(
                                  onTap: _spawnHeart,
                                  borderRadius: BorderRadius.circular(50),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.favorite_rounded, color: gasanEmerald, size: 16),
                                        if (!_isLoadingCount && _likeCount > 0) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatCount(_likeCount),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF0F172A)
                                            ),
                                          )
                                        ]
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ..._floatingHearts,
          ],
        ),
      ),
    );
  }
}

// 3. THE FLOATING HEART ANIMATION
class FloatingHeartParticle extends StatefulWidget {
  final VoidCallback onComplete;
  final Color color;
  const FloatingHeartParticle({super.key, required this.onComplete, required this.color});

  @override
  State<FloatingHeartParticle> createState() => _FloatingHeartParticleState();
}

class _FloatingHeartParticleState extends State<FloatingHeartParticle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late double _randomXDrift;

  @override
  void initState() {
    super.initState();
    _randomXDrift = (Random().nextDouble() - 0.5) * 60;
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;
          return Positioned(
            bottom: 28 + (progress * 100),
            right: 32 + (progress * _randomXDrift),
            child: IgnorePointer(
              child: Opacity(
                opacity: progress < 0.5 ? 1.0 : 1.0 - ((progress - 0.5) * 2),
                child: Transform.scale(
                  scale: 0.4 + (progress * 0.6),
                  child: Icon(Icons.favorite_rounded, color: widget.color.withValues(alpha: 0.8), size: 16),
                ),
              ),
            ),
          );
        }
    );
  }
}
