import 'package:docnest/app/docnest_app.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Starts the DocNest window; every provider lives in the [ProviderScope] above it.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: DocNestApp()));
}
