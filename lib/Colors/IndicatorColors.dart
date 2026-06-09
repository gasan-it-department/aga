import 'package:flutter/material.dart';

class StatusColors {
  final Color background;
  final Color text;
  final Color border;

  const StatusColors({
    required this.background,
    required this.text,
    required this.border,
  });
}

class IndicatorColors {

  // ==========================================
  // 1. MAINTENANCE (Grey to Black)
  // ==========================================
  static const StatusColors maintenance = StatusColors(
    background: Color(0xFFF3F4F6), // Very Light Faded Grey
    text: Color(0xFF1F2937),       // Near Black
    border: Color(0xFFD1D5DB),     // Medium Grey
  );

  // ==========================================
  // 2. DOCKED (Pinky to Red)
  // ==========================================
  static const StatusColors docked = StatusColors(
    background: Color(0xFFFFF1F2), // Faded Rose/Pink
    text: Color(0xFFE11D48),       // Deep Red
    border: Color(0xFFFECDD3),     // Soft Pink/Red Border
  );

  // ==========================================
  // 3. ONBOARDING (Yellow)
  // ==========================================
  static const StatusColors onboarding = StatusColors(
    background: Color(0xFFFFFBEB), // Faded Yellow
    text: Color(0xFFB45309),       // Dark Amber (so it's readable on white)
    border: Color(0xFFFDE68A),     // Soft Yellow Border
  );

  // ==========================================
  // 4. DEPARTED (Blue)
  // ==========================================
  static const StatusColors departed = StatusColors(
    background: Color(0xFFEFF6FF), // Faded Blue
    text: Color(0xFF1D4ED8),       // Solid Dark Blue
    border: Color(0xFFBFDBFE),     // Soft Blue Border
  );

  // ==========================================
  // 5. ARRIVAL / ARRIVED (Green)
  // ==========================================
  static const StatusColors arrival = StatusColors(
    background: Color(0xFFECFDF5), // Faded Mint Green
    text: Color(0xFF047857),       // Deep Emerald Green
    border: Color(0xFFA7F3D0),     // Soft Green Border
  );

  // ==========================================
  // 6. RE-ROUTED (Deep Purple)
  // ==========================================
  static const StatusColors rerouted = StatusColors(
    background: Color(0xFFF5F3FF), // Faded Purple
    text: Color(0xFF6D28D9),       // Vibrant Deep Purple
    border: Color(0xFFDDD6FE),     // Soft Purple Border
  );

  // ==========================================
  // DEFAULT (Catch-all)
  // ==========================================
  static const StatusColors unknown = StatusColors(
    background: Color(0xFFF8FAFC),
    text: Color(0xFF64748B),
    border: Color(0xFFE2E8F0),
  );

  static StatusColors getColors(String status) {
    switch (status.toLowerCase()) {
      case 'maintenance':
        return maintenance;
      case 'docked':
        return docked;
      case 'onboarding':
      case 'standby':
        return onboarding;
      case 'departed':
        return departed;
      case 'arrived':
      case 'arrival':
        return arrival;
      case 're-routed':
      case 'rerouted':
        return rerouted;
      default:
        return unknown;
    }
  }
}
