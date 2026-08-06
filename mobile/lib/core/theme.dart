import 'package:flutter/material.dart';

abstract final class AceColors {
  static const navy = Color(0xFF181847);
  static const navyDark = Color(0xFF101035);
  static const blue = Color(0xFF2C2C68);
  static const orange = Color(0xFFF44E1C);
  static const beige = Color(0xFFF1E4D1);
  static const beigeStrong = Color(0xFFF1E4D1);
  static const canvas = Color(0xFFFAF7F2);
  static const success = Color(0xFF198754);
  static const warning = Color(0xFFF3A712);
  static const danger = Color(0xFFB3261E);
}

ThemeData buildAceTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AceColors.navy,
    brightness: Brightness.light,
    primary: AceColors.navy,
    secondary: AceColors.orange,
    tertiary: AceColors.beige,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AceColors.canvas,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: AceColors.navy,
      foregroundColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AceColors.navy.withValues(alpha: .10)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AceColors.orange, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AceColors.orange,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AceColors.navy,
        side: const BorderSide(color: AceColors.navy),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AceColors.beigeStrong,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AceColors.orange
              : AceColors.navy,
        );
      }),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AceColors.orange,
      foregroundColor: Colors.white,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AceColors.orange,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AceColors.orange,
      selectionHandleColor: AceColors.orange,
    ),
  );
}
