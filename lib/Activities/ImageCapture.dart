import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../Dialogs/ClassicDialog.dart';

class ImageCaptureScreen extends StatefulWidget {
  const ImageCaptureScreen({super.key});

  @override
  State<ImageCaptureScreen> createState() => _ImageCaptureScreenState();
}

class _ImageCaptureScreenState extends State<ImageCaptureScreen> {
  final Color primaryDark = const Color(0xFF0A2E5C);
  final Color accentBlue = const Color(0xFF3B82F6);
  final _classicDialog = ClassicDialog();

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _hasCameraPermission = false;
  bool _isCapturing = false;
  XFile? _capturedImage;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    _initCamera();
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    super.dispose();
  }

  // --- SAFE NAVIGATION METHOD ---
  Future<void> _safeExit(XFile? returnImage) async {
    setState(() {
      _isCameraInitialized = false;
    });

    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    if (_cameraController != null) {
      await _cameraController!.dispose();
      _cameraController = null;
    }

    if (mounted) {
      Navigator.pop(context, returnImage);
    }
  }

  void _showClassicDialog(String title, String message) {
    _classicDialog.setTitle(title);
    _classicDialog.setMessage(message);
    _classicDialog.setCancelable(false);
    _classicDialog.setPositiveMessage("Close");
    if (mounted) {
      _classicDialog.showOnButtonDialog(context, () {
        _classicDialog.dismissDialog();
      });
    }
  }

  Future<void> _initCamera() async {
    try {
      if (!kIsWeb) {
        PermissionStatus status = await Permission.camera.request();
        if (!status.isGranted) {
          if (mounted) {
            setState(() => _hasCameraPermission = false);
            _showClassicDialog(
              "Permission Required",
              "Please allow camera access.",
            );
          }
          return;
        }
      }

      if (mounted) setState(() => _hasCameraPermission = true);

      _cameras = await availableCameras();

      if (_cameras != null && _cameras!.isNotEmpty) {
        CameraDescription selectedCamera;
        try {
          // Prefer the back camera
          selectedCamera = _cameras!.firstWhere(
            (c) =>
                c.lensDirection == CameraLensDirection.back &&
                !c.name.toLowerCase().contains("obs"),
          );
        } catch (_) {
          selectedCamera = _cameras![0];
        }

        _cameraController = CameraController(
          selectedCamera,
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );

        await _cameraController!.initialize();
        await _cameraController!.lockCaptureOrientation(
          DeviceOrientation.landscapeLeft,
        );

        if (mounted) setState(() => _isCameraInitialized = true);
      } else {
        if (mounted) {
          setState(() => _hasCameraPermission = false);
          _showClassicDialog("No Camera Found", "We couldn't detect a camera.");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _hasCameraPermission = false);
        _showClassicDialog("Camera Error", "Could not load camera.\n\n$e");
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (!_isCameraInitialized || _cameraController == null) return;
    setState(() => _isCapturing = true);

    try {
      final XFile image = await _cameraController!.takePicture();
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      if (mounted) {
        setState(() {
          _capturedImage = image;
          _isCapturing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCapturing = false);
        _showClassicDialog("Capture Failed", "Failed to take the picture.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _safeExit(null);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // --- 1. FULL SCREEN CAMERA OR IMAGE PREVIEW ---
              Positioned.fill(
                child: _capturedImage != null
                    ? _buildImagePreview()
                    : _isCameraInitialized
                    ? _buildCameraFeed()
                    : const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
              ),

              // --- 2. TOP BAR (Back Button & Title) ---
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () => _safeExit(null),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        "Capture Proof",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48), // Balance the back button
                    ],
                  ),
                ),
              ),

              // --- 3. BOTTOM CONTROLS ---
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  padding: const EdgeInsets.only(
                    bottom: 24,
                    top: 40,
                    left: 32,
                    right: 32,
                  ),
                  child: _capturedImage != null
                      ? _buildPostCaptureControls()
                      : _buildLiveCameraControls(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraFeed() {
    if (!_hasCameraPermission) {
      return const Center(
        child: Text("Camera Denied", style: TextStyle(color: Colors.white)),
      );
    }
    if (_cameraController == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Center(child: CameraPreview(_cameraController!));
  }

  Widget _buildImagePreview() {
    return kIsWeb
        ? Image.network(_capturedImage!.path, fit: BoxFit.contain)
        : Image.file(File(_capturedImage!.path), fit: BoxFit.contain);
  }

  Widget _buildLiveCameraControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _isCapturing ? null : _capturePhoto,
          child: Container(
            height: 72,
            width: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: Center(
              child: Container(
                height: 56,
                width: 56,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: _isCapturing
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 3,
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt_rounded,
                        color: Color(0xFF0A2E5C),
                        size: 28,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostCaptureControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // RETAKE BUTTON
        Expanded(
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => setState(() => _capturedImage = null),
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            label: const Text(
              "Retake",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),

        // USE PHOTO BUTTON
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentBlue,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            onPressed: () => _safeExit(_capturedImage),
            icon: const Icon(Icons.check_rounded, color: Colors.white),
            label: const Text(
              "Use Photo",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
