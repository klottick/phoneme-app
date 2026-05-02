import 'package:flutter/material.dart';

import 'routing/app_router.dart';

class PhonemeApp extends StatelessWidget {
  const PhonemeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Phoneme App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF236A4A)),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}
