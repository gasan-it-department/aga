import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Utility/Utility.dart';
import '../Dialogs/LoadingDialog.dart';
import '../Dialogs/ClassicDialog.dart';

class VerifyAccount extends StatefulWidget {
  const VerifyAccount({super.key});

  @override
  State<VerifyAccount> createState() => _VerifyAccountState();
}

class _VerifyAccountState extends State<VerifyAccount> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final LoadingDialog _loadingDialog = LoadingDialog();
  final _classicDialog = ClassicDialog();
  final _supabase = Supabase.instance.client;

  // --- DATA STATE ---
  String? _selectedIdType;
  XFile? _idFrontFile;
  XFile? _selfieFile;
  bool _acceptedPrivacy = false;

  // --- THEME COLORS ---
  final Color primaryDark = const Color(0xFF0F172A);
  final Color primaryBlue = const Color(0xFF2563EB);
  final Color accentEmerald = const Color(0xFF10B981);
  final Color textSecondary = const Color(0xFF64748B);
  final Color bgColor = const Color(0xFFF8FAFC);

  final List<String> _idTypes = [
    "Driver's License",
    "Passport",
    "UMID",
    "Postal ID",
    "Voter's ID",
    "National ID (PhilID)",
    "PRC ID"
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 5) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submitVerification() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _loadingDialog.showLoadingDialog(context);
    _loadingDialog.updateTitle("Uploading verification data...");

    try {
      // 1. Upload ID Image
      String? idUrl;
      if (_idFrontFile != null) {
        idUrl = await _uploadFile(_idFrontFile!, "verifications/ids/${user.id}_front.jpg");
      }

      // 2. Upload Selfie
      String? selfieUrl;
      if (_selfieFile != null) {
        selfieUrl = await _uploadFile(_selfieFile!, "verifications/selfies/${user.id}_selfie.jpg");
      }

      // 3. Save to database
      await _supabase.from('user_verifications').upsert({
        'user_id': user.id,
        'id_type': _selectedIdType,
        'id_image_url': idUrl,
        'selfie_image_url': selfieUrl,
        'status': 'pending',
        'submitted_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        _loadingDialog.dismiss();
        _showSuccessDialog();
      }
    } catch (e) {
      _loadingDialog.dismiss();
      debugPrint("Verification Error: $e");
      if (mounted) _showErrorSnackBar("Submission failed. Please try again.");
    }
  }

  Future<String?> _uploadFile(XFile file, String path) async {
    final bytes = await file.readAsBytes();
    await _supabase.storage.from('user_assets').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
    );
    return _supabase.storage.from('user_assets').getPublicUrl(path);
  }

  void _showSuccessDialog() {
    _classicDialog.setTitle("Verification Submitted");
    _classicDialog.setMessage("Your account verification is now being reviewed. This usually takes 24-48 hours. We'll notify you once it's complete.");
    _classicDialog.setPositiveMessage("Done");
    _classicDialog.showOnButtonDialog(context, () {
      _classicDialog.dismissDialog();
      Navigator.pop(context);
    });
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 0,
        centerTitle: false,
        title: const Text("Account Verification", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildProgressTracker(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStepPrivacyPolicy(),
                _buildStepIntro(),
                _buildStepIdType(),
                _buildStepIdScan(),
                _buildStepSelfie(),
                _buildStepReview(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTracker() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        children: List.generate(6, (index) {
          bool isCompleted = index < _currentStep;
          bool isCurrent = index == _currentStep;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: isCompleted ? accentEmerald : (isCurrent ? primaryBlue : Colors.grey.shade200),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 14)
                        : Text("${index + 1}", style: TextStyle(color: isCurrent ? Colors.white : textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                if (index < 5)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isCompleted ? accentEmerald : Colors.grey.shade200,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // --- STEP 1: INTRO ---
  Widget _buildStepIntro() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user_rounded, size: 64, color: Color(0xFF2563EB)),
          const SizedBox(height: 24),
          const Text("Verify Your Identity", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 12),
          Text(
            "To unlock full features and ensure a secure environment, we need to verify your account. This process only takes a few minutes.",
            style: TextStyle(fontSize: 15, color: textSecondary, height: 1.5),
          ),
          const SizedBox(height: 32),
          _buildRequirementTile(Icons.badge_outlined, "Valid Government ID", "Prepare a clear, original copy of your ID."),
          _buildRequirementTile(Icons.face_retouching_natural_rounded, "Clear Selfie", "Make sure you're in a well-lit area."),
          _buildRequirementTile(Icons.security_rounded, "Secure Process", "Your data is encrypted and used only for verification."),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
              child: const Text("GET STARTED", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.0)),
            ),
          ),
        ],
      ),
    );
  }

  // --- NEW STEP: PRIVACY POLICY ---
  Widget _buildStepPrivacyPolicy() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Data Privacy Notice & Consent", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                "Last Updated: May 14, 2026\n\n"
                "At Gasan Port Tracker, we are committed to protecting your personal information and your right to privacy. To ensure a safe and trusted marketplace, we require our users to undergo an identity verification process before activating a Seller Profile.\n\n"
                "This notice explains how we collect, use, store, and protect the sensitive information you provide during this process, in accordance with the Data Privacy Act of 2012 (RA 10173).\n\n"
                "1. What Information We Collect\n"
                "To verify your identity, we collect the following sensitive personal information:\n"
                "- Government-Issued Identification: Images of your ID (e.g., PhilSys ID, Passport, Driver’s License) and the data extracted from it, including your full name, date of birth, address, and ID number.\n"
                "- Biometric Data: A live selfie or facial scan to match against the photo on your provided ID.\n\n"
                "2. Why We Collect This Information\n"
                "We strictly use this information for the following purposes:\n"
                "- Identity Verification: To confirm that you are exactly who you say you are.\n"
                "- Fraud Prevention: To protect our community from impersonation, scams, and unauthorized accounts.\n"
                "- Legal & Regulatory Compliance: To comply with local laws and standard Know Your Customer (KYC) requirements.\n\n"
                "3. How We Share Your Information\n"
                "We treat your sensitive data with the highest level of confidentiality. We will never sell or rent your personal information to third parties. We may only share your data under the following circumstances:\n"
                "- Authorized Third-Party KYC Providers: We may use secure, globally recognized third-party services strictly to process and verify your ID and selfie.\n"
                "- Law Enforcement & Legal Obligations: We may disclose your information if required to do so by law.\n\n"
                "4. Data Storage, Security, and Retention\n"
                "- Security Measures: Your data is transmitted using secure, encrypted connections (SSL/TLS) and stored on highly secure servers.\n"
                "- Retention Period: We will retain your verification data only for as long as your account remains active. If your account is closed, your sensitive ID and biometric data will be permanently purged within 60 days.\n\n"
                "5. Your Data Privacy Rights\n"
                "Under the Data Privacy Act, you have the right to access, correct, erase, or object to the processing of your data.\n\n"
                "6. Contact Us\n"
                "If you have any questions, please contact our Data Protection Officer at support@gasanporttracker.com.",
                style: TextStyle(fontSize: 15, color: textSecondary, height: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
              child: const Text("I UNDERSTAND", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementTile(IconData icon, String title, String sub) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: primaryBlue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 2: ID TYPE ---
  Widget _buildStepIdType() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Select ID Type", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Text("Please choose the document you want to use.", style: TextStyle(color: textSecondary)),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _idTypes.length,
              itemBuilder: (context, index) {
                final type = _idTypes[index];
                bool isSelected = _selectedIdType == type;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIdType = type),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryBlue.withValues(alpha: 0.05) : Colors.white,
                      border: Border.all(color: isSelected ? primaryBlue : Colors.grey.shade200, width: 1.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.badge_rounded, color: isSelected ? primaryBlue : textSecondary, size: 20),
                        const SizedBox(width: 12),
                        Text(type, style: TextStyle(fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, color: isSelected ? primaryBlue : primaryDark)),
                        const Spacer(),
                        if (isSelected) Icon(Icons.check_circle_rounded, color: primaryBlue, size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _selectedIdType != null ? _nextStep : null,
              style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
              child: const Text("CONTINUE", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 3: ID SCAN ---
  Widget _buildStepIdScan() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Scan Front of ID", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Text("Place the front of your ID within the frame and make sure it's readable.", style: TextStyle(color: textSecondary)),
          const SizedBox(height: 32),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: () => _openScanner("id_front"),
                child: Container(
                  width: double.infinity,
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: primaryBlue.withValues(alpha: 0.3), style: BorderStyle.solid, width: 2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _idFrontFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: kIsWeb ? Image.network(_idFrontFile!.path, fit: BoxFit.cover) : Image.file(File(_idFrontFile!.path), fit: BoxFit.cover),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_enhance_rounded, size: 48, color: primaryBlue.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            const Text("Tap to Scan ID", style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
                          ],
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _prevStep,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: const Text("BACK", style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _idFrontFile != null ? _nextStep : null,
                  style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                  child: const Text("CONTINUE", style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- STEP 4: SELFIE ---
  Widget _buildStepSelfie() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Take a Selfie", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Text("Look straight at the camera and ensure your face is well-lit.", style: TextStyle(color: textSecondary)),
          const SizedBox(height: 32),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: () => _openScanner("selfie"),
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryBlue.withValues(alpha: 0.3), width: 2),
                  ),
                  child: _selfieFile != null
                      ? ClipOval(
                          child: kIsWeb ? Image.network(_selfieFile!.path, fit: BoxFit.cover) : Image.file(File(_selfieFile!.path), fit: BoxFit.cover),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.face_rounded, size: 64, color: primaryBlue.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            const Text("Tap to Take Selfie", style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
                          ],
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _prevStep,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: const Text("BACK", style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _selfieFile != null ? _nextStep : null,
                  style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                  child: const Text("CONTINUE", style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- STEP 5: REVIEW ---
  Widget _buildStepReview() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Review Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Text("Please make sure all information and photos are clear.", style: TextStyle(color: textSecondary)),
          const SizedBox(height: 32),
          _buildReviewRow("ID Type", _selectedIdType ?? "None"),
          const SizedBox(height: 20),
          const Text("Photos", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildReviewImage("ID Front", _idFrontFile),
              const SizedBox(width: 16),
              _buildReviewImage("Selfie", _selfieFile),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Checkbox(
                value: _acceptedPrivacy,
                activeColor: accentEmerald,
                onChanged: (val) => setState(() => _acceptedPrivacy = val!),
              ),
              Expanded(
                child: Text(
                  "I agree to the Privacy Policy and consent to the collection of my data for verification purposes.",
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _acceptedPrivacy ? _submitVerification : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _acceptedPrivacy ? accentEmerald : Colors.grey.shade300,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text("SUBMIT FOR VERIFICATION", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _prevStep,
              child: Text("Back to editing", style: TextStyle(color: textSecondary, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String val) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: textSecondary, fontWeight: FontWeight.w600)),
          Text(val, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildReviewImage(String label, XFile? file) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: file != null
                  ? (kIsWeb ? Image.network(file.path, fit: BoxFit.cover) : Image.file(File(file.path), fit: BoxFit.cover))
                  : const Center(child: Icon(Icons.image_not_supported_outlined)),
            ),
          ),
        ],
      ),
    );
  }

  // --- CAMERA SCANNER DIALOG ---
  Future<void> _openScanner(String type) async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    if (mounted) {
      final XFile? result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IDScanner(cameras: cameras, scannerType: type),
        ),
      );

      if (result != null) {
        setState(() {
          if (type == "id_front") _idFrontFile = result;
          if (type == "selfie") _selfieFile = result;
        });
      }
    }
  }
}

// --- CUSTOM ID SCANNER COMPONENT ---
class IDScanner extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String scannerType;

  const IDScanner({super.key, required this.cameras, required this.scannerType});

  @override
  State<IDScanner> createState() => _IDScannerState();
}

class _IDScannerState extends State<IDScanner> {
  late CameraController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    CameraDescription selected = widget.cameras.first;
    if (widget.scannerType == "selfie") {
      try {
        selected = widget.cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front);
      } catch (_) {}
    } else {
      try {
        selected = widget.cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back);
      } catch (_) {}
    }

    _controller = CameraController(selected, ResolutionPreset.high, enableAudio: false);
    await _controller.initialize();
    if (mounted) setState(() => _isInitialized = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller),
          
          // Overlay
          ColorFiltered(
            colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.7), BlendMode.srcOut),
            child: Stack(
              children: [
                Container(decoration: const BoxDecoration(color: Colors.black, backgroundBlendMode: BlendMode.dstOut)),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: widget.scannerType == "selfie" ? 280 : 320,
                    height: widget.scannerType == "selfie" ? 280 : 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(widget.scannerType == "selfie" ? 200 : 16),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Guidance Text
          Positioned(
            top: 100, left: 24, right: 24,
            child: Text(
              widget.scannerType == "selfie" ? "Center your face in the circle" : "Align the ID within the frame",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

          // Capture Button
          Positioned(
            bottom: 60, left: 0, right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () async {
                  final img = await _controller.takePicture();
                  if (mounted) Navigator.pop(context, img);
                },
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                  child: Center(child: Container(width: 56, height: 56, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
                ),
              ),
            ),
          ),

          // Back Button
          Positioned(
            top: 50, left: 16,
            child: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
          ),
        ],
      ),
    );
  }
}
