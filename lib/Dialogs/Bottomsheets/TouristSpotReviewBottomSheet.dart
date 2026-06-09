
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'dart:typed_data';

class ReviewBottomheet extends StatefulWidget {
  final String spotId;
  final Map<String, dynamic>? existingReview;
  final VoidCallback onReviewSaved;

  const ReviewBottomheet({super.key, required this.spotId, this.existingReview, required this.onReviewSaved});

  @override
  State<ReviewBottomheet> createState() => _ReviewBottomheetState();
}

class _ReviewBottomheetState extends State<ReviewBottomheet> {
  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();
  late int _stars;
  late TextEditingController _ctrl;
  late bool _isAnon;
  List<String> _oldImgs = [];
  List<String> _deletedUrls = [];
  List<Uint8List> _newImgsBytes = [];
  List<XFile> _newImgsFiles = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _stars = widget.existingReview?['review_rate'] ?? 5;
    _ctrl = TextEditingController(text: widget.existingReview?['review_message'] ?? '');
    _isAnon = widget.existingReview?['review_is_anonymous'] == true;
    if (widget.existingReview?['review_images'] != null) {
      _oldImgs = List<String>.from(jsonDecode(widget.existingReview!['review_images']));
    }
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      for (var file in picked) {
        if (_oldImgs.length + _newImgsFiles.length < 3) {
          final bytes = await file.readAsBytes();
          setState(() {
            _newImgsBytes.add(bytes);
            _newImgsFiles.add(file);
          });
        }
      }
    }
  }

  Future<void> _submit() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;

      if (_deletedUrls.isNotEmpty) {
        final List<String> paths = [];
        for (var url in _deletedUrls) {
          final segs = Uri.parse(url).pathSegments;
          final idx = segs.indexOf('review_images');
          if (idx != -1 && idx < segs.length - 1) {
            paths.add(segs.sublist(idx + 1).join('/'));
          } else {
            paths.add(segs.last);
          }
        }
        await _supabase.storage.from('review_images').remove(paths);
      }

      List<String> urls = List.from(_oldImgs);
      for (var file in _newImgsFiles) {
        final path = '${Utility().getCurrentMSEpochTime()}_$userId.${file.name.split('.').last}';
        await _supabase.storage.from('review_images').uploadBinary(path, await file.readAsBytes());
        urls.add(_supabase.storage.from('review_images').getPublicUrl(path));
      }

      await _supabase.from('tourist_spot_review').upsert({
        'review_id': widget.existingReview?['review_id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'review_spot_id': widget.spotId,
        'review_rate': _stars,
        'review_user_id': userId,
        'review_message': _ctrl.text.trim(),
        'review_images': jsonEncode(urls),
        'review_is_anonymous': _isAnon,
        'review_date': widget.existingReview?['review_date'] ?? DateTime.now().millisecondsSinceEpoch,
      });

      widget.onReviewSaved();
      Navigator.pop(context);
    } catch (e) {
      debugPrint("Save Error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 768,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                          child: Container(
                              width: 40, height: 4,
                              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))
                          )
                      ),
                      const SizedBox(height: 32),

                      const Center(
                        child: Text("Rate your experience", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (i) {
                          bool isSelected = i < _stars;
                          return GestureDetector(
                            onTap: () => setState(() => _stars = i + 1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                isSelected ? Icons.star_rounded : Icons.star_border_rounded,
                                color: isSelected ? const Color(0xFFF59E0B) : Colors.grey.shade300,
                                size: 44,
                              ),
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 32),

                      TextField(
                        controller: _ctrl,
                        maxLines: 4,
                        style: const TextStyle(fontSize: 15, color: Color(0xFF111827), fontWeight: FontWeight.w400),
                        decoration: InputDecoration(
                          hintText: "Share details of your own experience at this place",
                          hintStyle: TextStyle(color: const Color(0xFF6B7280).withValues(alpha: 0.5)),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          contentPadding: const EdgeInsets.all(20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildImagePickerSection(),

                      const SizedBox(height: 24),

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Post Anonymously", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF111827))),
                        subtitle: const Text("Hide your name and profile picture", style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                        value: _isAnon,
                        activeThumbColor: Colors.blueAccent.shade700,
                        onChanged: (v) => setState(() => _isAnon = v),
                      ),

                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity, height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            elevation: 0,
                          ),
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("Post", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.5)),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePickerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Photos (Max 3)", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF111827))),
        const SizedBox(height: 12),
        Row(
          children: [
            if (_oldImgs.length + _newImgsFiles.length < 3)
              GestureDetector(
                onTap: _pickImages,
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300, width: 1)
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, color: Color(0xFF6B7280), size: 20),
                      SizedBox(height: 4),
                      Text("Add", style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.bold))
                    ],
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 72,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    ..._oldImgs.map((url) => _buildImageThumbnail(Image.network(url, fit: BoxFit.cover), onRemove: () {
                      setState(() { _deletedUrls.add(url); _oldImgs.remove(url); });
                    })),
                    ..._newImgsBytes.asMap().entries.map((e) => _buildImageThumbnail(Image.memory(e.value, fit: BoxFit.cover), onRemove: () {
                      setState(() { _newImgsBytes.removeAt(e.key); _newImgsFiles.removeAt(e.key); });
                    })),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageThumbnail(Widget img, {required VoidCallback onRemove}) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      width: 72, height: 72,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200, width: 1)
      ),
      child: Stack(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox.expand(child: img)),
          Positioned(
            top: 4, right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
              ),
            ),
          )
        ],
      ),
    );
  }
}
