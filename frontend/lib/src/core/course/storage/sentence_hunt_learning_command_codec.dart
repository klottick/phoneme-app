import 'dart:convert';

import '../course_audio_contract.dart';
import '../learning_storage_types.dart';
import '../lesson_policy.dart';
import '../sentence_hunt_content.dart';
import '../sentence_hunt_learning_command.dart' as domain;
import '../sentence_hunt_learning_state.dart';

/// Scope-bound SQL command identity plus its unchanged legacy domain projection.
final class SentenceHuntCommandCodec {
  const SentenceHuntCommandCodec();

  static String canonicalCommand(domain.SentenceHuntLearningCommand command) =>
      domain.sentenceHuntLearningSqlCanonicalCommand(command);

  static String legacyCanonicalCommand(
    domain.SentenceHuntLearningCommand command,
  ) => domain.sentenceHuntCanonicalCommand(command);

  static domain.SentenceHuntLearningCommand decodeCanonicalCommand(
    String raw, {
    required SentenceHuntProfileScope scope,
    required SentenceHuntCatalogue catalogue,
  }) => _decode(raw, scope: scope, catalogue: catalogue, sqlScoped: true);

  /// Decodes only the domain receipt projection; it is not SQL retry proof.
  static domain.SentenceHuntLearningCommand decodeLegacyCanonicalCommand(
    String raw, {
    required SentenceHuntProfileScope scope,
    required SentenceHuntCatalogue catalogue,
  }) => _decode(raw, scope: scope, catalogue: catalogue, sqlScoped: false);

  static domain.SentenceHuntLearningCommand _decode(
    String raw, {
    required SentenceHuntProfileScope scope,
    required SentenceHuntCatalogue catalogue,
    required bool sqlScoped,
  }) {
    try {
      final value = _object(jsonDecode(raw), 'command');
      _exactKeys(
        value,
        <String>[
          'schemaVersion',
          'family',
          'courseId',
          'owner',
          'authGeneration',
          'sectionId',
          'sectionFingerprint',
          'generation',
          'sequence',
          'revision',
          'token',
          'submittedAt',
          'action',
          if (sqlScoped) 'activityId',
          if (sqlScoped) 'expectedScopeRevision',
        ],
        'command',
        ordered: true,
      );
      final owner = _object(value['owner'], 'command.owner');
      _exactKeys(
        owner,
        const ['kind', 'userId'],
        'command.owner',
        ordered: true,
      );
      final ownerKind = _string(owner['kind'], 'command.owner.kind');
      final Object? rawUserId = owner['userId'];
      final LearningOwner commandOwner;
      if (ownerKind == 'guest' && rawUserId == null) {
        commandOwner = LearningOwner.guest();
      } else if (ownerKind == 'account' && rawUserId is String) {
        commandOwner = LearningOwner.account(
          _nonblank(rawUserId, 'command.owner.userId'),
        );
      } else {
        throw const FormatException('Invalid command owner.');
      }
      if (commandOwner != scope.owner ||
          _integer(value['schemaVersion'], 'command.schemaVersion') != 1 ||
          _string(value['family'], 'command.family') != 'sentence-hunt' ||
          _string(value['courseId'], 'command.courseId') != scope.courseId) {
        throw const FormatException('Command profile mismatch.');
      }

      final sectionId = _nonblank(value['sectionId'], 'command.sectionId');
      final fingerprint = _nonblank(
        value['sectionFingerprint'],
        'command.sectionFingerprint',
      );
      final activityId = sqlScoped
          ? _nonblank(value['activityId'], 'command.activityId')
          : sectionId;
      if (activityId != sectionId ||
          !_knownFingerprint(catalogue, sectionId, fingerprint)) {
        throw const FormatException('Unknown command content identity.');
      }
      final action = _readAction(
        value['action'],
        scope: scope,
        sectionId: sectionId,
        fingerprint: fingerprint,
        catalogue: catalogue,
      );
      final command = domain.SentenceHuntLearningCommand(
        scope: scope,
        authGeneration: _integer(value['authGeneration'], 'authGeneration'),
        sectionId: sectionId,
        sectionFingerprint: fingerprint,
        expected: LearningCursorPosition(
          generation: _integer(value['generation'], 'generation'),
          sequence: _integer(value['sequence'], 'sequence'),
          revision: _integer(value['revision'], 'revision'),
        ),
        expectedScopeRevision: sqlScoped
            ? _integer(value['expectedScopeRevision'], 'expectedScopeRevision')
            : 0,
        token: _nonblank(value['token'], 'command.token'),
        submittedAt: _utc(value['submittedAt'], 'submittedAt'),
        action: action,
      );
      final canonical = sqlScoped
          ? canonicalCommand(command)
          : legacyCanonicalCommand(command);
      if (canonical != raw) {
        throw const FormatException('Noncanonical sentence-hunt command.');
      }
      return command;
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Invalid sentence-hunt command: $error');
    }
  }

  static domain.SentenceHuntAction _readAction(
    Object? raw, {
    required SentenceHuntProfileScope scope,
    required String sectionId,
    required String fingerprint,
    required SentenceHuntCatalogue catalogue,
  }) {
    final action = _object(raw, 'command.action');
    final kind = _string(action['kind'], 'action.kind');
    switch (kind) {
      case 'start':
        _exactKeys(
          action,
          const ['kind', 'sessionId', 'policy', 'mode', 'replaceExisting'],
          'action',
          ordered: true,
        );
        final policy = _readPolicy(action['policy'], 'action.policy');
        if (policy.completionThresholdPercent !=
            _thresholdForFingerprint(catalogue, sectionId, fingerprint)) {
          throw const FormatException('Start policy differs from content.');
        }
        return domain.StartSentenceHuntRun(
          sessionId: _nonblank(action['sessionId'], 'action.sessionId'),
          policy: policy,
          mode: _enum(
            SentenceHuntRunMode.values,
            action['mode'],
            'action.mode',
          ),
          replaceExisting: _boolean(
            action['replaceExisting'],
            'action.replaceExisting',
          ),
        );
      case 'answer':
        _exactKeys(
          action,
          const [
            'kind',
            'content',
            'selectedTokenIds',
            'expectedTokenIdsSnapshot',
            'playback',
          ],
          'action',
          ordered: true,
        );
        final identity = _readContent(action['content']);
        final selected = _stringList(
          action['selectedTokenIds'],
          'action.selectedTokenIds',
          unique: true,
        );
        final expected = _stringList(
          action['expectedTokenIdsSnapshot'],
          'action.expectedTokenIdsSnapshot',
          unique: true,
        );
        final playback = _readPlayback(action['playback'], scope);
        final answer = domain.SentenceHuntAnswer(
          content: identity,
          selectedTokenIds: selected,
          expectedTokenIdsSnapshot: expected,
          playback: playback,
        );
        _validateAnswer(
          answer,
          scope: scope,
          sectionId: sectionId,
          fingerprint: fingerprint,
          catalogue: catalogue,
        );
        return domain.AnswerSentenceHuntItem(answer);
      case 'advance':
        _exactKeys(action, const ['kind'], 'action', ordered: true);
        return const domain.AdvanceSentenceHuntItem();
      case 'review':
        _exactKeys(action, const ['kind'], 'action', ordered: true);
        return const domain.ReviewSentenceHuntMistakes();
      case 'finish':
        _exactKeys(action, const ['kind'], 'action', ordered: true);
        return const domain.FinishSentenceHuntRun();
      default:
        throw const FormatException('Unknown sentence-hunt action.');
    }
  }

  static void _validateAnswer(
    domain.SentenceHuntAnswer answer, {
    required SentenceHuntProfileScope scope,
    required String sectionId,
    required String fingerprint,
    required SentenceHuntCatalogue catalogue,
  }) {
    final item = _itemForFingerprint(
      catalogue,
      sectionId,
      fingerprint,
      answer.content,
    );
    if (item == null ||
        answer.content.sectionId != sectionId ||
        !_sameList(answer.expectedTokenIdsSnapshot, item.expectedTokenIds) ||
        !_sameList(
          _canonicalSelection(item.selectableTokenIds, answer.selectedTokenIds),
          answer.selectedTokenIds,
        )) {
      throw const FormatException(
        'Answer is not registered canonical content.',
      );
    }
    final playback = answer.playback;
    if (playback.scope != scope ||
        playback.content != answer.content ||
        playback.referenceId != answer.content.audioRefId ||
        playback.outcome != CourseAudioOutcome.completed ||
        playback.source != CourseAudioSource.reviewedRecording) {
      throw const FormatException('Answer playback facts are invalid.');
    }
  }

  static SentenceHuntPlaybackObservation _readPlayback(
    Object? raw,
    SentenceHuntProfileScope scope,
  ) {
    final value = _object(raw, 'playback');
    _exactKeys(
      value,
      const [
        'referenceId',
        'outcome',
        'source',
        'runGeneration',
        'round',
        'uiGeneration',
        'content',
      ],
      'playback',
      ordered: true,
    );
    return SentenceHuntPlaybackObservation(
      scope: scope,
      content: _readContent(value['content']),
      runGeneration: _positive(
        value['runGeneration'],
        'playback.runGeneration',
      ),
      round: _positive(value['round'], 'playback.round'),
      uiGeneration: _integer(value['uiGeneration'], 'playback.uiGeneration'),
      referenceId: _nonblank(value['referenceId'], 'playback.referenceId'),
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

  static SentenceHuntContentIdentity _readContent(Object? raw) {
    final value = _object(raw, 'content');
    _exactKeys(
      value,
      const [
        'sectionId',
        'itemId',
        'sentenceId',
        'audioRefId',
        'annotationHash',
        'contentRevision',
        'annotationRevision',
      ],
      'content',
      ordered: true,
    );
    return SentenceHuntContentIdentity(
      sectionId: _nonblank(value['sectionId'], 'content.sectionId'),
      itemId: _nonblank(value['itemId'], 'content.itemId'),
      sentenceId: _nonblank(value['sentenceId'], 'content.sentenceId'),
      audioRefId: _nonblank(value['audioRefId'], 'content.audioRefId'),
      annotationHash: _nonblank(
        value['annotationHash'],
        'content.annotationHash',
      ),
      contentRevision: _positive(
        value['contentRevision'],
        'content.contentRevision',
      ),
      annotationRevision: _positive(
        value['annotationRevision'],
        'content.annotationRevision',
      ),
    );
  }

  static bool _knownFingerprint(
    SentenceHuntCatalogue catalogue,
    String sectionId,
    String fingerprint,
  ) =>
      catalogue.sections.any(
        (section) =>
            section.id == sectionId &&
            section.sectionFingerprint == fingerprint,
      ) ||
      catalogue.historicalSections.any(
        (section) =>
            section.sectionId == sectionId &&
            section.sectionFingerprint == fingerprint,
      );

  static int _thresholdForFingerprint(
    SentenceHuntCatalogue catalogue,
    String sectionId,
    String fingerprint,
  ) {
    for (final section in catalogue.sections) {
      if (section.id == sectionId &&
          section.sectionFingerprint == fingerprint) {
        return section.policy.completionThresholdPercent;
      }
    }
    for (final historical in catalogue.historicalSections) {
      if (historical.sectionId == sectionId &&
          historical.sectionFingerprint == fingerprint) {
        return historical.completionThresholdPercent;
      }
    }
    throw const FormatException('Unknown section fingerprint.');
  }

  static _CommandItem? _itemForFingerprint(
    SentenceHuntCatalogue catalogue,
    String sectionId,
    String fingerprint,
    SentenceHuntContentIdentity identity,
  ) {
    for (final section in catalogue.sections) {
      if (section.id == sectionId &&
          section.sectionFingerprint == fingerprint) {
        for (final item in section.items) {
          if (item.identity == identity) {
            return _CommandItem(
              identity: item.identity,
              selectableTokenIds: item.selectableTokenIds,
              expectedTokenIds: item.expectedTokenIds,
            );
          }
        }
        return null;
      }
    }
    final historical = catalogue.historicalSections.where(
      (section) =>
          section.sectionId == sectionId &&
          section.sectionFingerprint == fingerprint,
    );
    if (historical.length != 1) return null;
    final root = _object(jsonDecode(fingerprint), 'section fingerprint');
    final rows = root['items'];
    if (rows is! List) return null;
    for (final rawItem in rows) {
      final value = _object(rawItem, 'fingerprint item');
      final rawTokens = value['tokens'];
      if (rawTokens is! List) return null;
      final itemIdentity = SentenceHuntContentIdentity(
        sectionId: sectionId,
        itemId: _nonblank(value['id'], 'fingerprint.id'),
        sentenceId: _nonblank(value['sentenceId'], 'fingerprint.sentenceId'),
        audioRefId: _nonblank(value['audioRefId'], 'fingerprint.audioRefId'),
        annotationHash: _nonblank(
          value['annotationHash'],
          'fingerprint.annotationHash',
        ),
        contentRevision: _positive(
          value['contentRevision'] ?? historical.single.contentRevision,
          'fingerprint.contentRevision',
        ),
        annotationRevision: _positive(
          value['annotationRevision'],
          'fingerprint.annotationRevision',
        ),
      );
      // Fingerprint items do not repeat the section revision.
      final correctedIdentity = SentenceHuntContentIdentity(
        sectionId: itemIdentity.sectionId,
        itemId: itemIdentity.itemId,
        sentenceId: itemIdentity.sentenceId,
        audioRefId: itemIdentity.audioRefId,
        annotationHash: itemIdentity.annotationHash,
        contentRevision: historical.single.contentRevision,
        annotationRevision: itemIdentity.annotationRevision,
      );
      final selectable = <String>[];
      for (final rawToken in rawTokens) {
        final token = _object(rawToken, 'fingerprint token');
        selectable.add(_nonblank(token['id'], 'token.id'));
      }
      final expected = _stringList(
        value['expectedTokenIds'],
        'expectedTokenIds',
        unique: true,
      );
      if (correctedIdentity == identity) {
        return _CommandItem(
          identity: correctedIdentity,
          selectableTokenIds: selectable,
          expectedTokenIds: expected,
        );
      }
    }
    return null;
  }
}

final class _CommandItem {
  const _CommandItem({
    required this.identity,
    required this.selectableTokenIds,
    required this.expectedTokenIds,
  });
  final SentenceHuntContentIdentity identity;
  final List<String> selectableTokenIds;
  final List<String> expectedTokenIds;
}

List<String> _canonicalSelection(
  List<String> selectable,
  List<String> selected,
) {
  final requested = <String>{};
  for (final id in selected) {
    if (!selectable.contains(id) || !requested.add(id)) {
      throw const FormatException(
        'Selection contains unknown or duplicate IDs.',
      );
    }
  }
  return [
    for (final id in selectable)
      if (requested.contains(id)) id,
  ];
}

Map<String, Object?> _object(Object? value, String name) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException('$name must be a string-keyed object.');
  }
  return Map<String, Object?>.from(value);
}

void _exactKeys(
  Map<String, Object?> value,
  List<String> expected,
  String name, {
  bool ordered = false,
}) {
  if (value.length != expected.length ||
      value.keys.any((key) => !expected.contains(key)) ||
      expected.any((key) => !value.containsKey(key)) ||
      (ordered && !_sameList(value.keys.toList(), expected))) {
    throw FormatException(
      '$name has missing, unknown, or out-of-order fields.',
    );
  }
}

String _string(Object? value, String name) {
  if (value is! String) throw FormatException('$name must be text.');
  return value;
}

String _nonblank(Object? value, String name) {
  final text = _string(value, name);
  if (text.trim().isEmpty) throw FormatException('$name must not be blank.');
  return text;
}

int _integer(Object? value, String name) {
  if (value is! int || value < 0 || value > sentenceHuntMaxSafeInteger) {
    throw FormatException('$name must be a safe nonnegative integer.');
  }
  return value;
}

int _positive(Object? value, String name) {
  final integer = _integer(value, name);
  if (integer == 0) throw FormatException('$name must be positive.');
  return integer;
}

bool _boolean(Object? value, String name) {
  if (value is! bool) throw FormatException('$name must be a boolean.');
  return value;
}

List<String> _stringList(Object? value, String name, {bool unique = false}) {
  if (value is! List) throw FormatException('$name must be a list.');
  final result = <String>[];
  final seen = <String>{};
  for (final entry in value) {
    final text = _nonblank(entry, name);
    if (unique && !seen.add(text)) {
      throw FormatException('$name has duplicates.');
    }
    result.add(text);
  }
  return result;
}

LessonPolicy _readPolicy(Object? value, String name) {
  final policy = _object(value, name);
  _exactKeys(policy, const ['completionThresholdPercent'], name, ordered: true);
  return LessonPolicy.fromJson(Map<String, dynamic>.from(policy));
}

T _enum<T extends Enum>(List<T> values, Object? value, String name) {
  final text = _nonblank(value, name);
  for (final variant in values) {
    if (variant.name == text) return variant;
  }
  throw FormatException('$name has an unknown value.');
}

DateTime _utc(Object? value, String name) {
  final text = _nonblank(value, name);
  final date = DateTime.tryParse(text);
  if (date == null || !date.isUtc || date.toIso8601String() != text) {
    throw FormatException('$name must be canonical UTC ISO-8601.');
  }
  return date;
}

bool _sameList(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
