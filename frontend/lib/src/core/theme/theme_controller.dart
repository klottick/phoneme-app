import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme.dart';

class ThemeController extends StateNotifier<ThemeMode> {
  final Ref _ref;

  ThemeController(this._ref) : super(ThemeMode.system) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final service = _ref.read(themeServiceProvider);
    final mode = await service.getThemeMode();
    state = mode;
  }

  Future<void> setTheme(ThemeMode mode) async {
    final service = _ref.read(themeServiceProvider);
    await service.setThemeMode(mode);
    state = mode;
  }

  Future<void> toggleTheme() async {
    final newMode = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await setTheme(newMode);
  }
}

final themeControllerProvider =
    StateNotifierProvider<ThemeController, ThemeMode>((ref) {
  return ThemeController(ref);
});