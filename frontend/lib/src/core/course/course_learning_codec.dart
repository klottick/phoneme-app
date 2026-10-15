import 'dart:convert';

import 'course_attempt.dart';
import 'course_learning_checkpoint.dart';
import 'course_learning_command.dart';
import 'course_learning_error.dart';
import 'course_learning_state.dart';
import 'course_skill_summary.dart';
import 'lesson_policy.dart';
import 'lesson_section_session.dart';

/// Versioned, strict JSON boundary for FR04 learning state and command identity.
class LearningDocumentCodec {
  const LearningDocumentCodec();

  String encode(CourseLearningState state) => jsonEncode(_state(state));

  CourseLearningState decode(String raw, LearningScope expectedScope) {
    try {
      final root = _obj(jsonDecode(raw), 'document');
      final version = _int(root['schemaVersion'], 'schemaVersion');
      if (version != 2) throw const LearningUnsupportedVersionException();
      _keys(
          root,
          {
            'schemaVersion',
            'courseId',
            'owner',
            'revision',
            'commitOrdinal',
            'history',
            'activities',
            'mistakes',
            'summaries',
            'completions',
            'bestScores',
            'pending'
          },
          'document');
      final owner = _owner(_obj(root['owner'], 'owner'));
      final scope = LearningScope(
          courseId: _str(root['courseId'], 'courseId'), owner: owner);
      if (scope != expectedScope) throw const FormatException('scope mismatch');
      final state = CourseLearningState(
        schemaVersion: version,
        scope: scope,
        revision: _int(root['revision'], 'revision'),
        commitOrdinal: _int(root['commitOrdinal'], 'commitOrdinal'),
        history: _arr(root['history'], 'history')
            .map((x) => _readBatch(_obj(x, 'batch'), scope))
            .toList(),
        activities: _readActivities(root['activities']),
        mistakes: _readMistakes(root['mistakes']),
        summaries: _readSummaries(root['summaries']),
        completions: _arr(root['completions'], 'completions')
            .map((x) => _readCompletion(_obj(x, 'completion')))
            .toList(),
        bestScores: _readScores(root['bestScores']),
        pending: _arr(root['pending'], 'pending')
            .map((x) => _readEvent(_obj(x, 'event')))
            .toList(),
      );
      _validateState(state);
      return state;
    } on LearningUnsupportedVersionException {
      rethrow;
    } on LearningCorruptException {
      rethrow;
    } catch (e) {
      throw LearningCorruptException(e);
    }
  }

  String canonicalCommand(LearningCommand c) => jsonEncode(_sort({
        'scope': c.scope.storageKey,
        'authGeneration': c.authGeneration,
        'activityId': c.activityId,
        'expected': _cursor(c.expected),
        'token': c.token,
        'submittedAt': c.submittedAt.toUtc().toIso8601String(),
        'action': _action(c.action),
        'draws': c.draws
            .map((d) => {'upperBound': d.upperBound, 'value': d.value})
            .toList(),
        'candidate': _snapshot(c.candidate),
        'feedback': {
          'message': c.feedback.message,
          'points': c.feedback.points,
          'cascades': c.feedback.cascades,
          'bonus': c.feedback.bonus,
          'correct': c.feedback.correct
        },
      }));

  Map<String, Object?> _state(CourseLearningState s) => {
        'schemaVersion': 2,
        'courseId': s.scope.courseId,
        'owner': _ownerJson(s.scope.owner),
        'revision': s.revision,
        'commitOrdinal': s.commitOrdinal,
        'history': s.history.map(_batch).toList(),
        'activities': s.activities.values.map(_slot).toList(),
        'mistakes': s.mistakes.values.map(_mistake).toList(),
        'summaries': s.summaries.entries
            .map((e) =>
                {'key': _summaryKey(e.key), 'count': _countJson(e.value)})
            .toList(),
        'completions': s.completions.map(_completion).toList(),
        'bestScores': s.bestScores,
        'pending': s.pending.map(_event).toList(),
      };

  Map<String, Object?> _ownerJson(LearningOwner o) =>
      o.isGuest ? {'kind': 'guest'} : {'kind': 'account', 'userId': o.userId};
  LearningOwner _owner(Map<String, Object?> m) {
    final kind = _str(m['kind'], 'owner.kind');
    switch (kind) {
      case 'guest':
        _keys(m, {'kind'}, 'owner');
        return LearningOwner.guest();
      case 'account':
        _keys(m, {'kind', 'userId'}, 'owner');
        return LearningOwner.account(_str(m['userId'], 'owner.userId'));
      default:
        throw const FormatException('unknown owner kind');
    }
  }

  Map<String, Object?> _batch(AttemptBatch b) => {
        'activityId': b.activityId,
        'generation': b.generation,
        'sequence': b.sequence,
        'token': b.token,
        'canonicalCommand': b.canonicalCommand,
        'attempts': b.attempts.map(_attempt).toList()
      };
  AttemptBatch _readBatch(Map<String, Object?> m, LearningScope s) {
    _keys(
        m,
        {
          'activityId',
          'generation',
          'sequence',
          'token',
          'canonicalCommand',
          'attempts'
        },
        'batch');
    return AttemptBatch(
        activityId: _str(m['activityId'], 'activityId'),
        generation: _int(m['generation'], 'generation'),
        sequence: _int(m['sequence'], 'sequence'),
        token: _str(m['token'], 'token'),
        canonicalCommand: _str(m['canonicalCommand'], 'canonicalCommand'),
        attempts: _arr(m['attempts'], 'attempts')
            .map((x) => _readAttempt(_obj(x, 'attempt'), s))
            .toList());
  }

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
        'answeredAt': _dateJson(a.answeredAt),
        'committedAt': _dateJson(a.committedAt),
        'skill': a.skill.name,
        'targetSounds': a.targetSounds,
        'answer': _answer(a.answer),
        'origin': a.origin.name,
        'presentation': a.presentation.name,
        'assistance': _enumSet(a.assistance),
        'contentState': a.contentState.name,
        'audioSource': a.audioSource.name,
        'correct': a.correct
      };
  CourseAttempt _readAttempt(Map<String, Object?> m, LearningScope s) {
    _keys(
        m,
        {
          'submissionId',
          'activityId',
          'runGeneration',
          'commandSequence',
          'batchIndex',
          'itemId',
          'itemOccurrence',
          'contentRevision',
          'commitOrdinal',
          'answeredAt',
          'committedAt',
          'skill',
          'targetSounds',
          'answer',
          'origin',
          'presentation',
          'assistance',
          'contentState',
          'audioSource',
          'correct'
        },
        'attempt');
    final a = _obj(m['answer'], 'answer');
    final kind = _str(a['answerKind'], 'answerKind');
    final answerFields = switch (kind) {
      'soundChoice' => {
          'answerKind',
          'selectedSound',
          'choices',
          'expectedSound'
        },
      'drillChoice' => {
          'answerKind',
          'selectedWord',
          'pairId',
          'choices',
          'expectedWord'
        },
      'soundCue' => {
          'answerKind',
          'selectedFamily',
          'wordId',
          'expectedFamily'
        },
      'wordTile' => {
          'answerKind',
          'wordId',
          'tileIndex',
          'targetSound',
          'expectedMembership'
        },
      _ => throw const FormatException('unknown answer kind')
    };
    _keys(a, answerFields, 'answer');
    final ans = switch (kind) {
      'soundChoice' => SoundChoiceAnswer(
          selectedSound: _str(a['selectedSound'], 'selectedSound'),
          choices: _strs(a['choices'], 'choices'),
          expectedSound: _str(a['expectedSound'], 'expectedSound')),
      'drillChoice' => DrillChoiceAnswer(
          selectedWord: _str(a['selectedWord'], 'selectedWord'),
          pairId: _str(a['pairId'], 'pairId'),
          choices: _strs(a['choices'], 'choices'),
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
        skill: _enum(LearningSkill.values, m['skill'], 'skill'),
        targetSounds: _strs(m['targetSounds'], 'targetSounds'),
        answer: ans,
        origin: _enum(AttemptOrigin.values, m['origin'], 'origin'),
        presentation: _enum(
            AttemptPresentation.values, m['presentation'], 'presentation'),
        assistance:
            _enumList(AssistanceFlag.values, m['assistance'], 'assistance')
                .toSet(),
        contentState: _enum(
            AttemptContentState.values, m['contentState'], 'contentState'),
        audioSource:
            _enum(AttemptAudioSource.values, m['audioSource'], 'audioSource'),
        correct: _bool(m['correct'], 'correct'));
  }

  Map<String, Object?> _answer(AttemptAnswer a) => switch (a) {
        final SoundChoiceAnswer x => {
            'answerKind': 'soundChoice',
            'selectedSound': x.selectedSound,
            'choices': x.choices,
            'expectedSound': x.expectedSound
          },
        final DrillChoiceAnswer x => {
            'answerKind': 'drillChoice',
            'selectedWord': x.selectedWord,
            'pairId': x.pairId,
            'choices': x.choices,
            'expectedWord': x.expectedWord
          },
        final SoundCueAnswer x => {
            'answerKind': 'soundCue',
            'selectedFamily': x.selectedFamily,
            'wordId': x.wordId,
            'expectedFamily': x.expectedFamily
          },
        final WordTileAnswer x => {
            'answerKind': 'wordTile',
            'wordId': x.wordId,
            'tileIndex': x.tileIndex,
            'targetSound': x.targetSound,
            'expectedMembership': x.expectedMembership
          }
      };

  Map<String, Object?> _cursor(SlotCursor c) => {
        'generation': c.generation,
        'sequence': c.sequence,
        'revision': c.revision
      };
  SlotCursor _readCursor(Object? v) {
    final m = _obj(v, 'cursor');
    _keys(m, {'generation', 'sequence', 'revision'}, 'cursor');
    return SlotCursor(
        generation: _int(m['generation'], 'generation'),
        sequence: _int(m['sequence'], 'sequence'),
        revision: _int(m['revision'], 'revision'));
  }

  Map<String, Object?> _slot(ActivitySlot s) => {
        'activityId': s.activityId,
        'kind': s.kind.name,
        'contentRevision': s.contentRevision,
        'cursor': _cursor(s.cursor),
        'options': s.options.policy.toJson(),
        'snapshot': _snapshot(s.snapshot),
        'exposures': s.exposures.entries
            .map((e) => {
                  'itemId': e.key.itemId,
                  'targetSound': e.key.targetSound,
                  'presentations': e.value.presentations,
                  'assistance': _enumSet(e.value.assistance)
                })
            .toList(),
        'latestReceipt': {
          'token': s.latestReceipt.token,
          'canonicalCommand': s.latestReceipt.canonicalCommand,
          'before': _cursor(s.latestReceipt.before),
          'after': _cursor(s.latestReceipt.after),
          'commitOrdinal': s.latestReceipt.commitOrdinal
        }
      };
  Map<String, ActivitySlot> _readActivities(Object? v) {
    final out = <String, ActivitySlot>{};
    for (final x in _arr(v, 'activities')) {
      final m = _obj(x, 'activity');
      _keys(
          m,
          {
            'activityId',
            'kind',
            'contentRevision',
            'cursor',
            'options',
            'snapshot',
            'exposures',
            'latestReceipt'
          },
          'activity');
      final id = _str(m['activityId'], 'activityId');
      final r = _obj(m['latestReceipt'], 'latestReceipt');
      final exp = <ItemContextKey, ItemExposure>{};
      for (final q in _arr(m['exposures'], 'exposures')) {
        final e = _obj(q, 'exposure');
        _keys(e, {'itemId', 'targetSound', 'presentations', 'assistance'},
            'exposure');
        final k = ItemContextKey(
            itemId: _str(e['itemId'], 'itemId'),
            targetSound: _str(e['targetSound'], 'targetSound'));
        if (exp.containsKey(k)) {
          throw const FormatException('duplicate exposure');
        }
        exp[k] = ItemExposure(
            presentations: _int(e['presentations'], 'presentations'),
            assistance:
                _enumList(AssistanceFlag.values, e['assistance'], 'assistance')
                    .toSet());
      }
      if (out.containsKey(id)) {
        throw const FormatException('duplicate activity');
      }
      final receipt = r;
      _keys(
          receipt,
          {'token', 'canonicalCommand', 'before', 'after', 'commitOrdinal'},
          'latestReceipt');
      final options = _obj(m['options'], 'options');
      _keys(options, {'completionThresholdPercent'}, 'options');
      out[id] = ActivitySlot(
          activityId: id,
          kind: _enum(LearningActivityKind.values, m['kind'], 'kind'),
          contentRevision: _int(m['contentRevision'], 'contentRevision'),
          cursor: _readCursor(m['cursor']),
          options: RunOptions(
              policy: LessonPolicy.fromJson(_obj(m['options'], 'options'))),
          snapshot: _readSnapshot(_obj(m['snapshot'], 'snapshot')),
          exposures: exp,
          latestReceipt: CommandReceipt(
              token: _str(r['token'], 'token'),
              canonicalCommand: _str(r['canonicalCommand'], 'canonicalCommand'),
              before: _readCursor(r['before']),
              after: _readCursor(r['after']),
              commitOrdinal: _int(r['commitOrdinal'], 'commitOrdinal')));
    }
    return out;
  }

  Map<String, Object?> _snapshot(ActivitySnapshot s) => switch (s) {
        final DiscoveryCheckpoint x => {
            'kind': 'discovery',
            'session': x.session.toJson()
          },
        final LegacyLessonCheckpoint x => {
            'kind': 'legacyLesson',
            'wordIndex': x.wordIndex,
            'selectedSound': x.selectedSound,
            'finished': x.finished
          },
        final DrillCheckpoint x => {
            'kind': 'drill',
            'pairIds': x.pairIds,
            'index': x.index,
            'correct': x.correct,
            'ended': x.ended
          },
        final SoundGameCheckpoint x => {
            'kind': 'soundGame',
            'board': {'board': x.board.board, 'stars': _sorted(x.board.stars)},
            'clock': _clock(x.clock)
          },
        final WordGameCheckpoint x => {
            'kind': 'wordGame',
            'board': {
              'board': x.board.board,
              'target': x.board.target,
              'moves': x.board.moves,
              'combo': x.board.combo,
              'stars': _sorted(x.board.stars),
              'obstacles': _sorted(x.board.obstacles)
            },
            'clock': _clock(x.clock)
          },
      };
  Map<String, Object?> _clock(ArcadeClockState c) => {
        'remaining': c.remaining,
        'round': c.round,
        'score': c.score,
        'paused': c.paused
      };
  ActivitySnapshot _readSnapshot(Map<String, Object?> m) {
    switch (_str(m['kind'], 'snapshot.kind')) {
      case 'discovery':
        _keys(m, {'kind', 'session'}, 'discovery snapshot');
        final session = _obj(m['session'], 'session');
        _keys(
            session,
            {
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
            },
            'session');
        final policy = _obj(session['policy'], 'session.policy');
        _keys(policy, {'completionThresholdPercent'}, 'session.policy');
        final ids = _strs(session['itemIds'], 'itemIds');
        return DiscoveryCheckpoint(
            session: LessonSectionSession.fromJson(session,
                itemIds: ids,
                contentRevision:
                    _int(session['contentRevision'], 'contentRevision')));
      case 'legacyLesson':
        _keys(m, {'kind', 'wordIndex', 'selectedSound', 'finished'},
            'legacyLesson snapshot');
        return LegacyLessonCheckpoint(
            wordIndex: _int(m['wordIndex'], 'wordIndex'),
            selectedSound: m['selectedSound'] == null
                ? null
                : _str(m['selectedSound'], 'selectedSound'),
            finished: _bool(m['finished'], 'finished'));
      case 'drill':
        _keys(m, {'kind', 'pairIds', 'index', 'correct', 'ended'},
            'drill snapshot');
        return DrillCheckpoint(
            pairIds: _strs(m['pairIds'], 'pairIds'),
            index: _int(m['index'], 'index'),
            correct: _int(m['correct'], 'correct'),
            ended: _bool(m['ended'], 'ended'));
      case 'soundGame':
        _keys(m, {'kind', 'board', 'clock'}, 'soundGame snapshot');
        final b = _obj(m['board'], 'board');
        _keys(b, {'board', 'stars'}, 'sound board');
        return SoundGameCheckpoint(
            board: SoundBoardState(
                board: _strs(b['board'], 'board'),
                stars: _intSet(b['stars'], 'stars')),
            clock: _readClock(_obj(m['clock'], 'clock')));
      case 'wordGame':
        _keys(m, {'kind', 'board', 'clock'}, 'wordGame snapshot');
        final b = _obj(m['board'], 'board');
        _keys(b, {'board', 'target', 'moves', 'combo', 'stars', 'obstacles'},
            'word board');
        return WordGameCheckpoint(
            board: WordBoardState(
                board: _strs(b['board'], 'board'),
                target: _str(b['target'], 'target'),
                moves: _int(b['moves'], 'moves'),
                combo: _int(b['combo'], 'combo'),
                stars: _intSet(b['stars'], 'stars'),
                obstacles: _intSet(b['obstacles'], 'obstacles')),
            clock: _readClock(_obj(m['clock'], 'clock')));
      default:
        throw const FormatException('unknown snapshot kind');
    }
  }

  ArcadeClockState _readClock(Map<String, Object?> m) {
    _keys(m, {'remaining', 'round', 'score', 'paused'}, 'clock');
    return ArcadeClockState(
        remaining: _int(m['remaining'], 'remaining'),
        round: _int(m['round'], 'round'),
        score: _int(m['score'], 'score'),
        paused: _bool(m['paused'], 'paused'));
  }

  Map<String, Object?> _mistake(LearningMistake x) => {
        'key': {
          'activityId': x.key.activityId,
          'itemId': x.key.itemId,
          'contentRevision': x.key.contentRevision,
          'skill': x.key.skill.name,
          'targetSound': x.key.targetSound
        },
        'firstWrongId': x.firstWrongId,
        'firstWrongAt': _dateJson(x.firstWrongAt),
        'latestWrongId': x.latestWrongId,
        'latestWrongAt': _dateJson(x.latestWrongAt),
        'failureCount': x.failureCount,
        'lastRunGeneration': x.lastRunGeneration
      };
  Map<MistakeKey, LearningMistake> _readMistakes(Object? v) {
    final out = <MistakeKey, LearningMistake>{};
    for (final x in _arr(v, 'mistakes')) {
      final m = _obj(x, 'mistake');
      _keys(
          m,
          {
            'key',
            'firstWrongId',
            'firstWrongAt',
            'latestWrongId',
            'latestWrongAt',
            'failureCount',
            'lastRunGeneration'
          },
          'mistake');
      final k = _obj(m['key'], 'key');
      _keys(
          k,
          {'activityId', 'itemId', 'contentRevision', 'skill', 'targetSound'},
          'mistake.key');
      final key = MistakeKey(
          activityId: _str(k['activityId'], 'activityId'),
          itemId: _str(k['itemId'], 'itemId'),
          contentRevision: _int(k['contentRevision'], 'contentRevision'),
          skill: _enum(LearningSkill.values, k['skill'], 'skill'),
          targetSound: _str(k['targetSound'], 'targetSound'));
      if (out.containsKey(key)) {
        throw const FormatException('duplicate mistake');
      }
      out[key] = LearningMistake(
          key: key,
          firstWrongId: _str(m['firstWrongId'], 'firstWrongId'),
          firstWrongAt: _date(m['firstWrongAt'], 'firstWrongAt'),
          latestWrongId: _str(m['latestWrongId'], 'latestWrongId'),
          latestWrongAt: _date(m['latestWrongAt'], 'latestWrongAt'),
          failureCount: _int(m['failureCount'], 'failureCount'),
          lastRunGeneration: _int(m['lastRunGeneration'], 'lastRunGeneration'));
    }
    return out;
  }

  Map<String, Object?> _summaryKey(SummaryKey k) => {
        'sound': k.sound,
        'skill': k.skill.name,
        'origin': k.origin.name,
        'presentation': k.presentation.name,
        'assistance': _enumSet(k.assistance)
      };
  Map<String, Object?> _countJson(SkillCount c) =>
      {'total': c.total, 'correct': c.correct};
  Map<SummaryKey, SkillCount> _readSummaries(Object? v) {
    final out = <SummaryKey, SkillCount>{};
    for (final x in _arr(v, 'summaries')) {
      final m = _obj(x, 'summary');
      _keys(m, {'key', 'count'}, 'summary');
      final k = _obj(m['key'], 'key');
      _keys(k, {'sound', 'skill', 'origin', 'presentation', 'assistance'},
          'summary.key');
      final key = SummaryKey(
          sound: _str(k['sound'], 'sound'),
          skill: _enum(LearningSkill.values, k['skill'], 'skill'),
          origin: _enum(AttemptOrigin.values, k['origin'], 'origin'),
          presentation: _enum(
              AttemptPresentation.values, k['presentation'], 'presentation'),
          assistance:
              _enumList(AssistanceFlag.values, k['assistance'], 'assistance')
                  .toSet());
      if (out.containsKey(key)) {
        throw const FormatException('duplicate summary');
      }
      final n = _obj(m['count'], 'count');
      _keys(n, {'total', 'correct'}, 'summary.count');
      out[key] = SkillCount(
          total: _int(n['total'], 'total'),
          correct: _int(n['correct'], 'correct'));
    }
    return out;
  }

  Map<String, Object?> _completion(LearningCompletion x) => {
        'lessonId': x.lessonId,
        'contentRevision': x.contentRevision,
        'policyKind': x.policyKind.name,
        'policyRevision': x.policyRevision,
        'thresholdPercent': x.thresholdPercent,
        'committedAt': _dateJson(x.committedAt)
      };
  LearningCompletion _readCompletion(Map<String, Object?> m) {
    _keys(
        m,
        {
          'lessonId',
          'contentRevision',
          'policyKind',
          'policyRevision',
          'thresholdPercent',
          'committedAt'
        },
        'completion');
    return LearningCompletion(
        lessonId: _str(m['lessonId'], 'lessonId'),
        contentRevision: _int(m['contentRevision'], 'contentRevision'),
        policyKind:
            _enum(CompletionPolicyKind.values, m['policyKind'], 'policyKind'),
        policyRevision: _int(m['policyRevision'], 'policyRevision'),
        thresholdPercent: m['thresholdPercent'] == null
            ? null
            : _int(m['thresholdPercent'], 'thresholdPercent'),
        committedAt: _date(m['committedAt'], 'committedAt'));
  }

  Map<String, Object?> _event(SupportedCloudEvent e) => {
        'id': e.id,
        'userId': e.userId,
        'courseId': e.courseId,
        'payload': switch (e.payload) {
          final CloudAnswer x => {
              'kind': 'answer',
              'sound': x.sound,
              'skill': x.skill.name,
              'correct': x.correct,
              'activity': x.activity
            },
          final CloudLesson x => {'kind': 'lesson', 'lessonId': x.lessonId},
          final CloudScore x => {
              'kind': 'score',
              'game': x.game,
              'score': x.score
            }
        }
      };
  SupportedCloudEvent _readEvent(Map<String, Object?> m) {
    _keys(m, {'id', 'userId', 'courseId', 'payload'}, 'event');
    final p = _obj(m['payload'], 'payload');
    final payloadKind = _str(p['kind'], 'payload.kind');
    _keys(
        p,
        switch (payloadKind) {
          'answer' => {'kind', 'sound', 'skill', 'correct', 'activity'},
          'lesson' => {'kind', 'lessonId'},
          'score' => {'kind', 'game', 'score'},
          _ => throw const FormatException('unknown cloud payload kind')
        },
        'payload');
    final payload = switch (payloadKind) {
      'answer' => CloudAnswer(
          sound: _str(p['sound'], 'sound'),
          skill: _enum(LearningSkill.values, p['skill'], 'skill'),
          correct: _bool(p['correct'], 'correct'),
          activity: _str(p['activity'], 'activity')),
      'lesson' => CloudLesson(lessonId: _str(p['lessonId'], 'lessonId')),
      'score' => CloudScore(
          game: _str(p['game'], 'game'), score: _int(p['score'], 'score')),
      _ => throw const FormatException('unknown cloud payload kind')
    };
    return SupportedCloudEvent(
        id: _str(m['id'], 'id'),
        userId: _str(m['userId'], 'userId'),
        courseId: _str(m['courseId'], 'courseId'),
        payload: payload);
  }

  Map<String, int> _readScores(Object? v) {
    final m = _obj(v, 'bestScores');
    final out = <String, int>{};
    for (final e in m.entries) {
      if (e.value is! int) {
        throw FormatException('score ${e.key} must be integer');
      }
      out[e.key] = _int(e.value, e.key);
    }
    return out;
  }

  Map<String, Object?> _action(LearningAction a) => switch (a) {
        final StartLearningRun x => {
            'kind': 'startRun',
            'options': x.options.policy.toJson()
          },
        final ChooseSound x => {
            'kind': 'chooseSound',
            'selectedSound': x.selectedSound,
            'audioSource': x.audioSource.name
          },
        final ChooseDrillWord x => {
            'kind': 'chooseDrillWord',
            'selectedWord': x.selectedWord,
            'audioSource': x.audioSource.name
          },
        AdvanceLesson _ => {'kind': 'advanceLesson'},
        ReviewDiscoveryMistakes _ => {'kind': 'reviewDiscoveryMistakes'},
        final ObserveAssistance x => {
            'kind': 'observeAssistance',
            'items': x.items
                .map((e) => {'itemId': e.itemId, 'targetSound': e.targetSound})
                .toList()
              ..sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b))),
            'flags': _enumSet(x.flags)
          },
        final FinishLearningActivity x => {
            'kind': 'finishLearningActivity',
            'recordCompletion': x.recordCompletion
          },
        EndDrill _ => {'kind': 'endDrill'},
        final SwapSoundTiles x => {
            'kind': 'swapSoundTiles',
            'first': x.first,
            'second': x.second,
            'cue': x.cue == null
                ? null
                : {
                    'wordId': x.cue!.wordId,
                    'targetSound': x.cue!.targetSound,
                    'audioSource': x.cue!.audioSource.name
                  },
            'elapsedSeconds': x.elapsedSeconds
          },
        final LinkWordTiles x => {
            'kind': 'linkWordTiles',
            'indices': x.indices,
            'elapsedSeconds': x.elapsedSeconds
          },
        final CheckpointArcade x => {
            'kind': 'checkpointArcade',
            'elapsedSeconds': x.elapsedSeconds,
            'paused': x.paused
          },
        ContinueArcadeRound _ => {'kind': 'continueArcadeRound'}
      };
  void _validateState(CourseLearningState s) {
    final batchIdentities = <String>{};
    for (final b in s.history) {
      final identity =
          jsonEncode([b.activityId, b.generation, b.sequence, b.token]);
      if (!batchIdentities.add(identity)) {
        throw const FormatException('duplicate attempt batch identity');
      }
      for (final a in b.attempts) {
        if (a.activityId != b.activityId ||
            a.runGeneration != b.generation ||
            a.commandSequence != b.sequence ||
            a.commitOrdinal > s.commitOrdinal) {
          throw const FormatException('batch/attempt identity mismatch');
        }
      }
    }
  }
}

Object? _sort(Object? v) {
  if (v is Map) {
    final keys = v.keys.cast<String>().toList()..sort();
    return {for (final k in keys) k: _sort(v[k])};
  }
  if (v is List) return v.map(_sort).toList();
  return v;
}

List<int> _sorted(Set<int> x) => x.toList()..sort();
List<String> _enumSet<T extends Enum>(Set<T> x) =>
    x.map((e) => e.name).toList()..sort();
List<Object?> _arr(Object? v, String n) =>
    v is List ? v : throw FormatException('$n must be a list');
Map<String, Object?> _obj(Object? v, String n) =>
    v is Map && v.keys.every((k) => k is String)
        ? Map<String, Object?>.from(v)
        : throw FormatException('$n must be an object');
void _keys(Map<String, Object?> value, Set<String> expected, String name) {
  final actual = value.keys.toSet();
  if (actual.length != expected.length || !actual.containsAll(expected)) {
    final unknown = actual.difference(expected);
    final missing = expected.difference(actual);
    throw FormatException(
        '$name has an invalid field set (unknown: $unknown, missing: $missing)');
  }
}

String _str(Object? v, String n) => v is String && v.trim().isNotEmpty
    ? v
    : throw FormatException('$n must be a nonblank string');
bool _bool(Object? v, String n) =>
    v is bool ? v : throw FormatException('$n must be boolean');
int _int(Object? v, String n) => v is int && v >= 0 && v <= 9007199254740991
    ? v
    : throw FormatException('$n must be a supported nonnegative integer');
List<String> _strs(Object? v, String n) =>
    _arr(v, n).map((x) => _str(x, n)).toList();
Set<int> _intSet(Object? v, String n) {
  final list = _arr(v, n).map((x) => _int(x, n)).toList();
  if (list.toSet().length != list.length) {
    throw FormatException('$n has duplicates');
  }
  return list.toSet();
}

List<T> _enumList<T extends Enum>(List<T> values, Object? v, String n) {
  final list = _arr(v, n).map((x) => _enum(values, x, n)).toList();
  if (list.toSet().length != list.length) {
    throw FormatException('$n has duplicates');
  }
  return list;
}

T _enum<T extends Enum>(List<T> values, Object? v, String n) {
  for (final value in values) {
    if (value.name == v) return value;
  }
  throw FormatException('invalid $n');
}

DateTime _date(Object? v, String n) {
  if (v is! String) throw FormatException('$n must be timestamp');
  final d = DateTime.tryParse(v);
  if (d == null || !v.endsWith('Z')) {
    throw FormatException('$n must be a valid UTC timestamp');
  }
  return d.toUtc();
}

String _dateJson(DateTime x) => x.toUtc().toIso8601String();
