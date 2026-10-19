import 'dart:convert';

import 'comparison_content.dart';
import 'comparison_learning_command.dart';
import 'comparison_learning_state.dart';
import 'course_learning_error.dart' show ComparisonUnavailableException;
import 'course_audio_contract.dart';
import 'lesson_policy.dart';
import 'lesson_section_session.dart';

export 'course_learning_error.dart' show ComparisonUnavailableException;

final class ComparisonLearningCodec {
  const ComparisonLearningCodec();

  String keyFor(ComparisonProfileScope scope) => scope.storageKey;
  String canonicalCommand(ComparisonLearningCommand command) =>
      comparisonCanonicalCommand(command);

  String encode(ComparisonLearningState state) {
    try {
      _validateState(state, null);
      return jsonEncode(_document(state));
    } on ComparisonUnavailableException {
      rethrow;
    } on ArgumentError catch (error) {
      throw ComparisonUnavailableException(error);
    } on FormatException catch (error) {
      throw ComparisonUnavailableException(error);
    }
  }

  ComparisonLearningState decode(String raw,
      ComparisonProfileScope expectedScope, ComparisonCatalogue catalogue) {
    try {
      final root = _object(jsonDecode(raw), 'document');
      _exactKeys(
          root,
          const [
            'schemaVersion',
            'family',
            'courseId',
            'owner',
            'revision',
            'commitOrdinal',
            'slot',
            'attempts',
            'receipts',
            'mistakes',
            'summaries',
            'completions'
          ],
          'document');
      if (_integer(root['schemaVersion'], 'schemaVersion') != 1) {
        throw const FormatException('Unsupported comparison schema.');
      }
      if (_string(root['family'], 'family') != 'comparison') {
        throw const FormatException('Wrong document family.');
      }
      final course = _string(root['courseId'], 'courseId');
      final owner = _readOwner(_object(root['owner'], 'owner'));
      final scope = ComparisonProfileScope(courseId: course, owner: owner);
      if (scope != expectedScope) {
        throw const FormatException('Comparison profile mismatch.');
      }
      if (catalogue.activityId != 'en-fr-phoneme-comparison' ||
          catalogue.contentRevision != 1) {
        throw const FormatException(
            'Unsupported comparison catalogue identity.');
      }
      final parsedReceipts = _array(root['receipts'], 'receipts')
          .map((v) => _readReceipt(_object(v, 'receipt'), scope))
          .toList();
      final slotRaw = root['slot'];
      final slot = slotRaw == null
          ? null
          : _readSlot(_object(slotRaw, 'slot'), scope, catalogue);
      final attempts = _array(root['attempts'], 'attempts')
          .map((v) => _readAttempt(_object(v, 'attempt'), scope))
          .toList();
      final mistakes = _readMistakes(root['mistakes'], scope, catalogue);
      final summaries = _readSummaries(root['summaries'], scope, catalogue);
      final completions = _array(root['completions'], 'completions')
          .map((v) =>
              _readCompletion(_object(v, 'completion'), scope, catalogue))
          .toList();
      final state = ComparisonLearningState(
          scope: scope,
          revision: _integer(root['revision'], 'revision'),
          commitOrdinal: _integer(root['commitOrdinal'], 'commitOrdinal'),
          slot: slot,
          attempts: attempts,
          receipts: parsedReceipts,
          mistakes: mistakes,
          summaries: summaries,
          completions: completions);
      _validateState(state, catalogue);
      return state;
    } on ComparisonUnavailableException {
      rethrow;
    } on FormatException catch (error) {
      throw ComparisonUnavailableException(error);
    } on ArgumentError catch (error) {
      throw ComparisonUnavailableException(error);
    } on TypeError catch (error) {
      throw ComparisonUnavailableException(error);
    }
  }

  Map<String, Object?> _document(ComparisonLearningState s) =>
      <String, Object?>{
        'schemaVersion': 1,
        'family': 'comparison',
        'courseId': s.scope.courseId,
        'owner': _ownerJson(s.scope.owner),
        'revision': s.revision,
        'commitOrdinal': s.commitOrdinal,
        'slot': s.slot == null ? null : _slotJson(s.slot!),
        'attempts': [for (final a in s.attempts) _attemptJson(a)],
        'receipts': [for (final r in s.receipts) _receiptJson(r)],
        'mistakes': {
          for (final e in s.mistakes.entries)
            _tupleKey([e.key.activityId, e.key.pairId, e.key.contentRevision]):
                {
              'firstWrongAt': _date(e.value.firstWrongAt),
              'latestWrongAt': _date(e.value.latestWrongAt),
              'failureCount': e.value.failureCount
            }
        },
        'summaries': {
          for (final e in s.summaries.entries)
            _tupleKey([e.key.activityId, e.key.pairId, e.key.contentRevision]):
                {
              'firstInRun': _countJson(e.value.firstInRun),
              'repeatInRun': _countJson(e.value.repeatInRun),
              'afterDebrief': _countJson(e.value.afterDebrief)
            }
        },
        'completions': [
          for (final c in s.completions)
            {
              'activityId': c.activityId,
              'contentRevision': c.contentRevision,
              'policyRevision': c.policyRevision,
              'thresholdPercent': c.thresholdPercent,
              'committedAt': _date(c.committedAt)
            }
        ]
      };

  Map<String, Object?> _ownerJson(LearningOwner o) =>
      {'kind': o.isGuest ? 'guest' : 'account', 'userId': o.userId};
  LearningOwner _readOwner(Map<String, Object?> o) {
    _exactKeys(o, const ['kind', 'userId'], 'owner');
    final kind = _string(o['kind'], 'owner.kind');
    final id = o['userId'];
    if (kind == 'guest') {
      if (id != null) {
        throw const FormatException('Guest owner must have null userId.');
      }
      return LearningOwner.guest();
    }
    if (kind == 'account') {
      return LearningOwner.account(_string(id, 'owner.userId'));
    }
    throw const FormatException('Unknown owner kind.');
  }

  Map<String, Object?> _slotJson(ComparisonSlot s) => {
        'activityId': s.activityId,
        'cursor': _cursorJson(s.cursor),
        'checkpoint': {
          'sessionId': s.checkpoint.sessionId,
          'contentRevision': s.checkpoint.contentRevision,
          'policy': s.checkpoint.policy.toJson(),
          'session': s.checkpoint.sessionJson
        },
        'latestReceipt': _receiptHeaderJson(s.latestReceipt)
      };
  ComparisonSlot _readSlot(Map<String, Object?> m, ComparisonProfileScope scope,
      ComparisonCatalogue catalogue) {
    _exactKeys(m, const ['activityId', 'cursor', 'checkpoint', 'latestReceipt'],
        'slot');
    final activity = _string(m['activityId'], 'slot.activityId');
    if (activity != catalogue.activityId) {
      throw const FormatException('Unknown slot activity.');
    }
    final cursor = _readCursor(_object(m['cursor'], 'slot.cursor'));
    final cp = _object(m['checkpoint'], 'slot.checkpoint');
    _exactKeys(cp, const ['sessionId', 'contentRevision', 'policy', 'session'],
        'checkpoint');
    final sessionId = _string(cp['sessionId'], 'checkpoint.sessionId');
    final revision =
        _integer(cp['contentRevision'], 'checkpoint.contentRevision');
    if (revision != catalogue.contentRevision) {
      throw const FormatException('Checkpoint content revision mismatch.');
    }
    final policyRaw = _object(cp['policy'], 'checkpoint.policy');
    _exactKeys(
        policyRaw, const ['completionThresholdPercent'], 'checkpoint.policy');
    final policy = LessonPolicy.fromJson(Map<String, dynamic>.from(policyRaw));
    final sessionRaw = _object(cp['session'], 'checkpoint.session');
    _exactKeys(
        sessionRaw,
        const [
          'version',
          'sessionId',
          'contentRevision',
          'itemIds',
          'queue',
          'position',
          'round',
          'attemptCount',
          'phase',
          'submittedThisRound',
          'lastCorrect',
          'answered',
          'latestAnswers',
          'policy'
        ],
        'session');
    final savedSessionPolicy = _object(sessionRaw['policy'], 'session.policy');
    _exactKeys(savedSessionPolicy, const ['completionThresholdPercent'],
        'session.policy');
    final itemIds = catalogue.exercises.map((e) => e.id).toList();
    for (final key in const [
      'version',
      'contentRevision',
      'position',
      'round',
      'attemptCount'
    ]) {
      _integer(sessionRaw[key], 'session.$key');
    }
    final session = LessonSectionSession.fromJson(
        Map<String, dynamic>.from(sessionRaw),
        itemIds: itemIds,
        contentRevision: catalogue.contentRevision);
    if (session.sessionId != sessionId ||
        session.contentRevision != revision ||
        session.policy.completionThresholdPercent !=
            policy.completionThresholdPercent) {
      throw const FormatException('Checkpoint/session metadata mismatch.');
    }
    final receipt =
        _readReceipt(_object(m['latestReceipt'], 'slot.latestReceipt'), scope);
    final checkpoint = ComparisonCheckpoint(
        scope: scope,
        sessionId: sessionId,
        contentRevision: revision,
        policy: policy,
        sessionJson: session.toJson());
    return ComparisonSlot(
        scope: scope,
        activityId: activity,
        cursor: cursor,
        checkpoint: checkpoint,
        latestReceipt: receipt);
  }

  Map<String, Object?> _cursorJson(ComparisonCursor c) => {
        'generation': c.generation,
        'sequence': c.sequence,
        'revision': c.revision
      };
  ComparisonCursor _readCursor(Map<String, Object?> m) {
    _exactKeys(m, const ['generation', 'sequence', 'revision'], 'cursor');
    return ComparisonCursor(
        generation: _integer(m['generation'], 'cursor.generation'),
        sequence: _integer(m['sequence'], 'cursor.sequence'),
        revision: _integer(m['revision'], 'cursor.revision'));
  }

  Map<String, Object?> _receiptHeaderJson(ComparisonReceipt r) => {
        'activityId': r.activityId,
        'generation': r.generation,
        'sequence': r.sequence,
        'token': r.token,
        'canonicalCommand': r.canonicalCommand,
        'before': _cursorJson(r.before),
        'after': _cursorJson(r.after),
        'commitOrdinal': r.commitOrdinal
      };
  Map<String, Object?> _receiptJson(ComparisonReceipt r) =>
      _receiptHeaderJson(r);
  ComparisonReceipt _readReceipt(
      Map<String, Object?> m, ComparisonProfileScope scope) {
    _exactKeys(
        m,
        const [
          'activityId',
          'generation',
          'sequence',
          'token',
          'canonicalCommand',
          'before',
          'after',
          'commitOrdinal'
        ],
        'receipt');
    final activity = _string(m['activityId'], 'receipt.activityId');
    final generation = _integer(m['generation'], 'receipt.generation');
    final sequence = _integer(m['sequence'], 'receipt.sequence');
    final token = _string(m['token'], 'receipt.token');
    final canonical =
        _string(m['canonicalCommand'], 'receipt.canonicalCommand');
    final before = _readCursor(_object(m['before'], 'receipt.before'));
    final after = _readCursor(_object(m['after'], 'receipt.after'));
    final ordinal = _integer(m['commitOrdinal'], 'receipt.commitOrdinal');
    final command = _readCanonicalCommand(canonical, scope);
    if (command.activityId != activity ||
        command.token != token ||
        command.expected != before ||
        command.expected.generation != before.generation) {
      throw const FormatException('Receipt command header mismatch.');
    }
    final isStart = command.action is StartComparisonRun;
    if (isStart !=
        (before.generation == 0 || after.generation == before.generation + 1)) {
      throw const FormatException('Receipt start action/cursor mismatch.');
    }
    return ComparisonReceipt(
        scope: scope,
        activityId: activity,
        generation: generation,
        sequence: sequence,
        token: token,
        canonicalCommand: canonical,
        before: before,
        after: after,
        commitOrdinal: ordinal);
  }

  ComparisonLearningCommand _readCanonicalCommand(
      String raw, ComparisonProfileScope scope) {
    final m = _object(jsonDecode(raw), 'canonicalCommand');
    const ordered = [
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
      'action'
    ];
    _exactKeys(m, ordered, 'canonicalCommand', ordered: true);
    if (_integer(m['schemaVersion'], 'command.schemaVersion') != 1 ||
        _string(m['family'], 'command.family') != 'comparison' ||
        _string(m['courseId'], 'command.courseId') != scope.courseId ||
        _readOwner(_object(m['owner'], 'command.owner')) != scope.owner) {
      throw const FormatException('Canonical command profile mismatch.');
    }
    final actionMap = _object(m['action'], 'command.action');
    final kind = _string(actionMap['kind'], 'action.kind');
    final ComparisonAction action;
    switch (kind) {
      case 'start':
        _exactKeys(actionMap, const ['kind', 'sessionId', 'policy'], 'action');
        final p = _object(actionMap['policy'], 'action.policy');
        _exactKeys(p, const ['completionThresholdPercent'], 'action.policy');
        action = StartComparisonRun(
            sessionId: _string(actionMap['sessionId'], 'action.sessionId'),
            policy: LessonPolicy.fromJson(Map<String, dynamic>.from(p)));
        break;
      case 'answer':
        _exactKeys(
            actionMap,
            const [
              'kind',
              'selectedRelation',
              'expectedRelationSnapshot',
              'observations'
            ],
            'action');
        final observations =
            _array(actionMap['observations'], 'action.observations').map((v) {
          final o = _object(v, 'observation');
          _exactKeys(
              o,
              const [
                'slot',
                'referenceId',
                'outcome',
                'source',
                'activityId',
                'runGeneration',
                'round',
                'pairId',
                'uiGeneration'
              ],
              'observation');
          return ComparisonPlaybackObservation(
              slot:
                  _enum(ComparisonSample.values, o['slot'], 'observation.slot'),
              referenceId: _string(o['referenceId'], 'observation.referenceId'),
              outcome: _enum(CourseAudioOutcome.values, o['outcome'],
                  'observation.outcome'),
              source: o['source'] == null
                  ? null
                  : _enum(CourseAudioSource.values, o['source'],
                      'observation.source'),
              activityId: _string(o['activityId'], 'observation.activityId'),
              runGeneration:
                  _integer(o['runGeneration'], 'observation.runGeneration'),
              round: _integer(o['round'], 'observation.round'),
              pairId: _string(o['pairId'], 'observation.pairId'),
              profile: scope,
              uiGeneration:
                  _integer(o['uiGeneration'], 'observation.uiGeneration'));
        }).toList();
        action = AnswerComparisonPair(ComparePhonemesAnswer(
            selectedRelation: _enum(PhonemeRelation.values,
                actionMap['selectedRelation'], 'selectedRelation'),
            expectedRelationSnapshot: _enum(
                PhonemeRelation.values,
                actionMap['expectedRelationSnapshot'],
                'expectedRelationSnapshot'),
            observations: observations));
        break;
      case 'advance':
        _exactKeys(actionMap, const ['kind'], 'action');
        action = const AdvanceComparisonPair();
        break;
      case 'review':
        _exactKeys(actionMap, const ['kind'], 'action');
        action = const ReviewComparisonPairs();
        break;
      case 'finish':
        _exactKeys(actionMap, const ['kind', 'recordCompletion'], 'action');
        action = FinishComparisonRun(
            recordCompletion:
                _boolean(actionMap['recordCompletion'], 'recordCompletion'));
        break;
      default:
        throw const FormatException('Unknown action kind.');
    }
    final command = ComparisonLearningCommand(
        scope: scope,
        authGeneration: _integer(m['authGeneration'], 'authGeneration'),
        activityId: _string(m['activityId'], 'activityId'),
        expected: ComparisonCursor(
            generation: _integer(m['generation'], 'generation'),
            sequence: _integer(m['sequence'], 'sequence'),
            revision: _integer(m['revision'], 'revision')),
        expectedScopeRevision: 0,
        token: _string(m['token'], 'token'),
        submittedAt: _utc(m['submittedAt'], 'submittedAt'),
        action: action);
    if (comparisonCanonicalCommand(command) != raw) {
      throw const FormatException('Noncanonical command fingerprint.');
    }
    return command;
  }

  Map<String, Object?> _attemptJson(ComparisonPairAttempt a) => {
        'activityId': a.activityId,
        'pairId': a.pairId,
        'contentRevision': a.contentRevision,
        'runGeneration': a.runGeneration,
        'round': a.round,
        'sequence': a.sequence,
        'selectedRelation': a.selectedRelation.name,
        'expectedRelation': a.expectedRelation.name,
        'correct': a.correct,
        'presentation': a.presentation.name,
        'afterDebrief': a.afterDebrief,
        'observations': [for (final o in a.observations) _observationJson(o)],
        'answeredAt': _date(a.answeredAt),
        'committedAt': _date(a.committedAt)
      };
  Map<String, Object?> _observationJson(ComparisonPlaybackObservation o) => {
        'slot': o.slot.name,
        'referenceId': o.referenceId,
        'outcome': o.outcome.name,
        'source': o.source?.name,
        'activityId': o.activityId,
        'runGeneration': o.runGeneration,
        'round': o.round,
        'pairId': o.pairId,
        'uiGeneration': o.uiGeneration
      };
  ComparisonPairAttempt _readAttempt(
      Map<String, Object?> m, ComparisonProfileScope scope) {
    _exactKeys(
        m,
        const [
          'activityId',
          'pairId',
          'contentRevision',
          'runGeneration',
          'round',
          'sequence',
          'selectedRelation',
          'expectedRelation',
          'correct',
          'presentation',
          'afterDebrief',
          'observations',
          'answeredAt',
          'committedAt'
        ],
        'attempt');
    final activity = _string(m['activityId'], 'attempt.activityId');
    final pair = _string(m['pairId'], 'attempt.pairId');
    final revision = _integer(m['contentRevision'], 'attempt.contentRevision');
    final gen = _integer(m['runGeneration'], 'attempt.runGeneration');
    final round = _integer(m['round'], 'attempt.round');
    final sequence = _integer(m['sequence'], 'attempt.sequence');
    final selected = _enum(
        PhonemeRelation.values, m['selectedRelation'], 'selectedRelation');
    final expected = _enum(
        PhonemeRelation.values, m['expectedRelation'], 'expectedRelation');
    final correct = _boolean(m['correct'], 'correct');
    final presentation =
        _enum(AttemptPresentation.values, m['presentation'], 'presentation');
    final after = _boolean(m['afterDebrief'], 'afterDebrief');
    final observations = _array(m['observations'], 'observations')
        .map((v) => _readObservation(_object(v, 'observation'), scope))
        .toList();
    return ComparisonPairAttempt(
        scope: scope,
        activityId: activity,
        pairId: pair,
        contentRevision: revision,
        runGeneration: gen,
        round: round,
        sequence: sequence,
        selectedRelation: selected,
        expectedRelation: expected,
        correct: correct,
        presentation: presentation,
        afterDebrief: after,
        observations: observations,
        answeredAt: _utc(m['answeredAt'], 'answeredAt'),
        committedAt: _utc(m['committedAt'], 'committedAt'));
  }

  ComparisonPlaybackObservation _readObservation(
      Map<String, Object?> o, ComparisonProfileScope scope) {
    _exactKeys(
        o,
        const [
          'slot',
          'referenceId',
          'outcome',
          'source',
          'activityId',
          'runGeneration',
          'round',
          'pairId',
          'uiGeneration'
        ],
        'observation');
    return ComparisonPlaybackObservation(
        slot: _enum(ComparisonSample.values, o['slot'], 'slot'),
        referenceId: _string(o['referenceId'], 'referenceId'),
        outcome: _enum(CourseAudioOutcome.values, o['outcome'], 'outcome'),
        source: o['source'] == null
            ? null
            : _enum(CourseAudioSource.values, o['source'], 'source'),
        activityId: _string(o['activityId'], 'activityId'),
        runGeneration: _integer(o['runGeneration'], 'runGeneration'),
        round: _integer(o['round'], 'round'),
        pairId: _string(o['pairId'], 'pairId'),
        profile: scope,
        uiGeneration: _integer(o['uiGeneration'], 'uiGeneration'));
  }

  Map<ComparisonPairMistakeKey, ComparisonPairMistake> _readMistakes(
      Object? value,
      ComparisonProfileScope scope,
      ComparisonCatalogue catalogue) {
    final raw = _object(value, 'mistakes');
    final out = <ComparisonPairMistakeKey, ComparisonPairMistake>{};
    for (final e in raw.entries) {
      final tuple = _readTupleKey(e.key);
      final activity = tuple[0] as String,
          pair = tuple[1] as String,
          rev = tuple[2] as int;
      _requireContent(activity, pair, rev, catalogue);
      final k = ComparisonPairMistakeKey(
          scope: scope,
          activityId: activity,
          pairId: pair,
          contentRevision: rev);
      if (out.containsKey(k) || _tupleKey(tuple) != e.key) {
        throw const FormatException('Duplicate/noncanonical mistake key.');
      }
      final m = _object(e.value, 'mistake');
      _exactKeys(m, const ['firstWrongAt', 'latestWrongAt', 'failureCount'],
          'mistake');
      out[k] = ComparisonPairMistake(
          scope: scope,
          key: k,
          firstWrongAt: _utc(m['firstWrongAt'], 'firstWrongAt'),
          latestWrongAt: _utc(m['latestWrongAt'], 'latestWrongAt'),
          failureCount: _integer(m['failureCount'], 'failureCount'));
    }
    return out;
  }

  Map<ComparisonSummaryKey, ComparisonPairSummary> _readSummaries(Object? value,
      ComparisonProfileScope scope, ComparisonCatalogue catalogue) {
    final raw = _object(value, 'summaries');
    final out = <ComparisonSummaryKey, ComparisonPairSummary>{};
    for (final e in raw.entries) {
      final tuple = _readTupleKey(e.key);
      final activity = tuple[0] as String,
          pair = tuple[1] as String,
          rev = tuple[2] as int;
      _requireContent(activity, pair, rev, catalogue);
      final k = ComparisonSummaryKey(
          scope: scope,
          activityId: activity,
          pairId: pair,
          contentRevision: rev);
      if (out.containsKey(k) || _tupleKey(tuple) != e.key) {
        throw const FormatException('Duplicate/noncanonical summary key.');
      }
      final m = _object(e.value, 'summary');
      _exactKeys(
          m, const ['firstInRun', 'repeatInRun', 'afterDebrief'], 'summary');
      out[k] = ComparisonPairSummary(
          key: k,
          firstInRun: _readCount(m['firstInRun'], 'firstInRun'),
          repeatInRun: _readCount(m['repeatInRun'], 'repeatInRun'),
          afterDebrief: _readCount(m['afterDebrief'], 'afterDebrief'));
    }
    return out;
  }

  ComparisonCount _readCount(Object? v, String name) {
    final m = _object(v, name);
    _exactKeys(m, const ['correct', 'total'], name);
    return ComparisonCount(
        correct: _integer(m['correct'], '$name.correct'),
        total: _integer(m['total'], '$name.total'));
  }

  Map<String, Object?> _countJson(ComparisonCount c) =>
      {'correct': c.correct, 'total': c.total};
  List<Object?> _readTupleKey(String key) {
    final decoded = jsonDecode(key);
    if (decoded is! List ||
        decoded.length != 3 ||
        decoded[0] is! String ||
        decoded[1] is! String ||
        decoded[2] is! int ||
        decoded[2] is bool) {
      throw const FormatException('Invalid tuple key.');
    }
    return decoded.cast<Object?>();
  }

  String _tupleKey(List<Object?> tuple) => jsonEncode(tuple);

  ComparisonCompletion _readCompletion(Map<String, Object?> m,
      ComparisonProfileScope scope, ComparisonCatalogue catalogue) {
    _exactKeys(
        m,
        const [
          'activityId',
          'contentRevision',
          'policyRevision',
          'thresholdPercent',
          'committedAt'
        ],
        'completion');
    final activity = _string(m['activityId'], 'activityId');
    final rev = _integer(m['contentRevision'], 'contentRevision');
    if (activity != catalogue.activityId || rev != catalogue.contentRevision) {
      throw const FormatException('Unknown completion content.');
    }
    final policyRevision = _integer(m['policyRevision'], 'policyRevision');
    final threshold = _integer(m['thresholdPercent'], 'thresholdPercent');
    if (policyRevision != 1 || threshold < 1 || threshold > 100) {
      throw const FormatException('Unsupported completion policy identity.');
    }
    return ComparisonCompletion(
        scope: scope,
        activityId: activity,
        contentRevision: rev,
        policyRevision: policyRevision,
        thresholdPercent: threshold,
        committedAt: _utc(m['committedAt'], 'committedAt'));
  }

  void _validateState(
      ComparisonLearningState state, ComparisonCatalogue? catalogue) {
    for (final entry in state.mistakes.entries) {
      if (entry.key != entry.value.key || entry.key.scope != state.scope) {
        throw const FormatException('Mistake identity mismatch.');
      }
      if (catalogue != null) {
        _requireContent(entry.key.activityId, entry.key.pairId,
            entry.key.contentRevision, catalogue);
      }
    }
    for (final entry in state.summaries.entries) {
      if (entry.key != entry.value.key || entry.key.scope != state.scope) {
        throw const FormatException('Summary identity mismatch.');
      }
      if (catalogue != null) {
        _requireContent(entry.key.activityId, entry.key.pairId,
            entry.key.contentRevision, catalogue);
      }
    }
    if (catalogue == null) return;
    final receipts = {
      for (final r in state.receipts)
        '${r.activityId}:${r.generation}:${r.sequence}': r
    };
    for (var i = 0; i < state.receipts.length; i++) {
      final receipt = state.receipts[i];
      final command =
          _readCanonicalCommand(receipt.canonicalCommand, state.scope);
      _validateCommandContent(command, receipt.after, catalogue);
      if (i > 0) {
        final previous = state.receipts[i - 1];
        if (receipt.commitOrdinal != previous.commitOrdinal + 1 ||
            receipt.before != previous.after) {
          throw const FormatException(
              'Retained receipt chain is inconsistent.');
        }
      }
    }
    final counts = <ComparisonSummaryKey, List<int>>{};
    for (final a in state.attempts) {
      _validateAttemptContent(a, catalogue);
      final key = ComparisonSummaryKey(
          scope: state.scope,
          activityId: a.activityId,
          pairId: a.pairId,
          contentRevision: a.contentRevision);
      final n = counts.putIfAbsent(key, () => [0, 0, 0, 0, 0, 0]);
      final first = a.presentation == AttemptPresentation.firstInRun;
      n[first ? 0 : 2]++;
      if (a.correct) n[first ? 1 : 3]++;
      if (a.afterDebrief) {
        n[4]++;
        if (a.correct) n[5]++;
      }
      final receipt =
          receipts['${a.activityId}:${a.runGeneration}:${a.sequence}'];
      if (receipt != null) {
        final cmd =
            _readCanonicalCommand(receipt.canonicalCommand, state.scope);
        if (cmd.action is! AnswerComparisonPair) {
          throw const FormatException('Attempt links to non-answer receipt.');
        }
        final answer = (cmd.action as AnswerComparisonPair).answer;
        if (answer.selectedRelation != a.selectedRelation ||
            answer.expectedRelationSnapshot != a.expectedRelation ||
            cmd.submittedAt != a.answeredAt ||
            receipt.after.generation != a.runGeneration ||
            receipt.after.sequence != a.sequence ||
            !_sameObservations(answer.observations, a.observations)) {
          throw const FormatException('Attempt/receipt link mismatch.');
        }
      }
    }
    for (final e in counts.entries) {
      final s = state.summaries[e.key];
      if (s == null ||
          s.firstInRun.total < e.value[0] ||
          s.firstInRun.correct < e.value[1] ||
          s.firstInRun.total - s.firstInRun.correct < e.value[0] - e.value[1] ||
          s.repeatInRun.total < e.value[2] ||
          s.repeatInRun.correct < e.value[3] ||
          s.repeatInRun.total - s.repeatInRun.correct <
              e.value[2] - e.value[3] ||
          s.afterDebrief.total < e.value[4] ||
          s.afterDebrief.correct < e.value[5] ||
          s.afterDebrief.total - s.afterDebrief.correct <
              e.value[4] - e.value[5]) {
        throw const FormatException('Summary undercounts retained attempts.');
      }
    }
    if (state.slot != null) {
      final slot = state.slot!;
      if (slot.activityId != catalogue.activityId ||
          slot.checkpoint.contentRevision != catalogue.contentRevision) {
        throw const FormatException('Slot content mismatch.');
      }
      final latest = slot.latestReceipt;
      final cmd = _readCanonicalCommand(latest.canonicalCommand, state.scope);
      _validateCommandContent(cmd, latest.after, catalogue);
      if (latest.activityId != catalogue.activityId ||
          cmd.token != latest.token ||
          cmd.expected != latest.before ||
          latest.after != slot.cursor) {
        throw const FormatException('Latest receipt mismatch.');
      }
      if (state.receipts.isNotEmpty) {
        final retained = state.receipts.last;
        if (latest.scope != retained.scope ||
            latest.activityId != retained.activityId ||
            latest.generation != retained.generation ||
            latest.sequence != retained.sequence ||
            latest.token != retained.token ||
            latest.canonicalCommand != retained.canonicalCommand ||
            latest.before != retained.before ||
            latest.after != retained.after ||
            latest.commitOrdinal != retained.commitOrdinal) {
          throw const FormatException(
              'Slot receipt differs from retained receipt.');
        }
      }
      if (cmd.action case StartComparisonRun(:final sessionId, :final policy)) {
        final session = _checkpointSession(slot, catalogue);
        final fresh = LessonSectionSession(
            itemIds: catalogue.exercises.map((e) => e.id).toList(),
            sessionId: sessionId,
            contentRevision: catalogue.contentRevision,
            policy: slot.checkpoint.policy);
        if (slot.checkpoint.sessionId != sessionId ||
            slot.checkpoint.policy.completionThresholdPercent !=
                policy.completionThresholdPercent ||
            jsonEncode(session.toJson()) != jsonEncode(fresh.toJson())) {
          throw const FormatException(
              'Latest start must retain a fresh canonical session.');
        }
      } else if (cmd.action is AnswerComparisonPair) {
        final session = _checkpointSession(slot, catalogue);
        final answer = (cmd.action as AnswerComparisonPair).answer;
        final currentPair = session.currentItemId;
        final expectedCorrect =
            answer.selectedRelation == answer.expectedRelationSnapshot;
        ComparisonPairAttempt? retainedAttempt;
        for (final attempt in state.attempts) {
          if (attempt.activityId == slot.activityId &&
              attempt.runGeneration == latest.after.generation &&
              attempt.sequence == latest.after.sequence) {
            retainedAttempt = attempt;
            break;
          }
        }
        if (!session.answered ||
            currentPair == null ||
            answer.observations.first.pairId != currentPair ||
            answer.observations.first.round != session.round ||
            session.lastCorrect != expectedCorrect ||
            session.latestAnswers[currentPair] != expectedCorrect ||
            (retainedAttempt != null &&
                (retainedAttempt.pairId != currentPair ||
                    retainedAttempt.round != session.round ||
                    retainedAttempt.selectedRelation !=
                        answer.selectedRelation ||
                    retainedAttempt.expectedRelation !=
                        answer.expectedRelationSnapshot ||
                    retainedAttempt.correct != expectedCorrect ||
                    cmd.submittedAt != retainedAttempt.answeredAt ||
                    !_sameObservations(
                        answer.observations, retainedAttempt.observations)))) {
          throw const FormatException(
              'Latest answer consequences differ from checkpoint.');
        }
      } else if (cmd.action is AdvanceComparisonPair) {
        final session = _checkpointSession(slot, catalogue);
        if (session.answered) {
          throw const FormatException(
              'Latest advance left an answered checkpoint item.');
        }
      } else if (cmd.action is ReviewComparisonPairs) {
        final session = _checkpointSession(slot, catalogue);
        if (session.round < 2) {
          throw const FormatException(
              'Latest review did not start a review round.');
        }
      } else if (cmd.action case FinishComparisonRun(recordCompletion: true)) {
        final session = _checkpointSession(slot, catalogue);
        final threshold = session.policy.completionThresholdPercent;
        if (!session.canComplete ||
            !state.completions.any((completion) =>
                completion.activityId == slot.activityId &&
                completion.contentRevision == slot.checkpoint.contentRevision &&
                completion.policyRevision == 1 &&
                completion.thresholdPercent == threshold)) {
          throw const FormatException(
              'Latest recorded finish lacks eligible completion evidence.');
        }
      }
      _validateCurrentRunAnswers(state, slot, catalogue);
    }
    _validateCompletions(state, catalogue);
  }

  void _validateCurrentRunAnswers(ComparisonLearningState state,
      ComparisonSlot slot, ComparisonCatalogue catalogue) {
    final factsBySequence = <int, (String, bool)>{};
    final latestByPair = <String, (int, bool)>{};
    void record(int generation, int sequence, String pairId, bool correct) {
      if (generation != slot.cursor.generation) return;
      final fact = (pairId, correct);
      final priorAtSequence = factsBySequence[sequence];
      if (priorAtSequence != null && priorAtSequence != fact) {
        throw const FormatException(
            'Conflicting current-generation answer facts.');
      }
      factsBySequence[sequence] = fact;
      final priorForPair = latestByPair[pairId];
      if (priorForPair == null || sequence > priorForPair.$1) {
        latestByPair[pairId] = (sequence, correct);
      }
    }

    void readReceipt(ComparisonReceipt receipt) {
      if (receipt.generation != slot.cursor.generation) return;
      final command =
          _readCanonicalCommand(receipt.canonicalCommand, state.scope);
      if (command.action case AnswerComparisonPair(:final answer)) {
        record(
            receipt.generation,
            receipt.sequence,
            answer.observations.first.pairId,
            answer.selectedRelation == answer.expectedRelationSnapshot);
      }
    }

    for (final receipt in state.receipts) {
      readReceipt(receipt);
    }
    readReceipt(slot.latestReceipt);
    for (final attempt in state.attempts) {
      record(attempt.runGeneration, attempt.sequence, attempt.pairId,
          attempt.correct);
    }
    final session = _checkpointSession(slot, catalogue);
    for (final entry in latestByPair.entries) {
      if (session.latestAnswers[entry.key] != entry.value.$2) {
        throw const FormatException(
            'Checkpoint latest answer differs from available run evidence.');
      }
    }
  }

  void _validateCompletions(
      ComparisonLearningState state, ComparisonCatalogue catalogue) {
    final slot = state.slot;
    if (slot == null) return;
    final receipts = <ComparisonReceipt>[
      ...state.receipts,
      if (state.receipts.isEmpty) slot.latestReceipt
    ];
    final policiesByGeneration = <int, int>{};
    final finishes = <(String, int, int, int)>{};
    for (final receipt in receipts) {
      final command =
          _readCanonicalCommand(receipt.canonicalCommand, state.scope);
      switch (command.action) {
        case StartComparisonRun(:final policy):
          final previous = policiesByGeneration[receipt.generation];
          if (previous != null &&
              previous != policy.completionThresholdPercent) {
            throw const FormatException(
                'One run has conflicting saved start policies.');
          }
          policiesByGeneration[receipt.generation] =
              policy.completionThresholdPercent;
        case FinishComparisonRun(recordCompletion: true):
          final threshold = policiesByGeneration[receipt.generation];
          if (threshold != null) {
            finishes.add(
                (command.activityId, catalogue.contentRevision, 1, threshold));
          }
          if (!state.completions.any((completion) =>
              completion.activityId == command.activityId &&
              completion.contentRevision == catalogue.contentRevision &&
              completion.policyRevision == 1 &&
              (threshold == null ||
                  completion.thresholdPercent == threshold))) {
            throw const FormatException(
                'Recorded finish receipt lacks matching completion evidence.');
          }
        case _:
          break;
      }
    }

    final completeHistory = state.receipts.isNotEmpty
        ? state.receipts.first.commitOrdinal == 1 &&
            state.receipts.last.commitOrdinal == state.commitOrdinal
        : slot.latestReceipt.commitOrdinal == 1 && state.commitOrdinal == 1;
    if (completeHistory &&
        state.completions.any((completion) => !finishes.contains((
              completion.activityId,
              completion.contentRevision,
              completion.policyRevision,
              completion.thresholdPercent
            )))) {
      throw const FormatException(
          'Complete receipt history does not justify stored completion.');
    }
  }

  LessonSectionSession _checkpointSession(
          ComparisonSlot slot, ComparisonCatalogue catalogue) =>
      LessonSectionSession.fromJson(
          Map<String, dynamic>.from(slot.checkpoint.sessionJson),
          itemIds: catalogue.exercises.map((e) => e.id).toList(),
          contentRevision: catalogue.contentRevision);

  void _validateCommandContent(ComparisonLearningCommand command,
      ComparisonCursor after, ComparisonCatalogue catalogue) {
    if (command.action case AnswerComparisonPair(:final answer)) {
      final observations = answer.observations;
      if (observations.length != 2 ||
          observations.first.activityId != catalogue.activityId ||
          observations.last.activityId != catalogue.activityId ||
          observations.first.runGeneration != after.generation ||
          observations.last.runGeneration != after.generation ||
          observations.first.pairId != observations.last.pairId ||
          observations.first.round != observations.last.round ||
          observations.first.round < 1 ||
          observations.first.uiGeneration != observations.last.uiGeneration ||
          observations.first.slot != ComparisonSample.a ||
          observations.last.slot != ComparisonSample.b) {
        throw const FormatException(
            'Canonical answer provenance identity mismatch.');
      }
      final pairId = observations.first.pairId;
      _requireContent(
          command.activityId, pairId, catalogue.contentRevision, catalogue);
      final pair = catalogue.exercise(pairId);
      if (answer.expectedRelationSnapshot != pair.expectedRelation ||
          observations[0].referenceId != pair.sampleA.referenceId ||
          observations[1].referenceId != pair.sampleB.referenceId ||
          observations.any((o) =>
              o.outcome != CourseAudioOutcome.completed ||
              o.source != CourseAudioSource.unverifiedRecording ||
              o.activityId != command.activityId ||
              o.profile != command.scope)) {
        throw const FormatException(
            'Canonical answer does not match authored pair provenance.');
      }
    }
  }

  void _validateAttemptContent(
      ComparisonPairAttempt a, ComparisonCatalogue catalogue) {
    _requireContent(a.activityId, a.pairId, a.contentRevision, catalogue);
    final exercise = catalogue.exercise(a.pairId);
    if (a.expectedRelation != exercise.expectedRelation ||
        a.correct != (a.selectedRelation == exercise.expectedRelation) ||
        a.observations[0].referenceId != exercise.sampleA.referenceId ||
        a.observations[1].referenceId != exercise.sampleB.referenceId) {
      throw const FormatException('Attempt content binding mismatch.');
    }
  }

  void _requireContent(String activity, String pair, int revision,
      ComparisonCatalogue catalogue) {
    if (activity != catalogue.activityId ||
        revision != catalogue.contentRevision ||
        !catalogue.byId.containsKey(pair)) {
      throw const FormatException('Unknown comparison content identity.');
    }
  }

  bool _sameObservations(List<ComparisonPlaybackObservation> a,
      List<ComparisonPlaybackObservation> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      final x = a[i], y = b[i];
      if (x.slot != y.slot ||
          x.referenceId != y.referenceId ||
          x.outcome != y.outcome ||
          x.source != y.source ||
          x.activityId != y.activityId ||
          x.runGeneration != y.runGeneration ||
          x.round != y.round ||
          x.pairId != y.pairId ||
          x.uiGeneration != y.uiGeneration) {
        return false;
      }
    }
    return true;
  }
}

Map<String, Object?> _object(Object? value, String name) {
  if (value is! Map || value.keys.any((k) => k is! String)) {
    throw FormatException('$name must be an object with string keys.');
  }
  return value.cast<String, Object?>();
}

List<Object?> _array(Object? value, String name) {
  if (value is! List) {
    throw FormatException('$name must be an array.');
  }
  return value.cast<Object?>();
}

void _exactKeys(Map<String, Object?> value, List<String> expected, String name,
    {bool ordered = false}) {
  if (value.length != expected.length ||
      !value.keys.toSet().containsAll(expected) ||
      value.keys.any((k) => !expected.contains(k)) ||
      (ordered && !_sameOrder(value.keys.toList(), expected))) {
    throw FormatException('$name keys are missing, unknown, or out of order.');
  }
}

bool _sameOrder(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String _string(Object? v, String name) {
  if (v is! String) {
    throw FormatException('$name must be a string.');
  }
  return v;
}

bool _boolean(Object? v, String name) {
  if (v is! bool) {
    throw FormatException('$name must be a boolean.');
  }
  return v;
}

int _integer(Object? v, String name) {
  if (v is! int || v is bool || v < 0 || v > comparisonMaxSafeInteger) {
    throw FormatException('$name must be a safe nonnegative integer.');
  }
  return v;
}

T _enum<T extends Enum>(List<T> values, Object? v, String name) {
  final s = _string(v, name);
  for (final x in values) {
    if (x.name == s) return x;
  }
  throw FormatException('$name has unknown variant.');
}

DateTime _utc(Object? v, String name) {
  final s = _string(v, name);
  final d = DateTime.tryParse(s);
  if (d == null || !d.isUtc || d.toIso8601String() != s) {
    throw FormatException('$name must be canonical UTC ISO-8601.');
  }
  return d;
}

String _date(DateTime d) {
  if (!d.isUtc) {
    throw ArgumentError('Timestamp must be UTC.');
  }
  return d.toIso8601String();
}
