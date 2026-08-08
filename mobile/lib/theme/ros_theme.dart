import 'package:flutter/material.dart';

/// Glass design tokens.
///
/// Surfaces are translucent — they only read correctly on top of
/// [GlassBackground] (installed once in `MaterialApp.builder`).
abstract final class RosColors {
  // Brand
  static const primary = Color(0xFF00614A);
  static const primaryContainer = Color(0x33008F6B);
  static const onPrimary = Color(0xFFFFFFFF);
  static const onPrimaryContainer = Color(0xFF00402F);
  static const secondary = Color(0xFF0F6B3E);
  static const secondaryContainer = Color(0x3320C273);
  static const onSecondaryContainer = Color(0xFF0B5230);

  // Aurora backdrop stops (used by GlassBackground)
  static const auroraTop = Color(0xFFDFF5EC);
  static const auroraMid = Color(0xFFEFF7F2);
  static const auroraBottom = Color(0xFFE4EEF6);
  static const auroraBlobA = Color(0x5500C08F);
  static const auroraBlobB = Color(0x44FFC46B);
  static const auroraBlobC = Color(0x4457A8FF);

  // Glass surfaces
  static const glass = Color(0x99FFFFFF); // panels
  static const glassStrong = Color(0xCCFFFFFF); // bars, sheets
  static const glassSoft = Color(0x55FFFFFF); // nested / secondary
  static const glassBorder = Color(0x66FFFFFF);
  static const glassShadow = Color(0x1A0B3B2E);

  // Aliases kept so existing screens restyle without edits.
  static const background = Color(0x00000000);
  static const surface = glass;
  static const surfaceContainer = glass;
  static const surfaceContainerLow = glassSoft;
  static const surfaceContainerLowest = glassStrong;
  static const surfaceDim = Color(0x33FFFFFF);

  static const onSurface = Color(0xFF11201B);
  static const onSurfaceVariant = Color(0xFF41544C);
  static const outline = Color(0xFF6C7F77);
  static const outlineVariant = Color(0x4D4A6B5E);

  static const error = Color(0xFFB3261E);
  static const errorContainer = Color(0x33E5484D);
  static const onError = Color(0xFFFFFFFF);
  static const paid = Color(0xFF0F6B3E);
  static const pending = Color(0xFF8A5300);
  static const pendingContainer = Color(0x40FFB020);
}

/// Shared glass geometry.
abstract final class RosGlass {
  static const blur = 18.0;
  static const radius = 20.0;
  static const border = BorderSide(color: RosColors.glassBorder, width: 1);
  static const shadow = [
    BoxShadow(
      color: RosColors.glassShadow,
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
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
    tertiary: Color(0xFF7A4A00),
    onTertiary: RosColors.onPrimary,
    tertiaryContainer: RosColors.pendingContainer,
    onTertiaryContainer: Color(0xFF5C3600),
    error: RosColors.error,
    onError: RosColors.onError,
    errorContainer: RosColors.errorContainer,
    onErrorContainer: Color(0xFF7A1710),
    surface: RosColors.glass,
    onSurface: RosColors.onSurface,
    onSurfaceVariant: RosColors.onSurfaceVariant,
    outline: RosColors.outline,
    outlineVariant: RosColors.outlineVariant,
    surfaceContainerHighest: RosColors.glassStrong,
    surfaceContainerHigh: RosColors.glass,
    surfaceContainer: RosColors.glass,
    surfaceContainerLow: RosColors.glassSoft,
    surfaceContainerLowest: RosColors.glassStrong,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.transparent,
    fontFamily: 'Roboto',
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: RosColors.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: RosColors.primary,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      indicatorColor: RosColors.secondaryContainer,
      indicatorShape: const StadiumBorder(
        side: BorderSide(color: RosColors.glassBorder),
      ),
      elevation: 0,
      height: 66,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: 'Roboto',
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
      backgroundColor: RosColors.glassSoft,
      shape: const StadiumBorder(side: RosGlass.border),
      side: RosGlass.border,
      showCheckmark: false,
      labelStyle: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: RosColors.onSurface,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: RosColors.glassSoft,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: RosColors.glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: RosColors.glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: RosColors.primary, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: RosColors.primary,
        foregroundColor: RosColors.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: RosColors.glassSoft,
        foregroundColor: RosColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(color: RosColors.glassBorder),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: RosColors.primary),
    ),
    cardTheme: CardThemeData(
      color: RosColors.glass,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RosGlass.radius),
        side: RosGlass.border,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: RosColors.glassBorder,
      thickness: 1,
      space: 1,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalBackgroundColor: Colors.transparent,
      modalElevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      showDragHandle: true,
      dragHandleColor: RosColors.outlineVariant,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: RosColors.glassStrong,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: RosGlass.border,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xF211201B),
      contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
      behavior: SnackBarBehavior.floating,
    ),
    listTileTheme: const ListTileThemeData(
      textColor: RosColors.onSurface,
      iconColor: RosColors.onSurfaceVariant,
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        height: 32 / 26,
        color: RosColors.onSurface,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: RosColors.onSurface,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 16,
        fontWeight: FontWeight.w600,
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
        fontWeight: FontWeight.w600,
        height: 16 / 11,
        letterSpacing: 0.5,
        color: RosColors.onSurfaceVariant,
      ),
    ),
  );
}
