import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccessibilitySettings {
  final double fontScale;
  final bool highContrast;
  final bool reduceMotion;
  final bool screenReader;
  final double audioFeedbackVolume;
  final bool hapticFeedback;
  final int debounceMs;

  const AccessibilitySettings({
    this.fontScale = 1.0,
    this.highContrast = false,
    this.reduceMotion = false,
    this.screenReader = false,
    this.audioFeedbackVolume = 1.0,
    this.hapticFeedback = true,
    this.debounceMs = 300,
  });

  AccessibilitySettings copyWith({
    double? fontScale,
    bool? highContrast,
    bool? reduceMotion,
    bool? screenReader,
    double? audioFeedbackVolume,
    bool? hapticFeedback,
    int? debounceMs,
  }) {
    return AccessibilitySettings(
      fontScale: fontScale ?? this.fontScale,
      highContrast: highContrast ?? this.highContrast,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      screenReader: screenReader ?? this.screenReader,
      audioFeedbackVolume: audioFeedbackVolume ?? this.audioFeedbackVolume,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      debounceMs: debounceMs ?? this.debounceMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'fontScale': fontScale,
        'highContrast': highContrast,
        'reduceMotion': reduceMotion,
        'screenReader': screenReader,
        'audioFeedbackVolume': audioFeedbackVolume,
        'hapticFeedback': hapticFeedback,
        'debounceMs': debounceMs,
      };

  factory AccessibilitySettings.fromJson(Map<String, dynamic> json) => AccessibilitySettings(
        fontScale: json['fontScale'] as double? ?? 1.0,
        highContrast: json['highContrast'] as bool? ?? false,
        reduceMotion: json['reduceMotion'] as bool? ?? false,
        screenReader: json['screenReader'] as bool? ?? false,
        audioFeedbackVolume: json['audioFeedbackVolume'] as double? ?? 1.0,
        hapticFeedback: json['hapticFeedback'] as bool? ?? true,
        debounceMs: json['debounceMs'] as int? ?? 300,
      );
}

class AccessibilityNotifier extends StateNotifier<AccessibilitySettings> {
  static const String _key = 'accessibility_settings';

  AccessibilityNotifier() : super(const AccessibilitySettings());

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data != null) {
      try {
        final decoded = jsonDecode(data) as Map<String, dynamic>;
        state = AccessibilitySettings.fromJson(decoded);
      } catch (e) {
        state = const AccessibilitySettings();
      }
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_key, jsonEncode(state.toJson()));
  }

  void setFontScale(double scale) {
    state = state.copyWith(fontScale: scale.clamp(0.8, 2.0));
    save();
  }

  void toggleHighContrast() {
    state = state.copyWith(highContrast: !state.highContrast);
    save();
  }

  void toggleReduceMotion() {
    state = state.copyWith(reduceMotion: !state.reduceMotion);
    save();
  }

  void toggleScreenReader() {
    state = state.copyWith(screenReader: !state.screenReader);
    save();
  }

  void setAudioVolume(double volume) {
    state = state.copyWith(audioFeedbackVolume: volume.clamp(0.0, 1.0));
    save();
  }

  void toggleHaptic() {
    state = state.copyWith(hapticFeedback: !state.hapticFeedback);
    save();
  }

  void setDebounce(int ms) {
    state = state.copyWith(debounceMs: ms.clamp(100, 1000));
    save();
  }
}

final accessibilityProvider =
    StateNotifierProvider<AccessibilityNotifier, AccessibilitySettings>((ref) {
  return AccessibilityNotifier();
});

class AccessibilitySettingsScreen extends ConsumerWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(accessibilityProvider);
    final notifier = ref.read(accessibilityProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Accessibility')),
      body: ListView(
        children: [
          const _SectionHeader(title: 'Display'),
          _SliderSetting(
            title: 'Text Size',
            value: settings.fontScale,
            min: 0.8,
            max: 2.0,
            divisions: 12,
            label: '${(settings.fontScale * 100).round()}%',
            onChanged: notifier.setFontScale,
          ),
          SwitchListTile(
            title: const Text('High Contrast'),
            subtitle: const Text('Increase text contrast for better visibility'),
            value: settings.highContrast,
            onChanged: (_) => notifier.toggleHighContrast(),
          ),
          SwitchListTile(
            title: const Text('Reduce Motion'),
            subtitle: const Text('Minimize animations'),
            value: settings.reduceMotion,
            onChanged: (_) => notifier.toggleReduceMotion(),
          ),
          const Divider(),
          const _SectionHeader(title: 'Audio'),
          _SliderSetting(
            title: 'Feedback Volume',
            value: settings.audioFeedbackVolume,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            label: '${(settings.audioFeedbackVolume * 100).round()}%',
            onChanged: notifier.setAudioVolume,
          ),
          SwitchListTile(
            title: const Text('Haptic Feedback'),
            subtitle: const Text('Vibrate on interactions'),
            value: settings.hapticFeedback,
            onChanged: (_) => notifier.toggleHaptic(),
          ),
          const Divider(),
          const _SectionHeader(title: 'Interaction'),
          _SliderSetting(
            title: 'Response Delay',
            value: settings.debounceMs.toDouble(),
            min: 100,
            max: 1000,
            divisions: 9,
            label: '${settings.debounceMs}ms',
            onChanged: (v) => notifier.setDebounce(v.round()),
          ),
          SwitchListTile(
            title: const Text('Screen Reader Support'),
            subtitle: const Text('Enhanced for assistive technology'),
            value: settings.screenReader,
            onChanged: (_) => notifier.toggleScreenReader(),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _SliderSetting extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final ValueChanged<double> onChanged;

  const _SliderSetting({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: label,
        onChanged: onChanged,
      ),
      trailing: Text(label),
    );
  }
}

class AccessibleText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final String? semanticsLabel;

  const AccessibleText(
    this.text, {
    super.key,
    this.style,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel ?? text,
      child: Text(text, style: style),
    );
  }
}

class SemanticButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final String? label;

  const SemanticButton({super.key, 
    required this.onPressed,
    required this.child,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: child,
    );
  }
}