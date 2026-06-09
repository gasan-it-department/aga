import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'dart:io';
import '../../../Dialogs/ClassicDialog.dart';
import '../../../Dialogs/LoadingDialog.dart';
import '../../../FloatingMessages/SnackbarMessenger.dart';
import '../../../Map/MapLocationPicker.dart';
import '../../../Utility/Utility.dart';

class AddEditTouristSpots extends StatefulWidget {
  final Map<String, dynamic>? existingSpot;
  final int municipalZipCode;

  const AddEditTouristSpots({super.key, this.existingSpot, required this.municipalZipCode});

  @override
  State<AddEditTouristSpots> createState() => _AddEditTouristSpotsState();
}

class _AddEditTouristSpotsState extends State<AddEditTouristSpots> {
  final _supabase = Supabase.instance.client;
  final _classicDialog = ClassicDialog();
  final _loadingDialog = LoadingDialog();
  final ImagePicker _picker = ImagePicker();
  final String _supabaseBucketName = 'spot_images';

  final Color primaryDark = const Color(0xFF0F172A);
  final Color gasanEmerald = const Color(0xFF059669);
  final Color backgroundLight = const Color(0xFFF8FAFC);
  final Color surfaceWhite = const Color(0xFFFFFFFF);
  final Color borderSubtle = const Color(0xFFE2E8F0);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textMuted = const Color(0xFF64748B);
  final Color dangerRed = const Color(0xFFEF4444);

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _latController;
  late TextEditingController _lngController;
  late TextEditingController _videoController;

  String _selectedType = 'Beach';
  bool _isOpen = true;
  bool _allowReviews = true;

  // Media Management
  String? _featureImageUrl;
  XFile? _featureImageFile;
  final List<dynamic> _galleryMedia = [];

  // TRACKING: Holds Supabase URLs of images the user removed during this session
  final List<String> _imagesToDeleteFromStorage = [];

  @override
  void initState() {
    super.initState();
    final isEditing = widget.existingSpot != null;
    final spot = widget.existingSpot;

    _nameController = TextEditingController(text: isEditing ? spot!['spot_label'] ?? spot['sport_label'] : '');
    _descController = TextEditingController(text: isEditing ? spot!['spot_description'] ?? spot['sport_description'] : '');

    // Parse Coordinates
    String lat = '';
    String lng = '';
    if (isEditing && spot!['spot_coordinates'] != null) {
      try {
        final coords = spot['spot_coordinates'] is String ? jsonDecode(spot['spot_coordinates']) : spot['spot_coordinates'];
        lat = coords['latitude']?.toString() ?? '';
        lng = coords['longitude']?.toString() ?? '';
      } catch (e) {
        debugPrint("Failed to parse coords: $e");
      }
    }
    _latController = TextEditingController(text: lat);
    _lngController = TextEditingController(text: lng);

    // Parse YouTube Video
    String videoLink = '';
    if (isEditing && spot!['spot_videos'] != null) {
      try {
        final videos = spot['spot_videos'] is String ? jsonDecode(spot['spot_videos']) : spot['spot_videos'];
        if (videos is List && videos.isNotEmpty) {
          videoLink = videos.first.toString();
        } else if (videos is String) {
          videoLink = videos;
        }
      } catch (e) {
        debugPrint("Failed to parse video: $e");
      }
    }
    _videoController = TextEditingController(text: videoLink);

    if (isEditing) {
      _isOpen = spot!['spot_status'] == 'opened';
      _allowReviews = spot['spot_allow_reviews'] ?? true;

      // Parse Images
      if (spot['spot_images'] != null) {
        try {
          final images = spot['spot_images'] is String ? jsonDecode(spot['spot_images']) : spot['spot_images'];
          List<String> imgList = List<String>.from(images);
          if (imgList.isNotEmpty) {
            _featureImageUrl = imgList.first;
            if (imgList.length > 1) {
              _galleryMedia.addAll(imgList.sublist(1));
            }
          }
        } catch (e) {
          debugPrint("Failed to parse images: $e");
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _videoController.dispose();
    super.dispose();
  }

  // --- IMAGE PICKER LOGIC ---

  Future<void> _pickFeatureImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (pickedFile != null) {
        setState(() {
          // If overwriting an existing Supabase URL, queue it for deletion
          if (_featureImageUrl != null) {
            _imagesToDeleteFromStorage.add(_featureImageUrl!);
          }
          _featureImageFile = pickedFile;
          _featureImageUrl = null;
        });
      }
    } catch (e) {
      if(mounted) SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Failed to pick image.");
    }
  }

  Future<void> _pickGalleryImages() async {
    if (_galleryMedia.length >= 4) {
      SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Maximum of 4 sub-images allowed.");
      return;
    }

    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(imageQuality: 80);
      if (pickedFiles.isNotEmpty) {
        int availableSlots = 4 - _galleryMedia.length;
        setState(() {
          for (int i = 0; i < pickedFiles.length && i < availableSlots; i++) {
            _galleryMedia.add(pickedFiles[i]);
          }
        });
      }
    } catch (e) {
      if(mounted) SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Failed to pick images.");
    }
  }

  void _removeGalleryImage(int index) {
    setState(() {
      final removedItem = _galleryMedia.removeAt(index);
      // If the removed item is a String, it means it's an existing URL from Supabase
      if (removedItem is String) {
        _imagesToDeleteFromStorage.add(removedItem);
      }
    });
  }

  // --- STORAGE UPLOAD & CLEANUP HELPERS ---

  Future<String?> _uploadImageToSupabase(XFile imageFile) async {
    try {
      final fileExt = imageFile.name.split('.').last.toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${Utility().generateUniqueID()}.$fileExt';
      final filePath = fileName;

      final bytes = await imageFile.readAsBytes();

      await _supabase.storage.from(_supabaseBucketName).uploadBinary(filePath, bytes);
      return _supabase.storage.from(_supabaseBucketName).getPublicUrl(filePath);
    } catch (e) {
      debugPrint("Storage Upload Error: $e");
      return null;
    }
  }

  Future<void> _deleteOrphanedImages() async {
    if (_imagesToDeleteFromStorage.isEmpty) return;

    try {
      // Extract just the file name from the full public URL
      List<String> filePaths = _imagesToDeleteFromStorage.map((url) {
        // e.g., https://[project].supabase.co/storage/v1/object/public/spot_images/filename.jpg -> filename.jpg
        return url.split('/').last.split('?').first;
      }).toList();

      await _supabase.storage.from(_supabaseBucketName).remove(filePaths);
      debugPrint("Successfully cleaned up ${filePaths.length} orphaned images.");
    } catch (e) {
      debugPrint("Failed to delete orphaned images from storage: $e");
    }
  }

  // --- IMAGE RENDERING HELPER ---

  ImageProvider _getImageProvider(dynamic media) {
    if (media is String) {
      return NetworkImage(media);
    } else if (media is XFile) {
      if (kIsWeb) {
        return NetworkImage(media.path);
      } else {
        return FileImage(File(media.path));
      }
    }
    throw Exception("Unknown media type");
  }

  // --- SAVE LOGIC ---

  Future<void> _saveTouristSpot() async {
    if (_nameController.text.trim().isEmpty || _descController.text.trim().isEmpty) {
      _showError("Please fill in the Spot Name and Description.");
      return;
    }

    if (_featureImageFile == null && _featureImageUrl == null) {
      _showError("A Cover Image is required.");
      return;
    }
    if (_galleryMedia.isEmpty) {
      _showError("Please add at least 1 sub-image (Total minimum is 2).");
      return;
    }
    if (_galleryMedia.length > 4) {
      _showError("You can only have up to 4 sub-images (Total maximum is 5).");
      return;
    }

    if (_latController.text.trim().isEmpty || _lngController.text.trim().isEmpty) {
      _showError("Latitude and Longitude are required for the map.");
      return;
    }

    _loadingDialog.showLoadingDialog(context);

    try {
      // Upload Cover
      String finalCoverUrl = _featureImageUrl ?? '';
      if (_featureImageFile != null) {
        final uploadedUrl = await _uploadImageToSupabase(_featureImageFile!);
        if (uploadedUrl == null) throw Exception("Failed to upload Cover Image.");
        finalCoverUrl = uploadedUrl;
      }

      // Upload Gallery
      List<String> finalGalleryUrls = [];
      for (var media in _galleryMedia) {
        if (media is String) {
          finalGalleryUrls.add(media);
        } else if (media is XFile) {
          final uploadedUrl = await _uploadImageToSupabase(media);
          if (uploadedUrl == null) throw Exception("Failed to upload a sub-image.");
          finalGalleryUrls.add(uploadedUrl);
        }
      }

      final coordinates = {
        "latitude": double.tryParse(_latController.text.trim()) ?? 0.0,
        "longitude": double.tryParse(_lngController.text.trim()) ?? 0.0
      };

      final allImages = [finalCoverUrl, ...finalGalleryUrls];
      final List<String> videoList = _videoController.text.trim().isNotEmpty ? [_videoController.text.trim()] : [];

      final spotData = {
        'spot_label': _nameController.text.trim(),
        'spot_description': _descController.text.trim(),
        'spot_images': jsonEncode(allImages),
        'spot_videos': jsonEncode(videoList),
        'spot_coordinates': jsonEncode(coordinates),
        'spot_status': _isOpen ? 'opened' : 'closed',
        'spot_allow_reviews': _allowReviews,
      };

      if (widget.existingSpot == null) {
        spotData['spot_id'] = Utility().generateUniqueID();
        spotData['spot_date_added'] = Utility().getCurrentMSEpochTime();
        spotData["spot_municipality"] = widget.municipalZipCode;

        await _supabase.from('tourist_spots').insert(spotData);
        if (mounted) SnackbarMessenger().showSnackbar(context, SnackbarMessenger.success, "Tourist spot created successfully.");
      } else {
        await _supabase.from('tourist_spots').update(spotData).eq('spot_id', widget.existingSpot!['spot_id']);
        if (mounted) SnackbarMessenger().showSnackbar(context, SnackbarMessenger.success, "Tourist spot updated successfully.");
      }

      // If DB update was successful, delete the old orphaned images
      await _deleteOrphanedImages();

      if (mounted) {
        _loadingDialog.dismiss();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _loadingDialog.dismiss();
      _showError("Failed to save: $e");
    }
  }

  void _showError(String message) {
    _classicDialog.setTitle("Action Required");
    _classicDialog.setMessage(message);
    _classicDialog.setPositiveMessage("Understood");
    if (mounted) _classicDialog.showOnButtonDialog(context, () => _classicDialog.dismissDialog());
  }

  // --- UI BUILDER ---

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingSpot != null;

    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        title: Text(
            isEditing ? "Edit Destination" : "New Destination",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: textPrimary, letterSpacing: -0.5)
        ),
        backgroundColor: surfaceWhite,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: borderSubtle, height: 1.0),
        ),
      ),
      bottomNavigationBar: _buildPersistentBottomBar(isEditing),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Utility().getMaxScreenSize()),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionContainer(
                  title: "Destination Images",
                  subtitle: "Required: 1 Cover Image and 1 to 4 Sub Images (Total 2-5).",
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInputLabel("Cover Image (Required)"),
                      _buildFeatureImageDropzone(),
                      const SizedBox(height: 24),
                      _buildInputLabel("Sub Images (${_galleryMedia.length}/4)"),
                      _buildGalleryPicker(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionContainer(
                  title: "General Information",
                  subtitle: "Core details about this tourist spot.",
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInputLabel("Spot Name"),
                      _buildTextField(_nameController, "e.g., Gasan Butterfly Garden"),
                      const SizedBox(height: 20),
                      _buildInputLabel("Category"),
                      _buildTypeSelector(),
                      const SizedBox(height: 20),
                      _buildInputLabel("Description"),
                      _buildTextField(_descController, "Write a detailed description...", maxLines: 4),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionContainer(
                  title: "Promotional Video",
                  subtitle: "Optional. Link a YouTube video to showcase this spot.",
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInputLabel("YouTube Video Link"),
                      _buildTextField(
                        _videoController,
                        "https://www.youtube.com/watch?v=...",
                        icon: Icons.play_circle_fill_rounded,
                        iconColor: dangerRed,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionContainer(
                  title: "Location Coordinates",
                  subtitle: "Pinpoint the exact location for the public map.",
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputLabel("Latitude"),
                                _buildTextField(_latController, "13.xxx", isNumber: true, icon: Icons.pin_drop_rounded),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputLabel("Longitude"),
                                _buildTextField(_lngController, "121.xxx", isNumber: true, icon: Icons.pin_drop_rounded),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textPrimary,
                            backgroundColor: surfaceWhite,
                            side: BorderSide(color: borderSubtle, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            final currentLat = double.tryParse(_latController.text);
                            final currentLng = double.tryParse(_lngController.text);
                            final hasExistingLocation = currentLat != null && currentLng != null;

                            final pickedLocation = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MapLocationPicker(
                                  initialLocation: hasExistingLocation ? LatLng(currentLat, currentLng) : null,
                                ),
                              ),
                            );

                            if (pickedLocation != null) {
                              setState(() {
                                _latController.text = pickedLocation.latitude.toStringAsFixed(6);
                                _lngController.text = pickedLocation.longitude.toStringAsFixed(6);
                              });
                            }
                          },
                          icon: Icon(Icons.explore_rounded, color: gasanEmerald, size: 20),
                          label: const Text("Pick on Interactive Map", style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionContainer(
                  title: "Spot Settings",
                  subtitle: "Control visibility and user interactions.",
                  child: Column(
                    children: [
                      _buildProfessionalSwitch(
                        title: "Open to Tourists",
                        subtitle: "Make this destination visible on the live map",
                        value: _isOpen,
                        onChanged: (v) => setState(() => _isOpen = v),
                      ),
                      Divider(height: 32, color: borderSubtle),
                      _buildProfessionalSwitch(
                        title: "Enable User Reviews",
                        subtitle: "Allow visitors to leave ratings and comments",
                        value: _allowReviews,
                        onChanged: (v) => setState(() => _allowReviews = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET COMPONENTS ---

  Widget _buildPersistentBottomBar(bool isEditing) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceWhite,
        boxShadow: [
          BoxShadow(color: primaryDark.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
        ],
        border: Border(top: BorderSide(color: borderSubtle)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: Utility().getMaxScreenSize()),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryDark,
                        foregroundColor: surfaceWhite,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _saveTouristSpot,
                      child: Text(
                        isEditing ? "Save Changes" : "Publish Destination",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
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

  Widget _buildSectionContainer({required String title, required String subtitle, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: surfaceWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderSubtle, width: 1.5),
          boxShadow: [
            BoxShadow(color: primaryDark.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 4)),
          ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textPrimary, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 13, color: textMuted, height: 1.4, fontWeight: FontWeight.w500)),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: textMuted, letterSpacing: 0.5)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1, bool isNumber = false, IconData? icon, Color? iconColor}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: TextStyle(fontSize: 15, color: textPrimary, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
        prefixIcon: icon != null ? Icon(icon, size: 20, color: iconColor ?? textMuted) : null,
        filled: true,
        fillColor: backgroundLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderSubtle)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderSubtle)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryDark, width: 1.5)),
      ),
    );
  }

  Widget _buildTypeSelector() {
    final types = ['Beach', 'Garden', 'Mountain', 'Historical', 'Religious', 'Resort'];
    return DropdownButtonFormField<String>(
      initialValue: _selectedType,
      icon: Icon(Icons.unfold_more_rounded, color: textMuted),
      style: TextStyle(fontSize: 15, color: textPrimary, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        filled: true,
        fillColor: backgroundLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderSubtle)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderSubtle)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryDark, width: 1.5)),
      ),
      items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
      onChanged: (v) => setState(() => _selectedType = v!),
    );
  }

  Widget _buildFeatureImageDropzone() {
    final hasImage = _featureImageFile != null || _featureImageUrl != null;
    final imageProvider = hasImage ? _getImageProvider(_featureImageFile ?? _featureImageUrl!) : null;

    return GestureDetector(
      onTap: _pickFeatureImage,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: backgroundLight,
          borderRadius: BorderRadius.circular(16),
          border: !hasImage
              ? Border.all(color: borderSubtle, style: BorderStyle.solid, width: 1.5)
              : Border.all(color: gasanEmerald, width: 2),
          image: imageProvider != null ? DecorationImage(image: imageProvider, fit: BoxFit.cover) : null,
        ),
        child: !hasImage
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: surfaceWhite, shape: BoxShape.circle, border: Border.all(color: borderSubtle)),
              child: Icon(Icons.add_photo_alternate_rounded, size: 28, color: gasanEmerald),
            ),
            const SizedBox(height: 12),
            Text("Select Cover Image", style: TextStyle(color: primaryDark, fontWeight: FontWeight.w700, fontSize: 14)),
          ],
        )
            : Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.black.withValues(alpha: 0.3),
              ),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_rounded, size: 16, color: primaryDark),
                    const SizedBox(width: 8),
                    Text("Change Cover", style: TextStyle(fontWeight: FontWeight.w800, color: primaryDark, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGalleryPicker() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ..._galleryMedia.asMap().entries.map((entry) {
          int idx = entry.key;
          dynamic media = entry.value;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderSubtle, width: 1.5),
                  image: DecorationImage(image: _getImageProvider(media), fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: () => _removeGalleryImage(idx),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: surfaceWhite, shape: BoxShape.circle, border: Border.all(color: borderSubtle)),
                    child: Icon(Icons.close_rounded, size: 16, color: dangerRed),
                  ),
                ),
              ),
            ],
          );
        }),

        if (_galleryMedia.length < 4)
          GestureDetector(
            onTap: _pickGalleryImages,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: backgroundLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderSubtle, width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, color: textMuted, size: 28),
                  const SizedBox(height: 4),
                  Text("Add", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfessionalSwitch({required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: textPrimary, fontSize: 15)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 13, color: textMuted, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          activeColor: surfaceWhite,
          activeTrackColor: gasanEmerald,
          inactiveThumbColor: textMuted,
          inactiveTrackColor: borderSubtle,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
