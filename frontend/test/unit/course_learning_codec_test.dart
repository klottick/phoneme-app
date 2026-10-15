import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_codec.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/course_skill_summary.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import '../support/course_learning_fixtures.dart';

void main() {
  const codec = LearningDocumentCodec();
  test('round trip preserves exact selected and expected answer', () {
    final state = sampleState();
    final decoded = codec.decode(codec.encode(state), guestScope);
    final attempt = decoded.history.single.attempts.single;
    expect(attempt.answer, isA<SoundChoiceAnswer>());
    expect((attempt.answer as SoundChoiceAnswer).selectedSound, 'sh');
    expect((attempt.answer as SoundChoiceAnswer).expectedSound, 's');
    expect(attempt.scope, guestScope);
    expect(decoded.revision, state.revision);
  });
  test('round trip preserves populated score summary and activity record', () {
    final fixture = sampleState();
    final state = CourseLearningState(
      scope: fixture.scope,
      revision: fixture.revision,
      commitOrdinal: fixture.commitOrdinal,
      history: fixture.history,
      activities: {
        'lesson:sample': sampleActivitySlot(),
      },
      mistakes: fixture.mistakes,
      summaries: fixture.summaries,
      completions: fixture.completions,
      bestScores: {'sound': 7},
      pending: fixture.pending,
    );
    final decoded = codec.decode(codec.encode(state), guestScope);
    expect(decoded.activities.keys, ['lesson:sample']);
    expect(decoded.bestScores['sound'], 7);
  });
  test('round trip preserves every nonempty state section and nested values',
      () {
    final base = sampleState();
    final key = MistakeKey(
        activityId: 'lesson:sample',
        itemId: 'item-0',
        contentRevision: 1,
        skill: LearningSkill.listening,
        targetSound: 's');
    final summary = SummaryKey(
        sound: 's',
        skill: LearningSkill.listening,
        origin: AttemptOrigin.practice,
        presentation: AttemptPresentation.firstInRun,
        assistance: const {AssistanceFlag.graphemeHint});
    final state = CourseLearningState(
        scope: guestScope,
        revision: 1,
        commitOrdinal: 1,
        history: base.history,
        activities: {
          'lesson:sample': ActivitySlot(
              activityId: 'lesson:sample',
              kind: LearningActivityKind.discovery,
              contentRevision: 1,
              cursor: SlotCursor(generation: 1, sequence: 1, revision: 1),
              options: RunOptions(),
              snapshot: DiscoveryCheckpoint(
                  session: LessonSectionSession(
                      itemIds: const ['item-0'], sessionId: 's1')),
              exposures: {
                ItemContextKey(itemId: 'item-0', targetSound: 's'):
                    ItemExposure(
                        presentations: 2,
                        assistance: const {AssistanceFlag.graphemeHint})
              },
              latestReceipt: CommandReceipt(
                  token: tokenFor(2),
                  canonicalCommand: 'c',
                  before: SlotCursor(generation: 1, sequence: 0, revision: 0),
                  after: SlotCursor(generation: 1, sequence: 1, revision: 1),
                  commitOrdinal: 1))
        },
        mistakes: {
          key: LearningMistake(
              key: key,
              firstWrongId: 'one',
              firstWrongAt: fixedTime,
              latestWrongId: 'two',
              latestWrongAt: fixedTime,
              failureCount: 2,
              lastRunGeneration: 1)
        },
        summaries: {
          summary: SkillCount(total: 3, correct: 2)
        },
        completions: [
          LearningCompletion(
              lessonId: 'lesson:sample',
              contentRevision: 1,
              policyKind: CompletionPolicyKind.discoveryThreshold,
              policyRevision: 1,
              thresholdPercent: 80,
              committedAt: fixedTime)
        ],
        bestScores: {
          'sound': 7
        },
        pending: const []);
    final restored = codec.decode(codec.encode(state), guestScope);
    expect(
        restored
            .activities['lesson:sample']!.exposures.values.single.presentations,
        2);
    expect(restored.mistakes[key]!.failureCount, 2);
    expect(restored.summaries[summary]!.correct, 2);
    expect(restored.completions.single.thresholdPercent, 80);
    expect(restored.bestScores, {'sound': 7});
  });
  test('round trips all answer variants without losing subtype fields', () {
    final source = _stateWithAttempts([
      _attempt(
          answer: SoundChoiceAnswer(
              selectedSound: 'sh',
              choices: const ['s', 'sh'],
              expectedSound: 's'),
          index: 0),
      _attempt(
          answer: DrillChoiceAnswer(
              selectedWord: 'chat',
              pairId: 'p1',
              choices: const ['chat', 'rat'],
              expectedWord: 'rat'),
          index: 1),
      _attempt(
          answer: SoundCueAnswer(
              selectedFamily: 'sh', wordId: 'chat', expectedFamily: 's'),
          index: 2),
      _attempt(
          answer: WordTileAnswer(
              wordId: 'chat',
              tileIndex: 7,
              targetSound: 'sh',
              expectedMembership: true),
          index: 3),
    ]);
    final attempts =
        codec.decode(codec.encode(source), guestScope).history.single.attempts;
    expect(attempts[0].answer, isA<SoundChoiceAnswer>());
    expect((attempts[0].answer as SoundChoiceAnswer).choices, ['s', 'sh']);
    expect((attempts[0].answer as SoundChoiceAnswer).selectedSound, 'sh');
    expect((attempts[0].answer as SoundChoiceAnswer).expectedSound, 's');
    expect(attempts[1].answer, isA<DrillChoiceAnswer>());
    expect((attempts[1].answer as DrillChoiceAnswer).pairId, 'p1');
    expect((attempts[1].answer as DrillChoiceAnswer).selectedWord, 'chat');
    expect((attempts[1].answer as DrillChoiceAnswer).expectedWord, 'rat');
    expect(attempts[2].answer, isA<SoundCueAnswer>());
    expect((attempts[2].answer as SoundCueAnswer).wordId, 'chat');
    expect((attempts[2].answer as SoundCueAnswer).selectedFamily, 'sh');
    expect((attempts[2].answer as SoundCueAnswer).expectedFamily, 's');
    expect(attempts[3].answer, isA<WordTileAnswer>());
    expect((attempts[3].answer as WordTileAnswer).tileIndex, 7);
    expect((attempts[3].answer as WordTileAnswer).expectedMembership, isTrue);
  });
  test('round trips all five checkpoint shapes and their nested fields', () {
    final state = CourseLearningState(
        scope: guestScope,
        revision: 1,
        commitOrdinal: 1,
        history: sampleState().history,
        activities: {
          'd': _slot(
              'd',
              LearningActivityKind.discovery,
              DiscoveryCheckpoint(
                  session: LessonSectionSession(
                      itemIds: const ['i'], sessionId: 'discovery'))),
          'l': _slot(
              'l',
              LearningActivityKind.legacyLesson,
              const LegacyLessonCheckpoint(
                  wordIndex: 2, selectedSound: 's', finished: true)),
          'r': _slot(
              'r',
              LearningActivityKind.drill,
              DrillCheckpoint(
                  pairIds: const ['p1', 'p2'],
                  index: 1,
                  correct: 1,
                  ended: false)),
          's': _slot(
              's',
              LearningActivityKind.soundGame,
              SoundGameCheckpoint(
                  board: SoundBoardState(
                      board: List.filled(36, 'sound'), stars: const {3, 11}),
                  clock: ArcadeClockState(
                      remaining: 42, round: 2, score: 9, paused: true))),
          'w': _slot(
              'w',
              LearningActivityKind.wordGame,
              WordGameCheckpoint(
                  board: WordBoardState(
                      board: List.filled(16, 'word'),
                      target: 'ou',
                      moves: 5,
                      combo: 2,
                      stars: const {4},
                      obstacles: const {9}),
                  clock: ArcadeClockState(
                      remaining: 37, round: 3, score: 12, paused: true))),
        },
        mistakes: const {},
        summaries: const {},
        completions: const [],
        bestScores: const {},
        pending: const []);
    final restored = codec.decode(codec.encode(state), guestScope);
    final discovery =
        (restored.activities['d']!.snapshot as DiscoveryCheckpoint).session;
    expect(discovery.sessionId, 'discovery');
    expect(discovery.itemIds, ['i']);
    final legacy = restored.activities['l']!.snapshot as LegacyLessonCheckpoint;
    expect((legacy.wordIndex, legacy.selectedSound, legacy.finished),
        (2, 's', true));
    final drill = restored.activities['r']!.snapshot as DrillCheckpoint;
    expect(drill.pairIds, ['p1', 'p2']);
    expect((drill.index, drill.correct, drill.ended), (1, 1, false));
    final sound = restored.activities['s']!.snapshot as SoundGameCheckpoint;
    expect(sound.board.board.length, 36);
    expect(sound.board.board.first, 'sound');
    expect(sound.board.stars, {3, 11});
    expect((
      sound.clock.remaining,
      sound.clock.round,
      sound.clock.score,
      sound.clock.paused
    ), (
      42,
      2,
      9,
      true
    ));
    final word = restored.activities['w']!.snapshot as WordGameCheckpoint;
    expect(word.board.board.length, 16);
    expect(word.board.target, 'ou');
    expect((word.board.moves, word.board.combo), (5, 2));
    expect(word.board.stars, {4});
    expect(word.board.obstacles, {9});
    expect((
      word.clock.remaining,
      word.clock.round,
      word.clock.score,
      word.clock.paused
    ), (
      37,
      3,
      12,
      true
    ));
  });
  test('round trips all supported cloud payloads under account scope', () {
    final scoped = sampleState(scope: accountAScope);
    final events = <SupportedCloudEvent>[
      SupportedCloudEvent(
          id: 'a',
          userId: accountAScope.owner.userId!,
          courseId: 'en-fr',
          payload: CloudAnswer(
              sound: 's',
              skill: LearningSkill.listening,
              correct: true,
              activity: 'lesson:x')),
      SupportedCloudEvent(
          id: 'l',
          userId: accountAScope.owner.userId!,
          courseId: 'en-fr',
          payload: CloudLesson(lessonId: 'lesson:x')),
      SupportedCloudEvent(
          id: 's',
          userId: accountAScope.owner.userId!,
          courseId: 'en-fr',
          payload: CloudScore(game: 'sound', score: 23)),
    ];
    final state = CourseLearningState(
        scope: scoped.scope,
        revision: 1,
        commitOrdinal: 1,
        history: scoped.history,
        activities: const {},
        mistakes: const {},
        summaries: const {},
        completions: const [],
        bestScores: const {},
        pending: events);
    final restored = codec.decode(codec.encode(state), accountAScope);
    expect(restored.pending.map((e) => (e.id, e.userId, e.courseId)), [
      ('a', accountAScope.owner.userId, 'en-fr'),
      ('l', accountAScope.owner.userId, 'en-fr'),
      ('s', accountAScope.owner.userId, 'en-fr')
    ]);
    expect((restored.pending[0].payload as CloudAnswer).correct, isTrue);
    expect((restored.pending[1].payload as CloudLesson).lessonId, 'lesson:x');
    expect((restored.pending[2].payload as CloudScore).score, 23);
  });
  test('rejects unknown enums and duplicate composite collection entries', () {
    final raw = codec.encode(_validationState());
    final unknownEnum = _copyJson(raw);
    unknownEnum['history'][0]['attempts'][0]['skill'] = 'speaking';
    _expectCorrupt(unknownEnum);
    final unknownActivityKind = _copyJson(raw);
    unknownActivityKind['activities'][0]['kind'] = 'futureLesson';
    _expectCorrupt(unknownActivityKind);

    for (final section in ['activities', 'mistakes', 'summaries']) {
      final duplicate = _copyJson(raw);
      duplicate[section].add(jsonDecode(jsonEncode(duplicate[section].first)));
      _expectCorrupt(duplicate);
    }
    final duplicateExposure = _copyJson(raw);
    final exposures = duplicateExposure['activities'][0]['exposures'] as List;
    exposures.add(jsonDecode(jsonEncode(exposures.first)));
    _expectCorrupt(duplicateExposure);
    final duplicateFlag = _copyJson(raw);
    duplicateFlag['history'][0]['attempts'][0]
        ['assistance'] = ['graphemeHint', 'graphemeHint'];
    _expectCorrupt(duplicateFlag);
    final duplicateBatch = _copyJson(raw);
    duplicateBatch['history']
        .add(jsonDecode(jsonEncode(duplicateBatch['history'].first)));
    _expectCorrupt(duplicateBatch);
    final unknownPayload = _copyJson(raw);
    unknownPayload['pending'][0]['payload']['kind'] = 'speaking';
    _expectCorrupt(unknownPayload);
  });
  test('rejects unknown fields at typed persisted-object boundaries', () {
    final valid = _copyJson(codec.encode(_validationState()));
    final paths = <List<Object>>[
      [],
      ['owner'],
      ['history', 0],
      ['history', 0, 'attempts', 0],
      ['history', 0, 'attempts', 0, 'answer'],
      ['activities', 0],
      ['activities', 0, 'cursor'],
      ['activities', 0, 'options'],
      ['activities', 0, 'snapshot'],
      ['activities', 0, 'snapshot', 'session'],
      ['activities', 0, 'snapshot', 'session', 'policy'],
      ['activities', 0, 'latestReceipt'],
      ['activities', 0, 'latestReceipt', 'before'],
      ['activities', 0, 'exposures', 0],
      ['mistakes', 0],
      ['mistakes', 0, 'key'],
      ['summaries', 0],
      ['summaries', 0, 'key'],
      ['summaries', 0, 'count'],
      ['completions', 0],
      ['pending', 0],
      ['pending', 0, 'payload'],
    ];
    for (final path in paths) {
      final copy = jsonDecode(jsonEncode(valid)) as Map<String, dynamic>;
      _injectUnknownField(copy, path);
      expect(() => codec.decode(jsonEncode(copy), accountAScope),
          throwsA(isA<LearningCorruptException>()),
          reason: 'unknown field at ${path.join('/')}');
    }

    final answerVariants = <AttemptAnswer>[
      SoundChoiceAnswer(
          selectedSound: 'sh', choices: const ['s', 'sh'], expectedSound: 's'),
      DrillChoiceAnswer(
          selectedWord: 'chat',
          pairId: 'pair',
          choices: const ['chat'],
          expectedWord: 'chat'),
      SoundCueAnswer(selectedFamily: 'sh', wordId: 'chat', expectedFamily: 's'),
      WordTileAnswer(
          wordId: 'chat',
          tileIndex: 2,
          targetSound: 'sh',
          expectedMembership: true),
    ];
    for (final answer in answerVariants) {
      final copy = _copyJson(codec
          .encode(_stateWithAttempts([_attempt(answer: answer, index: 0)])));
      _injectUnknownField(copy, ['history', 0, 'attempts', 0, 'answer']);
      _expectCorrupt(copy, scope: guestScope);
    }

    final snapshots = <ActivitySnapshot>[
      DiscoveryCheckpoint(
          session:
              LessonSectionSession(itemIds: const ['i'], sessionId: 'strict')),
      const LegacyLessonCheckpoint(wordIndex: 0, finished: false),
      DrillCheckpoint(pairIds: const ['p'], index: 0, correct: 0, ended: false),
      SoundGameCheckpoint(
          board: SoundBoardState(board: List.filled(36, 's'), stars: const {}),
          clock: ArcadeClockState(
              remaining: 60, round: 1, score: 0, paused: true)),
      WordGameCheckpoint(
          board: WordBoardState(
              board: List.filled(16, 'w'),
              target: 's',
              moves: 0,
              combo: 0,
              stars: const {},
              obstacles: const {}),
          clock: ArcadeClockState(
              remaining: 60, round: 1, score: 0, paused: true)),
    ];
    for (final snapshot in snapshots) {
      final copy = _copyJson(codec.encode(_stateWithSnapshot(snapshot)));
      _injectUnknownField(copy, ['activities', 0, 'snapshot']);
      _expectCorrupt(copy, scope: guestScope);
    }
    for (final snapshot in [snapshots[3], snapshots[4]]) {
      for (final nestedPath in [
        ['activities', 0, 'snapshot', 'board'],
        ['activities', 0, 'snapshot', 'clock'],
      ]) {
        final copy =
            _copyJson(codec.encode(_stateWithSnapshot(snapshot)));
        _injectUnknownField(copy, nestedPath);
        _expectCorrupt(copy, scope: guestScope);
      }
    }

    for (final kind in ['lesson', 'score']) {
      final copy = _copyJson(codec.encode(_validationState()));
      copy['pending'][0]['payload'] = kind == 'lesson'
          ? {'kind': 'lesson', 'lessonId': 'lesson:sample'}
          : {'kind': 'score', 'game': 'sound', 'score': 1};
      _injectUnknownField(copy, ['pending', 0, 'payload']);
      _expectCorrupt(copy);
    }

    final dynamicScore = _copyJson(codec.encode(_validationState()));
    dynamicScore['bestScores']['game:season-7'] = 42;
    expect(codec.decode(jsonEncode(dynamicScore), accountAScope).bestScores,
        containsPair('game:season-7', 42));
    final invalidSessionDataKey = _copyJson(codec.encode(_validationState()));
    invalidSessionDataKey['activities'][0]['snapshot']['session']
        ['latestAnswers']['not-an-item'] = true;
    _expectCorrupt(invalidSessionDataKey);
  });
  test('rejects mismatched nested scope receipts counters and batch identity',
      () {
    final raw = codec.encode(_validationState());
    final receipt = _copyJson(raw);
    receipt['activities'][0]['latestReceipt']['after']['sequence'] = 2;
    _expectCorrupt(receipt);
    final ordinal = _copyJson(raw);
    ordinal['commitOrdinal'] = 0;
    _expectCorrupt(ordinal);
    final batch = _copyJson(raw);
    batch['history'][0]['sequence'] = 2;
    _expectCorrupt(batch);
    final batchActivity = _copyJson(raw);
    batchActivity['history'][0]['activityId'] = 'lesson:other';
    _expectCorrupt(batchActivity);
    final attemptOrdinal = _copyJson(raw);
    attemptOrdinal['history'][0]['attempts'][0]['commitOrdinal'] = 2;
    _expectCorrupt(attemptOrdinal);
    final eventOwner = _copyJson(raw);
    eventOwner['pending'][0]['userId'] = 'some-other-account';
    _expectCorrupt(eventOwner, scope: accountAScope);
    final eventCourse = _copyJson(raw);
    eventCourse['pending'][0]['courseId'] = 'other-course';
    _expectCorrupt(eventCourse, scope: accountAScope);
    expect(() => const LearningDocumentCodec().decode(raw, guestScope),
        throwsA(isA<LearningCorruptException>()));
  });
  test('unsupported version never becomes empty progress', () {
    expect(() => codec.decode('{"schemaVersion":99}', guestScope),
        throwsA(isA<LearningUnsupportedVersionException>()));
  });
  test('strictly rejects malformed integers timestamps and answer kinds', () {
    final encoded =
        jsonDecode(codec.encode(sampleState())) as Map<String, dynamic>;
    for (final Object bad in [1.0, '1', -1, 9007199254740992]) {
      final copy = jsonDecode(jsonEncode(encoded)) as Map<String, dynamic>;
      copy['history'][0]['attempts'][0]['itemOccurrence'] = bad;
      expect(() => codec.decode(jsonEncode(copy), guestScope),
          throwsA(isA<LearningCorruptException>()));
    }
    final badTime = jsonDecode(jsonEncode(encoded)) as Map<String, dynamic>;
    badTime['history'][0]['attempts'][0]['answeredAt'] = 'not-a-time';
    expect(() => codec.decode(jsonEncode(badTime), guestScope),
        throwsA(isA<LearningCorruptException>()));
    final badKind = jsonDecode(jsonEncode(encoded)) as Map<String, dynamic>;
    badKind['history'][0]['attempts'][0]['answer']['answerKind'] = 'future';
    expect(() => codec.decode(jsonEncode(badKind), guestScope),
        throwsA(isA<LearningCorruptException>()));
    final wrongType = _copyJson(codec.encode(sampleState()));
    wrongType['history'][0]['attempts'][0]['correct'] = 0;
    _expectCorrupt(wrongType, scope: guestScope);
    final wrongAnswerFieldType = _copyJson(codec.encode(sampleState()));
    wrongAnswerFieldType['history'][0]['attempts'][0]['answer']['choices'] =
        's,sh';
    _expectCorrupt(wrongAnswerFieldType, scope: guestScope);
    final nonUtc = _copyJson(codec.encode(sampleState()));
    nonUtc['history'][0]['attempts'][0]['answeredAt'] =
        '2026-10-15T12:00:00+00:00';
    _expectCorrupt(nonUtc, scope: guestScope);
    final tileState = _stateWithAttempts([
      _attempt(
          answer: WordTileAnswer(
              wordId: 'word',
              tileIndex: 15,
              targetSound: 's',
              expectedMembership: true),
          index: 0)
    ]);
    final invalidTile = _copyJson(codec.encode(tileState));
    invalidTile['history'][0]['attempts'][0]['answer']['tileIndex'] = 16;
    expect(() => codec.decode(jsonEncode(invalidTile), guestScope),
        throwsA(isA<LearningCorruptException>()));
    final activityState = CourseLearningState(
        scope: guestScope,
        revision: 1,
        commitOrdinal: 1,
        history: sampleState().history,
        activities: {
          'sound': _slot(
              'sound',
              LearningActivityKind.soundGame,
              SoundGameCheckpoint(
                  board: SoundBoardState(
                      board: List.filled(36, 's'), stars: const {}),
                  clock: ArcadeClockState(
                      remaining: 60, round: 1, score: 0, paused: true)))
        },
        mistakes: const {},
        summaries: const {},
        completions: const [],
        bestScores: const {},
        pending: const []);
    final badBoard = _copyJson(codec.encode(activityState));
    (badBoard['activities'][0]['snapshot']['board']['board'] as List)
        .removeLast();
    _expectCorrupt(badBoard, scope: guestScope);
  });
  test('malformed nested receipt and scope are corrupt', () {
    expect(() => codec.decode('{"schemaVersion":2}', accountAScope),
        throwsA(isA<LearningCorruptException>()));
  });
  test('canonical command ignores map insertion order but not list order', () {
    final one = sampleCommand(draws: [RandomDraw(upperBound: 3, value: 1)]);
    final same = sampleCommand(draws: [RandomDraw(upperBound: 3, value: 1)]);
    final different =
        sampleCommand(draws: [RandomDraw(upperBound: 3, value: 2)]);
    expect(codec.canonicalCommand(one), codec.canonicalCommand(same));
    expect(
        codec.canonicalCommand(one), isNot(codec.canonicalCommand(different)));
  });
  test('discovery snapshot reads cannot mutate state or command identity', () {
    final original =
        LessonSectionSession(itemIds: const ['i'], sessionId: 'immutable');
    final checkpoint = DiscoveryCheckpoint(session: original);
    final state = _stateWithSnapshot(checkpoint);
    final base = sampleCommand(draws: []);
    final command = _copyCommand(base, candidate: checkpoint);
    final canonicalBefore = codec.canonicalCommand(command);
    final stateBefore = codec.encode(state);

    original.submit(false);
    final firstRead = checkpoint.session;
    firstRead.submit(true);
    final secondRead = checkpoint.session;

    expect(identical(firstRead, secondRead), isFalse);
    expect(secondRead.attemptCount, 0);
    expect(codec.canonicalCommand(command), canonicalBefore);
    expect(codec.encode(state), stateBefore);
  });
  test('canonical identity includes action candidate clock and feedback data',
      () {
    final base = sampleCommand(draws: []);
    final changedCandidate = SoundGameCheckpoint(
        board: SoundBoardState(
            board: [...List.filled(35, 's'), 'sh'], stars: const {}),
        clock:
            ArcadeClockState(remaining: 59, round: 1, score: 0, paused: true));
    final changed = LearningCommand(
        scope: base.scope,
        authGeneration: base.authGeneration,
        activityId: base.activityId,
        expected: base.expected,
        token: base.token,
        submittedAt: base.submittedAt,
        action: SwapSoundTiles(first: 1, second: 2, elapsedSeconds: 3),
        draws: [],
        candidate: changedCandidate,
        feedback: LearningFeedback(
            message: 'changed',
            points: 1,
            cascades: 0,
            bonus: 0,
            correct: true));
    expect(
        codec.canonicalCommand(base), isNot(codec.canonicalCommand(changed)));
  });
  test('canonical identity independently includes action inputs and draw order',
      () {
    final base = sampleCommand(draws: [
      RandomDraw(upperBound: 5, value: 1),
      RandomDraw(upperBound: 7, value: 2),
    ]);
    String id(
            {LearningAction? action,
            ActivitySnapshot? candidate,
            List<RandomDraw>? draws,
            LearningFeedback? feedback}) =>
        codec.canonicalCommand(_copyCommand(base,
            action: action,
            candidate: candidate,
            draws: draws,
            feedback: feedback));
    final expected = id();
    final changedActions = <LearningAction>[
      StartLearningRun(
          options:
              RunOptions(policy: LessonPolicy(completionThresholdPercent: 70))),
      ChooseSound(
          selectedSound: 'z', audioSource: AttemptAudioSource.practiceSpeech),
      ChooseSound(
          selectedSound: 's', audioSource: AttemptAudioSource.notApplicable),
      ChooseDrillWord(
          selectedWord: 'rat', audioSource: AttemptAudioSource.practiceSpeech),
      const FinishLearningActivity(recordCompletion: false),
      ObserveAssistance(
          items: {ItemContextKey(itemId: 'item', targetSound: 's')},
          flags: {AssistanceFlag.answerRevealed}),
      SwapSoundTiles(first: 1, second: 2, elapsedSeconds: 4),
      LinkWordTiles(indices: const [1, 2], elapsedSeconds: 4),
      CheckpointArcade(elapsedSeconds: 4, paused: false),
    ];
    for (final action in changedActions) {
      expect(id(action: action), isNot(expected),
          reason: action.runtimeType.toString());
    }
    expect(
        id(
            action: ChooseSound(
                selectedSound: 's',
                audioSource: AttemptAudioSource.practiceSpeech)),
        isNot(id(
            action: ChooseSound(
                selectedSound: 'sh',
                audioSource: AttemptAudioSource.practiceSpeech))));
    expect(id(action: SwapSoundTiles(first: 1, second: 2)),
        isNot(id(action: SwapSoundTiles(first: 2, second: 1))));
    expect(id(action: LinkWordTiles(indices: const [1, 2])),
        isNot(id(action: LinkWordTiles(indices: const [2, 1]))));
    expect(id(draws: [base.draws.last, base.draws.first]), isNot(expected));
    expect(
        id(
            action: ObserveAssistance(items: {
          ItemContextKey(itemId: 'a', targetSound: 's'),
          ItemContextKey(itemId: 'b', targetSound: 'sh')
        }, flags: {
          AssistanceFlag.graphemeHint,
          AssistanceFlag.answerRevealed
        })),
        id(
            action: ObserveAssistance(items: {
          ItemContextKey(itemId: 'b', targetSound: 'sh'),
          ItemContextKey(itemId: 'a', targetSound: 's')
        }, flags: {
          AssistanceFlag.answerRevealed,
          AssistanceFlag.graphemeHint
        })));
  });
  test('each same-action argument independently changes canonical identity',
      () {
    final base = sampleCommand(draws: []);
    String actionId(LearningAction action) =>
        codec.canonicalCommand(_copyCommand(base, action: action));
    final pairs = <(LearningAction, LearningAction)>[
      (
        StartLearningRun(
            options: RunOptions(
                policy: LessonPolicy(completionThresholdPercent: 70))),
        StartLearningRun(
            options: RunOptions(
                policy: LessonPolicy(completionThresholdPercent: 80)))
      ),
      (
        ChooseSound(
            selectedSound: 's', audioSource: AttemptAudioSource.practiceSpeech),
        ChooseSound(
            selectedSound: 'sh', audioSource: AttemptAudioSource.practiceSpeech)
      ),
      (
        ChooseSound(
            selectedSound: 's', audioSource: AttemptAudioSource.practiceSpeech),
        ChooseSound(
            selectedSound: 's',
            audioSource: AttemptAudioSource.pendingRecording)
      ),
      (
        ChooseDrillWord(
            selectedWord: 'chat',
            audioSource: AttemptAudioSource.practiceSpeech),
        ChooseDrillWord(
            selectedWord: 'rat', audioSource: AttemptAudioSource.practiceSpeech)
      ),
      (
        ChooseDrillWord(
            selectedWord: 'chat',
            audioSource: AttemptAudioSource.practiceSpeech),
        ChooseDrillWord(
            selectedWord: 'chat',
            audioSource: AttemptAudioSource.pendingRecording)
      ),
      (
        const FinishLearningActivity(recordCompletion: true),
        const FinishLearningActivity(recordCompletion: false)
      ),
      (
        SwapSoundTiles(first: 1, second: 2),
        SwapSoundTiles(first: 3, second: 2)
      ),
      (
        SwapSoundTiles(first: 1, second: 2),
        SwapSoundTiles(first: 1, second: 3)
      ),
      (
        SwapSoundTiles(first: 1, second: 2),
        SwapSoundTiles(first: 1, second: 2, elapsedSeconds: 1)
      ),
      (
        SwapSoundTiles(
            first: 1,
            second: 2,
            cue: HeardSoundCue(
                wordId: 'w1',
                targetSound: 's',
                audioSource: AttemptAudioSource.practiceSpeech)),
        SwapSoundTiles(
            first: 1,
            second: 2,
            cue: HeardSoundCue(
                wordId: 'w2',
                targetSound: 's',
                audioSource: AttemptAudioSource.practiceSpeech))
      ),
      (
        SwapSoundTiles(
            first: 1,
            second: 2,
            cue: HeardSoundCue(
                wordId: 'w',
                targetSound: 's',
                audioSource: AttemptAudioSource.practiceSpeech)),
        SwapSoundTiles(
            first: 1,
            second: 2,
            cue: HeardSoundCue(
                wordId: 'w',
                targetSound: 'sh',
                audioSource: AttemptAudioSource.practiceSpeech))
      ),
      (
        SwapSoundTiles(
            first: 1,
            second: 2,
            cue: HeardSoundCue(
                wordId: 'w',
                targetSound: 's',
                audioSource: AttemptAudioSource.practiceSpeech)),
        SwapSoundTiles(
            first: 1,
            second: 2,
            cue: HeardSoundCue(
                wordId: 'w',
                targetSound: 's',
                audioSource: AttemptAudioSource.pendingRecording))
      ),
      (
        LinkWordTiles(indices: const [1, 2]),
        LinkWordTiles(indices: const [1, 3])
      ),
      (
        LinkWordTiles(indices: const [1, 2]),
        LinkWordTiles(indices: const [1, 2], elapsedSeconds: 1)
      ),
      (
        CheckpointArcade(elapsedSeconds: 1, paused: true),
        CheckpointArcade(elapsedSeconds: 2, paused: true)
      ),
      (
        CheckpointArcade(elapsedSeconds: 1, paused: true),
        CheckpointArcade(elapsedSeconds: 1, paused: false)
      ),
      (
        ObserveAssistance(
            items: {ItemContextKey(itemId: 'i', targetSound: 's')},
            flags: {AssistanceFlag.graphemeHint}),
        ObserveAssistance(
            items: {ItemContextKey(itemId: 'i', targetSound: 'sh')},
            flags: {AssistanceFlag.graphemeHint})
      ),
      (
        ObserveAssistance(
            items: {ItemContextKey(itemId: 'i', targetSound: 's')},
            flags: {AssistanceFlag.graphemeHint}),
        ObserveAssistance(
            items: {ItemContextKey(itemId: 'i', targetSound: 's')},
            flags: {AssistanceFlag.answerRevealed})
      ),
    ];
    for (final pair in pairs) {
      expect(actionId(pair.$1), isNot(actionId(pair.$2)),
          reason: pair.toString());
    }
  });
  test(
      'canonical identity independently includes candidate fields and feedback',
      () {
    final base = sampleCommand(draws: []);
    String id({ActivitySnapshot? candidate, LearningFeedback? feedback}) =>
        codec.canonicalCommand(
            _copyCommand(base, candidate: candidate, feedback: feedback));
    final baseline = id();
    final sound = base.candidate as SoundGameCheckpoint;
    expect(
        id(
            candidate: SoundGameCheckpoint(
                board: SoundBoardState(
                    board: [...sound.board.board]..[0] = 'sh',
                    stars: sound.board.stars),
                clock: sound.clock)),
        isNot(baseline));
    expect(
        id(
            candidate: SoundGameCheckpoint(
                board: sound.board,
                clock: ArcadeClockState(
                    remaining: 59, round: 1, score: 0, paused: true))),
        isNot(baseline));
    final policyA = DiscoveryCheckpoint(
        session: LessonSectionSession(
            itemIds: const ['i'],
            sessionId: 'policy',
            policy: LessonPolicy(completionThresholdPercent: 70)));
    final policyB = DiscoveryCheckpoint(
        session: LessonSectionSession(
            itemIds: const ['i'],
            sessionId: 'policy',
            policy: LessonPolicy(completionThresholdPercent: 80)));
    expect(id(candidate: policyA), isNot(id(candidate: policyB)));
    final ordered = SoundGameCheckpoint(
        board: SoundBoardState(board: List.filled(36, 's'), stars: {1, 9}),
        clock:
            ArcadeClockState(remaining: 59, round: 1, score: 0, paused: true));
    final reverseSetInsertion = SoundGameCheckpoint(
        board: SoundBoardState(board: List.filled(36, 's'), stars: {9, 1}),
        clock:
            ArcadeClockState(remaining: 59, round: 1, score: 0, paused: true));
    expect(id(candidate: ordered), id(candidate: reverseSetInsertion));
    final reorderedBoard = SoundGameCheckpoint(
        board: SoundBoardState(
            board: ['sh', ...List.filled(35, 's')], stars: {1, 9}),
        clock:
            ArcadeClockState(remaining: 59, round: 1, score: 0, paused: true));
    expect(id(candidate: ordered), isNot(id(candidate: reorderedBoard)));

    final mapSession =
        LessonSectionSession(itemIds: const ['a', 'b'], sessionId: 'map-order');
    mapSession.submit(true);
    mapSession.advance();
    mapSession.submit(false);
    mapSession.advance();
    final sessionJson = mapSession.toJson();
    final reversedMapJson = Map<String, dynamic>.from(sessionJson)
      ..['latestAnswers'] = {'b': false, 'a': true};
    final sessionA = LessonSectionSession.fromJson(sessionJson,
        itemIds: const ['a', 'b'], contentRevision: 1);
    final sessionB = LessonSectionSession.fromJson(reversedMapJson,
        itemIds: const ['a', 'b'], contentRevision: 1);
    final commandA =
        _copyCommand(base, candidate: DiscoveryCheckpoint(session: sessionA));
    final commandB =
        _copyCommand(base, candidate: DiscoveryCheckpoint(session: sessionB));
    expect(codec.canonicalCommand(commandA), codec.canonicalCommand(commandB));
    final feedback = base.feedback;
    for (final changed in [
      LearningFeedback(
          message: 'm',
          points: feedback.points,
          cascades: feedback.cascades,
          bonus: feedback.bonus,
          correct: feedback.correct),
      LearningFeedback(
          message: feedback.message,
          points: 1,
          cascades: feedback.cascades,
          bonus: feedback.bonus,
          correct: feedback.correct),
      LearningFeedback(
          message: feedback.message,
          points: feedback.points,
          cascades: 1,
          bonus: feedback.bonus,
          correct: feedback.correct),
      LearningFeedback(
          message: feedback.message,
          points: feedback.points,
          cascades: feedback.cascades,
          bonus: 1,
          correct: feedback.correct),
      LearningFeedback(
          message: feedback.message,
          points: feedback.points,
          cascades: feedback.cascades,
          bonus: feedback.bonus,
          correct: true),
    ]) {
      expect(id(feedback: changed), isNot(baseline));
    }
  });
  test('constructors detach nested lists sets and session', () {
    final original = <String>['a'];
    final choices = <String>['s', 'sh'];
    final targets = <String>['s'];
    final assistance = <AssistanceFlag>{AssistanceFlag.graphemeHint};
    final answer = SoundChoiceAnswer(
        selectedSound: 's', choices: choices, expectedSound: 's');
    final attempt = sampleAttempt();
    final mutableSession =
        LessonSectionSession(itemIds: ['a'], sessionId: 'session');
    final checkpoint = DiscoveryCheckpoint(session: mutableSession);
    final slot = ActivitySlot(
        activityId: 'lesson:x',
        kind: LearningActivityKind.discovery,
        contentRevision: 1,
        cursor: SlotCursor(generation: 1, sequence: 1, revision: 1),
        options: RunOptions(),
        snapshot: checkpoint,
        exposures: const {},
        latestReceipt: CommandReceipt(
            token: tokenFor(2),
            canonicalCommand: 'valid',
            before: SlotCursor(generation: 1, sequence: 0, revision: 0),
            after: SlotCursor(generation: 1, sequence: 1, revision: 1),
            commitOrdinal: 1));

    choices.add('bad');
    targets.add('bad');
    assistance.add(AssistanceFlag.answerRevealed);
    original.add('b');
    expect(answer.choices, ['s', 'sh']);
    expect(attempt.targetSounds, ['s']);
    expect(attempt.assistance, isNot(contains(AssistanceFlag.answerRevealed)));
    mutableSession.submit(true);
    expect((slot.snapshot as DiscoveryCheckpoint).session.answered, isFalse);
    expect(original, ['a', 'b']);
  });
}

CourseLearningState _stateWithAttempts(List<CourseAttempt> attempts) {
  return CourseLearningState(
      scope: guestScope,
      revision: 1,
      commitOrdinal: 1,
      history: [
        AttemptBatch(
            activityId: 'lesson:sample',
            generation: 1,
            sequence: 1,
            token: tokenFor(1),
            canonicalCommand: 'fixture',
            attempts: attempts)
      ],
      activities: const {},
      mistakes: const {},
      summaries: const {},
      completions: const [],
      bestScores: const {},
      pending: const []);
}

CourseLearningState _stateWithSnapshot(ActivitySnapshot snapshot) =>
    CourseLearningState(
        scope: guestScope,
        revision: 1,
        commitOrdinal: 1,
        history: sampleState().history,
        activities: {
          'strict': _slot(
              'strict',
              switch (snapshot) {
                DiscoveryCheckpoint() => LearningActivityKind.discovery,
                LegacyLessonCheckpoint() => LearningActivityKind.legacyLesson,
                DrillCheckpoint() => LearningActivityKind.drill,
                SoundGameCheckpoint() => LearningActivityKind.soundGame,
                WordGameCheckpoint() => LearningActivityKind.wordGame,
              },
              snapshot)
        },
        mistakes: const {},
        summaries: const {},
        completions: const [],
        bestScores: const {},
        pending: const []);

CourseAttempt _attempt({required AttemptAnswer answer, required int index}) =>
    CourseAttempt(
        scope: guestScope,
        submissionId: 'member-$index',
        activityId: 'lesson:sample',
        runGeneration: 1,
        commandSequence: 1,
        batchIndex: index,
        itemId: 'item-$index',
        itemOccurrence: 1,
        contentRevision: 1,
        commitOrdinal: 1,
        answeredAt: fixedTime,
        committedAt: fixedTime,
        skill: LearningSkill.listening,
        targetSounds: const ['s'],
        answer: answer,
        origin: AttemptOrigin.practice,
        presentation: AttemptPresentation.firstInRun,
        assistance: const {},
        contentState: AttemptContentState.existingCurated,
        audioSource: AttemptAudioSource.practiceSpeech,
        correct: false);

ActivitySlot _slot(
        String id, LearningActivityKind kind, ActivitySnapshot snapshot,
        {Map<ItemContextKey, ItemExposure> exposures = const {}}) =>
    ActivitySlot(
        activityId: id,
        kind: kind,
        contentRevision: 1,
        cursor: SlotCursor(generation: 1, sequence: 1, revision: 1),
        options: RunOptions(),
        snapshot: snapshot,
        exposures: exposures,
        latestReceipt: CommandReceipt(
            token: tokenFor(8),
            canonicalCommand: 'receipt',
            before: SlotCursor(generation: 1, sequence: 0, revision: 0),
            after: SlotCursor(generation: 1, sequence: 1, revision: 1),
            commitOrdinal: 1));

LearningCommand _copyCommand(LearningCommand source,
        {LearningAction? action,
        ActivitySnapshot? candidate,
        List<RandomDraw>? draws,
        LearningFeedback? feedback}) =>
    LearningCommand(
        scope: source.scope,
        authGeneration: source.authGeneration,
        activityId: source.activityId,
        expected: source.expected,
        token: source.token,
        submittedAt: source.submittedAt,
        action: action ?? source.action,
        draws: draws ?? source.draws,
        candidate: candidate ?? source.candidate,
        feedback: feedback ?? source.feedback);

CourseLearningState _validationState() {
  final scoped = sampleState(scope: accountAScope);
  final mistakeKey = MistakeKey(
      activityId: 'lesson:sample',
      itemId: 'item-0',
      contentRevision: 1,
      skill: LearningSkill.listening,
      targetSound: 's');
  final summaryKey = SummaryKey(
      sound: 's',
      skill: LearningSkill.listening,
      origin: AttemptOrigin.practice,
      presentation: AttemptPresentation.firstInRun,
      assistance: const {});
  return CourseLearningState(
      scope: accountAScope,
      revision: 1,
      commitOrdinal: 1,
      history: scoped.history,
      activities: {
        'lesson:sample': _slot(
            'lesson:sample',
            LearningActivityKind.discovery,
            DiscoveryCheckpoint(
                session: LessonSectionSession(
                    itemIds: const ['item-0'], sessionId: 'validation')),
            exposures: {
              ItemContextKey(itemId: 'item-0', targetSound: 's'):
                  ItemExposure(presentations: 1, assistance: const {})
            })
      },
      mistakes: {
        mistakeKey: LearningMistake(
            key: mistakeKey,
            firstWrongId: 'wrong-1',
            firstWrongAt: fixedTime,
            latestWrongId: 'wrong-2',
            latestWrongAt: fixedTime,
            failureCount: 2,
            lastRunGeneration: 1)
      },
      summaries: {
        summaryKey: SkillCount(total: 2, correct: 1)
      },
      completions: [
        LearningCompletion(
            lessonId: 'lesson:sample',
            contentRevision: 1,
            policyKind: CompletionPolicyKind.discoveryThreshold,
            policyRevision: 1,
            thresholdPercent: 80,
            committedAt: fixedTime)
      ],
      bestScores: const {},
      pending: [
        SupportedCloudEvent(
            id: 'cloud',
            userId: accountAScope.owner.userId!,
            courseId: 'en-fr',
            payload: CloudAnswer(
                sound: 's',
                skill: LearningSkill.listening,
                correct: false,
                activity: 'lesson:sample'))
      ]);
}

Map<String, dynamic> _copyJson(String raw) =>
    jsonDecode(raw) as Map<String, dynamic>;

void _expectCorrupt(Map<String, dynamic> json, {LearningScope? scope}) {
  expect(
      () => const LearningDocumentCodec()
          .decode(jsonEncode(json), scope ?? accountAScope),
      throwsA(isA<LearningCorruptException>()));
}

void _injectUnknownField(Map<String, dynamic> root, List<Object> path) {
  dynamic target = root;
  for (final segment in path) {
    target = segment is int ? (target as List)[segment] : target[segment];
  }
  (target as Map)['unknownFutureField'] = 'unknown';
}
