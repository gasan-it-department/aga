import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gasan_port_tracker/Activities/UserDeliveryAddress.dart';
import 'package:gasan_port_tracker/Dialogs/ClassicDialog.dart';
import 'package:gasan_port_tracker/Dialogs/LoadingDialog.dart';
import 'package:gasan_port_tracker/FloatingMessages/SnackbarMessenger.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';

class UserDeliveryAddressList extends StatefulWidget {
  const UserDeliveryAddressList({super.key});

  @override
  State<UserDeliveryAddressList> createState() => _UserDeliveryAddressListState();
}

class _UserDeliveryAddressListState extends State<UserDeliveryAddressList> {
  final _supabase = Supabase.instance.client;
  final _loadingDialog = LoadingDialog();

  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryColor = const Color(0xFF0A2E5C);
  final Color accentColor = const Color(0xFF3B82F6);
  final Color outlineColor = const Color(0xFFE2E8F0);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);
  final Color successColor = const Color(0xFF10B981);
  final Color dangerColor = const Color(0xFFEF4444);

  List<Map<String, dynamic>> _addresses = [];
  bool _isLoading = true;
  static const int _maxAddresses = 10;

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
  }

  Future<void> _fetchAddresses() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final row = await _supabase
          .from('user_data')
          .select('user_delivery_address')
          .eq('user_id', user.id)
          .maybeSingle();

      final raw = row?['user_delivery_address'];
      List<Map<String, dynamic>> parsed = [];
      if (raw is List) {
        parsed = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (raw is Map) {
        // Backward compat: previously a single map.
        final m = Map<String, dynamic>.from(raw);
        m['id'] ??= 'ADDR_${DateTime.now().microsecondsSinceEpoch}';
        m['is_default'] ??= true;
        parsed = [m];
      }
      // Ensure each entry has an id
      for (final a in parsed) {
        a['id'] ??= 'ADDR_${DateTime.now().microsecondsSinceEpoch}_${parsed.indexOf(a)}';
      }
      if (mounted) setState(() => _addresses = parsed);
    } catch (e) {
      Utility().printLog("Fetch addresses error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _persist(List<Map<String, dynamic>> addrs) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    await _supabase
        .from('user_data')
        .update({'user_delivery_address': addrs})
        .eq('user_id', user.id);
  }

  Future<void> _addOrEdit({Map<String, dynamic>? existing}) async {
    if (existing == null && _addresses.length >= _maxAddresses) {
      SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed,
          "You can save up to $_maxAddresses addresses.");
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserDeliveryAddress(initialAddress: existing),
      ),
    );
    if (result is! Map) return;
    final newAddr = Map<String, dynamic>.from(result);

    final updated = List<Map<String, dynamic>>.from(_addresses);
    if (existing == null) {
      // First address becomes default automatically
      if (updated.isEmpty) newAddr['is_default'] = true;
      updated.add(newAddr);
    } else {
      final idx = updated.indexWhere((a) => a['id'] == existing['id']);
      if (idx == -1) {
        updated.add(newAddr);
      } else {
        updated[idx] = newAddr;
      }
    }

    _loadingDialog.showLoadingDialog(context);
    _loadingDialog.updateTitle("Saving...");
    try {
      await _persist(updated);
      _loadingDialog.dismiss();
      if (mounted) {
        SnackbarMessenger().showSnackbar(context, SnackbarMessenger.success,
            existing == null ? "Address added." : "Address updated.");
      }
      await _fetchAddresses();
    } catch (e) {
      _loadingDialog.dismiss();
      if (mounted) {
        SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Save failed: $e");
      }
    }
  }

  Future<void> _setDefault(Map<String, dynamic> addr) async {
    final updated = _addresses.map((a) {
      final m = Map<String, dynamic>.from(a);
      m['is_default'] = a['id'] == addr['id'];
      return m;
    }).toList();
    try {
      await _persist(updated);
      await _fetchAddresses();
    } catch (e) {
      if (mounted) {
        SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Could not set default: $e");
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> addr) async {
    final dialog = ClassicDialog();
    dialog.setTitle("Delete Address?");
    dialog.setMessage("This will permanently remove this delivery address.");
    dialog.setPositiveMessage("Delete");
    dialog.setNegativeMessage("Cancel");
    dialog.setCancelable(false);
    dialog.showTwoButtonDialog(context, (_) {
      dialog.dismissDialog();
    }, (_) async {
      dialog.dismissDialog();
      final updated = List<Map<String, dynamic>>.from(_addresses)
        ..removeWhere((a) => a['id'] == addr['id']);
      // Re-promote a default if removed
      if (addr['is_default'] == true && updated.isNotEmpty) {
        updated.first['is_default'] = true;
      }
      try {
        await _persist(updated);
        await _fetchAddresses();
        if (mounted) {
          SnackbarMessenger().showSnackbar(context, SnackbarMessenger.success, "Address deleted.");
        }
      } catch (e) {
        if (mounted) {
          SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Delete failed: $e");
        }
      }
    });
  }

  void _showActionsSheet(Map<String, dynamic> a) {
    final isDefault = a['is_default'] == true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          constraints: BoxConstraints(maxWidth: Utility().getMaxScreenSize()),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 5,
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  decoration: BoxDecoration(color: outlineColor, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Icon(Icons.home_work_rounded, color: accentColor, size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_displayName(a),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text(_addressLine(a),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: outlineColor),
              _sheetAction(
                icon: Icons.edit_rounded,
                label: "Edit address",
                color: primaryColor,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _addOrEdit(existing: a);
                },
              ),
              if (!isDefault)
                _sheetAction(
                  icon: Icons.check_circle_rounded,
                  label: "Set as default",
                  color: successColor,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _setDefault(a);
                  },
                ),
              _sheetAction(
                icon: Icons.delete_outline_rounded,
                label: "Delete address",
                color: dangerColor,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _delete(a);
                },
              ),
              const SafeArea(top: false, child: SizedBox(height: 8)),
            ],
          ),
        );
      },
    );
  }

  Widget _sheetAction({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
          ),
          Icon(Icons.arrow_forward_ios_rounded, color: textSecondary.withValues(alpha: 0.5), size: 13),
        ]),
      ),
    );
  }

  String _displayName(Map<String, dynamic> a) {
    final parts = [
      (a['first_name'] ?? '').toString().trim(),
      (a['middle_name'] ?? '').toString().trim(),
      (a['last_name'] ?? '').toString().trim(),
    ].where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? "Unnamed Recipient" : parts.join(' ');
  }

  String _addressLine(Map<String, dynamic> a) {
    final parts = [
      (a['street'] ?? '').toString().trim(),
      (a['barangay'] ?? '').toString().trim(),
      (a['municipality'] ?? '').toString().trim(),
      (a['province'] ?? '').toString().trim(),
    ].where((s) => s.isNotEmpty).toList();
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0,
        title: const Text("Delivery Addresses", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: Utility().getMaxScreenSize()),
                child: RefreshIndicator(
                  color: primaryColor,
                  onRefresh: _fetchAddresses,
                  child: _addresses.isEmpty ? _buildEmpty() : _buildList(),
                ),
              ),
            ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              onPressed: () => _addOrEdit(),
              icon: const Icon(Icons.add_location_alt_rounded),
              label: const Text("Add Address", style: TextStyle(fontWeight: FontWeight.w900)),
            ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: primaryColor.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Icon(Icons.local_shipping_outlined, size: 64, color: accentColor.withValues(alpha: 0.6)),
          ),
        ),
        const SizedBox(height: 20),
        Text("No saved addresses",
            textAlign: TextAlign.center,
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            "Add a delivery address so checkout can deliver your orders to the right place.",
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: _addresses.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) return _buildCountBanner();
        final addr = _addresses[index - 1];
        return _buildAddressCard(addr);
      },
    );
  }

  Widget _buildCountBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(Icons.bookmarks_rounded, color: accentColor, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "${_addresses.length} of $_maxAddresses saved",
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.w800, fontSize: 12.5),
          ),
        ),
        Text(
          "Tap a card to manage",
          style: TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ]),
    );
  }

  Widget _buildAddressCard(Map<String, dynamic> a) {
    final isDefault = a['is_default'] == true;
    final coords = a['coordinates'];
    String? coordsLabel;
    if (coords is Map) {
      final lat = (coords['latitude'] as num?)?.toDouble();
      final lng = (coords['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        coordsLabel = "${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}";
      }
    }
    final notes = (a['notes'] ?? '').toString().trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showActionsSheet(a),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDefault ? successColor.withValues(alpha: 0.5) : outlineColor),
            boxShadow: [
              BoxShadow(color: primaryColor.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isDefault ? successColor : accentColor).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.home_work_rounded,
                        color: isDefault ? successColor : accentColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text(
                              _displayName(a),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: textPrimary, fontWeight: FontWeight.w900, fontSize: 15),
                            ),
                          ),
                          if (isDefault) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: successColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text("DEFAULT",
                                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 4),
                        Text(_addressLine(a),
                            style: TextStyle(color: textSecondary, fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
              if (coordsLabel != null) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Icon(Icons.pin_drop_rounded, size: 14, color: accentColor),
                  const SizedBox(width: 6),
                  Text(coordsLabel,
                      style: TextStyle(color: textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700)),
                ]),
              ],
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: outlineColor),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.notes_rounded, size: 14, color: textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(notes,
                          style: TextStyle(color: textSecondary, fontSize: 12, height: 1.4, fontWeight: FontWeight.w500)),
                    ),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
