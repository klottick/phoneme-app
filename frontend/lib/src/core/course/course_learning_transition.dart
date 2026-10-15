import 'dart:math';

import 'course_attempt.dart';
import 'course_learning_checkpoint.dart';
import 'course_learning_command.dart';
import 'course_learning_codec.dart';
import 'course_learning_error.dart';
import 'course_learning_lesson_transition.dart';
import 'course_learning_registry.dart';
import 'course_learning_state.dart';
import 'course_skill_summary.dart';
import 'lesson_section_session.dart';

class LearningTransition {
  LearningTransition({
    required this.slot,
    required List<CourseAttempt> attempts,
    required Map<MistakeKey, LearningMistake> mistakes,
    required Map<SummaryKey, SkillCount> summaries,
    required List<LearningCompletion> completions,
    required Map<String, int> bestScores,
  })  : attempts = List.unmodifiable(attempts),
        mistakes = Map.unmodifiable(mistakes),
        summaries = Map.unmodifiable(summaries),
        completions = List.unmodifiable(completions),
        bestScores = Map.unmodifiable(bestScores);

  final ActivitySlot slot;
  final List<CourseAttempt> attempts;
  final Map<MistakeKey, LearningMistake> mistakes;
  final Map<SummaryKey, SkillCount> summaries;
  final List<LearningCompletion> completions;
  final Map<String, int> bestScores;
}

class LearningTransitionEngine {
  LearningTransitionEngine(this.registry);

  final LearningRegistry registry;

  LearningCommand prepare({
    required CourseLearningState state,
    required int authGeneration,
    required String activityId,
    required LearningAction action,
    required String token,
    required DateTime submittedAt,
    required Random random,
  }) {
    final definition = registry.require(activityId);
    _requireLessonOrDrill(definition);
    final slot = state.activities[activityId];
    final expected =
        slot?.cursor ?? SlotCursor(generation: 0, sequence: 0, revision: 0);
    if (slot != null && action is! StartLearningRun) {
      if (slot.contentRevision != definition.contentRevision ||
          slot.kind != definition.kind) {
        throw const LearningContentChangedException();
      }
      _validateActiveSlot(definition, slot);
    }
    final mutation = _applyAction(
      definition: definition,
      slot: slot,
      action: action,
      token: token,
    );
    return LearningCommand(
      scope: state.scope,
      authGeneration: authGeneration,
      activityId: activityId,
      expected: expected,
      token: token,
      submittedAt: submittedAt,
      action: action,
      draws: const [],
      candidate: mutation.snapshot,
      feedback: mutation.feedback,
    );
  }

  LearningTransition evaluate({
    required CourseLearningState state,
    required LearningCommand command,
    required DateTime committedAt,
  }) {
    try {
      if (command.scope != state.scope || command.draws.isNotEmpty) {
        throw const LearningInvalidCommandException();
      }
      final replay = prepare(
        state: state,
        authGeneration: command.authGeneration,
        activityId: command.activityId,
        action: command.action,
        token: command.token,
        submittedAt: command.submittedAt,
        random: _NoRandom(),
      );
      const codec = LearningDocumentCodec();
      if (codec.canonicalCommand(replay) != codec.canonicalCommand(command)) {
        throw const LearningInvalidCommandException();
      }
      final definition = registry.require(command.activityId);
      final beforeSlot = state.activities[command.activityId];
      final predecessor = beforeSlot?.cursor ??
          SlotCursor(generation: 0, sequence: 0, revision: 0);
      final start = command.action is StartLearningRun;
      final cursor = start
          ? SlotCursor(
              generation: predecessor.generation + 1,
              sequence: predecessor.sequence + 1,
              revision: 0,
            )
          : SlotCursor(
              generation: predecessor.generation,
              sequence: predecessor.sequence + 1,
              revision: predecessor.revision + 1,
            );
      final commitOrdinal = state.commitOrdinal + 1;
      final mutation = _applyAction(
        definition: definition,
        slot: beforeSlot,
        action: command.action,
        token: command.token,
      );
      final exposures = _exposuresFor(
        slot: beforeSlot,
        definition: definition,
        action: command.action,
        item: mutation.answerItem,
      );
      final slot = ActivitySlot(
        activityId: definition.id,
        kind: definition.kind,
        contentRevision: definition.contentRevision,
        cursor: cursor,
        options: start
            ? (command.action as StartLearningRun).options
            : beforeSlot!.options,
        snapshot: mutation.snapshot,
        exposures: exposures,
        latestReceipt: CommandReceipt(
          token: command.token,
          canonicalCommand: codec.canonicalCommand(command),
          before: predecessor,
          after: cursor,
          commitOrdinal: commitOrdinal,
        ),
      );

      final mistakes = Map<MistakeKey, LearningMistake>.of(state.mistakes);
      final attempts = <CourseAttempt>[];
      if (mutation.answerItem != null && mutation.selectedChoice != null) {
        final attempt = _attempt(
          state: state,
          definition: definition,
          slot: slot,
          item: mutation.answerItem!,
          selected: mutation.selectedChoice!,
          action: command.action,
          submittedAt: command.submittedAt,
          committedAt: committedAt,
          commitOrdinal: commitOrdinal,
          index: 0,
        );
        attempts.add(attempt);
        _updateMistakes(mistakes, attempt);
      }
      final summaries = addAttemptCounts(state.summaries, attempts);
      final completions = _nextCompletions(
        state: state,
        definition: definition,
        slot: slot,
        action: command.action,
        committedAt: committedAt,
      );
      return LearningTransition(
        slot: slot,
        attempts: attempts,
        mistakes: mistakes,
        summaries: summaries,
        completions: completions,
        bestScores: state.bestScores,
      );
    } on LearningContentChangedException {
      rethrow;
    } on LearningInvalidCommandException {
      rethrow;
    } catch (error) {
      throw LearningInvalidCommandException(error);
    }
  }

  _Mutation _applyAction({
    required LearningActivityDefinition definition,
    required ActivitySlot? slot,
    required LearningAction action,
    required String token,
  }) {
    if (action case StartLearningRun(:final options)) {
      final sessionId = token;
      final ActivitySnapshot snapshot = switch (definition.kind) {
        LearningActivityKind.discovery => DiscoveryCheckpoint(
            session: LessonSectionSession(
              itemIds:
                  definition.items.map((item) => item.sessionAlias!).toList(),
              sessionId: sessionId,
              contentRevision: definition.contentRevision,
              policy: options.policy,
            ),
          ),
        LearningActivityKind.legacyLesson => const LegacyLessonCheckpoint(
            wordIndex: 0, selectedSound: null, finished: false),
        LearningActivityKind.drill => DrillCheckpoint(
            pairIds: definition.items.map((item) => item.id).toList(),
            index: 0,
            correct: 0,
            ended: false,
          ),
        _ => throw const LearningInvalidCommandException(),
      };
      return _Mutation(snapshot: snapshot);
    }
    if (slot == null) throw const LearningInvalidCommandException();
    if (slot.contentRevision != definition.contentRevision ||
        slot.kind != definition.kind) {
      throw const LearningContentChangedException();
    }

    if (definition.kind == LearningActivityKind.discovery ||
        definition.kind == LearningActivityKind.legacyLesson) {
      if (action is FinishLearningActivity &&
          definition.kind == LearningActivityKind.discovery) {
        final session = (slot.snapshot as DiscoveryCheckpoint).session;
        if (!session.canComplete) throw const LearningInvalidCommandException();
        return _Mutation(snapshot: slot.snapshot);
      }
      if (action is FinishLearningActivity &&
          definition.kind == LearningActivityKind.legacyLesson) {
        final changed = transitionLesson(
          definition: definition,
          snapshot: slot.snapshot,
          action: action,
        );
        return _Mutation(
            snapshot: changed.snapshot, feedback: changed.feedback);
      }
      if (action is ObserveAssistance) {
        _validateAssistance(definition, action);
        return _Mutation(snapshot: slot.snapshot);
      }
      if (action case ChooseSound(:final audioSource)) {
        _requirePracticeSpeech(audioSource);
      }
      final changed = transitionLesson(
        definition: definition,
        snapshot: slot.snapshot,
        action: action,
      );
      return _Mutation(
        snapshot: changed.snapshot,
        answerItem: changed.answerItem,
        selectedChoice: changed.selectedChoice,
        feedback: changed.feedback,
      );
    }

    if (definition.kind == LearningActivityKind.drill) {
      final drill = slot.snapshot as DrillCheckpoint;
      switch (action) {
        case ChooseDrillWord(:final selectedWord, :final audioSource):
          if (drill.ended ||
              drill.index < 0 ||
              drill.index >= definition.items.length) {
            throw const LearningInvalidCommandException();
          }
          final item = definition.items[drill.index];
          if (!item.choices.contains(selectedWord)) {
            throw const LearningInvalidCommandException();
          }
          _requirePracticeSpeech(audioSource);
          final correct = selectedWord == item.expectedChoice;
          return _Mutation(
            snapshot: DrillCheckpoint(
              pairIds: drill.pairIds,
              index: drill.index + 1,
              correct: drill.correct + (correct ? 1 : 0),
              ended: false,
            ),
            answerItem: item,
            selectedChoice: selectedWord,
            feedback: LearningFeedback(
              message: correct ? 'Correct' : 'Try again',
              points: 0,
              cascades: 0,
              bonus: 0,
              correct: correct,
            ),
          );
        case EndDrill():
          if (drill.ended) throw const LearningInvalidCommandException();
          return _Mutation(
            snapshot: DrillCheckpoint(
              pairIds: drill.pairIds,
              index: drill.index,
              correct: drill.correct,
              ended: true,
            ),
          );
        case ObserveAssistance():
          _validateAssistance(definition, action);
          return _Mutation(snapshot: slot.snapshot);
        default:
          throw const LearningInvalidCommandException();
      }
    }
    throw const LearningInvalidCommandException();
  }

  Map<ItemContextKey, ItemExposure> _exposuresFor({
    required ActivitySlot? slot,
    required LearningActivityDefinition definition,
    required LearningAction action,
    required LearningSourceItem? item,
  }) {
    final out =
        Map<ItemContextKey, ItemExposure>.of(slot?.exposures ?? const {});
    if (action is StartLearningRun) {
      out.clear();
      if (definition.kind == LearningActivityKind.legacyLesson) {
        for (final item in definition.items) {
          for (final target in item.targetSounds) {
            out[ItemContextKey(itemId: item.id, targetSound: target)] =
                ItemExposure(
              presentations: 0,
              assistance: const {AssistanceFlag.explanationVisible},
            );
          }
        }
      }
      return out;
    }
    if (action is ObserveAssistance) {
      for (final context in action.items) {
        final old = out[context] ??
            ItemExposure(presentations: 0, assistance: const {});
        out[context] = ItemExposure(
          presentations: old.presentations,
          assistance: {...old.assistance, ...action.flags},
        );
      }
    }
    final aliases = action is ReviewDiscoveryMistakes
        ? (slot!.snapshot as DiscoveryCheckpoint).session.unresolvedItemIds
        : const <String>[];
    for (final alias in aliases) {
      final source =
          definition.items.firstWhere((item) => item.sessionAlias == alias);
      final context = ItemContextKey(
          itemId: source.id, targetSound: source.targetSounds.single);
      final old =
          out[context] ?? ItemExposure(presentations: 0, assistance: const {});
      out[context] = ItemExposure(
        presentations: old.presentations,
        assistance: {...old.assistance, AssistanceFlag.afterDebrief},
      );
    }
    if (item != null) {
      final actionAudio = switch (action) {
        ChooseSound(:final audioSource) => audioSource,
        ChooseDrillWord(:final audioSource) => audioSource,
        _ => AttemptAudioSource.notApplicable,
      };
      if (actionAudio == AttemptAudioSource.notApplicable) {
        throw const LearningInvalidCommandException();
      }
      for (final target in item.targetSounds) {
        final context = ItemContextKey(itemId: item.id, targetSound: target);
        final old = out[context] ??
            ItemExposure(presentations: 0, assistance: const {});
        out[context] = ItemExposure(
          presentations: old.presentations + 1,
          assistance: old.assistance,
        );
      }
    }
    return out;
  }

  CourseAttempt _attempt({
    required CourseLearningState state,
    required LearningActivityDefinition definition,
    required ActivitySlot slot,
    required LearningSourceItem item,
    required String selected,
    required LearningAction action,
    required DateTime submittedAt,
    required DateTime committedAt,
    required int commitOrdinal,
    required int index,
  }) {
    final contexts = item.targetSounds
        .map((sound) => ItemContextKey(itemId: item.id, targetSound: sound))
        .toList();
    final exposures = slot.exposures;
    final priorCount = contexts
            .map((key) => exposures[key]?.presentations ?? 0)
            .reduce((a, b) => a < b ? a : b) -
        1;
    final assistance = <AssistanceFlag>{
      for (final key in contexts) ...?exposures[key]?.assistance,
    };
    final source = switch (action) {
      ChooseSound(:final audioSource) => audioSource,
      ChooseDrillWord(:final audioSource) => audioSource,
      _ => throw const LearningInvalidCommandException(),
    };
    final expected = item.expectedChoice!;
    final answer = definition.kind == LearningActivityKind.drill
        ? DrillChoiceAnswer(
            selectedWord: selected,
            pairId: item.id,
            choices: item.choices,
            expectedWord: expected,
          )
        : SoundChoiceAnswer(
            selectedSound: selected,
            choices: item.choices,
            expectedSound: expected,
          );
    final correct = selected == expected;
    final submissionId =
        '${state.scope.storageKey}.${definition.id}.${slot.cursor.generation}.${slot.cursor.sequence}.${slot.latestReceipt.token}.a$index';
    return CourseAttempt(
      scope: state.scope,
      submissionId: submissionId,
      activityId: definition.id,
      runGeneration: slot.cursor.generation,
      commandSequence: slot.cursor.sequence,
      batchIndex: index,
      itemId: item.id,
      itemOccurrence: priorCount + 1,
      contentRevision: definition.contentRevision,
      commitOrdinal: commitOrdinal,
      answeredAt: submittedAt,
      committedAt: committedAt,
      skill: LearningSkill.listening,
      targetSounds: item.targetSounds,
      answer: answer,
      origin: AttemptOrigin.practice,
      presentation: priorCount == 0
          ? AttemptPresentation.firstInRun
          : AttemptPresentation.repeatInRun,
      assistance: assistance,
      contentState: item.contentState,
      audioSource: source,
      correct: correct,
    );
  }

  void _updateMistakes(
      Map<MistakeKey, LearningMistake> mistakes, CourseAttempt attempt) {
    for (final sound in attempt.targetSounds) {
      final key = MistakeKey(
        activityId: attempt.activityId,
        itemId: attempt.itemId,
        contentRevision: attempt.contentRevision,
        skill: attempt.skill,
        targetSound: sound,
      );
      final previous = mistakes[key];
      if (attempt.correct) {
        mistakes.remove(key);
      } else {
        mistakes[key] = LearningMistake(
          key: key,
          firstWrongId: previous?.firstWrongId ?? attempt.submissionId,
          firstWrongAt: previous?.firstWrongAt ?? attempt.answeredAt,
          latestWrongId: attempt.submissionId,
          latestWrongAt: attempt.answeredAt,
          failureCount: (previous?.failureCount ?? 0) + 1,
          lastRunGeneration: attempt.runGeneration,
        );
      }
    }
  }

  List<LearningCompletion> _nextCompletions({
    required CourseLearningState state,
    required LearningActivityDefinition definition,
    required ActivitySlot slot,
    required LearningAction action,
    required DateTime committedAt,
  }) {
    if (action is! FinishLearningActivity ||
        !action.recordCompletion ||
        definition.kind == LearningActivityKind.drill) {
      return state.completions;
    }
    final policyKind = definition.kind == LearningActivityKind.discovery
        ? CompletionPolicyKind.discoveryThreshold
        : CompletionPolicyKind.legacyOnePass;
    final lessonId = definition.id.substring('lesson:'.length);
    final thresholdPercent =
        policyKind == CompletionPolicyKind.discoveryThreshold
            ? slot.options.policy.completionThresholdPercent
            : null;
    final duplicate = state.completions.any((completion) =>
        completion.lessonId == lessonId &&
        completion.contentRevision == definition.contentRevision &&
        completion.policyKind == policyKind &&
        completion.policyRevision == 1 &&
        completion.thresholdPercent == thresholdPercent);
    if (duplicate) return state.completions;
    return [
      ...state.completions,
      LearningCompletion(
        lessonId: lessonId,
        contentRevision: definition.contentRevision,
        policyKind: policyKind,
        policyRevision: 1,
        thresholdPercent: thresholdPercent,
        committedAt: committedAt,
      ),
    ];
  }

  void _validateAssistance(
      LearningActivityDefinition definition, ObserveAssistance action) {
    final permitted = switch (definition.kind) {
      LearningActivityKind.discovery => const {
          AssistanceFlag.explanationVisible,
          AssistanceFlag.graphemeHint,
        },
      LearningActivityKind.legacyLesson => const {
          AssistanceFlag.explanationVisible,
          AssistanceFlag.graphemeHint,
          AssistanceFlag.answerRevealed,
        },
      _ => const <AssistanceFlag>{},
    };
    if (action.items.isEmpty ||
        action.flags.isEmpty ||
        !permitted.containsAll(action.flags)) {
      throw const LearningInvalidCommandException();
    }
    for (final context in action.items) {
      final item = definition.items.where((item) => item.id == context.itemId);
      if (item.length != 1 ||
          !item.single.targetSounds.contains(context.targetSound)) {
        throw const LearningInvalidCommandException();
      }
    }
  }

  void _validateActiveSlot(
      LearningActivityDefinition definition, ActivitySlot slot) {
    for (final context in slot.exposures.keys) {
      final sources =
          definition.items.where((item) => item.id == context.itemId);
      if (sources.length != 1 ||
          !sources.single.targetSounds.contains(context.targetSound)) {
        throw const LearningInvalidCommandException();
      }
    }
    switch (slot.snapshot) {
      case DiscoveryCheckpoint(:final session):
        final aliases =
            definition.items.map((item) => item.sessionAlias!).toList();
        try {
          final validated = LessonSectionSession.fromJson(
            session.toJson(),
            itemIds: aliases,
            contentRevision: definition.contentRevision,
          );
          if (validated.policy.completionThresholdPercent !=
              slot.options.policy.completionThresholdPercent) {
            throw const LearningInvalidCommandException();
          }
        } on LearningInvalidCommandException {
          rethrow;
        } catch (error) {
          throw LearningInvalidCommandException(error);
        }
      case LegacyLessonCheckpoint(
          :final wordIndex,
          :final selectedSound,
          :final finished
        ):
        if (wordIndex < 0 ||
            wordIndex > definition.items.length ||
            (selectedSound != null &&
                (wordIndex >= definition.items.length ||
                    !definition.items[wordIndex].choices
                        .contains(selectedSound))) ||
            (finished &&
                (wordIndex != definition.items.length ||
                    selectedSound != null))) {
          throw const LearningInvalidCommandException();
        }
      case DrillCheckpoint(
          :final pairIds,
          :final index,
          :final correct,
          :final ended
        ):
        if (!_sameOrder(
                pairIds, definition.items.map((item) => item.id).toList()) ||
            index < 0 ||
            index > pairIds.length ||
            correct < 0 ||
            correct > index ||
            (ended && index > pairIds.length)) {
          throw const LearningInvalidCommandException();
        }
      case SoundGameCheckpoint() || WordGameCheckpoint():
        throw const LearningInvalidCommandException();
    }
  }

  void _requirePracticeSpeech(AttemptAudioSource source) {
    if (source != AttemptAudioSource.practiceSpeech) {
      throw const LearningInvalidCommandException();
    }
  }

  void _requireLessonOrDrill(LearningActivityDefinition definition) {
    if (definition.kind != LearningActivityKind.discovery &&
        definition.kind != LearningActivityKind.legacyLesson &&
        definition.kind != LearningActivityKind.drill) {
      throw const LearningInvalidCommandException();
    }
  }
}

bool _sameOrder(List<String> first, List<String> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}

class _Mutation {
  const _Mutation({
    required this.snapshot,
    this.answerItem,
    this.selectedChoice,
    this.feedback = const LearningFeedback.none(),
  });
  final ActivitySnapshot snapshot;
  final LearningSourceItem? answerItem;
  final String? selectedChoice;
  final LearningFeedback feedback;
}

class _NoRandom implements Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
  @override
  int nextInt(int max) => throw const LearningInvalidCommandException();
}
