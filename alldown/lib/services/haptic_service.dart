import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized service for subtle, responsive haptic feedback throughout AllDown.
/// Uses exclusively Flutter's built-in [HapticFeedback] class with zero third-party dependencies.
class HapticService {
  static const String prefKey = 'haptic_feedback_enabled';
  static bool _enabled = true;

  /// Returns whether haptic feedback is currently enabled by the user in Settings.
  static bool get isEnabled => _enabled;

  /// Initializes the haptic feedback preference from SharedPreferences.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(prefKey) ?? true;
    } catch (_) {
      _enabled = true;
    }
  }

  /// Sets whether haptics are enabled and persists the setting locally.
  static void setEnabled(bool value) {
    _enabled = value;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(prefKey, value);
    }).catchError((_) {});
  }

  /// 1. Laki dodir: Klik na standardne gumbe, odabir kvalitete videa/audija ili otvaranje izbornika.
  static void light() {
    if (!_enabled) return;
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// 2. Srednji udarac: Pokretanje preuzimanja (Download) ili potvrda važne radnje.
  static void medium() {
    if (!_enabled) return;
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// 3. Odabir: Pomicanje slidera, mijenjanje tabova ili prebacivanje prekidača (Switch/Toggle).
  static void selection() {
    if (!_enabled) return;
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// 4. Upozorenje / Greška: Neuspjelo preuzimanje, nevažeći URL ili brisanje stavke.
  static void error() {
    if (!_enabled) return;
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  // Intuitive semantic helpers for clean UI call sites:
  static void button() => light();
  static void download() => medium();
  static void confirm() => medium();
  static void slider() => selection();
  static void tab() => selection();
  static void toggle() => selection();
  static void delete() => error();
}
