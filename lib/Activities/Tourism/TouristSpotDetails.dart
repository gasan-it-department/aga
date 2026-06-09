import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../Dialogs/Bottomsheets/TouristSpotReviewBottomSheet.dart';
import '../../Utility/ImageViewer.dart';
import '../../Utility/Responsive.dart';

class DraggableScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}

class TouristSpotDetails extends StatefulWidget {
  final Map<String, dynamic> spotData;

  const TouristSpotDetails({super.key, required this.spotData});

  @override
  State<TouristSpotDetails> createState() => _TouristSpotDetailsState();
}

class _TouristSpotDetailsState extends State<TouristSpotDetails> {
  final _supabase = Supabase.instance.client;

  // --- DESIGN PALETTE ---
  final Color primaryDark = const Color(0xFF1E293B);
  final Color accentEmerald = const Color(0xFF0F766E);
  final Color starGold = const Color(0xFFF59E0B);
  final Color textMain = const Color(0xFF111827);
  final Color textSub = const Color(0xFF6B7280);
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color surfaceColor = const Color(0xFFFFFFFF);
  final Color borderColor = const Color(0xFFE2E8F0);
  final Color oceanBlue = const Color(0xFF2563EB);
  final Color rosePink = const Color(0xFFE11D48);

  // --- CAROUSEL STATE ---
  late PageController _pageController;
  List<String> _imageUrls = [];
  int _currentImageIndex = 0;
  Timer? _carouselTimer;

  // --- DATA STATE ---
  List<Map<String, dynamic>> _reviews = [];
  final Map<String, Map<String, dynamic>> _userProfiles = {};
  Map<String, dynamic>? _myReview;
  bool _isLoadingReviews = true;
  double _averageRating = 0.0;
  bool _isFavorited = false;
  int _totalLikes = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _parseImages();
    _startCarousel();
    _fetchReviews();
    _fetchLikedState();
    _fetchTotalLikes();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _parseImages() {
    final raw = widget.spotData['spot_images'];
    if (raw != null) {
      try {
        _imageUrls = List<String>.from(raw is String ? jsonDecode(raw) : raw);
      } catch (e) {
        debugPrint("Image Error: $e");
      }
    }
  }

  void _startCarousel() {
    if (_imageUrls.length <= 1) return;
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients) {
        int nextPage = (_currentImageIndex + 1) % _imageUrls.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 900),
          curve: Curves.fastOutSlowIn,
        );
      }
    });
  }

  // --- HELPERS ---

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(date.year, date.month, date.day);
    final dayDiff = today.difference(that).inDays;

    if (dayDiff <= 0) return "Today";
    if (dayDiff == 1) return "Yesterday";
    if (dayDiff < 7) return "$dayDiff days ago";
    if (dayDiff < 30) {
      final weeks = (dayDiff / 7).floor();
      return weeks == 1 ? "1 week ago" : "$weeks weeks ago";
    }
    if (dayDiff < 365) {
      final months = (dayDiff / 30).floor();
      return months == 1 ? "1 month ago" : "$months months ago";
    }
    final years = (dayDiff / 365).floor();
    return years == 1 ? "1 year ago" : "$years years ago";
  }

  // --- DATABASE ACTIONS ---

  Future<void> _fetchLikedState() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;
    try {
      final response = await _supabase
          .from('tourist_spot_likes')
          .select('like_id')
          .eq('like_user_id', currentUser.id)
          .eq('like_spot_id', widget.spotData['spot_id'].toString())
          .maybeSingle();
      if (mounted) setState(() => _isFavorited = response != null);
    } catch (e) { debugPrint("Error fetching liked state: $e"); }
  }

  Future<void> _fetchTotalLikes() async {
    try {
      final response = await _supabase
          .from('tourist_spot_likes')
          .count(CountOption.exact)
          .eq('like_spot_id', widget.spotData['spot_id'].toString());
      if (mounted) setState(() => _totalLikes = response);
    } catch (e) { debugPrint("Error fetching total likes: $e"); }
  }

  Future<void> _toggleLike() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please log in to favorite.")));
      return;
    }
    final spotId = widget.spotData['spot_id'].toString();
    final userId = currentUser.id;

    setState(() {
      _isFavorited = !_isFavorited;
      _isFavorited ? _totalLikes++ : _totalLikes = max(0, _totalLikes - 1);
    });

    try {
      if (_isFavorited) {
        await _supabase.from('tourist_spot_likes').insert({
          'like_id': 'LIKE_${DateTime.now().millisecondsSinceEpoch}_$userId',
          'like_spot_id': spotId,
          'like_user_id': userId,
          'like_date': DateTime.now().millisecondsSinceEpoch
        });
      } else {
        await _supabase.from('tourist_spot_likes').delete().eq('like_user_id', userId).eq('like_spot_id', spotId);
      }
    } catch (e) { if (mounted) _fetchLikedState(); }
  }

  Future<void> _fetchReviews() async {
    final spotId = widget.spotData['spot_id']?.toString();
    if (spotId == null) return;
    try {
      final response = await _supabase.from('tourist_spot_review').select().eq('review_spot_id', spotId).order('review_date', ascending: false);
      final fetched = List<Map<String, dynamic>>.from(response);
      double totalStars = 0;
      Set<String> userIds = {};

      for (var r in fetched) {
        totalStars += (r['review_rate'] as num?)?.toDouble() ?? 0.0;
        userIds.add(r['review_user_id'].toString());
        if (_supabase.auth.currentUser != null && r['review_user_id'] == _supabase.auth.currentUser!.id) {
          _myReview = r;
        }
      }

      if (userIds.isNotEmpty) {
        final profiles = await _supabase.from('user_data').select('user_id, user_name, avatar_url').inFilter('user_id', userIds.toList());
        for (var p in profiles) {
          _userProfiles[p['user_id'].toString()] = p;
        }
      }

      if (mounted) {
        setState(() {
          _reviews = fetched;
          _averageRating = fetched.isNotEmpty ? (totalStars / fetched.length) : 0.0;
          _isLoadingReviews = false;
        });
      }
    } catch (e) { debugPrint("Review Error: $e"); }
  }

  Future<void> _launchDirections() async {
    var coords = widget.spotData['spot_coordinates'];
    if (coords == null) return;
    if (coords is String) coords = jsonDecode(coords);
    final lat = coords['latitude'] ?? coords['lat'];
    final lng = coords['longitude'] ?? coords['lng'] ?? coords['long'];
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void _openReviewBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReviewBottomheet(
        spotId: widget.spotData['spot_id'].toString(),
        existingReview: _myReview,
        onReviewSaved: _fetchReviews,
      ),
    );
  }

  void _openImageViewer(int imageIndex) {
    if (_imageUrls.isEmpty) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return ImageViewer(
            imageUrls: _imageUrls,
            initialIndex: imageIndex,
          );
        },
      ),
    );
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final spot = widget.spotData;

    return Responsive(
      mobile: _buildScrollableLayout(screenHeight: screenHeight, spot: spot, maxWidth: 768, heroFactor: 0.52, minHeroHeight: 360),
      tablet: _buildScrollableLayout(screenHeight: screenHeight, spot: spot, maxWidth: 920, heroFactor: 0.46, minHeroHeight: 380),
      desktop: _buildDesktopLayout(screenHeight: screenHeight, spot: spot),
    );
  }

  Widget _buildScrollableLayout({
    required double screenHeight,
    required Map<String, dynamic> spot,
    required double maxWidth,
    required double heroFactor,
    required double minHeroHeight,
  }) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(screenHeight, heroFactor: heroFactor, minHeroHeight: minHeroHeight),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
                      ),
                      child: Container(
                      transform: Matrix4.translationValues(0.0, -18.0, 0.0),
                      padding: const EdgeInsets.fromLTRB(20, 34, 20, 120),
                      child: _buildDetailsContent(spot, isDesktop: false),
                    ),
                    ),
                  ),
                ),
              )
            ],
          ),
          _buildFloatingActionBar(),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout({required double screenHeight, required Map<String, dynamic> spot}) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Row(
        children: [
          Expanded(
            flex: 5,
            child: SizedBox(
              height: screenHeight,
              child: _buildHeroStack(
                titleFontSize: 42,
                titleBottom: 92,
                horizontalPadding: 32,
                showDotsBottom: 42,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(32, 32, 32, 120),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: _buildDetailsContent(spot, isDesktop: true),
                    ),
                  ),
                ),
                _buildFloatingActionBar(isDesktop: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsContent(Map<String, dynamic> spot, {required bool isDesktop}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMainInfoCard(spot),
        const SizedBox(height: 24),
        Text("About this destination", style: TextStyle(fontSize: isDesktop ? 22 : 20, color: textMain, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(isDesktop ? 20 : 18),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 16, offset: const Offset(0, 8))],
          ),
          child: Text(
            (spot['spot_description'] ?? 'No description available yet.').toString(),
            style: TextStyle(color: textMain.withValues(alpha: 0.86), fontSize: isDesktop ? 16 : 15, height: 1.65, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 28),
        _buildGoogleMapsReviewHeader(spot),
        const SizedBox(height: 24),
        _buildReviewList(),
      ],
    );
  }

  Widget _buildSliverAppBar(double screenHeight, {required double heroFactor, required double minHeroHeight}) {
    return SliverAppBar(
      expandedHeight: max(minHeroHeight, screenHeight * heroFactor),
      pinned: true,
      stretch: true,
      backgroundColor: primaryDark,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: _buildHeroStack(),
      ),
    );
  }

  Widget _buildHeroStack({
    double titleFontSize = 34,
    double titleBottom = 88,
    double horizontalPadding = 20,
    double showDotsBottom = 60,
  }) {
    return StatefulBuilder(
      builder: (context, setCarouselState) {
        return Stack(
                fit: StackFit.expand,
                children: [
                  // 1. PAGEVIEW (GESTURE TARGET)
                  ScrollConfiguration(
                    behavior: DraggableScrollBehavior(),
                    child: _imageUrls.isEmpty
                        ? Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF064E3B), Color(0xFF0F766E), Color(0xFF38BDF8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Center(child: Icon(Icons.landscape_rounded, color: Colors.white, size: 72)),
                          )
                        : PageView.builder(
                            controller: _pageController,
                            allowImplicitScrolling: true,
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _imageUrls.length,
                            onPageChanged: (i) => setCarouselState(() => _currentImageIndex = i),
                            itemBuilder: (_, i) => GestureDetector(
                              onTap: () => _openImageViewer(i),
                              behavior: HitTestBehavior.opaque,
                              child: Hero(tag: 'hero_${_imageUrls[i]}', child: Image.network(_imageUrls[i], fit: BoxFit.cover)),
                            ),
                          ),
                  ),

                  // 2. GRADIENT OVERLAY (WRAPPED IN IGNOREPOINTER)
                  IgnorePointer(
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.5),
                                  Colors.black.withValues(alpha: 0.05),
                                  Colors.black.withValues(alpha: 0.72)
                                ]
                            )
                        )
                    ),
                  ),

                  // 3. INTERACTIVE BUTTONS (STAY OUTSIDE IGNOREPOINTER)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 16,
                    child: _buildGlassButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
                  ),
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    right: 16,
                    child: _buildGlassButton(icon: _isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded, onTap: _toggleLike),
                  ),

                  Positioned(
                    left: horizontalPadding,
                    right: horizontalPadding,
                    bottom: titleBottom,
                    child: IgnorePointer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatusIndicator((widget.spotData['spot_status'] ?? '').toString().toLowerCase() == 'opened', onImage: true),
                          const SizedBox(height: 12),
                          Text(
                            widget.spotData['spot_label'] ?? '',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: titleFontSize, height: 1.05, letterSpacing: -0.7),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Row(children: const [
                            Icon(Icons.location_on_rounded, color: Colors.white70, size: 17),
                            SizedBox(width: 6),
                            Text("Gasan, Marinduque", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                          ]),
                        ],
                      ),
                    ),
                  ),

                  // 4. DOT INDICATORS
                  if (_imageUrls.length > 1)
                    Positioned(
                        bottom: showDotsBottom,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(_imageUrls.length, (idx) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  width: _currentImageIndex == idx ? 24 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                      color: _currentImageIndex == idx ? Colors.white : Colors.white.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(4)
                                  )
                              ))
                          ),
                        )
                    ),
                ],
              );
      },
    );
  }

  Widget _buildGlassButton({required IconData icon, required VoidCallback onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3))
              ),
              child: Icon(icon, color: Colors.white, size: 20)
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(bool isOpen, {bool onImage = false}) {
    final color = isOpen ? accentEmerald : rosePink;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: onImage ? Colors.white.withValues(alpha: 0.18) : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: onImage ? Colors.white.withValues(alpha: 0.32) : color.withValues(alpha: 0.15))
        ),
        child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: onImage ? Colors.white : color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(isOpen ? "OPEN NOW" : "CLOSED", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: onImage ? Colors.white : color, letterSpacing: 0.5))
            ]
        )
    );
  }

  Widget _buildMainInfoCard(Map<String, dynamic> spot) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(spot['spot_label'] ?? '', style: TextStyle(color: textMain, fontWeight: FontWeight.w900, fontSize: 28, height: 1.05, letterSpacing: -0.6)),
              const SizedBox(height: 10),
              Row(children: [Icon(Icons.location_on_rounded, color: accentEmerald, size: 17), const SizedBox(width: 6), Text("Gasan, Marinduque", style: TextStyle(color: textSub, fontSize: 14, fontWeight: FontWeight.w700))]),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final isTight = constraints.maxWidth < 420;
              final tiles = [
                _buildMetricTile(Icons.star_rounded, _averageRating == 0 ? "New" : _averageRating.toStringAsFixed(1), "${_reviews.length} reviews", starGold),
                _buildMetricTile(Icons.favorite_rounded, _formatCount(_totalLikes), "favorites", rosePink),
                _buildMetricTile(Icons.photo_library_rounded, _imageUrls.length.toString(), "photos", oceanBlue),
              ];

              if (isTight) {
                return Column(
                  children: [
                    Row(children: [Expanded(child: tiles[0]), const SizedBox(width: 10), Expanded(child: tiles[1])]),
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: tiles[2]),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: tiles[0]),
                  const SizedBox(width: 10),
                  Expanded(child: tiles[1]),
                  const SizedBox(width: 10),
                  Expanded(child: tiles[2]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withValues(alpha: 0.12))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: textMain, fontSize: 18, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: textSub, fontSize: 11, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildGoogleMapsReviewHeader(dynamic spot) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Traveler reviews", style: TextStyle(fontSize: 22, color: textMain, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 16, offset: const Offset(0, 8))],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isTight = constraints.maxWidth < 420;
              final ratingSummary = Column(
                crossAxisAlignment: isTight ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                  children: [
                    Row(children: List.generate(5, (index) => Icon(index < _averageRating.floor() ? Icons.star_rounded : Icons.star_border_rounded, color: starGold, size: 20))),
                    const SizedBox(height: 4),
                    Text("${_reviews.length} reviews from visitors", style: TextStyle(color: textSub, fontSize: 13, fontWeight: FontWeight.w600), textAlign: isTight ? TextAlign.center : TextAlign.start),
                  ],
              );
              final reviewButton = spot['spot_allow_reviews'] == true
                  ? TextButton.icon(
                  onPressed: _openReviewBottomSheet,
                  icon: Icon(_myReview != null ? Icons.edit_rounded : Icons.rate_review_rounded, size: 18),
                  label: Text(_myReview != null ? "Edit" : "Review"),
                  style: TextButton.styleFrom(
                    foregroundColor: oceanBlue,
                    backgroundColor: oceanBlue.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                )
                  : const SizedBox.shrink();

              if (isTight) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(_averageRating == 0 ? "New" : _averageRating.toStringAsFixed(1), style: TextStyle(fontSize: _averageRating == 0 ? 34 : 50, fontWeight: FontWeight.w900, color: textMain, letterSpacing: -1)),
                    const SizedBox(height: 10),
                    ratingSummary,
                    if (spot['spot_allow_reviews'] == true) ...[const SizedBox(height: 14), SizedBox(width: double.infinity, child: reviewButton)],
                  ],
                );
              }

              return Row(
                children: [
                  Text(_averageRating == 0 ? "New" : _averageRating.toStringAsFixed(1), style: TextStyle(fontSize: _averageRating == 0 ? 34 : 50, fontWeight: FontWeight.w900, color: textMain, letterSpacing: -1)),
                  const SizedBox(width: 20),
                  Expanded(child: ratingSummary),
                  if (spot['spot_allow_reviews'] == true) reviewButton,
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReviewList() {
    if (_isLoadingReviews) return const Center(child: CircularProgressIndicator());
    if (_reviews.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(22), border: Border.all(color: borderColor)),
        child: Column(
          children: [
            Icon(Icons.rate_review_outlined, color: textSub.withValues(alpha: 0.6), size: 34),
            const SizedBox(height: 10),
            Text("No reviews yet", style: TextStyle(color: textMain, fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 4),
            Text("Be the first tourist to share your experience.", textAlign: TextAlign.center, style: TextStyle(color: textSub, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _reviews.length,
      separatorBuilder: (_, index) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final r = _reviews[i];
        final profile = _userProfiles[r['review_user_id'].toString()];
        final DateTime date = DateTime.fromMillisecondsSinceEpoch((r['review_date'] as num).toInt());
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(22), border: Border.all(color: borderColor)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Builder(builder: (_) {
                  final bool anon = r['review_is_anonymous'] == true;
                  final String? avatar = anon ? null : profile?['avatar_url'];
                  return CircleAvatar(
                    radius: 20,
                    backgroundColor: accentEmerald.withValues(alpha: 0.1),
                    backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                    child: avatar == null ? Icon(anon ? Icons.visibility_off_rounded : Icons.person_rounded, color: accentEmerald, size: 20) : null,
                  );
                }),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r['review_is_anonymous'] == true ? "Anonymous traveler" : (profile?['user_name'] ?? "Tourist"), style: TextStyle(fontWeight: FontWeight.w900, color: textMain), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(_getTimeAgo(date), style: TextStyle(color: textSub, fontSize: 12, fontWeight: FontWeight.w600)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(color: starGold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [Icon(Icons.star_rounded, color: starGold, size: 15), const SizedBox(width: 3), Text("${r['review_rate']}", style: TextStyle(color: textMain, fontWeight: FontWeight.w900, fontSize: 12))]),
                ),
              ]),
              const SizedBox(height: 14),
              Row(children: List.generate(5, (s) => Icon(Icons.star_rounded, color: s < r['review_rate'] ? starGold : Colors.grey.shade300, size: 16))),
              const SizedBox(height: 10),
              Text(r['review_message'] ?? '', style: TextStyle(fontSize: 14.5, height: 1.55, color: textMain.withValues(alpha: 0.86), fontWeight: FontWeight.w500)),
              _buildReviewImages(r['review_images']),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewImages(dynamic raw) {
    if (raw == null) return const SizedBox.shrink();
    List<String> urls = [];
    try {
      final parsed = raw is String ? jsonDecode(raw) : raw;
      urls = List<String>.from(parsed);
    } catch (_) {
      return const SizedBox.shrink();
    }
    if (urls.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: urls.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => Navigator.push(
              context,
              PageRouteBuilder(
                opaque: false,
                pageBuilder: (_, __, ___) => ImageViewer(imageUrls: urls, initialIndex: i),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                urls[i],
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 96,
                  height: 96,
                  color: borderColor,
                  child: Icon(Icons.broken_image_rounded, color: textSub),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionBar({bool isDesktop = false}) {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: SafeArea(
            child: Container(
              padding: EdgeInsets.fromLTRB(isDesktop ? 32 : 16, 12, isDesktop ? 32 : 16, 16),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), border: Border(top: BorderSide(color: borderColor))),
              child: ElevatedButton.icon(
                onPressed: _launchDirections,
                icon: const Icon(Icons.directions_rounded),
                label: const Text("Get directions"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentEmerald,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

