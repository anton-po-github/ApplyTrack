import 'package:material_ui/material_ui.dart';

/// Temporary content for a tab. Step 11 replaces it.
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
