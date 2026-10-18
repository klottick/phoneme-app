import 'course_audio_contract.dart';
import 'course_learning_transaction.dart';
import 'lesson_section_session.dart';
import 'sentence_hunt_content.dart';
import 'sentence_hunt_learning_command.dart';
import 'sentence_hunt_learning_state.dart';

final class SentenceHuntTransition {
  SentenceHuntTransition({
    required this.nextState,
    required this.slot,
    required List<SentenceHuntAttempt> attempts,
    required this.duplicate,
  }) : attempts = List<SentenceHuntAttempt>.unmodifiable(attempts);

  final SentenceHuntLearningState nextState;
  final SentenceHuntSlot slot;
  final List<SentenceHuntAttempt> attempts;
  final bool duplicate;
}

/// Pure reducer for the sentence-hunt family. It never writes storage and it
/// restores a detached shared LessonSectionSession for every candidate.
final class SentenceHuntTransitionEngine {
  SentenceHuntTransitionEngine({
    required this.catalogue,
    this.limits = const SentenceHuntLearningLimits(),
  }) {
    limits.validate();
  }

  final SentenceHuntCatalogue catalogue;
  final SentenceHuntLearningLimits limits;

  SentenceHuntLearningCommand prepare({
    required SentenceHuntLearningState state,
    required String sectionId,
    required SentenceHuntAction action,
    required int authGeneration,
    required String token,
    required DateTime submittedAt,
  }) {
    // Availability and the complete scored fingerprint gate every transition,
    // including a Start; pending packages cannot create partial sessions.
    final SentenceHuntSection section = _registeredSection(sectionId);
    final SentenceHuntSlot? slot = state.slots[sectionId];
    SentenceHuntAction normalizedAction = action;
    if (action case AnswerSentenceHuntItem(:final answer)) {
      final SentenceHuntSlot active = _activeSlot(state, section, slot);
      final LessonSectionSession session = _restore(active, section);
      final String? currentId = session.currentItemId;
      if (currentId == null) {
        throw StateError('No sentence-hunt item is answerable.');
      }
      final SentenceHuntItem item = catalogue.item(sectionId, currentId);
      if (answer.content != item.identity) {
        throw ArgumentError('Answer content identity is stale.');
      }
      normalizedAction = AnswerSentenceHuntItem(SentenceHuntAnswer(
        content: answer.content,
        selectedTokenIds:
            canonicalSentenceSelection(item, answer.selectedTokenIds),
        expectedTokenIdsSnapshot: answer.expectedTokenIdsSnapshot,
        playback: answer.playback,
      ));
    }

    final LearningCursorPosition expected = slot?.cursor ??
        const LearningCursorPosition(generation: 0, sequence: 0, revision: 0);
    final SentenceHuntLearningCommand command = SentenceHuntLearningCommand(
      scope: state.scope,
      authGeneration: authGeneration,
      sectionId: sectionId,
      sectionFingerprint: section.sectionFingerprint,
      expected: expected,
      token: token,
      submittedAt: submittedAt,
      action: normalizedAction,
    );
    // Same reducer validation as commit-time evaluation. The resulting local
    // projection is discarded, so prepare never mutates a prior snapshot.
    evaluate(state: state, command: command, committedAt: submittedAt);
    return command;
  }

  SentenceHuntTransition evaluate({
    required SentenceHuntLearningState state,
    required SentenceHuntLearningCommand command,
    required DateTime committedAt,
  }) {
    if (!committedAt.isUtc ||
        command.scope != state.scope ||
        command.authGeneration < 0 ||
        command.sectionId.trim().isEmpty ||
        command.expected !=
            (state.slots[command.sectionId]?.cursor ??
                const LearningCursorPosition(
                    generation: 0, sequence: 0, revision: 0))) {
      throw ArgumentError('Stale sentence-hunt command.');
    }
    final SentenceHuntSection section = _registeredSection(command.sectionId);
    if (command.sectionFingerprint != section.sectionFingerprint) {
      throw ArgumentError('Sentence-hunt content fingerprint is stale.');
    }
    final SentenceHuntSlot? beforeSlot = state.slots[command.sectionId];

    if (command.action case final StartSentenceHuntRun start) {
      final LessonSectionSession session =
          _startSession(state, section, beforeSlot, start);
      return _commit(
        state: state,
        command: command,
        beforeSlot: beforeSlot,
        section: section,
        session: session,
        mode: start.mode,
        finished: false,
        runStartRound: session.round,
        newAttempts: const <SentenceHuntAttempt>[],
        mistakes: state.mistakes,
        summaries: state.summaries,
        completions: state.completions,
        teachingExposure: state.teachingExposure,
        committedAt: committedAt,
      );
    }

    final SentenceHuntSlot active = _activeSlot(state, section, beforeSlot);
    if (active.checkpoint.finished) {
      throw StateError('Finished sentence-hunt runs cannot be resumed.');
    }
    final LessonSectionSession session = _restore(active, section);
    final List<SentenceHuntAttempt> newAttempts = <SentenceHuntAttempt>[];
    final Map<SentenceHuntMistakeKey, SentenceHuntMistake> mistakes =
        Map<SentenceHuntMistakeKey, SentenceHuntMistake>.of(state.mistakes);
    final Map<SentenceHuntSummaryKey, SentenceHuntSummary> summaries =
        Map<SentenceHuntSummaryKey, SentenceHuntSummary>.of(state.summaries);
    final List<SentenceHuntCompletion> completions =
        List<SentenceHuntCompletion>.of(state.completions);
    final Set<SentenceHuntExposureKey> exposure =
        Set<SentenceHuntExposureKey>.of(state.teachingExposure);
    bool finished = false;

    switch (command.action) {
      case AnswerSentenceHuntItem(:final answer):
        final String? itemId = session.currentItemId;
        if (itemId == null || session.answered) {
          throw StateError('No sentence-hunt item is answerable.');
        }
        final SentenceHuntItem item = catalogue.item(section.id, itemId);
        _validateAnswer(
          answer: answer,
          item: item,
          scope: state.scope,
          generation: active.cursor.generation,
          round: session.round,
        );
        final bool correct =
            scoreSentenceSelection(item, answer.selectedTokenIds);
        final bool firstInRun =
            session.round == active.checkpoint.runStartRound;
        final bool teachingExposed = exposure.contains(_exposureKey(
          state.scope,
          section.id,
          section.contentRevision,
        ));
        session.submit(correct);

        final SentenceHuntMistakeKey mistakeKey = SentenceHuntMistakeKey(
          scope: state.scope,
          content: item.identity,
        );
        if (correct) {
          mistakes.remove(mistakeKey);
        } else {
          final SentenceHuntMistake? prior = mistakes[mistakeKey];
          mistakes[mistakeKey] = SentenceHuntMistake(
            key: mistakeKey,
            firstWrongAt: prior?.firstWrongAt ?? command.submittedAt,
            latestWrongAt: command.submittedAt,
            failureCount: (prior?.failureCount ?? 0) + 1,
          );
        }

        final SentenceHuntSummaryKey summaryKey = SentenceHuntSummaryKey(
          scope: state.scope,
          content: item.identity,
        );
        final SentenceHuntSummary? prior = summaries[summaryKey];
        final SentenceHuntCounts first =
            prior?.firstInRun ?? SentenceHuntCounts(correct: 0, total: 0);
        final SentenceHuntCounts repeat =
            prior?.repeatInRun ?? SentenceHuntCounts(correct: 0, total: 0);
        final SentenceHuntCounts firstExposed = prior?.firstTeachingExposed ??
            SentenceHuntCounts(correct: 0, total: 0);
        final SentenceHuntCounts repeatExposed = prior?.repeatTeachingExposed ??
            SentenceHuntCounts(correct: 0, total: 0);
        summaries[summaryKey] = SentenceHuntSummary(
          key: summaryKey,
          firstInRun: firstInRun ? _increment(first, correct) : first,
          repeatInRun: firstInRun ? repeat : _increment(repeat, correct),
          firstTeachingExposed: firstInRun && teachingExposed
              ? _increment(firstExposed, correct)
              : firstExposed,
          repeatTeachingExposed: !firstInRun && teachingExposed
              ? _increment(repeatExposed, correct)
              : repeatExposed,
        );
        newAttempts.add(SentenceHuntAttempt(
          scope: state.scope,
          content: item.identity,
          runGeneration: active.cursor.generation,
          round: session.round,
          sequence: active.cursor.sequence + 1,
          selectedTokenIds: answer.selectedTokenIds,
          expectedTokenIds: item.expectedTokenIds,
          correct: correct,
          presentation: firstInRun
              ? AttemptPresentation.firstInRun
              : AttemptPresentation.repeatInRun,
          teachingExposed: teachingExposed,
          playback: answer.playback,
          answeredAt: command.submittedAt,
          committedAt: committedAt,
        ));
      case AdvanceSentenceHuntItem():
        session.advance();
        if (session.phase == LessonSectionPhase.debrief) {
          exposure.add(_exposureKey(
            state.scope,
            section.id,
            section.contentRevision,
          ));
        }
      case ReviewSentenceHuntMistakes():
        session.reviewMistakes();
      case FinishSentenceHuntRun():
        if (session.phase != LessonSectionPhase.debrief) {
          throw StateError('Sentence-hunt Finish requires the debrief.');
        }
        finished = true;
        if (active.checkpoint.mode == SentenceHuntRunMode.practice &&
            session.canComplete) {
          final SentenceHuntCompletion completion = SentenceHuntCompletion(
            scope: state.scope,
            sectionId: section.id,
            contentRevision: section.contentRevision,
            policyRevision: section.policyRevision,
            thresholdPercent:
                active.checkpoint.policy.completionThresholdPercent,
            committedAt: committedAt,
          );
          if (!completions.contains(completion)) completions.add(completion);
        }
      case StartSentenceHuntRun():
        throw StateError('Unreachable sentence-hunt action dispatch.');
    }

    return _commit(
      state: state,
      command: command,
      beforeSlot: active,
      section: section,
      session: session,
      mode: active.checkpoint.mode,
      finished: finished,
      runStartRound: active.checkpoint.runStartRound,
      newAttempts: newAttempts,
      mistakes: mistakes,
      summaries: summaries,
      completions: completions,
      teachingExposure: exposure,
      committedAt: committedAt,
    );
  }

  SentenceHuntSection _registeredSection(String sectionId) {
    final SentenceHuntSection section = catalogue.section(sectionId);
    if (!catalogue.isAvailable(sectionId)) {
      throw StateError('Sentence-hunt section is not fully available.');
    }
    return section;
  }

  SentenceHuntSlot _activeSlot(
    SentenceHuntLearningState state,
    SentenceHuntSection section,
    SentenceHuntSlot? slot,
  ) {
    if (slot == null) throw StateError('Sentence-hunt run has not started.');
    if (slot.checkpoint.sectionFingerprint != section.sectionFingerprint ||
        slot.checkpoint.contentRevision != section.contentRevision) {
      throw StateError('Sentence-hunt checkpoint content is stale.');
    }
    if (slot.checkpoint.scope != state.scope) {
      throw ArgumentError('Sentence-hunt checkpoint owner mismatch.');
    }
    return slot;
  }

  LessonSectionSession _startSession(
    SentenceHuntLearningState state,
    SentenceHuntSection section,
    SentenceHuntSlot? beforeSlot,
    StartSentenceHuntRun start,
  ) {
    final List<String> itemIds = section.items
        .map((SentenceHuntItem item) => item.identity.itemId)
        .toList(growable: false);
    if (start.mode == SentenceHuntRunMode.practice) {
      if (beforeSlot != null &&
          !beforeSlot.checkpoint.finished &&
          !start.replaceExisting) {
        throw StateError('An unfinished sentence-hunt run already exists.');
      }
      return LessonSectionSession(
        itemIds: itemIds,
        sessionId: start.sessionId,
        contentRevision: section.contentRevision,
        policy: start.policy,
      );
    }

    if (beforeSlot == null || !beforeSlot.checkpoint.finished) {
      throw StateError('Review-only run requires a finished debrief.');
    }
    if (beforeSlot.checkpoint.sectionFingerprint !=
            section.sectionFingerprint ||
        beforeSlot.checkpoint.contentRevision != section.contentRevision) {
      throw StateError('Review-only checkpoint content is stale.');
    }
    if (beforeSlot.checkpoint.policy.completionThresholdPercent !=
        start.policy.completionThresholdPercent) {
      throw StateError('Review-only must use the saved completion policy.');
    }
    final Map<String, dynamic> copied =
        _mutableJson(beforeSlot.checkpoint.sessionJson) as Map<String, dynamic>;
    // This is the only field changed before restoring the shared session API.
    copied['sessionId'] = start.sessionId;
    final LessonSectionSession session = LessonSectionSession.fromJson(
      copied,
      itemIds: itemIds,
      contentRevision: section.contentRevision,
    );
    if (session.phase != LessonSectionPhase.debrief ||
        session.unresolvedItemIds.isEmpty) {
      throw StateError('No unresolved items are available for review.');
    }
    session.reviewMistakes();
    return session;
  }

  void _validateAnswer({
    required SentenceHuntAnswer answer,
    required SentenceHuntItem item,
    required SentenceHuntProfileScope scope,
    required int generation,
    required int round,
  }) {
    final List<String> canonical =
        canonicalSentenceSelection(item, answer.selectedTokenIds);
    if (answer.content != item.identity ||
        !_sameOrder(canonical, answer.selectedTokenIds) ||
        !_sameOrder(answer.expectedTokenIdsSnapshot, item.expectedTokenIds)) {
      throw ArgumentError('Sentence-hunt answer key or selection is stale.');
    }
    final SentenceHuntPlaybackObservation playback = answer.playback;
    if (playback.scope != scope ||
        playback.content != item.identity ||
        playback.runGeneration != generation ||
        playback.round != round ||
        playback.referenceId != item.identity.audioRefId ||
        playback.outcome != CourseAudioOutcome.completed ||
        playback.source != CourseAudioSource.reviewedRecording) {
      throw ArgumentError('Invalid sentence-hunt playback provenance.');
    }
  }

  SentenceHuntExposureKey _exposureKey(
    SentenceHuntProfileScope scope,
    String sectionId,
    int contentRevision,
  ) =>
      SentenceHuntExposureKey(
        scope: scope,
        sectionId: sectionId,
        contentRevision: contentRevision,
      );

  SentenceHuntCounts _increment(SentenceHuntCounts counts, bool correct) =>
      SentenceHuntCounts(
        correct: counts.correct + (correct ? 1 : 0),
        total: counts.total + 1,
      );

  SentenceHuntTransition _commit({
    required SentenceHuntLearningState state,
    required SentenceHuntLearningCommand command,
    required SentenceHuntSlot? beforeSlot,
    required SentenceHuntSection section,
    required LessonSectionSession session,
    required SentenceHuntRunMode mode,
    required bool finished,
    required int runStartRound,
    required List<SentenceHuntAttempt> newAttempts,
    required Map<SentenceHuntMistakeKey, SentenceHuntMistake> mistakes,
    required Map<SentenceHuntSummaryKey, SentenceHuntSummary> summaries,
    required List<SentenceHuntCompletion> completions,
    required Set<SentenceHuntExposureKey> teachingExposure,
    required DateTime committedAt,
  }) {
    if (state.commitOrdinal >= sentenceHuntMaxSafeInteger ||
        state.revision >= sentenceHuntMaxSafeInteger) {
      throw StateError('Sentence-hunt document revision is exhausted.');
    }
    if (mistakes.length > limits.maxAggregateEntries) {
      throw SentenceHuntCapacityException(
          'mistakes', limits.maxAggregateEntries);
    }
    if (summaries.length > limits.maxAggregateEntries) {
      throw SentenceHuntCapacityException(
          'summaries', limits.maxAggregateEntries);
    }
    if (completions.length > limits.maxAggregateEntries) {
      throw SentenceHuntCapacityException(
          'completions', limits.maxAggregateEntries);
    }
    if (teachingExposure.length > limits.maxAggregateEntries) {
      throw SentenceHuntCapacityException(
          'teachingExposure', limits.maxAggregateEntries);
    }

    final LearningCursorPosition before = beforeSlot?.cursor ??
        const LearningCursorPosition(generation: 0, sequence: 0, revision: 0);
    final bool starting = command.action is StartSentenceHuntRun;
    if (before.sequence >= sentenceHuntMaxSafeInteger ||
        (starting && before.generation >= sentenceHuntMaxSafeInteger) ||
        (!starting && before.revision >= sentenceHuntMaxSafeInteger)) {
      throw StateError('Sentence-hunt cursor is exhausted.');
    }
    final int generation = starting ? before.generation + 1 : before.generation;
    final LearningCursorPosition after = LearningCursorPosition(
      generation: generation,
      sequence: before.sequence + 1,
      revision: starting ? 0 : before.revision + 1,
    );
    final int ordinal = state.commitOrdinal + 1;
    final SentenceHuntReceipt receipt = SentenceHuntReceipt(
      scope: state.scope,
      sectionId: command.sectionId,
      token: command.token,
      canonicalCommand: sentenceHuntCanonicalCommand(command),
      before: before,
      after: after,
      commitOrdinal: ordinal,
    );
    final SentenceHuntCheckpoint checkpoint = SentenceHuntCheckpoint(
      scope: state.scope,
      sessionId: session.sessionId,
      sectionFingerprint: section.sectionFingerprint,
      contentRevision: section.contentRevision,
      mode: mode,
      finished: finished,
      policy: session.policy,
      sessionJson: Map<String, Object?>.from(session.toJson()),
      runStartRound: runStartRound,
    );
    final SentenceHuntSlot slot = SentenceHuntSlot(
      sectionId: section.id,
      checkpoint: checkpoint,
      cursor: after,
      latestReceipt: receipt,
    );
    final Map<String, SentenceHuntSlot> slots =
        Map<String, SentenceHuntSlot>.of(state.slots)..[section.id] = slot;
    final List<SentenceHuntReceipt> allReceipts = <SentenceHuntReceipt>[
      ...state.receipts,
      receipt,
    ];
    final List<SentenceHuntAttempt> allAttempts = <SentenceHuntAttempt>[
      ...state.attempts,
      ...newAttempts,
    ];
    final SentenceHuntLearningState nextState = SentenceHuntLearningState(
      scope: state.scope,
      revision: state.revision + 1,
      commitOrdinal: ordinal,
      slots: slots,
      attempts: allAttempts
          .skip(allAttempts.length > limits.maxAttempts
              ? allAttempts.length - limits.maxAttempts
              : 0)
          .toList(growable: false),
      receipts: allReceipts
          .skip(allReceipts.length > limits.maxReceipts
              ? allReceipts.length - limits.maxReceipts
              : 0)
          .toList(growable: false),
      mistakes: mistakes,
      summaries: summaries,
      completions: completions,
      teachingExposure: teachingExposure,
    );
    return SentenceHuntTransition(
      nextState: nextState,
      slot: slot,
      attempts: newAttempts,
      duplicate: false,
    );
  }
}

LessonSectionSession _restore(
    SentenceHuntSlot slot, SentenceHuntSection section) {
  return LessonSectionSession.fromJson(
    _mutableJson(slot.checkpoint.sessionJson) as Map<String, dynamic>,
    itemIds: section.items
        .map((SentenceHuntItem item) => item.identity.itemId)
        .toList(growable: false),
    contentRevision: section.contentRevision,
  );
}

Object? _mutableJson(Object? value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final MapEntry<Object?, Object?> entry in value.entries)
        entry.key as String: _mutableJson(entry.value),
    };
  }
  if (value is List) {
    final List<Object?> result =
        value.map<Object?>((Object? child) => _mutableJson(child)).toList();
    return result.every((Object? child) => child is String)
        ? result.cast<String>()
        : result;
  }
  return value;
}

bool _sameOrder(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}
