import 'package:flutter/material.dart';

/// Linguist Design System
/// 
/// Color palette, typography, and spacing definitions
/// for consistent styling across the app.

class DesignColors {
  // Primary colors - Teal/Green for learning/calm
  static const Color primary = Color(0xFF236A4A);
  static const Color primaryLight = Color(0xFF4A9B7A);
  static const Color primaryDark = Color(0xFF004D40);
  
  // Secondary - Warm accent
  static const Color secondary = Color(0xFFFF9800);
  static const Color secondaryLight = Color(0xFFFFB74D);
  static const Color secondaryDark = Color(0xFFF57C00);
  
  // Semantic colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFEF5350);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);
  
  // Neutral colors - Light theme
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF212121);
  static const Color textSecondaryLight = Color(0xFF757575);
  
  // Neutral colors - Dark theme
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  
  // Streak colors
  static const Color streakFire = Color(0xFFFF5722);
  static const Color streakGold = Color(0xFFFFD700);
  
  // Practice colors for phonemes
  static const Color correctAnswer = Color(0xFF81C784);
  static const Color incorrectAnswer = Color(0xFFE57373);
}

class DesignTypography {
  static const String fontFamily = 'Roboto';
  
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 57,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.25,
  );
  
  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 45,
    fontWeight: FontWeight.w400,
  );
  
  static const TextStyle displaySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 36,
    fontWeight: FontWeight.w400,
  );
  
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w600,
  );
  
  static const TextStyle headlineMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w500,
  );
  
  static const TextStyle headlineSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w500,
  );
  
  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w500,
  );
  
  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
  );
  
  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
  );
  
  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );
  
  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );
  
  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );
}

class DesignSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);
}

class DesignRadius {
  static const double sm = 4.0;
  static const double md = 8.0;
  static const double lg = 12.0;
  static const double xl = 16.0;
  static const double full = 100.0;
  
  static const BorderRadius borderRadiusSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius borderRadiusMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius borderRadiusLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius borderRadiusXl = BorderRadius.all(Radius.circular(xl));
}

class DesignElevation {
  static const double none = 0.0;
  static const double sm = 1.0;
  static const double md = 2.0;
  static const double lg = 4.0;
  static const double xl = 8.0;
}

/// Accessibility-focused theme configuration
class DesignAccessibility {
  // Minimum touch target size (WCAG requirement)
  static const double minTouchTarget = 48.0;
  
  // Minimum text size for body text (readable)
  static const double minBodyText = 14.0;
  
  // Contrast ratios for accessibility
  static const double contrastRatioMedium = 4.5; // AA for normal text
  static const double contrastRatioHigh = 7.0; // AAA for normal text
  
  // Focus indicators
  static const double focusIndicatorWidth = 2.0;
}