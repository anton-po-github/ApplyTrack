import 'package:material_ui/material_ui.dart';

/// Shared frame for the sign in and sign up screens.
///
/// It shows the brand name and a short text, then [child] (the form).
/// Everything is centered on both axes. When the screen is too small
/// (small phone, open keyboard) the content scrolls instead of overflowing.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.description, required this.child});

  static const double maxWidth = 480;
  static const Key contentKey = Key('auth-layout-content');

  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints viewport) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: viewport.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: maxWidth),
                      child: Column(
                        key: contentKey,
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 24,
                        children: <Widget>[
                          _BrandHeader(description: description),
                          child,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            'ApplyTrack',
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          description,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
