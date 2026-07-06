import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Utility/SupabaseExternalAuthBridge.dart';

class AnnouncementDetails extends StatefulWidget {
  const AnnouncementDetails({
    super.key,
    required this.announcementId,
    this.initialAnnouncement,
  });

  final String announcementId;
  final Map<String, dynamic>? initialAnnouncement;

  @override
  State<AnnouncementDetails> createState() => _AnnouncementDetailsState();
}

class _AnnouncementDetailsState extends State<AnnouncementDetails> {
  final Color _primary = const Color(0xFF0F2042);
  final Color _muted = const Color(0xFF64748B);
  final Color _border = const Color(0xFFE2E8F0);
  final Color _accent = const Color(0xFF2563EB);

  bool _loading = true;
  Map<String, dynamic>? _announcement;
  String? _error;

  @override
  void initState() {
    super.initState();
    _announcement = widget.initialAnnouncement;
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await SupabaseExternalAuthBridge()
          .getAnnouncementDetails(widget.announcementId);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(response.body);
      }

      final decoded = jsonDecode(response.body);
      final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
      final announcement = data is Map<String, dynamic>
          ? data
          : decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        _announcement = {
          ...?widget.initialAnnouncement,
          ...?_announcement,
          ...announcement,
        };
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Unable to load announcement.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _stringValue(List<String> keys) {
    final source = _announcement ?? widget.initialAnnouncement ?? {};
    for (final key in keys) {
      final value = source[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return '';
  }

  String _typeLabel() {
    final source = _announcement ?? widget.initialAnnouncement ?? {};
    final type = source['type'];
    if (type is Map && type['label'] != null) return type['label'].toString();
    return 'Announcement';
  }

  String _cleanBody(String value) {
    return value
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final title = _stringValue(['title']);
    final createdAt = _stringValue(['created_at']);
    final coverImageUrl = _stringValue(['cover_image_url']);
    final body = _cleanBody(
      _stringValue(['body', 'content', 'description', 'excerpt']),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        foregroundColor: _primary,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Announcement',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDetails,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            if (_loading && _announcement == null)
              const Padding(
                padding: EdgeInsets.only(top: 160),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && _announcement == null)
              _errorCard()
            else ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (coverImageUrl.isNotEmpty) _coverImage(coverImageUrl),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _typeChip(),
                              if (createdAt.isNotEmpty) _dateChip(createdAt),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            title.isEmpty ? 'Announcement' : title,
                            style: TextStyle(
                              color: _primary,
                              fontSize: 23,
                              height: 1.13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            height: 1,
                            color: _border.withValues(alpha: 0.75),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            body.isEmpty
                                ? 'No announcement details provided.'
                                : body,
                            style: TextStyle(
                              color: _muted,
                              fontSize: 14.5,
                              height: 1.62,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _coverImage(String url) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            url,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: const Color(0xFFEFF6FF),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _accent,
                  ),
                ),
              );
            },
            errorBuilder: (_, _, _) => Container(
              color: const Color(0xFFEFF6FF),
              child: Icon(Icons.campaign_rounded, color: _accent, size: 42),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateChip(String createdAt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.schedule_rounded,
            color: Color(0xFF94A3B8),
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            createdAt,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.campaign_rounded, size: 13, color: _accent),
          const SizedBox(width: 5),
          Text(
            _typeLabel(),
            style: TextStyle(
              color: _accent,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard() {
    return Container(
      margin: const EdgeInsets.only(top: 120),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
          const SizedBox(height: 10),
          Text(
            _error ?? 'Unable to load announcement.',
            style: TextStyle(color: _primary, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _loadDetails, child: const Text('Retry')),
        ],
      ),
    );
  }
}
