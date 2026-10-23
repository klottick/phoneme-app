import 'dart:convert';

import '../comparison_content.dart';
import '../comparison_learning_command.dart' as domain;
import '../comparison_learning_state.dart';
import '../course_audio_contract.dart';
import '../lesson_policy.dart';

/// SQL-scoped command identities and typed receipt translation for comparison.
///
/// SQL receipt bytes include the scope revision; the domain receipt projection
/// deliberately retains the legacy canonical bytes used by the transition
/// engine and preferences-backed store.
final class ComparisonLearningCommandCodec {
  const ComparisonLearningCommandCodec();

  static String canonicalCommand(domain.ComparisonLearningCommand command) =>
      domain.comparisonLearningSqlCanonicalCommand(command);

  static String legacyCanonicalCommand(
    domain.ComparisonLearningCommand command,
  ) => domain.comparisonCanonicalCommand(command);

  static domain.ComparisonLearningCommand decodeCanonicalCommand(
    String raw, {
    required ComparisonProfileScope scope,
    required ComparisonCatalogue catalogue,
  }) => _decode(
    raw,
    scope: scope,
    registry: ComparisonCatalogueRegistry.single(catalogue),
    sqlScoped: true,
  );

  static domain.ComparisonLearningCommand decodeRegisteredCanonicalCommand(
    String raw, {
    required ComparisonProfileScope scope,
    required ComparisonCatalogueRegistry registry,
  }) => _decode(raw, scope: scope, registry: registry, sqlScoped: true);

  /// Decodes the pre-SQL typed projection, which remains the domain state shape.
  /// The value has no scope revision, so it is never used as a SQL receipt proof.
  static domain.ComparisonLearningCommand decodeLegacyCanonicalCommand(
    String raw, {
    required ComparisonProfileScope scope,
    required ComparisonCatalogue catalogue,
  }) => _decode(
    raw,
    scope: scope,
    registry: ComparisonCatalogueRegistry.single(catalogue),
    sqlScoped: false,
  );

  static domain.ComparisonLearningCommand
  decodeRegisteredLegacyCanonicalCommand(
    String raw, {
    required ComparisonProfileScope scope,
    required ComparisonCatalogueRegistry registry,
  }) => _decode(raw, scope: scope, registry: registry, sqlScoped: false);

  static domain.ComparisonLearningCommand _decode(
    String raw, {
    required ComparisonProfileScope scope,
    required ComparisonCatalogueRegistry registry,
    required bool sqlScoped,
  }) {
    try {
      final value = _object(jsonDecode(raw), 'command');
      final expectedKeys = <String>[
        'schemaVersion',
        'family',
        'courseId',
        'owner',
        'authGeneration',
        'activityId',
        'generation',
        'sequence',
        'revision',
        'token',
        'submittedAt',
        'action',
        if (sqlScoped) 'expectedScopeRevision',
      ];
      _exactKeys(value, expectedKeys, 'command', ordered: true);
      final owner = _object(value['owner'], 'command.owner');
      _exactKeys(
        owner,
        const ['kind', 'userId'],
        'command.owner',
        ordered: true,
      );
      final ownerKind = _string(owner['kind'], 'command.owner.kind');
      final ownerId = owner['userId'];
      final decodedOwner = switch (ownerKind) {
        'guest' when ownerId == null =>
          scope.owner.isGuest
              ? scope.owner
              : (throw const FormatException('Command owner mismatch.')),
        'account' when ownerId is String => LearningOwner.account(
          _string(ownerId, 'command.owner.userId'),
        ),
        _ => throw const FormatException('Invalid command owner.'),
      };
      final activityId = _string(value['activityId'], 'activityId');
      final catalogue = registry.requireAvailable(activityId);
      if (decodedOwner != scope.owner ||
          _integer(value['schemaVersion'], 'command.schemaVersion') != 1 ||
          _string(value['family'], 'command.family') != 'comparison' ||
          _string(value['courseId'], 'command.courseId') != scope.courseId ||
          catalogue.activityId != activityId ||
          catalogue.contentRevision < 1) {
        throw const FormatException('Command profile/content mismatch.');
      }

      final command = domain.ComparisonLearningCommand(
        scope: scope,
        authGeneration: _integer(value['authGeneration'], 'authGeneration'),
        activityId: _string(value['activityId'], 'activityId'),
        expected: ComparisonCursor(
          generation: _integer(value['generation'], 'generation'),
          sequence: _integer(value['sequence'], 'sequence'),
          revision: _integer(value['revision'], 'revision'),
        ),
        expectedScopeRevision: sqlScoped
            ? _integer(value['expectedScopeRevision'], 'expectedScopeRevision')
            : 0,
        token: _string(value['token'], 'token'),
        submittedAt: _utc(value['submittedAt'], 'submittedAt'),
        action: _readAction(value['action'], scope),
      );
      if (command.activityId != catalogue.activityId) {
        throw const FormatException('Command activity mismatch.');
      }
      _validateAnswer(command, catalogue);
      final canonical = sqlScoped
          ? canonicalCommand(command)
          : legacyCanonicalCommand(command);
      if (canonical != raw) {
        throw const FormatException('Noncanonical comparison command.');
      }
      return command;
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Invalid comparison command: $error');
    }
  }

  static domain.ComparisonAction _readAction(
    Object? raw,
    ComparisonProfileScope scope,
  ) {
    final action = _object(raw, 'command.action');
    final kind = _string(action['kind'], 'action.kind');
    switch (kind) {
      case 'start':
        _exactKeys(
          action,
          const ['kind', 'sessionId', 'policy'],
          'action',
          ordered: true,
        );
        final policy = _object(action['policy'], 'action.policy');
        _exactKeys(
          policy,
          const ['completionThresholdPercent'],
          'policy',
          ordered: true,
        );
        return domain.StartComparisonRun(
          sessionId: _string(action['sessionId'], 'action.sessionId'),
          policy: LessonPolicy.fromJson(Map<String, dynamic>.from(policy)),
        );
      case 'answer':
        _exactKeys(
          action,
          const [
            'kind',
            'selectedRelation',
            'expectedRelationSnapshot',
            'observations',
          ],
          'action',
          ordered: true,
        );
        final observations = _array(action['observations'], 'observations')
            .map((value) => _readObservation(value, scope))
            .toList(growable: false);
        return domain.AnswerComparisonPair(
          domain.ComparePhonemesAnswer(
            selectedRelation: _enum(
              PhonemeRelation.values,
              action['selectedRelation'],
              'selectedRelation',
            ),
            expectedRelationSnapshot: _enum(
              PhonemeRelation.values,
              action['expectedRelationSnapshot'],
              'expectedRelationSnapshot',
            ),
            observations: observations,
          ),
        );
      case 'advance':
        _exactKeys(action, const ['kind'], 'action', ordered: true);
        return const domain.AdvanceComparisonPair();
      case 'review':
        _exactKeys(action, const ['kind'], 'action', ordered: true);
        return const domain.ReviewComparisonPairs();
      case 'finish':
        _exactKeys(
          action,
          const ['kind', 'recordCompletion'],
          'action',
          ordered: true,
        );
        return domain.FinishComparisonRun(
          recordCompletion: _boolean(
            action['recordCompletion'],
            'recordCompletion',
          ),
        );
      default:
        throw const FormatException('Unknown comparison action.');
    }
  }

  static ComparisonPlaybackObservation _readObservation(
    Object? raw,
    ComparisonProfileScope scope,
  ) {
    final observation = _object(raw, 'observation');
    _exactKeys(
      observation,
      const [
        'slot',
        'referenceId',
        'outcome',
        'source',
        'activityId',
        'runGeneration',
        'round',
        'pairId',
        'uiGeneration',
      ],
      'observation',
      ordered: true,
    );
    final sourceValue = observation['source'];
    return ComparisonPlaybackObservation(
      slot: _enum(ComparisonSample.values, observation['slot'], 'slot'),
      referenceId: _string(observation['referenceId'], 'referenceId'),
      outcome: _enum(
        CourseAudioOutcome.values,
        observation['outcome'],
        'outcome',
      ),
      source: sourceValue == null
          ? null
          : _enum(CourseAudioSource.values, sourceValue, 'source'),
      activityId: _string(observation['activityId'], 'activityId'),
      runGeneration: _integer(observation['runGeneration'], 'runGeneration'),
      round: _integer(observation['round'], 'round'),
      pairId: _string(observation['pairId'], 'pairId'),
      profile: scope,
      uiGeneration: _integer(observation['uiGeneration'], 'uiGeneration'),
    );
  }

  static void _validateAnswer(
    domain.ComparisonLearningCommand command,
    ComparisonCatalogue catalogue,
  ) {
    if (command.action case domain.AnswerComparisonPair(:final answer)) {
      final observations = answer.observations;
      if (observations.length != 2 ||
          observations[0].slot != ComparisonSample.a ||
          observations[1].slot != ComparisonSample.b ||
          observations[0].pairId != observations[1].pairId ||
          observations[0].round < 1 ||
          observations[0].round != observations[1].round ||
          observations[0].runGeneration != command.expected.generation ||
          observations[1].runGeneration != command.expected.generation ||
          observations[0].activityId != command.activityId ||
          observations[1].activityId != command.activityId ||
          observations[0].profile != command.scope ||
          observations[1].profile != command.scope ||
          observations[0].uiGeneration != observations[1].uiGeneration ||
          observations.any(
            (observation) =>
                observation.outcome != CourseAudioOutcome.completed ||
                observation.source != CourseAudioSource.unverifiedRecording,
          )) {
        throw const FormatException('Invalid comparison playback provenance.');
      }
      final exercise = catalogue.byId[observations.first.pairId];
      if (exercise == null ||
          answer.expectedRelationSnapshot != exercise.expectedRelation ||
          observations[0].referenceId != exercise.sampleA.referenceId ||
          observations[1].referenceId != exercise.sampleB.referenceId) {
        throw const FormatException(
          'Answer does not match authored A/B content.',
        );
      }
    }
  }
}

Map<String, Object?> _object(Object? value, String name) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException('$name must be an object with string keys.');
  }
  return value.cast<String, Object?>();
}

List<Object?> _array(Object? value, String name) {
  if (value is! List) throw FormatException('$name must be an array.');
  return value.cast<Object?>();
}

void _exactKeys(
  Map<String, Object?> value,
  List<String> expected,
  String name, {
  bool ordered = false,
}) {
  if (value.length != expected.length ||
      value.keys.any((key) => !expected.contains(key)) ||
      (ordered && !_sameOrder(value.keys.toList(), expected))) {
    throw FormatException(
      '$name has missing, unknown, or out-of-order fields.',
    );
  }
}

bool _sameOrder(List<String> actual, List<String> expected) {
  if (actual.length != expected.length) return false;
  for (var index = 0; index < actual.length; index++) {
    if (actual[index] != expected[index]) return false;
  }
  return true;
}

String _string(Object? value, String name) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$name must be nonblank text.');
  }
  return value;
}

bool _boolean(Object? value, String name) {
  if (value is! bool) throw FormatException('$name must be boolean.');
  return value;
}

int _integer(Object? value, String name) {
  if (value is! int || value < 0 || value > comparisonMaxSafeInteger) {
    throw FormatException('$name must be a safe nonnegative integer.');
  }
  return value;
}

T _enum<T extends Enum>(List<T> values, Object? value, String name) {
  final string = _string(value, name);
  for (final variant in values) {
    if (variant.name == string) return variant;
  }
  throw FormatException('$name has an unknown variant.');
}

DateTime _utc(Object? value, String name) {
  final raw = _string(value, name);
  final parsed = DateTime.tryParse(raw);
  if (parsed == null || !parsed.isUtc || parsed.toIso8601String() != raw) {
    throw FormatException('$name must be canonical UTC ISO-8601.');
  }
  return parsed;
}
