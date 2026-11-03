import 'package:material_ui/material_ui.dart';
import 'package:phase2_widgets/features/layout_demo/widgets/demo_box.dart';
import 'package:phase2_widgets/features/layout_demo/widgets/section_title.dart';

class LayoutDemoScreen extends StatelessWidget {
  const LayoutDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Layout demo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const <Widget>[
          SectionTitle('Row + Expanded (flex 1 : 2)'),
          Row(
            spacing: 8,
            children: <Widget>[
              Expanded(child: DemoBox(label: 'flex 1')),
              Expanded(flex: 2, child: DemoBox(label: 'flex 2')),
            ],
          ),
          SectionTitle('Column'),
          Column(
            spacing: 8,
            children: <Widget>[
              DemoBox(label: 'A'),
              DemoBox(label: 'B'),
              DemoBox(label: 'C'),
            ],
          ),
          SectionTitle('Stack + Positioned'),
          _BadgeDemo(),
        ],
      ),
    );
  }
}

class _BadgeDemo extends StatelessWidget {
  const _BadgeDemo();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: <Widget>[
        DemoBox(label: 'Stack base', height: 120),
        Positioned(top: 8, right: 8, child: Badge(label: Text('New'))),
      ],
    );
  }
}
