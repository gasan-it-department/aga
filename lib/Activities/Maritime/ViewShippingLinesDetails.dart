import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';

// IMPORTANT: Adjust this path to wherever you saved ViewVesselsDetails.dart
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
          onTap: () {
            // --- NEW: Navigate to the Vessels Details Screen ---
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
                // --- NEW: Added a forward arrow to show it's clickable ---
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: outlineColor),
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
