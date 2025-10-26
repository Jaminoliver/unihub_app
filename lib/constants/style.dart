import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ===========================
/// UNI HUB GLOBAL STYLES
/// ===========================
class AppColors {
  static const Color primary = Color(0xFF0057D9);
  static const Color secondary = Color(0xFF2D9CDB);
  static const Color background = Color(0xFFF9FAFB);
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color textLight = Color(0xFF6C757D);
  static const Color success = Color(0xFF27AE60);
  static const Color warning = Color(0xFFF2C94C);
  static const Color danger = Color(0xFFEB5757);
}

class AppText {
  static TextStyle get heading => GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
  );

  static TextStyle get subheading => GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );

  static TextStyle get body =>
      GoogleFonts.inter(fontSize: 15, color: AppColors.textLight);

  static TextStyle get label => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textDark,
  );
}

class AppPadding {
  static const EdgeInsets screen = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 10,
  );
  static const EdgeInsets content = EdgeInsets.all(12);
}
