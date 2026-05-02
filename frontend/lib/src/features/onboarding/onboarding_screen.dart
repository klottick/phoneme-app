import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  static const _languages = <String>['English', 'French', 'Japanese'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select target language')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _languages.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (BuildContext context, int index) {
          final language = _languages[index];
          return FilledButton.tonal(
            onPressed: () => context.go('/home'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(language),
            ),
          );
        },
      ),
    );
  }
}
