import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/app_theme_type.dart';

class AppTheme {
  static ThemeData buildTheme(AppThemeType theme) {
    final primaryColor = theme.primaryColor;
    final fontFamily = theme.fontFamily;
    
    // Pure Light color scheme
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      surface: Colors.white,
      onSurface: const Color(0xFF111827), // Deep charcoal
      primary: primaryColor,
      onPrimary: Colors.white,
      secondary: const Color(0xFF6B7280), // Medium gray
      onSecondary: Colors.white,
      surfaceContainerHighest: const Color(0xFFF3F4F6), // Soft gray for containers
      onSurfaceVariant: const Color(0xFF4B5563),
      outline: const Color(0xFFE5E7EB), // Very subtle borders
      outlineVariant: const Color(0xFFD1D5DB),
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.transparent, // Let SpaceBackground show through
      textTheme: _buildTextTheme(colorScheme, fontFamily),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: GoogleFonts.getFont(
          fontFamily,
          color: const Color.fromRGBO(68, 0, 170, 1),
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.01,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color.fromRGBO(199, 70, 237, 1),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.getFont(
            fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.outline, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.getFont(
            fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.3)),
        ),
        color: const Color.fromRGBO(240, 230, 255, 1), // Very light soft purple
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color.fromRGBO(215, 195, 245, 1), // Distinct purple base matching theme
        indicatorColor: colorScheme.primary.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.getFont(fontFamily, color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12);
          }
          return GoogleFonts.getFont(fontFamily, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.primary);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color.fromRGBO(199, 70, 237, 0.1), // 10% opacity for text box background
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color.fromRGBO(199, 70, 237, 1), width: 2),
        ),
        labelStyle: GoogleFonts.getFont(fontFamily, color: colorScheme.onSurfaceVariant),
        hintStyle: GoogleFonts.getFont(fontFamily, color: colorScheme.outlineVariant),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: 0.05),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outline.withValues(alpha: 0.5),
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(
        color: colorScheme.onSurface,
      ),
    );
  }

  static TextTheme _buildTextTheme(ColorScheme colorScheme, String fontFamily) {
    const headingColor = Color.fromRGBO(68, 0, 170, 1);
    const subHeadingColor = Color.fromRGBO(196, 144, 253, 1);

    return TextTheme(
      displayLarge: GoogleFonts.getFont(
        fontFamily,
        fontSize: 48,
        fontWeight: FontWeight.w700,
        height: 56 / 48,
        letterSpacing: -0.02,
        color: headingColor,
      ),
      headlineLarge: GoogleFonts.getFont(
        fontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 40 / 32,
        letterSpacing: -0.01,
        color: headingColor,
      ),
      titleLarge: GoogleFonts.getFont(
        fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 32 / 24,
        color: headingColor,
      ),
      titleMedium: GoogleFonts.getFont(
        fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 28 / 20,
        color: headingColor,
      ),
      bodyLarge: GoogleFonts.getFont(
        fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: headingColor, // Default body text, but can be headingColor for consistency
      ),
      bodyMedium: GoogleFonts.getFont(
        fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: subHeadingColor,
      ),
      labelLarge: GoogleFonts.getFont(
        fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 20 / 14,
        color: headingColor,
      ),
      labelSmall: GoogleFonts.getFont(
        fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
        color: subHeadingColor,
      ),
    );
  }
}
