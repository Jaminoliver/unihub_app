import 'package:flutter/material.dart';

/// UniHub App Colors
/// Compatible with existing code while adding new UniHub branding
class AppColors {
  AppColors._(); // Private constructor

  // =============== UNIHUB PRIMARY COLORS ===============
  static const Color primaryNavy = Color(0xFF0F172A);
  static const Color primaryOrange = Color(0xFFFF6B35);
  static const Color pureWhite = Color(0xFFFFFFFF);

  // =============== OLD NAMES (For compatibility with existing code) ===============
  static const Color primary = primaryOrange; // Maps to orange
  static const Color textDark = primaryNavy; // Maps to navy
  static const Color textLight = Color(0xFF94A3B8); // Medium grey
  static const Color white = pureWhite;

  // =============== SECONDARY COLORS ===============
  static const Color successGreen = Color(0xFF10B981);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color warningYellow = Color(0xFFF59E0B);
  static const Color infoBlue = Color(0xFF3B82F6);

  // =============== NEUTRAL COLORS ===============
  static const Color offWhite = Color(0xFFF8FAFC);
  static const Color lightGrey = Color(0xFFE2E8F0);
  static const Color mediumGrey = Color(0xFF94A3B8);
  static const Color darkGrey = Color(0xFF475569);
  static const Color almostBlack = Color(0xFF1E293B);

  // =============== TEXT COLORS ===============
  static const Color textPrimary = primaryNavy;
  static const Color textSecondary = darkGrey;
  static const Color textMuted = mediumGrey;
  static const Color textOnPrimary = pureWhite;
  static const Color textOnOrange = pureWhite;

  // =============== BACKGROUND COLORS ===============
  static const Color background = pureWhite;
  static const Color backgroundSecondary = offWhite;
  static const Color cardBackground = pureWhite;

  // =============== BORDER COLORS ===============
  static const Color border = lightGrey;
  static const Color borderFocus = primaryOrange;

  // =============== STATUS COLORS ===============
  static const Color statusPending = warningYellow;
  static const Color statusActive = infoBlue;
  static const Color statusDelivered = successGreen;
  static const Color statusCancelled = errorRed;

  // =============== BADGE COLORS ===============
  static const Color badgeTopSeller = Color(0xFFFFD700); // Gold
  static const Color badgeFastShipper = primaryOrange;
  static const Color badgeVerified = successGreen;
  static const Color badgeTopRated = Color(0xFF9333EA); // Purple
  static const Color badgeNew = infoBlue;

  // =============== SHADOW COLORS ===============
  static Color shadow = Colors.black.withOpacity(0.1);
  static Color shadowMedium = Colors.black.withOpacity(0.15);
  static Color shadowLarge = Colors.black.withOpacity(0.2);

  // =============== OVERLAY COLORS ===============
  static Color overlay = Colors.black.withOpacity(0.5);
  static Color overlayLight = Colors.black.withOpacity(0.2);
}
