import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_audio_contract.dart';
import 'package:linguist/src/core/course/french_uy_demo_spelling_content.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/spelling_learning_command.dart';
import 'package:linguist/src/core/course/spelling_learning_state.dart';
import 'package:linguist/src/core/course/spelling_learning_transition.dart';
import 'package:linguist/src/core/course/storage/learning_tables.dart'
    show learningMaxCheckpointBytes;
import 'package:linguist/src/core/course/storage/spelling_learning_checkpoint_codec.dart';
import 'package:linguist/src/core/course/storage/spelling_learning_command_codec.dart';
import 'package:linguist/src/core/course/spelling_learning_validator.dart';

void main() {
  final catalogue = loadFrenchUyDemoSpellingCatalogue();
  final scope = SpellingProfileScope(
    courseId: 'en-fr',
    owner: LearningOwner.guest(),
  );
  final policy = LessonPolicy();
  final engine = SpellingLearningTransitionEngine(catalogue: catalogue);
  const commandCodec = SpellingLearningCommandCodec();
  const checkpointCodec = SpellingLearningCheckpointCodec();

  SpellingLearningCommand startCommand() => engine.prepare(
    state: SpellingLearningState.empty(scope),
    action: StartSpellingPractice(sessionId: 'codec-session', policy: policy),
    authGeneration: 4,
    token: 'codec-token-0000000001',
    submittedAt: DateTime.utc(2026, 10, 24),
  );

  SpellingCheckpoint startCheckpoint() {
    final transition = engine.evaluate(
      state: SpellingLearningState.empty(scope),
      command: startCommand(),
      committedAt: DateTime.utc(2026, 10, 24),
    );
    return transition.slot.checkpoint;
  }

  SpellingLearningCommand answerCommand() {
    final empty = SpellingLearningState.empty(scope);
    final started = engine.evaluate(
      state: empty,
      command: startCommand(),
      committedAt: DateTime.utc(2026, 10, 24),
    );
    final row = catalogue.rows.first;
    return engine.prepare(
      state: started.nextState,
      action: AnswerSpellingChoice(
        itemId: row.exercise.id,
        contentRevision: catalogue.contentRevision,
        selectedOptionId: row.exercise.correctOptionId,
        expectedOptionIdSnapshot: row.exercise.correctOptionId,
        playback: SpellingPlaybackObservation(
          profile: scope,
          authGeneration: 4,
          activityId: catalogue.activityId,
          contentRevision: catalogue.contentRevision,
          runGeneration: 1,
          round: 1,
          itemId: row.exercise.id,
          referenceId: row.exercise.audioRefId,
          promptEpoch: 9,
          outcome: CourseAudioOutcome.completed,
          source: CourseAudioSource.unverifiedRecording,
        ),
      ),
      authGeneration: 4,
      token: 'answer-token-000000001',
      submittedAt: DateTime.utc(2026, 10, 24, 0, 0, 1),
    );
  }

  SpellingCheckpoint completeCheckpoint() {
    var state = SpellingLearningState.empty(scope);
    var step = 0;
    void apply(SpellingAction action) {
      final now = DateTime.utc(2026, 10, 24).add(Duration(microseconds: step));
      final command = engine.prepare(
        state: state,
        action: action,
        authGeneration: 4,
        token: 'full-token-${step.toString().padLeft(11, '0')}',
        submittedAt: now,
      );
      state = engine
          .evaluate(state: state, command: command, committedAt: now)
          .nextState;
      step += 1;
    }

    apply(StartSpellingPractice(sessionId: 'full-session', policy: policy));
    for (final row in catalogue.rows) {
      final slot = state.slots[catalogue.activityId]!;
      final session = LessonSectionSession.fromJson(
        Map<String, dynamic>.from(slot.checkpoint.sessionJson),
        itemIds: catalogue.rows.map((item) => item.exercise.id).toList(),
        contentRevision: catalogue.contentRevision,
      );
      final id = session.currentItemId!;
      final current = catalogue.rows.singleWhere(
        (item) => item.exercise.id == id,
      );
      final expected = current.exercise.correctOptionId;
      final wrong = current.exercise.options
          .singleWhere((option) => option.id != expected)
          .id;
      apply(
        AnswerSpellingChoice(
          itemId: id,
          contentRevision: catalogue.contentRevision,
          selectedOptionId: row.exercise.id == catalogue.rows.first.exercise.id
              ? wrong
              : expected,
          expectedOptionIdSnapshot: expected,
          playback: SpellingPlaybackObservation(
            profile: scope,
            authGeneration: 4,
            activityId: catalogue.activityId,
            contentRevision: catalogue.contentRevision,
            runGeneration: slot.cursor.generation,
            round: session.round,
            itemId: id,
            referenceId: current.exercise.audioRefId,
            promptEpoch: step,
            outcome: CourseAudioOutcome.completed,
            source: CourseAudioSource.unverifiedRecording,
          ),
        ),
      );
      apply(const AdvanceSpellingItem());
    }
    return state.slots[catalogue.activityId]!.checkpoint;
  }

  test(
    'command codec pins ordered v1 fields and byte-identical round trip',
    () {
      final encoded = commandCodec.encode(startCommand());
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      expect(decoded.keys, [
        'version',
        'scope',
        'authGeneration',
        'activityId',
        'expected',
        'expectedScopeRevision',
        'token',
        'submittedAt',
        'action',
      ]);
      expect((decoded['scope'] as Map).keys, ['courseId', 'owner']);
      expect((decoded['scope'] as Map)['owner'].keys, ['kind', 'id']);
      expect((decoded['expected'] as Map).keys, [
        'generation',
        'sequence',
        'revision',
      ]);
      expect((decoded['action'] as Map).keys, ['kind', 'sessionId', 'policy']);
      expect(commandCodec.encode(commandCodec.decode(encoded)), encoded);
    },
  );

  test('command decoder rejects out-of-order and extra fields', () {
    final command =
        jsonDecode(commandCodec.encode(startCommand())) as Map<String, dynamic>;
    final reordered = jsonEncode({
      for (final key in command.keys.toList().reversed) key: command[key],
    });
    expect(() => commandCodec.decode(reordered), throwsFormatException);

    final extended = Map<String, dynamic>.of(command)..['extra'] = true;
    expect(
      () => commandCodec.decode(jsonEncode(extended)),
      throwsFormatException,
    );

    final answer =
        jsonDecode(commandCodec.encode(answerCommand()))
            as Map<String, dynamic>;
    final action = Map<String, dynamic>.of(
      answer['action'] as Map<String, dynamic>,
    );
    expect(action.keys, [
      'kind',
      'itemId',
      'contentRevision',
      'selectedOptionId',
      'expectedOptionIdSnapshot',
      'playback',
    ]);
    final playback = Map<String, dynamic>.of(
      action['playback'] as Map<String, dynamic>,
    );
    expect(playback.keys, [
      'profile',
      'authGeneration',
      'activityId',
      'contentRevision',
      'runGeneration',
      'round',
      'itemId',
      'referenceId',
      'promptEpoch',
      'outcome',
      'source',
    ]);
    action['playback'] = {
      for (final key in playback.keys.toList().reversed) key: playback[key],
    };
    answer['action'] = action;
    expect(
      () => commandCodec.decode(jsonEncode(answer)),
      throwsFormatException,
    );
    final encodedAnswer = commandCodec.encode(answerCommand());
    expect(
      commandCodec.encode(commandCodec.decode(encodedAnswer)),
      encodedAnswer,
    );
  });

  test(
    'checkpoint codec pins ordered fields and strict canonical round trip',
    () {
      final checkpoint = startCheckpoint();
      final encoded = checkpointCodec.encode(checkpoint);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      expect(decoded.keys, [
        'version',
        'scope',
        'sessionId',
        'contentRevision',
        'policy',
        'mode',
        'runStartRound',
        'finished',
        'session',
        'firstAttemptAnswers',
        'baseline',
      ]);
      expect((decoded['session'] as Map).keys, [
        'version',
        'sessionId',
        'contentRevision',
        'itemIds',
        'queue',
        'position',
        'round',
        'attemptCount',
        'phase',
        'submittedThisRound',
        'lastCorrect',
        'answered',
        'latestAnswers',
        'policy',
      ]);
      expect(
        checkpointCodec.encode(
          checkpointCodec.decode(
            encoded,
            scope: scope,
            catalogue: catalogue,
            policy: policy,
          ),
        ),
        encoded,
      );
    },
  );

  test('checkpoint decoder rejects wrong mode and answer-map order', () {
    final checkpoint = startCheckpoint();
    final base =
        jsonDecode(checkpointCodec.encode(checkpoint)) as Map<String, dynamic>;
    final wrongMode = Map<String, dynamic>.of(base)..['mode'] = 'reviewOnly';
    expect(
      () => checkpointCodec.decode(
        jsonEncode(wrongMode),
        scope: scope,
        catalogue: catalogue,
        policy: policy,
      ),
      throwsFormatException,
    );

    final wrongKey = <String, dynamic>{
      for (final entry in base.entries)
        if (entry.key == 'runStartRound')
          'runStartRoundX': entry.value
        else
          entry.key: entry.value,
    };
    expect(
      () => checkpointCodec.decode(
        jsonEncode(wrongKey),
        scope: scope,
        catalogue: catalogue,
        policy: policy,
      ),
      throwsFormatException,
    );

    final wrongMapOrder = Map<String, dynamic>.of(base)
      ..['firstAttemptAnswers'] = {
        'uy-demo-spelling-02': true,
        'uy-demo-spelling-01': false,
      };
    expect(
      () => checkpointCodec.decode(
        jsonEncode(wrongMapOrder),
        scope: scope,
        catalogue: catalogue,
        policy: policy,
      ),
      throwsFormatException,
    );
  });

  test('checkpoint byte limit is enforced in UTF-8 bytes', () {
    final id = 'é' * learningMaxCheckpointBytes;
    final overlong = SpellingCheckpoint(
      scope: scope,
      sessionId: id,
      contentRevision: catalogue.contentRevision,
      policy: policy,
      mode: SpellingRunMode.practice,
      runStartRound: 1,
      finished: false,
      sessionJson: <String, Object?>{
        ...LessonSectionSession(
          itemIds: catalogue.rows.map((row) => row.exercise.id).toList(),
          sessionId: id,
          contentRevision: catalogue.contentRevision,
          policy: policy,
        ).toJson(),
      },
      firstAttemptAnswers: const <String, bool>{},
    );
    expect(() => checkpointCodec.encode(overlong), throwsArgumentError);
    final overlongJson = jsonEncode(<String, Object?>{
      'version': 1,
      'scope': {
        'courseId': 'en-fr',
        'owner': {'kind': 'guest', 'id': ''},
      },
      'sessionId': id,
      'contentRevision': 1,
      'policy': policy.toJson(),
      'mode': 'practice',
      'runStartRound': 1,
      'finished': false,
      'session': overlong.sessionJson,
      'firstAttemptAnswers': <String, bool>{},
      'baseline': null,
    });
    expect(
      utf8.encode(overlongJson).length,
      greaterThan(learningMaxCheckpointBytes),
    );
    expect(
      () => checkpointCodec.decode(
        overlongJson,
        scope: scope,
        catalogue: catalogue,
        policy: policy,
      ),
      throwsFormatException,
    );
  });

  test('checkpoint codec keeps the complete first score in authored order', () {
    final checkpoint = completeCheckpoint();
    final ids = catalogue.rows.map((row) => row.exercise.id).toList();
    expect(checkpoint.firstAttemptAnswers.keys, ids);
    expect(checkpoint.firstAttemptAnswers[ids.first], isFalse);
    expect(checkpoint.firstAttemptAnswers.values.skip(1), everyElement(isTrue));
    final encoded = checkpointCodec.encode(checkpoint);
    final root = jsonDecode(encoded) as Map<String, dynamic>;
    expect((root['firstAttemptAnswers'] as Map).keys, ids);
    final decoded = checkpointCodec.decode(
      encoded,
      scope: scope,
      catalogue: catalogue,
      policy: policy,
    );
    expect(decoded.firstAttemptAnswers, checkpoint.firstAttemptAnswers);
  });

  test('whole-state validator accepts empty and real reducer states', () {
    final empty = SpellingLearningState.empty(scope);
    SpellingLearningStateValidator.validate(empty, catalogue);
    final command = startCommand();
    final started = engine.evaluate(
      state: empty,
      command: command,
      committedAt: DateTime.utc(2026, 10, 24),
    );
    SpellingLearningStateValidator.validate(started.nextState, catalogue);
    final oldCheckpoint = started.slot.checkpoint;
    final invalidCheckpoint = SpellingCheckpoint(
      scope: oldCheckpoint.scope,
      sessionId: oldCheckpoint.sessionId,
      contentRevision: oldCheckpoint.contentRevision,
      policy: oldCheckpoint.policy,
      mode: oldCheckpoint.mode,
      runStartRound: oldCheckpoint.runStartRound,
      finished: oldCheckpoint.finished,
      sessionJson: oldCheckpoint.sessionJson,
      firstAttemptAnswers: const {'uy-demo-spelling-01': false},
    );
    final invalidSlot = SpellingSlot(
      scope: started.slot.scope,
      activityId: started.slot.activityId,
      cursor: started.slot.cursor,
      checkpoint: invalidCheckpoint,
      latestReceipt: started.slot.latestReceipt,
    );
    final invalidState = SpellingLearningState(
      scope: started.nextState.scope,
      revision: started.nextState.revision,
      commitOrdinal: started.nextState.commitOrdinal,
      slots: {catalogue.activityId: invalidSlot},
      attempts: started.nextState.attempts,
      receipts: started.nextState.receipts,
      mistakes: started.nextState.mistakes,
      summaries: started.nextState.summaries,
      exposures: started.nextState.exposures,
      completions: started.nextState.completions,
    );
    expect(
      () => SpellingLearningStateValidator.validate(invalidState, catalogue),
      throwsFormatException,
    );
  });
}
