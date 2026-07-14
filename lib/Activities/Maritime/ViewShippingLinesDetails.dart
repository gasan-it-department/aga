import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';

import 'ViewVesselsDetails.dart';
import '../../Maritime/MaritimeDataMapper.dart';

class ViewShippingLinesDetails extends StatefulWidget {
  const ViewShippingLinesDetails({super.key});

  @override
  State<ViewShippingLinesDetails> createState() =>
      _ViewShippingLinesDetailsState();
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
  List<Map<String, dynamic>> _ports = [];
  Map<String, String> _passengerLevelsByPort = {};

  @override
  void initState() {
    super.initState();
    _fetchShippingLines();
  }

  Future<void> _fetchShippingLines() async {
    setState(() => _isLoading = true);
    try {
      final responses = await Future.wait([
        supabase.from('ports').select('port_id, port_name'),
        supabase
            .from('shipping_lines')
            .select(
              '*, vessels(vessel_id), shipping_line_route_profiles(*, shipping_line_fares(*))',
            )
            .order('shipping_line_name'),
      ]);
      final ports = List<Map<String, dynamic>>.from(responses[0] as List);
      final portNames = {
        for (final port in ports)
          port['port_id'].toString(): port['port_name'].toString(),
      };
      final passengerRows = await supabase
          .from('maritime_dashboard_status')
          .select('dashboard_status_scope, passenger_level')
          .like('dashboard_status_scope', 'port:%');
      final passengerLevels = <String, String>{};
      for (final row in List<Map<String, dynamic>>.from(passengerRows)) {
        final scope = row['dashboard_status_scope']?.toString() ?? '';
        if (!scope.startsWith('port:')) continue;
        passengerLevels[scope.substring(5)] =
            row['passenger_level']?.toString() ?? 'not_available';
      }

      if (mounted) {
        setState(() {
          _ports = ports;
          _passengerLevelsByPort = passengerLevels;
          _shippingLines = List<Map<String, dynamic>>.from(responses[1] as List)
              .map(
                (line) =>
                    MaritimeDataMapper.normalizeShippingLine(line, portNames),
              )
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching shipping lines: $e");
      if (mounted) setState(() => _isLoading = false);
    }
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
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 18,
          color: primaryDark,
          letterSpacing: -0.5,
        ),
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
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    itemCount: _shippingLines.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) return _buildPassengerLevelCard();
                      final line = _shippingLines[index - 1];
                      return _buildShippingLineCard(line);
                    },
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildPassengerLevelCard() {
    final visiblePorts = _ports.where((port) {
      final id = port['port_id']?.toString() ?? '';
      return id.isNotEmpty && _passengerLevelsByPort.containsKey(id);
    }).toList();

    if (visiblePorts.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: outlineColor.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: primaryDark.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.groups_2_rounded,
                  color: accentBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Passenger Level",
                      style: TextStyle(
                        color: primaryDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Current port passenger condition",
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Passenger level info',
                onPressed: _showPassengerLevelInfoDialog,
                icon: Icon(
                  Icons.info_outline_rounded,
                  color: textSecondary,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: visiblePorts.map((port) {
              final portId = port['port_id']?.toString() ?? '';
              final level = _passengerLevelsByPort[portId] ?? 'not_available';
              final color = _passengerLevelColor(level);
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: color.withValues(alpha: 0.22)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      port['port_name']?.toString() ?? 'Port',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _passengerLevelText(level).toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showPassengerLevelInfoDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: primaryDark.withValues(alpha: 0.18),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 20, 16, 18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primaryDark,
                            const Color(0xFF155EAC),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: const Icon(
                              Icons.groups_2_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Passenger Level Guide',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Use these indicators to estimate how busy each port is.',
                                  style: TextStyle(
                                    color: Color(0xFFDCEBFF),
                                    fontSize: 12,
                                    height: 1.3,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                            color: Colors.white,
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildPassengerLevelInfoRow(
                            'light',
                            'Light',
                            'Few passengers at the port.',
                          ),
                          _buildPassengerLevelInfoRow(
                            'medium',
                            'Medium',
                            'Normal passenger volume.',
                          ),
                          _buildPassengerLevelInfoRow(
                            'heavy',
                            'Heavy',
                            'Many passengers are waiting.',
                          ),
                          _buildPassengerLevelInfoRow(
                            'very_heavy',
                            'Very Heavy',
                            'Expect crowding and possible longer waiting time.',
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryDark,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Got it',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPassengerLevelInfoRow(
    String value,
    String title,
    String description,
  ) {
    final color = _passengerLevelColor(value);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.circle_rounded, color: color, size: 13),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                    height: 1.35,
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

  String _passengerLevelText(String value) {
    switch (value) {
      case 'light':
        return 'Light';
      case 'medium':
        return 'Medium';
      case 'heavy':
        return 'Heavy';
      case 'very_heavy':
        return 'Very Heavy';
      default:
        return 'Not Available';
    }
  }

  Color _passengerLevelColor(String value) {
    return switch (value) {
      'light' => const Color(0xFF16A34A),
      'medium' => const Color(0xFF2563EB),
      'heavy' => const Color(0xFFD97706),
      'very_heavy' => const Color(0xFFDC2626),
      _ => textSecondary,
    };
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
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ViewVesselsDetails(shippingLine: line),
              ),
            );
          },
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
                  child: Icon(
                    Icons.business_rounded,
                    color: primaryDark,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line['shipping_line_name'] ?? 'Unknown Line',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: primaryDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.directions_boat_rounded,
                            size: 14,
                            color: textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "$fleetSize Vessel${fleetSize <= 1 ? '' : 's'}",
                            style: TextStyle(
                              fontSize: 13,
                              color: textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
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
            decoration: BoxDecoration(
              color: primaryDark.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.business_rounded,
              size: 48,
              color: textSecondary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "No shipping lines found",
            style: TextStyle(
              color: primaryDark,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Directory is currently empty.",
            style: TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
