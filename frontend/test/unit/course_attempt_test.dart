import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import '../support/course_learning_fixtures.dart';

void main() {
  test('composite keys cannot alias owners or targets', () {
    expect(guestScope.storageKey, isNot(accountAScope.storageKey));
    expect(accountAScope.storageKey, isNot(accountBScope.storageKey));
    expect(accountAScope.storageKey, isNot(guestScope.storageKey));
    expect(accountAScope.owner.userId, 'account/a');
    expect(
        LearningScope(courseId: 'a.b', owner: accountAScope.owner).storageKey,
        isNot(LearningScope(courseId: 'a', owner: LearningOwner.account('b/c'))
            .storageKey));
  });

  test('constructors reject malformed identifiers counters and tokens', () {
    expect(() => LearningOwner.account('  '), throwsArgumentError);
    expect(() => LearningScope(courseId: '', owner: guestScope.owner),
        throwsArgumentError);
    expect(
        () => SoundChoiceAnswer(
            selectedSound: '', choices: const ['s'], expectedSound: 's'),
        throwsArgumentError);
    expect(
        () => WordTileAnswer(
            wordId: 'w',
            tileIndex: 16,
            targetSound: 's',
            expectedMembership: true),
        throwsArgumentError);
    expect(() => SlotCursor(generation: -1, sequence: 0, revision: 0),
        throwsArgumentError);
    expect(
        () => CommandReceipt(
            token: 'invalid',
            canonicalCommand: 'command',
            before: SlotCursor(generation: 1, sequence: 0, revision: 0),
            after: SlotCursor(generation: 1, sequence: 1, revision: 1),
            commitOrdinal: 1),
        throwsArgumentError);
    expect(() => RandomDraw(upperBound: 0, value: 0), throwsArgumentError);
    expect(
        () => CourseAttempt(
              scope: guestScope,
              submissionId: '',
              activityId: 'lesson:x',
              runGeneration: 1,
              commandSequence: 1,
              batchIndex: 0,
              itemId: 'i',
              itemOccurrence: 1,
              contentRevision: 1,
              commitOrdinal: 1,
              answeredAt: fixedTime,
              committedAt: fixedTime,
              skill: LearningSkill.listening,
              targetSounds: const ['s'],
              answer: SoundChoiceAnswer(
                  selectedSound: 's', choices: const ['s'], expectedSound: 's'),
              origin: AttemptOrigin.practice,
              presentation: AttemptPresentation.firstInRun,
              assistance: const {},
              contentState: AttemptContentState.pending,
              audioSource: AttemptAudioSource.notApplicable,
              correct: true,
            ),
        throwsArgumentError);
    expect(
        () => AttemptBatch(
            activityId: 'a',
            generation: 0,
            sequence: 1,
            token: 'bad',
            canonicalCommand: 'x',
            attempts: [sampleAttempt()]),
        throwsArgumentError);
  });

  test('answer and attempt collections detach caller-owned data', () {
    final choices = ['s', 'sh'];
    final targets = ['s'];
    final flags = <AssistanceFlag>{AssistanceFlag.graphemeHint};
    final answer = SoundChoiceAnswer(
        selectedSound: 's', choices: choices, expectedSound: 's');
    final attempt = CourseAttempt(
        scope: guestScope,
        submissionId: 'submission-1',
        activityId: 'lesson:x',
        runGeneration: 1,
        commandSequence: 1,
        batchIndex: 0,
        itemId: 'item',
        itemOccurrence: 1,
        contentRevision: 1,
        commitOrdinal: 1,
        answeredAt: fixedTime,
        committedAt: fixedTime,
        skill: LearningSkill.listening,
        targetSounds: targets,
        answer: answer,
        origin: AttemptOrigin.practice,
        presentation: AttemptPresentation.firstInRun,
        assistance: flags,
        contentState: AttemptContentState.pending,
        audioSource: AttemptAudioSource.notApplicable,
        correct: true);
    choices.add('bad');
    targets.add('bad');
    flags.clear();
    expect(answer.choices, ['s', 'sh']);
    expect(attempt.targetSounds, ['s']);
    expect(attempt.assistance, {AssistanceFlag.graphemeHint});
  });

  test('all answer shapes retain their exact typed values', () {
    final answers = <AttemptAnswer>[
      SoundChoiceAnswer(
          selectedSound: 'sh', choices: const ['s', 'sh'], expectedSound: 's'),
      DrillChoiceAnswer(
          selectedWord: 'chat',
          pairId: 'p1',
          choices: const ['chat', 'rat'],
          expectedWord: 'rat'),
      SoundCueAnswer(selectedFamily: 'sh', wordId: 'chat', expectedFamily: 's'),
      WordTileAnswer(
          wordId: 'chat',
          tileIndex: 15,
          targetSound: 'sh',
          expectedMembership: true),
    ];
    expect(answers[0], isA<SoundChoiceAnswer>());
    expect((answers[1] as DrillChoiceAnswer).pairId, 'p1');
    expect((answers[2] as SoundCueAnswer).wordId, 'chat');
    expect((answers[3] as WordTileAnswer).tileIndex, 15);
  });

  test('checkpoint boards validate ranges and detach nested collections', () {
    final board = List<String>.filled(36, 's');
    final stars = <int>{0, 35};
    final checkpoint = SoundBoardState(board: board, stars: stars);
    board[0] = '';
    stars.clear();
    expect(checkpoint.board.first, 's');
    expect(checkpoint.stars, {0, 35});
    expect(() => SoundBoardState(board: List.filled(36, ''), stars: const {}),
        throwsArgumentError);
    expect(
        () => WordBoardState(
            board: List.filled(16, 'w'),
            target: 's',
            moves: -1,
            combo: 0,
            stars: const {},
            obstacles: const {}),
        throwsArgumentError);
    expect(
        () => ArcadeClockState(remaining: 61, round: 1, score: 0, paused: true),
        throwsArgumentError);
  });

  test('state rejects inconsistent nested scope and activity identity', () {
    final state = sampleState();
    expect(state.scope, guestScope);
    expect(state.history.single.attempts.single.scope, guestScope);
    final slot = sampleActivitySlot();
    expect(
        () => CourseLearningState(
            scope: guestScope,
            revision: 1,
            commitOrdinal: 1,
            history: const [],
            activities: {'wrong': slot},
            mistakes: const {},
            summaries: const {},
            completions: const [],
            bestScores: const {},
            pending: const []),
        throwsArgumentError);
  });

  test('command and state detach submitted collections', () {
    final draws = <RandomDraw>[RandomDraw(upperBound: 3, value: 1)];
    final command = sampleCommand(draws: draws);
    draws.clear();
    expect(command.draws, hasLength(1));
    final state = sampleState();
    expect(state.history.single.attempts.single.itemId, 'item-0');
    expect(state.activities, isEmpty);
  });

  test('discovery checkpoint detaches the mutable session', () {
    final session =
        LessonSectionSession(itemIds: ['item'], sessionId: 'session');
    final checkpoint = DiscoveryCheckpoint(session: session);
    session.submit(false);
    expect(checkpoint.session.attemptCount, 0);
    expect(checkpoint.session.latestAnswers, isEmpty);
  });

  test('state does not claim equality from matching collection lengths', () {
    final state = sampleState();
    final other = CourseLearningState(
        scope: accountAScope,
        revision: 1,
        commitOrdinal: 1,
        history: const [],
        activities: const {},
        mistakes: const {},
        summaries: const {},
        completions: const [],
        bestScores: const {},
        pending: const []);
    expect(state.scope, guestScope);
    expect(state.history.single.attempts.single.itemId, 'item-0');
    expect(other.scope, accountAScope);
    expect(other.history, isEmpty);
    expect(state, isNot(other));
  });
}
