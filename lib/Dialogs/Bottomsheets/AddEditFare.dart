import 'package:flutter/material.dart';

class AddEditFare extends StatefulWidget {
  final Map<String, dynamic>? fare;

  const AddEditFare({super.key, this.fare});

  static Future<Map<String, String>?> show(BuildContext context, {Map<String, dynamic>? fare}) async {
    return await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AddEditFare(fare: fare),
    );
  }

  @override
  State<AddEditFare> createState() => _AddEditFareDialogState();
}

class _AddEditFareDialogState extends State<AddEditFare> {
  // Predefined Categories for Gasan Port
  final List<String> _categories = [
    'Adult / Regular',
    'Student',
    'Half Fare',
    'Senior Citizen / PWD',
    'Child',
    'Motorcycle (2-Wheel)',
    'Car / SUV (4-Wheel)',
    'Truck (6-Wheel)',
    'Truck (10-Wheel)',
    'Bicycle',
  ];

  String? _selectedCategory;
  final TextEditingController _priceController = TextEditingController();

  final Color primaryColor = const Color(0xFF0A2E5C);
  final Color outlineColor = const Color(0xFFCBD5E1);
  final Color textPrimary = const Color(0xFF0F172A);

  bool get isEditMode => widget.fare != null;

  @override
  void initState() {
    super.initState();
    if (isEditMode) {
      _priceController.text = widget.fare!['price'] ?? '';

      // Check if existing category is in our list, otherwise add it temporarily
      String category = widget.fare!['type'] ?? '';
      if (_categories.contains(category)) {
        _selectedCategory = category;
      } else if (category.isNotEmpty) {
        _categories.add(category);
        _selectedCategory = category;
      }
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: outlineColor, width: 1),
      ),
      backgroundColor: Colors.white,
      title: Text(
        isEditMode ? "Edit Fare Item" : "Add Fare Item",
        style: TextStyle(fontWeight: FontWeight.w800, color: textPrimary, fontSize: 20),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- DROPDOWN FOR CATEGORY ---
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            decoration: InputDecoration(
              labelText: "Fare Category",
              prefixIcon: Icon(Icons.person_outline, size: 20, color: primaryColor),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: outlineColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: primaryColor, width: 1.5),
              ),
            ),
            items: _categories.map((String category) {
              return DropdownMenuItem(
                value: category,
                child: Text(category, style: TextStyle(color: textPrimary)),
              );
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                _selectedCategory = newValue;
              });
            },
          ),
          const SizedBox(height: 16),

          // --- PRICE FIELD ---
          _buildField(
            controller: _priceController,
            label: "Price (PHP)",
            hint: "0.00",
            icon: Icons.payments_outlined,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixText: "₱ ",
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CANCEL", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            final String price = _priceController.text.trim();

            if (_selectedCategory != null && price.isNotEmpty) {
              Navigator.pop(context, {
                'type': _selectedCategory!,
                'price': price,
              });
            }
          },
          child: Text(
            isEditMode ? "UPDATE FARE" : "ADD FARE",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? prefixText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        prefixIcon: Icon(icon, size: 20, color: primaryColor),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: outlineColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
    );
  }
}
