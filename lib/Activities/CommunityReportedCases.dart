import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Activities/CommunityReportDetails.dart';
import 'package:gasan_port_tracker/Utility/CommunityReportStatusStyle.dart';
import 'package:gasan_port_tracker/Utility/SupabaseExternalAuthBridge.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';

class CommunityReportedCases extends StatefulWidget {
  const CommunityReportedCases({super.key});

  @override
  State<CommunityReportedCases> createState() => _CommunityReportedCasesState();
}

class _CommunityReportedCasesState extends State<CommunityReportedCases> {
  final _primary = const Color(0xFF0F766E);
  final _dark = const Color(0xFF0F172A);
  final _muted = const Color(0xFF64748B);
  final _border = const Color(0xFFE2E8F0);

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await SupabaseExternalAuthBridge().getCommunityReports();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(response.body);
      }

      final decoded = jsonDecode(response.body);
      final reports = _extractReports(decoded);
      if (!mounted) return;
      setState(() => _reports = reports);
    } catch (error) {
      Utility().printLog('Community reports load failed: $error');
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _extractReports(dynamic source) {
    if (source is List) {
      return source.whereType<Map>().map(_asStringMap).toList();
    }

    if (source is Map) {
      for (final key in ['data', 'reports', 'items', 'cases', 'results']) {
        final value = source[key];
        if (value is List) {
          return value.whereType<Map>().map(_asStringMap).toList();
        }
        if (value is Map) {
          final nested = _extractReports(value);
          if (nested.isNotEmpty) return nested;
        }
      }
    }

    return const [];
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
          'Reported Cases',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
      ),
      body: RefreshIndicator(onRefresh: _loadReports, child: _body()),
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
        children: [
          _emptyState(
            Icons.error_outline_rounded,
            'Unable to load reports',
            _error!,
          ),
        ],
      );
    }

    if (_reports.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        children: [
          _emptyState(
            Icons.assignment_outlined,
            'No reported cases yet',
            'Submitted community reports will appear here.',
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _reports.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (_, index) => _reportCard(_reports[index]),
    );
  }

  Widget _reportCard(Map<String, dynamic> report) {
    final category = _readLabel(report, [
      'category',
      'type',
      'ticket_incidents_type',
    ]);
    final statusValue = _readValue(report, ['status', 'ticket_status']);
    final statusLabel =
        _readLabel(report, ['status', 'ticket_status']) ?? 'Submitted';
    final location = _read(report, [
      'location_text',
      'location',
      'ticket_incidents_location',
    ]);
    final description = _read(report, [
      'description',
      'ticket_incidents_description',
    ]);
    final date = _read(report, [
      'created_at',
      'date_created',
      'ticket_date_created',
    ]);
    final reportId = _read(report, ['id', 'report_id', 'ticket_id']);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: reportId == null
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CommunityReportDetails(reportId: reportId),
                ),
              );
            },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.report_rounded, color: _primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    category ?? 'Community Report',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _dark,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
                _statusBadge(statusLabel, statusValue),
              ],
            ),
            if (location != null) ...[
              const SizedBox(height: 12),
              _meta(Icons.place_rounded, location),
            ],
            if (description != null) ...[
              const SizedBox(height: 10),
              Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _muted,
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (date != null) ...[
              const SizedBox(height: 10),
              _meta(Icons.schedule_rounded, date),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status, String? statusValue) {
    final color = CommunityReportStatusStyle.color(statusValue ?? status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _muted, size: 16),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState(IconData icon, String title, String message) {
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
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _dark,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
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
