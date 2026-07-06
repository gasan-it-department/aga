import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Activities/AnnouncementDetails.dart';
import 'package:gasan_port_tracker/Utility/SupabaseExternalAuthBridge.dart';

class AnnouncementsList extends StatefulWidget {
  const AnnouncementsList({super.key});

  @override
  State<AnnouncementsList> createState() => _AnnouncementsListState();
}

class _AnnouncementsListState extends State<AnnouncementsList> {
  final Color _primary = const Color(0xFF0F2042);
  final Color _muted = const Color(0xFF64748B);
  final Color _border = const Color(0xFFE2E8F0);

  final ScrollController _scrollController = ScrollController();
  
  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _perPage = 10;
  
  List<Map<String, dynamic>> _announcements = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitialAnnouncements();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_loadingMore && _hasMore && _error == null) {
        _loadMoreAnnouncements();
      }
    }
  }

  Future<void> _loadInitialAnnouncements() async {
    if (!mounted) return;
    setState(() {
      _loadingInitial = true;
      _error = null;
      _currentPage = 1;
      _hasMore = true;
    });

    try {
      final response = await SupabaseExternalAuthBridge().getAnnouncements(
        page: _currentPage,
        perPage: _perPage,
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(response.body);
      }

      final decoded = jsonDecode(response.body);
      final rows = decoded is Map<String, dynamic> ? decoded['data'] : null;
      
      final List<Map<String, dynamic>> loaded = rows is List
          ? rows
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _announcements = loaded;
        _hasMore = loaded.length >= _perPage;
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Unable to load announcements.');
    } finally {
      if (mounted) setState(() => _loadingInitial = false);
    }
  }

  Future<void> _loadMoreAnnouncements() async {
    if (!mounted) return;
    setState(() {
      _loadingMore = true;
    });

    final nextPage = _currentPage + 1;

    try {
      final response = await SupabaseExternalAuthBridge().getAnnouncements(
        page: nextPage,
        perPage: _perPage,
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(response.body);
      }

      final decoded = jsonDecode(response.body);
      final rows = decoded is Map<String, dynamic> ? decoded['data'] : null;
      
      final List<Map<String, dynamic>> loaded = rows is List
          ? rows
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _currentPage = nextPage;
        _announcements.addAll(loaded);
        _hasMore = loaded.length >= _perPage;
      });
    } catch (error) {
      // Fail silently for page scrolling loading
      debugPrint('Load more announcements error: $error');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        elevation: 0,
        title: const Text(
          'Announcements',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitialAnnouncements,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: _header()),
            if (_loadingInitial)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
              )
            else if (_error != null && _announcements.isEmpty)
              SliverFillRemaining(child: _messageState(_error!))
            else if (_announcements.isEmpty)
              SliverFillRemaining(child: _messageState('No announcements yet.'))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                sliver: SliverList.separated(
                  itemCount: _announcements.length + (_hasMore ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    if (index == _announcements.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2.0),
                        ),
                      );
                    }
                    return _announcementCard(_announcements[index]);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        children: [
          Icon(Icons.campaign_rounded, color: Colors.white, size: 34),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Latest Announcements',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Important news, notices, and advisories from Gasan.',
                  style: TextStyle(
                    color: Color(0xFFEFF6FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _announcementCard(Map<String, dynamic> announcement) {
    final announcementId = announcement['id']?.toString() ?? '';
    final type = announcement['type'];
    final typeLabel = type is Map
        ? type['label']?.toString() ?? 'Announcement'
        : 'Announcement';
    final coverImageUrl = announcement['cover_image_url']?.toString();

    return InkWell(
      onTap: announcementId.isEmpty
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AnnouncementDetails(
                    announcementId: announcementId,
                    initialAnnouncement: announcement,
                  ),
                ),
              ),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 135,
              width: double.infinity,
              child: coverImageUrl != null && coverImageUrl.trim().isNotEmpty
                  ? Image.network(
                      coverImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _announcementIcon(),
                    )
                  : _announcementIcon(),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      typeLabel,
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    announcement['title']?.toString() ?? 'Announcement',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    announcement['excerpt']?.toString() ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _muted,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, color: _muted, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        announcement['created_at']?.toString() ?? '',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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

  Widget _announcementIcon() {
    return Container(
      color: const Color(0xFFEFF6FF),
      child: const Center(
        child: Icon(
          Icons.campaign_rounded,
          color: Color(0xFF2563EB),
          size: 42,
        ),
      ),
    );
  }

  Widget _messageState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_rounded, color: _muted, size: 42),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _primary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
