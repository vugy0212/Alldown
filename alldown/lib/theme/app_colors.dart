import 'package:flutter/material.dart';

class AppColors {
  static bool isDark = true;

  // Surface & Canvas Palette
  static Color background = const Color(0xFF131319);
  static Color surface = const Color(0xFF131319);
  static Color surfaceDim = const Color(0xFF131319);
  static Color surfaceBright = const Color(0xFF39383F);
  
  static Color surfaceContainerLowest = const Color(0xFF0E0E14);
  static Color surfaceContainerLow = const Color(0xFF1B1B21);
  static Color surfaceContainer = const Color(0xFF1F1F25);
  static Color surfaceContainerHigh = const Color(0xFF2A2930);
  static Color surfaceContainerHighest = const Color(0xFF34343B);

  // Border & Hairlines
  static Color outline = const Color(0xFF908FA0);
  static Color outlineVariant = const Color(0xFF464554);
  static Color stroke = const Color(0xFF2E2E3E);

  // Content / Typography
  static Color onSurface = const Color(0xFFE4E1EA);
  static Color onSurfaceVariant = const Color(0xFFC7C4D7);
  static Color onBackground = const Color(0xFFE4E1EA);
  static Color textMuted = const Color(0xFF9CA3AF);

  // Brand Accents
  static Color primary = const Color(0xFFC0C1FF);
  static const Color primaryAccent = Color(0xFF6366F1); // Electric Indigo
  static Color onPrimary = const Color(0xFF1000A9);
  static Color primaryContainer = const Color(0xFF8083FF);
  static Color onPrimaryContainer = const Color(0xFF0D0096);
  static Color primaryFixed = const Color(0xFFE1E0FF);

  // Secondary Accents (Cyan)
  static Color secondary = const Color(0xFF4CD7F6); // Tactical Cyan
  static const Color secondaryAccent = Color(0xFF06B6D4);
  static Color onSecondary = const Color(0xFF003640);
  static Color secondaryContainer = const Color(0xFF03B5D3);
  static Color onSecondaryContainer = const Color(0xFF00424E);

  // Tertiary / Success (Emerald)
  static Color tertiary = const Color(0xFF4EDEA3); // Cyber Emerald
  static const Color tertiaryAccent = Color(0xFF10B981);
  static Color onTertiary = const Color(0xFF003824);
  static Color tertiaryContainer = const Color(0xFF00885D);
  static Color onTertiaryContainer = const Color(0xFF000703);

  // Alert & Error (Rose)
  static Color error = const Color(0xFFFFB4AB);
  static const Color errorAccent = Color(0xFFF43F5E);
  static Color onError = const Color(0xFF690005);
  static Color errorContainer = const Color(0xFF93000A);
  static Color onErrorContainer = const Color(0xFFFFDAD6);

  // Custom Gradients
  static LinearGradient get primaryGradient => LinearGradient(
    colors: [primaryContainer, primary, secondary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient progressGradient = LinearGradient(
    colors: [primaryAccent, secondaryAccent],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static LinearGradient get audioProgressGradient => LinearGradient(
    colors: [secondary, tertiary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static void setMode({required bool dark}) {
    isDark = dark;
    if (dark) {
      background = const Color(0xFF131319);
      surface = const Color(0xFF131319);
      surfaceDim = const Color(0xFF131319);
      surfaceBright = const Color(0xFF39383F);
      surfaceContainerLowest = const Color(0xFF0E0E14);
      surfaceContainerLow = const Color(0xFF1B1B21);
      surfaceContainer = const Color(0xFF1F1F25);
      surfaceContainerHigh = const Color(0xFF2A2930);
      surfaceContainerHighest = const Color(0xFF34343B);

      outline = const Color(0xFF908FA0);
      outlineVariant = const Color(0xFF464554);
      stroke = const Color(0xFF2E2E3E);

      onSurface = const Color(0xFFE4E1EA);
      onSurfaceVariant = const Color(0xFFC7C4D7);
      onBackground = const Color(0xFFE4E1EA);
      textMuted = const Color(0xFF9CA3AF);

      primary = const Color(0xFFC0C1FF);
      onPrimary = const Color(0xFF1000A9);
      primaryContainer = const Color(0xFF8083FF);
      onPrimaryContainer = const Color(0xFF0D0096);
      primaryFixed = const Color(0xFFE1E0FF);

      secondary = const Color(0xFF4CD7F6);
      onSecondary = const Color(0xFF003640);
      secondaryContainer = const Color(0xFF03B5D3);
      onSecondaryContainer = const Color(0xFF00424E);

      tertiary = const Color(0xFF4EDEA3);
      onTertiary = const Color(0xFF003824);
      tertiaryContainer = const Color(0xFF00885D);
      onTertiaryContainer = const Color(0xFF000703);

      error = const Color(0xFFFFB4AB);
      onError = const Color(0xFF690005);
      errorContainer = const Color(0xFF93000A);
      onErrorContainer = const Color(0xFFFFDAD6);
    } else {
      background = const Color(0xFFF3F4F8);
      surface = const Color(0xFFFFFFFF);
      surfaceDim = const Color(0xFFE5E7EB);
      surfaceBright = const Color(0xFFFFFFFF);
      surfaceContainerLowest = const Color(0xFFFFFFFF);
      surfaceContainerLow = const Color(0xFFF8F9FC);
      surfaceContainer = const Color(0xFFEFF1F6);
      surfaceContainerHigh = const Color(0xFFE5E8F0);
      surfaceContainerHighest = const Color(0xFFDCE0EA);

      outline = const Color(0xFF6B7280);
      outlineVariant = const Color(0xFFCBD5E1);
      stroke = const Color(0xFFD1D5DB);

      onSurface = const Color(0xFF111827);
      onSurfaceVariant = const Color(0xFF4B5563);
      onBackground = const Color(0xFF111827);
      textMuted = const Color(0xFF6B7280);

      primary = const Color(0xFF4F46E5);
      onPrimary = const Color(0xFFFFFFFF);
      primaryContainer = const Color(0xFFE0E7FF);
      onPrimaryContainer = const Color(0xFF1E1B4B);
      primaryFixed = const Color(0xFFC7D2FE);

      secondary = const Color(0xFF0284C7);
      onSecondary = const Color(0xFFFFFFFF);
      secondaryContainer = const Color(0xFFE0F2FE);
      onSecondaryContainer = const Color(0xFF0369A1);

      tertiary = const Color(0xFF059669);
      onTertiary = const Color(0xFFFFFFFF);
      tertiaryContainer = const Color(0xFFD1FAE5);
      onTertiaryContainer = const Color(0xFF065F46);

      error = const Color(0xFFDC2626);
      onError = const Color(0xFFFFFFFF);
      errorContainer = const Color(0xFFFEE2E2);
      onErrorContainer = const Color(0xFF991B1B);
    }
  }
}
