import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class RequestAmbulance extends StatefulWidget {
  const RequestAmbulance({super.key});

  @override
  State<RequestAmbulance> createState() => _RequestAmbulanceState();
}

class _RequestAmbulanceState extends State<RequestAmbulance> {
  final _formKey = GlobalKey<FormState>();
  final _psgc = _PsgcAddressService();
  final _supabase = Supabase.instance.client;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _contactController = TextEditingController();
  final _gmailController = TextEditingController();
  final _patientFirstNameController = TextEditingController();
  final _patientLastNameController = TextEditingController();
  final _patientMiddleNameController = TextEditingController();
  final _detailsController = TextEditingController();

  final _requestTypes = const ['Patient Transport', 'Deceased Transport'];

  List<_PsgcLocation> _provinces = [];
  List<_PsgcLocation> _municipalities = [];
  List<_PsgcLocation> _barangays = [];

  _PsgcLocation? _selectedProvince;
  _PsgcLocation? _selectedMunicipality;
  _PsgcLocation? _selectedBarangay;
  String _selectedNeed = 'Patient Transport';
  bool _isLoadingProvinces = true;
  bool _isLoadingMunicipalities = false;
  bool _isLoadingBarangays = false;
  bool _isSubmitting = false;

  static const _primary = Color(0xFF0A2E5C);
  static const _danger = Color(0xFFDC2626);
  static const _muted = Color(0xFF64748B);
  static const _line = Color(0xFFE2E8F0);
  static const _bg = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _contactController.dispose();
    _gmailController.dispose();
    _patientFirstNameController.dispose();
    _patientLastNameController.dispose();
    _patientMiddleNameController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _loadProvinces() async {
    setState(() => _isLoadingProvinces = true);
    try {
      final provinces = await _psgc.getProvinces();
      if (!mounted) return;
      final marinduque = provinces.where((item) {
        return item.name.toLowerCase() == 'marinduque';
      }).toList();
      setState(() {
        _provinces = provinces;
        _selectedProvince = marinduque.isEmpty ? null : marinduque.first;
      });
      if (_selectedProvince != null) {
        await _loadMunicipalities(_selectedProvince!);
      }
    } catch (_) {
      if (mounted) _showSnack('Could not load provinces. Check internet.');
    } finally {
      if (mounted) setState(() => _isLoadingProvinces = false);
    }
  }

  Future<void> _loadMunicipalities(_PsgcLocation province) async {
    setState(() {
      _isLoadingMunicipalities = true;
      _municipalities = [];
      _barangays = [];
      _selectedMunicipality = null;
      _selectedBarangay = null;
    });
    try {
      final municipalities = await _psgc.getMunicipalities(province.code);
      if (!mounted) return;
      setState(() => _municipalities = municipalities);
    } catch (_) {
      if (mounted) _showSnack('Could not load cities/municipalities.');
    } finally {
      if (mounted) setState(() => _isLoadingMunicipalities = false);
    }
  }

  Future<void> _loadBarangays(_PsgcLocation municipality) async {
    setState(() {
      _isLoadingBarangays = true;
      _barangays = [];
      _selectedBarangay = null;
    });
    try {
      final barangays = await _psgc.getBarangays(municipality.code);
      if (!mounted) return;
      setState(() => _barangays = barangays);
    } catch (_) {
      if (mounted) _showSnack('Could not load barangays.');
    } finally {
      if (mounted) setState(() => _isLoadingBarangays = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    final requestId = 'AMB_${DateTime.now().microsecondsSinceEpoch}';
    final payload = {
      'ambulance_request_id': requestId,
      'requester_user_id': _supabase.auth.currentUser?.id,
      'requester_first_name': _firstNameController.text.trim(),
      'requester_last_name': _lastNameController.text.trim(),
      'requester_middle_name': _middleNameController.text.trim(),
      'requester_contact_number': _contactController.text.trim(),
      'requester_gmail': _gmailController.text.trim(),
      'request_type': _selectedNeed,
      'pickup_barangay': _selectedBarangay?.name,
      'pickup_municipality': _selectedMunicipality?.name,
      'pickup_province': _selectedProvince?.name,
      'pickup_barangay_code': _selectedBarangay?.code,
      'pickup_municipality_code': _selectedMunicipality?.code,
      'pickup_province_code': _selectedProvince?.code,
      'patient_first_name': _patientFirstNameController.text.trim(),
      'patient_last_name': _patientLastNameController.text.trim(),
      'patient_middle_name': _patientMiddleNameController.text.trim(),
      'request_details': _detailsController.text.trim(),
      'request_status': 'pending',
      'request_date_created': Utility().getCurrentMSEpochTime(),
      'request_date_updated': Utility().getCurrentMSEpochTime(),
      'request_metadata': {
        'source': 'aga_app',
        'screen': 'request_ambulance',
        'debug_feature': true,
      },
    };
    try {
      debugPrint('Ambulance request payload: ${jsonEncode(payload)}');
      await _supabase.from('ambulance_request').insert(payload);
      if (!mounted) return;
      _showSnack('Ambulance request submitted.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) _showSnack('Failed to submit ambulance request: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        elevation: 0,
        title: const Text(
          'Request Ambulance',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              width >= 700 ? 24 : 16,
              16,
              width >= 700 ? 24 : 16,
              24,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _hero(),
                      const SizedBox(height: 16),
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _yourDetailsSection()),
                            const SizedBox(width: 16),
                            Expanded(child: _transportSection()),
                          ],
                        )
                      else ...[
                        _yourDetailsSection(),
                        const SizedBox(height: 16),
                        _transportSection(),
                      ],
                      const SizedBox(height: 16),
                      _addressSection(),
                      const SizedBox(height: 16),
                      _detailsSection(),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : () => _submit(),
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.local_hospital_rounded),
                          label: const Text(
                            'SUBMIT AMBULANCE REQUEST',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _danger,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _danger,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _danger.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: const Icon(
              Icons.airport_shuttle_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ambulance Transport Request',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'For patient or deceased transport coordination. This form is currently enabled for debug testing.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
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

  Widget _yourDetailsSection() {
    return _section(
      title: 'Your Details',
      subtitle: 'Requester information for contact and verification.',
      icon: Icons.person_rounded,
      children: [
        _responsiveFields([
          _field('First name', _firstNameController),
          _field('Last name', _lastNameController),
          _field('Middle name', _middleNameController, required: false),
        ]),
        const SizedBox(height: 12),
        _responsiveFields([
          _field(
            'Contact number',
            _contactController,
            keyboardType: TextInputType.phone,
          ),
          _field(
            'Gmail (optional)',
            _gmailController,
            required: false,
            keyboardType: TextInputType.emailAddress,
          ),
        ]),
      ],
    );
  }

  Widget _transportSection() {
    return _section(
      title: 'Transport Information',
      subtitle: 'Tell responders what kind of transport is needed.',
      icon: Icons.medical_services_rounded,
      children: [
        _choiceGroup(),
        const SizedBox(height: 14),
        _responsiveFields([
          _field(
            _selectedNeed == 'Deceased Transport'
                ? 'Deceased first name'
                : 'Patient first name',
            _patientFirstNameController,
          ),
          _field(
            _selectedNeed == 'Deceased Transport'
                ? 'Deceased last name'
                : 'Patient last name',
            _patientLastNameController,
          ),
          _field('Middle name', _patientMiddleNameController, required: false),
        ]),
      ],
    );
  }

  Widget _addressSection() {
    return _section(
      title: 'Pickup Address',
      subtitle:
          'Location lists are loaded from the Philippine PSGC public API.',
      icon: Icons.location_on_rounded,
      children: [
        _responsiveFields([
          _locationDropdown(
            label: 'Province',
            value: _selectedProvince,
            items: _provinces,
            isLoading: _isLoadingProvinces,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedProvince = value);
              _loadMunicipalities(value);
            },
          ),
          _locationDropdown(
            label: 'City/Municipality',
            value: _selectedMunicipality,
            items: _municipalities,
            isLoading: _isLoadingMunicipalities,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedMunicipality = value);
              _loadBarangays(value);
            },
          ),
          _locationDropdown(
            label: 'Barangay',
            value: _selectedBarangay,
            items: _barangays,
            isLoading: _isLoadingBarangays,
            onChanged: (value) => setState(() => _selectedBarangay = value),
          ),
        ]),
      ],
    );
  }

  Widget _detailsSection() {
    return _section(
      title: 'Tell More About It',
      subtitle: 'Add the important context dispatchers should know.',
      icon: Icons.notes_rounded,
      children: [
        TextFormField(
          controller: _detailsController,
          minLines: 4,
          maxLines: 7,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please add request details.';
            }
            return null;
          },
          decoration: _inputDecoration(
            'Describe the condition, pickup landmark, destination, urgency, or special instructions.',
            Icons.edit_note_rounded,
          ),
        ),
      ],
    );
  }

  Widget _choiceGroup() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _requestTypes.map((type) {
        final selected = _selectedNeed == type;
        return ChoiceChip(
          selected: selected,
          label: Text(type),
          avatar: Icon(
            type == 'Patient Transport'
                ? Icons.accessible_forward_rounded
                : Icons.airline_seat_flat_rounded,
            size: 18,
            color: selected ? Colors.white : _danger,
          ),
          labelStyle: TextStyle(
            color: selected ? Colors.white : _primary,
            fontWeight: FontWeight.w900,
          ),
          selectedColor: _danger,
          backgroundColor: const Color(0xFFFEF2F2),
          side: BorderSide(color: selected ? _danger : const Color(0xFFFECACA)),
          onSelected: (_) => setState(() => _selectedNeed = type),
        );
      }).toList(),
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: _primary, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _muted,
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
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _responsiveFields(List<Widget> fields) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 620;
        if (!isWide) {
          return Column(
            children: fields
                .map(
                  (field) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: field,
                  ),
                )
                .toList(),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: fields
              .map(
                (field) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: field,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool required = true,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty)) {
          return '$label is required.';
        }
        if (label.toLowerCase().contains('gmail') &&
            value != null &&
            value.trim().isNotEmpty &&
            !value.trim().contains('@')) {
          return 'Enter a valid email.';
        }
        return null;
      },
      decoration: _inputDecoration(label, Icons.badge_rounded),
    );
  }

  Widget _locationDropdown({
    required String label,
    required _PsgcLocation? value,
    required List<_PsgcLocation> items,
    required bool isLoading,
    required ValueChanged<_PsgcLocation?> onChanged,
  }) {
    return DropdownButtonFormField<_PsgcLocation>(
      initialValue: value,
      isExpanded: true,
      validator: (selected) => selected == null ? '$label is required.' : null,
      decoration: _inputDecoration(label, Icons.place_rounded).copyWith(
        suffixIcon: isLoading
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<_PsgcLocation>(
              value: item,
              child: Text(item.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: isLoading || items.isEmpty ? null : onChanged,
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _muted, size: 20),
      filled: true,
      fillColor: _bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primary, width: 1.4),
      ),
    );
  }
}

class _PsgcAddressService {
  static const _baseUrl = 'https://psgc.gitlab.io/api';
  List<_PsgcLocation>? _municipalityCache;

  Future<List<_PsgcLocation>> getProvinces() async {
    final data = await _getList('$_baseUrl/provinces/');
    return _parseLocations(data);
  }

  Future<List<_PsgcLocation>> getMunicipalities(String provinceCode) async {
    _municipalityCache ??= _parseLocations(
      await _getList('$_baseUrl/cities-municipalities/'),
    );
    final items = _municipalityCache!
        .where((item) => item.parentProvinceCode == provinceCode)
        .toList();
    items.sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  Future<List<_PsgcLocation>> getBarangays(String municipalityCode) async {
    final data = await _getList(
      '$_baseUrl/cities-municipalities/$municipalityCode/barangays/',
    );
    final items = _parseLocations(data);
    items.sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  Future<List<dynamic>> _getList(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('PSGC request failed: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is List) return decoded;
    if (decoded is Map && decoded['data'] is List) {
      return decoded['data'] as List;
    }
    return const [];
  }

  List<_PsgcLocation> _parseLocations(List<dynamic> data) {
    return data
        .whereType<Map<String, dynamic>>()
        .map((item) {
          return _PsgcLocation(
            code: item['code']?.toString() ?? '',
            name: item['name']?.toString().trim() ?? '',
            parentProvinceCode: item['provinceCode']?.toString(),
          );
        })
        .where((item) => item.code.isNotEmpty && item.name.isNotEmpty)
        .toList();
  }
}

class _PsgcLocation {
  const _PsgcLocation({
    required this.code,
    required this.name,
    this.parentProvinceCode,
  });

  final String code;
  final String name;
  final String? parentProvinceCode;

  @override
  bool operator ==(Object other) {
    return other is _PsgcLocation && other.code == code;
  }

  @override
  int get hashCode => code.hashCode;
}
