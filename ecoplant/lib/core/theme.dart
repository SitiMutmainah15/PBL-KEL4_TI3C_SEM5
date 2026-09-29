import 'package:flutter/material.dart';

abstract final class AppColors {
  static const forest900 = Color(0xFF244B2A);
  static const forest700 = Color(0xFF4F7B3A);
  static const leaf500 = Color(0xFFA6C94C);
  static const sun400 = Color(0xFFF6D365);
  static const cream100 = Color(0xFFFFF1D9);
  static const ink900 = Color(0xFF1F241F);
  static const ink600 = Color(0xFF667066);
  static const line200 = Color(0xFFDFE6DD);
  static const canvas = Color(0xFFF7F9F4);
  static const error = Color(0xFF9D3434);
}

ThemeData appTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    colorScheme: const ColorScheme.light(
      primary: AppColors.forest700,
      onPrimary: Colors.white,
      secondary: AppColors.forest900,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: AppColors.ink900,
      error: AppColors.error,
      outline: AppColors.ink600,
    ),
    scaffoldBackgroundColor: AppColors.canvas,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  return base.copyWith(
    textTheme: base.textTheme
        .copyWith(
          headlineLarge: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.forest900,
          ),
          headlineMedium: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.forest900,
          ),
          titleLarge: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.forest900,
          ),
          titleMedium: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.ink900,
          ),
          bodyLarge: const TextStyle(
            fontSize: 16,
            height: 1.5,
            color: AppColors.ink900,
          ),
          bodyMedium: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppColors.ink600,
          ),
        )
        .apply(fontFamily: 'Roboto'),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.canvas,
      foregroundColor: AppColors.forest900,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style:
          FilledButton.styleFrom(
            minimumSize: const Size(48, 52),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: shape,
            textStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ).copyWith(
            side: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.focused)
                  ? const BorderSide(color: AppColors.ink900, width: 3)
                  : BorderSide.none,
            ),
          ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: shape,
        side: const BorderSide(color: AppColors.forest700),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line200),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.cream100,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.forest900
              : AppColors.ink600,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? AppColors.forest900
              : AppColors.ink600,
        ),
      ),
    ),
  );
}
