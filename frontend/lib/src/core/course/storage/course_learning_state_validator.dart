import 'dart:convert';

import '../../../features/arcade/word_match_engine.dart';
import '../course_attempt.dart';
import 'course_learning_checkpoint_codec.dart';
import '../course_learning_registry.dart';
import '../course_learning_state.dart';
import '../course_skill_summary.dart';

/// Validates the typed course state assembled from normalized SQL rows.
///
/// This deliberately checks one checkpoint at a time; it never serializes the
/// entire state or derives durable aggregates from retained attempt detail.
final class CourseLearningStateValidator {
  const CourseLearningStateValidator._();

  static const int _maxAggregateIdentities = 4096;
  static const int _maxRetainedAttempts = 2000;

  static void validate(CourseLearningState state, LearningRegistry registry) {
    try {
      _validate(state, registry);
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Invalid course learning state: $error');
    }
  }

  static void _validate(CourseLearningState state, LearningRegistry registry) {
    if (state.schemaVersion != 2 ||
        state.revision < 0 ||
        state.commitOrdinal < 0 ||
        state.commitOrdinal > state.revision ||
        state.history.fold<int>(
              0,
              (total, batch) => total + batch.attempts.length,
            ) >
            _maxRetainedAttempts ||
        state.activities.length > _maxAggregateIdentities ||
        state.mistakes.length > _maxAggregateIdentities ||
        state.summaries.length > _maxAggregateIdentities ||
        state.completions.length > _maxAggregateIdentities ||
        state.bestScores.length > _maxAggregateIdentities) {
      throw const FormatException('Course state exceeds its supported bounds.');
    }

    final definitions = <String, LearningActivityDefinition>{};
    for (final activityId in <String>{
      ...state.activities.keys,
      for (final batch in state.history) batch.activityId,
      for (final key in state.mistakes.keys) key.activityId,
      for (final completion in state.completions)
        'lesson:${completion.lessonId}',
      ...state.bestScores.keys,
      for (final attempt in state.history.expand((batch) => batch.attempts))
        attempt.activityId,
    }) {
      definitions[activityId] = _definition(registry, activityId);
    }

    const snapshotCodec = CourseLearningCheckpointCodec();
    for (final entry in state.activities.entries) {
      final ActivitySlot slot = entry.value;
      final definition =
          definitions[slot.activityId] ??
          _definition(registry, slot.activityId);
      if (entry.key != slot.activityId ||
          slot.kind != definition.kind ||
          slot.contentRevision != definition.contentRevision) {
        throw const FormatException('Activity slot content identity mismatch.');
      }
      // Encode only this typed checkpoint to validate the storage-size bound,
      // then decode it against current registered content and saved options.
      snapshotCodec.decode(
        snapshotCodec.encode(slot.snapshot),
        kind: slot.kind,
        definition: definition,
        options: slot.options,
      );
      for (final exposure in slot.exposures.entries) {
        final items = definition.items
            .where((item) => item.id == exposure.key.itemId)
            .toList(growable: false);
        if (items.length != 1 ||
            !_validTarget(definition, items.single, exposure.key.targetSound) ||
            exposure.value.presentations < 0 ||
            exposure.value.presentations > 9007199254740991 ||
            exposure.value.assistance.any(
              (flag) => !AssistanceFlag.values.contains(flag),
            )) {
          throw const FormatException('Invalid activity exposure identity.');
        }
      }
    }

    final attemptById = <String, CourseAttempt>{};
    final batchIdentities = <String>{};
    var retainedAttempts = 0;
    for (final batch in state.history) {
      final identity = jsonEncode([
        batch.activityId,
        batch.generation,
        batch.sequence,
        batch.token,
      ]);
      if (!batchIdentities.add(identity) ||
          batch.activityId.trim().isEmpty ||
          batch.generation < 1 ||
          batch.sequence < 1 ||
          batch.attempts.isEmpty) {
        throw const FormatException('Duplicate or invalid attempt batch.');
      }
      final definition =
          definitions[batch.activityId] ??
          _definition(registry, batch.activityId);
      for (var index = 0; index < batch.attempts.length; index++) {
        final attempt = batch.attempts[index];
        if (attempt.scope != state.scope ||
            attempt.activityId != batch.activityId ||
            attempt.runGeneration != batch.generation ||
            attempt.commandSequence != batch.sequence ||
            attempt.batchIndex != index ||
            attempt.commitOrdinal > state.commitOrdinal ||
            attemptById.containsKey(attempt.submissionId)) {
          throw const FormatException('Attempt batch identity mismatch.');
        }
        _validateAttempt(attempt, definition);
        attemptById[attempt.submissionId] = attempt;
        retainedAttempts++;
      }
    }
    if (retainedAttempts > _maxRetainedAttempts) {
      throw const FormatException('Retained attempts exceed the SQL limit.');
    }

    for (final entry in state.mistakes.entries) {
      final LearningMistake mistake = entry.value;
      final key = mistake.key;
      final definition =
          definitions[key.activityId] ?? _definition(registry, key.activityId);
      final items = definition.items
          .where((item) => item.id == key.itemId)
          .toList(growable: false);
      final currentSlot = state.activities[key.activityId];
      if (entry.key != key ||
          items.length != 1 ||
          key.contentRevision != definition.contentRevision ||
          !_validTarget(definition, items.single, key.targetSound) ||
          mistake.failureCount < 1 ||
          mistake.firstWrongAt.isAfter(mistake.latestWrongAt) ||
          (currentSlot != null &&
              mistake.lastRunGeneration > currentSlot.cursor.generation)) {
        throw const FormatException('Invalid unresolved mistake identity.');
      }
      _validateReferencedWrongAttempt(mistake.firstWrongId, key, attemptById);
      _validateReferencedWrongAttempt(mistake.latestWrongId, key, attemptById);
    }

    final knownCounts = addAttemptCounts(
      const <SummaryKey, SkillCount>{},
      state.history.expand((batch) => batch.attempts),
    );
    for (final entry in state.summaries.entries) {
      if (entry.key.sound.trim().isEmpty ||
          !_knownSound(registry, entry.key.sound) ||
          entry.value.total < 0 ||
          entry.value.correct < 0 ||
          entry.value.correct > entry.value.total) {
        throw const FormatException('Invalid course summary aggregate.');
      }
      final retained = knownCounts[entry.key];
      if (retained != null &&
          (entry.value.total < retained.total ||
              entry.value.correct < retained.correct)) {
        throw const FormatException(
          'Course summary aggregate is inconsistent with retained attempts.',
        );
      }
    }
    for (final entry in knownCounts.entries) {
      final aggregate = state.summaries[entry.key];
      if (aggregate == null ||
          aggregate.total < entry.value.total ||
          aggregate.correct < entry.value.correct) {
        throw const FormatException(
          'Retained attempts are missing from course summaries.',
        );
      }
    }

    final completionIdentities = <String>{};
    for (final completion in state.completions) {
      final activityId = 'lesson:${completion.lessonId}';
      final definition =
          definitions[activityId] ?? _definition(registry, activityId);
      final validKind = switch (definition.kind) {
        LearningActivityKind.discovery =>
          completion.policyKind == CompletionPolicyKind.discoveryThreshold &&
              completion.thresholdPercent != null,
        LearningActivityKind.legacyLesson =>
          completion.policyKind == CompletionPolicyKind.legacyOnePass &&
              completion.thresholdPercent == null,
        _ => false,
      };
      final identity = jsonEncode([
        completion.lessonId,
        completion.contentRevision,
        completion.policyKind.name,
        completion.policyRevision,
        completion.thresholdPercent,
      ]);
      if (!validKind ||
          completion.contentRevision != definition.contentRevision ||
          completion.policyRevision != 1 ||
          (completion.thresholdPercent != null &&
              (completion.thresholdPercent! < 1 ||
                  completion.thresholdPercent! > 100)) ||
          !completionIdentities.add(identity)) {
        throw const FormatException('Invalid course completion identity.');
      }
    }

    for (final entry in state.bestScores.entries) {
      final definition =
          definitions[entry.key] ?? _definition(registry, entry.key);
      if ((definition.kind != LearningActivityKind.soundGame &&
              definition.kind != LearningActivityKind.wordGame) ||
          entry.value < 0 ||
          entry.value > 9007199254740991) {
        throw const FormatException('Invalid game best-score identity.');
      }
    }

    if (state.pending.map((event) => event.id).toSet().length !=
        state.pending.length) {
      throw const FormatException('Duplicate supported outbox event id.');
    }
    for (final event in state.pending) {
      if (state.scope.owner.isGuest ||
          event.userId != state.scope.owner.userId ||
          event.courseId != state.scope.courseId ||
          event.id.trim().isEmpty) {
        throw const FormatException('Invalid supported outbox identity.');
      }
    }

    final exposureCount = state.activities.values.fold<int>(
      0,
      (total, slot) => total + slot.exposures.length,
    );
    if (exposureCount > _maxAggregateIdentities) {
      throw const FormatException('Course exposure aggregate exceeds its cap.');
    }
  }

  static LearningActivityDefinition _definition(
    LearningRegistry registry,
    String activityId,
  ) {
    try {
      return registry.require(activityId);
    } on Object catch (error) {
      throw FormatException('Unknown registered activity $activityId: $error');
    }
  }

  static void _validateAttempt(
    CourseAttempt attempt,
    LearningActivityDefinition definition,
  ) {
    final items = definition.items
        .where((item) => item.id == attempt.itemId)
        .toList(growable: false);
    if (items.length != 1 ||
        attempt.contentRevision != definition.contentRevision ||
        attempt.targetSounds.isEmpty ||
        attempt.targetSounds.any(
          (sound) => !_validTarget(definition, items.single, sound),
        ) ||
        attempt.contentState != items.single.contentState) {
      throw const FormatException('Attempt does not match registered content.');
    }

    final item = items.single;
    final bool answerCorrect;
    switch (attempt.answer) {
      case final SoundChoiceAnswer answer:
        if (definition.kind != LearningActivityKind.discovery &&
            definition.kind != LearningActivityKind.legacyLesson) {
          throw const FormatException(
            'Sound choice belongs to another activity.',
          );
        }
        if (attempt.skill != LearningSkill.listening ||
            attempt.origin != AttemptOrigin.practice ||
            !_sameOrder(answer.choices, item.choices) ||
            answer.expectedSound != item.expectedChoice ||
            !item.choices.contains(answer.selectedSound) ||
            attempt.audioSource != authoredAudioSource(item) ||
            !_sameOrder(attempt.targetSounds, item.targetSounds)) {
          throw const FormatException('Invalid sound-choice attempt.');
        }
        answerCorrect = answer.selectedSound == answer.expectedSound;
      case final DrillChoiceAnswer answer:
        if (definition.kind != LearningActivityKind.drill ||
            attempt.skill != LearningSkill.listening ||
            attempt.origin != AttemptOrigin.practice ||
            answer.pairId != item.id ||
            !_sameOrder(answer.choices, item.choices) ||
            answer.expectedWord != item.expectedChoice ||
            !item.choices.contains(answer.selectedWord) ||
            attempt.audioSource != authoredAudioSource(item) ||
            !_sameOrder(attempt.targetSounds, item.targetSounds)) {
          throw const FormatException('Invalid drill-choice attempt.');
        }
        answerCorrect = answer.selectedWord == answer.expectedWord;
      case final SoundCueAnswer answer:
        if (definition.kind != LearningActivityKind.soundGame ||
            attempt.skill != LearningSkill.listening ||
            attempt.origin != AttemptOrigin.game ||
            answer.wordId != item.id ||
            !_sameOrder(attempt.targetSounds, [answer.expectedFamily]) ||
            !_validTarget(definition, item, answer.expectedFamily)) {
          throw const FormatException('Invalid sound-cue attempt.');
        }
        answerCorrect = answer.selectedFamily == answer.expectedFamily;
      case final WordTileAnswer answer:
        if (definition.kind != LearningActivityKind.wordGame ||
            attempt.skill != LearningSkill.spelling ||
            attempt.origin != AttemptOrigin.game ||
            answer.wordId != item.id ||
            !_sameOrder(attempt.targetSounds, [answer.targetSound]) ||
            !WordMatchEngine.targets.contains(answer.targetSound) ||
            answer.expectedMembership !=
                item.targetSounds.contains(answer.targetSound)) {
          throw const FormatException('Invalid word-tile attempt.');
        }
        answerCorrect = answer.expectedMembership;
    }
    if (attempt.correct != answerCorrect) {
      throw const FormatException(
        'Attempt correctness disagrees with its answer.',
      );
    }
  }

  static void _validateReferencedWrongAttempt(
    String id,
    MistakeKey key,
    Map<String, CourseAttempt> attempts,
  ) {
    final attempt = attempts[id];
    if (attempt == null) return; // The attempt may have aged out of detail.
    if (attempt.correct ||
        attempt.activityId != key.activityId ||
        attempt.itemId != key.itemId ||
        attempt.contentRevision != key.contentRevision ||
        attempt.skill != key.skill ||
        !attempt.targetSounds.contains(key.targetSound)) {
      throw const FormatException('Mistake points at a nonmatching attempt.');
    }
  }

  static bool _validTarget(
    LearningActivityDefinition definition,
    LearningSourceItem item,
    String target,
  ) => definition.kind == LearningActivityKind.wordGame
      ? WordMatchEngine.targets.contains(target)
      : item.targetSounds.contains(target);

  static bool _knownSound(LearningRegistry registry, String sound) =>
      registry.activities.any(
        (activity) =>
            activity.items.any((item) => item.targetSounds.contains(sound)),
      );

  static bool _sameOrder(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
