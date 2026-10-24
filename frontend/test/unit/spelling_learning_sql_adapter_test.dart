import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show DatabaseConnection, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio_contract.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_transition.dart';
import 'package:linguist/src/core/course/french_uy_demo_spelling_content.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/spelling_learning_command.dart';
import 'package:linguist/src/core/course/spelling_learning_state.dart';
import 'package:linguist/src/core/course/spelling_learning_store.dart';
import 'package:linguist/src/core/course/spelling_learning_transition.dart';
import 'package:linguist/src/core/course/storage/course_learning_sql_repository.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show
        LearningDatabase,
        LearningDatabaseHandle,
        LearningMigrationFailurePoint;
import 'package:linguist/src/core/course/storage/spelling_learning_command_codec.dart';
import 'package:linguist/src/core/course/storage/spelling_learning_sql_repository.dart';

import '../support/learning_v1_fixture.dart';

const _activityId = 'en-fr-u-y-spelling';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('spelling SQLite adapter and repository', () {
    late _Fixture fixture;

    setUp(() async {
      fixture = await _Fixture.create();
    });

    tearDown(() async {
      await fixture.close();
    });

    test(
      'repository construction is lazy and bounds retained history',
      () async {
        final repository = fixture.repository();
        expect(fixture.openCalls, 0);
        expect(() => fixture.repository(historyLimit: 0), throwsArgumentError);
        expect(
          () => fixture.repository(historyLimit: 2001),
          throwsArgumentError,
        );

        final state = await repository.load();
        expect(state, isA<SpellingLearningState>());
        expect(fixture.openCalls, 1);
      },
    );

    test('exact spelling rows and frozen receipt round-trip through SQLite', () async {
      final repository = fixture.repository();
      final initial = await repository.load();
      final started = await fixture.commit(
        repository,
        initial,
        StartSpellingPractice(
          sessionId: 'sql-round-trip',
          policy: LessonPolicy(),
        ),
      );
      final answer = await fixture.answer(
        repository,
        started.state,
        correct: false,
      );
      final state = answer.state;
      final attempt = state.attempts.single;
      final db = await fixture.handle.open();
      final scopeId = await fixture.scopeId(db);

      final values = await db
          .customSelect(
            'SELECT field, ordinal, value_type, text_value, int_value, bool_value '
            'FROM learning_attempt_values WHERE scope_id = ? AND attempt_id = ? '
            'ORDER BY field, ordinal',
            variables: <Variable<Object>>[
              Variable<int>(scopeId),
              Variable<String>(attempt.attemptId),
            ],
          )
          .get();
      expect(
        values
            .map(
              (row) => <Object?>[
                row.read<String>('field'),
                row.read<int>('ordinal'),
                row.read<String>('value_type'),
                row.readNullable<String>('text_value'),
                row.readNullable<int>('int_value'),
                row.readNullable<int>('bool_value'),
              ],
            )
            .toList(),
        <List<Object?>>[
          <Object?>['choice', 0, 'text', 'u', null, null],
          <Object?>['choice', 1, 'text', 'ou', null, null],
          <Object?>[
            'expected_option_id',
            0,
            'text',
            attempt.expectedOptionId,
            null,
            null,
          ],
          <Object?>[
            'selected_option_id',
            0,
            'text',
            attempt.selectedOptionId,
            null,
            null,
          ],
          <Object?>['target_sound', 0, 'text', 'u', null, null],
          <Object?>['word_id', 0, 'text', 'tout', null, null],
        ],
      );

      final attemptRow = await db
          .customSelect(
            'SELECT activity_id, run_generation, command_sequence, batch_index, '
            'item_id, item_occurrence, content_revision, commit_ordinal, answer_kind, '
            'correct, skill, origin, presentation, assistance_mask, content_state, '
            'audio_source, round, after_debrief, teaching_exposed, selected_relation, '
            'expected_relation, section_id, sentence_id, annotation_hash, annotation_revision '
            'FROM learning_attempts WHERE scope_id = ? AND attempt_id = ?',
            variables: <Variable<Object>>[
              Variable<int>(scopeId),
              Variable<String>(attempt.attemptId),
            ],
          )
          .getSingle();
      expect(attemptRow.read<String>('activity_id'), _activityId);
      expect(attemptRow.read<int>('run_generation'), 1);
      expect(attemptRow.read<int>('command_sequence'), 2);
      expect(attemptRow.read<int>('batch_index'), 0);
      expect(attemptRow.read<String>('item_id'), 'uy-demo-spelling-01');
      expect(attemptRow.readNullable<int>('item_occurrence'), isNull);
      expect(attemptRow.read<int>('content_revision'), 1);
      expect(attemptRow.read<int>('commit_ordinal'), 2);
      expect(attemptRow.read<String>('answer_kind'), 'spellingChoice');
      expect(attemptRow.read<int>('correct'), 0);
      expect(attemptRow.read<String>('skill'), 'spelling');
      expect(attemptRow.read<String>('origin'), 'practice');
      expect(attemptRow.read<String>('presentation'), 'firstInRun');
      expect(attemptRow.read<int>('assistance_mask'), 0);
      expect(attemptRow.read<String>('content_state'), 'pending');
      expect(attemptRow.read<String>('audio_source'), 'pendingRecording');
      expect(attemptRow.read<int>('round'), 1);
      expect(attemptRow.read<int>('after_debrief'), 0);
      expect(attemptRow.readNullable<int>('teaching_exposed'), isNull);
      for (final column in <String>[
        'selected_relation',
        'expected_relation',
        'section_id',
        'sentence_id',
        'annotation_hash',
        'annotation_revision',
      ]) {
        expect(
          attemptRow.data[column],
          isNull,
          reason: '$column is unused for spelling',
        );
      }

      final evidence = await db
          .customSelect(
            'SELECT evidence_index, evidence_kind, slot, reference_id, outcome, '
            'source, activity_id, run_generation, round, pair_id, ui_generation, '
            'section_id, item_id, sentence_id, audio_ref_id, annotation_hash, '
            'annotation_revision, content_revision FROM learning_attempt_evidence '
            'WHERE scope_id = ? AND attempt_id = ?',
            variables: <Variable<Object>>[
              Variable<int>(scopeId),
              Variable<String>(attempt.attemptId),
            ],
          )
          .get();
      expect(evidence, hasLength(1));
      final playback = evidence.single;
      expect(playback.read<int>('evidence_index'), 0);
      expect(playback.read<String>('evidence_kind'), 'spellingPlayback');
      expect(playback.readNullable<String>('slot'), isNull);
      expect(playback.read<String>('reference_id'), 'fr-word-tout');
      expect(playback.read<String>('outcome'), 'completed');
      expect(playback.read<String>('source'), 'unverifiedRecording');
      expect(playback.read<String>('activity_id'), _activityId);
      expect(playback.read<int>('run_generation'), 1);
      expect(playback.read<int>('round'), 1);
      expect(playback.readNullable<String>('pair_id'), isNull);
      expect(playback.read<int>('ui_generation'), 43);
      expect(playback.readNullable<String>('section_id'), isNull);
      expect(playback.read<String>('item_id'), attempt.itemId);
      expect(playback.readNullable<String>('sentence_id'), isNull);
      expect(playback.readNullable<String>('audio_ref_id'), isNull);
      expect(playback.readNullable<String>('annotation_hash'), isNull);
      expect(playback.readNullable<int>('annotation_revision'), isNull);
      expect(playback.read<int>('content_revision'), 1);

      final receipt = await db
          .customSelect(
            'SELECT token, canonical_payload, activity_id, commit_ordinal '
            'FROM learning_command_receipts WHERE scope_id = ? AND token = ?',
            variables: <Variable<Object>>[
              Variable<int>(scopeId),
              Variable<String>(answer.command.token),
            ],
          )
          .getSingle();
      expect(receipt.read<String>('token'), answer.command.token);
      expect(
        receipt.read<String>('canonical_payload'),
        const SpellingLearningCommandCodec().encode(answer.command),
      );
      expect(receipt.read<String>('activity_id'), _activityId);
      expect(receipt.read<int>('commit_ordinal'), 2);
      final storedCommand =
          jsonDecode(receipt.read<String>('canonical_payload'))
              as Map<String, dynamic>;
      expect(storedCommand['authGeneration'], fixture.authGeneration);
      expect(
        (storedCommand['action']
            as Map<String, dynamic>)['playback']['authGeneration'],
        fixture.authGeneration,
      );

      final mistake = await db
          .customSelect(
            'SELECT family, activity_id, item_id, target_sound, skill, pair_id, '
            'section_id, sentence_id, audio_ref_id, annotation_hash, '
            'annotation_revision, content_revision FROM learning_mistakes '
            'WHERE scope_id = ?',
            variables: <Variable<Object>>[Variable<int>(scopeId)],
          )
          .getSingle();
      expect(mistake.read<String>('family'), 'spelling');
      expect(mistake.read<String>('activity_id'), _activityId);
      expect(mistake.read<String>('item_id'), attempt.itemId);
      expect(mistake.read<String>('target_sound'), 'u');
      expect(mistake.read<String>('skill'), 'spelling');
      for (final column in <String>[
        'pair_id',
        'section_id',
        'sentence_id',
        'audio_ref_id',
        'annotation_hash',
        'annotation_revision',
      ]) {
        expect(
          mistake.data[column],
          isNull,
          reason: '$column is unused for spelling',
        );
      }
      expect(mistake.read<int>('content_revision'), 1);

      final summaries = await db
          .customSelect(
            'SELECT family, activity_id, sound, skill, origin, presentation, '
            'assistance_mask, pair_id, section_id, item_id, sentence_id, '
            'audio_ref_id, annotation_hash, annotation_revision, content_revision, '
            'bucket, correct, total FROM learning_summaries WHERE scope_id = ? '
            'ORDER BY bucket',
            variables: <Variable<Object>>[Variable<int>(scopeId)],
          )
          .get();
      expect(summaries, hasLength(2));
      expect(summaries.map((row) => row.read<String>('bucket')).toSet(), {
        'firstInRun',
        'afterDebrief',
      });
      for (final summary in summaries) {
        expect(summary.read<String>('family'), 'spelling');
        expect(summary.read<String>('activity_id'), _activityId);
        expect(summary.read<String>('sound'), 'u');
        expect(summary.read<String>('skill'), 'spelling');
        expect(summary.read<String>('origin'), 'practice');
        expect(summary.readNullable<String>('presentation'), isNull);
        expect(summary.readNullable<int>('assistance_mask'), isNull);
        expect(summary.readNullable<String>('pair_id'), isNull);
        expect(summary.readNullable<String>('section_id'), isNull);
        expect(summary.read<String>('item_id'), attempt.itemId);
        expect(summary.readNullable<String>('sentence_id'), isNull);
        expect(summary.readNullable<String>('audio_ref_id'), isNull);
        expect(summary.readNullable<String>('annotation_hash'), isNull);
        expect(summary.readNullable<int>('annotation_revision'), isNull);
        expect(summary.read<int>('content_revision'), 1);
      }
      expect(
        (await db
                .customSelect(
                  'SELECT presentations, assistance_mask FROM learning_exposure '
                  'WHERE scope_id = ? AND item_id = ?',
                  variables: <Variable<Object>>[
                    Variable<int>(scopeId),
                    Variable<String>(attempt.itemId),
                  ],
                )
                .getSingle())
            .read<int>('presentations'),
        1,
      );
      expect(
        await db.customSelect('SELECT * FROM learning_best_scores').get(),
        isEmpty,
      );
      expect(
        await db.customSelect('SELECT * FROM supported_sync_outbox').get(),
        isEmpty,
      );

      await fixture.handle.close();
      await fixture.handle.reopen();
      final reopened = await repository.load();
      expect(
        reopened.attempts.single.selectedOptionId,
        attempt.selectedOptionId,
      );
      expect(
        reopened.attempts.single.expectedOptionId,
        attempt.expectedOptionId,
      );
      expect(reopened.attempts.single.playback.promptEpoch, 43);
      expect(
        reopened.slots[_activityId]!.checkpoint.mode,
        SpellingRunMode.practice,
      );
      expect(
        reopened.slots[_activityId]!.latestReceipt.canonicalCommand,
        receipt.read<String>('canonical_payload'),
      );
      expect(reopened.receipts.map((receipt) => receipt.commitOrdinal), <int>[
        1,
        2,
      ]);
    });

    test(
      'spelling_answer_ack_is_idempotent_and_does_not_duplicate_exposure',
      () async {
        final repository = fixture.repository();
        var state = await repository.load();
        state = (await fixture.commit(
          repository,
          state,
          StartSpellingPractice(
            sessionId: 'ack-practice',
            policy: LessonPolicy(),
          ),
        )).state;
        final answer = await fixture.answer(repository, state, correct: false);
        final afterFirstAck = answer.state;
        expect(afterFirstAck.attempts, hasLength(1));
        expect(afterFirstAck.receipts, hasLength(2));
        expect(afterFirstAck.completions, isEmpty);
        final notificationsAfterAck = fixture.notifications;

        final duplicate = await repository.submit(answer.command);
        expect(duplicate.duplicate, isTrue);
        expect(duplicate.state.attempts, hasLength(1));
        expect(duplicate.state.attempts.single.itemId, 'uy-demo-spelling-01');
        expect(
          duplicate.state.slots[_activityId]!.checkpoint.firstAttemptAnswers,
          {'uy-demo-spelling-01': false},
        );
        expect(duplicate.state.completions, isEmpty);
        expect(fixture.notifications, notificationsAfterAck);

        final db = await fixture.handle.open();
        final scopeId = await fixture.scopeId(db);
        expect(await fixture.count(db, 'learning_attempts', scopeId), 1);
        expect(
          await fixture.count(
            db,
            'learning_command_receipts',
            scopeId,
            where: 'token = ?',
            args: <Object?>[answer.command.token],
          ),
          1,
        );
        final exposure = await db
            .customSelect(
              'SELECT presentations FROM learning_exposure WHERE scope_id = ? '
              'AND item_id = ?',
              variables: <Variable<Object>>[
                Variable<int>(scopeId),
                const Variable<String>('uy-demo-spelling-01'),
              ],
            )
            .getSingle();
        expect(exposure.read<int>('presentations'), 1);

        final changedPayload = SpellingLearningCommand(
          scope: answer.command.scope,
          authGeneration: answer.command.authGeneration,
          activityId: answer.command.activityId,
          expected: answer.command.expected,
          expectedScopeRevision: answer.command.expectedScopeRevision,
          token: answer.command.token,
          submittedAt: answer.command.submittedAt,
          action: AnswerSpellingChoice(
            itemId: 'uy-demo-spelling-01',
            contentRevision: 1,
            selectedOptionId:
                answer.command.action is AnswerSpellingChoice &&
                    (answer.command.action as AnswerSpellingChoice)
                            .selectedOptionId ==
                        'u'
                ? 'ou'
                : 'u',
            expectedOptionIdSnapshot:
                (answer.command.action as AnswerSpellingChoice)
                    .expectedOptionIdSnapshot,
            playback: (answer.command.action as AnswerSpellingChoice).playback,
          ),
        );
        await expectLater(
          repository.submit(changedPayload),
          throwsA(isA<LearningInvalidCommandException>()),
        );
        expect(await fixture.count(db, 'learning_attempts', scopeId), 1);
        expect(fixture.notifications, notificationsAfterAck);
      },
    );

    test(
      'stale revision and foreign owner commands do not partially write',
      () async {
        final repository = fixture.repository();
        final empty = await repository.load();
        final firstStart = repository.prepare(
          state: empty,
          action: StartSpellingPractice(
            sessionId: 'first-start',
            policy: LessonPolicy(),
          ),
        );
        final staleStart = repository.prepare(
          state: empty,
          action: StartSpellingPractice(
            sessionId: 'stale-start',
            policy: LessonPolicy(),
          ),
        );
        await repository.submit(firstStart);
        final db = await fixture.handle.open();
        final scopeId = await fixture.scopeId(db);
        final before = await fixture.relationCounts(db, scopeId);
        await expectLater(
          repository.submit(staleStart),
          throwsA(isA<LearningConflictException>()),
        );
        expect(await fixture.relationCounts(db, scopeId), before);

        final foreignScope = SpellingProfileScope(
          courseId: 'en-fr',
          owner: LearningOwner.account('another-owner'),
        );
        final foreignRepository = fixture.repository(scope: foreignScope);
        expect(
          () => foreignRepository.prepare(
            state: empty,
            action: const AdvanceSpellingItem(),
          ),
          throwsA(isA<LearningOwnerChangedException>()),
        );
        final current = await repository.load();
        final foreignCommand = SpellingLearningCommand(
          scope: foreignScope,
          authGeneration: fixture.authGeneration,
          activityId: _activityId,
          expected: current.slots[_activityId]!.cursor,
          expectedScopeRevision: current.revision,
          token: fixture.nextToken(),
          submittedAt: fixture.clock().toUtc(),
          action: StartSpellingPractice(
            sessionId: 'foreign-command',
            policy: LessonPolicy(),
          ),
        );
        await expectLater(
          repository.submit(foreignCommand),
          throwsA(isA<LearningInvalidCommandException>()),
        );
        expect(await fixture.relationCounts(db, scopeId), before);

        final state = await repository.load();
        final action = AnswerSpellingChoice(
          itemId: 'uy-demo-spelling-01',
          contentRevision: 1,
          selectedOptionId: 'u',
          expectedOptionIdSnapshot: 'ou',
          playback: fixture.playback(
            state,
            itemId: 'uy-demo-spelling-01',
            promptEpoch: 7,
          ),
        );
        final staleAnswer = repository.prepare(state: state, action: action);
        final competingAnswer = repository.prepare(
          state: state,
          action: AnswerSpellingChoice(
            itemId: 'uy-demo-spelling-01',
            contentRevision: 1,
            selectedOptionId: 'ou',
            expectedOptionIdSnapshot: 'ou',
            playback: fixture.playback(
              state,
              itemId: 'uy-demo-spelling-01',
              promptEpoch: 8,
            ),
          ),
        );
        await repository.submit(competingAnswer);
        final afterWinner = await fixture.relationCounts(db, scopeId);
        await expectLater(
          repository.submit(staleAnswer),
          throwsA(isA<LearningConflictException>()),
        );
        expect(await fixture.relationCounts(db, scopeId), afterWinner);
      },
    );

    test('spelling_sql_rejects_cross_family_shapes', () async {
      final repository = fixture.repository();
      var state = await repository.load();
      state = (await fixture.commit(
        repository,
        state,
        StartSpellingPractice(sessionId: 'shape-test', policy: LessonPolicy()),
      )).state;
      state = (await fixture.answer(repository, state, correct: true)).state;
      final db = await fixture.handle.open();
      final scopeId = await fixture.scopeId(db);
      final attemptId = state.attempts.single.attemptId;

      final choices = await db
          .customSelect(
            'SELECT field, text_value FROM learning_attempt_values '
            'WHERE scope_id = ? AND attempt_id = ? ORDER BY field, ordinal',
            variables: <Variable<Object>>[
              Variable<int>(scopeId),
              Variable<String>(attemptId),
            ],
          )
          .get();
      expect(choices.map((row) => row.read<String>('field')).toSet(), {
        'choice',
        'selected_option_id',
        'expected_option_id',
        'word_id',
        'target_sound',
      });
      expect(
        choices
            .where((row) => row.read<String>('field') == 'choice')
            .map((row) => row.read<String>('text_value'))
            .toList(),
        ['u', 'ou'],
      );
      await expectLater(
        db.customStatement(
          'UPDATE learning_summaries SET bucket = ? WHERE scope_id = ?',
          ['repeatInRun', scopeId],
        ),
        throwsA(anything),
      );

      await expectLater(
        db.customStatement(
          'UPDATE learning_attempt_values SET field = ? WHERE scope_id = ? '
          'AND attempt_id = ? AND field = ?',
          ['selected_sound', scopeId, attemptId, 'selected_option_id'],
        ),
        throwsA(anything),
      );
      expect(
        (await repository.load()).attempts.single.selectedOptionId,
        state.attempts.single.selectedOptionId,
        reason: 'the SQL family trigger rejects phoneme-shaped value fields',
      );
      final playback = state.attempts.single.playback;
      await db.customStatement(
        'UPDATE learning_attempt_evidence SET ui_generation = ? '
        'WHERE scope_id = ? AND attempt_id = ?',
        [playback.promptEpoch + 1, scopeId, attemptId],
      );
      await expectLater(
        repository.load(),
        throwsA(isA<LearningCorruptException>()),
      );
      await db.customStatement(
        'UPDATE learning_attempt_evidence SET ui_generation = ? '
        'WHERE scope_id = ? AND attempt_id = ?',
        [playback.promptEpoch, scopeId, attemptId],
      );
      await expectLater(
        db.customStatement(
          'UPDATE learning_runs SET activity_kind = ? WHERE scope_id = ?',
          ['comparison', scopeId],
        ),
        throwsA(anything),
      );
      expect((await repository.load()).attempts, hasLength(1));
    });

    test(
      'completion_requires_acked_practice_finish_at_saved_threshold',
      () async {
        final repository = fixture.repository();
        var state = await repository.load();
        state = (await fixture.commit(
          repository,
          state,
          StartSpellingPractice(
            sessionId: 'qualifying-practice',
            policy: LessonPolicy(),
          ),
        )).state;
        final beforePrematureFinishDb = await fixture.handle.open();
        final beforePrematureFinishScopeId = await fixture.scopeId(
          beforePrematureFinishDb,
        );
        final beforePrematureFinishCounts = await fixture.relationCounts(
          beforePrematureFinishDb,
          beforePrematureFinishScopeId,
        );
        await expectLater(
          repository.submit(
            fixture.commandFor(
              state,
              action: const FinishSpellingRun(recordCompletion: true),
            ),
          ),
          throwsA(isA<LearningInvalidCommandException>()),
        );
        final rejectedPrematureFinish = await repository.load();
        expect(rejectedPrematureFinish.completions, isEmpty);
        expect(rejectedPrematureFinish.revision, state.revision);
        expect(
          await fixture.relationCounts(
            beforePrematureFinishDb,
            beforePrematureFinishScopeId,
          ),
          beforePrematureFinishCounts,
        );

        state = await fixture.finishRound(repository, state, correctCount: 8);
        expect(state.completions, isEmpty, reason: 'answer ACKs do not Finish');
        final inspection = await repository.load();
        expect(
          inspection.completions,
          isEmpty,
          reason: 'inspection is read-only',
        );
        final beforeFinish = inspection.revision;
        final finished = await fixture.commit(
          repository,
          inspection,
          const FinishSpellingRun(recordCompletion: true),
        );
        expect(finished.state.revision, beforeFinish + 1);
        expect(finished.state.completions, hasLength(1));
        final completion = finished.state.completions.single;
        expect(completion.policyKind, CompletionPolicyKind.discoveryThreshold);
        expect(completion.policyRevision, 1);
        expect(completion.thresholdPercent, 80);
        final db = await fixture.handle.open();
        final scopeId = await fixture.scopeId(db);
        final run = await db
            .customSelect(
              'SELECT run_mode, policy_revision, threshold_percent '
              'FROM learning_runs WHERE scope_id = ?',
              variables: <Variable<Object>>[Variable<int>(scopeId)],
            )
            .getSingle();
        expect(run.read<String>('run_mode'), 'practice');
        expect(run.read<int>('policy_revision'), 1);
        expect(run.read<int>('threshold_percent'), 80);

        final underThreshold = await _Fixture.create(
          owner: LearningOwner.account('below-threshold'),
        );
        addTearDown(underThreshold.close);
        final belowRepository = underThreshold.repository();
        var below = await belowRepository.load();
        below = (await underThreshold.commit(
          belowRepository,
          below,
          StartSpellingPractice(sessionId: 'below-80', policy: LessonPolicy()),
        )).state;
        below = await underThreshold.finishRound(
          belowRepository,
          below,
          correctCount: 7,
        );
        expect(below.completions, isEmpty);
        await expectLater(
          belowRepository.submit(
            underThreshold.commandFor(
              below,
              action: const FinishSpellingRun(recordCompletion: true),
            ),
          ),
          throwsA(isA<LearningInvalidCommandException>()),
        );
        final rejectedBelowThreshold = await belowRepository.load();
        expect(rejectedBelowThreshold.completions, isEmpty);
        expect(rejectedBelowThreshold.revision, below.revision);
      },
    );

    test(
      'review_only_mode_survives_query_removal_without_completion',
      () async {
        final repository = fixture.repository();
        var state = await repository.load();
        state = (await fixture.commit(
          repository,
          state,
          StartSpellingPractice(
            sessionId: 'source-practice',
            policy: LessonPolicy(),
          ),
        )).state;
        state = await fixture.finishRound(repository, state, correctCount: 9);
        state = (await fixture.commit(
          repository,
          state,
          const FinishSpellingRun(recordCompletion: true),
        )).state;
        expect(state.completions, hasLength(1));
        expect(state.completions.single.thresholdPercent, 80);
        final practiceScore = Map<String, bool>.of(
          state.slots[_activityId]!.checkpoint.firstAttemptAnswers,
        );

        state = (await fixture.commit(
          repository,
          state,
          const StartSpellingReviewOnly(sessionId: 'persisted-review'),
        )).state;
        expect(
          state.slots[_activityId]!.checkpoint.mode,
          SpellingRunMode.reviewOnly,
        );
        await fixture.handle.close();
        await fixture.handle.reopen();
        state = await repository.load(); // no caller review query is supplied
        final checkpoint = state.slots[_activityId]!.checkpoint;
        expect(checkpoint.mode, SpellingRunMode.reviewOnly);
        expect(checkpoint.baseline!.firstAttemptAnswers, practiceScore);
        expect(checkpoint.baseline!.latestPracticeAnswers, practiceScore);
        expect(state.completions.single.thresholdPercent, 80);

        state = (await fixture.answer(repository, state, correct: true)).state;
        state = (await fixture.commit(
          repository,
          state,
          const AdvanceSpellingItem(),
        )).state;
        expect(_session(state).phase, LessonSectionPhase.debrief);
        await expectLater(
          repository.submit(
            fixture.commandFor(
              state,
              action: const FinishSpellingRun(recordCompletion: true),
            ),
          ),
          throwsA(isA<LearningInvalidCommandException>()),
        );
        final afterRejectedReviewCompletion = await repository.load();
        expect(afterRejectedReviewCompletion.completions, hasLength(1));
        expect(afterRejectedReviewCompletion.revision, state.revision);

        final reviewFinish = await fixture.commit(
          repository,
          state,
          const FinishSpellingRun(recordCompletion: false),
        );
        expect(reviewFinish.state.completions, hasLength(1));
        expect(
          reviewFinish.state.slots[_activityId]!.checkpoint.mode,
          SpellingRunMode.reviewOnly,
        );
        expect(
          reviewFinish
              .state
              .slots[_activityId]!
              .checkpoint
              .baseline!
              .latestPracticeAnswers,
          practiceScore,
        );
      },
    );

    test(
      'retention_prune_keeps_first_score_baseline_and_latest_receipt',
      () async {
        final repository = fixture.repository(historyLimit: 10);
        var state = await repository.load();
        state = (await fixture.commit(
          repository,
          state,
          StartSpellingPractice(
            sessionId: 'retention-practice',
            policy: LessonPolicy(),
          ),
        )).state;
        state = await fixture.finishRound(repository, state, correctCount: 0);
        final firstScore = Map<String, bool>.of(
          state.slots[_activityId]!.checkpoint.firstAttemptAnswers,
        );
        expect(firstScore, hasLength(10));
        expect(firstScore.values.toSet(), {false});

        state = (await fixture.commit(
          repository,
          state,
          const StartSpellingReviewOnly(sessionId: 'retention-review'),
        )).state;
        final baseline = state.slots[_activityId]!.checkpoint.baseline!;
        expect(state.slots[_activityId]!.cursor.generation, 2);
        expect(baseline.sourceGeneration, 1);
        expect(baseline.sourceSessionId, 'retention-practice');
        expect(baseline.sourceContentRevision, 1);
        expect(baseline.sourceRound, 1);
        expect(state.slots[_activityId]!.checkpoint.runStartRound, 2);
        expect(baseline.firstAttemptAnswers, firstScore);
        expect(baseline.latestPracticeAnswers, firstScore);
        state = await fixture.finishRound(repository, state, correctCount: 0);
        state = (await fixture.commit(
          repository,
          state,
          const ReviewSpellingMistakes(),
        )).state;
        final latestAnswer = await fixture.answer(
          repository,
          state,
          correct: false,
        );
        state = latestAnswer.state;
        expect(
          state.slots[_activityId]!.checkpoint.mode,
          SpellingRunMode.reviewOnly,
        );
        expect(_session(state).round, 3);
        expect(state.attempts, hasLength(10));
        expect(state.attempts.last.attemptId, latestAnswer.command.token);
        expect(state.receipts, hasLength(10));
        expect(state.receipts.last.token, latestAnswer.command.token);
        expect(
          state.slots[_activityId]!.latestReceipt.token,
          latestAnswer.command.token,
        );
        expect(
          state.slots[_activityId]!.checkpoint.firstAttemptAnswers,
          firstScore,
        );
        expect(
          state.slots[_activityId]!.checkpoint.baseline!.firstAttemptAnswers,
          firstScore,
        );
        expect(
          state.slots[_activityId]!.checkpoint.baseline!.latestPracticeAnswers,
          firstScore,
        );

        final db = await fixture.handle.open();
        final scopeId = await fixture.scopeId(db);
        expect(await fixture.allRelationCounts(db, scopeId), <String, int>{
          'learning_scopes': 1,
          'learning_content_bindings': 1,
          'learning_runs': 1,
          'learning_attempts': 10,
          'learning_attempt_values': 60,
          'learning_attempt_evidence': 10,
          'learning_command_receipts': 10,
          'learning_mistakes': 10,
          'learning_summaries': 20,
          'learning_completions': 0,
          'learning_exposure': 10,
          'learning_best_scores': 0,
          'supported_sync_outbox': 0,
        });
        expect(
          (await repository.submit(latestAnswer.command)).duplicate,
          isTrue,
        );
        expect(await fixture.allRelationCounts(db, scopeId), {
          'learning_scopes': 1,
          'learning_content_bindings': 1,
          'learning_runs': 1,
          'learning_attempts': 10,
          'learning_attempt_values': 60,
          'learning_attempt_evidence': 10,
          'learning_command_receipts': 10,
          'learning_mistakes': 10,
          'learning_summaries': 20,
          'learning_completions': 0,
          'learning_exposure': 10,
          'learning_best_scores': 0,
          'supported_sync_outbox': 0,
        });
        expect(fixture.notifications, state.revision);
      },
    );

    test('orphan spelling binding corruption stays local to spelling', () async {
      final spelling = fixture.repository();
      await spelling.load();
      final db = await fixture.handle.open();
      final scopeId = await fixture.scopeId(db);
      await db.customStatement(
        'INSERT INTO learning_content_bindings '
        '(scope_id, activity_id, content_revision, policy_kind, policy_revision, '
        'catalogue_fingerprint, section_fingerprint, annotation_hash, annotation_revision) '
        "VALUES (?, ?, 1, 'discoveryThreshold', 1, 'uy-demo-spelling-v0', NULL, NULL, NULL)",
        [scopeId, _activityId],
      );

      await expectLater(
        spelling.load(),
        throwsA(isA<LearningContentChangedException>()),
      );

      final auth = LearningAuthScope(
        owner: fixture.scope.owner,
        generation: fixture.authGeneration,
        ready: true,
      );
      final course = SqliteCourseLearningRepository(
        database: fixture.handle,
        scope: LearningScope(courseId: 'en-fr', owner: fixture.scope.owner),
        authGeneration: fixture.authGeneration,
        currentAuth: () => auth,
        backendOwner: () => fixture.scope.owner,
        transitions: LearningTransitionEngine(LearningRegistry.french()),
        clock: fixture.clock,
        newToken: fixture.nextToken,
        random: Random(3),
      );
      expect((await course.load()).activities, isEmpty);
    });

    test(
      'spelling corruption is local; physical migration failure is global',
      () async {
        final spelling = fixture.repository();
        final empty = await spelling.load();
        final started = await fixture.commit(
          spelling,
          empty,
          StartSpellingPractice(
            sessionId: 'corruption-scope',
            policy: LessonPolicy(),
          ),
        );
        final db = await fixture.handle.open();
        final scopeId = await fixture.scopeId(db);
        await db.customStatement(
          'UPDATE learning_content_bindings SET content_revision = 2 '
          'WHERE scope_id = ? AND activity_id = ?',
          [scopeId, _activityId],
        );
        await expectLater(
          spelling.load(),
          throwsA(isA<LearningContentChangedException>()),
        );

        final auth = LearningAuthScope(
          owner: fixture.scope.owner,
          generation: fixture.authGeneration,
          ready: true,
        );
        final course = SqliteCourseLearningRepository(
          database: fixture.handle,
          scope: LearningScope(courseId: 'en-fr', owner: fixture.scope.owner),
          authGeneration: fixture.authGeneration,
          currentAuth: () => auth,
          backendOwner: () => fixture.scope.owner,
          transitions: LearningTransitionEngine(LearningRegistry.french()),
          clock: fixture.clock,
          newToken: fixture.nextToken,
          random: Random(1),
        );
        expect((await course.load()).activities, isEmpty);
        expect(started.state.revision, 1);

        final migration = await _Fixture.create(migrationFailure: true);
        addTearDown(migration.close);
        final failedSpelling = migration.repository();
        final migrationAuth = LearningAuthScope(
          owner: migration.scope.owner,
          generation: migration.authGeneration,
          ready: true,
        );
        final failedCourse = SqliteCourseLearningRepository(
          database: migration.handle,
          scope: LearningScope(courseId: 'en-fr', owner: migration.scope.owner),
          authGeneration: migration.authGeneration,
          currentAuth: () => migrationAuth,
          backendOwner: () => migration.scope.owner,
          transitions: LearningTransitionEngine(LearningRegistry.french()),
          clock: migration.clock,
          newToken: migration.nextToken,
          random: Random(2),
        );
        await expectLater(
          failedSpelling.load(),
          throwsA(isA<LearningUnavailableException>()),
        );
        await expectLater(
          failedCourse.load(),
          throwsA(isA<LearningUnavailableException>()),
        );
      },
    );
  });
}

LessonSectionSession _session(SpellingLearningState state) {
  final checkpoint = state.slots[_activityId]!.checkpoint;
  return LessonSectionSession.fromJson(
    Map<String, dynamic>.from(checkpoint.sessionJson),
    itemIds: loadFrenchUyDemoSpellingCatalogue().rows
        .map((row) => row.exercise.id)
        .toList(),
    contentRevision: checkpoint.contentRevision,
  );
}

final class _Answer {
  const _Answer(this.state, this.command);

  final SpellingLearningState state;
  final SpellingLearningCommand command;
}

final class _Fixture {
  _Fixture(
    this.directory, {
    LearningOwner? owner,
    required this.migrationFailure,
  }) : scope = SpellingProfileScope(
         courseId: 'en-fr',
         owner: owner ?? LearningOwner.guest(),
       );

  final Directory directory;
  final SpellingProfileScope scope;
  final bool migrationFailure;
  final int authGeneration = 9;
  int openCalls = 0;
  int notifications = 0;
  int _tokenCounter = 0;
  int _clockCounter = 0;
  bool _v1Seeded = false;

  late final LearningDatabaseHandle handle = LearningDatabaseHandle(
    open: () async {
      openCalls++;
      final file = File('${directory.path}/learning.sqlite');
      final connection = DatabaseConnection(NativeDatabase(file));
      if (!migrationFailure) return LearningDatabase.openValidated(connection);
      if (!_v1Seeded) {
        final seedConnection = DatabaseConnection(NativeDatabase(file));
        try {
          await openPublishedLearningV1Fixture(seedConnection);
        } finally {
          await seedConnection.executor.close();
        }
        _v1Seeded = true;
      }
      return LearningDatabase.openValidatedForMigrationTesting(
        connection,
        onPoint: (point) {
          if (point == LearningMigrationFailurePoint.beforeVersion2Commit) {
            throw StateError('forced physical v1-to-v2 migration failure');
          }
        },
      );
    },
  );

  static Future<_Fixture> create({
    LearningOwner? owner,
    bool migrationFailure = false,
  }) async {
    final directory = await Directory.systemTemp.createTemp('spelling-sql-');
    return _Fixture(
      directory,
      owner: owner,
      migrationFailure: migrationFailure,
    );
  }

  SqliteSpellingLearningRepository repository({
    SpellingProfileScope? scope,
    int historyLimit = 2000,
  }) {
    final profile = scope ?? this.scope;
    return SqliteSpellingLearningRepository(
      database: handle,
      scope: profile,
      authGeneration: authGeneration,
      currentAuth: () => LearningAuthScope(
        owner: this.scope.owner,
        generation: authGeneration,
        ready: true,
      ),
      backendOwner: () => this.scope.owner,
      transitions: SpellingLearningTransitionEngine(
        catalogue: loadFrenchUyDemoSpellingCatalogue(),
      ),
      clock: clock,
      newToken: nextToken,
      onCommitted: () => notifications++,
      historyLimit: historyLimit,
    );
  }

  DateTime clock() =>
      DateTime.utc(2026, 10, 24).add(Duration(microseconds: ++_clockCounter));

  String nextToken() => (++_tokenCounter).toString().padLeft(22, '0');

  Future<SpellingCommit> commit(
    SqliteSpellingLearningRepository repository,
    SpellingLearningState state,
    SpellingAction action,
  ) => repository.submit(repository.prepare(state: state, action: action));

  SpellingLearningCommand commandFor(
    SpellingLearningState state, {
    required SpellingAction action,
  }) {
    final slot = state.slots[_activityId];
    if (slot == null) throw StateError('Spelling run has not started.');
    return SpellingLearningCommand(
      scope: scope,
      authGeneration: authGeneration,
      activityId: _activityId,
      expected: slot.cursor,
      expectedScopeRevision: state.revision,
      token: nextToken(),
      submittedAt: clock().toUtc(),
      action: action,
    );
  }

  SpellingPlaybackObservation playback(
    SpellingLearningState state, {
    required String itemId,
    required int promptEpoch,
  }) {
    final row = loadFrenchUyDemoSpellingCatalogue().rows.singleWhere(
      (candidate) => candidate.exercise.id == itemId,
    );
    final slot = state.slots[_activityId];
    final session = slot == null ? null : _session(state);
    return SpellingPlaybackObservation(
      profile: scope,
      authGeneration: authGeneration,
      activityId: _activityId,
      contentRevision: 1,
      runGeneration: slot?.cursor.generation ?? 1,
      round: session?.round ?? 1,
      itemId: itemId,
      referenceId: row.exercise.audioRefId,
      promptEpoch: promptEpoch,
      outcome: CourseAudioOutcome.completed,
      source: CourseAudioSource.unverifiedRecording,
    );
  }

  Future<_Answer> answer(
    SqliteSpellingLearningRepository repository,
    SpellingLearningState state, {
    required bool correct,
  }) async {
    final session = _session(state);
    final itemId = session.currentItemId!;
    final row = loadFrenchUyDemoSpellingCatalogue().rows.singleWhere(
      (candidate) => candidate.exercise.id == itemId,
    );
    final expected = row.exercise.correctOptionId;
    final selected = correct ? expected : (expected == 'u' ? 'ou' : 'u');
    final command = repository.prepare(
      state: state,
      action: AnswerSpellingChoice(
        itemId: itemId,
        contentRevision: 1,
        selectedOptionId: selected,
        expectedOptionIdSnapshot: expected,
        playback: playback(
          state,
          itemId: itemId,
          promptEpoch: state.revision + 42,
        ),
      ),
    );
    final saved = await repository.submit(command);
    return _Answer(saved.state, command);
  }

  Future<SpellingLearningState> finishRound(
    SqliteSpellingLearningRepository repository,
    SpellingLearningState state, {
    required int correctCount,
  }) async {
    for (var index = 0; index < 10; index++) {
      final answered = await answer(
        repository,
        state,
        correct: index < correctCount,
      );
      state = answered.state;
      state = (await commit(
        repository,
        state,
        const AdvanceSpellingItem(),
      )).state;
    }
    expect(_session(state).phase, LessonSectionPhase.debrief);
    return state;
  }

  Future<int> scopeId(LearningDatabase db) async {
    final rows = await db
        .customSelect(
          'SELECT id FROM learning_scopes WHERE owner_kind = ? AND owner_id = ? '
          'AND course_id = ? AND family = ?',
          variables: <Variable<Object>>[
            Variable<String>(scope.owner.isGuest ? 'guest' : 'account'),
            Variable<String>(scope.owner.userId ?? ''),
            const Variable<String>('en-fr'),
            const Variable<String>('spelling'),
          ],
        )
        .get();
    expect(rows, hasLength(1));
    return rows.single.read<int>('id');
  }

  Future<int> count(
    LearningDatabase db,
    String relation,
    int scopeId, {
    String? where,
    List<Object?> args = const <Object?>[],
  }) async {
    final rows = await db
        .customSelect(
          'SELECT count(*) AS count FROM $relation WHERE scope_id = ?'
          '${where == null ? '' : ' AND $where'}',
          variables: <Variable<Object>>[
            Variable<int>(scopeId),
            for (final argument in args) Variable<Object>(argument),
          ],
        )
        .getSingle();
    return rows.read<int>('count');
  }

  Future<Map<String, int>> relationCounts(
    LearningDatabase db,
    int scopeId,
  ) async {
    final relations = <String>[
      'learning_scopes',
      'learning_content_bindings',
      'learning_runs',
      'learning_attempts',
      'learning_attempt_values',
      'learning_attempt_evidence',
      'learning_command_receipts',
      'learning_mistakes',
      'learning_summaries',
      'learning_completions',
      'learning_exposure',
      'learning_best_scores',
      'supported_sync_outbox',
    ];
    return <String, int>{
      for (final relation in relations)
        relation: relation == 'learning_scopes'
            ? (await db
                      .customSelect(
                        'SELECT count(*) AS count FROM learning_scopes WHERE id = ?',
                        variables: <Variable<Object>>[Variable<int>(scopeId)],
                      )
                      .getSingle())
                  .read<int>('count')
            : await count(db, relation, scopeId),
    };
  }

  Future<Map<String, int>> allRelationCounts(
    LearningDatabase db,
    int scopeId,
  ) => relationCounts(db, scopeId);

  Future<void> close() async {
    await handle.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
