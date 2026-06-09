import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gasan_port_tracker/Activities/Tourism/SubActivities/AddEditTourismEventBanner.dart';
import 'package:gasan_port_tracker/Dialogs/ClassicDialog.dart';
import 'package:gasan_port_tracker/Dialogs/LoadingDialog.dart';
import 'package:gasan_port_tracker/FloatingMessages/SnackbarMessenger.dart';
import 'package:gasan_port_tracker/Utility/Responsive.dart';

class TourismEventsBanner extends StatefulWidget {
  final int municipalZipCode;

  const TourismEventsBanner({super.key, required this.municipalZipCode});

  @override
  State<TourismEventsBanner> createState() => _TourismEventsBannerState();
}

class _TourismEventsBannerState extends State<TourismEventsBanner> {
  final _supabase = Supabase.instance.client;
  final _classicDialog = ClassicDialog();
  final _loadingDialog = LoadingDialog();
  final String _bucket = 'tourism_event_banner_images';

  final Color bgColor = const Color(0xFFF8FAFC);
  final Color surfaceColor = const Color(0xFFFFFFFF);
  final Color primaryDark = const Color(0xFF0F172A);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);
  final Color borderColor = const Color(0xFFE2E8F0);
  final Color eventViolet = const Color(0xFF8B5CF6);
  final Color rose = const Color(0xFFEF4444);

  bool _isLoading = true;
  List<Map<String, dynamic>> _events = [];

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchEvents() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      var builder = _supabase
          .from('tourism_event_banners')
          .select()
          .eq('banner_municipal_zipcode', widget.municipalZipCode);

      if (_query.isNotEmpty) {
        final escaped = _query.replaceAll('%', r'\%').replaceAll(',', ' ');
        builder = builder.or('banner_name.ilike.%$escaped%,banner_description.ilike.%$escaped%');
      }

      final response = await builder.order('banner_date_added', ascending: false);

      if (mounted) {
        setState(() {
          _events = List<Map<String, dynamic>>.from(response as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching tourism events: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Failed to load events.");
      }
    }
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _query = v.trim();
      _fetchEvents();
    });
  }

  String _formatDate(dynamic epochValue) {
    if (epochValue == null) return "Unknown";
    int ms = epochValue is num ? epochValue.toInt() : int.tryParse(epochValue.toString()) ?? 0;
    if (ms == 0) return "Unknown";
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return "${months[d.month - 1]} ${d.day}, ${d.year}";
  }

  String? _pathFromUrl(String url) {
    try {
      final segs = Uri.parse(url).pathSegments;
      final idx = segs.indexOf(_bucket);
      if (idx != -1 && idx < segs.length - 1) return segs.sublist(idx + 1).join('/');
    } catch (_) {}
    return null;
  }

  Future<void> _deleteEvent(Map<String, dynamic> event) async {
    _classicDialog.setTitle("Delete Event");
    _classicDialog.setMessage("Are you sure you want to permanently remove this event banner?");
    _classicDialog.setPositiveMessage("Delete");
    _classicDialog.setNegativeMessage("Cancel");

    _classicDialog.showTwoButtonDialog(context, (neg) => _classicDialog.dismissDialog(), (pos) async {
      _classicDialog.dismissDialog();
      _loadingDialog.showLoadingDialog(context);

      try {
        final String? cover = event['banner_cover_image']?.toString();
        if (cover != null && cover.isNotEmpty) {
          final path = _pathFromUrl(cover);
          if (path != null) {
            try { await _supabase.storage.from(_bucket).remove([path]); } catch (_) {}
          }
        }
        await _supabase.from('tourism_event_banners').delete().eq('banner_id', event['banner_id']);

        if (mounted) {
          _loadingDialog.dismiss();
          SnackbarMessenger().showSnackbar(context, SnackbarMessenger.success, "Event removed.");
          _fetchEvents();
        }
      } catch (e) {
        if (mounted) {
          _loadingDialog.dismiss();
          SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Failed to delete event.");
        }
      }
    });
  }

  Future<void> _navigateToAddOrUpdate([Map<String, dynamic>? existingEvent]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditTourismEventBanner(
          municipalZipCode: widget.municipalZipCode,
          existingEvent: existingEvent,
        ),
      ),
    );
    _fetchEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surfaceColor,
        foregroundColor: primaryDark,
        centerTitle: false,
        title: const Text(
          "Tourism Events",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5, fontSize: 19),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderColor, height: 1),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: Icon(Icons.add_circle_rounded, color: eventViolet, size: 30),
              onPressed: () => _navigateToAddOrUpdate(),
              tooltip: "Create new event",
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: eventViolet, strokeWidth: 3))
                : RefreshIndicator(
                    onRefresh: _fetchEvents,
                    color: eventViolet,
                    backgroundColor: Colors.white,
                    child: _events.isEmpty
                        ? _buildEmptyState()
                        : Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: Responsive.isDesktop(context) ? 1280 : 920),
                              child: _buildGrid(),
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: surfaceColor,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: "Search events...",
              hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.7), fontWeight: FontWeight.w600),
              prefixIcon: Icon(Icons.search_rounded, color: textSecondary, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, color: textSecondary, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _query = '';
                        _fetchEvents();
                      },
                    )
                  : null,
              filled: true,
              fillColor: bgColor,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: eventViolet, width: 1.5)),
            ),
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
      crossAxis = 3;
      extent = 340;
      pad = const EdgeInsets.fromLTRB(24, 20, 24, 28);
    } else if (Responsive.isTablet(context)) {
      crossAxis = 2;
      extent = 340;
      pad = const EdgeInsets.fromLTRB(18, 18, 18, 24);
    } else {
      crossAxis = 1;
      extent = 320;
      pad = const EdgeInsets.fromLTRB(14, 14, 14, 24);
    }

    return GridView.builder(
      padding: pad,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxis,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: extent,
      ),
      itemCount: _events.length,
      itemBuilder: (context, index) => _buildEventCard(_events[index]),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final String name = event['banner_name']?.toString() ?? 'Unnamed Event';
    final String description = event['banner_description']?.toString() ?? 'No description available.';
    final String? imageUrl = event['banner_cover_image']?.toString();
    final String formattedDate = _formatDate(event['banner_date_added']);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _navigateToAddOrUpdate(event),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 170,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageUrl != null && imageUrl.isNotEmpty)
                        Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _fallbackHero(),
                          loadingBuilder: (_, child, p) => p == null
                              ? child
                              : Container(color: bgColor, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: eventViolet))),
                        )
                      else
                        _fallbackHero(),
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
                          decoration: BoxDecoration(color: eventViolet, borderRadius: BorderRadius.circular(8)),
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
                        bottom: 10,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 11),
                              const SizedBox(width: 5),
                              Text(formattedDate, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textPrimary, letterSpacing: -0.3),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Text(
                            description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, color: textSecondary, height: 1.45, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            InkWell(
                              onTap: () => _deleteEvent(event),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: rose.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.delete_outline_rounded, size: 12, color: rose),
                                    const SizedBox(width: 5),
                                    Text("Delete", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: rose)),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            Icon(Icons.arrow_forward_rounded, size: 16, color: textSecondary),
                          ],
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

  Widget _fallbackHero() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [eventViolet, const Color(0xFFF59E0B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(child: Icon(Icons.celebration_rounded, color: Colors.white, size: 44)),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: eventViolet.withValues(alpha: 0.1), blurRadius: 30, spreadRadius: 5)],
                  ),
                  child: Icon(Icons.event_busy_rounded, size: 56, color: eventViolet.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: 24),
                Text(
                  _query.isEmpty ? "No Events Yet" : "No Matching Events",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: primaryDark, letterSpacing: -0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  _query.isEmpty
                      ? "Create your first tourism event\nto promote local festivities."
                      : "Try a different keyword.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textSecondary, fontSize: 14, height: 1.4, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 24),
                if (_query.isEmpty)
                  ElevatedButton.icon(
                    onPressed: () => _navigateToAddOrUpdate(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text("Create Event"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: eventViolet,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

