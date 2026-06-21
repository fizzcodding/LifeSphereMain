import 'package:flutter/material.dart';

class AppTheme {
  static const primary = Color(0xFF303D67);
  static const secondary = Color(0xFF3E8299);
  static const danger = Color(0xFF5C4E4E);
  static const background = Color(0xFFF8F6F3);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF263044);
  static const muted = Color(0xFF6D7280);
  static const border = Color(0xFFE8E2DA);

  static BoxShadow get softShadow => BoxShadow(
    color: Colors.black.withValues(alpha: 0.07),
    blurRadius: 28,
    offset: const Offset(0, 12),
  );

  static ThemeData get lightTheme {
    final base = ThemeData(
      brightness: Brightness.light,
      fontFamily: 'Poppins',
      useMaterial3: true,
    );
    return base.copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        error: danger,
        surface: surface,
        onPrimary: surface,
        onSecondary: surface,
        onError: surface,
        onSurface: ink,
      ),
      textTheme: base.textTheme.copyWith(
        displayLarge: const TextStyle(
          fontFamily: 'Georgia',
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
        headlineMedium: const TextStyle(
          fontFamily: 'Georgia',
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
        titleLarge: const TextStyle(
          fontFamily: 'Georgia',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
        titleMedium: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        bodyLarge: const TextStyle(
          fontSize: 16,
          height: 1.45,
          color: ink,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          height: 1.4,
          color: muted,
        ),
        labelLarge: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: primary,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        labelStyle: const TextStyle(color: muted),
        hintStyle: const TextStyle(color: Color(0xFF9C9A96)),
        prefixIconColor: secondary,
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: border),
          borderRadius: BorderRadius.circular(18),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: border),
          borderRadius: BorderRadius.circular(18),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: secondary, width: 1.5),
          borderRadius: BorderRadius.circular(18),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: danger),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: surface,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: secondary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? primary : muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? secondary.withValues(alpha: 0.35)
              : border,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: secondary,
        inactiveTrackColor: border,
        thumbColor: primary,
        overlayColor: secondary.withValues(alpha: 0.12),
        trackHeight: 5,
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: secondary,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: muted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
    );
  }
}
