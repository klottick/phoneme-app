import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/core/course/backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Production configuration is supplied with --dart-define;
  // the course demo works without a backend or environment asset.
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (url.isNotEmpty && key.isNotEmpty) {
    await Supabase.initialize(url: url, anonKey: key);
    courseBackend = Supabase.instance.client;
  }

  runApp(const ProviderScope(child: LinguistApp()));
}
