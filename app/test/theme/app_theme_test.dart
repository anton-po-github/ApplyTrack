import 'package:apply_track/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const brand = Color(0xFF4F46E5);

  for (final (String name, ThemeData theme) in <(String, ThemeData)>[
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    test('$name theme uses the exact brand color for all accent roles', () {
      final s = theme.colorScheme;
      expect(s.primary, brand);
      expect(s.primaryContainer, brand);
      expect(s.secondary, brand);
      expect(s.secondaryContainer, brand);
      expect(s.tertiary, brand);
      expect(s.tertiaryContainer, brand);
      expect(s.inversePrimary, brand);
    });

    test('$name theme has no surface tint', () {
      expect(theme.colorScheme.surfaceTint.a, 0);
    });
  }
}
