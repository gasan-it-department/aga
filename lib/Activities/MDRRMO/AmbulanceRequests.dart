import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/FloatingMessages/SnackbarMessenger.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AmbulanceRequests extends StatefulWidget {
  const AmbulanceRequests({super.key, required this.municipalityName});

  final String municipalityName;

  @override
  State<AmbulanceRequests> createState() => _AmbulanceRequestsState();
}

class _AmbulanceRequestsState extends State<AmbulanceRequests> {
  final _supabase = Supabase.instance.client;

  static const _primary = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _line = Color(0xFFE2E8F0);
  static const _bg = Color(0xFFF8FAFC);
  static const _red = Color(0xFFDC2626);

  final _statuses = const [
    'all',
    'pending',
    'accepted',
    'dispatched',
    'completed',
    'rejected',
  ];

  String _selectedStatus = 'all';
  String _selectedType = 'all';
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      var query = _supabase.from('ambulance_request').select();

      if (_selectedStatus != 'all') {
        query = query.eq('request_status', _selectedStatus);
      }

      final data = await query.order('request_date_created', ascending: false);
      final list = (data as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where(_matchesMunicipality)
          .where(_matchesType)
          .toList();

      if (mounted) setState(() => _requests = list);
    } catch (e) {
      if (mounted) {
        SnackbarMessenger().showSnackbar(
          context,
          SnackbarMessenger.failed,
          'Failed to load ambulance requests: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _matchesMunicipality(Map<String, dynamic> request) {
    final adminMunicipality = widget.municipalityName.trim().toLowerCase();
    if (adminMunicipality.isEmpty ||
        adminMunicipality == 'mdrrmo' ||
        adminMunicipality == 'provincial command') {
      return true;
    }
    return (request['pickup_municipality'] ?? '')
        .toString()
        .trim()
        .toLowerCase()
        .contains(adminMunicipality);
  }

  bool _matchesType(Map<String, dynamic> request) {
    if (_selectedType == 'all') return true;
    return (request['request_type'] ?? '').toString() == _selectedType;
  }

  Future<void> _updateStatus(
    Map<String, dynamic> request,
    String status,
  ) async {
    final requestId = request['ambulance_request_id']?.toString();
    if (requestId == null || requestId.isEmpty) return;
    try {
      await _supabase
          .from('ambulance_request')
          .update({
            'request_status': status,
            'request_date_updated': Utility().getCurrentMSEpochTime(),
          })
          .eq('ambulance_request_id', requestId);
      if (mounted) {
        SnackbarMessenger().showSnackbar(
          context,
          SnackbarMessenger.success,
          'Ambulance request marked ${_label(status)}.',
        );
      }
      await _loadRequests();
    } catch (e) {
      if (mounted) {
        SnackbarMessenger().showSnackbar(
          context,
          SnackbarMessenger.failed,
          'Failed to update status: $e',
        );
      }
    }
  }

  Future<void> _call(String number) async {
    final clean = number.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: clean);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        elevation: 0,
        title: const Text(
          'Ambulance Requests',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _loadRequests,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _line),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadRequests,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _header(),
            const SizedBox(height: 14),
            _filters(),
            const SizedBox(height: 14),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_requests.isEmpty)
              _emptyState()
            else
              ..._requests.map(_requestCard),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final pending = _requests.where((item) {
      return (item['request_status'] ?? '').toString() == 'pending';
    }).length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _red,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _red.withValues(alpha: 0.2),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.airport_shuttle_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Transport Coordination',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$pending pending request(s) for ${widget.municipalityName}.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._statuses.map((status) {
          return _filterChip(
            label: _label(status),
            selected: _selectedStatus == status,
            onTap: () {
              setState(() => _selectedStatus = status);
              _loadRequests();
            },
          );
        }),
        _filterChip(
          label: _selectedType == 'all' ? 'All Types' : _selectedType,
          selected: _selectedType != 'all',
          onTap: _showTypeFilter,
        ),
      ],
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      selected: selected,
      onSelected: (_) => onTap(),
      label: Text(label),
      labelStyle: TextStyle(
        color: selected ? Colors.white : _primary,
        fontWeight: FontWeight.w800,
      ),
      selectedColor: _primary,
      backgroundColor: Colors.white,
      side: const BorderSide(color: _line),
      checkmarkColor: Colors.white,
    );
  }

  void _showTypeFilter() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final types = ['all', 'Patient Transport', 'Deceased Transport'];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: types.map((type) {
              return ListTile(
                title: Text(type == 'all' ? 'All Types' : type),
                trailing: _selectedType == type
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedType = type);
                  _loadRequests();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _requestCard(Map<String, dynamic> request) {
    final status = (request['request_status'] ?? 'pending').toString();
    final statusColor = _statusColor(status);
    final type = (request['request_type'] ?? 'Ambulance Request').toString();
    final requester = _fullName(
      request['requester_first_name'],
      request['requester_middle_name'],
      request['requester_last_name'],
    );
    final patient = _fullName(
      request['patient_first_name'],
      request['patient_middle_name'],
      request['patient_last_name'],
    );
    final address =
        [
              request['pickup_barangay'],
              request['pickup_municipality'],
              request['pickup_province'],
            ]
            .where((item) => item != null && item.toString().trim().isNotEmpty)
            .join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  type == 'Deceased Transport'
                      ? Icons.airline_seat_flat_rounded
                      : Icons.accessible_forward_rounded,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type,
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatDate(request['request_date_created']),
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _statusBadge(status),
            ],
          ),
          const SizedBox(height: 14),
          _infoRow(Icons.person_rounded, 'Requester', requester),
          _infoRow(Icons.local_hospital_rounded, 'For', patient),
          _infoRow(Icons.place_rounded, 'Pickup', address),
          _infoRow(
            Icons.notes_rounded,
            'Details',
            (request['request_details'] ?? 'No details').toString(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _call(
                  (request['requester_contact_number'] ?? '').toString(),
                ),
                icon: const Icon(Icons.call_rounded, size: 18),
                label: const Text('Call'),
              ),
              if (status == 'pending')
                FilledButton(
                  onPressed: () => _updateStatus(request, 'accepted'),
                  child: const Text('Accept'),
                ),
              if (status == 'accepted')
                FilledButton(
                  onPressed: () => _updateStatus(request, 'dispatched'),
                  child: const Text('Dispatch'),
                ),
              if (status == 'dispatched')
                FilledButton(
                  onPressed: () => _updateStatus(request, 'completed'),
                  child: const Text('Complete'),
                ),
              if (status != 'completed' && status != 'rejected')
                TextButton(
                  onPressed: () => _updateStatus(request, 'rejected'),
                  child: const Text('Reject'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _label(status),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: _muted),
          const SizedBox(width: 8),
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'N/A' : value,
              style: const TextStyle(
                color: _primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: const Column(
        children: [
          Icon(Icons.airport_shuttle_rounded, size: 42, color: _muted),
          SizedBox(height: 12),
          Text(
            'No ambulance requests found.',
            style: TextStyle(
              color: _primary,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return const Color(0xFF2563EB);
      case 'dispatched':
        return const Color(0xFFF59E0B);
      case 'completed':
        return const Color(0xFF059669);
      case 'rejected':
        return const Color(0xFF64748B);
      default:
        return _red;
    }
  }

  String _label(String value) {
    if (value == 'all') return 'All';
    return value
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  String _fullName(dynamic first, dynamic middle, dynamic last) {
    return [first, middle, last]
        .where((item) => item != null && item.toString().trim().isNotEmpty)
        .map((item) => item.toString().trim())
        .join(' ');
  }

  String _formatDate(dynamic epochMillis) {
    final value = epochMillis is num
        ? epochMillis.toInt()
        : int.tryParse(epochMillis?.toString() ?? '');
    if (value == null || value <= 0) return 'Unknown time';
    final date = DateTime.fromMillisecondsSinceEpoch(value);
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.month}/${date.day}/${date.year} $hour:$minute $suffix';
  }
}
