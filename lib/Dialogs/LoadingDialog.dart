import 'package:flutter/material.dart';

class LoadingDialog {
  OverlayEntry? _entry;
  final ValueNotifier<String> _title = ValueNotifier<String>('Loading...');

  bool get _isShowing => _entry != null;

  void showLoadingDialog(BuildContext context) {
    if (_isShowing) {
      _title.value = 'Loading...';
      return;
    }

    final overlay = Overlay.of(context, rootOverlay: true);
    _title.value = 'Loading...';
    _entry = OverlayEntry(
      builder: (_) => Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ModalBarrier(dismissible: false, color: Colors.black38),
            SafeArea(
              child: Center(
                child: Container(
                  width: 180,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 22,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          strokeCap: StrokeCap.round,
                          color: Color(0xFF0A2E5C),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ValueListenableBuilder<String>(
                        valueListenable: _title,
                        builder: (_, title, _) => Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    overlay.insert(_entry!);
  }

  void dismiss() {
    final entry = _entry;
    _entry = null;
    if (entry?.mounted == true) entry!.remove();
  }

  void dismissWithContext(BuildContext context) => dismiss();

  void updateTitle(String title) {
    if (!_isShowing || _title.value == title) return;
    _title.value = title;
  }
}
