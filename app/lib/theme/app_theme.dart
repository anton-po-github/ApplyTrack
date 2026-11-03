import 'package:material_ui/material_ui.dart';

abstract final class AppTheme {
  static const Color _seed = Color.fromARGB(255, 67, 181, 63);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: brightness,
      ),
    );
  }
}
