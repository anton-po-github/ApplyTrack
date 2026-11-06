import 'package:material_ui/material_ui.dart';

/// App theme with one brand color.
///
/// We do NOT use `ColorScheme.fromSeed`. It builds many lighter and darker
/// shades from one seed (containers, nav pill, chips, focus colors, ...).
/// Here every color role is set by hand, so every accent is exactly
/// [brand]. Surfaces and text are neutral grey (no color tint).
abstract final class AppTheme {
  static const Color brand = Color(0xFF4F46E5);
  static const Color _onBrand = Color(0xFFFFFFFF);

  // Errors keep a red color, so "Lost" and "due" stay easy to see.
  static const Color _error = Color(0xFFB3261E);
  static const Color _errorContainer = Color(0xFF8C1D18);

  static ThemeData light() => _build(_lightScheme);
  static ThemeData dark() => _build(_darkScheme);

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: brand,
    onPrimary: _onBrand,
    primaryContainer: brand,
    onPrimaryContainer: _onBrand,
    primaryFixed: brand,
    primaryFixedDim: brand,
    onPrimaryFixed: _onBrand,
    onPrimaryFixedVariant: _onBrand,
    secondary: brand,
    onSecondary: _onBrand,
    secondaryContainer: brand,
    onSecondaryContainer: _onBrand,
    secondaryFixed: brand,
    secondaryFixedDim: brand,
    onSecondaryFixed: _onBrand,
    onSecondaryFixedVariant: _onBrand,
    tertiary: brand,
    onTertiary: _onBrand,
    tertiaryContainer: brand,
    onTertiaryContainer: _onBrand,
    tertiaryFixed: brand,
    tertiaryFixedDim: brand,
    onTertiaryFixed: _onBrand,
    onTertiaryFixedVariant: _onBrand,
    error: _error,
    onError: _onBrand,
    errorContainer: _errorContainer,
    onErrorContainer: _onBrand,
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF111111),
    surfaceDim: Color(0xFFE6E6E6),
    surfaceBright: Color(0xFFFFFFFF),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF7F7F7),
    surfaceContainer: Color(0xFFF2F2F2),
    surfaceContainerHigh: Color(0xFFECECEC),
    surfaceContainerHighest: Color(0xFFE6E6E6),
    onSurfaceVariant: Color(0xFF5F5F5F),
    outline: Color(0xFF8A8A8A),
    outlineVariant: Color(0xFFCFCFCF),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF222222),
    onInverseSurface: Color(0xFFF2F2F2),
    inversePrimary: brand,
    surfaceTint: Color(0x00000000),
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: brand,
    onPrimary: _onBrand,
    primaryContainer: brand,
    onPrimaryContainer: _onBrand,
    primaryFixed: brand,
    primaryFixedDim: brand,
    onPrimaryFixed: _onBrand,
    onPrimaryFixedVariant: _onBrand,
    secondary: brand,
    onSecondary: _onBrand,
    secondaryContainer: brand,
    onSecondaryContainer: _onBrand,
    secondaryFixed: brand,
    secondaryFixedDim: brand,
    onSecondaryFixed: _onBrand,
    onSecondaryFixedVariant: _onBrand,
    tertiary: brand,
    onTertiary: _onBrand,
    tertiaryContainer: brand,
    onTertiaryContainer: _onBrand,
    tertiaryFixed: brand,
    tertiaryFixedDim: brand,
    onTertiaryFixed: _onBrand,
    onTertiaryFixedVariant: _onBrand,
    error: _error,
    onError: _onBrand,
    errorContainer: _errorContainer,
    onErrorContainer: _onBrand,
    surface: Color(0xFF121212),
    onSurface: Color(0xFFEDEDED),
    surfaceDim: Color(0xFF121212),
    surfaceBright: Color(0xFF2C2C2C),
    surfaceContainerLowest: Color(0xFF0D0D0D),
    surfaceContainerLow: Color(0xFF181818),
    surfaceContainer: Color(0xFF1C1C1C),
    surfaceContainerHigh: Color(0xFF232323),
    surfaceContainerHighest: Color(0xFF2C2C2C),
    onSurfaceVariant: Color(0xFFB0B0B0),
    outline: Color(0xFF8A8A8A),
    outlineVariant: Color(0xFF3A3A3A),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFEDEDED),
    onInverseSurface: Color(0xFF222222),
    inversePrimary: brand,
    surfaceTint: Color(0x00000000),
  );

  static ThemeData _build(ColorScheme scheme) {
    return ThemeData(
      colorScheme: scheme,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
    );
  }
}
