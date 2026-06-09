import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/FloatingMessages/SnackbarMessenger.dart';
import '../../Map/MapLocationPicker.dart';
import '../ClassicDialog.dart';

class CreateEmergencyResponseTicket {
  static void show(BuildContext context) {
    try {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const _TicketBottomSheet(),
      );
    } catch (e) {
      Utility().printLog("Failed to show BottomSheet: $e");
    }
  }
}

class _TicketBottomSheet extends StatefulWidget {
  const _TicketBottomSheet();

  @override
  State<_TicketBottomSheet> createState() => _TicketBottomSheetState();
}

class _TicketBottomSheetState extends State<_TicketBottomSheet> {
  final _supabase = Supabase.instance.client;
  final Color primaryDark = const Color(0xFF0A2E5C);
  final Color backgroundLight = const Color(0xFFF8FAFC);
  final Color cardBorder = const Color(0xFFE2E8F0);
  final Color textSecondary = const Color(0xFF64748B);
  final Color warningRed = const Color(0xFFDC2626);
  final Color successGreen = const Color(0xFF10B981);
  final _classicDialog = ClassicDialog();

  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();
  List<XFile> _pickedImages = [];

  String _selectedCategory = 'Medical Assistance';
  bool _isSubmitting = false;
  LatLng? _pickedCoordinates;

  final LatLng _defaultCenter = const LatLng(13.3941, 121.9564);

  final List<String> _categories = [
    'Medical Assistance',
    'Fire / Explosion',
    'Crime / Security',
    'Traffic Accident',
    'Search & Rescue',
    'General Assistance'
  ];

  @override
  void dispose() {
    try {
      _locationController.dispose();
      _descController.dispose();
      _contactController.dispose();
    } catch (e) {
      Utility().printLog("Dispose Error: $e");
    }
    super.dispose();
  }

  // --- BULLETPROOF ERROR DIALOG ---
  void _showErrorDialog(String title, String message) {
    try {
      if (!mounted) return;
      _classicDialog.setTitle(title);
      _classicDialog.setMessage(message);
      _classicDialog.setCancelable(false);
      _classicDialog.setPositiveMessage("Close");
      _classicDialog.showOnButtonDialog(context, () {
        try {
          _classicDialog.dismissDialog();
        } catch (e) {
          Navigator.pop(context);
        }
      });
    } catch (e) {
      Utility().printLog("ClassicDialog Failed. Using Fallback. Error: $e");
      // Fallback if ClassicDialog crashes
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.error_outline_rounded, color: warningRed),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: TextStyle(color: primaryDark, fontWeight: FontWeight.bold, fontSize: 18))),
              ],
            ),
            content: Text(message, style: TextStyle(color: primaryDark, fontSize: 14)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    }
  }

  // --- IMAGE PICKER LOGIC ---
  Future<void> _pickImages() async {
    try {
      if (_pickedImages.length >= 3) {
        _showErrorDialog("Limit Reached", "You can only attach up to 3 images.");
        return;
      }

      final List<XFile> selected = await _imagePicker.pickMultiImage();
      if (selected.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _pickedImages.addAll(selected);
          // Enforce max 3 limit
          if (_pickedImages.length > 3) {
            _pickedImages = _pickedImages.sublist(0, 3);
            SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Only the first 3 images were added.");
          }
        });
      }
    } catch (e) {
      Utility().printLog("Image Picker Error: $e");
      _showErrorDialog("Image Selection Failed", "Could not select images. Details: $e");
    }
  }

  void _removeImage(int index) {
    try {
      if (!mounted) return;
      setState(() {
        _pickedImages.removeAt(index);
      });
    } catch (e) {
      Utility().printLog("Image Removal Error: $e");
      _showErrorDialog("Error", "Could not remove image. Details: $e");
    }
  }

  // --- SUBMISSION LOGIC ---
  Future<void> _submitTicket() async {
    try {
      if (_locationController.text.trim().isEmpty ||
          _descController.text.trim().isEmpty ||
          _contactController.text.trim().isEmpty) {
        _showErrorDialog("Missing Information", "Please fill in all required fields (Location, Description, and Contact).");
        return;
      }

      if (!mounted) return;
      setState(() => _isSubmitting = true);

      Map<String, dynamic> coordinatesToSave;

      // 1. Get Coordinates
      try {
        if (_pickedCoordinates != null) {
          coordinatesToSave = {
            "latitude": _pickedCoordinates!.latitude,
            "longitude": _pickedCoordinates!.longitude
          };
        } else {
          bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (!serviceEnabled) {
            throw Exception("Location services are disabled. Please turn on GPS or pick a location on the map.");
          }

          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
            if (permission == LocationPermission.denied) {
              throw Exception("Location permissions are denied.");
            }
          }

          if (permission == LocationPermission.deniedForever) {
            throw Exception("Location permissions are permanently denied. Enable them in Settings.");
          }

          Position position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 15),
            ),
          );

          coordinatesToSave = {
            "latitude": position.latitude,
            "longitude": position.longitude
          };
        }
      } catch (gpsError) {
        throw Exception("GPS Error: $gpsError");
      }

      // 2. Upload Images to Supabase Storage (if any)
      List<String> uploadedImageUrls = [];
      try {
        if (_pickedImages.isNotEmpty) {
          for (var image in _pickedImages) {
            final bytes = await image.readAsBytes();
            final fileExt = image.name.split('.').last;
            final fileName = '${Utility().generateUniqueID()}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
            final filePath = 'tickets/$fileName';

            await _supabase.storage.from('incident_images').uploadBinary(
              filePath,
              bytes,
            );

            final publicUrl = _supabase.storage.from('incident_images').getPublicUrl(filePath);
            uploadedImageUrls.add(publicUrl);
          }
        }
      } catch (uploadError) {
        throw Exception("Image Upload Failed. Ensure 'incident_images' bucket exists and is public. Details: $uploadError");
      }

      // 3. Save to Database
      final Map<String, dynamic> ticketData = {
        'ticket_id': Utility().generateUniqueID(),
        'ticket_incidents_type': _selectedCategory,
        'ticket_incidents_location': _locationController.text.trim(),
        'ticket_incidents_coordinates': jsonEncode(coordinatesToSave),
        'ticket_incidents_description': _descController.text.trim(),
        'ticket_incidents_contact_number': _contactController.text.trim(),
        'ticket_date_created': Utility().getCurrentMSEpochTime(),
        'ticket_status': 'pending',
        'ticket_images': uploadedImageUrls.isEmpty ? null : jsonEncode(uploadedImageUrls),
      };

      final response = await _supabase
          .from('incidents_reports')
          .insert(ticketData)
          .select();

      Utility().printLog("Ticket inserted successfully: $response");

      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.pop(context);
        SnackbarMessenger().showSnackbar(context, SnackbarMessenger.success, "Response Ticket Submitted Successfully!");
      }

    } on PostgrestException catch (dbError) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        Utility().printLog("Supabase DB Error: ${dbError.message}");
        _showErrorDialog("Database Error", "Failed to save the ticket to the database.\n\nDetails: ${dbError.message}");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        Utility().printLog("General Error: $e");
        String errorMsg = e.toString().replaceAll("Exception: ", "");
        _showErrorDialog("Submission Failed", errorMsg);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 40),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: cardBorder,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "New Response Ticket",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: primaryDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Material(
                      color: backgroundLight,
                      shape: const CircleBorder(),
                      child: IconButton(
                        icon: Icon(Icons.close_rounded, color: textSecondary, size: 20),
                        onPressed: () {
                          try {
                            Navigator.pop(context);
                          } catch (e) {
                            Utility().printLog("Close Error: $e");
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: warningRed.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: warningRed.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, color: warningRed, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "For immediate, life-threatening emergencies, please close this form and use the SOS Button on the main screen.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: warningRed.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      _buildInputLabel("Incident Category"),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: textSecondary),
                        decoration: _inputDecoration(Icons.category_rounded),
                        style: TextStyle(fontSize: 15, color: primaryDark, fontWeight: FontWeight.w600),
                        items: _categories.map((cat) {
                          return DropdownMenuItem(value: cat, child: Text(cat));
                        }).toList(),
                        onChanged: (val) {
                          try {
                            setState(() => _selectedCategory = val!);
                          } catch (e) {
                            Utility().printLog("Dropdown Error: $e");
                          }
                        },
                      ),

                      const SizedBox(height: 20),

                      _buildInputLabel("Exact Location / Landmark"),
                      TextFormField(
                        controller: _locationController,
                        style: TextStyle(fontSize: 15, color: primaryDark, fontWeight: FontWeight.w500),
                        decoration: _inputDecoration(Icons.pin_drop_rounded, hint: "Where is help needed?"),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final LatLng? result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MapLocationPicker(
                                    initialLocation: _pickedCoordinates ?? _defaultCenter,
                                  ),
                                ),
                              );

                              if (result != null && mounted) {
                                setState(() {
                                  _pickedCoordinates = result;
                                });
                              }
                            } catch (e) {
                              _showErrorDialog("Map Error", "Could not open map. Details: $e");
                            }
                          },
                          icon: Icon(
                              _pickedCoordinates != null ? Icons.check_circle_rounded : Icons.add_location_alt_rounded,
                              color: _pickedCoordinates != null ? successGreen : primaryDark,
                              size: 20
                          ),
                          label: Text(
                              _pickedCoordinates != null
                                  ? "Lat: ${_pickedCoordinates!.latitude.toStringAsFixed(4)}, Lon: ${_pickedCoordinates!.longitude.toStringAsFixed(4)}"
                                  : "Pick Coordinates on Map",
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _pickedCoordinates != null ? successGreen : primaryDark
                              )
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _pickedCoordinates != null ? successGreen.withValues(alpha: 0.1) : backgroundLight,
                            side: BorderSide(
                                color: _pickedCoordinates != null ? successGreen.withValues(alpha: 0.5) : cardBorder,
                                width: 1.5
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      _buildInputLabel("Incident Description"),
                      TextFormField(
                        controller: _descController,
                        maxLines: 4,
                        style: TextStyle(fontSize: 15, color: primaryDark, fontWeight: FontWeight.w500),
                        decoration: _inputDecoration(Icons.subject_rounded, hint: "Describe the situation briefly...").copyWith(
                          alignLabelWithHint: true,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // --- BEAUTIFIED IMAGES SECTION ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildInputLabel("Evidence Photos (Optional)"),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _pickedImages.length == 3 ? successGreen.withValues(alpha: 0.1) : backgroundLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${_pickedImages.length}/3",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _pickedImages.length == 3 ? successGreen : textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: backgroundLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder, width: 1.5),
                        ),
                        child: _pickedImages.isEmpty
                        // EMPTY STATE
                            ? GestureDetector(
                          onTap: () {
                            try {
                              _pickImages();
                            } catch(e) {
                              _showErrorDialog("Tap Error", "Failed to trigger image picker: $e");
                            }
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: primaryDark.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
                                  ],
                                ),
                                child: Icon(Icons.add_a_photo_rounded, size: 32, color: primaryDark),
                              ),
                              const SizedBox(height: 12),
                              Text("Tap to upload photos", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: primaryDark)),
                              const SizedBox(height: 4),
                              Text("JPEG or PNG, up to 3 images", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary)),
                            ],
                          ),
                        )
                        // IMAGES SELECTED STATE
                            : Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            ..._pickedImages.asMap().entries.map((entry) {
                              int idx = entry.key;
                              XFile file = entry.value;
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 90,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(color: primaryDark.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4))
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: kIsWeb
                                          ? Image.network(file.path, fit: BoxFit.cover)
                                          : Image.file(File(file.path), fit: BoxFit.cover),
                                    ),
                                  ),
                                  Positioned(
                                    right: -8,
                                    top: -8,
                                    child: GestureDetector(
                                      onTap: () {
                                        try {
                                          _removeImage(idx);
                                        } catch(e) {
                                          _showErrorDialog("Tap Error", "Failed to remove image: $e");
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4)
                                          ],
                                        ),
                                        child: const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 24),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),

                            // ADD MORE BUTTON (Shows only if less than 3)
                            if (_pickedImages.length < 3)
                              GestureDetector(
                                onTap: () {
                                  try {
                                    _pickImages();
                                  } catch (e) {
                                    _showErrorDialog("Tap Error", "Failed to trigger image picker: $e");
                                  }
                                },
                                child: Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: cardBorder, width: 2),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_rounded, color: textSecondary, size: 28),
                                      const SizedBox(height: 4),
                                      Text("Add More", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textSecondary)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      _buildInputLabel("Your Contact Number"),
                      TextFormField(
                        controller: _contactController,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(fontSize: 15, color: primaryDark, fontWeight: FontWeight.w500),
                        decoration: _inputDecoration(Icons.phone_rounded, hint: "e.g., 0912 345 6789"),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: cardBorder)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _isSubmitting ? null : () {
                      try {
                        _submitTicket();
                      } catch (e) {
                        _showErrorDialog("Submit Error", "A critical error occurred: $e");
                      }
                    },
                    child: _isSubmitting
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                        : const Text(
                      "SUBMIT TICKET",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildInputLabel(String label) {
    try {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: primaryDark),
        ),
      );
    } catch (e) {
      return const SizedBox();
    }
  }

  InputDecoration _inputDecoration(IconData icon, {String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6)),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Icon(icon, size: 20, color: textSecondary),
      ),
      filled: true,
      fillColor: backgroundLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: cardBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: cardBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primaryDark, width: 1.5)),
    );
  }
}
