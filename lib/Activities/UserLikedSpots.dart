import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../Dialogs/LoadingDialog.dart';
import '../../FloatingMessages/SnackbarMessenger.dart';
import 'package:gasan_port_tracker/Utility/Responsive.dart';
import 'Tourism/TouristSpotDetails.dart';

class UserLikedSpots extends StatefulWidget {
  const UserLikedSpots({super.key});

  @override
  State<UserLikedSpots> createState() => _UserLikedSpotsState();
}

class _UserLikedSpotsState extends State<UserLikedSpots> {
  final _supabase = Supabase.instance.client;
  final _loadingDialog = LoadingDialog();

  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryDark = const Color(0xFF0F172A);
  final Color govBlue = const Color(0xFF1565C0);
  final Color accentEmerald = const Color(0xFF10B981);
  final Color rosePink = const Color(0xFFEF4444);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);
  final Color cardBorder = const Color(0xFFE2E8F0);
  final Color starGold = const Color(0xFFF59E0B);

  bool _isLoading = true;
  List<dynamic> _likedSpotIds = [];
  List<Map<String, dynamic>> _validSpotsData = [];

  @override
  void initState() {
    super.initState();
    _fetchLikedSpots();
  }

  Future<void> _fetchLikedSpots() async {
    setState(() => _isLoading = true);
    try {
      final String userId = _supabase.auth.currentUser!.id;
      final likesRes = await _supabase
          .from('tourist_spot_likes')
          .select('like_spot_id')
          .eq('like_user_id', userId)
          .order('like_date', ascending: false);

      _likedSpotIds = likesRes.map((like) => like['like_spot_id']).toList();

      if (_likedSpotIds.isNotEmpty) {
        final List<Object> queryIds = _likedSpotIds.map((e) => e as Object).toList();
        final spotsRes = await _supabase
            .from('tourist_spots')
            .select('*, tourist_spot_review(review_rate)')
            .inFilter('spot_id', queryIds);
        _validSpotsData = List<Map<String, dynamic>>.from(spotsRes);
      } else {
        _validSpotsData = [];
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Failed to load liked spots.");
      }
    }
  }

  Future<void> _removeSpot(dynamic spotIdToRemove) async {
    _loadingDialog.showLoadingDialog(context);
    try {
      final String userId = _supabase.auth.currentUser!.id;
      await _supabase
          .from('tourist_spot_likes')
          .delete()
          .eq('like_spot_id', spotIdToRemove)
          .eq('like_user_id', userId);

      if (mounted) {
        _loadingDialog.dismiss();
        SnackbarMessenger().showSnackbar(context, SnackbarMessenger.success, "Removed from saved spots.");
        _fetchLikedSpots();
      }
    } catch (e) {
      if (mounted) {
        _loadingDialog.dismiss();
        SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Failed to remove spot.");
      }
    }
  }

  void _navigateToViewSpot(Map<String, dynamic> spot) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TouristSpotDetails(spotData: spot)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        centerTitle: false,
        title: const Text(
          "Saved Destinations",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19, letterSpacing: -0.5),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: cardBorder, height: 1),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: govBlue, strokeWidth: 3))
          : RefreshIndicator(
              onRefresh: _fetchLikedSpots,
              color: govBlue,
              backgroundColor: Colors.white,
              child: _likedSpotIds.isEmpty
                  ? _buildEmptyState()
                  : Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: Responsive.isDesktop(context) ? 1280 : 920),
                        child: _buildGrid(),
                      ),
                    ),
            ),
    );
  }

  Widget _buildGrid() {
    int crossAxis;
    double extent;
    EdgeInsets pad;
    if (Responsive.isDesktop(context)) {
      crossAxis = 4;
      extent = 290;
      pad = const EdgeInsets.fromLTRB(24, 20, 24, 28);
    } else if (Responsive.isTablet(context)) {
      crossAxis = 3;
      extent = 280;
      pad = const EdgeInsets.fromLTRB(18, 18, 18, 24);
    } else {
      crossAxis = 2;
      extent = 270;
      pad = const EdgeInsets.fromLTRB(14, 14, 14, 24);
    }

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: pad,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxis,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        mainAxisExtent: extent,
      ),
      itemCount: _likedSpotIds.length,
      itemBuilder: (context, index) {
        final currentId = _likedSpotIds[index];
        final spotData = _validSpotsData.where((spot) => spot['spot_id'].toString() == currentId.toString()).toList();
        if (spotData.isEmpty) return _buildMissingCard(currentId);
        return _buildSpotCard(spotData.first);
      },
    );
  }

  Widget _buildSpotCard(Map<String, dynamic> spot) {
    String? imageUrl;
    int imageCount = 0;
    final dynamic rawImages = spot['spot_images'];
    if (rawImages != null) {
      try {
        final List<String> urls = List<String>.from(rawImages is String ? jsonDecode(rawImages) : rawImages);
        imageCount = urls.length;
        if (urls.isNotEmpty) imageUrl = urls.first;
      } catch (_) {}
    }

    double rating = 0.0;
    final reviews = spot['tourist_spot_review'] as List?;
    final int reviewCount = reviews?.length ?? 0;
    if (reviews != null && reviews.isNotEmpty) {
      rating = reviews.fold(0.0, (sum, r) => sum + (r['review_rate'] as num)) / reviews.length;
    }

    final String status = (spot['spot_status'] ?? '').toString().toLowerCase();
    final bool isOpen = status == 'opened';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _navigateToViewSpot(spot),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 150,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      imageUrl != null
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: bgColor,
                                child: Icon(Icons.broken_image_rounded, color: textSecondary.withValues(alpha: 0.4)),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [govBlue.withValues(alpha: 0.8), accentEmerald.withValues(alpha: 0.7)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Center(child: Icon(Icons.landscape_rounded, color: Colors.white, size: 38)),
                            ),
                      IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isOpen ? accentEmerald : rosePink).withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 5, height: 5, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                              const SizedBox(width: 5),
                              Text(
                                isOpen ? "OPEN" : "CLOSED",
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.white.withValues(alpha: 0.95),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _removeSpot(spot['spot_id']),
                            child: Padding(
                              padding: const EdgeInsets.all(7),
                              child: Icon(Icons.favorite_rounded, color: rosePink, size: 16),
                            ),
                          ),
                        ),
                      ),
                      if (imageCount > 1)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.photo_library_rounded, color: Colors.white, size: 10),
                                const SizedBox(width: 3),
                                Text("$imageCount", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spot['spot_label'] ?? "Unnamed",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: textPrimary, letterSpacing: -0.3),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded, size: 11, color: textSecondary),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                "Gasan, Marinduque",
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.star_rounded, color: starGold, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                rating == 0 ? "New" : rating.toStringAsFixed(1),
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: textPrimary),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "($reviewCount)",
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: textSecondary),
                              ),
                              const Spacer(),
                              Icon(Icons.arrow_forward_rounded, color: govBlue, size: 14),
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
      ),
    );
  }

  Widget _buildMissingCard(dynamic missingId) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder, style: BorderStyle.solid),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: rosePink.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.visibility_off_rounded, color: rosePink.withValues(alpha: 0.7), size: 26),
            ),
            const SizedBox(height: 10),
            Text("Unavailable", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: textPrimary)),
            const SizedBox(height: 4),
            Text(
              "This spot was removed.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textSecondary),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: rosePink,
                backgroundColor: rosePink.withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _removeSpot(missingId),
              icon: const Icon(Icons.delete_outline_rounded, size: 14),
              label: const Text("Clear", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: govBlue.withValues(alpha: 0.08), blurRadius: 30, spreadRadius: 5)],
                  ),
                  child: Icon(Icons.favorite_border_rounded, size: 56, color: govBlue.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: 24),
                Text(
                  "No Saved Spots Yet",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: primaryDark, letterSpacing: -0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  "Destinations you heart will\nappear right here.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textSecondary, fontSize: 14, height: 1.4, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

