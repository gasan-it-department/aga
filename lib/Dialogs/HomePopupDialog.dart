import 'package:flutter/material.dart';

class HomePopupDialog extends StatelessWidget {
  const HomePopupDialog({
    super.key,
    required this.imageAsset,
    this.barrierLabel = 'Close popup',
  });

  static const String morionBannerAsset =
      'assets/morion_themed/morion_images/morion_popup_banner.png';

  final String imageAsset;
  final String barrierLabel;

  static Future<void> show(
    BuildContext context, {
    String imageAsset = morionBannerAsset,
    String barrierLabel = 'Close popup',
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: barrierLabel,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        return HomePopupDialog(
          imageAsset: imageAsset,
          barrierLabel: barrierLabel,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxWidth = size.width >= 600 ? 430.0 : size.width - 32;
    final maxHeight = size.height * 0.78;

    return SafeArea(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    imageAsset,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                Positioned(
                  top: -10,
                  right: -10,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 8,
                    shadowColor: Colors.black.withValues(alpha: 0.24),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.close_rounded,
                          color: Color(0xFF0F172A),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
