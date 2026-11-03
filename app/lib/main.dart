import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:apply_track/app.dart';
import 'package:apply_track/router/app_router.dart';

void main() {
  runApp(ProviderScope(child: App(router: createAppRouter())));
}
