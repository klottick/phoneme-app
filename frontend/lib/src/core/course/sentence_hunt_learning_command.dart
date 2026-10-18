import 'dart:convert';

import 'course_learning_transaction.dart';
import 'lesson_policy.dart';
import 'sentence_hunt_content.dart';
import 'sentence_hunt_learning_state.dart';

sealed class SentenceHuntAction {
  const SentenceHuntAction();
}

final class StartSentenceHuntRun extends SentenceHuntAction {
  const StartSentenceHuntRun({
    required this.sessionId,
    required this.policy,
    required this.mode,
    this.replaceExisting = false,
  });

  final String sessionId;
  final LessonPolicy policy;
  final SentenceHuntRunMode mode;
  final bool replaceExisting;
}

final class AnswerSentenceHuntItem extends SentenceHuntAction {
  const AnswerSentenceHuntItem(this.answer);

  final SentenceHuntAnswer answer;
}

final class AdvanceSentenceHuntItem extends SentenceHuntAction {
  const AdvanceSentenceHuntItem();
}

final class ReviewSentenceHuntMistakes extends SentenceHuntAction {
  const ReviewSentenceHuntMistakes();
}

final class FinishSentenceHuntRun extends SentenceHuntAction {
  const FinishSentenceHuntRun();
}

final class SentenceHuntAnswer {
  SentenceHuntAnswer({
    required this.content,
    required List<String> selectedTokenIds,
    required List<String> expectedTokenIdsSnapshot,
    required this.playback,
  })  : selectedTokenIds = List<String>.unmodifiable(selectedTokenIds),
        expectedTokenIdsSnapshot =
            List<String>.unmodifiable(expectedTokenIdsSnapshot);

  final SentenceHuntContentIdentity content;
  final List<String> selectedTokenIds;
  final List<String> expectedTokenIdsSnapshot;
  final SentenceHuntPlaybackObservation playback;
}

final class SentenceHuntLearningCommand {
  SentenceHuntLearningCommand({
    required this.scope,
    required int authGeneration,
    required this.sectionId,
    required this.sectionFingerprint,
    required this.expected,
    required this.token,
    required this.submittedAt,
    required this.action,
  }) : authGeneration = sentenceHuntCounter(authGeneration, 'authGeneration') {
    sentenceHuntRequired(sectionId, 'sectionId');
    sentenceHuntRequired(sectionFingerprint, 'sectionFingerprint');
    if (!RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(token) || !submittedAt.isUtc) {
      throw ArgumentError('Invalid sentence-hunt command.');
    }
  }

  final SentenceHuntProfileScope scope;
  final int authGeneration;
  final String sectionId;
  final String sectionFingerprint;
  final LearningCursorPosition expected;
  final String token;
  final DateTime submittedAt;
  final SentenceHuntAction action;
}

/// Ordered canonical JSON for receipt identity. Selection IDs are expected to
/// have been normalized by the registered item in prepare/evaluate first.
String sentenceHuntCanonicalCommand(SentenceHuntLearningCommand command) {
  final SentenceHuntProfileScope scope = command.scope;
  final Map<String, Object?> owner = <String, Object?>{
    'kind': scope.owner.isGuest ? 'guest' : 'account',
    'userId': scope.owner.userId,
  };
  final SentenceHuntAction action = command.action;
  final Map<String, Object?> actionJson = switch (action) {
    StartSentenceHuntRun(
      :final sessionId,
      :final policy,
      :final mode,
      :final replaceExisting
    ) =>
      <String, Object?>{
        'kind': 'start',
        'sessionId': sessionId,
        'policy': policy.toJson(),
        'mode': mode.name,
        'replaceExisting': replaceExisting,
      },
    AnswerSentenceHuntItem(:final answer) => <String, Object?>{
        'kind': 'answer',
        'content': _contentJson(answer.content),
        'selectedTokenIds': answer.selectedTokenIds,
        'expectedTokenIdsSnapshot': answer.expectedTokenIdsSnapshot,
        'playback': _playbackJson(answer.playback),
      },
    AdvanceSentenceHuntItem() => <String, Object?>{'kind': 'advance'},
    ReviewSentenceHuntMistakes() => <String, Object?>{'kind': 'review'},
    FinishSentenceHuntRun() => <String, Object?>{'kind': 'finish'},
  };
  return jsonEncode(<String, Object?>{
    'schemaVersion': 1,
    'family': 'sentence-hunt',
    'courseId': scope.courseId,
    'owner': owner,
    'authGeneration': command.authGeneration,
    'sectionId': command.sectionId,
    'sectionFingerprint': command.sectionFingerprint,
    'generation': command.expected.generation,
    'sequence': command.expected.sequence,
    'revision': command.expected.revision,
    'token': command.token,
    'submittedAt': command.submittedAt.toIso8601String(),
    'action': actionJson,
  });
}

Map<String, Object?> _contentJson(SentenceHuntContentIdentity identity) =>
    <String, Object?>{
      'sectionId': identity.sectionId,
      'itemId': identity.itemId,
      'sentenceId': identity.sentenceId,
      'audioRefId': identity.audioRefId,
      'annotationHash': identity.annotationHash,
      'contentRevision': identity.contentRevision,
      'annotationRevision': identity.annotationRevision,
    };

Map<String, Object?> _playbackJson(SentenceHuntPlaybackObservation o) =>
    <String, Object?>{
      'referenceId': o.referenceId,
      'outcome': o.outcome.name,
      'source': o.source.name,
      'runGeneration': o.runGeneration,
      'round': o.round,
      'uiGeneration': o.uiGeneration,
      'content': _contentJson(o.content),
    };
