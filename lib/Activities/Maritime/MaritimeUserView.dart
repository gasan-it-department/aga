import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'VesselTracking.dart';

class MaritimeUserView extends StatefulWidget {
  const MaritimeUserView({super.key});

  @override
  State<MaritimeUserView> createState() => _MaritimeUserViewState();
}

class _MaritimeUserViewState extends State<MaritimeUserView> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _vessels = [];
  List<Map<String, dynamic>> _ports = [];

  final Color primaryDark = const Color(0xFF0A2E5C);
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color outlineColor = const Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final responses = await Future.wait([
        _supabase.from('ports').select(),
        _supabase.from('vessels').select(),
      ]);

      if (mounted) {
        setState(() {
          _ports = List<Map<String, dynamic>>.from(responses[0] as List);
          _vessels = List<Map<String, dynamic>>.from(responses[1] as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching maritime data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("MARITIME TRACKER", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 0,
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: outlineColor, height: 1.0),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryDark))
          : RefreshIndicator(
        onRefresh: _fetchData,
        color: primaryDark,
        child: _vessels.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _vessels.length,
          itemBuilder: (context, index) {
            final vessel = _vessels[index];
            return _buildVesselCard(vessel);
          },
        ),
      ),
    );
  }

  Widget _buildVesselCard(Map<String, dynamic> vessel) {
    String displayStatus = "Docked";
    final dynamic statusData = vessel['vessel_status'];
    if (statusData is Map) {
      displayStatus = (statusData['status'] ?? "Docked").toString();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outlineColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: primaryDark.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.directions_boat_rounded, color: primaryDark),
        ),
        title: Text(vessel['vessel_name'] ?? "Unknown Vessel", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(vessel['vessel_type'] ?? "Ro-Ro Passenger", style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(displayStatus).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                displayStatus.toUpperCase(),
                style: TextStyle(color: _getStatusColor(displayStatus), fontWeight: FontWeight.w900, fontSize: 10),
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VesselTracking(
                vessel: vessel,
                availablePorts: _ports,
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'docked': return Colors.teal;
      case 'departed': return Colors.blue;
      case 'arrived': return Colors.green;
      case 'onboarding': return Colors.orange;
      default: return Colors.grey;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_boat_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text("No vessels tracked yet.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
