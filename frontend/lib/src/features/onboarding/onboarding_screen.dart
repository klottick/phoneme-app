import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/supported_languages.dart';
import '../../core/providers/app_providers.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose learning language')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: supportedLanguages.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (BuildContext context, int index) {
          final language = supportedLanguages[index];
          return FilledButton.tonal(
            onPressed: () async {
              await ref
                  .read(onboardingControllerProvider.notifier)
                  .selectLanguage(language.code);
              if (!context.mounted) {
                return;
              }
              context.go('/home');
            },
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(language.label),
            ),
          );
        },
      ),
    );
  }
}
