import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:gasan_port_tracker/Map/MapLocationPicker.dart';
import 'package:gasan_port_tracker/FloatingMessages/SnackbarMessenger.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';

class UserDeliveryAddress extends StatefulWidget {
  final Map<String, dynamic>? initialAddress;
  const UserDeliveryAddress({super.key, this.initialAddress});

  @override
  State<UserDeliveryAddress> createState() => _UserDeliveryAddressState();
}

class _UserDeliveryAddressState extends State<UserDeliveryAddress> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _firstNameCtrl = TextEditingController();
  final TextEditingController _middleNameCtrl = TextEditingController();
  final TextEditingController _lastNameCtrl = TextEditingController();
  final TextEditingController _contactCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _streetCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryColor = const Color(0xFF0A2E5C);
  final Color accentColor = const Color(0xFF3B82F6);
  final Color outlineColor = const Color(0xFFE2E8F0);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);

  final List<String> _provinces = const ["Marinduque"];
  final Map<String, List<String>> _municipalities = const {
    "Marinduque": ["Boac", "Mogpog", "Santa Cruz", "Torrijos", "Buenavista", "Gasan"],
  };
  final Map<String, List<String>> _barangays = const {
    "Boac": [
      "Agot", "Agumaymayan", "Amoingon", "Apitong", "Balagasan", "Balaring",
      "Balimbing", "Balogo", "Bamban", "Bangbangalon", "Bantad", "Bantay",
      "Bayuti", "Binunga", "Boi", "Boton", "Buliasnin", "Bunganay",
      "Caganhao", "Canat", "Catubugan", "Cawit", "Daig", "Daypay", "Duyay",
      "Hinapulan", "Ihatub", "Isok I (Poblacion)", "Isok II Poblacion",
      "Laylay", "Lupac", "Mahinhin", "Mainit", "Malbog", "Maligaya",
      "Malusak (Poblacion)", "Mansiwat", "Mataas na Bayan (Poblacion)",
      "Maybo", "Mercado (Poblacion)", "Murallon (Poblacion)", "Ogbac",
      "Pawa", "Pili", "Poctoy", "Poras", "Puting Buhangin", "Puyog",
      "Sabong", "San Miguel (Poblacion)", "Santol", "Sawi", "Tabi",
      "Tabigue", "Tagwak", "Tambunan", "Tampus (Poblacion)", "Tanza",
      "Tugos", "Tumagabok", "Tumapon"
    ],
    "Buenavista": [
      "Bagacay", "Bagtingon", "Barangay I (Poblacion)",
      "Barangay II (Poblacion)", "Barangay III (Poblacion)",
      "Barangay IV (Poblacion)", "Bicas-Bicas", "Caigangan", "Daykitin",
      "Libas", "Malbog", "Sihi", "Timbo", "Tungib-Lipata", "Yook"
    ],
    "Gasan": [
      "Antipolo", "Bachao Ibaba", "Bachao Ilaya", "Bacongbacong", "Bahi",
      "Bangbang", "Banot", "Banuyo", "Barangay I (Poblacion)",
      "Barangay II (Poblacion)", "Barangay III (Poblacion)", "Bognuyan",
      "Cabugao", "Dawis", "Dili", "Libtangin", "Mahunig", "Mangiliol",
      "Masiga", "Matandang Gasan", "Pangi", "Pingan", "Tabionan",
      "Tapuyan", "Tiguion"
    ],
    "Mogpog": [
      "Anapog-Sibucao", "Argao", "Balanacan", "Banto", "Bintakay", "Bocboc",
      "Butansapa", "Candahon", "Capayang", "Danao", "Dulong Bayan (Poblacion)",
      "Gitnang Bayan (Poblacion)", "Guisian", "Hinadharan", "Hinanggayon",
      "Ino", "Janagdong", "Lamesa", "Laon", "Magapua", "Malayak", "Malusak",
      "Mampaitan", "Mangyan-Mababad", "Market Site (Poblacion)",
      "Mataas na Bayan", "Mendez", "Nangka I", "Nangka II", "Paye", "Pili",
      "Puting Buhangin", "Sayao", "Silangan", "Sumangga", "Tarug",
      "Villa Mendez (Poblacion)"
    ],
    "Santa Cruz": [
      "Alobo", "Angas", "Aturan", "Bagong Silang (Poblacion)", "Baguidbirin",
      "Baliis", "Balogo", "Banahaw (Poblacion)", "Bangcuangan", "Banogbog",
      "Biga", "Botilao", "Buyabod", "Dating Bayan", "Devilla", "Dolores",
      "Haguimit", "Hupi", "Ipil", "Jolo", "Kaganhao", "Kalangkang",
      "Kamandugan", "Kasily", "Kilo-Kilo", "Kiñaman", "Labo", "Lamesa",
      "Landy", "Lapu-Lapu", "Libjo", "Lipa", "Lusok", "Maharlika (Poblacion)",
      "Makina", "Maniwaya", "Manlibunan", "Masaguisi", "Masalukot",
      "Matalaba", "Mongpong", "Morales", "Napo", "Pag-Asa (Poblacion)",
      "Pantayin", "Polo", "Pulong-Parang", "Punong", "San Antonio",
      "San Isidro", "Tagum", "Tamayo", "Tambangan", "Tawiran", "Taytay"
    ],
    "Torrijos": [
      "Bangwayin", "Bayakbakin", "Bolo", "Bonliw", "Buangan", "Cabuyo",
      "Cagpo", "Dampulan", "Kay Duke", "Mabuhay", "Makawayan", "Malibago",
      "Malinao", "Marlangga", "Matuyatuya", "Nangka", "Pakaskasan",
      "Payanas", "Poblacion", "Poctoy", "Sibuyao", "Suha", "Talawan",
      "Tigwi"
    ],
  };

  String? _selectedProvince = "Marinduque";
  String? _selectedMunicipality;
  String? _selectedBarangay;
  Map<String, dynamic>? _coordinates;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final addr = widget.initialAddress;
    if (addr != null) {
      _firstNameCtrl.text = (addr['first_name'] ?? '').toString();
      _middleNameCtrl.text = (addr['middle_name'] ?? '').toString();
      _lastNameCtrl.text = (addr['last_name'] ?? '').toString();
      _contactCtrl.text = (addr['contact_number'] ?? '').toString();
      _emailCtrl.text = (addr['email'] ?? '').toString();
      _streetCtrl.text = (addr['street'] ?? '').toString();
      _notesCtrl.text = (addr['notes'] ?? '').toString();
      _selectedProvince = addr['province']?.toString() ?? _selectedProvince;
      _selectedMunicipality = addr['municipality']?.toString();
      _selectedBarangay = addr['barangay']?.toString();
      final coords = addr['coordinates'];
      if (coords is Map) {
        final lat = (coords['latitude'] as num?)?.toDouble();
        final lng = (coords['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          _coordinates = {'latitude': lat, 'longitude': lng};
        }
      }
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _contactCtrl.dispose();
    _emailCtrl.dispose();
    _streetCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final lat = (_coordinates?['latitude'] as num?)?.toDouble();
    final lng = (_coordinates?['longitude'] as num?)?.toDouble();
    final picked = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapLocationPicker(
          initialLocation: (lat != null && lng != null) ? LatLng(lat, lng) : null,
        ),
      ),
    );
    if (picked is LatLng) {
      setState(() {
        _coordinates = {'latitude': picked.latitude, 'longitude': picked.longitude};
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMunicipality == null || _selectedBarangay == null) {
      SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Please select Municipality and Barangay.");
      return;
    }
    if (_coordinates == null) {
      SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Please pin your location on the map.");
      return;
    }
    setState(() => _isSaving = true);
    final payload = {
      'id': widget.initialAddress?['id'] ?? 'ADDR_${DateTime.now().microsecondsSinceEpoch}',
      'first_name': _firstNameCtrl.text.trim(),
      'middle_name': _middleNameCtrl.text.trim(),
      'last_name': _lastNameCtrl.text.trim(),
      'contact_number': _contactCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'province': _selectedProvince,
      'municipality': _selectedMunicipality,
      'barangay': _selectedBarangay,
      'street': _streetCtrl.text.trim(),
      'coordinates': _coordinates,
      'notes': _notesCtrl.text.trim(),
      'is_default': widget.initialAddress?['is_default'] == true,
    };
    Navigator.pop(context, payload);
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: textSecondary, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: outlineColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: outlineColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor, width: 1.5)),
      );

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
        child: Text(title, style: TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
      );

  @override
  Widget build(BuildContext context) {
    final bool hasCoords = _coordinates != null;
    final bool isEditing = widget.initialAddress != null;
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0,
        title: Text(isEditing ? "Edit Delivery Address" : "Add Delivery Address",
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Utility().getMaxScreenSize()),
          child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _section("RECIPIENT"),
                  TextFormField(
                    controller: _firstNameCtrl,
                    decoration: _dec("First Name", Icons.person_outline_rounded),
                    validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _middleNameCtrl,
                    decoration: _dec("Middle Name (Optional)", Icons.person_outline_rounded),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _lastNameCtrl,
                    decoration: _dec("Last Name", Icons.person_outline_rounded),
                    validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contactCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: _dec("Contact Number", Icons.call_rounded),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return "Required";
                      final digits = t.replaceAll(RegExp(r'\D'), '');
                      if (digits.length < 10) return "Enter a valid contact number";
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _dec("Gmail (Optional)", Icons.alternate_email_rounded),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return null;
                      final ok = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+').hasMatch(t);
                      return ok ? null : "Enter a valid email";
                    },
                  ),
                  const SizedBox(height: 16),
                  _section("ADDRESS"),
                  DropdownButtonFormField<String>(
                    value: _selectedProvince,
                    decoration: _dec("Province", Icons.map_outlined),
                    items: _provinces.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (v) => setState(() {
                      _selectedProvince = v;
                      _selectedMunicipality = null;
                      _selectedBarangay = null;
                    }),
                    validator: (v) => v == null ? "Required" : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedMunicipality,
                    decoration: _dec("Municipality", Icons.location_city_outlined),
                    items: (_municipalities[_selectedProvince] ?? [])
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _selectedMunicipality = v;
                      _selectedBarangay = null;
                    }),
                    validator: (v) => v == null ? "Required" : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedBarangay,
                    decoration: _dec("Barangay", Icons.home_outlined),
                    items: (_barangays[_selectedMunicipality] ?? [])
                        .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedBarangay = v),
                    validator: (v) => v == null ? "Required" : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _streetCtrl,
                    decoration: _dec("Street / Purok (Optional)", Icons.streetview_outlined),
                  ),
                  const SizedBox(height: 16),
                  _section("PIN LOCATION (REQUIRED)"),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: hasCoords ? accentColor.withValues(alpha: 0.5) : outlineColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(hasCoords ? Icons.check_circle_rounded : Icons.location_off_rounded,
                              color: hasCoords ? const Color(0xFF10B981) : textSecondary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              hasCoords
                                  ? "Lat: ${(_coordinates!['latitude'] as num).toStringAsFixed(5)}, Lng: ${(_coordinates!['longitude'] as num).toStringAsFixed(5)}"
                                  : "No coordinates pinned yet.",
                              style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _pickLocation,
                            icon: Icon(Icons.pin_drop_rounded, color: accentColor, size: 18),
                            label: Text(hasCoords ? "Change Location" : "Pin Location on Map",
                                style: TextStyle(color: accentColor, fontWeight: FontWeight.w800)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: accentColor.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _section("NOTES"),
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    decoration: _dec("Notes (Optional)", Icons.notes_rounded),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isSaving ? null : _save,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text("Save Address", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
        ),
      ),
    );
  }
}
