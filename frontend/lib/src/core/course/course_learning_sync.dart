import 'course_attempt.dart';
import 'course_learning_command.dart';
import 'course_learning_state.dart';
import 'course_learning_transition.dart';

abstract class LearningCloudTransport {
  Future<void> send(List<SupportedCloudEvent> events);
}

enum SupportedSyncStatus { guest, synced, pending, ownerChanged }

class SupportedSyncResult {
  const SupportedSyncResult(
      {required this.status, required this.remainingEvents});
  final SupportedSyncStatus status;
  final int remainingEvents;
}

class SupportedProgressProjector {
  const SupportedProgressProjector();

  static const _activities = <String, String>{
    'lesson:en-fr-vowels': 'l0',
    'lesson:en-fr-u-y': 'l1',
    'lesson:en-fr-nasal': 'l2',
    'lesson:en-fr-r': 'l3',
    'lesson:en-fr-mix': 'l4',
    'drill:minimal-pairs': 'd0',
    'arcade:sound': 'gs',
    'arcade:word': 'gw',
  };

  List<SupportedCloudEvent> project({
    required CourseLearningState before,
    required LearningTransition transition,
    required LearningCommand command,
  }) {
    if (before.scope.owner.isGuest || before.scope.courseId != 'en-fr') {
      return const [];
    }
    final userId = before.scope.owner.userId!;
    final activityCode = _activities[command.activityId];
    if (activityCode == null) return const [];
    final generation = transition.slot.cursor.generation;
    final sequence = transition.slot.cursor.sequence;
    _portable(generation);
    _portable(sequence);
    final events = <SupportedCloudEvent>[];
    for (var i = 0; i < transition.attempts.length; i++) {
      final attempt = transition.attempts[i];
      final sound =
          attempt.targetSounds.isEmpty ? null : attempt.targetSounds.first;
      if (sound != null) {
        events.add(_event(
            userId,
            before.scope.courseId,
            _id(activityCode, generation, sequence, command.token, 'a$i'),
            CloudAnswer(
                sound: sound,
                skill: attempt.skill,
                correct: attempt.correct,
                activity: command.activityId)));
      }
    }
    final priorCompletionKeys = before.completions.map(_completionKey).toSet();
    for (final completion in transition.completions) {
      if (!priorCompletionKeys.contains(_completionKey(completion)) &&
          const {
            'en-fr-vowels',
            'en-fr-u-y',
            'en-fr-nasal',
            'en-fr-r',
            'en-fr-mix'
          }.contains(completion.lessonId)) {
        final index = const [
          'en-fr-vowels',
          'en-fr-u-y',
          'en-fr-nasal',
          'en-fr-r',
          'en-fr-mix'
        ].indexOf(completion.lessonId);
        events.add(_event(
            userId,
            before.scope.courseId,
            _id('l$index', generation, sequence, command.token, 'l0'),
            CloudLesson(lessonId: completion.lessonId)));
      }
    }
    for (final entry in transition.bestScores.entries) {
      if (entry.value <= (before.bestScores[entry.key] ?? 0)) continue;
      final game = switch (entry.key) {
        'arcade:sound' => 'sound',
        'arcade:word' => 'word',
        _ => null,
      };
      if (game != null) {
        _portable(entry.value);
        events.add(_event(
            userId,
            before.scope.courseId,
            _id(game == 'sound' ? 'gs' : 'gw', generation, sequence,
                command.token, 's0'),
            CloudScore(game: game, score: entry.value)));
      }
    }
    return List.unmodifiable(events);
  }

  SupportedCloudEvent _event(String user, String course, String id,
          SupportedCloudPayload payload) =>
      SupportedCloudEvent(
          id: id, userId: user, courseId: course, payload: payload);

  String _id(String activity, int generation, int sequence, String token,
      String member) {
    final value =
        'fr04.c0.$activity.${generation.toRadixString(36)}.${sequence.toRadixString(36)}.$token.$member';
    if (value.length >= 128) {
      throw ArgumentError('Supported event ID is too long.');
    }
    return value;
  }

  String _completionKey(LearningCompletion x) =>
      '${x.lessonId}\u0000${x.contentRevision}\u0000${x.policyKind.name}\u0000${x.policyRevision}\u0000${x.thresholdPercent}';

  void _portable(int value) {
    if (value < 0 || value > 9007199254740991) {
      throw ArgumentError('Counter exceeds portable integer range.');
    }
  }
}

class SupportedProgressSync {
  SupportedProgressSync({
    required this.scope,
    required this.authGeneration,
    required this.transport,
    required this.readPending,
    required this.acknowledge,
    required this.isCurrent,
  });
  final LearningScope scope;
  final int authGeneration;
  final LearningCloudTransport transport;
  final Future<List<SupportedCloudEvent>> Function() readPending;
  final Future<void> Function(Set<String> ids) acknowledge;
  final bool Function() isCurrent;
  static final Map<String, Future<SupportedSyncResult>> _running = {};

  Future<SupportedSyncResult> run() {
    final key = scope.storageKey;
    final existing = _running[key];
    if (existing != null) return existing;
    final result = _run();
    _running[key] = result;
    result.then<void>((_) => _running.remove(key),
        onError: (Object _, StackTrace __) => _running.remove(key));
    return result;
  }

  Future<SupportedSyncResult> _run() async => SupportedSyncResult(
      status: isCurrent()
          ? SupportedSyncStatus.pending
          : SupportedSyncStatus.ownerChanged,
      remainingEvents: (await readPending()).length);
}
