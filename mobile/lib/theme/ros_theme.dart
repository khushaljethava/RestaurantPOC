import 'package:flutter/material.dart';

/// Efficient Vendor Service tokens from stitch DESIGN.md.
abstract final class RosColors {
  static const primary = Color(0xFF00513E);
  static const primaryContainer = Color(0xFF156B54);
  static const onPrimary = Color(0xFFFFFFFF);
  static const onPrimaryContainer = Color(0xFF9AE9CB);
  static const secondary = Color(0xFF1B6C3D);
  static const secondaryContainer = Color(0xFFA4F4B8);
  static const onSecondaryContainer = Color(0xFF237242);
  static const background = Color(0xFFF5FBF5);
  static const surface = Color(0xFFF5FBF5);
  static const surfaceContainer = Color(0xFFE9EFEA);
  static const surfaceContainerLow = Color(0xFFEFF5F0);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceDim = Color(0xFFD5DCD6);
  static const onSurface = Color(0xFF171D1A);
  static const onSurfaceVariant = Color(0xFF3F4944);
  static const outline = Color(0xFF6F7974);
  static const outlineVariant = Color(0xFFBEC9C3);
  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onError = Color(0xFFFFFFFF);
  static const paid = Color(0xFF1B6C3D);
  static const pending = Color(0xFF8A5300);
  static const pendingContainer = Color(0xFFFFF0D4);
}

ThemeData buildRosTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: RosColors.primary,
    onPrimary: RosColors.onPrimary,
    primaryContainer: RosColors.primaryContainer,
    onPrimaryContainer: RosColors.onPrimaryContainer,
    secondary: RosColors.secondary,
    onSecondary: RosColors.onPrimary,
    secondaryContainer: RosColors.secondaryContainer,
    onSecondaryContainer: RosColors.onSecondaryContainer,
    tertiary: Color(0xFF673D00),
    onTertiary: RosColors.onPrimary,
    tertiaryContainer: Color(0xFF885200),
    onTertiaryContainer: Color(0xFFFFD0A0),
    error: RosColors.error,
    onError: RosColors.onError,
    errorContainer: RosColors.errorContainer,
    onErrorContainer: Color(0xFF93000A),
    surface: RosColors.surface,
    onSurface: RosColors.onSurface,
    onSurfaceVariant: RosColors.onSurfaceVariant,
    outline: RosColors.outline,
    outlineVariant: RosColors.outlineVariant,
    surfaceContainerHighest: Color(0xFFDEE4DF),
    surfaceContainerHigh: Color(0xFFE4EAE4),
    surfaceContainer: RosColors.surfaceContainer,
    surfaceContainerLow: RosColors.surfaceContainerLow,
    surfaceContainerLowest: Color(0xFFFFFFFF),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: RosColors.background,
    fontFamily: 'Roboto',
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: RosColors.surfaceContainer,
      foregroundColor: RosColors.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: RosColors.primary,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: RosColors.surfaceContainerLow,
      indicatorColor: RosColors.secondaryContainer,
      elevation: 0,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: 'Roboto',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: selected
              ? RosColors.onSecondaryContainer
              : RosColors.onSurfaceVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected
              ? RosColors.onSecondaryContainer
              : RosColors.onSurfaceVariant,
        );
      }),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: const StadiumBorder(),
      side: BorderSide.none,
      labelStyle: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: RosColors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: RosColors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: RosColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: const BorderSide(color: RosColors.outlineVariant),
      ),
    ),
    cardTheme: CardThemeData(
      color: RosColors.surfaceContainer,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: RosColors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      showDragHandle: true,
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 24,
        fontWeight: FontWeight.w400,
        height: 32 / 24,
        color: RosColors.onSurface,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: RosColors.onSurface,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 24 / 16,
        color: RosColors.onSurface,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: RosColors.onSurface,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: RosColors.onSurfaceVariant,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 16 / 11,
        letterSpacing: 0.5,
        color: RosColors.onSurfaceVariant,
      ),
    ),
  );
}
