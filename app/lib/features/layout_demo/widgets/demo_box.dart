import 'package:material_ui/material_ui.dart';

class DemoBox extends StatelessWidget {
  const new({required this.label, super.key, this.height = 56});

  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(color: colors.onPrimaryContainer)),
    );
  }
}
