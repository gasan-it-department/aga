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

  String? _province;
  String? _municipality;
  String? _barangay;

  @override
  void initState() {
    super.initState();
    if (widget.rateItem != null) {
      _province = widget.rateItem!['rate_province'];
      _municipality = widget.rateItem!['rate_municipality'];
      _barangay = widget.rateItem!['rate_barangay'];
      _streetController.text = widget.rateItem!['rate_street'] ?? '';
      _amountController.text = (widget.rateItem!['rate_amount'] as num).toString();
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.rateItem != null;
    final List<String> municipalities = MarinduqueLocations.municipalities[_province] ?? [];
    final List<String> barangays = MarinduqueLocations.barangays[_municipality] ?? [];

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: SizedBox(
                  width: 40,
                  height: 4,
                  child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFFE2E8F0), borderRadius: BorderRadius.all(Radius.circular(2)))),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isEditing ? "Edit Delivery Rate" : "Add Delivery Rate",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _province,
                isExpanded: true,
                decoration: _dec("Province"),
                items: MarinduqueLocations.provinces
                    .map((p) => DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (val) => setState(() {
                  _province = val;
                  _municipality = null;
                  _barangay = null;
                }),
                validator: (v) => v == null ? "Required" : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _municipality,
                isExpanded: true,
                decoration: _dec("Municipality"),
                items: municipalities
                    .map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (val) => setState(() {
                  _municipality = val;
                  _barangay = null;
                }),
                validator: (v) => v == null ? "Required" : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _barangay,
                isExpanded: true,
                decoration: _dec("Barangay"),
                items: barangays
                    .map((b) => DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (val) => setState(() => _barangay = val),
                validator: (v) => v == null ? "Required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _streetController,
                decoration: _dec("Street / Purok (Optional)", hint: "e.g. Purok 3"),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: _dec("Delivery Amount (PHP)", hint: "e.g. 50.00", prefix: "₱ "),
                validator: (v) => v == null || v.isEmpty || double.tryParse(v) == null ? "Enter a valid amount" : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      widget.onSave({
                        'rate_label': _composeLabel(),
                        'rate_province': _province,
                        'rate_municipality': _municipality,
                        'rate_barangay': _barangay,
                        'rate_street': _streetController.text.trim(),
                        'rate_amount': double.parse(_amountController.text),
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: Text(isEditing ? "Update Rate" : "Save Rate", style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
