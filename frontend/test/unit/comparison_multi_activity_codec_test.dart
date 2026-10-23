import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/comparison_content.dart';
import 'package:linguist/src/core/course/comparison_learning_command.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/comparison_learning_transition.dart';
import 'package:linguist/src/core/course/course_audio_contract.dart';
import 'package:linguist/src/core/course/french_comparison_content.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/storage/comparison_learning_checkpoint_codec.dart';
import 'package:linguist/src/core/course/storage/comparison_learning_command_codec.dart';
import 'package:linguist/src/core/course/storage/comparison_learning_storage_validator.dart';

void main() {
  test('mixed_legacy_and_sql_command_bytes_and_storage_key_are_frozen', () {
    final catalogue = loadFrenchComparisonCatalogue();
    final scope = ComparisonProfileScope(
      courseId: 'en-fr',
      owner: LearningOwner.guest(),
    );
    final engine = ComparisonLearningTransitionEngine(catalogue: catalogue);
    final mixedStart = engine.prepare(
      state: ComparisonLearningState.empty(scope),
      activityId: comparisonActivityId,
      action: StartComparisonRun(
        sessionId: 'frozen-mixed-start',
        policy: LessonPolicy(),
      ),
      authGeneration: 7,
      token: 'AAAAAAAAAAAAAAAAAAAAAA',
      submittedAt: DateTime.utc(2026, 10, 23),
    );
    const frozenMixedLegacy =
        '{"schemaVersion":1,"family":"comparison","courseId":"en-fr","owner":{"kind":"guest","userId":null},"authGeneration":7,"activityId":"en-fr-phoneme-comparison","generation":0,"sequence":0,"revision":0,"token":"AAAAAAAAAAAAAAAAAAAAAA","submittedAt":"2026-10-23T00:00:00.000Z","action":{"kind":"start","sessionId":"frozen-mixed-start","policy":{"completionThresholdPercent":80}}}';

    expect(comparisonCanonicalCommand(mixedStart), frozenMixedLegacy);
    expect(
      ComparisonLearningCommandCodec.canonicalCommand(mixedStart),
      '${frozenMixedLegacy.substring(0, frozenMixedLegacy.length - 1)},'
      '"expectedScopeRevision":0}',
    );
    expect(scope.storageKey, 'course.learning.comparison.v1.ZW4tZnI.g');
    expect(
      ComparisonLearningCommandCodec.decodeLegacyCanonicalCommand(
        frozenMixedLegacy,
        scope: scope,
        catalogue: catalogue,
      ).activityId,
      comparisonActivityId,
    );
    expect(
      ComparisonLearningCommandCodec.decodeCanonicalCommand(
        ComparisonLearningCommandCodec.canonicalCommand(mixedStart),
        scope: scope,
        catalogue: catalogue,
      ).activityId,
      comparisonActivityId,
    );
  });

  test('registered decoders reject unknown and cross-catalogue content', () {
    final mixed = loadFrenchComparisonCatalogue();
    final dedicated = loadFrenchUyDemoComparisonCatalogue();
    final registry = _registry(mixed, dedicated);
    final scope = ComparisonProfileScope(
      courseId: 'en-fr',
      owner: LearningOwner.guest(),
    );
    final engine = ComparisonLearningTransitionEngine(registry: registry);
    final empty = ComparisonLearningState.empty(scope);
    final start = engine.prepare(
      state: empty,
      activityId: uyDemoComparisonActivityId,
      action: StartComparisonRun(
        sessionId: 'codec-dedicated-start',
        policy: LessonPolicy(),
      ),
      authGeneration: 0,
      token: 'BBBBBBBBBBBBBBBBBBBBBB',
      submittedAt: DateTime.utc(2026, 10, 23),
    );
    final legacyStart = comparisonCanonicalCommand(start);
    final sqlStart = ComparisonLearningCommandCodec.canonicalCommand(start);

    expect(
      ComparisonLearningCommandCodec.decodeRegisteredLegacyCanonicalCommand(
        legacyStart,
        scope: scope,
        registry: registry,
      ).activityId,
      uyDemoComparisonActivityId,
    );
    expect(
      ComparisonLearningCommandCodec.decodeRegisteredCanonicalCommand(
        sqlStart,
        scope: scope,
        registry: registry,
      ).activityId,
      uyDemoComparisonActivityId,
    );

    final unknownLegacy = _withActivity(legacyStart, 'en-fr-unknown');
    final unknownSql = _withActivity(sqlStart, 'en-fr-unknown');
    expect(
      () =>
          ComparisonLearningCommandCodec.decodeRegisteredLegacyCanonicalCommand(
            unknownLegacy,
            scope: scope,
            registry: registry,
          ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ComparisonLearningCommandCodec.decodeRegisteredCanonicalCommand(
        unknownSql,
        scope: scope,
        registry: registry,
      ),
      throwsA(isA<FormatException>()),
    );

    final started = engine
        .evaluate(
          state: empty,
          command: start,
          committedAt: DateTime.utc(2026, 10, 23),
        )
        .nextState;
    final slot = started.slots[uyDemoComparisonActivityId]!;
    final exercise = dedicated.exercises.first;
    final observations = [
      for (final sample in [exercise.sampleA, exercise.sampleB])
        ComparisonPlaybackObservation(
          slot: sample.slot,
          referenceId: sample.referenceId,
          outcome: CourseAudioOutcome.completed,
          source: CourseAudioSource.unverifiedRecording,
          activityId: uyDemoComparisonActivityId,
          runGeneration: slot.cursor.generation,
          round: 1,
          pairId: exercise.id,
          profile: scope,
          uiGeneration: 1,
        ),
    ];
    final answer = engine.prepare(
      state: started,
      activityId: uyDemoComparisonActivityId,
      action: AnswerComparisonPair(
        ComparePhonemesAnswer(
          selectedRelation: exercise.expectedRelation,
          expectedRelationSnapshot: exercise.expectedRelation,
          observations: observations,
        ),
      ),
      authGeneration: 0,
      token: 'CCCCCCCCCCCCCCCCCCCCCC',
      submittedAt: DateTime.utc(2026, 10, 23, 0, 0, 1),
    );
    final sqlAnswer = ComparisonLearningCommandCodec.canonicalCommand(answer);
    expect(
      ComparisonLearningCommandCodec.decodeRegisteredCanonicalCommand(
        sqlAnswer,
        scope: scope,
        registry: registry,
      ).activityId,
      uyDemoComparisonActivityId,
    );
    final wrongReference = _withObservationField(
      sqlAnswer,
      0,
      'referenceId',
      'fr-word-rouge',
    );
    final wrongPair = _withObservationField(
      sqlAnswer,
      0,
      'pairId',
      'fr07b-pair-01',
    );
    final wrongPairBoth = _withObservationField(
      wrongPair,
      1,
      'pairId',
      'fr07b-pair-01',
    );

    expect(
      () => ComparisonLearningCommandCodec.decodeRegisteredCanonicalCommand(
        wrongReference,
        scope: scope,
        registry: registry,
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ComparisonLearningCommandCodec.decodeRegisteredCanonicalCommand(
        wrongPairBoth,
        scope: scope,
        registry: registry,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'registered checkpoint codec accepts only its exact activity binding',
    () {
      final mixed = loadFrenchComparisonCatalogue();
      final dedicated = loadFrenchUyDemoComparisonCatalogue();
      final registry = _registry(mixed, dedicated);
      final scope = ComparisonProfileScope(
        courseId: 'en-fr',
        owner: LearningOwner.guest(),
      );
      final engine = ComparisonLearningTransitionEngine(registry: registry);
      final state = ComparisonLearningState.empty(scope);
      final command = engine.prepare(
        state: state,
        activityId: uyDemoComparisonActivityId,
        action: StartComparisonRun(
          sessionId: 'checkpoint-dedicated-start',
          policy: LessonPolicy(),
        ),
        authGeneration: 0,
        token: 'DDDDDDDDDDDDDDDDDDDDDD',
        submittedAt: DateTime.utc(2026, 10, 23),
      );
      final started = engine
          .evaluate(
            state: state,
            command: command,
            committedAt: DateTime.utc(2026, 10, 23),
          )
          .nextState;
      final checkpoint = started.slots[uyDemoComparisonActivityId]!.checkpoint;
      const codec = ComparisonLearningCheckpointCodec();
      final encoded = codec.encode(checkpoint);

      final decoded = codec.decodeRegistered(
        encoded,
        scope: scope,
        activityId: uyDemoComparisonActivityId,
        registry: registry,
        policy: LessonPolicy(),
      );
      expect(decoded.sessionId, checkpoint.sessionId);
      expect(decoded.contentRevision, dedicated.contentRevision);
      expect(decoded.sessionJson, checkpoint.sessionJson);
      expect(
        () => codec.decodeRegistered(
          encoded,
          scope: scope,
          activityId: comparisonActivityId,
          registry: registry,
          policy: LessonPolicy(),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => codec.decodeRegistered(
          encoded,
          scope: scope,
          activityId: 'en-fr-unknown',
          registry: registry,
          policy: LessonPolicy(),
        ),
        throwsA(isA<FormatException>()),
      );
      ComparisonLearningStateValidator.validateRegistered(started, registry);
    },
  );
}

ComparisonCatalogueRegistry _registry(
  ComparisonCatalogue mixed,
  ComparisonCatalogue dedicated,
) => ComparisonCatalogueRegistry([
  ComparisonCatalogueRegistration.available(mixed),
  ComparisonCatalogueRegistration.available(dedicated),
]);

String _withActivity(String raw, String activityId) {
  final command = jsonDecode(raw) as Map<String, dynamic>;
  command['activityId'] = activityId;
  return jsonEncode(command);
}

String _withObservationField(
  String raw,
  int index,
  String field,
  String value,
) {
  final command = jsonDecode(raw) as Map<String, dynamic>;
  final action = command['action'] as Map<String, dynamic>;
  final observations = action['observations'] as List<dynamic>;
  final observation = observations[index] as Map<String, dynamic>;
  observation[field] = value;
  return jsonEncode(command);
}
