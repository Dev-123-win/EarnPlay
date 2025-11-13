import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Material 3 Expressive Theme System for EarnPlay
class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  // Material 3 Expressive Color System
  static const Color _primary = Color(0xFF6B5BFF); // Purple
  static const Color _onPrimary = Color(0xFFFFFFFF); // White
  static const Color _primaryContainer = Color(0xFFE8E0FF); // Soft purple
  static const Color _onPrimaryContainer = Color(0xFF21005D); // Dark purple

  static const Color _secondary = Color(0xFFFF6B9D); // Pink
  static const Color _onSecondary = Color(0xFFFFFFFF); // White
  static const Color _secondaryContainer = Color(0xFFFFD8E8); // Soft pink
  static const Color _onSecondaryContainer = Color(0xFF78003A);

  static const Color _tertiary = Color(0xFF1DD1A1); // Green (Success)
  static const Color _onTertiary = Color(0xFFFFFFFF); // White
  static const Color _tertiaryContainer = Color(0xFFB8F0D1); // Soft green
  static const Color _onTertiaryContainer = Color(0xFF002D1B);

  static const Color _error = Color(0xFFFF5252); // Red
  static const Color _onError = Color(0xFFFFFFFF); // White
  static const Color _errorContainer = Color(0xFFFFCDD2); // Soft red
  static const Color _onErrorContainer = Color(0xFF8B0000);

  static const Color _surface = Color(0xFFFFFFFF); // White
  static const Color _onSurface = Color(0xFF1A1A1A); // Dark text
  static const Color _surfaceDim = Color(0xFFF0F0F0);
  static const Color _surfaceBright = Color(0xFFFFFFFF);
  static const Color _outline = Color(0xFFB0B0B0); // Borders
  static const Color _outlineVariant = Color(0xFFD0D0D0); // Subtle borders

  // Game-Specific Colors
  static const Color _coinColor = Color(0xFFFFD700); // Gold - Rewards
  static const Color _energyColor = Color(0xFFFF6B9D); // Pink - Power
  static const Color _streakColor = Color(0xFFFF9500); // Orange - Multiplier

  /// Light theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: _primary,
        onPrimary: _onPrimary,
        primaryContainer: _primaryContainer,
        onPrimaryContainer: _onPrimaryContainer,
        secondary: _secondary,
        onSecondary: _onSecondary,
        secondaryContainer: _secondaryContainer,
        onSecondaryContainer: _onSecondaryContainer,
        tertiary: _tertiary,
        onTertiary: _onTertiary,
        tertiaryContainer: _tertiaryContainer,
        onTertiaryContainer: _onTertiaryContainer,
        error: _error,
        onError: _onError,
        errorContainer: _errorContainer,
        onErrorContainer: _onErrorContainer,
        surface: _surface,
        onSurface: _onSurface,
        outline: _outline,
        outlineVariant: _outlineVariant,
        surfaceDim: _surfaceDim,
        surfaceBright: _surfaceBright,
      ),
      textTheme: _buildTextTheme(brightness: Brightness.light),
      appBarTheme: const AppBarTheme(
        elevation: 2,
        backgroundColor: _primary,
        foregroundColor: _onPrimary,
        centerTitle: true,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _primary,
        foregroundColor: _onPrimary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: _onPrimary,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primary,
          side: const BorderSide(color: _primary, width: 1),
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primary,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: _surface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceDim,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _error, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _primaryContainer,
        selectedColor: _primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: GoogleFonts.manrope(
          color: _onPrimaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _surface,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: _outlineVariant,
        thickness: 1,
      ),
    );
  }

  /// Dark theme
  static ThemeData get darkTheme {
    const Color darkPrimary = Color(0xFFD0BCFF);
    const Color darkOnPrimary = Color(0xFF380070);
    const Color darkPrimaryContainer = Color(0xFF4F378B);
    const Color darkSurface = Color(0xFF1E1E1E);
    const Color darkOnSurface = Color(0xFFFFFFFF);
    const Color darkSecondary = Color(0xFFFFB1D9);
    const Color darkTertiary = Color(0xFF66D699);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: darkPrimary,
        onPrimary: darkOnPrimary,
        primaryContainer: darkPrimaryContainer,
        onPrimaryContainer: Color(0xFFE8E0FF),
        secondary: darkSecondary,
        onSecondary: Color(0xFF50213A),
        secondaryContainer: Color(0xFF78003A),
        onSecondaryContainer: Color(0xFFFFD8E8),
        tertiary: darkTertiary,
        onTertiary: Color(0xFF003B1E),
        tertiaryContainer: Color(0xFF005331),
        onTertiaryContainer: Color(0xFFB8F0D1),
        error: Color(0xFFFFB1B1),
        onError: Color(0xFF5C0A0A),
        errorContainer: Color(0xFF8B0000),
        onErrorContainer: Color(0xFFFFCDD2),
        surface: darkSurface,
        onSurface: darkOnSurface,
        outline: Color(0xFF9C9C9C),
        outlineVariant: Color(0xFF4A4A4A),
        surfaceDim: Color(0xFF121212),
        surfaceBright: Color(0xFF3A3A3A),
      ),
      textTheme: _buildTextTheme(brightness: Brightness.dark),
      appBarTheme: const AppBarTheme(
        elevation: 2,
        backgroundColor: darkPrimary,
        foregroundColor: darkOnPrimary,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: darkOnPrimary,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  /// Build text theme with Manrope font
  static TextTheme _buildTextTheme({required Brightness brightness}) {
    final baseTextTheme = brightness == Brightness.light
        ? GoogleFonts.manropeTextTheme()
        : GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme);

    return baseTextTheme.copyWith(
      // Display Sizes
      displayLarge: GoogleFonts.manrope(
        fontSize: 57,
        fontWeight: FontWeight.w800,
        height: 1.12,
        letterSpacing: 0,
      ),
      displayMedium: GoogleFonts.manrope(
        fontSize: 45,
        fontWeight: FontWeight.w700,
        height: 1.16,
        letterSpacing: 0,
      ),
      displaySmall: GoogleFonts.manrope(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        height: 1.22,
        letterSpacing: 0,
      ),
      // Headline Sizes
      headlineLarge: GoogleFonts.manrope(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: 0,
      ),
      headlineMedium: GoogleFonts.manrope(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.29,
        letterSpacing: 0,
      ),
      headlineSmall: GoogleFonts.manrope(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.33,
        letterSpacing: 0,
      ),
      // Title Sizes
      titleLarge: GoogleFonts.manrope(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        height: 1.27,
        letterSpacing: 0,
      ),
      titleMedium: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.5,
        letterSpacing: 0.16,
      ),
      titleSmall: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.43,
        letterSpacing: 0.1,
      ),
      // Body Sizes
      bodyLarge: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0.5,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.43,
        letterSpacing: 0.25,
      ),
      bodySmall: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w300,
        height: 1.33,
        letterSpacing: 0.4,
      ),
      // Label Sizes
      labelLarge: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.43,
        letterSpacing: 0.1,
      ),
      labelMedium: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.33,
        letterSpacing: 0.5,
      ),
      labelSmall: GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.45,
        letterSpacing: 0.5,
      ),
    );
  }

  // Utility color getters
  static const Color primaryColor = _primary;
  static const Color secondaryColor = _secondary;
  static const Color tertiaryColor = _tertiary;
  static const Color errorColor = _error;
  static const Color coinColor = _coinColor;
  static const Color energyColor = _energyColor;
  static const Color streakColor = _streakColor;
  static const Color outlineColor = _outline;
}
