import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Activities/MainNavigation.dart';
import 'package:gasan_port_tracker/Activities/MDRRMO/EmergencyScreen.dart';
import 'package:gasan_port_tracker/Dialogs/ClassicDialog.dart';
import 'package:gasan_port_tracker/Dialogs/LoadingDialog.dart';
import 'package:gasan_port_tracker/FloatingMessages/SnackbarMessenger.dart';
import 'package:gasan_port_tracker/Utility/ImageDirectory.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Authentication/SupabaseAuthentication.dart';

class LoginSignup extends StatefulWidget {
  const LoginSignup({super.key});

  @override
  State<LoginSignup> createState() => _LoginSignupState();
}

class _LoginSignupState extends State<LoginSignup> {
  final _loadingDialog = LoadingDialog();
  bool _isSigningIn = false;

  // AGA Brand Colors
  final Color primaryGreen = const Color(0xFF059669);
  final Color darkGreen = const Color(0xFF064E3B);
  final Color bgColor = const Color(0xFFFDFDFD);
  final Color slateBackground = const Color(0xFFF1F5F9);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);
  final _classicDialog = ClassicDialog();

  late final TapGestureRecognizer _termsAndPrivacyPolicyTextRecognition;

  @override
  void initState() {
    super.initState();
    _termsAndPrivacyPolicyTextRecognition = TapGestureRecognizer()
      ..onTap = () {
        _openLink(
          "'https://sites.google.com/view/terms-conditions-aga-app/home'",
        );
      };
  }

  @override
  void dispose() {
    _termsAndPrivacyPolicyTextRecognition.dispose();
    super.dispose();
  }

  Future<void> _openLink(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Could not open browser. Please try again."),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  Future<void> _createUserData(User? user) async {
    final supabase = Supabase.instance.client;
    final String? email = user?.email;
    final String? fullName = user?.userMetadata?['full_name'];
    final String? avatarUrl = user?.userMetadata?['avatar_url'];
    final String? userId = user?.id;
    final String currentDate = Utility().getCurrentReadableDate(
      "MMMM-dd-yyyy hh:mm a",
    );

    final userData = {
      'user_name': fullName,
      'user_account': email,
      'user_id': userId,
      'avatar_url': avatarUrl,
      'user_access': null,
      'user_registration_date': currentDate,
      'user_status': null,
    };

    await supabase.from("user_data").insert(userData);
  }

  Future<bool> _userDataExist(String userId) async {
    try {
      final List<dynamic> result = await Supabase.instance.client
          .from('user_data')
          .select('user_id')
          .eq('user_id', userId)
          .limit(1);

      return result.isNotEmpty;
    } catch (error) {
      Utility().printLog("Error: ${error.toString()}");
      return false;
    }
  }

  void _signIn() async {
    if (_isSigningIn) return;
    setState(() {
      _isSigningIn = true;
    });
    _loadingDialog.showLoadingDialog(context);
    SupabaseAuthentication().signInWithGoogle(
      (errorMessage, stacktrace) {
        if (mounted) {
          setState(() {
            _isSigningIn = false;
          });
        }
        _loadingDialog.dismiss();
        _classicDialog.setTitle("An error occurred!");
        _classicDialog.setMessage(
          "$errorMessage\n\n"
          "Stacktrace: \n"
          "$stacktrace",
        );
        _classicDialog.setCancelable(false);
        _classicDialog.setPositiveMessage("Close");
        if (mounted) {
          _classicDialog.showOnButtonDialog(context, () {
            _classicDialog.dismissDialog();
          });
        }
        return;
      },
      (authResponse) async {
        if (!context.mounted) return;

        if (authResponse.user != null) {
          if (await _userDataExist(authResponse.user!.id) == false) {
            await _createUserData(authResponse.user);
          }

          if (mounted) {
            _loadingDialog.dismiss();
            SnackbarMessenger().showSnackbar(
              context,
              SnackbarMessenger.success,
              "Welcome to AGA Gasan!",
            );
            MainNavigation.resetForNewSession();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainNavigation()),
            );
          }
        } else {
          if (mounted) {
            setState(() {
              _isSigningIn = false;
            });
          }
          _loadingDialog.dismiss();
          SnackbarMessenger().showSnackbar(
            context,
            SnackbarMessenger.failed,
            "Sign in interrupted.",
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Utility().getMaxScreenSize()),
          child: Stack(
            children: [
              // Background Decorative Circle
              Positioned(
                top: -100,
                right: -50,
                child: CircleAvatar(
                  radius: 150,
                  backgroundColor: primaryGreen.withValues(alpha: 0.05),
                ),
              ),

              // --- NEW: Floating Emergency Button ---
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFFFEF2F2,
                        ), // Very Light Red
                        foregroundColor: const Color(0xFFDC2626), // Alert Red
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(
                            color: Color(0xFFFECACA),
                          ), // Soft red border
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EmergencyScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.emergency_share_rounded, size: 18),
                      label: const Text(
                        "Emergency",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Main Content
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // --- APP LOGO SECTION ---
                        Container(
                          height: 100,
                          width: 100,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: slateBackground,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primaryGreen.withValues(alpha: 0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Center(
                              child: Image.asset(
                                ImageDirectory().getOfficialRoundedLogoPath(),
                                width: 70,
                                height: 70,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // --- TYPOGRAPHY ---
                        const Text(
                          "AGA",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF064E3B),
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Explore the heart of the Philippines",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: textSecondary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),

                        const SizedBox(height: 48),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: slateBackground,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                "Welcome Back",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Sign in to your account",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textSecondary,
                                ),
                              ),
                              const SizedBox(height: 32),

                              // --- MODERN GOOGLE BUTTON ---
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E293B),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: Image.asset(
                                    "assets/google.png",
                                    width: 22,
                                    height: 22,
                                  ),
                                  label: const Text(
                                    "Continue with Google",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  onPressed: _isSigningIn ? null : _signIn,
                                ),
                              ),

                              // --- FIX: CLICKABLE TERMS AND PRIVACY POLICY ---
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 24.0,
                                  bottom: 8.0,
                                  left: 8.0,
                                  right: 8.0,
                                ),
                                child: RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: textSecondary,
                                      fontFamily: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.fontFamily,
                                    ),
                                    children: [
                                      const TextSpan(
                                        text:
                                            "By logging in, you agree to our ",
                                      ),
                                      TextSpan(
                                        text: "terms and privacy policy",
                                        style: TextStyle(
                                          color: primaryGreen,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        recognizer:
                                            _termsAndPrivacyPolicyTextRecognition,
                                      ),
                                      const TextSpan(text: "."),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),

                        // --- FOOTER ---
                        Text(
                          "Version ${Utility().getCurrentGlobalVersion()}",
                          style: TextStyle(
                            fontSize: 11,
                            color: textSecondary.withValues(alpha: 0.7),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
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
      ),
    );
  }
}
