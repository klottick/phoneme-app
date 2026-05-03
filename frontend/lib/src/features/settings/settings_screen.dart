import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/supported_languages.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/theme_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageCode = ref.watch(selectedLanguageCodeProvider);
    final themeMode = ref.watch(themeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Theme section
          ListTile(
            leading: Icon(
              themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
            ),
            title: const Text('Appearance'),
            subtitle: Text(_getThemeLabel(themeMode)),
          ),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('Auto'),
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (modes) {
              ref.read(themeControllerProvider.notifier).setTheme(modes.first);
            },
          ),
          const Divider(),
          // Language section
          const ListTile(
            leading: Icon(Icons.language),
            title: Text('Learning Language'),
            subtitle: Text('Change your target language'),
          ),
          ...supportedLanguages.map(
            (lang) => RadioListTile<String>(
              title: Text(lang.label),
              value: lang.code,
              groupValue: languageCode,
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(onboardingControllerProvider.notifier)
                      .selectLanguage(value);
                }
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.record_voice_over),
            title: const Text('Text-to-Speech'),
            subtitle: const Text('Voice settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showTtsDialog(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Reset Progress',
                style: TextStyle(color: Colors.red)),
            subtitle: const Text('Clear all local data'),
            onTap: () => _showResetDialog(context, ref),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('About'),
            subtitle: Text('Linguist v0.1.0'),
          ),
          const Card(
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Credits',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('• IPA data: ipa-dict (MIT)'),
                  Text('• Audio: Wikipedia (CC BY-SA 3.0)'),
                  Text('• Backend: Supabase'),
                  Text('• Frontend: Flutter'),
                  SizedBox(height: 16),
                  Text(
                    'License: MIT',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Follow system';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  void _showTtsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Voice Settings'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('TTS voice is device-dependent.'),
            SizedBox(height: 16),
            ListTile(
              title: Text('Rate'),
              subtitle: Slider(
                value: 0.5,
                onChanged: null,
              ),
            ),
            ListTile(
              title: Text('Pitch'),
              subtitle: Slider(
                value: 1.0,
                min: 0.5,
                max: 2.0,
                onChanged: null,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Progress?'),
        content: const Text(
            'This will clear your streak and all local progress. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ref.read(streakServiceProvider).resetStreak();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Progress reset')),
                );
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}