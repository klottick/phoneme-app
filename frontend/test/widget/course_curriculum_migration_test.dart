// FR-01 Task 4 save-compatibility oracle for the live pilot migration.
//
// Runs the real CourseProgressStore (shared_preferences-backed, backend null)
// and the actual discovery lesson screen against the five literal version-1
// old-ID checkpoints owned by the frozen fixture
// (test/fixtures/course_curriculum_legacy_sessions.json, provenance a500651).
// These assertions use only pre-migration public APIs, so the file must pass
// both before and after the catalogue migration: a projected section that is
// not byte-compatible with the old pilot would break the real store or the
// screen here.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_progress.dart';
import 'package:linguist/src/core/course/lesson_section.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/features/course/discovery_lesson_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Practice-TTS playback stand-in: records what it speaks and completes
/// immediately. Only the store itself is exercised for real here.
class FakeAudio implements CourseAudio {
  final List<String> spoken = [];

  @override
  Future<void> speak(String word) async {
    spoken.add(word);
  }

  @override
  Future<void> stop() async {}
}

const List<String> _legacyItemIds = [
  'tout',
  'tu',
  'rouge',
  'rue',
  'vous',
  'lune',
  'doux',
  'jus',
  'loup',
  'mur',
];

Map<String, dynamic> _fixture() =>
    jsonDecode(
      File('test/fixtures/course_curriculum_legacy_sessions.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;

/// Assembles the exact on-device document for one named checkpoint: the
/// literal checkpoint plus the literal history seed (lessons, scores,
/// sibling section, sentinel outbox event, unknown legacy field).
String _seedDocument(String name) {
  final Map<String, dynamic> fixture = _fixture();
  final Map<String, dynamic> seed = fixture['seed'] as Map<String, dynamic>;
  final Map<String, dynamic> checkpoints =
      fixture['checkpoints'] as Map<String, dynamic>;
  final Map<String, dynamic> checkpoint =
      checkpoints[name] as Map<String, dynamic>;
  return jsonEncode(<String, dynamic>{
    'lessons': (seed['lessons'] as List).cast<String>(),
    'evidence': (seed['evidence'] as Map<String, dynamic>)[name],
    'scores': seed['scores'],
    seed['legacyFieldKey'] as String: 'sentinel-legacy-badge',
    'pending': [seed['sentinelPending']],
    'sections': <String, dynamic>{
      'en-fr-u-y': <String, dynamic>{
        'checkpoint': checkpoint,
        'processedSessionId': checkpoint['sessionId'],
        'processedAttemptCount': checkpoint['attemptCount'],
      },
      'en-fr-nasal': seed['siblingSection'],
    },
  });
}

String _prefsKey() =>
    (_fixture()['seed'] as Map<String, dynamic>)['preferencesKey'] as String;

Map<String, dynamic> _document(SharedPreferences prefs) {
  final String? raw = prefs.getString(_prefsKey());
  expect(raw, isNotNull, reason: 'the seeded document must still exist');
  return jsonDecode(raw!) as Map<String, dynamic>;
}

void _expectHistorySurvives(
  SharedPreferences prefs, {
  required bool completed,
}) {
  final Map<String, dynamic> seed = _fixture()['seed'] as Map<String, dynamic>;
  final Map<String, dynamic> doc = _document(prefs);
  final List<String> lessons = (doc['lessons'] as List).cast<String>();
  if (completed) {
    expect(lessons, [...(seed['lessons'] as List).cast<String>(), 'en-fr-u-y']);
  } else {
    expect(lessons, (seed['lessons'] as List).cast<String>());
  }
  expect(doc['scores'], seed['scores'],
      reason: 'legacy scores are preserved');
  expect(doc[seed['legacyFieldKey'] as String], 'sentinel-legacy-badge',
      reason: 'the unknown legacy field survives');
  expect(doc['pending'], [seed['sentinelPending']],
      reason: 'the sentinel outbox event survives and no upload happens '
          'with a null backend (guest stays on-device)');
  expect(doc['sections']['en-fr-nasal'], seed['siblingSection'],
      reason: 'the sibling section entry is preserved untouched');
}

void _expectLegacyCheckpoint(
  SharedPreferences prefs, {
  required String name,
  required int processedAttemptCount,
}) {
  final Map<String, dynamic> entry =
      _document(prefs)['sections']['en-fr-u-y'] as Map<String, dynamic>;
  final Map<String, dynamic> checkpoint =
      entry['checkpoint'] as Map<String, dynamic>;
  expect(checkpoint['itemIds'], _legacyItemIds,
      reason: 'new saves keep the ten legacy old IDs');
  expect(checkpoint['contentRevision'], 1,
      reason: 'content revision 1 is unchanged');
  expect(checkpoint['sessionId'], 'legacy-$name',
      reason: 'the saved session identity is preserved');
  expect(checkpoint['version'], 1,
      reason: 'session serialization version 1 is unchanged');
  expect(entry['processedSessionId'], 'legacy-$name');
  expect(entry['processedAttemptCount'], processedAttemptCount);
}

Widget _app(CourseAudio audio, CourseProgressStore store) {
  return ProviderScope(
    overrides: [
      courseAudioProvider.overrideWithValue(audio),
      lessonSectionStoreProvider.overrideWithValue(store),
    ],
    child: const MaterialApp(home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y')),
  );
}

void main() {
  group('literal checkpoint parsing oracle (old IDs, version 1)', () {
    test('all five checkpoints restore through the current parser with '
        'exact expected state', () {
      final Map<String, dynamic> fixture = _fixture();
      final Map<String, dynamic> checkpoints =
          fixture['checkpoints'] as Map<String, dynamic>;
      final List<String> itemIds =
          frenchUySection.items.map((item) => item.id).toList();
      expect(itemIds, _legacyItemIds,
          reason: 'the pre-migration section uses the old word IDs');

      const Map<String, Map<String, Object?>> expected = {
        'fresh': {
          'phase': 'exercise',
          'position': 0,
          'round': 1,
          'attemptCount': 0,
          'queue': 'all',
          'submitted': 'none',
          'lastCorrect': null,
          'answered': false,
          'latest': 'empty',
          'threshold': 80,
        },
        'answered': {
          'phase': 'exercise',
          'position': 0,
          'round': 1,
          'attemptCount': 1,
          'queue': 'all',
          'submitted': 'tout',
          'lastCorrect': true,
          'answered': true,
          'latest': 'only-tout-true',
          'threshold': 80,
        },
        'debrief': {
          'phase': 'debrief',
          'position': 10,
          'round': 1,
          'attemptCount': 10,
          'queue': 'all',
          'submitted': 'all',
          'lastCorrect': true,
          'answered': false,
          'latest': 'debrief',
          'threshold': 80,
        },
        'review': {
          'phase': 'exercise',
          'position': 0,
          'round': 2,
          'attemptCount': 10,
          'queue': 'tu',
          'submitted': 'none',
          'lastCorrect': true,
          'answered': false,
          'latest': 'debrief',
          'threshold': 80,
        },
        'custom-policy': {
          'phase': 'debrief',
          'position': 10,
          'round': 1,
          'attemptCount': 10,
          'queue': 'all',
          'submitted': 'all',
          'lastCorrect': true,
          'answered': false,
          'latest': 'debrief',
          'threshold': 100,
        },
      };

      for (final MapEntry<String, dynamic> entry in checkpoints.entries) {
        final Map<String, Object?> exp = expected[entry.key]!;
        final LessonSectionSession session = LessonSectionSession.fromJson(
          entry.value,
          itemIds: itemIds,
          contentRevision: frenchUySection.contentRevision,
        );
        expect(session.sessionId, 'legacy-${entry.key}');
        expect(session.contentRevision, 1);
        expect(session.itemIds, _legacyItemIds);
        expect(session.phase == LessonSectionPhase.debrief,
            exp['phase'] == 'debrief');
        expect(session.position, exp['position']);
        expect(session.round, exp['round']);
        expect(session.attemptCount, exp['attemptCount']);
        expect(session.queue,
            exp['queue'] == 'tu' ? const ['tu'] : _legacyItemIds);
        expect(
          session.toJson()['submittedThisRound'],
          exp['submitted'] == 'none'
              ? const <String>[]
              : (exp['submitted'] == 'all'
                  ? _legacyItemIds
                  : const ['tout']),
        );
        expect(session.lastCorrect, exp['lastCorrect']);
        expect(session.answered, exp['answered']);
        if (exp['latest'] == 'empty') {
          expect(session.latestAnswers, isEmpty);
        } else if (exp['latest'] == 'only-tout-true') {
          expect(session.latestAnswers, const {'tout': true});
        } else {
          expect(
            session.latestAnswers,
            {
              for (final id in _legacyItemIds) id: id != 'tu',
            },
          );
        }
        expect(session.policy.completionThresholdPercent, exp['threshold']);
      }
    });
  });

  group('real store and screen against the frozen old-ID seeds', () {
    testWidgets('fresh: exact load writes nothing; answer then advances '
        'with one recording, and a reopened screen resumes', (tester) async {
      final String raw = _seedDocument('fresh');
      SharedPreferences.setMockInitialValues({_prefsKey(): raw});
      final FakeAudio audio = FakeAudio();
      final CourseProgressStore store = CourseProgressStore('en-fr');
      await tester.pumpWidget(_app(audio, store));
      await tester.pumpAndSettle();

      expect(find.text('Item 1 of 10'), findsOneWidget);
      expect(find.text('Correct'), findsNothing);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_prefsKey()), raw,
          reason: 'the initial load must write nothing');

      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      expect(audio.spoken.last, 'tout');
      await tester.tap(find.text('/u/'));
      await tester.pumpAndSettle();
      expect(find.text('Correct'), findsOneWidget);

      final Map<String, dynamic> evidence =
          _document(prefs)['evidence'] as Map<String, dynamic>;
      expect(evidence.keys, {'listening:u'},
          reason: 'the correct answer records against /u/ exactly once');
      expect(evidence['listening:u']['attempts'], 1);
      expect(evidence['listening:u']['correct'], 1);
      _expectHistorySurvives(prefs, completed: false);
      _expectLegacyCheckpoint(prefs, name: 'fresh', processedAttemptCount: 1);

      await tester.tap(find.text('Next word'));
      await tester.pumpAndSettle();
      expect(find.text('Item 2 of 10'), findsOneWidget);
      expect(prefs.getString(_prefsKey()) != null, isTrue);
      expect(
          (_document(prefs)['evidence']
                      ['listening:u'] as Map<String, dynamic>)
                  ['attempts'],
          1,
          reason: 'advancing does not record a second time');
      _expectLegacyCheckpoint(prefs, name: 'fresh', processedAttemptCount: 1);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_app(FakeAudio(), store));
      await tester.pumpAndSettle();
      expect(find.text('Item 2 of 10'), findsOneWidget,
          reason: 'a reopened screen resumes the continued saved state');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('answered: exact load writes nothing; Next advances the '
        'saved item without re-recording', (tester) async {
      final String raw = _seedDocument('answered');
      SharedPreferences.setMockInitialValues({_prefsKey(): raw});
      final FakeAudio audio = FakeAudio();
      final CourseProgressStore store = CourseProgressStore('en-fr');
      await tester.pumpWidget(_app(audio, store));
      await tester.pumpAndSettle();

      expect(find.text('Item 1 of 10'), findsOneWidget);
      expect(find.text('Correct'), findsOneWidget,
          reason: 'the restored submitted answer shows its saved outcome');
      expect(tester.widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Next word'))
              .onPressed,
          isNotNull);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_prefsKey()), raw,
          reason: 'the initial load must write nothing');

      await tester.tap(find.text('Next word'));
      await tester.pumpAndSettle();
      expect(find.text('Item 2 of 10'), findsOneWidget);
      final Map<String, dynamic> evidence =
          _document(prefs)['evidence'] as Map<String, dynamic>;
      expect(evidence['listening:u']['attempts'], 1,
          reason: 'the advance reuses the stored outcome, no new recording');
      expect(evidence['listening:u']['correct'], 1);
      _expectHistorySurvives(prefs, completed: false);
      _expectLegacyCheckpoint(prefs, name: 'answered', processedAttemptCount: 1);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_app(FakeAudio(), store));
      await tester.pumpAndSettle();
      expect(find.text('Item 2 of 10'), findsOneWidget,
          reason: 'a reopened screen resumes the advanced saved state');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('debrief: Finish completes exactly once and history '
        'survives', (tester) async {
      final String raw = _seedDocument('debrief');
      SharedPreferences.setMockInitialValues({_prefsKey(): raw});
      final CourseProgressStore store = CourseProgressStore('en-fr');
      await tester.pumpWidget(_app(FakeAudio(), store));
      await tester.pumpAndSettle();

      expect(find.text('Section debrief'), findsOneWidget);
      expect(find.text('You got 9 of 10 correct.'), findsOneWidget);
      expect(find.text('Passing needs 8 of 10 correct.'), findsOneWidget);
      expect(find.text('tu'), findsOneWidget,
          reason: 'the debrief lists the unresolved legacy word');
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_prefsKey()), raw,
          reason: 'the initial load must write nothing');

      await tester.tap(find.text('Finish section'));
      await tester.pumpAndSettle();
      final Map<String, dynamic> doc = _document(prefs);
      expect((doc['lessons'] as List).cast<String>(),
          ['en-fr-vowels', 'en-fr-u-y'],
          reason: 'completion is recorded once alongside the historical '
              'lesson');
      expect((doc['lessons'] as List)
                  .where((Object? id) => id == 'en-fr-u-y')
                  .length,
          1);
      final Map<String, dynamic> evidence =
          doc['evidence'] as Map<String, dynamic>;
      expect(evidence['listening:u']['attempts'], 5,
          reason: 'completing does not record answers');
      expect(evidence['listening:u']['correct'], 5);
      expect(evidence['listening:y']['attempts'], 5);
      expect(evidence['listening:y']['correct'], 4);
      _expectHistorySurvives(prefs, completed: true);
      _expectLegacyCheckpoint(prefs, name: 'debrief', processedAttemptCount: 10);

      // A second Finish must not add a second completion.
      final int completionsBefore =
          doc['lessons'].where((Object? id) => id == 'en-fr-u-y').length;
      final FilledButton finish =
          tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Finish section'));
      if (finish.onPressed != null) {
        await tester.tap(find.text('Finish section'));
        await tester.pumpAndSettle();
      }
      final Map<String, dynamic> docAfter = _document(prefs);
      expect(
          docAfter['lessons'].where((Object? id) => id == 'en-fr-u-y').length,
          completionsBefore,
          reason: 'completion stays exactly once');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('review: Item 1 of 1 with a closed hearing gate, then one '
        'correction recorded once', (tester) async {
      final String raw = _seedDocument('review');
      SharedPreferences.setMockInitialValues({_prefsKey(): raw});
      final FakeAudio audio = FakeAudio();
      final CourseProgressStore store = CourseProgressStore('en-fr');
      await tester.pumpWidget(_app(audio, store));
      await tester.pumpAndSettle();

      expect(find.textContaining('Review round 2'), findsOneWidget);
      expect(find.textContaining('item 1 of 1'), findsOneWidget,
          reason: 'the review round carries only the legacy mistake');
      // Closed hearing gate: no completed playback, no answer enabled.
      expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, '/u/'))
              .onPressed,
          isNull);
      expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, '/y/'))
              .onPressed,
          isNull);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_prefsKey()), raw,
          reason: 'the initial load must write nothing');

      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      expect(audio.spoken.last, 'tu',
          reason: 'the round item keeps its legacy word');
      await tester.tap(find.text('/y/'));
      await tester.pumpAndSettle();
      expect(find.text('Correct'), findsOneWidget);

      Map<String, dynamic> doc = _document(prefs);
      final Map<String, dynamic> evidence =
          doc['evidence'] as Map<String, dynamic>;
      expect(evidence['listening:u']['attempts'], 5,
          reason: 'the /u/ aggregate is untouched');
      expect(evidence['listening:u']['correct'], 5);
      expect(evidence['listening:y']['attempts'], 6,
          reason: 'the review correction records against /y/ exactly once');
      expect(evidence['listening:y']['correct'], 5);
      _expectHistorySurvives(prefs, completed: false);
      _expectLegacyCheckpoint(prefs, name: 'review', processedAttemptCount: 11);

      await tester.tap(find.text('See section explanation'));
      await tester.pumpAndSettle();
      expect(find.text('You got 10 of 10 correct.'), findsOneWidget);
      expect(find.text('Passing needs 8 of 10 correct.'), findsOneWidget);
      doc = _document(prefs);
      expect((doc['lessons'] as List).cast<String>(), ['en-fr-vowels'],
          reason: 'this flow continues the session, it does not complete');
      final Map<String, dynamic> checkpoint =
          (doc['sections']['en-fr-u-y'] as Map<String, dynamic>)['checkpoint']
              as Map<String, dynamic>;
      expect(checkpoint['phase'], 'debrief');
      expect(checkpoint['round'], 2);
      expect(checkpoint['itemIds'], _legacyItemIds);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'custom policy: saved 100% stays authoritative over the 80% '
        'widget default; the debrief keeps failing until the mistake is '
        'corrected', (tester) async {
      final String raw = _seedDocument('custom-policy');
      SharedPreferences.setMockInitialValues({_prefsKey(): raw});
      final FakeAudio audio = FakeAudio();
      final CourseProgressStore store = CourseProgressStore('en-fr');
      await tester.pumpWidget(_app(audio, store));
      await tester.pumpAndSettle();

      expect(find.text('Section debrief'), findsOneWidget);
      expect(find.text('You got 9 of 10 correct.'), findsOneWidget);
      expect(find.text('Passing needs 10 of 10 correct.'), findsOneWidget,
          reason: 'the saved 100% policy, not the 80% widget default, '
              'is authoritative on resume');
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Finish section'))
              .onPressed,
          isNull,
          reason: '9 of 10 cannot finish under the saved 100% threshold');
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_prefsKey()), raw,
          reason: 'the initial load must write nothing');

      await tester.tap(find.text('Review mistakes'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Review round 2'), findsOneWidget);
      expect(find.textContaining('item 1 of 1'), findsOneWidget);
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      expect(audio.spoken.last, 'tu',
          reason: 'the corrected item is the legacy /y/ word');
      await tester.tap(find.text('/y/'));
      await tester.pumpAndSettle();
      expect(find.text('Correct'), findsOneWidget);
      final Map<String, dynamic> evidence =
          (_document(prefs)['evidence'] as Map<String, dynamic>);
      expect(evidence['listening:y']['attempts'], 6,
          reason: 'the correction records exactly once');
      expect(evidence['listening:y']['correct'], 5);

      await tester.tap(find.text('See section explanation'));
      await tester.pumpAndSettle();
      expect(find.text('You got 10 of 10 correct.'), findsOneWidget);
      expect(find.text('Passing needs 10 of 10 correct.'), findsOneWidget);

      await tester.tap(find.text('Finish section'));
      await tester.pumpAndSettle();
      final Map<String, dynamic> doc = _document(prefs);
      expect((doc['lessons'] as List).cast<String>(),
          ['en-fr-vowels', 'en-fr-u-y']);
      expect(
          (doc['lessons'] as List).where((Object? id) => id == 'en-fr-u-y').length,
          1);
      expect(evidence['listening:u']['attempts'], 5);
      expect(evidence['listening:u']['correct'], 5);
      _expectHistorySurvives(prefs, completed: true);
      _expectLegacyCheckpoint(
          prefs, name: 'custom-policy', processedAttemptCount: 11);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
