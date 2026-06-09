import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddEditTourismEventBanner extends StatefulWidget {
  final int municipalZipCode;
  final Map<String, dynamic>? existingEvent;

  const AddEditTourismEventBanner({
    super.key,
    required this.municipalZipCode,
    this.existingEvent,
  });

  @override
  State<AddEditTourismEventBanner> createState() => _AddEditTourismEventBannerState();
}

class _AddEditTourismEventBannerState extends State<AddEditTourismEventBanner> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final String _bucket = 'tourism_event_banner_images';

  final Color bgColor = const Color(0xFFF8FAFC);
  final Color surfaceColor = const Color(0xFFFFFFFF);
  final Color primaryDark = const Color(0xFF0F172A);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);
  final Color borderColor = const Color(0xFFE2E8F0);
  final Color inputBgColor = const Color(0xFFF1F5F9);
  final Color eventViolet = const Color(0xFF8B5CF6);
  final Color rose = const Color(0xFFEF4444);

  late TextEditingController _nameController;
  late TextEditingController _descController;

  String? _existingImageUrl;
  XFile? _pickedFile;
  Uint8List? _pickedBytes;
  bool _removeExisting = false;

  bool _isSaving = false;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _isUpdating = widget.existingEvent != null;
    _nameController = TextEditingController(text: _isUpdating ? widget.existingEvent!['banner_name']?.toString() ?? '' : '');
    _descController = TextEditingController(text: _isUpdating ? widget.existingEvent!['banner_description']?.toString() ?? '' : '');
    _existingImageUrl = _isUpdating ? widget.existingEvent!['banner_cover_image']?.toString() : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? f = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedFile = f;
      _pickedBytes = bytes;
      _removeExisting = false;
    });
  }

  void _clearImage() {
    setState(() {
      _pickedFile = null;
      _pickedBytes = null;
      _removeExisting = _existingImageUrl != null;
    });
  }

  String? _pathFromUrl(String url) {
    try {
      final segs = Uri.parse(url).pathSegments;
      final idx = segs.indexOf(_bucket);
      if (idx != -1 && idx < segs.length - 1) return segs.sublist(idx + 1).join('/');
    } catch (_) {}
    return null;
  }

  Future<String?> _uploadImage() async {
    if (_pickedFile == null || _pickedBytes == null) return null;
    final ext = _pickedFile!.name.contains('.') ? _pickedFile!.name.split('.').last : 'jpg';
    final path = 'banner_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _supabase.storage.from(_bucket).uploadBinary(path, _pickedBytes!);
    return _supabase.storage.from(_bucket).getPublicUrl(path);
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      String? coverUrl = _existingImageUrl;

      if (_pickedFile != null) {
        if (_existingImageUrl != null) {
          final old = _pathFromUrl(_existingImageUrl!);
          if (old != null) {
            try { await _supabase.storage.from(_bucket).remove([old]); } catch (_) {}
          }
        }
        coverUrl = await _uploadImage();
      } else if (_removeExisting && _existingImageUrl != null) {
        final old = _pathFromUrl(_existingImageUrl!);
        if (old != null) {
          try { await _supabase.storage.from(_bucket).remove([old]); } catch (_) {}
        }
        coverUrl = null;
      }

      final payload = <String, dynamic>{
        'banner_name': _nameController.text.trim(),
        'banner_description': _descController.text.trim(),
        'banner_cover_image': coverUrl,
        'banner_municipal_zipcode': widget.municipalZipCode,
      };

      if (_isUpdating) {
        final String eventId = widget.existingEvent!['banner_id'];
        await _supabase.from('tourism_event_banners').update(payload).eq('banner_id', eventId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event successfully published.'), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      } else {
        payload['banner_id'] = "EVT-${DateTime.now().millisecondsSinceEpoch}";
        payload['banner_date_added'] = DateTime.now().millisecondsSinceEpoch;
        await _supabase.from('tourism_event_banners').insert(payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event successfully published.'), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint("Error saving event: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An error occurred: $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool get _hasImage => _pickedBytes != null || (!_removeExisting && _existingImageUrl != null && _existingImageUrl!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: surfaceColor,
        foregroundColor: primaryDark,
        centerTitle: true,
        title: Text(
          _isUpdating ? "Edit Event" : "Create Event",
          style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5, fontSize: 16),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderColor, height: 1),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildSectionHeader(Icons.image_outlined, "COVER IMAGE"),
                        const SizedBox(height: 16),
                        _buildImagePicker(),
                        const SizedBox(height: 40),

                        _buildSectionHeader(Icons.article_outlined, "EVENT DETAILS"),
                        const SizedBox(height: 16),

                        _buildTextField(
                          controller: _nameController,
                          label: "Event Name",
                          hint: "e.g., Summer Festival 2026",
                          icon: Icons.title_rounded,
                          validator: (val) => (val == null || val.trim().isEmpty) ? "Please enter the event name." : null,
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _descController,
                          label: "Description",
                          hint: "Provide a detailed description of the event...",
                          icon: Icons.notes_rounded,
                          maxLines: 6,
                          validator: (val) => (val == null || val.trim().isEmpty) ? "Please enter a description." : null,
                        ),
                      ],
                    ),
                  ),
                ),
                _buildStationaryBottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStationaryBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
        boxShadow: [
          BoxShadow(
            color: primaryDark.withValues(alpha: 0.03),
            offset: const Offset(0, -4),
            blurRadius: 12,
          )
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveEvent,
          style: ElevatedButton.styleFrom(
            backgroundColor: eventViolet,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.cloud_upload_rounded, size: 20),
          label: Text(
            _isSaving ? "Publishing..." : (_isUpdating ? "Publish Update" : "Publish Event"),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.2),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    final Widget content;
    if (_hasImage) {
      content = Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: _pickedBytes != null
                ? Image.memory(_pickedBytes!, fit: BoxFit.cover)
                : Image.network(
              _existingImageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(broken: true),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Row(
              children: [
                _circleButton(Icons.swap_horiz_rounded, eventViolet, _pickImage, tooltip: "Replace Image"),
                const SizedBox(width: 10),
                _circleButton(Icons.delete_outline_rounded, rose, _clearImage, tooltip: "Remove Image"),
              ],
            ),
          ),
        ],
      );
    } else {
      content = InkWell(
        onTap: _pickImage,
        borderRadius: BorderRadius.circular(15),
        child: _placeholder(),
      );
    }

    // Adjusted the height to mimic a 16:9 container aspect ratio dynamically
    // for a standard mobile width, but hardcoded 240 works great for desktop/tablet scaling.
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: inputBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5, style: BorderStyle.solid),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }

  Widget _placeholder({bool broken = false}) {
    return Container(
      color: inputBgColor,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: surfaceColor, shape: BoxShape.circle, border: Border.all(color: borderColor)),
            child: Icon(broken ? Icons.broken_image_outlined : Icons.add_photo_alternate_outlined, color: textSecondary, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            broken ? "Image failed to load" : "Click to browse files",
            style: TextStyle(color: primaryDark, fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 6),
          // Added explicit Canva sizing instructions here
          Text(
            "Recommended size: 1920 x 1080 pixels (16:9 ratio)",
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            "Perfect for Canva designs • JPG or PNG",
            style: TextStyle(color: textSecondary, fontWeight: FontWeight.w500, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, Color color, VoidCallback onTap, {String? tooltip}) {
    return Material(
      color: surfaceColor,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip ?? '',
          child: Padding(padding: const EdgeInsets.all(10), child: Icon(icon, color: color, size: 18)),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: primaryDark),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: textSecondary, letterSpacing: 1.2),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: primaryDark)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          onChanged: onChanged,
          style: TextStyle(fontSize: 15, color: textPrimary, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.5), fontWeight: FontWeight.w400),
            prefixIcon: maxLines == 1
                ? Icon(icon, color: textSecondary, size: 20)
                : Padding(padding: const EdgeInsets.only(bottom: 120), child: Icon(icon, color: textSecondary, size: 20)),
            filled: true,
            fillColor: inputBgColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor, width: 1)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: eventViolet, width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: rose, width: 1)),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: rose, width: 1.5)),
          ),
        ),
      ],
    );
  }
}
