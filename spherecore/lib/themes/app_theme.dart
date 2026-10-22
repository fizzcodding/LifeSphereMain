import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  AppTheme._();

  // SF-matched system colours
  static const systemBlue   = Color(0xFF007AFF);
  static const systemIndigo = Color(0xFF5856D6);
  static const systemGreen  = Color(0xFF34C759);
  static const systemRed    = Color(0xFFFF3B30);
  static const systemOrange = Color(0xFFFF9500);

  // Semantic surface stack (light)
  static const background      = Color(0xFFF2F2F7); // iOS grouped bg
  static const surface         = Color(0xFFFFFFFF); // primary grouped cell
  static const surfaceElevated = Color(0xFFFFFFFF);
  static const surfaceGlass    = Color(0xCCFFFFFF); // 80% white for blur layer

  // Label hierarchy (light) — matches iOS label / secondaryLabel / tertiaryLabel
  static const label          = Color(0xFF000000);
  static const labelSecondary = Color(0xFF3C3C43); // ~60% opacity visually
  static const labelTertiary  = Color(0xFF3C3C43);
  static const labelQuaternary= Color(0xFF3C3C43);
  static const separator      = Color(0xFFC6C6C8);
  static const opaqueSeparator= Color(0xFFE5E5EA);

  // Accent — iOS blue
  static const accent  = systemBlue;
  static const danger  = systemRed;
  static const success = systemGreen;

  // Radius tokens
  static const double radiusSm  = 10.0;
  static const double radiusMd  = 14.0;
  static const double radiusLg  = 20.0;
  static const double radiusXl  = 28.0;

  // Spacing tokens (8pt grid)
  static const double sp4  = 4.0;
  static const double sp8  = 8.0;
  static const double sp12 = 12.0;
  static const double sp16 = 16.0;
  static const double sp20 = 20.0;
  static const double sp24 = 24.0;
  static const double sp32 = 32.0;

  // Shadow — subtle, Apple-style (not Material elevation)
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get sheetShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 40,
      offset: const Offset(0, -2),
    ),
  ];

  // Glass material decoration used for nav chrome
  static BoxDecoration get glassMaterial => BoxDecoration(
    color: surfaceGlass,
    border: Border(
      top: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 0.5),
    ),
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      // Use system font — closest to SF Pro on Android is the device default
      fontFamily: null,
      scaffoldBackgroundColor: background,
      primaryColor: accent,
      colorScheme: ColorScheme.light(
        primary: accent,
        secondary: systemIndigo,
        error: danger,
        surface: surface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onError: Colors.white,
        onSurface: label,
        surfaceContainerHighest: background,
      ),

      // Typography — size-specific tracking, iOS Dynamic Type scale
      textTheme: const TextTheme(
        // Large title: 34pt tight tracking
        displayLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.12,
          color: label,
        ),
        // Title 1: 28pt
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          height: 1.14,
          color: label,
        ),
        // Title 2: 22pt
        displaySmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.26,
          height: 1.18,
          color: label,
        ),
        // Title 3: 20pt
        headlineLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          height: 1.2,
          color: label,
        ),
        // Headline: 17pt semibold
        headlineMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.41,
          height: 1.29,
          color: label,
        ),
        // Body: 17pt regular
        bodyLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.41,
          height: 1.29,
          color: label,
        ),
        // Callout: 16pt
        bodyMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.32,
          height: 1.31,
          color: labelSecondary,
        ),
        // Subheadline: 15pt
        bodySmall: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.24,
          height: 1.33,
          color: labelSecondary,
        ),
        // Footnote: 13pt — slightly positive tracking for legibility
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.07,
          height: 1.38,
          color: labelTertiary,
        ),
        // Caption: 12pt
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.0,
          height: 1.33,
          color: labelTertiary,
        ),
        // Caption 2: 11pt
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.07,
          height: 1.18,
          color: labelQuaternary,
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: accent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.41,
          color: label,
        ),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.41,
          color: label,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
        showDragHandle: true,
        dragHandleColor: opaqueSeparator,
        dragHandleSize: const Size(36, 4),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: sp16, vertical: sp12),
        labelStyle: const TextStyle(fontSize: 15, color: labelSecondary),
        hintStyle: const TextStyle(fontSize: 17, color: labelTertiary),
        prefixIconColor: accent,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: opaqueSeparator),
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: opaqueSeparator),
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: accent, width: 1.5),
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: danger),
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(horizontal: sp24, vertical: sp12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.41,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.41,
          ),
          padding: const EdgeInsets.symmetric(horizontal: sp8, vertical: sp4),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: CircleBorder(),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: sp16, vertical: sp4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
        tileColor: surface,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? success : opaqueSeparator,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      dividerTheme: const DividerThemeData(
        color: opaqueSeparator,
        thickness: 0.5,
        indent: sp16,
        endIndent: 0,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(color: accent),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: accent,
        unselectedItemColor: labelTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
        unselectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w400),
      ),
    );
  }
}
