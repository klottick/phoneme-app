import 'package:flutter/material.dart';

import 'space_course_colors.dart';

/// Applies the approved space-course palette without changing light mode or
/// the application's shared typography and semantic error/success colors.
ThemeData spaceCourseTheme(ThemeData inherited) {
  if (inherited.brightness != Brightness.dark) return inherited;

  final ColorScheme scheme = inherited.colorScheme.copyWith(
    primary: SpaceCourseColors.action,
    onPrimary: SpaceCourseColors.textPrimary,
    primaryContainer: SpaceCourseColors.selected,
    onPrimaryContainer: SpaceCourseColors.textPrimary,
    secondary: SpaceCourseColors.currentRing,
    onSecondary: SpaceCourseColors.textPrimary,
    secondaryContainer: SpaceCourseColors.raised,
    onSecondaryContainer: SpaceCourseColors.textPrimary,
    surface: SpaceCourseColors.panel,
    onSurface: SpaceCourseColors.textPrimary,
    onSurfaceVariant: SpaceCourseColors.textSecondary,
    surfaceContainerLowest: SpaceCourseColors.background,
    surfaceContainerLow: SpaceCourseColors.canvas,
    surfaceContainer: SpaceCourseColors.panel,
    surfaceContainerHigh: SpaceCourseColors.raised,
    surfaceContainerHighest: SpaceCourseColors.raised,
    outline: SpaceCourseColors.border,
    outlineVariant: SpaceCourseColors.border,
    surfaceTint: Colors.transparent,
  );
  const BorderSide focusBorder = BorderSide(
    color: SpaceCourseColors.currentRing,
    width: 2,
  );
  const Color disabledForeground = SpaceCourseColors.textSecondary;
  final TextTheme textTheme = inherited.textTheme;

  return inherited.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: SpaceCourseColors.background,
    canvasColor: SpaceCourseColors.canvas,
    disabledColor: disabledForeground,
    textTheme: textTheme.copyWith(
      displayLarge: textTheme.displayLarge?.copyWith(
        color: SpaceCourseColors.textPrimary,
      ),
      displayMedium: textTheme.displayMedium?.copyWith(
        color: SpaceCourseColors.textPrimary,
      ),
      displaySmall: textTheme.displaySmall?.copyWith(
        color: SpaceCourseColors.textPrimary,
      ),
      headlineLarge: textTheme.headlineLarge?.copyWith(
        color: SpaceCourseColors.textPrimary,
      ),
      headlineMedium: textTheme.headlineMedium?.copyWith(
        color: SpaceCourseColors.textPrimary,
      ),
      headlineSmall: textTheme.headlineSmall?.copyWith(
        color: SpaceCourseColors.textPrimary,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(
        color: SpaceCourseColors.textPrimary,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(
        color: SpaceCourseColors.textPrimary,
      ),
      titleSmall: textTheme.titleSmall?.copyWith(
        color: SpaceCourseColors.textPrimary,
      ),
      bodyLarge: textTheme.bodyLarge?.copyWith(
        color: SpaceCourseColors.textPrimary,
      ),
      bodyMedium: textTheme.bodyMedium?.copyWith(
        color: SpaceCourseColors.textPrimary,
      ),
      bodySmall: textTheme.bodySmall?.copyWith(
        color: SpaceCourseColors.textSecondary,
      ),
      labelLarge: textTheme.labelLarge?.copyWith(
        color: SpaceCourseColors.textPrimary,
      ),
      labelMedium: textTheme.labelMedium?.copyWith(
        color: SpaceCourseColors.textPrimary,
      ),
      labelSmall: textTheme.labelSmall?.copyWith(
        color: SpaceCourseColors.textSecondary,
      ),
    ),
    iconTheme: inherited.iconTheme.copyWith(
      color: SpaceCourseColors.textPrimary,
    ),
    appBarTheme: inherited.appBarTheme.copyWith(
      backgroundColor: SpaceCourseColors.background,
      foregroundColor: SpaceCourseColors.textPrimary,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: inherited.cardTheme.copyWith(
      color: SpaceCourseColors.panel,
      surfaceTintColor: Colors.transparent,
      shape:
          inherited.cardTheme.shape ??
          RoundedRectangleBorder(
            side: const BorderSide(color: SpaceCourseColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: inherited.filledButtonTheme.style?.minimumSize,
        shape: inherited.filledButtonTheme.style?.shape,
        side: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? const BorderSide(color: SpaceCourseColors.textPrimary, width: 2)
              : BorderSide.none,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? SpaceCourseColors.raised
              : SpaceCourseColors.action,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? disabledForeground
              : SpaceCourseColors.textPrimary,
        ),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return SpaceCourseColors.currentRing.withValues(alpha: 0.24);
          }
          if (states.contains(WidgetState.pressed)) {
            return SpaceCourseColors.selected;
          }
          return null;
        }),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: inherited.outlinedButtonTheme.style?.minimumSize,
        shape: inherited.outlinedButtonTheme.style?.shape,
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? disabledForeground
              : SpaceCourseColors.textPrimary,
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.focused)
                ? SpaceCourseColors.textPrimary
                : SpaceCourseColors.border,
            width: states.contains(WidgetState.focused) ? 2 : 1,
          ),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: inherited.textButtonTheme.style?.minimumSize,
        side: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? const BorderSide(color: SpaceCourseColors.textPrimary, width: 2)
              : BorderSide.none,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? disabledForeground
              : SpaceCourseColors.textSecondary,
        ),
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? SpaceCourseColors.currentRing.withValues(alpha: 0.24)
              : null,
        ),
      ),
    ),
    floatingActionButtonTheme: inherited.floatingActionButtonTheme.copyWith(
      backgroundColor: SpaceCourseColors.action,
      foregroundColor: SpaceCourseColors.textPrimary,
      focusColor: SpaceCourseColors.currentRing.withValues(alpha: 0.24),
    ),
    inputDecorationTheme: inherited.inputDecorationTheme.copyWith(
      fillColor: SpaceCourseColors.panel,
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: SpaceCourseColors.border),
      ),
      focusedBorder: const OutlineInputBorder(borderSide: focusBorder),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: inherited.colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: inherited.colorScheme.error, width: 2),
      ),
    ),
    navigationBarTheme: inherited.navigationBarTheme.copyWith(
      backgroundColor: SpaceCourseColors.background,
      indicatorColor: SpaceCourseColors.selected,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => inherited.textTheme.labelMedium?.copyWith(
          color: states.contains(WidgetState.selected)
              ? SpaceCourseColors.textPrimary
              : SpaceCourseColors.textSecondary,
        ),
      ),
    ),
    navigationRailTheme: inherited.navigationRailTheme.copyWith(
      backgroundColor: SpaceCourseColors.background,
      indicatorColor: SpaceCourseColors.selected,
    ),
    dialogTheme: inherited.dialogTheme.copyWith(
      backgroundColor: SpaceCourseColors.panel,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: inherited.bottomSheetTheme.copyWith(
      backgroundColor: SpaceCourseColors.panel,
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: inherited.dividerTheme.copyWith(
      color: SpaceCourseColors.border,
    ),
  );
}

/// A route-scoped bridge from the app's saved/system ThemeData to course style.
class SpaceCourseTheme extends StatelessWidget {
  const SpaceCourseTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData inherited = Theme.of(context);
    final ThemeData courseTheme = spaceCourseTheme(inherited).copyWith(
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
    return Theme(data: courseTheme, child: child);
  }
}
