import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Utility/ImageViewer.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/Utility/YouTubeVideoPlayer.dart';
import 'package:gasan_port_tracker/Utility/Responsive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../Dialogs/ClassicDialog.dart';
import '../../Dialogs/LoadingDialog.dart';
import '../../FloatingMessages/SnackbarMessenger.dart';
import 'SubActivities/AddEditTouristSpots.dart';
import 'package:gasan_port_tracker/Activities/Tourism/TouristSpotMap.dart';

class TouristSpots extends StatefulWidget {
  final int municipalZipCode;
  const TouristSpots({super.key, required this.municipalZipCode});

  @override
  State<TouristSpots> createState() => _TouristSpotsState();
}

class _TouristSpotsState extends State<TouristSpots> {
  final _supabase = Supabase.instance.client;
  final _classicDialog = ClassicDialog();
  final _loadingDialog = LoadingDialog();

  // Premium Theme Constants
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryDark = const Color(0xFF0F172A);
  final Color gasanEmerald = const Color(0xFF10B981);
  final Color textSecondary = const Color(0xFF64748B);
  final Color cardBorder = const Color(0xFFE2E8F0);

  List<Map<String, dynamic>> _spots = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _currentFilter = 'All';
  final List<String> _filters = ['All', 'Opened', 'Closed'];
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _fetchSpots();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSpots() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final String query = _searchController.text.trim();

      var builder = _supabase
          .from('tourist_spots')
          .select('''
            *,
            tourist_spot_review(review_rate, review_images),
            tourist_spot_likes(count)
          ''');

      if (widget.municipalZipCode != 0) {
        builder = builder.eq("spot_municipality", widget.municipalZipCode);
      }

      if (_currentFilter == 'Opened') {
        builder = builder.eq('spot_status', 'opened');
      } else if (_currentFilter == 'Closed') {
        builder = builder.eq('spot_status', 'closed');
      }

      if (query.isNotEmpty) {
        final escaped = query.replaceAll('%', r'\%').replaceAll(',', ' ');
        builder = builder.or('spot_label.ilike.%$escaped%,spot_description.ilike.%$escaped%');
      }

      final response = await builder.order('spot_date_added', ascending: false);

      if (mounted) {
        setState(() {
          _spots = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError("Failed to sync data: $e");
      }
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), _fetchSpots);
  }

  // --- ACTIONS & NAVIGATION ---
  void _navigateToAddEdit([Map<String, dynamic>? spot]) async {
    final bool? refresh = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditTouristSpots(
          existingSpot: spot,
          municipalZipCode: widget.municipalZipCode,
        ),
      ),
    );

    if (refresh == true) _fetchSpots();
  }

  Future<void> _openMaps(String? coordinatesJson) async {
    if (coordinatesJson == null || coordinatesJson.isEmpty) {
      SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "GPS data missing.");
      return;
    }

    try {
      final Map<String, dynamic> coords = jsonDecode(coordinatesJson);
      final lat = coords['latitude'] ?? coords['lat'];
      final lng = coords['longitude'] ?? coords['lng'];
      final Uri url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Invalid coordinates.");
    }
  }

  // --- DELETION WITH STORAGE CLEANUP ---
  Future<void> _deleteSpot(Map<String, dynamic> spot) async {
    final String id = spot['spot_id'].toString();

    _classicDialog.setTitle("Delete Destination");
    _classicDialog.setMessage("Are you sure? This will permanently remove the spot, its reviews, and all associated images.");
    _classicDialog.setPositiveMessage("Delete Everything");
    _classicDialog.setNegativeMessage("Cancel");

    _classicDialog.showTwoButtonDialog(context, (neg) => _classicDialog.dismissDialog(), (pos) async {
      _classicDialog.dismissDialog();
      _loadingDialog.showLoadingDialog(context);

      try {
        // 1. Cleanup Spot Images
        if (spot['spot_images'] != null) {
          final dynamic parsed = spot['spot_images'] is String ? jsonDecode(spot['spot_images']) : spot['spot_images'];
          List<String> imageUrls = List<String>.from(parsed);
          List<String> filePaths = imageUrls.map((url) => url.split('/').last.split('?').first).toList();
          if (filePaths.isNotEmpty) {
            await _supabase.storage.from('spot_images').remove(filePaths);
          }
        }

        // 2. Cleanup Review Images
        List<String> reviewImagePaths = [];
        final reviews = spot['tourist_spot_review'] as List?;
        if (reviews != null) {
          for (var review in reviews) {
            if (review['review_images'] != null && review['review_images'].toString().length > 2) {
              try {
                final dynamic parsed = review['review_images'] is String ? jsonDecode(review['review_images']) : review['review_images'];
                List<String> urls = List<String>.from(parsed);
                reviewImagePaths.addAll(urls.map((url) => url.split('/').last.split('?').first));
              } catch (e) {
                debugPrint("Failed to parse review images: $e");
              }
            }
          }
        }

        if (reviewImagePaths.isNotEmpty) {
          await _supabase.storage.from('review_images').remove(reviewImagePaths);
        }

        // 3. Delete Database Record (Cascades automatically)
        await _supabase.from('tourist_spots').delete().eq('spot_id', id);

        if (mounted) {
          _loadingDialog.dismiss();
          SnackbarMessenger().showSnackbar(context, SnackbarMessenger.success, "Spot and all media successfully removed.");
          _fetchSpots();
        }
      } catch (e) {
        if (mounted) {
          _loadingDialog.dismiss();
          _showError("Deletion failed: $e");
        }
      }
    });
  }

  // --- REFINED BOTTOM SHEET ---
  void _showOptionsBottomSheet(Map<String, dynamic> spot) {
    final String label = spot['spot_label'] ?? "Options";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: Text(label, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: primaryDark, letterSpacing: -0.5))),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSheetItem(
                  icon: Icons.star_outline_rounded,
                  label: "Reviews & Feedback",
                  color: const Color(0xFFF59E0B),
                  onTap: () => Navigator.pop(context), 
                ),
                const SizedBox(height: 12),
                _buildSheetItem(
                    icon: Icons.map_rounded,
                    label: "View on Map",
                    color: const Color(0xFF3B82F6),
                    onTap: () {
                      Navigator.pop(context);
                      final coords = spot['spot_coordinates'];
                      _openMaps(coords is String ? coords : jsonEncode(coords));
                    }
                ),
                const SizedBox(height: 12),
                _buildSheetItem(
                    icon: Icons.edit_rounded,
                    label: "Edit Spot Details",
                    color: gasanEmerald,
                    onTap: () { Navigator.pop(context); _navigateToAddEdit(spot); }
                ),
                const SizedBox(height: 12),
                _buildSheetItem(
                    icon: Icons.delete_outline_rounded,
                    label: "Delete Permanently",
                    color: const Color(0xFFEF4444),
                    onTap: () { Navigator.pop(context); _deleteSpot(spot); }
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetItem({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: primaryDark)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: textSecondary.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        title: const Text("Tourist Spots", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: Icon(Icons.add_circle_rounded, color: gasanEmerald, size: 32),
              onPressed: () => _navigateToAddEdit(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilterBar(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: gasanEmerald))
                : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: Responsive.isDesktop(context) ? 1200 : 840),
                child: RefreshIndicator(
                  onRefresh: _fetchSpots,
                  color: gasanEmerald,
                  child: _spots.isEmpty
                      ? _buildEmptyState()
                      : Responsive(
                    mobile: ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _spots.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 20),
                      itemBuilder: (context, index) => _PremiumSpotCard(
                        spot: _spots[index],
                        onTap: () => _showOptionsBottomSheet(_spots[index]),
                        onEdit: () => _navigateToAddEdit(_spots[index]),
                        onDelete: () => _deleteSpot(_spots[index]),
                      ),
                    ),
                    tablet: GridView.builder(
                      padding: const EdgeInsets.all(20),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 18,
                        mainAxisSpacing: 18,
                        mainAxisExtent: 380,
                      ),
                      itemCount: _spots.length,
                      itemBuilder: (context, index) => _PremiumSpotCard(
                        spot: _spots[index],
                        onTap: () => _showOptionsBottomSheet(_spots[index]),
                        onEdit: () => _navigateToAddEdit(_spots[index]),
                        onDelete: () => _deleteSpot(_spots[index]),
                      ),
                    ),
                    desktop: GridView.builder(
                      padding: const EdgeInsets.all(24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        mainAxisExtent: 370,
                      ),
                      itemCount: _spots.length,
                      itemBuilder: (context, index) => _PremiumSpotCard(
                        spot: _spots[index],
                        onTap: () => _showOptionsBottomSheet(_spots[index]),
                        onEdit: () => _navigateToAddEdit(_spots[index]),
                        onDelete: () => _deleteSpot(_spots[index]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: TextStyle(fontWeight: FontWeight.w600, color: primaryDark),
                decoration: InputDecoration(
                  hintText: "Search destinations...",
                  prefixIcon: Icon(Icons.search_rounded, color: textSecondary),
                  filled: true,
                  fillColor: bgColor,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: gasanEmerald, width: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: _filters.map((filter) {
                  bool isSelected = _currentFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isSelected ? Colors.white : textSecondary)),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) {
                          setState(() => _currentFilter = filter);
                          _fetchSpots();
                        }
                      },
                      backgroundColor: bgColor,
                      selectedColor: gasanEmerald,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide.none,
                      showCheckmark: false,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.travel_explore_rounded, size: 64, color: textSecondary.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(_searchController.text.isEmpty ? "No destinations found yet." : "No results for \"${_searchController.text}\"",
              style: TextStyle(color: textSecondary, fontWeight: FontWeight.w600)),
          if (_searchController.text.isNotEmpty)
            TextButton(
              onPressed: () {
                _searchController.clear();
                _fetchSpots();
              },
              child: Text("Clear Search", style: TextStyle(color: gasanEmerald, fontWeight: FontWeight.w700)),
            )
        ],
      ),
    );
  }

  void _showError(String message) {
    _classicDialog.setTitle("Oops!");
    _classicDialog.setMessage(message);
    _classicDialog.setPositiveMessage("Understood");
    if (mounted) _classicDialog.showOnButtonDialog(context, () => _classicDialog.dismissDialog());
  }
}

// ============================================================================
// PREMIUM SPOT CARD
// ============================================================================

class _PremiumSpotCard extends StatefulWidget {
  final Map<String, dynamic> spot;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PremiumSpotCard({
    required this.spot,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_PremiumSpotCard> createState() => _PremiumSpotCardState();
}

class _PremiumSpotCardState extends State<_PremiumSpotCard> {
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;
  List<String> _imageUrls = [];
  String? _youtubeVideoId;

  int get _totalMediaCount => _imageUrls.length + (_youtubeVideoId != null ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _extractMedia();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _extractMedia() {
    final dynamic rawImages = widget.spot['spot_images'];
    if (rawImages != null) {
      try {
        final dynamic parsed = rawImages is String ? jsonDecode(rawImages) : rawImages;
        _imageUrls = List<String>.from(parsed);
      } catch (e) {
        debugPrint("Failed to parse spot_images: $e");
      }
    }

    final dynamic rawVideos = widget.spot['spot_videos'];
    if (rawVideos != null) {
      try {
        final dynamic parsedVideos = rawVideos is String ? jsonDecode(rawVideos) : rawVideos;
        final List<String> videoUrls = List<String>.from(parsedVideos);
        if (videoUrls.isNotEmpty && videoUrls.first.isNotEmpty) {
          _youtubeVideoId = _extractYoutubeId(videoUrls.first);
        }
      } catch (e) {
        debugPrint("Failed to parse spot_videos: $e");
      }
    }
  }

  String? _extractYoutubeId(String url) {
    final RegExp regExp = RegExp(
        r'(?:(?:https?:)?//)?(?:www\.)?(?:youtube\.com/(?:[^/\n\s]+\/\S+\/|(?:v|e(?:mbed)?)/|\S*?[?&]v=)|youtu\.be/)([a-zA-Z0-9_-]{11})',
        caseSensitive: false,
        multiLine: false);
    final match = regExp.firstMatch(url);
    if (match != null && match.groupCount >= 1) return match.group(1);
    return null;
  }

  void _openImageViewer(int imageIndex) {
    if (_imageUrls.isEmpty) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, _, __) {
          return ImageViewer(
            imageUrls: _imageUrls,
            initialIndex: imageIndex,
          );
        },
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  double _calculateRating() {
    final reviews = widget.spot['tourist_spot_review'] as List?;
    if (reviews == null || reviews.isEmpty) return 0.0;
    double sum = reviews.fold(0, (prev, el) => prev + (el['review_rate'] as num));
    return sum / reviews.length;
  }

  int _getLikeCount() {
    final likesData = widget.spot['tourist_spot_likes'] as List?;
    if (likesData == null || likesData.isEmpty) return 0;
    return (likesData.first['count'] as num?)?.toInt() ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final double rating = _calculateRating();
    final int likes = _getLikeCount();
    final String status = (widget.spot['spot_status'] ?? 'closed').toString().toLowerCase();
    final bool isOpened = status == 'opened';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // MEDIA SECTION
            Stack(
              children: [
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentImageIndex = i),
                    itemCount: _totalMediaCount,
                    itemBuilder: (context, index) {
                      if (_youtubeVideoId != null && index == 0) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => YouTubeVideoPlayer(videoId: _youtubeVideoId!),
                            ));
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network('https://img.youtube.com/vi/$_youtubeVideoId/hqdefault.jpg', fit: BoxFit.cover),
                              Container(color: Colors.black.withValues(alpha: 0.3)),
                              const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 56)),
                            ],
                          ),
                        );
                      }

                      final int imageIndex = _youtubeVideoId != null ? index - 1 : index;
                      return GestureDetector(
                        onTap: () => _openImageViewer(imageIndex),
                        child: Hero(
                          tag: 'hero_${_imageUrls[imageIndex]}',
                          child: Image.network(
                            _imageUrls[imageIndex],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: const Color(0xFFF1F5F9), child: const Icon(Icons.broken_image, color: Colors.grey)),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Indicators
                if (_totalMediaCount > 1)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
                      child: Text("${_currentImageIndex + 1}/$_totalMediaCount", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),

                // Status Badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isOpened ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                    ),
                    child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.spot['spot_label'] ?? "Unnamed Destination",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.3),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _buildMiniStat(Icons.star_rounded, const Color(0xFFF59E0B), rating == 0 ? "N/A" : rating.toStringAsFixed(1)),
                      const SizedBox(width: 6),
                      _buildMiniStat(Icons.favorite_rounded, const Color(0xFFEF4444), likes.toString()),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.spot['spot_description'] ?? "No description provided.",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onEdit,
                          icon: const Icon(Icons.edit_rounded, size: 15),
                          label: const Text("Edit", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onTap,
                          icon: const Icon(Icons.more_horiz_rounded, size: 15),
                          label: const Text("Options", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 38,
                        height: 36,
                        child: IconButton(
                          onPressed: widget.onDelete,
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFFEE2E2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
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
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
      ],
    );
  }
}
