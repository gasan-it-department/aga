import 'dart:convert';
import 'package:gasan_port_tracker/Activities/CommunityReportedCases.dart';
import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Dialogs/ClassicDialog.dart';
import 'package:gasan_port_tracker/FloatingMessages/SnackbarMessenger.dart';
import 'package:gasan_port_tracker/Utility/SupabaseExternalAuthBridge.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

class CommunityIssueReport extends StatefulWidget {
  const CommunityIssueReport({super.key});

  @override
  State<CommunityIssueReport> createState() => _CommunityIssueReportState();
}

class _CommunityIssueReportState extends State<CommunityIssueReport> {
  static const int _maximumPhotos = 5;
  static const int _maximumPhotoSizeMb = 10;
  static const int _maximumDescriptionLength = 5000;

  final _classicDialog = ClassicDialog();
  final _locationCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _imagePicker = ImagePicker();

  final _primary = const Color(0xFF0F766E);
  final _dark = const Color(0xFF0F172A);
  final _muted = const Color(0xFF64748B);
  final _border = const Color(0xFFE2E8F0);

  String _issueTypeValue = 'Road or drainage issue';
  bool _submitting = false;
  bool _loadingIssueTypes = false;
  bool _isAnonymous = false;
  Position? _position;
  List<XFile> _evidencePhotos = [];

  List<_IssueTypeOption> _issueTypes = [
    _IssueTypeOption(
      label: 'Road or drainage issue',
      value: 'Road or drainage issue',
    ),
    _IssueTypeOption(
      label: 'Streetlight problem',
      value: 'Streetlight problem',
    ),
    _IssueTypeOption(
      label: 'Garbage or sanitation',
      value: 'Garbage or sanitation',
    ),
    _IssueTypeOption(
      label: 'Water supply concern',
      value: 'Water supply concern',
    ),
    _IssueTypeOption(
      label: 'Public safety concern',
      value: 'Public safety concern',
    ),
    _IssueTypeOption(
      label: 'Stray animal concern',
      value: 'Stray animal concern',
    ),
    _IssueTypeOption(label: 'Noise or nuisance', value: 'Noise or nuisance'),
    _IssueTypeOption(
      label: 'Other community issue',
      value: 'Other community issue',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadIssueTypes();
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadIssueTypes() async {
    setState(() => _loadingIssueTypes = true);
    try {
      final response = await SupabaseExternalAuthBridge()
          .getCommunityReportSubmissionContext();
      if (response.statusCode < 200 || response.statusCode >= 300) return;

      final decoded = jsonDecode(response.body);
      final loadedTypes = _extractIssueTypes(decoded);
      if (loadedTypes.isEmpty || !mounted) return;

      setState(() {
        _issueTypes = loadedTypes;
        _issueTypeValue = loadedTypes.first.value;
      });
    } catch (error) {
      Utility().printLog('Load community issue types failed: $error');
    } finally {
      if (mounted) setState(() => _loadingIssueTypes = false);
    }
  }

  List<_IssueTypeOption> _extractIssueTypes(dynamic source) {
    const typeKeys = {
      'issue_types',
      'issueTypes',
      'types',
      'categories',
      'report_types',
      'reportTypes',
    };

    if (source is List) {
      return source
          .map(_issueTypeOption)
          .whereType<_IssueTypeOption>()
          .fold<Map<String, _IssueTypeOption>>({}, (map, option) {
            map[option.value] = option;
            return map;
          })
          .values
          .toList();
    }

    if (source is Map) {
      for (final entry in source.entries) {
        if (typeKeys.contains(entry.key.toString())) {
          final result = _extractIssueTypes(entry.value);
          if (result.isNotEmpty) return result;
        }
      }

      final data = source['data'];
      if (data != null) {
        final result = _extractIssueTypes(data);
        if (result.isNotEmpty) return result;
      }
    }

    return <_IssueTypeOption>[];
  }

  _IssueTypeOption? _issueTypeOption(dynamic item) {
    if (item == null) return null;
    if (item is String || item is num || item is bool) {
      final value = item.toString();
      return value.trim().isEmpty
          ? null
          : _IssueTypeOption(label: value, value: value);
    }
    if (item is Map) {
      String? label;
      String? value;
      for (final key in ['label', 'name', 'title', 'display_name']) {
        final raw = item[key];
        if (raw != null && raw.toString().trim().isNotEmpty) {
          label = raw.toString();
          break;
        }
      }
      for (final key in ['value', 'id', 'slug', 'code', 'type', 'category']) {
        final raw = item[key];
        if (raw != null && raw.toString().trim().isNotEmpty) {
          value = raw.toString();
          break;
        }
      }
      label ??= value;
      value ??= label;
      if (label != null && value != null) {
        return _IssueTypeOption(label: label, value: value);
      }
    }
    return null;
  }

  Future<void> _useCurrentLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _showDialog('Location Disabled', 'Please turn on GPS first.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showDialog('Permission Required', 'Location permission is required.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() {
        _position = position;
        if (_locationCtrl.text.trim().isEmpty) {
          _locationCtrl.text = 'Pinned current location';
        }
      });
    } catch (error) {
      _showDialog('Location Failed', error.toString());
    }
  }

  Future<void> _pickEvidencePhotos() async {
    try {
      if (_evidencePhotos.length >= _maximumPhotos) {
        _showDialog(
          'Limit Reached',
          'You can attach up to $_maximumPhotos photos only.',
        );
        return;
      }

      final selected = await _imagePicker.pickMultiImage(imageQuality: 75);
      if (selected.isEmpty || !mounted) return;

      final accepted = <XFile>[];
      for (final photo in selected) {
        final sizeMb = await photo.length() / (1024 * 1024);
        if (sizeMb <= _maximumPhotoSizeMb) {
          accepted.add(photo);
        }
      }

      setState(() {
        _evidencePhotos = [
          ..._evidencePhotos,
          ...accepted,
        ].take(_maximumPhotos).toList();
      });

      if (accepted.length < selected.length && mounted) {
        SnackbarMessenger().showSnackbar(
          context,
          SnackbarMessenger.failed,
          'Some photos exceeded $_maximumPhotoSizeMb MB and were skipped.',
        );
      }
    } catch (error) {
      _showDialog('Photo Selection Failed', error.toString());
    }
  }

  void _removeEvidencePhoto(int index) {
    setState(() => _evidencePhotos.removeAt(index));
  }

  Future<void> _submit() async {
    if (_locationCtrl.text.trim().isEmpty ||
        _descriptionCtrl.text.trim().isEmpty) {
      _showDialog('Missing Details', 'Please complete all required fields.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final payload = {
        'category': _issueTypeValue,
        'location_text': _locationCtrl.text.trim(),
        'latitude': _position?.latitude,
        'longitude': _position?.longitude,
        'description': _descriptionCtrl.text.trim(),
        'is_anonymous': _isAnonymous,
      };

      final response = await SupabaseExternalAuthBridge().submitCommunityReport(
        payload,
        _evidencePhotos,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(response.body);
      }
      if (!mounted) return;
      setState(() => _submitting = false);
      SnackbarMessenger().showSnackbar(
        context,
        SnackbarMessenger.success,
        'Community issue submitted.',
      );
      Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _submitting = false);
      _showDialog('Submission Failed', error.toString());
    }
  }

  void _showDialog(String title, String message) {
    if (!mounted) return;
    _classicDialog.setTitle(title);
    _classicDialog.setMessage(message);
    _classicDialog.setPositiveMessage('Close');
    _classicDialog.showOnButtonDialog(context, _classicDialog.dismissDialog);
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
          'Report Community Issue',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        actions: [
          IconButton(
            tooltip: 'Reported Cases',
            icon: const Icon(Icons.assignment_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CommunityReportedCases(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _hero(),
            const SizedBox(height: 16),
            _section(
              title: 'Report Details',
              children: [
                _dropdown(
                  label: _loadingIssueTypes
                      ? 'Loading Issue Types...'
                      : 'Issue Type',
                  value: _issueTypeValue,
                  items: _issueTypes,
                  onChanged: _loadingIssueTypes
                      ? null
                      : (value) => setState(() => _issueTypeValue = value!),
                  loading: _loadingIssueTypes,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _locationCtrl,
                  label: 'Location Text',
                  hint: 'Barangay, street, landmark, or exact area',
                  icon: Icons.place_rounded,
                ),
                const SizedBox(height: 10),
                _locationButton(),
                const SizedBox(height: 10),
                _coordinateBox(),
              ],
            ),
            const SizedBox(height: 14),
            _section(
              title: 'Description and Evidence',
              children: [
                _field(
                  controller: _descriptionCtrl,
                  label: 'Description',
                  hint: 'Describe the issue clearly.',
                  icon: Icons.notes_rounded,
                  maxLines: 5,
                  maxLength: _maximumDescriptionLength,
                ),
                const SizedBox(height: 12),
                _anonymousSwitch(),
                const SizedBox(height: 12),
                _evidencePhotoPicker(),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_submitting ? 'Submitting...' : 'Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationButton() {
    return OutlinedButton.icon(
      onPressed: _useCurrentLocation,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        foregroundColor: _primary,
        side: BorderSide(color: _primary.withValues(alpha: 0.35)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(
        _position == null
            ? Icons.my_location_rounded
            : Icons.check_circle_rounded,
      ),
      label: Text(
        _position == null
            ? 'Capture Latitude and Longitude'
            : 'Location Captured',
      ),
    );
  }

  Widget _coordinateBox() {
    final latitude = _position?.latitude.toStringAsFixed(6) ?? '--';
    final longitude = _position?.longitude.toStringAsFixed(6) ?? '--';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.pin_drop_rounded, color: _primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Latitude: $latitude\nLongitude: $longitude',
              style: TextStyle(
                color: _dark,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _anonymousSwitch() {
    return SwitchListTile(
      value: _isAnonymous,
      onChanged: (value) => setState(() => _isAnonymous = value),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      tileColor: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: _border),
      ),
      activeThumbColor: _primary,
      title: Text(
        'Submit Anonymously',
        style: TextStyle(
          color: _dark,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
      subtitle: Text(
        'Your account name will not be shown in the report.',
        style: TextStyle(color: _muted, fontSize: 11),
      ),
    );
  }

  Widget _evidencePhotoPicker() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_library_rounded, color: _primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Evidence Photos',
                  style: TextStyle(
                    color: _dark,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _evidencePhotos.length >= _maximumPhotos
                    ? null
                    : _pickEvidencePhotos,
                icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_evidencePhotos.isEmpty)
            Text(
              'Optional. Add up to $_maximumPhotos photos, $_maximumPhotoSizeMb MB each.',
              style: TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_evidencePhotos.length, (index) {
                final photo = _evidencePhotos[index];
                return InputChip(
                  label: Text(photo.name, overflow: TextOverflow.ellipsis),
                  avatar: const Icon(Icons.image_rounded, size: 18),
                  onDeleted: () => _removeEvidencePhoto(index),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.report_problem_rounded,
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
                  'Community Issue',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Report non-emergency concerns for municipal action.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    height: 1.35,
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

  Widget _section({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<_IssueTypeOption> items,
    required ValueChanged<String?>? onChanged,
    bool loading = false,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items
          .map(
            (item) =>
                DropdownMenuItem(value: item.value, child: Text(item.label)),
          )
          .toList(),
      onChanged: onChanged,
      decoration: _input(label, Icons.category_rounded).copyWith(
        suffixIcon: loading
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      decoration: _input(label, icon).copyWith(hintText: hint),
    );
  }

  InputDecoration _input(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _primary),
      labelStyle: TextStyle(color: _muted, fontWeight: FontWeight.w700),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _primary, width: 1.5),
      ),
    );
  }
}

class _IssueTypeOption {
  const _IssueTypeOption({required this.label, required this.value});

  final String label;
  final String value;
}
