import 'package:flutter/material.dart';

class AITermsPrivacyDialog extends StatefulWidget {
  const AITermsPrivacyDialog({super.key});

  static Future<bool> show(BuildContext context, VoidCallback onDeclineClicked) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AITermsPrivacyDialog(),
    );

    if (result == false || result == null) {
      onDeclineClicked();
    }

    return result ?? false;
  }

  @override
  State<AITermsPrivacyDialog> createState() => _AITermsPrivacyDialogState();
}

class _AITermsPrivacyDialogState extends State<AITermsPrivacyDialog> {
  // --- Theme Colors ---
  final Color primaryDark = const Color(0xFF0A2E5C);
  final Color borderColor = const Color(0xFFE2E8F0);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);
  final Color warningColor = const Color(0xFFDC2626);

  bool _isAgreed = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- HEADER ---
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primaryDark.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: borderColor)),
                    child: Icon(Icons.gavel_rounded, color: primaryDark, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Terms & Privacy Policy", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: primaryDark, letterSpacing: -0.5)),
                        const SizedBox(height: 2),
                        Text("AGA AI Assistant", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // --- SCROLLABLE POLICY CONTENT ---
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader("1. Introduction"),
                      _buildParagraph("Welcome to the AGA (Advanced Gasan Assistant) feature. This AI is provided by the Gasan Municipality to assist citizens. By proceeding, you agree to these Terms & Privacy rules."),

                      const SizedBox(height: 20),
                      _buildSectionHeader("2. Data Collection & Usage"),
                      _buildParagraph("To provide accurate responses, AGA processes your chat prompts along with your in-app context, including:"),
                      _buildBulletPoint("Name, Email, and User ID."),
                      _buildBulletPoint("Account Access Level (e.g., Citizen, Maritime Admin)."),
                      _buildBulletPoint("Assigned Port and Municipality Zip Code."),
                      _buildParagraph("Your data is securely transmitted to Google's servers via the Gemini API strictly for generating responses. We do not sell your personal data."),

                      const SizedBox(height: 20),
                      _buildSectionHeader("3. Acceptable Use"),
                      _buildParagraph("You agree not to use the AI to request illegal information, generate malicious code, or bypass system security. This tool is strictly for maritime tracking, disaster readiness, and municipal guidance."),

                      const SizedBox(height: 20),
                      _buildSectionHeader("4. Emergency Disclaimers & Liability", isWarning: true),
                      _buildBulletPoint("Not a Dispatch Replacement: In a life-threatening emergency, DO NOT rely solely on the AI. Use official MDRRMO hotlines immediately.", isWarning: true),
                      _buildBulletPoint("AI Hallucinations: Artificial Intelligence can occasionally produce inaccurate or fabricated information. Always verify critical severe weather or evacuation data through official bulletins.", isWarning: true),
                      _buildParagraph("MDRRMO Gasan and the developers shall not be liable for any damages or losses resulting from reliance on the AI's outputs."),
                    ],
                  ),
                ),
              ),
            ),

            // --- CHECKBOX AREA ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  checkboxTheme: CheckboxThemeData(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                child: CheckboxListTile(
                  value: _isAgreed,
                  activeColor: primaryDark,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    "I have read and agree to the Terms of Service and Privacy Policy.",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
                  ),
                  onChanged: (bool? value) {
                    setState(() => _isAgreed = value ?? false);
                  },
                ),
              ),
            ),

            // --- ACTION BUTTONS ---
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: textSecondary,
                        side: BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        // FIX: Pass 'false' back to the show() method to trigger the decline logic
                        Navigator.of(context).pop(false);
                      },
                      child: const Text("Decline", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: primaryDark,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade500,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      // FIX: Pass 'true' back to the show() method to indicate acceptance
                      onPressed: _isAgreed ? () => Navigator.of(context).pop(true) : null,
                      child: const Text("Accept & Continue", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- UI FORMATTING HELPERS ---

  Widget _buildSectionHeader(String title, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: isWarning ? warningColor : primaryDark
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, height: 1.5, color: textPrimary),
      ),
    );
  }

  Widget _buildBulletPoint(String text, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, left: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("•", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isWarning ? warningColor : textPrimary)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: isWarning ? warningColor : textPrimary,
                  fontWeight: isWarning ? FontWeight.w600 : FontWeight.normal
              ),
            ),
          ),
        ],
      ),
    );
  }
}
