import 'dart:convert';
import 'course_attempt.dart';
import 'course_learning_command.dart';
import 'course_learning_error.dart';
import 'course_learning_state.dart';

class LearningDocumentCodec {
  const LearningDocumentCodec();
  String encode(CourseLearningState state) => jsonEncode({
        'schemaVersion': 2,
        'courseId': state.scope.courseId,
        'owner': state.scope.owner.isGuest
            ? {'kind': 'guest'}
            : {'kind': 'account', 'userId': state.scope.owner.userId},
        'revision': state.revision,
        'commitOrdinal': state.commitOrdinal,
        'history': state.history
            .map((b) => {
                  'activityId': b.activityId,
                  'generation': b.generation,
                  'sequence': b.sequence,
                  'token': b.token,
                  'canonicalCommand': b.canonicalCommand,
                  'attempts': b.attempts.map(_attempt).toList()
                })
            .toList(),
        'activities': <Object>[],
        'mistakes': <Object>[],
        'summaries': <Object>[],
        'completions': <Object>[],
        'bestScores': <String, int>{},
        'pending': <Object>[]
      });
  CourseLearningState decode(String raw, LearningScope expectedScope) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map)
        throw const FormatException('document must be an object');
      final m = Map<String, Object?>.from(decoded);
      final version = _int(m['schemaVersion'], 'schemaVersion');
      if (version != 2) throw LearningUnsupportedVersionException();
      final om = _map(m['owner'], 'owner');
      final owner = om['kind'] == 'guest'
          ? LearningOwner.guest()
          : om['kind'] == 'account' && om['userId'] is String
              ? LearningOwner.account(om['userId'] as String)
              : throw const FormatException('invalid owner');
      final scope = LearningScope(
          courseId: _str(m['courseId'], 'courseId'), owner: owner);
      if (scope != expectedScope) throw const FormatException('scope mismatch');
      final history = <AttemptBatch>[];
      for (final b0 in _list(m['history'], 'history')) {
        final b = _map(b0, 'batch');
        history.add(AttemptBatch(
            activityId: _str(b['activityId'], 'activityId'),
            generation: _int(b['generation'], 'generation'),
            sequence: _int(b['sequence'], 'sequence'),
            token: _str(b['token'], 'token'),
            canonicalCommand: _str(b['canonicalCommand'], 'canonicalCommand'),
            attempts: _list(b['attempts'], 'attempts')
                .map((a) => _readAttempt(_map(a, 'attempt'), scope))
                .toList()));
      }
      if (_list(m['activities'], 'activities').isNotEmpty ||
          _list(m['mistakes'], 'mistakes').isNotEmpty ||
          _list(m['summaries'], 'summaries').isNotEmpty ||
          _list(m['completions'], 'completions').isNotEmpty ||
          _list(m['pending'], 'pending').isNotEmpty ||
          _map(m['bestScores'], 'bestScores').isNotEmpty)
        throw const FormatException('unsupported nonempty section in codec');
      return CourseLearningState(
          scope: scope,
          revision: _int(m['revision'], 'revision'),
          commitOrdinal: _int(m['commitOrdinal'], 'commitOrdinal'),
          history: history,
          activities: const {},
          mistakes: const {},
          summaries: const {},
          completions: const [],
          bestScores: const {},
          pending: const []);
    } on LearningUnsupportedVersionException {
      rethrow;
    } on LearningCorruptException {
      rethrow;
    } catch (e) {
      throw LearningCorruptException(e);
    }
  }

  String canonicalCommand(LearningCommand c) => jsonEncode({
        'scope': c.scope.storageKey,
        'generation': c.authGeneration,
        'activity': c.activityId,
        'cursor': [
          c.expected.generation,
          c.expected.sequence,
          c.expected.revision
        ],
        'token': c.token,
        'submittedAt': c.submittedAt.toUtc().toIso8601String(),
        'action': c.action.runtimeType.toString(),
        'draws': c.draws.map((d) => [d.upperBound, d.value]).toList(),
        'candidate': c.candidate.runtimeType.toString(),
        'feedback': [
          c.feedback.message,
          c.feedback.points,
          c.feedback.cascades,
          c.feedback.bonus,
          c.feedback.correct
        ]
      });
  Map<String, Object?> _attempt(CourseAttempt a) => {
        'submissionId': a.submissionId,
        'activityId': a.activityId,
        'runGeneration': a.runGeneration,
        'commandSequence': a.commandSequence,
        'batchIndex': a.batchIndex,
        'itemId': a.itemId,
        'itemOccurrence': a.itemOccurrence,
        'contentRevision': a.contentRevision,
        'commitOrdinal': a.commitOrdinal,
        'answeredAt': a.answeredAt.toUtc().toIso8601String(),
        'committedAt': a.committedAt.toUtc().toIso8601String(),
        'skill': a.skill.name,
        'targetSounds': a.targetSounds,
        'answer': _answer(a.answer),
        'origin': a.origin.name,
        'presentation': a.presentation.name,
        'assistance': a.assistance.map((e) => e.name).toList()..sort(),
        'contentState': a.contentState.name,
        'audioSource': a.audioSource.name,
        'correct': a.correct
      };
  Map<String, Object?> _answer(AttemptAnswer a) => switch (a) {
        SoundChoiceAnswer x => {
            'answerKind': 'soundChoice',
            'selectedSound': x.selectedSound,
            'choices': x.choices,
            'expectedSound': x.expectedSound
          },
        DrillChoiceAnswer x => {
            'answerKind': 'drillChoice',
            'selectedWord': x.selectedWord,
            'pairId': x.pairId,
            'choices': x.choices,
            'expectedWord': x.expectedWord
          },
        SoundCueAnswer x => {
            'answerKind': 'soundCue',
            'selectedFamily': x.selectedFamily,
            'wordId': x.wordId,
            'expectedFamily': x.expectedFamily
          },
        WordTileAnswer x => {
            'answerKind': 'wordTile',
            'wordId': x.wordId,
            'tileIndex': x.tileIndex,
            'targetSound': x.targetSound,
            'expectedMembership': x.expectedMembership
          }
      };
  CourseAttempt _readAttempt(Map<String, Object?> m, LearningScope s) {
    final a = _map(m['answer'], 'answer');
    final kind = _str(a['answerKind'], 'answerKind');
    AttemptAnswer ans = switch (kind) {
      'soundChoice' => SoundChoiceAnswer(
          selectedSound: _str(a['selectedSound'], 'selectedSound'),
          choices: _strings(a['choices'], 'choices'),
          expectedSound: _str(a['expectedSound'], 'expectedSound')),
      'drillChoice' => DrillChoiceAnswer(
          selectedWord: _str(a['selectedWord'], 'selectedWord'),
          pairId: _str(a['pairId'], 'pairId'),
          choices: _strings(a['choices'], 'choices'),
          expectedWord: _str(a['expectedWord'], 'expectedWord')),
      'soundCue' => SoundCueAnswer(
          selectedFamily: _str(a['selectedFamily'], 'selectedFamily'),
          wordId: _str(a['wordId'], 'wordId'),
          expectedFamily: _str(a['expectedFamily'], 'expectedFamily')),
      'wordTile' => WordTileAnswer(
          wordId: _str(a['wordId'], 'wordId'),
          tileIndex: _int(a['tileIndex'], 'tileIndex'),
          targetSound: _str(a['targetSound'], 'targetSound'),
          expectedMembership:
              _bool(a['expectedMembership'], 'expectedMembership')),
      _ => throw const FormatException('unknown answer kind')
    };
    T en<T extends Enum>(List<T> values, Object? v, String key) =>
        values.firstWhere((e) => e.name == v,
            orElse: () => throw FormatException('invalid $key'));
    return CourseAttempt(
        scope: s,
        submissionId: _str(m['submissionId'], 'submissionId'),
        activityId: _str(m['activityId'], 'activityId'),
        runGeneration: _int(m['runGeneration'], 'runGeneration'),
        commandSequence: _int(m['commandSequence'], 'commandSequence'),
        batchIndex: _int(m['batchIndex'], 'batchIndex'),
        itemId: _str(m['itemId'], 'itemId'),
        itemOccurrence: _int(m['itemOccurrence'], 'itemOccurrence'),
        contentRevision: _int(m['contentRevision'], 'contentRevision'),
        commitOrdinal: _int(m['commitOrdinal'], 'commitOrdinal'),
        answeredAt: _date(m['answeredAt'], 'answeredAt'),
        committedAt: _date(m['committedAt'], 'committedAt'),
        skill: en(LearningSkill.values, m['skill'], 'skill'),
        targetSounds: _strings(m['targetSounds'], 'targetSounds'),
        answer: ans,
        origin: en(AttemptOrigin.values, m['origin'], 'origin'),
        presentation:
            en(AttemptPresentation.values, m['presentation'], 'presentation'),
        assistance: _strings(m['assistance'], 'assistance')
            .map((x) => en(AssistanceFlag.values, x, 'assistance'))
            .toSet(),
        contentState:
            en(AttemptContentState.values, m['contentState'], 'contentState'),
        audioSource:
            en(AttemptAudioSource.values, m['audioSource'], 'audioSource'),
        correct: _bool(m['correct'], 'correct'));
  }

  static int _int(Object? v, String n) => v is int && v >= 0
      ? v
      : throw FormatException('$n must be nonnegative integer');
  static String _str(Object? v, String n) => v is String && v.trim().isNotEmpty
      ? v
      : throw FormatException('$n must be nonempty string');
  static bool _bool(Object? v, String n) =>
      v is bool ? v : throw FormatException('$n must be bool');
  static DateTime _date(Object? v, String n) {
    if (v is! String) throw FormatException('$n must be timestamp');
    final d = DateTime.tryParse(v);
    if (d == null) throw FormatException('$n invalid timestamp');
    return d.toUtc();
  }

  static Map<String, Object?> _map(Object? v, String n) =>
      v is Map && v.keys.every((x) => x is String)
          ? Map<String, Object?>.from(v)
          : throw FormatException('$n must be object');
  static List _list(Object? v, String n) =>
      v is List ? v : throw FormatException('$n must be list');
  static List<String> _strings(Object? v, String n) =>
      _list(v, n).map((x) => _str(x, n)).toList();
}
