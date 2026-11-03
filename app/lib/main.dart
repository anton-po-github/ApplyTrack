import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phase2_widgets/app.dart';
import 'package:phase2_widgets/router/app_router.dart';

void main() {
  runApp(ProviderScope(child: App(router: createAppRouter())));
}
