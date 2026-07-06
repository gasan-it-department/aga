import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';

import '../../Dialogs/Bottomsheets/ViewFares.dart';
import '../../Dialogs/Bottomsheets/ViewSchedules.dart';
import 'ViewVesselsDetails.dart';

class ViewShippingLinesDetails extends StatefulWidget {
  const ViewShippingLinesDetails({super.key});

  @override
  State<ViewShippingLinesDetails> createState() => _ViewShippingLinesDetailsState();
}

class _ViewShippingLinesDetailsState extends State<ViewShippingLinesDetails> {
  final supabase = Supabase.instance.client;

  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryDark = const Color(0xFF0A2E5C);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);
  final Color outlineColor = const Color(0xFFE2E8F0);
  final Color accentBlue = const Color(0xFF3B82F6);

  bool _isLoading = true;
  List<Map<String, dynamic>> _shippingLines = [];

  @override
  void initState() {
    super.initState();
    _fetchShippingLines();
  }

  Future<void> _fetchShippingLines() async {
    setState(() => _isLoading = true);
    try {
      // Fetch shipping lines and just grab the vessel IDs to count the fleet size
      final linesResponse = await supabase
          .from('shipping_lines')
          .select('*, vessels(vessel_id)')
          .order('shipping_line_name');

      if (mounted) {
        setState(() {
          _shippingLines = List<Map<String, dynamic>>.from(linesResponse);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching shipping lines: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> _parseData(dynamic data) {
    if (data == null) return [];
    if (data is List) return data;
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        return decoded is List ? decoded : [decoded];
      } catch (_) {
        return [];
      }
    }
    return [data];
  }

  void _showShippingLineOptions(Map<String, dynamic> line) {
    final String lineName = line['shipping_line_name']?.toString() ?? 'Shipping Line';
    final int fleetSize = (line['vessels'] as List?)?.length ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: outlineColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryDark.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.directions_boat_filled_rounded, color: primaryDark, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lineName,
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: primaryDark),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "$fleetSize Vessel${fleetSize <= 1 ? '' : 's'} available",
                            style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildOptionTile(
                  icon: Icons.payments_rounded,
                  title: 'View Rates',
                  subtitle: 'Passenger and cargo fare information',
                  color: const Color(0xFF059669),
                  onTap: () {
                    Navigator.pop(context);
                    ViewFares.showBottomSheet(
                      context: context,
                      shippingLineName: lineName,
                      fares: _parseData(line['shipping_line_fares']),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _buildOptionTile(
                  icon: Icons.event_available_rounded,
                  title: 'View Schedules',
                  subtitle: 'Routes, departure times and trip status',
                  color: const Color(0xFF2563EB),
                  onTap: () {
                    Navigator.pop(context);
                    ViewSchedules.showBottomSheet(
                      context: context,
                      shippingLineName: lineName,
                      schedules: _parseData(line['shipping_line_schedules']),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _buildOptionTile(
                  icon: Icons.directions_boat_rounded,
                  title: 'View Vessels',
                  subtitle: 'Open vessel list and live vessel details',
                  color: const Color(0xFF7C3AED),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ViewVesselsDetails(shippingLine: line),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Shipping Lines"),
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: primaryDark, letterSpacing: -0.5),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Utility().getMaxScreenSize()),
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: accentBlue))
              : _shippingLines.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
            onRefresh: _fetchShippingLines,
            color: accentBlue,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              itemCount: _shippingLines.length,
              itemBuilder: (context, index) {
                return _buildShippingLineCard(_shippingLines[index]);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShippingLineCard(Map<String, dynamic> line) {
    final int fleetSize = (line['vessels'] as List?)?.length ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: outlineColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: primaryDark.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showShippingLineOptions(line),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: primaryDark.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.business_rounded, color: primaryDark, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line['shipping_line_name'] ?? 'Unknown Line',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: primaryDark),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.directions_boat_rounded, size: 14, color: textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            "$fleetSize Vessel${fleetSize <= 1 ? '' : 's'}",
                            style: TextStyle(fontSize: 13, color: textSecondary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.more_horiz_rounded, size: 22, color: textSecondary),
              ],
            ),
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: primaryDark.withValues(alpha: 0.05), shape: BoxShape.circle),
            child: Icon(Icons.business_rounded, size: 48, color: textSecondary.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          Text("No shipping lines found", style: TextStyle(color: primaryDark, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 8),
          Text("Directory is currently empty.", style: TextStyle(color: textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
