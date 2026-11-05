import 'package:material_ui/material_ui.dart';

/// Temporary content for a tab. Steps 8 and 11 replace it.
class PlaceholderBody extends StatelessWidget {
  const PlaceholderBody({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

/// Temporary full screen page (with a back button). Steps 9 and 10
/// replace it.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PlaceholderBody(text: text),
    );
  }
}
