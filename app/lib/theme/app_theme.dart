import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colors sampled straight from the RadioBox mark (assets/branding/icon.png):
/// an orange-to-pink gradient microphone with a deep-purple soundwave.
class AppColors {
  const AppColors._();

  static const orange = Color(0xFFFFA34D);
  static const coral = Color(0xFFFF7A66);
  static const pink = Color(0xFFFF2D6B);
  static const purple = Color(0xFF4A2E7A);

  static const background = Color(0xFF0C0C11);
  static const surface = Color(0xFF19191F);
  static const surfaceRaised = Color(0xFF232330);
  static const textMuted = Color(0xFFA0A0AC);

  /// Flat solid accent for buttons/CTAs (play buttons, active tab, "Kaydet"
  /// style filled buttons) — a single warm orange, not a gradient.
  static const accent = Color(0xFFFF7A33);

  /// The mark's own top-to-bottom gradient — decorative only now (the logo
  /// asset itself, fallback art tiles). Buttons use the flat [accent]
  /// instead, to match the reference UI kit's flat CTA style.
  static const brandGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [orange, pink],
  );
}

/// Radii shared by cards, hero banners, sheets, and buttons so the whole
/// app reads as one rounded, "premium dark UI kit" system rather than
/// stock Material defaults.
class AppRadii {
  const AppRadii._();

  static const card = 24.0;
  static const pill = 999.0;
}

ThemeData buildAppTheme(Color seedColor) {
  final base = ThemeData(
    colorSchemeSeed: seedColor,
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
  );

  final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).copyWith(
    headlineSmall: GoogleFonts.poppins(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      color: Colors.white,
      height: 1.2,
    ),
    titleLarge: GoogleFonts.poppins(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    ),
    titleMedium: GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    ),
    bodyMedium: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
    bodySmall: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
    labelSmall: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
  );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: Colors.white70,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: textTheme.titleMedium,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      backgroundColor: AppColors.surfaceRaised,
      labelStyle: textTheme.bodyMedium,
      side: BorderSide.none,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
      ),
    ),
  );
}
