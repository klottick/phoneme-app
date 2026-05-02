import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routing/app_router.dart';

class LinguistApp extends StatelessWidget {
  const LinguistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LinguistAppView();
  }
}

class _LinguistAppView extends ConsumerWidget {
  const _LinguistAppView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Linguist',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF236A4A)),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
