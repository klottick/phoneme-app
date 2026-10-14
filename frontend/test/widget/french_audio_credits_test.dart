import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_audio_catalog.dart';
import 'package:linguist/src/core/course/french_course.dart';
import 'package:linguist/src/features/settings/french_audio_credits.dart';
import 'package:linguist/src/features/settings/settings_screen.dart';

/// Test-only asset bundle over the shipped files (the asset boundary); can
/// fail its first reads on purpose to exercise the Retry path.
class _RealFileBundle extends AssetBundle {
  _RealFileBundle({this.failingLoads = 0});

  final int failingLoads;
  int _emittedFailures = 0;

  @override
  Future<ByteData> load(String key) async {
    if (_emittedFailures < failingLoads) {
      _emittedFailures++;
      throw FlutterError('injected bundle read failure: $key');
    }
    final List<int> bytes = File(key).readAsBytesSync();
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}

/// Counts constructions: if viewing credits ever reaches the legacy audio
/// provider, an instance is built and the test fails.
class _EngineProbe implements CourseAudio {
  _EngineProbe() {
    builtCount++;
  }

  static int builtCount = 0;

  @override
  Future<void> speak(String word) async => throw StateError('must not speak');

  @override
  Future<void> stop() async {}
}

Future<void> _pump(
  WidgetTester tester, {
  AssetBundle? bundle,
  List<Override> extra = const [],
}) async {
  final loader =
      CourseAudioCatalogLoader(bundle: bundle ?? _RealFileBundle(), references: frenchCurriculum.audioReferences);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        courseAudioCatalogLoaderProvider.overrideWithValue(loader),
        ...extra,
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Material(
              child: FrenchAudioCredits(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 25));
  await tester.pumpAndSettle();
}

Future<void> _expand(WidgetTester tester, String header) async {
  await tester.ensureVisible(find.text(header));
  await tester.pumpAndSettle();
  await tester.tap(find.text(header));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FrenchAudioCredits (real pending catalogue)', () {
    testWidgets('lists all 24 unverified credits in authored order',
        (WidgetTester tester) async {
      await _pump(tester);
      expect(
          find.text('French recordings are unverified alpha material.'),
          findsOneWidget);
      for (final reference in frenchCurriculum.audioReferences) {
        final header = '${reference.spokenText} (${reference.id})';
        await tester.ensureVisible(find.text(header));
        await tester.pumpAndSettle();
        expect(find.text(header), findsOneWidget);
      }
      // The generic Wikipedia CC BY-SA 3.0 notice is gone from this package.
      expect(find.textContaining('CC BY-SA 3.0'), findsNothing);
      // Code MIT stays visibly separate from the audio licences.
      expect(find.text('App code licence: MIT (separate from the audio credits)'),
          findsOneWidget);
    });

    testWidgets('shows creator, source, revision, licence URLs and status per file',
        (WidgetTester tester) async {
      await _pump(tester);
      await _expand(tester, 'tout (fr-word-tout)');
      expect(find.text('Creator: LoquaxFR'), findsOneWidget);
      expect(
          find.text(
              "LoquaxFR (speaker and recorder), 'LL-Q150_(fra)-LoquaxFR-tout.wav', via Wikimedia Commons (CC BY SA 4.0)"),
          findsOneWidget);
      expect(
          find.text('https://commons.wikimedia.org/wiki/File:LL-Q150_(fra)-LoquaxFR-tout.wav'),
          findsOneWidget);
      expect(
          find.text('https://commons.wikimedia.org/w/index.php?title=File%3ALL-Q150%20(fra)-LoquaxFR-tout.wav&oldid=995917835'),
          findsOneWidget);
      expect(find.text('Licence: CC-BY-SA-4.0'), findsOneWidget);
      expect(find.text('https://creativecommons.org/licenses/by-sa/4.0/'),
          findsOneWidget);
      expect(find.text('Unchanged original: yes'), findsOneWidget);
      expect(find.textContaining('You must give appropriate credit'),
          findsOneWidget);
    });

    testWidgets('keeps the sans CC BY 4.0 licence exception exact',
        (WidgetTester tester) async {
      await _pump(tester);
      await _expand(tester, 'sans (fr-word-sans)');
      expect(find.text('Licence: CC-BY-4.0'), findsOneWidget);
      expect(find.text('https://creativecommons.org/licenses/by/4.0/'),
          findsOneWidget);
      expect(find.text('Licence: CC-BY-SA-4.0'), findsNothing,
          reason: 'sans must keep its own CC BY 4.0 licence, not BY-SA');
    });

    testWidgets('shows a faithful archived-mur provenance caveat only for mur',
        (WidgetTester tester) async {
      await _pump(tester);
      // A non-archived word must not carry any provenance caveat.
      await _expand(tester, 'tout (fr-word-tout)');
      expect(find.textContaining('Provenance caveat'), findsNothing,
          reason: 'a current recording must not carry an archive caveat');
      // The approved archived mur original carries its faithful caveat.
      await _expand(tester, 'mur (fr-word-mur)');
      expect(
          find.text('Provenance caveat: archived original upload (description revision 384728988, 2020 original, retrieved 2026-10-13). The Commons description shows recorded, unresolved licence conflicts; this is source provenance, not a current grant.'),
          findsOneWidget);
    });

    testWidgets('shows the complete bundled legal text offline',
        (WidgetTester tester) async {
      await _pump(tester);
      await _expand(tester, 'tout (fr-word-tout)');
      await tester.tap(find.text('View licence text'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 25));
      await tester.pumpAndSettle();
      expect(
          find.textContaining(
              'Creative Commons Corporation ("Creative Commons") is not a law firm'),
          findsOneWidget);
      // The retained text is complete, not an excerpt: the tail is present.
      final tail =
          File('assets/audio/fr/licenses/CC-BY-SA-4.0.txt')
              .readAsStringSync()
              .trim()
              .split('\n')
              .last;
      expect(find.textContaining(tail), findsOneWidget);
      expect(find.text('Hide licence text'), findsOneWidget);
    });

    testWidgets('shows Retry on a malformed first load, then recovers',
        (WidgetTester tester) async {
      await _pump(tester, bundle: _RealFileBundle(failingLoads: 1));
      expect(find.text('Could not load audio credits.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Loading audio credits'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 25));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('tout (fr-word-tout)'));
      await tester.pumpAndSettle();
      expect(find.text('tout (fr-word-tout)'), findsOneWidget);
    });

    testWidgets('viewing credits never constructs or uses an audio engine',
        (WidgetTester tester) async {
      int ttsMessages = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('flutter_tts'), (call) async {
        ttsMessages++;
        return 1;
      });
      await _pump(
        tester,
        extra: [
          courseAudioProvider.overrideWith((ref) => _EngineProbe()),
        ],
      );
      await _expand(tester, 'tout (fr-word-tout)');
      await tester.tap(find.text('View licence text'));
      await tester.pumpAndSettle();
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
      expect(_EngineProbe.builtCount, 0,
          reason: 'viewing credits must not read the legacy audio provider');
      expect(ttsMessages, 0,
          reason: 'viewing credits must not touch the TTS channel');
    });
  });

  group('Settings credits slice', () {
    testWidgets(
        'settings screen replaces the generic BY-SA 3.0 audio credit with the real credits',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SettingsScreen())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 25));
      await tester.pumpAndSettle();

      expect(find.textContaining('CC BY-SA 3.0'), findsNothing,
          reason: 'the generic Wikipedia CC BY-SA 3.0 notice must not remain');
      expect(
          find.text('French recordings are unverified alpha material.'),
          findsOneWidget);
      expect(find.text('License: MIT'), findsOneWidget,
          reason: 'code MIT stays visible and separate');
      expect(find.text('• IPA data: ipa-dict (MIT)'), findsOneWidget);
      // Theme/reset/TTS controls remain untouched.
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Text-to-Speech'), findsOneWidget);
      expect(find.text('Reset Streak'), findsOneWidget);
      expect(find.text('• Backend: Supabase'), findsOneWidget);
    });
  });
}
