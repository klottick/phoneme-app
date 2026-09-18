import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/app_providers.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Linguist')),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                    padding: const EdgeInsets.all(24),
                    shrinkWrap: true,
                    children: [
                      Icon(Icons.hearing,
                          size: 72,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 24),
                      Text('A new language starts with new sounds.',
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 16),
                      const Text(
                          'Short pronunciation lessons. Playful practice. Built around the language you already know.'),
                      const SizedBox(height: 24),
                      const Card(
                          child: Column(children: [
                        ListTile(
                            leading: Icon(Icons.chat_bubble_outline),
                            title: Text('I speak English')),
                        ListTile(
                            leading: Icon(Icons.arrow_forward),
                            title: Text('I want to learn French')),
                      ])),
                      const SizedBox(height: 16),
                      FilledButton(
                          onPressed: () async {
                            await ref
                                .read(onboardingControllerProvider.notifier)
                                .selectCourse('en-fr');
                            if (context.mounted) context.go('/home');
                          },
                          child: const Text('Start English → French')),
                      const SizedBox(height: 12),
                      const Text(
                          'Our first course: French pronunciation for English speakers. No account needed to try it.'),
                    ]))),
      );
}
