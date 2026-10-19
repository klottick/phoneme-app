import 'dart:convert';

import '../course_audio_contract.dart';
import '../learning_storage_types.dart';
import '../lesson_section_session.dart';
import '../sentence_hunt_content.dart';
import '../sentence_hunt_learning_command.dart' as domain;
import '../sentence_hunt_learning_state.dart';
import 'sentence_hunt_learning_checkpoint_codec.dart';
import 'sentence_hunt_learning_command_codec.dart';

/// Validates typed state assembled from sentence-hunt SQL rows.
///
/// It never serializes or decodes the complete legacy profile document.
final class SentenceHuntLearningStateValidator {
  const SentenceHuntLearningStateValidator._();

  static void validate(
    SentenceHuntLearningState state,
    SentenceHuntCatalogue catalogue,
  ) {
    try {
      _validate(state, catalogue);
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Invalid sentence-hunt learning state: $error');
    }
  }

  static void _validate(
    SentenceHuntLearningState state,
    SentenceHuntCatalogue catalogue,
  ) {
    final descriptors = _descriptors(catalogue);
    if (state.schemaVersion != 1 ||
        state.revision < 0 ||
        state.revision > sentenceHuntMaxSafeInteger ||
        state.commitOrdinal != state.revision ||
        state.attempts.length > sentenceHuntMaxAttempts ||
        state.receipts.length > sentenceHuntMaxReceipts ||
        state.slots.length > sentenceHuntMaxSlots ||
        state.mistakes.length > sentenceHuntMaxAggregateEntries ||
        state.summaries.length > sentenceHuntMaxAggregateEntries ||
        state.completions.length > sentenceHuntMaxAggregateEntries ||
        state.teachingExposure.length > sentenceHuntMaxAggregateEntries) {
      throw const FormatException(
        'Sentence-hunt state exceeds supported bounds.',
      );
    }
    if (state.commitOrdinal == 0) {
      if (state.slots.isNotEmpty ||
          state.attempts.isNotEmpty ||
          state.receipts.isNotEmpty ||
          state.mistakes.isNotEmpty ||
          state.summaries.isNotEmpty ||
          state.completions.isNotEmpty ||
          state.teachingExposure.isNotEmpty) {
        throw const FormatException('Empty sentence-hunt state has SQL rows.');
      }
      return;
    }
    if (state.receipts.isEmpty ||
        state.receipts.last.commitOrdinal != state.commitOrdinal) {
      throw const FormatException(
        'Retained receipt tail lacks the latest commit.',
      );
    }

    final byCursor = <String, _ReceiptProof>{};
    final tokens = <String, SentenceHuntReceipt>{};
    final ordinals = <int>{};
    final priorBySection = <String, SentenceHuntReceipt>{};
    var priorOrdinal = state.receipts.first.commitOrdinal - 1;
    for (final receipt in state.receipts) {
      if (receipt.scope != state.scope ||
          receipt.commitOrdinal != priorOrdinal + 1 ||
          receipt.commitOrdinal > state.commitOrdinal ||
          !ordinals.add(receipt.commitOrdinal)) {
        throw const FormatException('Sentence-hunt receipt tail is invalid.');
      }
      priorOrdinal = receipt.commitOrdinal;
      final command = SentenceHuntCommandCodec.decodeLegacyCanonicalCommand(
        receipt.canonicalCommand,
        scope: state.scope,
        catalogue: catalogue,
      );
      _validateReceiptCommand(command, receipt, descriptors);
      final previous = priorBySection[receipt.sectionId];
      if (previous != null && previous.after != receipt.before) {
        throw const FormatException('Receipt cursors are discontinuous.');
      }
      priorBySection[receipt.sectionId] = receipt;
      final oldToken = tokens[receipt.token];
      if (oldToken != null && !_sameReceipt(oldToken, receipt)) {
        throw const FormatException('Receipt token is multiply claimed.');
      }
      tokens[receipt.token] = receipt;
      final cursorKey = _cursorKey(receipt.sectionId, receipt.after);
      if (byCursor.containsKey(cursorKey)) {
        throw const FormatException('Receipt cursor is duplicated.');
      }
      byCursor[cursorKey] = _ReceiptProof(receipt, command);
    }

    final slotCommands = <String, domain.SentenceHuntLearningCommand>{};
    final latestOrdinals = <int>{};
    for (final entry in state.slots.entries) {
      final slot = entry.value;
      final checkpoint = slot.checkpoint;
      final descriptor = _descriptorByIdentity(
        descriptors,
        slot.sectionId,
        checkpoint.contentRevision,
        checkpoint.sectionFingerprint,
      );
      if (entry.key != slot.sectionId ||
          descriptor == null ||
          slot.sectionId != descriptor.sectionId ||
          checkpoint.scope != state.scope ||
          checkpoint.contentRevision != descriptor.contentRevision ||
          checkpoint.sectionFingerprint != descriptor.fingerprint ||
          slot.cursor != slot.latestReceipt.after ||
          slot.latestReceipt.sectionId != slot.sectionId ||
          slot.latestReceipt.scope != state.scope ||
          slot.latestReceipt.commitOrdinal > state.commitOrdinal ||
          !latestOrdinals.add(slot.latestReceipt.commitOrdinal)) {
        throw const FormatException('Sentence-hunt slot identity is invalid.');
      }
      final command = SentenceHuntCommandCodec.decodeLegacyCanonicalCommand(
        slot.latestReceipt.canonicalCommand,
        scope: state.scope,
        catalogue: catalogue,
      );
      _validateReceiptCommand(command, slot.latestReceipt, descriptors);
      if (command.sectionFingerprint != checkpoint.sectionFingerprint) {
        throw const FormatException('Latest receipt and checkpoint differ.');
      }
      final indexed = byCursor[_cursorKey(slot.sectionId, slot.cursor)];
      if (indexed != null &&
          !_sameReceipt(indexed.receipt, slot.latestReceipt)) {
        throw const FormatException('Latest receipt differs from SQL history.');
      }
      for (final receipt in state.receipts) {
        if (receipt.sectionId == slot.sectionId &&
            receipt.commitOrdinal > slot.latestReceipt.commitOrdinal) {
          throw const FormatException(
            'Slot receipt is not latest for section.',
          );
        }
      }
      final existingToken = tokens[slot.latestReceipt.token];
      if (existingToken != null &&
          !_sameReceipt(existingToken, slot.latestReceipt)) {
        throw const FormatException(
          'Latest receipt token conflicts with history.',
        );
      }
      tokens[slot.latestReceipt.token] = slot.latestReceipt;
      if (!state.slots.containsKey(slot.sectionId)) {
        throw const FormatException('Slot is not indexed by its section.');
      }
      final current = catalogue.section(slot.sectionId);
      if (!catalogue.isAvailable(slot.sectionId) ||
          current.contentRevision != checkpoint.contentRevision ||
          current.sectionFingerprint != checkpoint.sectionFingerprint) {
        throw const FormatException(
          'Current slot content is no longer available.',
        );
      }
      final checkpointJson = const SentenceHuntCheckpointCodec().encode(
        checkpoint,
      );
      final restored = const SentenceHuntCheckpointCodec().decode(
        checkpointJson,
        scope: state.scope,
        sectionId: slot.sectionId,
        catalogue: catalogue,
        mode: checkpoint.mode,
        finished: checkpoint.finished,
        policy: checkpoint.policy,
        runStartRound: checkpoint.runStartRound,
      );
      final session = _session(restored, current);
      _validateLatestSlot(state, slot, command, session, descriptors);
      slotCommands[slot.sectionId] = command;
    }
    if (!latestOrdinals.contains(state.commitOrdinal)) {
      throw const FormatException('No slot proves the latest scope commit.');
    }
    for (final receipt in state.receipts) {
      if (!state.slots.containsKey(receipt.sectionId)) {
        throw const FormatException('Receipt has no retained section slot.');
      }
    }

    _validateAttempts(state, catalogue, descriptors, byCursor);
    _validateMistakes(state, descriptors);
    _validateSummaries(state, descriptors);
    _validateExposure(state, descriptors);
    _validateCompletions(state, descriptors);
    _validateCurrentSessionAnswers(state, catalogue, slotCommands, byCursor);
  }

  static void _validateReceiptCommand(
    domain.SentenceHuntLearningCommand command,
    SentenceHuntReceipt receipt,
    Map<String, _Descriptor> descriptors,
  ) {
    if (command.scope != receipt.scope ||
        command.sectionId != receipt.sectionId ||
        command.token != receipt.token ||
        command.expected != receipt.before ||
        !_reachableActionCursor(
          command.action,
          receipt.before,
          receipt.after,
        )) {
      throw const FormatException('Receipt header or cursor is unreachable.');
    }
    final descriptor = _descriptorByFingerprint(
      descriptors,
      command.sectionId,
      command.sectionFingerprint,
    );
    if (descriptor == null) {
      throw const FormatException('Receipt uses an unknown fingerprint.');
    }
    if (command.action case domain.StartSentenceHuntRun(:final policy)) {
      if (policy.completionThresholdPercent != descriptor.thresholdPercent) {
        throw const FormatException(
          'Receipt start policy differs from content.',
        );
      }
    }
    if (command.action case domain.AnswerSentenceHuntItem(:final answer)) {
      _validateAnswer(answer, descriptor);
      if (answer.content.sectionId != command.sectionId ||
          answer.playback.runGeneration != receipt.after.generation) {
        throw const FormatException('Receipt answer generation mismatch.');
      }
    }
  }

  static void _validateAnswer(
    domain.SentenceHuntAnswer answer,
    _Descriptor descriptor,
  ) {
    final item = _resolveIdentity(descriptor, answer.content);
    final playback = answer.playback;
    if (answer.expectedTokenIdsSnapshot.isEmpty ||
        !_sameList(answer.expectedTokenIdsSnapshot, item.expectedTokenIds) ||
        !_sameList(
          _canonicalSelection(item.selectableTokenIds, answer.selectedTokenIds),
          answer.selectedTokenIds,
        ) ||
        playback.content != answer.content ||
        playback.referenceId != answer.content.audioRefId ||
        playback.outcome != CourseAudioOutcome.completed ||
        playback.source != CourseAudioSource.reviewedRecording) {
      throw const FormatException(
        'Answer content or playback evidence mismatch.',
      );
    }
  }

  static void _validateAttempts(
    SentenceHuntLearningState state,
    SentenceHuntCatalogue catalogue,
    Map<String, _Descriptor> descriptors,
    Map<String, _ReceiptProof> byCursor,
  ) {
    final identities = <String>{};
    final retained = <SentenceHuntSummaryKey, List<int>>{};
    for (final attempt in state.attempts) {
      final descriptor = _descriptorByRevision(
        descriptors,
        attempt.content.sectionId,
        attempt.content.contentRevision,
      );
      if (descriptor == null ||
          attempt.scope != state.scope ||
          attempt.runGeneration < 1 ||
          attempt.sequence < 1 ||
          attempt.round < 1 ||
          !attempt.answeredAt.isUtc ||
          !attempt.committedAt.isUtc ||
          attempt.committedAt.isBefore(attempt.answeredAt) ||
          attempt.playback.scope != state.scope ||
          attempt.playback.content != attempt.content ||
          attempt.playback.referenceId != attempt.content.audioRefId ||
          attempt.playback.outcome != CourseAudioOutcome.completed ||
          attempt.playback.source != CourseAudioSource.reviewedRecording ||
          attempt.playback.runGeneration != attempt.runGeneration ||
          attempt.playback.round != attempt.round ||
          !identities.add(
            _attemptKey(
              attempt.content.sectionId,
              attempt.runGeneration,
              attempt.sequence,
            ),
          )) {
        throw const FormatException(
          'Sentence-hunt attempt evidence is invalid.',
        );
      }
      final item = _resolveIdentity(descriptor, attempt.content);
      if (!_sameList(attempt.expectedTokenIds, item.expectedTokenIds) ||
          !_sameList(
            _canonicalSelection(
              item.selectableTokenIds,
              attempt.selectedTokenIds,
            ),
            attempt.selectedTokenIds,
          ) ||
          attempt.correct !=
              _equalSet(attempt.selectedTokenIds, item.expectedTokenIds)) {
        throw const FormatException(
          'Attempt is not bound to authored content.',
        );
      }
      final exposureKey = SentenceHuntExposureKey(
        scope: state.scope,
        sectionId: attempt.content.sectionId,
        contentRevision: attempt.content.contentRevision,
      );
      if (attempt.teachingExposed &&
          !state.teachingExposure.contains(exposureKey)) {
        throw const FormatException(
          'Attempt exposure lacks durable exposure row.',
        );
      }
      final proof =
          byCursor[_attemptKey(
            attempt.content.sectionId,
            attempt.runGeneration,
            attempt.sequence,
          )];
      if (proof != null) {
        if (proof.command.action is! domain.AnswerSentenceHuntItem ||
            proof.receipt.commitOrdinal != attempt.sequence &&
                proof.receipt.commitOrdinal < attempt.sequence) {
          throw const FormatException('Attempt links to a non-answer receipt.');
        }
        final answer =
            (proof.command.action as domain.AnswerSentenceHuntItem).answer;
        if (proof.receipt.after.generation != attempt.runGeneration ||
            proof.receipt.after.sequence != attempt.sequence ||
            proof.command.submittedAt != attempt.answeredAt ||
            answer.content != attempt.content ||
            !_sameList(answer.selectedTokenIds, attempt.selectedTokenIds) ||
            !_sameList(
              answer.expectedTokenIdsSnapshot,
              attempt.expectedTokenIds,
            ) ||
            !_samePlayback(answer.playback, attempt.playback)) {
          throw const FormatException(
            'Attempt differs from its receipt proof.',
          );
        }
      }
      final key = SentenceHuntSummaryKey(
        scope: state.scope,
        content: attempt.content,
      );
      final counts = retained.putIfAbsent(key, () => List<int>.filled(8, 0));
      final first = attempt.presentation == AttemptPresentation.firstInRun;
      final base = first ? 0 : 2;
      counts[base]++;
      if (attempt.correct) counts[base + 1]++;
      if (attempt.teachingExposed) {
        counts[first ? 4 : 6]++;
        if (attempt.correct) counts[first ? 5 : 7]++;
      }
    }
    for (final entry in retained.entries) {
      final summary = state.summaries[entry.key];
      final counts = entry.value;
      if (summary == null ||
          summary.firstInRun.total < counts[0] ||
          summary.firstInRun.correct < counts[1] ||
          summary.repeatInRun.total < counts[2] ||
          summary.repeatInRun.correct < counts[3] ||
          summary.firstTeachingExposed.total < counts[4] ||
          summary.firstTeachingExposed.correct < counts[5] ||
          summary.repeatTeachingExposed.total < counts[6] ||
          summary.repeatTeachingExposed.correct < counts[7]) {
        throw const FormatException('Summary undercounts retained attempts.');
      }
    }
  }

  static void _validateMistakes(
    SentenceHuntLearningState state,
    Map<String, _Descriptor> descriptors,
  ) {
    for (final entry in state.mistakes.entries) {
      final mistake = entry.value;
      if (entry.key != mistake.key ||
          entry.key.scope != state.scope ||
          !_containsIdentity(descriptors, mistake.content) ||
          !mistake.firstWrongAt.isUtc ||
          !mistake.latestWrongAt.isUtc ||
          mistake.latestWrongAt.isBefore(mistake.firstWrongAt) ||
          mistake.failureCount < 1) {
        throw const FormatException(
          'Sentence-hunt mistake identity is invalid.',
        );
      }
    }
  }

  static void _validateSummaries(
    SentenceHuntLearningState state,
    Map<String, _Descriptor> descriptors,
  ) {
    for (final entry in state.summaries.entries) {
      final summary = entry.value;
      if (entry.key != summary.key ||
          entry.key.scope != state.scope ||
          !_containsIdentity(descriptors, summary.content)) {
        throw const FormatException(
          'Sentence-hunt summary identity is invalid.',
        );
      }
      _validateCount(summary.firstInRun);
      _validateCount(summary.repeatInRun);
      _validateCount(summary.firstTeachingExposed);
      _validateCount(summary.repeatTeachingExposed);
    }
  }

  static void _validateExposure(
    SentenceHuntLearningState state,
    Map<String, _Descriptor> descriptors,
  ) {
    for (final key in state.teachingExposure) {
      if (key.scope != state.scope ||
          _descriptorByRevision(
                descriptors,
                key.sectionId,
                key.contentRevision,
              ) ==
              null) {
        throw const FormatException('Unknown sentence-hunt exposure identity.');
      }
    }
  }

  static void _validateCompletions(
    SentenceHuntLearningState state,
    Map<String, _Descriptor> descriptors,
  ) {
    final identities = <String>{};
    for (final completion in state.completions) {
      final matches = descriptors.values.any(
        (descriptor) =>
            descriptor.sectionId == completion.sectionId &&
            descriptor.contentRevision == completion.contentRevision &&
            descriptor.policyRevision == completion.policyRevision &&
            descriptor.thresholdPercent == completion.thresholdPercent,
      );
      final identity = jsonEncode([
        completion.sectionId,
        completion.contentRevision,
        completion.policyRevision,
        completion.thresholdPercent,
      ]);
      if (completion.scope != state.scope ||
          !matches ||
          !completion.committedAt.isUtc ||
          !identities.add(identity)) {
        throw const FormatException('Sentence-hunt completion is invalid.');
      }
    }
  }

  static void _validateLatestSlot(
    SentenceHuntLearningState state,
    SentenceHuntSlot slot,
    domain.SentenceHuntLearningCommand command,
    LessonSectionSession session,
    Map<String, _Descriptor> descriptors,
  ) {
    final checkpoint = slot.checkpoint;
    switch (command.action) {
      case domain.StartSentenceHuntRun(
        :final sessionId,
        :final policy,
        :final mode,
      ):
        if (checkpoint.finished ||
            checkpoint.sessionId != sessionId ||
            checkpoint.mode != mode ||
            checkpoint.policy.completionThresholdPercent !=
                policy.completionThresholdPercent) {
          throw const FormatException(
            'Latest start metadata differs from slot.',
          );
        }
        if (mode == SentenceHuntRunMode.practice) {
          final section =
              descriptors[jsonEncode([
                slot.sectionId,
                checkpoint.contentRevision,
                checkpoint.sectionFingerprint,
              ])]!;
          final fresh = LessonSectionSession(
            itemIds: section.items.map((item) => item.identity.itemId).toList(),
            sessionId: sessionId,
            contentRevision: checkpoint.contentRevision,
            policy: policy,
          );
          if (jsonEncode(fresh.toJson()) != jsonEncode(session.toJson())) {
            throw const FormatException('Latest practice start is not fresh.');
          }
        } else if (session.round != checkpoint.runStartRound ||
            session.phase != LessonSectionPhase.exercise ||
            session.round < 2) {
          throw const FormatException(
            'Latest review-only start is unreachable.',
          );
        }
      case domain.AnswerSentenceHuntItem(:final answer):
        final correct = _equalSet(
          answer.selectedTokenIds,
          answer.expectedTokenIdsSnapshot,
        );
        final currentId = session.currentItemId;
        if (checkpoint.finished ||
            currentId != answer.content.itemId ||
            !session.answered ||
            session.round != answer.playback.round ||
            session.lastCorrect != correct ||
            session.latestAnswers[currentId] != correct) {
          throw const FormatException('Latest answer differs from checkpoint.');
        }
        final attempt = state.attempts.where(
          (value) =>
              value.content.sectionId == slot.sectionId &&
              value.runGeneration == slot.cursor.generation &&
              value.sequence == slot.cursor.sequence,
        );
        if (attempt.isNotEmpty &&
            (attempt.length != 1 ||
                attempt.single.content != answer.content ||
                attempt.single.correct != correct ||
                !_sameList(
                  attempt.single.selectedTokenIds,
                  answer.selectedTokenIds,
                ))) {
          throw const FormatException(
            'Latest retained attempt differs from answer.',
          );
        }
      case domain.AdvanceSentenceHuntItem():
        if (checkpoint.finished || session.answered || session.position == 0) {
          throw const FormatException(
            'Latest advance lacks submitted queue prefix.',
          );
        }
      case domain.ReviewSentenceHuntMistakes():
        if (checkpoint.finished ||
            session.phase != LessonSectionPhase.exercise ||
            session.round < 2) {
          throw const FormatException(
            'Latest review did not start a review round.',
          );
        }
      case domain.FinishSentenceHuntRun():
        if (!checkpoint.finished ||
            session.phase != LessonSectionPhase.debrief) {
          throw const FormatException(
            'Latest finish is not a finished debrief.',
          );
        }
        if (checkpoint.mode == SentenceHuntRunMode.practice &&
            session.canComplete &&
            !state.completions.any(
              (completion) =>
                  completion.sectionId == slot.sectionId &&
                  completion.contentRevision == checkpoint.contentRevision &&
                  completion.policyRevision ==
                      descriptors[jsonEncode([
                            slot.sectionId,
                            checkpoint.contentRevision,
                            checkpoint.sectionFingerprint,
                          ])]!
                          .policyRevision &&
                  completion.thresholdPercent ==
                      checkpoint.policy.completionThresholdPercent,
            )) {
          throw const FormatException('Eligible finish lacks completion.');
        }
    }
  }

  static void _validateCurrentSessionAnswers(
    SentenceHuntLearningState state,
    SentenceHuntCatalogue catalogue,
    Map<String, domain.SentenceHuntLearningCommand> slotCommands,
    Map<String, _ReceiptProof> byCursor,
  ) {
    for (final slot in state.slots.values) {
      final session = _session(
        slot.checkpoint,
        catalogue.section(slot.sectionId),
      );
      final latestByItem = <String, (int, bool)>{};
      void record(int generation, int sequence, String itemId, bool correct) {
        if (generation != slot.cursor.generation) return;
        final prior = latestByItem[itemId];
        if (prior == null || sequence > prior.$1) {
          latestByItem[itemId] = (sequence, correct);
        } else if (sequence == prior.$1 && prior.$2 != correct) {
          throw const FormatException('Conflicting answer evidence.');
        }
      }

      for (final proof in byCursor.values) {
        if (proof.receipt.sectionId != slot.sectionId ||
            proof.command.action is! domain.AnswerSentenceHuntItem) {
          continue;
        }
        final answer =
            (proof.command.action as domain.AnswerSentenceHuntItem).answer;
        record(
          proof.receipt.after.generation,
          proof.receipt.after.sequence,
          answer.content.itemId,
          _equalSet(answer.selectedTokenIds, answer.expectedTokenIdsSnapshot),
        );
      }
      for (final attempt in state.attempts) {
        if (attempt.content.sectionId == slot.sectionId) {
          record(
            attempt.runGeneration,
            attempt.sequence,
            attempt.content.itemId,
            attempt.correct,
          );
        }
      }
      for (final entry in latestByItem.entries) {
        if (session.latestAnswers[entry.key] != entry.value.$2) {
          throw const FormatException(
            'Checkpoint answer differs from retained proof.',
          );
        }
      }
      final latestCommand = slotCommands[slot.sectionId];
      if (latestCommand == null || latestCommand.sectionId != slot.sectionId) {
        throw const FormatException('Slot lacks its typed latest receipt.');
      }
    }
  }

  static LessonSectionSession _session(
    SentenceHuntCheckpoint checkpoint,
    SentenceHuntSection section,
  ) => LessonSectionSession.fromJson(
    Map<String, dynamic>.from(checkpoint.sessionJson),
    itemIds: section.items.map((item) => item.identity.itemId).toList(),
    contentRevision: section.contentRevision,
  );

  static _Descriptor? _descriptorByIdentity(
    Map<String, _Descriptor> descriptors,
    String sectionId,
    int revision,
    String fingerprint,
  ) => descriptors[_descriptorKey(sectionId, revision, fingerprint)];

  static _Descriptor? _descriptorByFingerprint(
    Map<String, _Descriptor> descriptors,
    String sectionId,
    String fingerprint,
  ) {
    for (final descriptor in descriptors.values) {
      if (descriptor.sectionId == sectionId &&
          descriptor.fingerprint == fingerprint) {
        return descriptor;
      }
    }
    return null;
  }

  static _Descriptor? _descriptorByRevision(
    Map<String, _Descriptor> descriptors,
    String sectionId,
    int revision,
  ) {
    _Descriptor? found;
    for (final descriptor in descriptors.values) {
      if (descriptor.sectionId != sectionId ||
          descriptor.contentRevision != revision) {
        continue;
      }
      if (found != null && !_sameDescriptor(found, descriptor)) {
        throw const FormatException('Ambiguous historical item revision.');
      }
      found = descriptor;
    }
    return found;
  }

  static _ItemDescriptor _resolveIdentity(
    _Descriptor descriptor,
    SentenceHuntContentIdentity identity,
  ) {
    for (final item in descriptor.items) {
      if (item.identity == identity) return item;
    }
    throw const FormatException('Unknown sentence-hunt content identity.');
  }

  static bool _containsIdentity(
    Map<String, _Descriptor> descriptors,
    SentenceHuntContentIdentity identity,
  ) {
    final descriptor = _descriptorByRevision(
      descriptors,
      identity.sectionId,
      identity.contentRevision,
    );
    if (descriptor == null) return false;
    try {
      _resolveIdentity(descriptor, identity);
      return true;
    } on FormatException {
      return false;
    }
  }

  static Map<String, _Descriptor> _descriptors(
    SentenceHuntCatalogue catalogue,
  ) {
    final result = <String, _Descriptor>{};
    for (final section in catalogue.sections) {
      final parsed = _parseFingerprint(section.sectionFingerprint, section.id);
      if (parsed.contentRevision != section.contentRevision ||
          parsed.policyRevision != section.policyRevision ||
          parsed.thresholdPercent !=
              section.policy.completionThresholdPercent ||
          parsed.items.length != section.items.length) {
        throw const FormatException('Current section fingerprint mismatch.');
      }
      for (var index = 0; index < section.items.length; index++) {
        final actual = section.items[index];
        final saved = parsed.items[index];
        if (actual.identity != saved.identity ||
            !_sameList(actual.selectableTokenIds, saved.selectableTokenIds) ||
            !_sameList(actual.expectedTokenIds, saved.expectedTokenIds)) {
          throw const FormatException('Current item fingerprint mismatch.');
        }
      }
      _insertDescriptor(result, parsed);
    }
    for (final historical in catalogue.historicalSections) {
      final parsed = _parseFingerprint(
        historical.sectionFingerprint,
        historical.sectionId,
      );
      if (parsed.kind != historical.kind.name ||
          parsed.contentRevision != historical.contentRevision ||
          parsed.policyRevision != historical.policyRevision ||
          parsed.thresholdPercent != historical.completionThresholdPercent) {
        throw const FormatException('Historical section fingerprint mismatch.');
      }
      _insertDescriptor(result, parsed);
    }
    return result;
  }

  static _Descriptor _parseFingerprint(String fingerprint, String sectionId) {
    final decoded = jsonDecode(fingerprint);
    if (decoded is! Map<String, dynamic> ||
        _canonicalJson(decoded) != fingerprint) {
      throw const FormatException('Section fingerprint is not canonical JSON.');
    }
    final root = _object(decoded, 'section fingerprint');
    _exactKeys(root, const ['items', 'section'], 'section fingerprint');
    final section = _object(root['section'], 'fingerprint.section');
    _exactKeys(section, const [
      'id',
      'kind',
      'contentRevision',
      'policyRevision',
      'completionThresholdPercent',
    ], 'fingerprint.section');
    final id = _text(section['id'], 'fingerprint.section.id');
    final kind = _text(section['kind'], 'fingerprint.section.kind');
    final revision = _positive(section['contentRevision'], 'contentRevision');
    final policyRevision = _positive(
      section['policyRevision'],
      'policyRevision',
    );
    final threshold = _positive(
      section['completionThresholdPercent'],
      'threshold',
    );
    if (id != sectionId ||
        !const {
          'en-fr-sentence-hunt-vowels',
          'en-fr-sentence-hunt-consonants',
          'en-fr-sentence-hunt-mixed',
        }.contains(id) ||
        !const {'vowels', 'consonants', 'mixed'}.contains(kind) ||
        threshold > 100) {
      throw const FormatException('Unknown section fingerprint identity.');
    }
    final rows = root['items'];
    if (rows is! List || rows.length != 5) {
      throw const FormatException('Fingerprint must retain all five items.');
    }
    final items = <_ItemDescriptor>[];
    final itemIds = <String>{};
    for (final rawItem in rows) {
      final item = _object(rawItem, 'fingerprint item');
      _exactKeys(item, const [
        'id',
        'sentenceId',
        'audioRefId',
        'purpose',
        'targetSound',
        'targetLabel',
        'text',
        'debriefNote',
        'annotationRevision',
        'annotationHash',
        'tokens',
        'expectedTokenIds',
        'originalSha256',
        'clipSha256',
      ], 'fingerprint item');
      final itemId = _text(item['id'], 'item.id');
      final sentenceId = _text(item['sentenceId'], 'item.sentenceId');
      final audioRefId = _text(item['audioRefId'], 'item.audioRefId');
      final annotationHash = _text(
        item['annotationHash'],
        'item.annotationHash',
      );
      final annotationRevision = _positive(
        item['annotationRevision'],
        'annotationRevision',
      );
      if (!itemIds.add(itemId) ||
          item['purpose'] != 'practice' ||
          !_sha256(annotationHash) ||
          !_sha256(_text(item['originalSha256'], 'originalSha256')) ||
          !_sha256(_text(item['clipSha256'], 'clipSha256'))) {
        throw const FormatException('Malformed fingerprint item identity.');
      }
      final tokens = item['tokens'];
      if (tokens is! List || tokens.isEmpty) {
        throw const FormatException(
          'Fingerprint item has no selectable tokens.',
        );
      }
      final selectable = <String>[];
      for (final rawToken in tokens) {
        final token = _object(rawToken, 'fingerprint token');
        _exactKeys(token, const [
          'id',
          'text',
          'phonemes',
        ], 'fingerprint token');
        final tokenId = _text(token['id'], 'token.id');
        _text(token['text'], 'token.text');
        final phonemes = _stringList(token['phonemes'], 'token.phonemes');
        if (phonemes.isEmpty || selectable.contains(tokenId)) {
          throw const FormatException('Invalid selectable token.');
        }
        selectable.add(tokenId);
      }
      final expected = _stringList(
        item['expectedTokenIds'],
        'expectedTokenIds',
        unique: true,
      );
      if (expected.isEmpty || expected.any((id) => !selectable.contains(id))) {
        throw const FormatException(
          'Expected key is not a selectable token subset.',
        );
      }
      items.add(
        _ItemDescriptor(
          identity: SentenceHuntContentIdentity(
            sectionId: sectionId,
            itemId: itemId,
            sentenceId: sentenceId,
            audioRefId: audioRefId,
            annotationHash: annotationHash,
            contentRevision: revision,
            annotationRevision: annotationRevision,
          ),
          selectableTokenIds: selectable,
          expectedTokenIds: expected,
        ),
      );
    }
    return _Descriptor(
      sectionId: sectionId,
      kind: kind,
      contentRevision: revision,
      policyRevision: policyRevision,
      thresholdPercent: threshold,
      fingerprint: fingerprint,
      items: items,
    );
  }

  static void _insertDescriptor(
    Map<String, _Descriptor> descriptors,
    _Descriptor descriptor,
  ) {
    final key = _descriptorKey(
      descriptor.sectionId,
      descriptor.contentRevision,
      descriptor.fingerprint,
    );
    final old = descriptors[key];
    if (old != null && !_sameDescriptor(old, descriptor)) {
      throw const FormatException('Conflicting content descriptors.');
    }
    descriptors[key] = descriptor;
  }

  static void _validateCount(SentenceHuntCounts count) {
    if (count.correct < 0 ||
        count.total < 0 ||
        count.correct > count.total ||
        count.correct > sentenceHuntMaxSafeInteger ||
        count.total > sentenceHuntMaxSafeInteger) {
      throw const FormatException('Invalid sentence-hunt summary count.');
    }
  }

  static bool _reachableActionCursor(
    domain.SentenceHuntAction action,
    LearningCursorPosition before,
    LearningCursorPosition after,
  ) {
    if (!_validCursor(before) || !_validCursor(after)) return false;
    if (action is domain.StartSentenceHuntRun) {
      if (before.generation == 0) {
        return before.sequence == 0 &&
            before.revision == 0 &&
            after.generation == 1 &&
            after.sequence == 1 &&
            after.revision == 0;
      }
      return before.generation < sentenceHuntMaxSafeInteger &&
          before.sequence < sentenceHuntMaxSafeInteger &&
          after.generation == before.generation + 1 &&
          after.sequence == before.sequence + 1 &&
          after.revision == 0;
    }
    return before.generation > 0 &&
        before.sequence < sentenceHuntMaxSafeInteger &&
        before.revision < sentenceHuntMaxSafeInteger &&
        after.generation == before.generation &&
        after.sequence == before.sequence + 1 &&
        after.revision == before.revision + 1;
  }

  static bool _validCursor(LearningCursorPosition cursor) =>
      cursor.generation >= 0 &&
      cursor.generation <= sentenceHuntMaxSafeInteger &&
      cursor.sequence >= 0 &&
      cursor.sequence <= sentenceHuntMaxSafeInteger &&
      cursor.revision >= 0 &&
      cursor.revision <= sentenceHuntMaxSafeInteger;

  static bool _equalSet(List<String> left, List<String> right) =>
      left.length == right.length && left.toSet().containsAll(right);

  static List<String> _canonicalSelection(
    List<String> selectable,
    List<String> values,
  ) {
    final selected = <String>{};
    for (final id in values) {
      if (!selectable.contains(id) || !selected.add(id)) {
        throw const FormatException('Unknown or repeated selected token.');
      }
    }
    return [
      for (final id in selectable)
        if (selected.contains(id)) id,
    ];
  }

  static String _cursorKey(String sectionId, LearningCursorPosition cursor) =>
      jsonEncode([sectionId, cursor.generation, cursor.sequence]);

  static String _attemptKey(String sectionId, int generation, int sequence) =>
      jsonEncode([sectionId, generation, sequence]);

  static String _descriptorKey(
    String sectionId,
    int revision,
    String fingerprint,
  ) => jsonEncode([sectionId, revision, fingerprint]);

  static bool _sameReceipt(
    SentenceHuntReceipt left,
    SentenceHuntReceipt right,
  ) =>
      left.scope == right.scope &&
      left.sectionId == right.sectionId &&
      left.token == right.token &&
      left.canonicalCommand == right.canonicalCommand &&
      left.before == right.before &&
      left.after == right.after &&
      left.commitOrdinal == right.commitOrdinal;

  static bool _sameDescriptor(_Descriptor left, _Descriptor right) =>
      left.sectionId == right.sectionId &&
      left.kind == right.kind &&
      left.contentRevision == right.contentRevision &&
      left.policyRevision == right.policyRevision &&
      left.thresholdPercent == right.thresholdPercent &&
      left.fingerprint == right.fingerprint;

  static bool _samePlayback(
    SentenceHuntPlaybackObservation left,
    SentenceHuntPlaybackObservation right,
  ) =>
      left.scope == right.scope &&
      left.content == right.content &&
      left.runGeneration == right.runGeneration &&
      left.round == right.round &&
      left.uiGeneration == right.uiGeneration &&
      left.referenceId == right.referenceId &&
      left.outcome == right.outcome &&
      left.source == right.source;

  static bool _sameList(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  static Map<String, Object?> _object(Object? value, String name) {
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw FormatException('$name must be an object with string keys.');
    }
    return Map<String, Object?>.from(value);
  }

  static void _exactKeys(
    Map<String, Object?> value,
    List<String> expected,
    String name,
  ) {
    if (value.length != expected.length ||
        value.keys.any((key) => !expected.contains(key)) ||
        expected.any((key) => !value.containsKey(key))) {
      throw FormatException('$name has missing or unknown fields.');
    }
  }

  static String _text(Object? value, String name) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$name must be nonblank text.');
    }
    return value;
  }

  static int _integer(Object? value, String name) {
    if (value is! int || value < 0 || value > sentenceHuntMaxSafeInteger) {
      throw FormatException('$name must be a safe integer.');
    }
    return value;
  }

  static int _positive(Object? value, String name) {
    final result = _integer(value, name);
    if (result == 0) throw FormatException('$name must be positive.');
    return result;
  }

  static List<String> _stringList(
    Object? value,
    String name, {
    bool unique = false,
  }) {
    if (value is! List) throw FormatException('$name must be an array.');
    final result = <String>[];
    final seen = <String>{};
    for (final entry in value) {
      final text = _text(entry, name);
      if (unique && !seen.add(text)) {
        throw FormatException('$name has duplicates.');
      }
      result.add(text);
    }
    return result;
  }

  static String _canonicalJson(Object? value) =>
      jsonEncode(_canonicalValue(value));

  static Object? _canonicalValue(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return <String, Object?>{
        for (final key in keys) key: _canonicalValue(value[key]),
      };
    }
    if (value is List) return [for (final item in value) _canonicalValue(item)];
    return value;
  }

  static bool _sha256(String value) =>
      RegExp(r'^[0-9a-f]{64}$').hasMatch(value);
}

final class _Descriptor {
  const _Descriptor({
    required this.sectionId,
    required this.kind,
    required this.contentRevision,
    required this.policyRevision,
    required this.thresholdPercent,
    required this.fingerprint,
    required this.items,
  });
  final String sectionId;
  final String kind;
  final int contentRevision;
  final int policyRevision;
  final int thresholdPercent;
  final String fingerprint;
  final List<_ItemDescriptor> items;
}

final class _ItemDescriptor {
  const _ItemDescriptor({
    required this.identity,
    required this.selectableTokenIds,
    required this.expectedTokenIds,
  });

  final SentenceHuntContentIdentity identity;
  final List<String> selectableTokenIds;
  final List<String> expectedTokenIds;
}

final class _ReceiptProof {
  const _ReceiptProof(this.receipt, this.command);
  final SentenceHuntReceipt receipt;
  final domain.SentenceHuntLearningCommand command;
}
