import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kClaveTema = 'foody_theme_mode';

/// Preferencia de tema persistida (light / dark / system).
class TemaModeNotifier extends StateNotifier<ThemeMode> {
  TemaModeNotifier() : super(ThemeMode.light) {
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kClaveTema);
      state = switch (raw) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      };
    } catch (_) {
      // ponytail: sin prefs → light
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = switch (mode) {
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
        ThemeMode.light => 'light',
      };
      await prefs.setString(_kClaveTema, raw);
    } catch (_) {}
  }

  /// Alterna light ↔ dark (ignora system al ciclar desde el toggle admin).
  Future<void> alternar() async {
    final siguiente =
        state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setMode(siguiente);
  }

  bool get esOscuroEfectivo => state == ThemeMode.dark;
}

final temaModeProvider =
    StateNotifierProvider<TemaModeNotifier, ThemeMode>((ref) {
  return TemaModeNotifier();
});
