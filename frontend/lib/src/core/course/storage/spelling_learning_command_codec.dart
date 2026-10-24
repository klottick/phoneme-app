import 'dart:convert';

import '../course_audio_contract.dart';
import '../course_attempt.dart';
import '../french_uy_demo_spelling_content.dart';
import '../lesson_policy.dart';
import '../spelling_learning_command.dart';
import '../spelling_learning_state.dart';

final class SpellingLearningCommandCodec {
  const SpellingLearningCommandCodec();

  String encode(SpellingLearningCommand command) {
    _validateCommand(command, loadFrenchUyDemoSpellingCatalogue());
    final action = _actionJson(command.action);
    return jsonEncode(<String, Object?>{
      'version': 1,
      'scope': _scopeJson(command.scope),
      'authGeneration': command.authGeneration,
      'activityId': command.activityId,
      'expected': <String, Object?>{
        'generation': command.expected.generation,
        'sequence': command.expected.sequence,
        'revision': command.expected.revision,
      },
      'expectedScopeRevision': command.expectedScopeRevision,
      'token': command.token,
      'submittedAt': command.submittedAt.toIso8601String(),
      'action': action,
    });
  }

  SpellingLearningCommand decode(String canonicalJson) {
    try {
      final root = _object(jsonDecode(canonicalJson), 'command');
      _exactKeys(root, const [
        'version',
        'scope',
        'authGeneration',
        'activityId',
        'expected',
        'expectedScopeRevision',
        'token',
        'submittedAt',
        'action',
      ], 'command');
      if (_integer(root['version'], 'version') != 1) {
        throw const FormatException('Unsupported spelling command version.');
      }
      final scope = _readScope(root['scope'], 'scope');
      final expected = _object(root['expected'], 'expected');
      _exactKeys(expected, const [
        'generation',
        'sequence',
        'revision',
      ], 'expected');
      final action = _readAction(root['action']);
      final command = SpellingLearningCommand(
        scope: scope,
        authGeneration: _integer(root['authGeneration'], 'authGeneration'),
        activityId: _text(root['activityId'], 'activityId'),
        expected: SpellingCursor(
          generation: _integer(expected['generation'], 'expected.generation'),
          sequence: _integer(expected['sequence'], 'expected.sequence'),
          revision: _integer(expected['revision'], 'expected.revision'),
        ),
        expectedScopeRevision: _integer(
          root['expectedScopeRevision'],
          'expectedScopeRevision',
        ),
        token: _text(root['token'], 'token'),
        submittedAt: _utc(root['submittedAt'], 'submittedAt'),
        action: action,
      );
      _validateCommand(command, loadFrenchUyDemoSpellingCatalogue());
      if (encode(command) != canonicalJson) {
        throw const FormatException('Spelling command JSON is not canonical.');
      }
      return command;
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Invalid spelling command: $error');
    }
  }

  static Map<String, Object?> _scopeJson(SpellingProfileScope scope) =>
      <String, Object?>{
        'courseId': scope.courseId,
        'owner': <String, Object?>{
          'kind': scope.owner.isGuest ? 'guest' : 'account',
          'id': scope.owner.userId ?? '',
        },
      };

  static Map<String, Object?> _actionJson(SpellingAction action) =>
      switch (action) {
        StartSpellingPractice(:final sessionId, :final policy) =>
          <String, Object?>{
            'kind': 'startPractice',
            'sessionId': sessionId,
            'policy': policy.toJson(),
          },
        AnswerSpellingChoice(
          :final itemId,
          :final contentRevision,
          :final selectedOptionId,
          :final expectedOptionIdSnapshot,
          :final playback,
        ) =>
          <String, Object?>{
            'kind': 'answerChoice',
            'itemId': itemId,
            'contentRevision': contentRevision,
            'selectedOptionId': selectedOptionId,
            'expectedOptionIdSnapshot': expectedOptionIdSnapshot,
            'playback': _playbackJson(playback),
          },
        AdvanceSpellingItem() => <String, Object?>{'kind': 'advanceItem'},
        ReviewSpellingMistakes() => <String, Object?>{'kind': 'reviewMistakes'},
        StartSpellingReviewOnly(:final sessionId) => <String, Object?>{
          'kind': 'startReviewOnly',
          'sessionId': sessionId,
        },
        FinishSpellingRun(:final recordCompletion) => <String, Object?>{
          'kind': 'finishRun',
          'recordCompletion': recordCompletion,
        },
      };

  static Map<String, Object?> _playbackJson(
    SpellingPlaybackObservation playback,
  ) => <String, Object?>{
    'profile': _scopeJson(playback.profile),
    'authGeneration': playback.authGeneration,
    'activityId': playback.activityId,
    'contentRevision': playback.contentRevision,
    'runGeneration': playback.runGeneration,
    'round': playback.round,
    'itemId': playback.itemId,
    'referenceId': playback.referenceId,
    'promptEpoch': playback.promptEpoch,
    'outcome': playback.outcome.name,
    'source': playback.source.name,
  };

  static SpellingAction _readAction(Object? raw) {
    final action = _object(raw, 'action');
    final kind = _text(action['kind'], 'action.kind');
    switch (kind) {
      case 'startPractice':
        _exactKeys(action, const ['kind', 'sessionId', 'policy'], 'action');
        return StartSpellingPractice(
          sessionId: _text(action['sessionId'], 'action.sessionId'),
          policy: _readPolicy(action['policy'], 'action.policy'),
        );
      case 'answerChoice':
        _exactKeys(action, const [
          'kind',
          'itemId',
          'contentRevision',
          'selectedOptionId',
          'expectedOptionIdSnapshot',
          'playback',
        ], 'action');
        return AnswerSpellingChoice(
          itemId: _text(action['itemId'], 'action.itemId'),
          contentRevision: _positive(
            action['contentRevision'],
            'action.contentRevision',
          ),
          selectedOptionId: _text(
            action['selectedOptionId'],
            'action.selectedOptionId',
          ),
          expectedOptionIdSnapshot: _text(
            action['expectedOptionIdSnapshot'],
            'action.expectedOptionIdSnapshot',
          ),
          playback: _readPlayback(action['playback']),
        );
      case 'advanceItem':
        _exactKeys(action, const ['kind'], 'action');
        return const AdvanceSpellingItem();
      case 'reviewMistakes':
        _exactKeys(action, const ['kind'], 'action');
        return const ReviewSpellingMistakes();
      case 'startReviewOnly':
        _exactKeys(action, const ['kind', 'sessionId'], 'action');
        return StartSpellingReviewOnly(
          sessionId: _text(action['sessionId'], 'action.sessionId'),
        );
      case 'finishRun':
        _exactKeys(action, const ['kind', 'recordCompletion'], 'action');
        return FinishSpellingRun(
          recordCompletion: _boolean(
            action['recordCompletion'],
            'action.recordCompletion',
          ),
        );
      default:
        throw const FormatException('Unknown spelling action kind.');
    }
  }

  static SpellingPlaybackObservation _readPlayback(Object? raw) {
    final value = _object(raw, 'playback');
    _exactKeys(value, const [
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
    ], 'playback');
    return SpellingPlaybackObservation(
      profile: _readScope(value['profile'], 'playback.profile'),
      authGeneration: _integer(
        value['authGeneration'],
        'playback.authGeneration',
      ),
      activityId: _text(value['activityId'], 'playback.activityId'),
      contentRevision: _positive(
        value['contentRevision'],
        'playback.contentRevision',
      ),
      runGeneration: _positive(
        value['runGeneration'],
        'playback.runGeneration',
      ),
      round: _positive(value['round'], 'playback.round'),
      itemId: _text(value['itemId'], 'playback.itemId'),
      referenceId: _text(value['referenceId'], 'playback.referenceId'),
      promptEpoch: _integer(value['promptEpoch'], 'playback.promptEpoch'),
      outcome: _enum(
        CourseAudioOutcome.values,
        value['outcome'],
        'playback.outcome',
      ),
      source: _enum(
        CourseAudioSource.values,
        value['source'],
        'playback.source',
      ),
    );
  }

  static SpellingProfileScope _readScope(Object? raw, String name) {
    final value = _object(raw, name);
    _exactKeys(value, const ['courseId', 'owner'], name);
    final owner = _object(value['owner'], '$name.owner');
    _exactKeys(owner, const ['kind', 'id'], '$name.owner');
    final kind = _text(owner['kind'], '$name.owner.kind');
    final id = owner['id'];
    final LearningOwner learningOwner;
    if (kind == 'guest' && id == '') {
      learningOwner = LearningOwner.guest();
    } else if (kind == 'account' && id is String && id.trim().isNotEmpty) {
      learningOwner = LearningOwner.account(id);
    } else {
      throw FormatException('$name.owner is invalid.');
    }
    return SpellingProfileScope(
      courseId: _text(value['courseId'], '$name.courseId'),
      owner: learningOwner,
    );
  }

  static void _validateCommand(
    SpellingLearningCommand command,
    FrenchUyDemoSpellingCatalogue catalogue,
  ) {
    if (command.scope.courseId != 'en-fr' ||
        command.activityId != catalogue.activityId ||
        catalogue.contentRevision != 1) {
      throw const FormatException('Spelling command identity mismatch.');
    }
    switch (command.action) {
      case StartSpellingPractice(:final sessionId, :final policy):
        if (sessionId.trim().isEmpty ||
            policy.completionThresholdPercent != 80) {
          throw const FormatException('Invalid spelling practice start.');
        }
      case AnswerSpellingChoice(
        :final itemId,
        :final contentRevision,
        :final selectedOptionId,
        :final expectedOptionIdSnapshot,
        :final playback,
      ):
        final rows = catalogue.rows.where((row) => row.exercise.id == itemId);
        if (rows.length != 1) {
          throw const FormatException('Answer item is not in the catalogue.');
        }
        final row = rows.single;
        if (contentRevision != catalogue.contentRevision ||
            row.exercise.correctOptionId != expectedOptionIdSnapshot ||
            !row.exercise.options.any(
              (option) => option.id == selectedOptionId,
            ) ||
            playback.profile != command.scope ||
            playback.authGeneration != command.authGeneration ||
            playback.activityId != command.activityId ||
            playback.contentRevision != contentRevision ||
            playback.runGeneration != command.expected.generation ||
            playback.round < 1 ||
            playback.itemId != itemId ||
            playback.referenceId != row.exercise.audioRefId ||
            playback.promptEpoch < 0 ||
            playback.outcome != CourseAudioOutcome.completed ||
            playback.source != CourseAudioSource.unverifiedRecording) {
          throw const FormatException('Spelling answer provenance is invalid.');
        }
      case StartSpellingReviewOnly(:final sessionId):
        if (sessionId.trim().isEmpty) {
          throw const FormatException('Invalid review-only session ID.');
        }
      case AdvanceSpellingItem() ||
          ReviewSpellingMistakes() ||
          FinishSpellingRun():
        break;
    }
  }
}

Map<String, Object?> _object(Object? value, String name) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException('$name must be an object with string keys.');
  }
  return Map<String, Object?>.from(value);
}

void _exactKeys(
  Map<String, Object?> value,
  List<String> expected,
  String name,
) {
  if (value.length != expected.length ||
      value.keys.any((key) => !expected.contains(key)) ||
      expected.any((key) => !value.containsKey(key)) ||
      !_sameOrder(value.keys.toList(), expected)) {
    throw FormatException('$name has missing, extra, or out-of-order fields.');
  }
}

String _text(Object? value, String name) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$name must be nonblank text.');
  }
  return value;
}

int _integer(Object? value, String name) {
  if (value is! int || value < 0 || value > spellingMaxSafeInteger) {
    throw FormatException('$name must be a safe nonnegative integer.');
  }
  return value;
}

int _positive(Object? value, String name) {
  final result = _integer(value, name);
  if (result == 0) throw FormatException('$name must be positive.');
  return result;
}

bool _boolean(Object? value, String name) {
  if (value is! bool) throw FormatException('$name must be a boolean.');
  return value;
}

LessonPolicy _readPolicy(Object? raw, String name) {
  final policy = _object(raw, name);
  _exactKeys(policy, const ['completionThresholdPercent'], name);
  return LessonPolicy.fromJson(Map<String, dynamic>.from(policy));
}

T _enum<T extends Enum>(List<T> values, Object? raw, String name) {
  final value = _text(raw, name);
  for (final entry in values) {
    if (entry.name == value) return entry;
  }
  throw FormatException('$name has an unknown value.');
}

DateTime _utc(Object? raw, String name) {
  final value = _text(raw, name);
  final date = DateTime.tryParse(value);
  if (date == null || !date.isUtc || date.toIso8601String() != value) {
    throw FormatException('$name must be canonical UTC ISO-8601.');
  }
  return date;
}

bool _sameOrder(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
