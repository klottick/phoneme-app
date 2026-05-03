import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'design_system.dart';

class ThemeService {
  static const String _themeKey = 'theme_mode';

  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_themeKey);
    
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    String value;
    
    switch (mode) {
      case ThemeMode.light:
        value = 'light';
        break;
      case ThemeMode.dark:
        value = 'dark';
        break;
      case ThemeMode.system:
        value = 'system';
        break;
    }
    
    await prefs.setString(_themeKey, value);
  }
}

final themeServiceProvider = Provider<ThemeService>((ref) => ThemeService());

final lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: const ColorScheme.light(
    primary: DesignColors.primary,
    onPrimary: Colors.white,
    primaryContainer: DesignColors.primaryLight,
    secondary: DesignColors.secondary,
    onSecondary: Colors.white,
    secondaryContainer: DesignColors.secondaryLight,
    surface: DesignColors.surfaceLight,
    onSurface: DesignColors.textPrimaryLight,
    error: DesignColors.error,
    onError: Colors.white,
  ),
  scaffoldBackgroundColor: DesignColors.backgroundLight,
  
  // AppBar theme
  appBarTheme: const AppBarTheme(
    elevation: 0,
    centerTitle: true,
    backgroundColor: DesignColors.surfaceLight,
    foregroundColor: DesignColors.textPrimaryLight,
    surfaceTintColor: Colors.transparent,
  ),
  
  // Card theme
  cardTheme: const CardThemeData(
    elevation: DesignElevation.sm,
    shape: RoundedRectangleBorder(
      borderRadius: DesignRadius.borderRadiusMd,
    ),
    color: DesignColors.surfaceLight,
  ),
  
  // Button themes
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(88, DesignAccessibility.minTouchTarget),
      shape: const RoundedRectangleBorder(
        borderRadius: DesignRadius.borderRadiusMd,
      ),
    ),
  ),
  
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(88, DesignAccessibility.minTouchTarget),
      shape: const RoundedRectangleBorder(
        borderRadius: DesignRadius.borderRadiusMd,
      ),
    ),
  ),
  
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      minimumSize: const Size(64, DesignAccessibility.minTouchTarget),
    ),
  ),
  
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: DesignColors.primary,
    foregroundColor: Colors.white,
    elevation: DesignElevation.md,
  ),
  
  // Input decoration
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: DesignColors.surfaceLight,
    border: const OutlineInputBorder(
      borderRadius: DesignRadius.borderRadiusMd,
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: DesignRadius.borderRadiusMd,
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: DesignRadius.borderRadiusMd,
      borderSide: BorderSide(color: DesignColors.primary, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: DesignSpacing.md,
      vertical: DesignSpacing.sm,
    ),
  ),
  
  // List tile
  listTileTheme: const ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(horizontal: DesignSpacing.md),
    minVerticalPadding: DesignSpacing.sm,
  ),
  
  // Navigation bar
  navigationBarTheme: NavigationBarThemeData(
    indicatorColor: DesignColors.primaryLight.withValues(alpha: 0.3),
    labelTextStyle: WidgetStateProperty.all(
      DesignTypography.labelMedium,
    ),
  ),
  
  // Snackbar
  snackBarTheme: const SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: DesignRadius.borderRadiusMd,
    ),
  ),
  
  // Dialog
  dialogTheme: const DialogThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: DesignRadius.borderRadiusLg,
    ),
  ),
  
  // Bottom sheet
  bottomSheetTheme: const BottomSheetThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(DesignRadius.xl),
      ),
    ),
  ),
  
  // Typography
  textTheme: const TextTheme(
    displayLarge: DesignTypography.displayLarge,
    displayMedium: DesignTypography.displayMedium,
    displaySmall: DesignTypography.displaySmall,
    headlineLarge: DesignTypography.headlineLarge,
    headlineMedium: DesignTypography.headlineMedium,
    headlineSmall: DesignTypography.headlineSmall,
    titleLarge: DesignTypography.titleLarge,
    titleMedium: DesignTypography.titleMedium,
    titleSmall: DesignTypography.titleSmall,
    bodyLarge: DesignTypography.bodyLarge,
    bodyMedium: DesignTypography.bodyMedium,
    bodySmall: DesignTypography.bodySmall,
    labelLarge: DesignTypography.labelLarge,
    labelMedium: DesignTypography.labelMedium,
    labelSmall: DesignTypography.labelSmall,
  ),
  
  // Icon theme
  iconTheme: const IconThemeData(
    size: 24,
    color: DesignColors.textPrimaryLight,
  ),
  
  // Divider
  dividerTheme: DividerThemeData(
    color: Colors.grey.shade200,
    thickness: 1,
    space: 1,
  ),
);

final darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    primary: DesignColors.primaryLight,
    onPrimary: Colors.black,
    primaryContainer: DesignColors.primaryDark,
    secondary: DesignColors.secondary,
    onSecondary: Colors.black,
    secondaryContainer: DesignColors.secondaryDark,
    surface: DesignColors.surfaceDark,
    onSurface: DesignColors.textPrimaryDark,
    error: DesignColors.error,
    onError: Colors.white,
  ),
  scaffoldBackgroundColor: DesignColors.backgroundDark,
  
  // AppBar theme
  appBarTheme: const AppBarTheme(
    elevation: 0,
    centerTitle: true,
    backgroundColor: DesignColors.surfaceDark,
    foregroundColor: DesignColors.textPrimaryDark,
    surfaceTintColor: Colors.transparent,
  ),
  
  // Card theme
  cardTheme: const CardThemeData(
    elevation: DesignElevation.sm,
    shape: RoundedRectangleBorder(
      borderRadius: DesignRadius.borderRadiusMd,
    ),
    color: DesignColors.surfaceDark,
  ),
  
  // Button themes
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(88, DesignAccessibility.minTouchTarget),
      shape: const RoundedRectangleBorder(
        borderRadius: DesignRadius.borderRadiusMd,
      ),
    ),
  ),
  
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(88, DesignAccessibility.minTouchTarget),
      shape: const RoundedRectangleBorder(
        borderRadius: DesignRadius.borderRadiusMd,
      ),
    ),
  ),
  
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      minimumSize: const Size(64, DesignAccessibility.minTouchTarget),
    ),
  ),
  
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: DesignColors.primaryLight,
    foregroundColor: Colors.black,
    elevation: DesignElevation.md,
  ),
  
  // Input decoration
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: DesignColors.surfaceDark,
    border: const OutlineInputBorder(
      borderRadius: DesignRadius.borderRadiusMd,
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: DesignRadius.borderRadiusMd,
      borderSide: BorderSide(color: Colors.grey.shade700),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: DesignRadius.borderRadiusMd,
      borderSide: BorderSide(color: DesignColors.primaryLight, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: DesignSpacing.md,
      vertical: DesignSpacing.sm,
    ),
  ),
  
  // List tile
  listTileTheme: const ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(horizontal: DesignSpacing.md),
    minVerticalPadding: DesignSpacing.sm,
  ),
  
  // Navigation bar
  navigationBarTheme: NavigationBarThemeData(
    indicatorColor: DesignColors.primaryDark.withValues(alpha: 0.3),
    labelTextStyle: WidgetStateProperty.all(
      DesignTypography.labelMedium.copyWith(color: DesignColors.textPrimaryDark),
    ),
  ),
  
  // Snackbar
  snackBarTheme: const SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: DesignRadius.borderRadiusMd,
    ),
  ),
  
  // Dialog
  dialogTheme: const DialogThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: DesignRadius.borderRadiusLg,
    ),
    backgroundColor: DesignColors.surfaceDark,
  ),
  
  // Bottom sheet
  bottomSheetTheme: const BottomSheetThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(DesignRadius.xl),
      ),
    ),
    backgroundColor: DesignColors.surfaceDark,
  ),
  
  // Typography
  textTheme: TextTheme(
    displayLarge: DesignTypography.displayLarge.copyWith(color: DesignColors.textPrimaryDark),
    displayMedium: DesignTypography.displayMedium.copyWith(color: DesignColors.textPrimaryDark),
    displaySmall: DesignTypography.displaySmall.copyWith(color: DesignColors.textPrimaryDark),
    headlineLarge: DesignTypography.headlineLarge.copyWith(color: DesignColors.textPrimaryDark),
    headlineMedium: DesignTypography.headlineMedium.copyWith(color: DesignColors.textPrimaryDark),
    headlineSmall: DesignTypography.headlineSmall.copyWith(color: DesignColors.textPrimaryDark),
    titleLarge: DesignTypography.titleLarge.copyWith(color: DesignColors.textPrimaryDark),
    titleMedium: DesignTypography.titleMedium.copyWith(color: DesignColors.textPrimaryDark),
    titleSmall: DesignTypography.titleSmall.copyWith(color: DesignColors.textPrimaryDark),
    bodyLarge: DesignTypography.bodyLarge.copyWith(color: DesignColors.textPrimaryDark),
    bodyMedium: DesignTypography.bodyMedium.copyWith(color: DesignColors.textPrimaryDark),
    bodySmall: DesignTypography.bodySmall.copyWith(color: DesignColors.textSecondaryDark),
    labelLarge: DesignTypography.labelLarge.copyWith(color: DesignColors.textPrimaryDark),
    labelMedium: DesignTypography.labelMedium.copyWith(color: DesignColors.textPrimaryDark),
    labelSmall: DesignTypography.labelSmall.copyWith(color: DesignColors.textSecondaryDark),
  ),
  
  // Icon theme
  iconTheme: const IconThemeData(
    size: 24,
    color: DesignColors.textPrimaryDark,
  ),
  
  // Divider
  dividerTheme: DividerThemeData(
    color: Colors.grey.shade800,
    thickness: 1,
    space: 1,
  ),
);