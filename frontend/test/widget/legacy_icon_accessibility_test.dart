import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:linguist/src/core/models/phoneme.dart';
import 'package:linguist/src/core/providers/app_providers.dart';
import 'package:linguist/src/core/services/recording_service.dart'
    hide recordingServiceProvider;
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
}
