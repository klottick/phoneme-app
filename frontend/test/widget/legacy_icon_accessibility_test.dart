import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:linguist/src/core/models/phoneme.dart';
import 'package:linguist/src/core/providers/app_providers.dart';
import 'package:linguist/src/core/services/recording_service.dart'
    hide recordingServiceProvider;
import 'package:linguist/src/core/services/tts_service.dart';
import 'package:linguist/src/core/services/audio_service.dart';
import 'package:linguist/src/features/audio/audio_compare_screen.dart';
import 'package:linguist/src/features/content/content_manager_screen.dart';
import 'package:linguist/src/features/phoneme_id/phoneme_identify_screen.dart';
import 'package:linguist/src/features/phoneme_test/phoneme_test_screen.dart';
import 'package:linguist/src/features/speak/speak_screen.dart';

List<Phoneme> _phonemes() => [
  for (var i = 0; i < 4; i++)
    Phoneme(
      id: '$i',
      languageCode: 'fr',
      ipaSymbol: '/p$i/',
      descriptor: 'sample$i',
      difficultyLevel: 1,
    ),
];

SemanticsData _semanticsForTooltip(WidgetTester tester, String label) =>
    tester.getSemantics(find.byTooltip(label)).getSemanticsData();

class _FakeRecordingService extends RecordingService {
  bool recording = false;

  @override
  Future<void> startRecording(String path, {bool Function()? isActive}) async {
    recording = true;
  }

  @override
  Future<String?> stopRecording() async {
    recording = false;
    return '/fake/recording.m4a';
  }
}

class _HeldTtsService extends TtsService {
  final Completer<void> playback = Completer<void>();

  @override
  Future<void> speak(String text, {String? languageCode}) => playback.future;

  @override
  void dispose() {}
}

class _HeldAudioService extends AudioService {
  final Completer<void> playback = Completer<void>();

  @override
  Future<void> play(String path) => playback.future;

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('phoneme identification playback actions have distinct names', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [phonemesProvider.overrideWith((ref) async => _phonemes())],
        child: const MaterialApp(home: PhonemeIdentifyScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      _semanticsForTooltip(tester, 'Play phoneme').tooltip,
      'Play phoneme',
    );
    expect(
      _semanticsForTooltip(tester, 'Play sample word').tooltip,
      'Play sample word',
    );
    semantics.dispose();
  });

  testWidgets('phoneme test microphone is named and remains disabled on web', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          phonemesProvider.overrideWith((ref) async => _phonemes()),
          phonemeRecordingAvailableProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(home: PhonemeTestScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final action = _semanticsForTooltip(
      tester,
      'Recording is not available in this browser',
    );
    expect(action.tooltip, 'Recording is not available in this browser');
    expect(action.hasAction(SemanticsAction.tap), isFalse);
    expect(
      find.text('Recording is not available in this browser'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('audio comparison microphone action is contextual', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AudioCompareScreen())),
    );
    await tester.pumpAndSettle();
    final action = _semanticsForTooltip(tester, 'Record your pronunciation');
    expect(action.tooltip, 'Record your pronunciation');
    expect(action.hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('audio comparison name follows record and stop actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    final semantics = tester.ensureSemantics();
    final recorder = _FakeRecordingService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [recordingServiceProvider.overrideWithValue(recorder)],
        child: const MaterialApp(home: AudioCompareScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Record your pronunciation'));
    await tester.pumpAndSettle();
    expect(recorder.recording, isTrue);
    final stop = _semanticsForTooltip(
      tester,
      'Stop recording your pronunciation',
    );
    expect(stop.tooltip, 'Stop recording your pronunciation');
    expect(stop.hasAction(SemanticsAction.tap), isTrue);
    await tester.tap(find.byTooltip('Stop recording your pronunciation'));
    await tester.pumpAndSettle();
    expect(recorder.recording, isFalse);
    expect(find.text('Play Your Recording'), findsOneWidget);
    semantics.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('speaking practice microphone action is contextual', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SpeakScreen())),
    );
    await tester.pumpAndSettle();
    final action = _semanticsForTooltip(tester, 'Record your pronunciation');
    expect(action.tooltip, 'Record your pronunciation');
    expect(action.hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
  });

  testWidgets('custom phoneme add and named delete actions are contextual', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'custom_phonemes': jsonEncode([
        {
          'id': 'custom-a',
          'ipaSymbol': 'æ',
          'name': 'near-open front',
          'description': null,
          'audioUrl': null,
          'createdAt': DateTime.utc(2026).toIso8601String(),
        },
      ]),
    });
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ContentManagerScreen())),
    );
    await tester.pumpAndSettle();
    expect(
      _semanticsForTooltip(tester, 'Add custom phoneme').tooltip,
      'Add custom phoneme',
    );
    final remove = _semanticsForTooltip(tester, 'Delete near-open front');
    expect(remove.tooltip, 'Delete near-open front');
    expect(remove.hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
  });

  testWidgets('keyboard activates custom add and keyboard Cancel dismisses', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ContentManagerScreen())),
    );
    await tester.pumpAndSettle();

    var addFocused = false;
    for (var i = 0; i < 12 && !addFocused; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      addFocused =
          _semanticsForTooltip(
            tester,
            'Add custom phoneme',
          ).flagsCollection.isFocused ==
          Tristate.isTrue;
    }
    expect(addFocused, isTrue, reason: 'Tab traversal focuses Add');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Add Custom Phoneme'), findsOneWidget);

    var cancelFocused = false;
    for (var i = 0; i < 8 && !cancelFocused; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      cancelFocused =
          tester
              .getSemantics(find.text('Cancel'))
              .getSemanticsData()
              .flagsCollection
              .isFocused ==
          Tristate.isTrue;
    }
    expect(cancelFocused, isTrue, reason: 'Tab traversal focuses Cancel');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Add Custom Phoneme'), findsNothing);
  });

  testWidgets('keyboard activates contextual delete for seeded phoneme', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'custom_phonemes': jsonEncode([
        {
          'id': 'custom-a',
          'ipaSymbol': 'æ',
          'name': 'near-open front',
          'description': null,
          'audioUrl': null,
          'createdAt': DateTime.utc(2026).toIso8601String(),
        },
      ]),
    });
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ContentManagerScreen())),
    );
    await tester.pumpAndSettle();

    var deleteFocused = false;
    for (var i = 0; i < 12 && !deleteFocused; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      deleteFocused =
          _semanticsForTooltip(
            tester,
            'Delete near-open front',
          ).flagsCollection.isFocused ==
          Tristate.isTrue;
    }
    expect(deleteFocused, isTrue, reason: 'Tab traversal focuses named Delete');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('near-open front'), findsNothing);
    expect(
      find.text('No custom phonemes added yet.\nTap + to add your first one.'),
      findsOneWidget,
    );
  });

  testWidgets('audio comparison playback states have truthful disabled names', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final tts = _HeldTtsService();
    final audio = _HeldAudioService();
    final recorder = _FakeRecordingService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ttsServiceProvider.overrideWithValue(tts),
          audioServiceProvider.overrideWithValue(audio),
          recordingServiceProvider.overrideWithValue(recorder),
        ],
        child: const MaterialApp(home: AudioCompareScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Record your pronunciation'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Stop recording your pronunciation'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Play Reference'));
    await tester.pump();
    var reference = tester
        .getSemantics(find.text('Reference audio is playing'))
        .getSemanticsData();
    expect(reference.label, 'Reference audio is playing');
    expect(reference.hasAction(SemanticsAction.tap), isFalse);
    tts.playback.complete();
    await tester.pumpAndSettle();
    reference = tester
        .getSemantics(find.text('Play Reference'))
        .getSemanticsData();
    expect(reference.hasAction(SemanticsAction.tap), isTrue);

    await tester.tap(find.text('Play Your Recording'));
    await tester.pump();
    final userRecording = tester
        .getSemantics(find.text('Your recording is playing'))
        .getSemanticsData();
    expect(userRecording.label, 'Your recording is playing');
    expect(userRecording.hasAction(SemanticsAction.tap), isFalse);
    audio.playback.complete();
    await tester.pumpAndSettle();
    semantics.dispose();
  });

  testWidgets(
    'ID playback controls describe their own unavailable action while busy',
    (tester) async {
      final semantics = tester.ensureSemantics();
      for (final icon in [Icons.volume_up, Icons.volume_down]) {
        await tester.pumpWidget(const SizedBox.shrink());
        final tts = _HeldTtsService();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              phonemesProvider.overrideWith((ref) async => _phonemes()),
              ttsServiceProvider.overrideWithValue(tts),
            ],
            child: const MaterialApp(home: PhonemeIdentifyScreen()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(icon));
        await tester.pump();

        for (final (tooltip, label) in [
          (
            'Play phoneme — unavailable during playback',
            'Play phoneme — unavailable during playback',
          ),
          (
            'Play sample word — unavailable during playback',
            'Play sample word — unavailable during playback',
          ),
        ]) {
          final control = _semanticsForTooltip(tester, tooltip);
          expect(control.tooltip, label);
          expect(control.hasAction(SemanticsAction.tap), isFalse);
        }

        tts.playback.complete();
        await tester.pumpAndSettle();
        expect(
          _semanticsForTooltip(tester, 'Play phoneme')
              .hasAction(SemanticsAction.tap),
          isTrue,
        );
        expect(
          _semanticsForTooltip(tester, 'Play sample word')
              .hasAction(SemanticsAction.tap),
          isTrue,
        );
      }
      semantics.dispose();
    },
  );
}
