import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Utility/MarinduqueLocations.dart';

class AddEditDeliveryRate extends StatefulWidget {
  final String sellerId;
  final Map<String, dynamic>? rateItem;
  final Function(Map<String, dynamic> data) onSave;

  const AddEditDeliveryRate({
    super.key,
    required this.sellerId,
    this.rateItem,
    required this.onSave,
  });

  @override
  State<AddEditDeliveryRate> createState() => _AddEditDeliveryRateState();
}

class _AddEditDeliveryRateState extends State<AddEditDeliveryRate> {
  final _streetController = TextEditingController();
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final Color _primaryDark = const Color(0xFF0F172A);
  final Color _primaryBlue = const Color(0xFF2563EB);
  final Color _textSecondary = const Color(0xFF64748B);
  final Color _border = const Color(0xFFE2E8F0);

  String? _province;
  String? _municipality;
  String? _barangay;

  @override
  void initState() {
    super.initState();
    final item = widget.rateItem;
    if (item != null) {
      _province = item['rate_province']?.toString();
      _municipality = item['rate_municipality']?.toString();
      _barangay = item['rate_barangay']?.toString();
      _streetController.text = item['rate_street']?.toString() ?? '';
      _amountController.text = item['rate_amount']?.toString() ?? '';
    }
    _province ??= MarinduqueLocations.provinces.first;
  }

  @override
  void dispose() {
    _streetController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {String? hint, String? prefix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefix,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _primaryBlue, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  String _composeLabel() {
    final parts = [
      _streetController.text.trim(),
      _barangay,
      _municipality,
      _province,
    ].where((e) => e != null && e.toString().trim().isNotEmpty).toList();
    return parts.join(', ');
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSave({
      'rate_label': _composeLabel(),
      'rate_province': _province,
      'rate_municipality': _municipality,
      'rate_barangay': _barangay,
      'rate_street': _streetController.text.trim(),
      'rate_amount': double.parse(_amountController.text.trim()),
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.rateItem != null;
    final municipalities = MarinduqueLocations.municipalities[_province] ?? [];
    final barangays = MarinduqueLocations.barangays[_municipality] ?? [];
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screen = MediaQuery.of(context).size;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 640,
              maxHeight: screen.height * 0.92,
            ),
            child: Material(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: _border,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: _primaryBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.local_shipping_rounded,
                                color: _primaryBlue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isEditing
                                        ? "Edit Delivery Rate"
                                        : "Add Delivery Rate",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: _primaryDark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Set the location and fee buyers will pay for delivery.",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded),
                              tooltip: "Close",
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.all(22),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              key: ValueKey('province-$_province'),
                              initialValue: _province,
                              isExpanded: true,
                              decoration: _dec("Province"),
                              items: MarinduqueLocations.provinces
                                  .map(
                                    (p) => DropdownMenuItem(
                                      value: p,
                                      child: Text(
                                        p,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) => setState(() {
                                _province = val;
                                _municipality = null;
                                _barangay = null;
                              }),
                              validator: (v) =>
                                  v == null ? "Select province" : null,
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              key: ValueKey(
                                'municipality-$_province-$_municipality',
                              ),
                              initialValue:
                                  municipalities.contains(_municipality)
                                  ? _municipality
                                  : null,
                              isExpanded: true,
                              decoration: _dec("Municipality"),
                              items: municipalities
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(
                                        m,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: municipalities.isEmpty
                                  ? null
                                  : (val) => setState(() {
                                      _municipality = val;
                                      _barangay = null;
                                    }),
                              validator: (v) =>
                                  v == null ? "Select municipality" : null,
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              key: ValueKey(
                                'barangay-$_municipality-$_barangay',
                              ),
                              initialValue: barangays.contains(_barangay)
                                  ? _barangay
                                  : null,
                              isExpanded: true,
                              decoration: _dec("Barangay"),
                              items: barangays
                                  .map(
                                    (b) => DropdownMenuItem(
                                      value: b,
                                      child: Text(
                                        b,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: barangays.isEmpty
                                  ? null
                                  : (val) => setState(() => _barangay = val),
                              validator: (v) =>
                                  v == null ? "Select barangay" : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _streetController,
                              textInputAction: TextInputAction.next,
                              decoration: _dec(
                                "Street / Purok",
                                hint: "Optional, e.g. Purok 3",
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _amountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textInputAction: TextInputAction.done,
                              decoration: _dec(
                                "Delivery Amount",
                                hint: "e.g. 50.00",
                                prefix: "₱ ",
                              ),
                              validator: (v) {
                                final amount = double.tryParse(v?.trim() ?? '');
                                if (amount == null || amount < 0) {
                                  return "Enter a valid amount";
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _save(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: _border)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _save,
                        icon: Icon(
                          isEditing ? Icons.check_rounded : Icons.add_rounded,
                        ),
                        label: Text(
                          isEditing ? "Update Rate" : "Save Rate",
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
