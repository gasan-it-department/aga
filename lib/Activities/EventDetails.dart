import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Utility/SupabaseExternalAuthBridge.dart';

class EventDetails extends StatefulWidget {
  const EventDetails({super.key, required this.eventId, this.initialEvent});

  final String eventId;
  final Map<String, dynamic>? initialEvent;

  @override
  State<EventDetails> createState() => _EventDetailsState();
}

class _EventDetailsState extends State<EventDetails> {
  final Color _primary = const Color(0xFF0F2042);
  final Color _muted = const Color(0xFF64748B);
  final Color _border = const Color(0xFFE2E8F0);

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _event;

  @override
  void initState() {
    super.initState();
    _event = widget.initialEvent;
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await SupabaseExternalAuthBridge().getEventDetails(
        widget.eventId,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(response.body);
      }
      final decoded = jsonDecode(response.body);
      final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
      final event = data is Map<String, dynamic>
          ? data
          : decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      if (!mounted) return;
      setState(() => _event = event);
    } catch (error) {
      if (mounted) setState(() => _error = 'Unable to load event.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _value(List<String> keys) {
    final source = _event ?? widget.initialEvent ?? {};
    for (final key in keys) {
      final value = source[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return '';
  }

  String _typeLabel() {
    final source = _event ?? widget.initialEvent ?? {};
    final type = source['type'];
    if (type is Map && type['label'] != null) return type['label'].toString();
    return 'Event';
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
    final title = _value(['title']);
    final bannerUrl = _value(['banner_url']);
    final body = _cleanBody(
      _value(['body', 'content', 'description', 'excerpt']),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        elevation: 0,
        title: const Text(
          'Event Details',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDetails,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            if (_loading && _event == null)
              const Padding(
                padding: EdgeInsets.only(top: 160),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && _event == null)
              _errorCard()
            else ...[
              if (bannerUrl.isNotEmpty) _banner(bannerUrl),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _chip(),
                    const SizedBox(height: 12),
                    Text(
                      title.isEmpty ? 'Event' : title,
                      style: TextStyle(
                        color: _primary,
                        fontSize: 22,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _info(Icons.schedule_rounded, _dateRange()),
                    _info(Icons.place_rounded, _value(['location_name'])),
                    const SizedBox(height: 16),
                    Text(
                      body.isEmpty ? 'No event details provided.' : body,
                      style: TextStyle(
                        color: _muted,
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _dateRange() {
    final start = _value(['start_datetime']);
    final end = _value(['end_datetime']);
    if (start.isEmpty) return end;
    if (end.isEmpty) return start;
    return '$start - $end';
  }

  Widget _banner(String url) {
    return Container(
      height: 200,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Center(
          child: Icon(Icons.event_available_rounded, color: Color(0xFF7C3AED)),
        ),
      ),
    );
  }

  Widget _chip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _typeLabel(),
        style: const TextStyle(
          color: Color(0xFF7C3AED),
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _info(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF94A3B8), size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
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
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
          const SizedBox(height: 10),
          Text(
            _error ?? 'Unable to load event.',
            style: TextStyle(color: _primary, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _loadDetails, child: const Text('Retry')),
        ],
      ),
    );
  }
}
