import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Utility/Municipalities.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GodModeUserAccess extends StatefulWidget {
  const GodModeUserAccess({super.key});

  @override
  State<GodModeUserAccess> createState() => _GodModeUserAccessState();
}

class _GodModeUserAccessState extends State<GodModeUserAccess> {
  static const _bg = Color(0xFFF8FAFC);
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _line = Color(0xFFE2E8F0);
  static const _primary = Color(0xFF0A2E5C);
  static const _gold = Color(0xFFF59E0B);
  static const _roles = [
    'maritime',
    'captain',
    'mdrrmo',
    'tourism',
    'mdrrmo_personnel',
    'marketplace_admin',
  ];

  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  final _assignedPortIdController = TextEditingController();
  final _assignedPortController = TextEditingController();
  final Set<String> _selectedRoles = {};

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _ports = [];
  Map<String, dynamic>? _selectedUser;
  String _userType = 'citizen';
  int _municipalityZipCode = 4905;
  String? _selectedPortId;
  bool _loading = false;
  bool _saving = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _loadPorts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _assignedPortIdController.dispose();
    _assignedPortController.dispose();
    super.dispose();
  }

  Future<void> _loadPorts() async {
    try {
      final data = await _supabase
          .from('ports')
          .select('port_id, port_name')
          .order('port_name');
      if (!mounted) return;
      setState(() => _ports = List<Map<String, dynamic>>.from(data));
    } catch (error) {
      debugPrint('God Mode ports load failed: $error');
    }
  }

  Future<void> _searchUsers() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _notice = null;
      _selectedUser = null;
    });

    try {
      final data = await _supabase
          .from('user_data')
          .select('user_id, user_name, user_account, user_access, account_status')
          .or('user_name.ilike.%$query%,user_account.ilike.%$query%,user_id.ilike.%$query%')
          .limit(30);
      if (!mounted) return;
      setState(() {
        _users = List<Map<String, dynamic>>.from(data);
        _notice = _users.isEmpty ? 'No users found for "$query".' : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _notice = 'Unable to search users: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectUser(Map<String, dynamic> user) {
    final access = _asAccessMap(user['user_access']);
    final rawRoles = access['access'] is List ? access['access'] as List : const [];
    final portId = access['assigned_port_id']?.toString();
    final portName = access['assigned_port']?.toString() ?? '';

    _selectedRoles
      ..clear()
      ..addAll(rawRoles.map((role) => role.toString()).where(_roles.contains));
    _userType = access['user_type']?.toString() ?? (_selectedRoles.isEmpty ? 'citizen' : 'admin');
    _municipalityZipCode =
        int.tryParse(access['municipality_zip_code']?.toString() ?? '') ?? 4905;
    _selectedPortId = portId?.isEmpty == true ? null : portId;
    _assignedPortIdController.text = _selectedPortId ?? '';
    _assignedPortController.text = portName;

    if (_selectedPortId != null && _assignedPortController.text.trim().isEmpty) {
      final match = _ports.where((port) => port['port_id'].toString() == _selectedPortId).toList();
      if (match.isNotEmpty) {
        _assignedPortController.text = match.first['port_name'].toString();
      }
    }

    setState(() {
      _selectedUser = user;
      _notice = null;
    });
  }

  Map<String, dynamic> _asAccessMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  Future<void> _saveAccess() async {
    final user = _selectedUser;
    if (user == null) return;

    final assignedPort = _assignedPortController.text.trim();
    final assignedPortId = _assignedPortIdController.text.trim();
    final roles = _roles.where(_selectedRoles.contains).toList();
    final userAccess = {
      'access': roles,
      'user_type': _userType.trim().isEmpty ? 'citizen' : _userType.trim(),
      'assigned_port': assignedPort,
      'assigned_port_id': assignedPortId,
      'municipality_zip_code': _municipalityZipCode,
    };

    setState(() {
      _saving = true;
      _notice = null;
    });

    try {
      await _supabase
          .from('user_data')
          .update({'user_access': userAccess})
          .eq('user_id', user['user_id'].toString());
      if (!mounted) return;
      setState(() {
        _selectedUser = {...user, 'user_access': userAccess};
        final index = _users.indexWhere((item) => item['user_id'] == user['user_id']);
        if (index >= 0) _users[index] = _selectedUser!;
        _notice = 'Access updated for ${user['user_account'] ?? user['user_name']}.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _notice = 'Unable to save access: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clearAccess() async {
    final user = _selectedUser;
    if (user == null) return;

    setState(() {
      _saving = true;
      _notice = null;
    });

    try {
      await _supabase
          .from('user_data')
          .update({'user_access': null})
          .eq('user_id', user['user_id'].toString());
      if (!mounted) return;
      setState(() {
        _selectedRoles.clear();
        _userType = 'citizen';
        _selectedPortId = null;
        _assignedPortController.clear();
        _assignedPortIdController.clear();
        _selectedUser = {...user, 'user_access': null};
        final index = _users.indexWhere((item) => item['user_id'] == user['user_id']);
        if (index >= 0) _users[index] = _selectedUser!;
        _notice = 'Access cleared.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _notice = 'Unable to clear access: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 940;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        elevation: 0,
        title: const Text('User Access', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: EdgeInsets.all(width >= 700 ? 18 : 12),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 410, child: _buildSearchPanel()),
                        const SizedBox(width: 14),
                        Expanded(child: _buildEditorPanel()),
                      ],
                    )
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildSearchPanel(),
                        const SizedBox(height: 14),
                        _buildEditorPanel(),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchPanel() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Find User', 'Search by name, email, or user id.'),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _searchUsers(),
            decoration: _inputDecoration(
              hint: 'Search user...',
              icon: Icons.search_rounded,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _searchUsers,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.manage_search_rounded),
              label: Text(_loading ? 'Searching...' : 'Search'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (_notice != null) ...[
            const SizedBox(height: 12),
            _noticeBox(_notice!),
          ],
          const SizedBox(height: 14),
          if (_users.isEmpty)
            const Text('No selected user yet.', style: TextStyle(color: _muted))
          else
            ..._users.map(_userTile),
        ],
      ),
    );
  }

  Widget _userTile(Map<String, dynamic> user) {
    final selected = _selectedUser?['user_id'] == user['user_id'];
    final access = _asAccessMap(user['user_access']);
    final roles = access['access'] is List
        ? (access['access'] as List).map((item) => item.toString()).join(', ')
        : 'No access';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _selectUser(user),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? _primary : _line),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: selected ? _primary : const Color(0xFFE2E8F0),
                  child: Text(
                    (user['user_name'] ?? user['user_account'] ?? 'U')
                        .toString()
                        .trim()
                        .characters
                        .take(1)
                        .toString()
                        .toUpperCase(),
                    style: TextStyle(
                      color: selected ? Colors.white : _primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (user['user_name'] ?? 'Unnamed User').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _ink, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (user['user_account'] ?? user['user_id']).toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        roles,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _primary, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditorPanel() {
    final user = _selectedUser;
    if (user == null) {
      return _panel(
        child: const SizedBox(
          height: 360,
          child: Center(
            child: Text(
              'Search and select a user to edit system access.',
              style: TextStyle(color: _muted, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      );
    }

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Set Access', user['user_account']?.toString() ?? user['user_id'].toString()),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _roles.map((role) {
              final selected = _selectedRoles.contains(role);
              return FilterChip(
                selected: selected,
                label: Text(_labelForRole(role)),
                avatar: Icon(_iconForRole(role), size: 17),
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _selectedRoles.add(role);
                      if (_userType == 'citizen') _userType = 'admin';
                    } else {
                      _selectedRoles.remove(role);
                      if (_selectedRoles.isEmpty) _userType = 'citizen';
                    }
                  });
                },
                selectedColor: _primary.withValues(alpha: 0.12),
                checkmarkColor: _primary,
                side: BorderSide(color: selected ? _primary : _line),
                labelStyle: TextStyle(
                  color: selected ? _primary : _ink,
                  fontWeight: FontWeight.w800,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: _userType,
            decoration: _inputDecoration(hint: 'User type', icon: Icons.badge_rounded),
            items: const [
              DropdownMenuItem(value: 'admin', child: Text('admin')),
              DropdownMenuItem(value: 'citizen', child: Text('citizen')),
              DropdownMenuItem(value: 'personnel', child: Text('personnel')),
              DropdownMenuItem(value: 'seller', child: Text('seller')),
            ],
            onChanged: (value) => setState(() => _userType = value ?? 'citizen'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _municipalityZipCode,
            decoration: _inputDecoration(
              hint: 'Municipality',
              icon: Icons.location_city_rounded,
            ),
            items: Municipalities.list.map((item) {
              final zip = int.parse(item['zip']!);
              return DropdownMenuItem(
                value: zip,
                child: Text('${item['name']} ($zip)'),
              );
            }).toList(),
            onChanged: (value) => setState(() => _municipalityZipCode = value ?? 4905),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _ports.any((port) => port['port_id'].toString() == _selectedPortId)
                ? _selectedPortId
                : null,
            decoration: _inputDecoration(
              hint: 'Assigned port',
              icon: Icons.anchor_rounded,
            ),
            items: _ports.map((port) {
              return DropdownMenuItem(
                value: port['port_id'].toString(),
                child: Text(port['port_name'].toString()),
              );
            }).toList(),
            onChanged: (value) {
              final match = _ports.where((port) => port['port_id'].toString() == value).toList();
              setState(() {
                _selectedPortId = value;
                _assignedPortIdController.text = value ?? '';
                _assignedPortController.text =
                    match.isEmpty ? _assignedPortController.text : match.first['port_name'].toString();
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _assignedPortController,
                  decoration: _inputDecoration(
                    hint: 'Assigned port name',
                    icon: Icons.edit_location_alt_rounded,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _assignedPortIdController,
                  decoration: _inputDecoration(
                    hint: 'Assigned port id',
                    icon: Icons.numbers_rounded,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _previewJson(),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _clearAccess,
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  label: const Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _saveAccess,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Saving...' : 'Save Access'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewJson() {
    final lines = [
      '{',
      '  "access": [${_roles.where(_selectedRoles.contains).map((r) => '"$r"').join(', ')}],',
      '  "user_type": "$_userType",',
      '  "assigned_port": "${_assignedPortController.text.trim()}",',
      '  "assigned_port_id": "${_assignedPortIdController.text.trim()}",',
      '  "municipality_zip_code": $_municipalityZipCode',
      '}',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        lines.join('\n'),
        style: const TextStyle(
          color: Color(0xFFE2E8F0),
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: child,
    );
  }

  Widget _title(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: _muted, height: 1.35)),
      ],
    );
  }

  Widget _noticeBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold.withValues(alpha: 0.35)),
      ),
      child: Text(text, style: const TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.w700)),
    );
  }

  InputDecoration _inputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: _primary),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary, width: 1.4),
      ),
    );
  }

  String _labelForRole(String role) {
    switch (role) {
      case 'mdrrmo':
        return 'MDRRMO';
      case 'mdrrmo_personnel':
        return 'MDRRMO Personnel';
      case 'marketplace_admin':
        return 'Marketplace Admin';
      default:
        return role
            .split('_')
            .map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
            .join(' ');
    }
  }

  IconData _iconForRole(String role) {
    switch (role) {
      case 'maritime':
        return Icons.directions_boat_rounded;
      case 'captain':
        return Icons.sailing_rounded;
      case 'mdrrmo':
        return Icons.emergency_rounded;
      case 'tourism':
        return Icons.travel_explore_rounded;
      case 'mdrrmo_personnel':
        return Icons.health_and_safety_rounded;
      case 'marketplace_admin':
        return Icons.storefront_rounded;
      default:
        return Icons.admin_panel_settings_rounded;
    }
  }
}
