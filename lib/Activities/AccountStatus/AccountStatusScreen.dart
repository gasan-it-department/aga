import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Dialogs/LoadingDialog.dart';
import '../../Authentication/SupabaseAuthentication.dart';
import '../../Utility/UserStatus.dart';
import '../LoginSignup.dart';

class AccountStatusScreen extends StatelessWidget {
  const AccountStatusScreen({super.key, required this.status});

  final String status;

  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryDark = const Color(0xFF0F172A);
  final Color textSecondary = const Color(0xFF64748B);
  final Color borderColor = const Color(0xFFE2E8F0);

  static final _loadingDialog = LoadingDialog();

  void _handleLogout(BuildContext context) async {
    try {
      _loadingDialog.showLoadingDialog(context);
      await SupabaseAuthentication().signOut();
      _loadingDialog.dismiss();
      if (!context.mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginSignup()));
    } catch (error) {
      _loadingDialog.dismiss();
      if (!context.mounted) return;
      _showError(context, error.toString());
    }
  }

  void _showError(BuildContext context, String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusConfig = _getStatusConfig();

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  const Spacer(),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: statusConfig.color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: statusConfig.color.withValues(alpha: 0.2),
                          blurRadius: 30,
                          spreadRadius: 5,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: statusConfig.color.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: statusConfig.color.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        statusConfig.icon,
                        size: 64,
                        color: statusConfig.color,
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  Text(
                    statusConfig.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: primaryDark,
                      letterSpacing: -0.8,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    statusConfig.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textSecondary,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 40),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: statusConfig.color.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusConfig.color.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                            Icons.info_outline_rounded,
                            color: statusConfig.color.withValues(alpha: 0.8),
                            size: 20
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Text(
                            "If you believe this is an error, please contact your system administrator and quote your User ID.",
                            style: TextStyle(
                              fontSize: 13,
                              color: primaryDark.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  if (statusConfig.showAppealButton) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {

                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryDark,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Contact Support",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton(
                      onPressed: () => _handleLogout(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textSecondary,
                        side: BorderSide(color: borderColor, width: 2),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Return to Login",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _StatusConfiguration _getStatusConfig() {
    switch (status) {
      case UserStatus.temporarySuspended:
        return _StatusConfiguration(
          title: "Account Suspended",
          description: "Your account has been temporarily placed on hold due to unusual activity or a minor policy violation. Please wait while our team reviews your account.",
          color: const Color(0xFFF59E0B),
          icon: Icons.lock_clock_rounded,
          showAppealButton: true,
        );

      case UserStatus.permanentlyBanned:
        return _StatusConfiguration(
          title: "Permanently Banned",
          description: "This account has been permanently banned from the app. This action is final and cannot be reversed.",
          color: const Color(0xFFEF4444),
          icon: Icons.gpp_bad_rounded,
          showAppealButton: false,
        );

      default:
        return _StatusConfiguration(
          title: "Account Under Review",
          description: "Your account status is currently pending review. Please check back later or contact support if you need immediate assistance.",
          color: const Color(0xFF64748B),
          icon: Icons.pending_actions_rounded,
          showAppealButton: true,
        );
    }
  }
}

class _StatusConfiguration {
  final String title;
  final String description;
  final Color color;
  final IconData icon;
  final bool showAppealButton;

  _StatusConfiguration({
    required this.title,
    required this.description,
    required this.color,
    required this.icon,
    required this.showAppealButton,
  });
}
