import 'package:flutter/material.dart';

/// UniHub App Colors with Dark Mode Support
class AppColors {
  AppColors._(); // Private constructor

  // =============== UNIHUB PRIMARY COLORS (THEME INDEPENDENT) ===============
  static const Color primaryNavy = Color(0xFF0F172A);
  static const Color primaryOrange = Color(0xFFFF6B35);
  static const Color pureWhite = Color(0xFFFFFFFF);

  // =============== OLD NAMES (For compatibility with existing code) ===============
  static const Color primary = primaryOrange;
  static const Color white = pureWhite;

  // =============== SECONDARY COLORS (THEME INDEPENDENT) ===============
  static const Color successGreen = Color(0xFF10B981);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color warningYellow = Color(0xFFF59E0B);
  static const Color infoBlue = Color(0xFF3B82F6);

  // =============== LIGHT MODE COLORS ===============
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightBackgroundSecondary = Color(0xFFF8FAFC);
  static const Color lightCardBackground = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightDivider = Color(0xFFE2E8F0);
  
  // Old names for light mode (backward compatibility)
  static const Color textDark = lightTextPrimary;
  static const Color textLight = lightTextMuted;
  static const Color offWhite = lightBackgroundSecondary;
  static const Color lightGrey = lightBorder;
  static const Color mediumGrey = Color(0xFF94A3B8);
  static const Color darkGrey = Color(0xFF475569);
  static const Color almostBlack = Color(0xFF1E293B);

  // =============== DARK MODE COLORS ===============
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkBackgroundSecondary = Color(0xFF1E293B);
  static const Color darkCardBackground = Color(0xFF1E293B);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextMuted = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkDivider = Color(0xFF334155);

  // =============== CONTEXT-AWARE COLORS (USE THESE IN WIDGETS) ===============
  
  /// Get background color based on theme
  static Color getBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackground
        : lightBackground;
  }

  /// Get secondary background color based on theme
  static Color getBackgroundSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackgroundSecondary
        : lightBackgroundSecondary;
  }

  /// Get card background color based on theme
  static Color getCardBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkCardBackground
        : lightCardBackground;
  }

  /// Get primary text color based on theme
  static Color getTextPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextPrimary
        : lightTextPrimary;
  }

  /// Get secondary text color based on theme
  static Color getTextSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextSecondary
        : lightTextSecondary;
  }

  /// Get muted text color based on theme
  static Color getTextMuted(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextMuted
        : lightTextMuted;
  }

  /// Get border color based on theme
  static Color getBorder(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBorder
        : lightBorder;
  }

  /// Get divider color based on theme
  static Color getDivider(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkDivider
        : lightDivider;
  }

  /// Get icon color based on theme
  static Color getIconColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextPrimary
        : lightTextPrimary;
  }

  /// Get surface color based on theme
  static Color getSurfaceColor(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }

  // =============== STATIC COLORS (BACKWARD COMPATIBILITY) ===============
  static const Color background = lightBackground;
  static const Color backgroundSecondary = lightBackgroundSecondary;
  static const Color cardBackground = lightCardBackground;
  static const Color textPrimary = lightTextPrimary;
  static const Color textSecondary = lightTextSecondary;
  static const Color textMuted = lightTextMuted;
  static const Color textOnPrimary = pureWhite;
  static const Color textOnOrange = pureWhite;
  static const Color border = lightBorder;
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

  // =============== HELPER METHOD ===============
  
  /// Check if current theme is dark mode
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }
}