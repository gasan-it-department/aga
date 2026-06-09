import 'package:flutter/material.dart';

class ClassicDialog {
  String title = "";
  String message = "";
  String positiveButtonTitle = "";
  String negativeButtonTitle = "";
  BuildContext? dialogContext;
  bool cancelable = true;

  void setTitle(String title) {
    this.title = title;
  }

  void setMessage(String message) {
    this.message = message;
  }

  void setPositiveMessage(String message) {
    positiveButtonTitle = message;
  }

  void setNegativeMessage(String message) {
    negativeButtonTitle = message;
  }

  void setCancelable(bool cancelable) {
    this.cancelable = cancelable;
  }

  void dismissDialog() {
    if (dialogContext != null) {
      Navigator.pop(dialogContext!);
      dialogContext = null;
    }
  }

  void showOnButtonDialog(BuildContext mainContext, void Function() onButtonPressed) {
    showDialog(
      barrierDismissible: cancelable,
      context: mainContext,
      builder: (BuildContext context) {
        dialogContext = context;
        return PopScope(
          canPop: false,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0,
            backgroundColor: Colors.white,
            child: SizedBox(
              width: 400,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A), // Dark slate
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Message
                    Flexible(
                      child: SingleChildScrollView(
                        child: Text(
                          message,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF475569), // Softer grey for readability
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Single Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A2E5C), // App Primary Color
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                        // FIXED: Removed the invalid 'onTap' here
                        onPressed: onButtonPressed,
                        child: Text(
                          positiveButtonTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void showTwoButtonDialog(
      BuildContext mainContext,
      void Function(bool negativeClicked) negativeClick,
      void Function(bool positiveClicked) positiveClicked) {
    showDialog(
      context: mainContext,
      barrierDismissible: cancelable,
      builder: (BuildContext context) {
        dialogContext = context;
        return PopScope(
          canPop: false,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0,
            backgroundColor: Colors.white,
            child: SizedBox(
              width: 400,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Message
                    Flexible(
                      child: SingleChildScrollView(
                        child: Text(
                          message,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF475569),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Two Buttons
                    Row(
                      children: [
                        // Negative Button (Subtle)
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFFF1F5F9), // Light grey fill
                                foregroundColor: const Color(0xFF64748B), // Slate text
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50),
                                ),
                              ),
                              onPressed: () => negativeClick(true),
                              child: Text(
                                negativeButtonTitle,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Positive Button (Primary)
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0A2E5C), // App Primary Color
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50),
                                ),
                              ),
                              onPressed: () => positiveClicked(true),
                              child: Text(
                                positiveButtonTitle,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
