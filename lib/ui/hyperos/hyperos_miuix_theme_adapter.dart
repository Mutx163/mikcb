import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

/// Theme variant color map (replaces Forui's 10 themes).
class MiuixThemeVariant {
  const MiuixThemeVariant({
    required this.seedHex,
    required this.lightPrimary,
    required this.darkPrimary,
  });
  final String seedHex;
  final Color lightPrimary;
  final Color darkPrimary;
}

const Map<String, MiuixThemeVariant> kMiuixThemeVariants = {
  'neutral': MiuixThemeVariant(
    seedHex: '#171717',
    lightPrimary: Color(0xFF3482FF),
    darkPrimary: Color(0xFF277AF7),
  ),
  'zinc': MiuixThemeVariant(
    seedHex: '#18181B',
    lightPrimary: Color(0xFF3482FF),
    darkPrimary: Color(0xFF277AF7),
  ),
  'slate': MiuixThemeVariant(
    seedHex: '#0F172B',
    lightPrimary: Color(0xFF3482FF),
    darkPrimary: Color(0xFF277AF7),
  ),
  'blue': MiuixThemeVariant(
    seedHex: '#1447E6',
    lightPrimary: Color(0xFF1447E6),
    darkPrimary: Color(0xFF3B82F6),
  ),
  'green': MiuixThemeVariant(
    seedHex: '#5EA500',
    lightPrimary: Color(0xFF3482FF),
    darkPrimary: Color(0xFF277AF7),
  ),
  'orange': MiuixThemeVariant(
    seedHex: '#F54A00',
    lightPrimary: Color(0xFF3482FF),
    darkPrimary: Color(0xFF277AF7),
  ),
  'red': MiuixThemeVariant(
    seedHex: '#E7000B',
    lightPrimary: Color(0xFFE7000B),
    darkPrimary: Color(0xFFEF4444),
  ),
  'rose': MiuixThemeVariant(
    seedHex: '#EC003F',
    lightPrimary: Color(0xFFEC003F),
    darkPrimary: Color(0xFFF43F5E),
  ),
  'violet': MiuixThemeVariant(
    seedHex: '#7F22FE',
    lightPrimary: Color(0xFF3482FF),
    darkPrimary: Color(0xFF277AF7),
  ),
  'yellow': MiuixThemeVariant(
    seedHex: '#FCC800',
    lightPrimary: Color(0xFF3482FF),
    darkPrimary: Color(0xFF277AF7),
  ),
};

MiuixColors miuixColorsForVariant(String variant, {required bool dark}) {
  final v = kMiuixThemeVariants[variant];
  if (v == null) return dark ? darkColorScheme() : lightColorScheme();
  final primary = dark ? v.darkPrimary : v.lightPrimary;
  final onPrimary = primary.computeLuminance() > 0.5
      ? const Color(0xFF000000)
      : const Color(0xFFFFFFFF);
  return (dark ? darkColorScheme() : lightColorScheme()).copy(
    primary: primary,
    onPrimary: onPrimary,
    primaryVariant: primary,
    disabledPrimary: primary.withValues(alpha: 0.38),
    disabledPrimaryButton: primary.withValues(alpha: 0.38),
    disabledOnPrimaryButton: onPrimary.withValues(alpha: 0.38),
    primaryContainer: primary.withValues(alpha: 0.8),
    onPrimaryContainer: onPrimary,
    sliderKeyPointForeground: onPrimary,
  );
}

/// Builds Material [ThemeData] from [MiuixThemeData] (replaces forui.toApproximateMaterialTheme).
ThemeData miuixThemeDataToMaterial(
  MiuixThemeData miuix, {
  required String fontFamily,
  required List<String> fontFamilyFallback,
}) {
  final c = miuix.colors;
  final ts = miuix.textStyles;
  final colorScheme = ColorScheme(
    brightness: miuix.brightness,
    primary: c.primary,
    onPrimary: c.onPrimary,
    primaryContainer: c.primaryContainer,
    onPrimaryContainer: c.onPrimaryContainer,
    secondary: c.secondary,
    onSecondary: c.onSecondary,
    secondaryContainer: c.secondaryContainer,
    onSecondaryContainer: c.onSecondaryContainer,
    tertiary: c.tertiaryContainer,
    onTertiary: c.onTertiaryContainer,
    error: c.error,
    onError: c.onError,
    errorContainer: c.errorContainer,
    onErrorContainer: c.onErrorContainer,
    surface: c.surface,
    onSurface: c.onSurface,
    surfaceContainerHighest: c.surfaceContainerHighest,
    onSurfaceVariant: c.onSurfaceVariantSummary,
    outline: c.outline,
    outlineVariant: c.dividerLine,
    shadow: Colors.black,
    scrim: c.windowDimming,
    inverseSurface: c.onSurface,
    onInverseSurface: c.surface,
    inversePrimary: c.primary.withValues(alpha: 0.8),
  );
  final textTheme = TextTheme(
    displayLarge: ts.title1.copyWith(color: c.onBackground),
    displayMedium: ts.title2.copyWith(color: c.onBackground),
    displaySmall: ts.title3.copyWith(color: c.onBackground),
    headlineMedium: TextStyle(
      fontSize: 24,
      color: c.onBackground,
      fontWeight: FontWeight.w400,
    ),
    headlineSmall: ts.title4.copyWith(
      color: c.onBackground,
      fontWeight: FontWeight.w400,
    ),
    titleLarge: ts.title4.copyWith(fontSize: 20, color: c.onBackground),
    titleMedium: ts.body1.copyWith(
      fontWeight: FontWeight.w500,
      color: c.onSurface,
    ),
    titleSmall: ts.body2.copyWith(
      fontWeight: FontWeight.w500,
      color: c.onSurface,
    ),
    bodyLarge: ts.main.copyWith(color: c.onSurface),
    bodyMedium: ts.body1.copyWith(color: c.onSurface),
    bodySmall: ts.body2.copyWith(color: c.onSurface),
    labelLarge: ts.button.copyWith(color: c.onSurface),
    labelMedium: ts.footnote1.copyWith(color: c.onSurfaceVariantSummary),
    labelSmall: ts.footnote2.copyWith(color: c.onSurfaceVariantSummary),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: miuix.brightness,
    colorScheme: colorScheme,
    textTheme: textTheme.apply(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
    ),
    scaffoldBackgroundColor: c.background,
    appBarTheme: AppBarTheme(
      backgroundColor: c.surfaceContainer,
      foregroundColor: c.onSurfaceContainer,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: c.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerColor: c.dividerLine,
    dialogTheme: DialogThemeData(
      backgroundColor: c.surfaceContainer,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    iconTheme: IconThemeData(color: c.onSurfaceVariantActions),
    primaryIconTheme: IconThemeData(color: c.onPrimary),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        TargetPlatform.android: const CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
