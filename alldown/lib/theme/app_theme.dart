import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static TextTheme _buildTextTheme({required Color onSurface, required Color onSurfaceVariant}) {
    return TextTheme(
      displayLarge: GoogleFonts.plusJakartaSans(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.02,
        color: onSurface,
      ),
      displayMedium: GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.02,
        color: onSurface,
      ),
      headlineLarge: GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.01,
        color: onSurface,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      headlineSmall: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.01,
        color: onSurface,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.01,
        color: onSurface,
      ),
      titleSmall: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.01,
        color: onSurface,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.01,
        color: onSurface,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.02,
        color: onSurfaceVariant,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.01,
        color: onSurface,
      ),
      labelMedium: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.02,
        color: onSurfaceVariant,
      ),
      labelSmall: GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.04,
        color: onSurfaceVariant,
      ),
    );
  }

  static ThemeData get darkTheme {
    final textTheme = _buildTextTheme(
      onSurface: const Color(0xFFE4E1EA),
      onSurfaceVariant: const Color(0xFFC7C4D7),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF131319),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFC0C1FF),
        onPrimary: Color(0xFF1000A9),
        primaryContainer: Color(0xFF8083FF),
        onPrimaryContainer: Color(0xFF0D0096),
        secondary: Color(0xFF4CD7F6),
        onSecondary: Color(0xFF003640),
        secondaryContainer: Color(0xFF03B5D3),
        onSecondaryContainer: Color(0xFF00424E),
        tertiary: Color(0xFF4EDEA3),
        onTertiary: Color(0xFF003824),
        tertiaryContainer: Color(0xFF00885D),
        onTertiaryContainer: Color(0xFF000703),
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
        errorContainer: Color(0xFF93000A),
        onErrorContainer: Color(0xFFFFDAD6),
        surface: Color(0xFF131319),
        onSurface: Color(0xFFE4E1EA),
        onSurfaceVariant: Color(0xFFC7C4D7),
        outline: Color(0xFF908FA0),
        outlineVariant: Color(0xFF464554),
      ),
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: const Color(0xFF1F1F25),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2E2E3E), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF0D0096);
          }
          return const Color(0xFFC7C4D7);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF8083FF);
          }
          return const Color(0xFF34343B);
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primaryAccent,
        inactiveTrackColor: const Color(0xFF0E0E14),
        thumbColor: const Color(0xFFC0C1FF),
        overlayColor: AppColors.primaryAccent.withValues(alpha: 0.15),
      ),
    );
  }

  static ThemeData get lightTheme {
    final textTheme = _buildTextTheme(
      onSurface: const Color(0xFF111827),
      onSurfaceVariant: const Color(0xFF4B5563),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF3F4F8),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF4F46E5),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFE0E7FF),
        onPrimaryContainer: Color(0xFF1E1B4B),
        secondary: Color(0xFF0284C7),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFE0F2FE),
        onSecondaryContainer: Color(0xFF0369A1),
        tertiary: Color(0xFF059669),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFD1FAE5),
        onTertiaryContainer: Color(0xFF065F46),
        error: Color(0xFFDC2626),
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFEE2E2),
        onErrorContainer: Color(0xFF991B1B),
        surface: Color(0xFFFFFFFF),
        onSurface: Color(0xFF111827),
        onSurfaceVariant: Color(0xFF4B5563),
        outline: Color(0xFF6B7280),
        outlineVariant: Color(0xFFCBD5E1),
      ),
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: const Color(0xFFEFF1F6),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return const Color(0xFF6B7280);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF4F46E5);
          }
          return const Color(0xFFDCE0EA);
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primaryAccent,
        inactiveTrackColor: const Color(0xFFE5E8F0),
        thumbColor: const Color(0xFF4F46E5),
        overlayColor: AppColors.primaryAccent.withValues(alpha: 0.15),
      ),
    );
  }
}
