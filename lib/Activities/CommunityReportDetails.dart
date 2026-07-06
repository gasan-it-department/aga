import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Utility/CommunityReportStatusStyle.dart';
import 'package:gasan_port_tracker/Utility/SupabaseExternalAuthBridge.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';

class CommunityReportDetails extends StatefulWidget {
  const CommunityReportDetails({super.key, required this.reportId});

  final String reportId;

  @override
  State<CommunityReportDetails> createState() => _CommunityReportDetailsState();
}

class _CommunityReportDetailsState extends State<CommunityReportDetails> {
  final _primary = const Color(0xFF0F766E);
  final _dark = const Color(0xFF0F172A);
  final _muted = const Color(0xFF64748B);
  final _border = const Color(0xFFE2E8F0);

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _details;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await SupabaseExternalAuthBridge()
          .getCommunityReportDetails(widget.reportId);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(response.body);
      }

      final decoded = jsonDecode(response.body);
      final details = _extractDetails(decoded);
      if (!mounted) return;
      setState(() => _details = details);
    } catch (error) {
      Utility().printLog('Community report details load failed: $error');
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _extractDetails(dynamic source) {
    if (source is Map) {
      final data = source['data'];
      if (data is Map) return _asStringMap(data);
      return _asStringMap(source);
    }
    return {};
  }

  Map<String, dynamic> _asStringMap(Map source) {
    return source.map((key, value) => MapEntry(key.toString(), value));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _dark,
        elevation: 0,
        title: const Text(
          'Report Details',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
      ),
      body: RefreshIndicator(onRefresh: _loadReport, child: _body()),
    );
  }

  Widget _body() {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.32),
          Center(child: CircularProgressIndicator(color: _primary)),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        children: [_emptyState(Icons.error_outline_rounded, _error!)],
      );
    }

    final details = _details;
    if (details == null || details.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        children: [
          _emptyState(Icons.assignment_outlined, 'Report details not found.'),
        ],
      );
    }

    final report = _extractReport(details);
    final category = _readLabel(report, ['category', 'type']);
    final statusValue = _readValue(report, ['status']);
    final statusLabel = _readLabel(report, ['status']) ?? 'Submitted';
    final location = _read(report, ['location_text', 'location']);
    final description = _read(report, ['description']);
    final createdAt = _read(report, ['created_at']);
    final latitude = _read(report, ['latitude']);
    final longitude = _read(report, ['longitude']);
    final photos = _readPhotos(details, report);
    final timeline = _readTimeline(details);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _header(category ?? 'Community Report', statusLabel, statusValue),
        const SizedBox(height: 12),
        _section('Location', [
          if (location != null) _detail(Icons.place_rounded, 'Area', location),
          if (latitude != null || longitude != null)
            _detail(
              Icons.pin_drop_rounded,
              'Coordinates',
              '${latitude ?? '--'}, ${longitude ?? '--'}',
            ),
        ]),
        const SizedBox(height: 12),
        _section('Report', [
          if (description != null)
            _paragraph(description)
          else
            _paragraph('No description provided.'),
          if (createdAt != null)
            _detail(Icons.schedule_rounded, 'Submitted', createdAt),
        ]),
        const SizedBox(height: 12),
        _section('Evidence Photos', [_photos(photos)]),
        const SizedBox(height: 12),
        _section('Timeline', [_timeline(timeline)]),
      ],
    );
  }

  Map<String, dynamic> _extractReport(Map<String, dynamic> details) {
    final report = details['report'];
    if (report is Map) return _asStringMap(report);
    return details;
  }

  Widget _header(String category, String status, String? statusValue) {
    final color = CommunityReportStatusStyle.color(statusValue ?? status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.report_rounded, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: TextStyle(
                    color: _dark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: _dark,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _detail(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _primary, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: _dark,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _paragraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          color: _dark,
          fontSize: 13,
          height: 1.45,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _photos(List<String> photos) {
    if (photos.isEmpty) {
      return Text(
        'No evidence photos attached.',
        style: TextStyle(
          color: _muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: photos.map((url) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            url,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 96,
              height: 96,
              color: const Color(0xFFE2E8F0),
              child: Icon(Icons.broken_image_rounded, color: _muted),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _timeline(List<Map<String, dynamic>> timeline) {
    if (timeline.isEmpty) {
      return Text(
        'No timeline updates yet.',
        style: TextStyle(
          color: _muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Column(
      children: List.generate(timeline.length, (index) {
        final item = timeline[index];
        final reached = item['reached'] == true;
        final key = item['key']?.toString() ?? '';
        final color = reached
            ? CommunityReportStatusStyle.color(key)
            : const Color(0xFFCBD5E1);
        final label = item['label']?.toString() ?? 'Update';
        final description = item['description']?.toString();
        final at = item['at']?.toString();
        final isLast = index == timeline.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: reached ? color : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: reached
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : null,
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 46,
                    color: const Color(0xFFE2E8F0),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: reached ? _dark : _muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (description != null &&
                        description.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: TextStyle(
                          color: _muted,
                          fontSize: 11,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (at != null && at.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        at,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _emptyState(IconData icon, String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Icon(icon, color: _primary, size: 42),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _dark,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  List<String> _readPhotos(
    Map<String, dynamic> details,
    Map<String, dynamic> report,
  ) {
    final value =
        details['photos'] ??
        report['evidence_photos'] ??
        report['photos'] ??
        report['ticket_images'];
    if (value is List) return value.map((item) => item.toString()).toList();
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((item) => item.toString()).toList();
        }
      } catch (_) {
        return [value];
      }
    }
    return const [];
  }

  List<Map<String, dynamic>> _readTimeline(Map<String, dynamic> details) {
    final value = details['timeline'];
    if (value is List) {
      return value.whereType<Map>().map(_asStringMap).toList();
    }
    return const [];
  }

  String? _read(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  String? _readLabel(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is Map) {
        final label = value['label'] ?? value['name'] ?? value['value'];
        if (label != null && label.toString().trim().isNotEmpty) {
          return label.toString();
        }
      }
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  String? _readValue(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is Map) {
        final raw = value['value'] ?? value['label'];
        if (raw != null && raw.toString().trim().isNotEmpty) {
          return raw.toString();
        }
      }
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }
}
