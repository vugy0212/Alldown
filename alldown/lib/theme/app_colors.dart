import 'package:flutter/material.dart';

class AppColors {
  // Surface & Canvas Palette
  static const Color background = Color(0xFF131319);
  static const Color surface = Color(0xFF131319);
  static const Color surfaceDim = Color(0xFF131319);
  static const Color surfaceBright = Color(0xFF39383F);
  
  static const Color surfaceContainerLowest = Color(0xFF0E0E14);
  static const Color surfaceContainerLow = Color(0xFF1B1B21);
  static const Color surfaceContainer = Color(0xFF1F1F25);
  static const Color surfaceContainerHigh = Color(0xFF2A2930);
  static const Color surfaceContainerHighest = Color(0xFF34343B);

  // Border & Hairlines
  static const Color outline = Color(0xFF908FA0);
  static const Color outlineVariant = Color(0xFF464554);
  static const Color stroke = Color(0xFF2E2E3E);

  // Content / Typography
  static const Color onSurface = Color(0xFFE4E1EA);
  static const Color onSurfaceVariant = Color(0xFFC7C4D7);
  static const Color onBackground = Color(0xFFE4E1EA);
  static const Color textMuted = Color(0xFF9CA3AF);

  // Brand Accents
  static const Color primary = Color(0xFFC0C1FF);
  static const Color primaryAccent = Color(0xFF6366F1); // Electric Indigo
  static const Color onPrimary = Color(0xFF1000A9);
  static const Color primaryContainer = Color(0xFF8083FF);
  static const Color onPrimaryContainer = Color(0xFF0D0096);
  static const Color primaryFixed = Color(0xFFE1E0FF);

  // Secondary Accents (Cyan)
  static const Color secondary = Color(0xFF4CD7F6); // Tactical Cyan
  static const Color secondaryAccent = Color(0xFF06B6D4);
  static const Color onSecondary = Color(0xFF003640);
  static const Color secondaryContainer = Color(0xFF03B5D3);
  static const Color onSecondaryContainer = Color(0xFF00424E);

  // Tertiary / Success (Emerald)
  static const Color tertiary = Color(0xFF4EDEA3); // Cyber Emerald
  static const Color tertiaryAccent = Color(0xFF10B981);
  static const Color onTertiary = Color(0xFF003824);
  static const Color tertiaryContainer = Color(0xFF00885D);
  static const Color onTertiaryContainer = Color(0xFF000703);

  // Alert & Error (Rose)
  static const Color error = Color(0xFFFFB4AB);
  static const Color errorAccent = Color(0xFFF43F5E);
  static const Color onError = Color(0xFF690005);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onErrorContainer = Color(0xFFFFDAD6);

  // Custom Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryContainer, primary, secondary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient progressGradient = LinearGradient(
    colors: [primaryAccent, secondary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient audioProgressGradient = LinearGradient(
    colors: [secondary, tertiary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

