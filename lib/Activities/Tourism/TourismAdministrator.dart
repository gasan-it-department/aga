import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Activities/Tourism/TouristSpots.dart';
import 'package:gasan_port_tracker/Activities/Tourism/TourismEventsBanner.dart';
import 'package:gasan_port_tracker/Dialogs/ClassicDialog.dart';
import 'package:gasan_port_tracker/Dialogs/LoadingDialog.dart';
import 'package:gasan_port_tracker/Utility/Responsive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TourismAdministrator extends StatefulWidget {
  const TourismAdministrator({super.key});

  @override
  State<TourismAdministrator> createState() => _TourismAdministratorState();
}

class _TourismAdministratorState extends State<TourismAdministrator> {
  final _supabase = Supabase.instance.client;

  final Color bgColor = const Color(0xFFF8FAFC);
  final Color surfaceColor = const Color(0xFFFFFFFF);
  final Color primaryDark = const Color(0xFF0F172A);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);
  final Color borderColor = const Color(0xFFE2E8F0);
  final Color lockedBgColor = const Color(0xFFF1F5F9);
  final Color tourismGreen = const Color(0xFF10B981);
  final Color reviewAmber = const Color(0xFFF59E0B);
  final Color likeRose = const Color(0xFFF43F5E);
  final Color oceanBlue = const Color(0xFF3B82F6);
  final Color violet = const Color(0xFF8B5CF6);

  final _loadingDialog = LoadingDialog();
  final _classicDialog = ClassicDialog();

  String _userName = "Loading...";
  String _userEmail = "";
  String? _avatarUrl;
  String _municipalityName = "Tourism";
  int _municipalZipCode = 4905;

  int _totalSpots = 0;
  int _openedSpots = 0;
  int _closedSpots = 0;
  int _totalReviews = 0;
  int _totalLikes = 0;
  double _avgRating = 0.0;

  List<double> _ratingDistribution = List.filled(5, 0.0);
  List<double> _weeklyReviewCounts = List.filled(7, 0.0);
  List<double> _monthlyReviewCounts = List.filled(12, 0.0);
  List<double> _monthlyLikeCounts = List.filled(12, 0.0);
  List<MapEntry<String, int>> _topLikedSpots = [];
  List<MapEntry<String, double>> _topRatedSpots = [];
  List<Map<String, dynamic>> _latestReviews = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAdminData());
  }

  Future<void> _loadAdminData() async {
    _loadingDialog.showLoadingDialog(context);
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _loadingDialog.dismiss();
      return;
    }

    try {
      final userData = await _supabase.from('user_data').select().eq('user_id', user.id).maybeSingle();
      if (userData != null) {
        final zip = _extractZipCode(userData['user_access']);
        if (mounted) {
          setState(() {
            _userName = userData['user_name'] ?? "Tourism Officer";
            _userEmail = userData['user_account'] ?? "";
            _avatarUrl = userData['avatar_url'];
            _municipalZipCode = zip;
            _municipalityName = _getMunicipalityName(zip.toString());
          });
        }
        await _fetchAnalytics(zip);
      }
      _loadingDialog.dismiss();
    } catch (e, stacktrace) {
      debugPrint("Error loading tourism admin data: $e");
      _loadingDialog.dismiss();
      _classicDialog.setTitle("An error occurred!");
      _classicDialog.setMessage("${e.toString()}\n\nStacktrace:\n$stacktrace");
      _classicDialog.setCancelable(false);
      _classicDialog.setPositiveMessage("Close");
      if (mounted) _classicDialog.showOnButtonDialog(context, () => _classicDialog.dismissDialog());
    }
  }

  int _extractZipCode(dynamic accessData) {
    if (accessData is Map && accessData['municipality_zip_code'] != null) {
      return int.tryParse(accessData['municipality_zip_code'].toString()) ?? 4905;
    }

    if (accessData is List && accessData.isNotEmpty) {
      for (final accessItem in accessData) {
        if (accessItem is Map && accessItem['municipality_zip_code'] != null) {
          return int.tryParse(accessItem['municipality_zip_code'].toString()) ?? 4905;
        }
      }
    }

    return 4905;
  }

  Future<void> _fetchAnalytics(int zipCode) async {
    try {
      final spotsResponse = await _supabase
          .from('tourist_spots')
          .select('spot_id, spot_label, spot_status')
          .eq('spot_municipality', zipCode);

      final spots = List<Map<String, dynamic>>.from(spotsResponse as List);
      final spotIds = spots.map((spot) => spot['spot_id'].toString()).toList();
      final spotNames = {
        for (final spot in spots) spot['spot_id'].toString(): (spot['spot_label'] ?? 'Unnamed spot').toString(),
      };

      List<Map<String, dynamic>> reviews = [];
      List<Map<String, dynamic>> likes = [];
      if (spotIds.isNotEmpty) {
        final reviewsResponse = await _supabase
            .from('tourist_spot_review')
            .select('review_spot_id, review_rate, review_message, review_date')
            .inFilter('review_spot_id', spotIds)
            .order('review_date', ascending: false);

        final likesResponse = await _supabase
            .from('tourist_spot_likes')
            .select('like_spot_id, like_date')
            .inFilter('like_spot_id', spotIds)
            .order('like_date', ascending: false);

        reviews = List<Map<String, dynamic>>.from(reviewsResponse as List);
        likes = List<Map<String, dynamic>>.from(likesResponse as List);
      }

      final now = DateTime.now();
      final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      final weeklyReviews = List<double>.filled(7, 0.0);
      final monthlyReviews = List<double>.filled(12, 0.0);
      final monthlyLikes = List<double>.filled(12, 0.0);
      final ratingDistribution = List<double>.filled(5, 0.0);
      final ratingsBySpot = <String, List<double>>{};
      final likesBySpot = <String, int>{};

      double totalRating = 0;
      for (final review in reviews) {
        final rating = ((review['review_rate'] as num?)?.toDouble() ?? 0).clamp(1.0, 5.0).toDouble();
        final roundedRating = rating.round().clamp(1, 5).toInt();
        ratingDistribution[roundedRating - 1]++;
        totalRating += rating;

        final spotId = review['review_spot_id'].toString();
        ratingsBySpot.putIfAbsent(spotId, () => []).add(rating);

        final date = _epochToDate(review['review_date']);
        if (date != null && date.year == now.year) {
          monthlyReviews[date.month - 1]++;
          if (!date.isBefore(startOfWeek)) weeklyReviews[date.weekday - 1]++;
        }
      }

      for (final like in likes) {
        final spotId = like['like_spot_id'].toString();
        likesBySpot[spotId] = (likesBySpot[spotId] ?? 0) + 1;

        final date = _epochToDate(like['like_date']);
        if (date != null && date.year == now.year) {
          monthlyLikes[date.month - 1]++;
        }
      }

      final topLiked = likesBySpot.entries
          .map((entry) => MapEntry(spotNames[entry.key] ?? 'Unnamed spot', entry.value))
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final topRated = ratingsBySpot.entries
          .where((entry) => entry.value.isNotEmpty)
          .map((entry) {
        final average = entry.value.reduce((a, b) => a + b) / entry.value.length;
        return MapEntry(spotNames[entry.key] ?? 'Unnamed spot', average);
      })
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final opened = spots.where((spot) => spot['spot_status']?.toString().toLowerCase() == 'opened').length;

      if (mounted) {
        setState(() {
          _totalSpots = spots.length;
          _openedSpots = opened;
          _closedSpots = spots.length - opened;
          _totalReviews = reviews.length;
          _totalLikes = likes.length;
          _avgRating = reviews.isNotEmpty ? totalRating / reviews.length : 0.0;
          _ratingDistribution = ratingDistribution;
          _weeklyReviewCounts = weeklyReviews;
          _monthlyReviewCounts = monthlyReviews;
          _monthlyLikeCounts = monthlyLikes;
          _topLikedSpots = topLiked.take(5).toList();
          _topRatedSpots = topRated.take(5).toList();
          _latestReviews = reviews.take(6).toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching tourism analytics: $e");
    }
  }

  DateTime? _epochToDate(dynamic value) {
    if (value == null) return null;
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return DateTime.tryParse(value.toString());
  }

  String _getMunicipalityName(String zipCode) {
    switch (zipCode) {
      case "4900":
        return "Boac";
      case "4901":
        return "Mogpog";
      case "4902":
        return "Santa Cruz";
      case "4903":
        return "Torrijos";
      case "4904":
        return "Buenavista";
      case "4905":
        return "Gasan";
      case "0000":
        return "Provincial Tourism";
      default:
        return "Municipality ($zipCode)";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Responsive(
        mobile: _buildMobileLayout(),
        tablet: _buildTabletLayout(),
        desktop: _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildMobileLayout() => Scaffold(backgroundColor: bgColor, appBar: _buildAppBar(), body: _buildDashboardContent(crossAxisCount: 2));

  Widget _buildTabletLayout() => Scaffold(backgroundColor: bgColor, appBar: _buildAppBar(), body: _buildDashboardContent(crossAxisCount: 3));

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        _buildSidebar(),
        const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE2E8F0)),
        Expanded(child: Scaffold(backgroundColor: bgColor, appBar: _buildAppBar(isDesktop: true), body: _buildDashboardContent(crossAxisCount: 4, isDesktop: true))),
      ],
    );
  }

  AppBar _buildAppBar({bool isDesktop = false}) {
    return AppBar(
      elevation: 0,
      backgroundColor: surfaceColor,
      foregroundColor: primaryDark,
      centerTitle: false,
      title: const Text("TOURISM PANEL", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5, fontSize: 18)),
      bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: borderColor, height: 1)),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      color: surfaceColor,
      child: Column(
        children: [
          _buildSidebarHeader(),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildSidebarItem(Icons.dashboard_rounded, "Dashboard", true, () {}),
                _buildSidebarItem(Icons.place_rounded, "Tourist Spots", false, () => Navigator.push(context, MaterialPageRoute(builder: (_) => TouristSpots(municipalZipCode: _municipalZipCode)))),
                // ADDED: Events option in the sidebar
                _buildSidebarItem(Icons.event_rounded, "Events", false, () => Navigator.push(context, MaterialPageRoute(builder: (_) => TourismEventsBanner(municipalZipCode: _municipalZipCode)))),
                _buildSidebarItem(Icons.business_rounded, "Establishments", false, _showComingSoon, comingSoon: true),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildSidebarFooter(),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: tourismGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.landscape_rounded, color: tourismGreen, size: 24)),
          const SizedBox(width: 12),
          const Text("TOURISM", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title, bool isActive, VoidCallback onTap, {bool comingSoon = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: isActive ? tourismGreen.withValues(alpha: 0.1) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Icon(icon, color: isActive ? tourismGreen : textSecondary, size: 20),
              const SizedBox(width: 16),
              Expanded(child: Text(title, style: TextStyle(fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, color: isActive ? tourismGreen : textPrimary))),
              if (comingSoon) _comingSoonBadge(),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Establishments — Coming soon!", style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _comingSoonBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: reviewAmber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
      child: Text("SOON", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: reviewAmber, letterSpacing: 0.5)),
    );
  }

  Widget _buildSidebarFooter() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            CircleAvatar(radius: 18, backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty ? NetworkImage(_avatarUrl!) : null, backgroundColor: lockedBgColor, child: _avatarUrl == null || _avatarUrl!.isEmpty ? const Icon(Icons.person, size: 18) : null),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_userName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis), Text(_userEmail, style: TextStyle(color: textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)])),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent({required int crossAxisCount, bool isDesktop = false}) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isDesktop ? 1200 : 800),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            physics: const BouncingScrollPhysics(),
            children: [
              if (!isDesktop) _buildAdminProfileHeader(),
              if (!isDesktop) const SizedBox(height: 24),
              if (!isDesktop) ...[
                _buildSectionTitle(Icons.bolt_rounded, "ACTIVE MODULES", tourismGreen),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 0.85,
                  children: [
                    _buildGridCard(
                      title: "Tourist Spots",
                      subtitle: "$_totalSpots listed destinations.",
                      icon: Icons.place_rounded,
                      iconColor: tourismGreen,
                      isActive: true,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TouristSpots(municipalZipCode: _municipalZipCode))),
                    ),
                    _buildGridCard(
                      title: "Events",
                      subtitle: "Manage tourism events and activities.",
                      icon: Icons.event_rounded,
                      iconColor: violet,
                      isActive: true,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TourismEventsBanner(municipalZipCode: _municipalZipCode))),
                    ),
                    _buildGridCard(
                      title: "Establishments",
                      subtitle: "Hotels, restaurants, and local businesses.",
                      icon: Icons.business_rounded,
                      iconColor: oceanBlue,
                      isActive: false,
                      comingSoon: true,
                      onTap: _showComingSoon,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
              _buildSectionTitle(Icons.insights_rounded, "INSIGHTS & ANALYTICS", primaryDark),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: isDesktop ? 4 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isDesktop ? 1.5 : 1.2,
                children: [
                  _buildStatCard("Destinations", _totalSpots.toString(), tourismGreen, Icons.place_rounded),
                  _buildStatCard("Average Rating", _avgRating == 0 ? "N/A" : _avgRating.toStringAsFixed(1), reviewAmber, Icons.star_rounded),
                  _buildStatCard("Total Reviews", _totalReviews.toString(), oceanBlue, Icons.rate_review_rounded),
                  _buildStatCard("Total Likes", _totalLikes.toString(), likeRose, Icons.favorite_rounded),
                ],
              ),
              const SizedBox(height: 32),
              _buildSectionTitle(Icons.auto_graph_rounded, "REVIEW PERFORMANCE", primaryDark),
              const SizedBox(height: 16),
              _buildWeeklyReviewChart(),
              const SizedBox(height: 32),
              _buildSectionTitle(Icons.stacked_line_chart_rounded, "ADVANCED ENGAGEMENT", primaryDark),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (context, constraints) {
                return Responsive.isMobile(context)
                    ? Column(children: [_buildEngagementTrendChart(), const SizedBox(height: 16), _buildRatingDistribution()])
                    : Row(children: [Expanded(flex: 3, child: _buildEngagementTrendChart()), const SizedBox(width: 24), Expanded(flex: 2, child: _buildRatingDistribution())]);
              }),
              const SizedBox(height: 32),
              _buildSectionTitle(Icons.favorite_rounded, "DESTINATION SIGNALS", likeRose),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (context, constraints) {
                return Responsive.isMobile(context)
                    ? Column(children: [_buildSpotStatusCard(), const SizedBox(height: 16), _buildTopLikedSpotsCard(), const SizedBox(height: 16), _buildTopRatedSpotsCard()])
                    : Row(children: [Expanded(child: _buildSpotStatusCard()), const SizedBox(width: 24), Expanded(child: _buildTopLikedSpotsCard()), const SizedBox(width: 24), Expanded(child: _buildTopRatedSpotsCard())]);
              }),
              const SizedBox(height: 32),
              _buildSectionTitle(Icons.reviews_rounded, "LATEST REVIEWS", textSecondary),
              const SizedBox(height: 16),
              _buildLatestReviewsSection(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Row(children: [
        Container(height: 60, width: 60, decoration: BoxDecoration(color: lockedBgColor, shape: BoxShape.circle, border: Border.all(color: borderColor), image: _avatarUrl != null && _avatarUrl!.isNotEmpty ? DecorationImage(image: NetworkImage(_avatarUrl!), fit: BoxFit.cover) : null), child: _avatarUrl == null || _avatarUrl!.isEmpty ? Icon(Icons.person_rounded, size: 30, color: textSecondary.withValues(alpha: 0.5)) : null),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("ADMINISTRATOR", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: tourismGreen, letterSpacing: 1.5)),
          const SizedBox(height: 2),
          Text(_userName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: primaryDark, letterSpacing: -0.5), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(_userEmail, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: tourismGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: tourismGreen.withValues(alpha: 0.2))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.landscape_rounded, size: 12, color: tourismGreen), const SizedBox(width: 4), Text("TOURISM | $_municipalityName", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: tourismGreen, letterSpacing: 0.5))])),
        ])),
      ]),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)), Flexible(child: Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis))]),
        const Spacer(),
        Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textSecondary, letterSpacing: 0.2), maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _buildWeeklyReviewChart() {
    final maxVal = _weeklyReviewCounts.reduce((curr, next) => curr > next ? curr : next);
    final maxY = maxVal == 0 ? 5.0 : (maxVal / 5).ceil() * 5.0;

    return Container(
      height: 250,
      padding: const EdgeInsets.fromLTRB(16, 20, 24, 16),
      decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Weekly Reviews", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E293B))), Icon(Icons.more_horiz_rounded, size: 18, color: textSecondary)]),
        const SizedBox(height: 24),
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: maxY,
              barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(getTooltipColor: (_) => primaryDark, getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(rod.toY.toInt().toString(), const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)))),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (value, meta) {
                  const days = ["M", "T", "W", "T", "F", "S", "S"];
                  final index = value.toInt();
                  if (index < 0 || index >= days.length) return const SizedBox.shrink();
                  return Padding(padding: const EdgeInsets.only(top: 8), child: Text(days[index], style: TextStyle(color: textSecondary, fontWeight: FontWeight.w700, fontSize: 10)));
                })),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: maxY / 5, getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: TextStyle(color: textSecondary, fontWeight: FontWeight.w700, fontSize: 10)))),
              ),
              gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY / 5, getDrawingHorizontalLine: (value) => FlLine(color: borderColor.withValues(alpha: 0.5), strokeWidth: 1)),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(7, (i) {
                final colors = [tourismGreen, reviewAmber, oceanBlue, likeRose, violet, tourismGreen, textSecondary];
                return BarChartGroupData(x: i, barRods: [BarChartRodData(toY: _weeklyReviewCounts[i], color: colors[i], width: 14, borderRadius: BorderRadius.circular(4), backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxY, color: bgColor))]);
              }),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildEngagementTrendChart() {
    final maxReview = _monthlyReviewCounts.reduce((curr, next) => curr > next ? curr : next);
    final maxLike = _monthlyLikeCounts.reduce((curr, next) => curr > next ? curr : next);
    final maxVal = maxReview > maxLike ? maxReview : maxLike;
    final maxY = maxVal == 0 ? 10.0 : (maxVal / 5).ceil() * 5.0;

    return Container(
      height: 280,
      padding: const EdgeInsets.fromLTRB(16, 20, 24, 16),
      decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Monthly Reviews vs Likes", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A))),
          Row(children: [_buildLegend(reviewAmber, "Reviews"), const SizedBox(width: 12), _buildLegend(likeRose, "Likes")]),
        ]),
        const SizedBox(height: 20),
        Expanded(
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY,
              lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(getTooltipColor: (_) => primaryDark)),
              gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY / 5, getDrawingHorizontalLine: (value) => FlLine(color: borderColor.withValues(alpha: 0.5), strokeWidth: 1)),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 1, getTitlesWidget: (value, meta) {
                  const months = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"];
                  final index = value.toInt();
                  if (index < 0 || index >= months.length) return const SizedBox.shrink();
                  return Padding(padding: const EdgeInsets.only(top: 8), child: Text(months[index], style: TextStyle(color: textSecondary, fontWeight: FontWeight.w700, fontSize: 9)));
                })),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: maxY / 5, getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: TextStyle(color: textSecondary, fontWeight: FontWeight.w700, fontSize: 10)))),
              ),
              lineBarsData: [
                _buildLineChartBar(_monthlyReviewCounts, reviewAmber),
                _buildLineChartBar(_monthlyLikeCounts, likeRose),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  LineChartBarData _buildLineChartBar(List<double> values, Color color) {
    return LineChartBarData(
      spots: List.generate(values.length, (index) => FlSpot(index.toDouble(), values[index])),
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 3, color: surfaceColor, strokeColor: color, strokeWidth: 2)),
      belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.08)),
    );
  }

  Widget _buildRatingDistribution() {
    final maxCount = _ratingDistribution.reduce((curr, next) => curr > next ? curr : next);
    final maxY = maxCount == 0 ? 5.0 : maxCount + 1;

    return Container(
      height: 280,
      padding: const EdgeInsets.fromLTRB(16, 20, 24, 16),
      decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Rating Breakdown", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A))),
        const SizedBox(height: 20),
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: maxY,
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index > 4) return const SizedBox.shrink();
                  return Padding(padding: const EdgeInsets.only(top: 8), child: Text("${index + 1} star", style: TextStyle(color: textSecondary, fontWeight: FontWeight.w700, fontSize: 9)));
                })),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: maxY / 5, getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: TextStyle(color: textSecondary, fontWeight: FontWeight.w700, fontSize: 10)))),
              ),
              gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY / 5, getDrawingHorizontalLine: (value) => FlLine(color: borderColor.withValues(alpha: 0.5), strokeWidth: 1)),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(5, (i) => BarChartGroupData(x: i, barRods: [BarChartRodData(toY: _ratingDistribution[i], color: reviewAmber, width: 18, borderRadius: BorderRadius.circular(4), backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxY, color: bgColor))])),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildSpotStatusCard() {
    return Container(
      height: 230,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Spot Status", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A))),
        const SizedBox(height: 16),
        Expanded(
          child: _totalSpots == 0
              ? Center(child: Text("No Data Available", style: TextStyle(fontSize: 12, color: textSecondary)))
              : PieChart(PieChartData(sectionsSpace: 4, centerSpaceRadius: 34, sections: [
            PieChartSectionData(value: _openedSpots.toDouble(), color: tourismGreen, title: "Open", radius: 48, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
            PieChartSectionData(value: _closedSpots.toDouble(), color: likeRose, title: "Closed", radius: 48, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
          ])),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [_buildLegend(tourismGreen, "Open"), const SizedBox(width: 12), _buildLegend(likeRose, "Closed")]),
      ]),
    );
  }

  Widget _buildTopLikedSpotsCard() {
    final maxLikes = _topLikedSpots.isEmpty ? 1 : _topLikedSpots.first.value;
    return _buildRankingCard(
      title: "Top Liked",
      emptyText: "No likes yet",
      items: _topLikedSpots.map((entry) => _RankingItem(label: entry.key, valueText: entry.value.toString(), color: likeRose, progress: entry.value / maxLikes)).toList(),
    );
  }

  Widget _buildTopRatedSpotsCard() {
    return _buildRankingCard(
      title: "Top Rated",
      emptyText: "No ratings yet",
      items: _topRatedSpots.map((entry) => _RankingItem(label: entry.key, valueText: entry.value.toStringAsFixed(1), color: reviewAmber, progress: entry.value / 5)).toList(),
    );
  }

  Widget _buildRankingCard({required String title, required String emptyText, required List<_RankingItem> items}) {
    return Container(
      height: 230,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A))),
        const SizedBox(height: 16),
        if (items.isEmpty) Expanded(child: Center(child: Text(emptyText, style: TextStyle(fontSize: 12, color: textSecondary)))) else Expanded(child: ListView.separated(physics: const NeverScrollableScrollPhysics(), itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(height: 12), itemBuilder: (context, index) {
          final item = items[index];
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(item.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)), const SizedBox(width: 8), Text(item.valueText, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900))]),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: item.progress.clamp(0.0, 1.0).toDouble(), backgroundColor: bgColor, color: item.color, minHeight: 4, borderRadius: BorderRadius.circular(2)),
          ]);
        })),
      ]),
    );
  }

  Widget _buildLatestReviewsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: borderColor)),
      child: _latestReviews.isEmpty
          ? Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text("No reviews available yet.", style: TextStyle(color: textSecondary, fontWeight: FontWeight.w600))))
          : Column(
        children: _latestReviews.map((review) {
          final rating = ((review['review_rate'] as num?)?.toDouble() ?? 0).clamp(0.0, 5.0).toDouble();
          final message = (review['review_message'] ?? '').toString().trim();
          final date = _epochToDate(review['review_date']);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: reviewAmber.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.star_rounded, color: reviewAmber, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Text(rating.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.w900, color: textPrimary)), const SizedBox(width: 8), Expanded(child: Text(date == null ? "Recent review" : _formatCompactDate(date), style: TextStyle(fontSize: 12, color: textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                const SizedBox(height: 4),
                Text(message.isEmpty ? "No written comment." : message, style: TextStyle(fontSize: 13, color: textPrimary, height: 1.35), maxLines: 2, overflow: TextOverflow.ellipsis),
              ])),
            ]),
          );
        }).toList(),
      ),
    );
  }

  String _formatCompactDate(DateTime date) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return "${months[date.month - 1]} ${date.day}, ${date.year}";
  }

  Widget _buildLegend(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: textSecondary))]);
  }

  Widget _buildSectionTitle(IconData icon, String title, Color color) {
    return Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 8), Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: textSecondary, letterSpacing: 1.0))]);
  }

  Widget _buildGridCard({required String title, required String subtitle, required IconData icon, required Color iconColor, required bool isActive, required VoidCallback? onTap, bool comingSoon = false}) {
    return Container(
      decoration: BoxDecoration(color: isActive ? surfaceColor : lockedBgColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: isActive ? borderColor : borderColor.withValues(alpha: 0.5)), boxShadow: isActive ? [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))] : []),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isActive ? iconColor.withValues(alpha: 0.1) : Colors.white, shape: BoxShape.circle, border: Border.all(color: isActive ? Colors.transparent : borderColor)), child: Icon(icon, color: isActive ? iconColor : textSecondary.withValues(alpha: 0.5), size: 28)),
                if (comingSoon) _comingSoonBadge() else if (!isActive) Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: borderColor)), child: Icon(Icons.lock_outline_rounded, size: 14, color: textSecondary.withValues(alpha: 0.4))),
              ]),
              const Spacer(),
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isActive ? textPrimary : textSecondary, height: 1.2, letterSpacing: -0.3)),
              const SizedBox(height: 6),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textSecondary.withValues(alpha: isActive ? 1.0 : 0.7), height: 1.3)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RankingItem {
  final String label;
  final String valueText;
  final Color color;
  final double progress;

  const _RankingItem({
    required this.label,
    required this.valueText,
    required this.color,
    required this.progress,
  });
}


