// The literal curriculum checkpoints remain useful parser fixtures, but the
// replaced local progress store intentionally does not import them. The tests
// below preserve the content/session parsing oracle and assert byte-preserving
// no-import behavior through the file-backed SQL repository.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/lesson_section.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/course_learning_widget_store.dart';

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
          File(
            'test/fixtures/course_curriculum_legacy_sessions.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

String _prefsKey() =>
    (_fixture()['seed'] as Map<String, dynamic>)['preferencesKey'] as String;

String _seedDocument(String name) {
  final fixture = _fixture();
  final seed = fixture['seed'] as Map<String, dynamic>;
  final checkpoint =
      (fixture['checkpoints'] as Map<String, dynamic>)[name]
          as Map<String, dynamic>;
  return jsonEncode({
    'lessons': seed['lessons'],
    'evidence': (seed['evidence'] as Map<String, dynamic>)[name],
    'scores': seed['scores'],
    seed['legacyFieldKey'] as String: 'sentinel-legacy-badge',
    'pending': [seed['sentinelPending']],
    'sections': {
      'en-fr-u-y': {
        'checkpoint': checkpoint,
        'processedSessionId': checkpoint['sessionId'],
        'processedAttemptCount': checkpoint['attemptCount'],
      },
      'en-fr-nasal': seed['siblingSection'],
    },
  });
}

void main() {
  group('literal checkpoint parsing oracle (old IDs, version 1)', () {
    test('all five checkpoints restore through the current parser with '
        'exact expected state', () {
      final Map<String, dynamic> fixture = _fixture();
      final Map<String, dynamic> checkpoints =
          fixture['checkpoints'] as Map<String, dynamic>;
      final List<String> itemIds = frenchUySection.items
          .map((item) => item.id)
          .toList();
      expect(
        itemIds,
        _legacyItemIds,
        reason: 'the pre-migration section uses the old word IDs',
      );

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
        expect(
          session.phase == LessonSectionPhase.debrief,
          exp['phase'] == 'debrief',
        );
        expect(session.position, exp['position']);
        expect(session.round, exp['round']);
        expect(session.attemptCount, exp['attemptCount']);
        expect(
          session.queue,
          exp['queue'] == 'tu' ? const ['tu'] : _legacyItemIds,
        );
        expect(
          session.toJson()['submittedThisRound'],
          exp['submitted'] == 'none'
              ? const <String>[]
              : (exp['submitted'] == 'all' ? _legacyItemIds : const ['tout']),
        );
        expect(session.lastCorrect, exp['lastCorrect']);
        expect(session.answered, exp['answered']);
        if (exp['latest'] == 'empty') {
          expect(session.latestAnswers, isEmpty);
        } else if (exp['latest'] == 'only-tout-true') {
          expect(session.latestAnswers, const {'tout': true});
        } else {
          expect(session.latestAnswers, {
            for (final id in _legacyItemIds) id: id != 'tu',
          });
        }
        expect(session.policy.completionThresholdPercent, exp['threshold']);
      }
    });
  });
  test(
    'all literal old checkpoints remain byte-for-byte and are not imported',
    () async {
      for (final name in [
        'fresh',
        'answered',
        'debrief',
        'review',
        'custom-policy',
      ]) {
        final raw = _seedDocument(name);
        SharedPreferences.setMockInitialValues({
          _prefsKey(): raw,
          'auth.token': 'keep-auth',
          'profile.name': 'keep-profile',
          'streak.days': 7,
        });
        final prefs = await SharedPreferences.getInstance();
        final harness = CourseLearningSqlTestHarness();
        final store = harness.store;

        final state = await store.load();
        expect(
          state.history,
          isEmpty,
          reason: '$name must not import attempts',
        );
        expect(
          state.completions,
          isEmpty,
          reason: '$name must not import completion',
        );
        expect(
          state.summaries,
          isEmpty,
          reason: '$name must not import aggregates',
        );
        expect(
          prefs.getString(_prefsKey()),
          raw,
          reason: '$name legacy bytes must remain untouched',
        );
        expect(prefs.getString('auth.token'), 'keep-auth');
        expect(prefs.getString('profile.name'), 'keep-profile');
        expect(prefs.getInt('streak.days'), 7);
      }
    },
  );
}
