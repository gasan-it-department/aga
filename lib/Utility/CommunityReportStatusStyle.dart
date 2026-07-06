import 'package:flutter/material.dart';

class CommunityReportStatusStyle {
  static Color color(String status) {
    switch (status.toLowerCase().trim()) {
      case 'pending':
      case 'pending_review':
      case 'pending review':
        return const Color(0xFFF59E0B);
      case 'acknowledged':
        return const Color(0xFF2563EB);
      case 'in_progress':
      case 'in progress':
        return const Color(0xFF7C3AED);
      case 'resolved':
        return const Color(0xFF16A34A);
      case 'rejected':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF0F766E);
    }
  }
}
