import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the user lets wording the app does not recognize be sent to
/// Google Gemini. Kept on this device, and on until the user turns it off.
class GeminiPreference {
  GeminiPreference._();

  static const String _key = 'use_gemini';

  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled.value = prefs.getBool(_key) ?? true;
    } catch (_) {
      // Keep the current value if the device storage cannot be read.
    }
  }

  static Future<void> set(bool value) async {
    enabled.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (_) {
      // The choice still applies until the app is closed.
    }
  }
}
