import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_command_codec.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_transition.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';

void main() {
  test('course command identity goldens retain legacy and SQL bytes', () {
    final command = LearningCommand(
      scope: LearningScope(courseId: 'en-fr', owner: LearningOwner.guest()),
      authGeneration: 4,
      activityId: 'lesson:golden',
      expected: SlotCursor(generation: 2, sequence: 3, revision: 4),
      expectedScopeRevision: 5,
      token: 'AAAAAAAAAAAAAAAAAAAA09',
      submittedAt: DateTime.utc(2026, 10, 15, 12),
      action: ObserveAssistance(
        items: <ItemContextKey>{
          ItemContextKey(itemId: 'z-item', targetSound: 'z'),
          ItemContextKey(itemId: 'a-item', targetSound: 'a'),
        },
        flags: <AssistanceFlag>{
          AssistanceFlag.graphemeHint,
          AssistanceFlag.answerRevealed,
        },
      ),
      draws: <RandomDraw>[
        RandomDraw(upperBound: 7, value: 3),
        RandomDraw(upperBound: 5, value: 2),
      ],
      candidate: const LegacyLessonCheckpoint(
        wordIndex: 2,
        selectedSound: 'u',
        finished: false,
      ),
      feedback: LearningFeedback(
        message: 'Correct',
        points: 7,
        cascades: 1,
        bonus: 2,
        correct: true,
      ),
    );

    const legacyGolden =
        '{"action":{"flags":["answerRevealed","graphemeHint"],'
        '"items":[{"itemId":"a-item","targetSound":"a"},'
        '{"itemId":"z-item","targetSound":"z"}],'
        '"kind":"observeAssistance"},"activityId":"lesson:golden",'
        '"authGeneration":4,"candidate":{"finished":false,'
        '"kind":"legacyLesson","selectedSound":"u","wordIndex":2},'
        '"draws":[{"upperBound":7,"value":3},{"upperBound":5,"value":2}],'
        '"expected":{"generation":2,"revision":4,"sequence":3},'
        '"feedback":{"bonus":2,"cascades":1,"correct":true,'
        '"message":"Correct","points":7},'
        '"scope":"course.learning.v2.ZW4tZnI.g",'
        '"submittedAt":"2026-10-15T12:00:00.000Z",'
        '"token":"AAAAAAAAAAAAAAAAAAAA09"}';
    const sqlGolden =
        '{"action":{"flags":["answerRevealed","graphemeHint"],'
        '"items":[{"itemId":"a-item","targetSound":"a"},'
        '{"itemId":"z-item","targetSound":"z"}],'
        '"kind":"observeAssistance"},"activityId":"lesson:golden",'
        '"authGeneration":4,"candidate":{"finished":false,'
        '"kind":"legacyLesson","selectedSound":"u","wordIndex":2},'
        '"draws":[{"upperBound":7,"value":3},{"upperBound":5,"value":2}],'
        '"expected":{"generation":2,"revision":4,"sequence":3},'
        '"expectedScopeRevision":5,'
        '"feedback":{"bonus":2,"cascades":1,"correct":true,'
        '"message":"Correct","points":7},'
        '"scope":"course.learning.v2.ZW4tZnI.g",'
        '"submittedAt":"2026-10-15T12:00:00.000Z",'
        '"token":"AAAAAAAAAAAAAAAAAAAA09"}';

    expect(
      CourseLearningCommandCodec.legacyCanonicalCommand(command),
      legacyGolden,
    );
    expect(CourseLearningCommandCodec.canonicalCommand(command), sqlGolden);
  });

  test('retained course command codec has no whole-document dependency', () {
    final String source = File(
      'lib/src/core/course/course_learning_command_codec.dart',
    ).readAsStringSync();

    final legacyImport = ["import 'course_learning_", "codec.dart'"].join();
    final legacyCodec = ['LearningDocument', 'Codec'].join();
    expect(source, isNot(contains(legacyImport)));
    expect(source, isNot(contains(legacyCodec)));
  });

  test('course_command_captures_scope_revision', () {
    final scope = LearningScope(
      courseId: 'en-fr',
      owner: LearningOwner.guest(),
    );
    final engine = LearningTransitionEngine(LearningRegistry.french());
    final empty = CourseLearningState.empty(scope);
    final start = engine.prepare(
      state: empty,
      authGeneration: 0,
      activityId: 'lesson:en-fr-u-y',
      action: StartLearningRun(options: RunOptions()),
      token: 'AAAAAAAAAAAAAAAAAAAA01',
      submittedAt: DateTime.utc(2026, 10, 15, 12),
      random: Random(1),
    );
    final startTransition = engine.evaluate(
      state: empty,
      command: start,
      committedAt: DateTime.utc(2026, 10, 15, 12),
    );
    final started = CourseLearningState(
      scope: scope,
      revision: 1,
      commitOrdinal: 1,
      history: const [],
      activities: {start.activityId: startTransition.slot},
      mistakes: const {},
      summaries: const {},
      completions: const [],
      bestScores: const {},
      pending: const [],
    );
    final command = engine.prepare(
      state: started,
      authGeneration: 0,
      activityId: 'lesson:en-fr-u-y',
      action: ChooseSound(
        selectedSound: 'u',
        audioSource: AttemptAudioSource.pendingRecording,
      ),
      token: 'AAAAAAAAAAAAAAAAAAAA02',
      submittedAt: DateTime.utc(2026, 10, 15, 12),
      random: Random(1),
    );

    expect(command.expectedScopeRevision, started.revision);
    final sqlCanonical = CourseLearningCommandCodec.canonicalCommand(command);
    final canonical = jsonDecode(sqlCanonical) as Map<String, dynamic>;
    expect(canonical['activityId'], command.activityId);
    expect(canonical['expectedScopeRevision'], started.revision);
    final decoded = CourseLearningCommandCodec.decodeCanonicalCommand(
      sqlCanonical,
      scope: command.scope,
    );
    expect(decoded.expectedScopeRevision, started.revision);
    expect(CourseLearningCommandCodec.canonicalCommand(decoded), sqlCanonical);

    LearningCommand withScopeRevision(int revision) => LearningCommand(
      scope: command.scope,
      authGeneration: command.authGeneration,
      activityId: command.activityId,
      expected: command.expected,
      expectedScopeRevision: revision,
      token: command.token,
      submittedAt: command.submittedAt,
      action: command.action,
      draws: command.draws,
      candidate: command.candidate,
      feedback: command.feedback,
    );
    expect(withScopeRevision(0).expectedScopeRevision, 0);
    expect(
      withScopeRevision(9007199254740991).expectedScopeRevision,
      9007199254740991,
    );
    expect(() => withScopeRevision(-1), throwsArgumentError);
    expect(() => withScopeRevision(9007199254740992), throwsArgumentError);
    expect(
      CourseLearningCommandCodec.canonicalCommand(
        withScopeRevision(started.revision + 1),
      ),
      isNot(sqlCanonical),
    );

    final legacy = CourseLearningCommandCodec.legacyCanonicalCommand(command);
    expect(
      legacy,
      '{"action":{"audioSource":"pendingRecording","kind":"chooseSound",'
      '"selectedSound":"u"},"activityId":"lesson:en-fr-u-y",'
      '"authGeneration":0,"candidate":{"kind":"discovery","session":'
      '{"answered":true,"attemptCount":1,"contentRevision":1,'
      '"itemIds":["tout","tu","rouge","rue","vous","lune",'
      '"doux","jus","loup","mur"],"lastCorrect":true,'
      '"latestAnswers":{"tout":true},"phase":"exercise",'
      '"policy":{"completionThresholdPercent":80},"position":0,'
      '"queue":["tout","tu","rouge","rue","vous","lune",'
      '"doux","jus","loup","mur"],"round":1,'
      '"sessionId":"AAAAAAAAAAAAAAAAAAAA01",'
      '"submittedThisRound":["tout"],"version":1}},"draws":[],"expected":'
      '{"generation":1,"revision":0,"sequence":1},'
      '"feedback":{"bonus":0,"cascades":0,"correct":true,'
      '"message":"Correct","points":0},'
      '"scope":"course.learning.v2.ZW4tZnI.g",'
      '"submittedAt":"2026-10-15T12:00:00.000Z",'
      '"token":"AAAAAAAAAAAAAAAAAAAA02"}',
    );
    expect(
      CourseLearningCommandCodec.legacyCanonicalCommand(
        withScopeRevision(started.revision + 1),
      ),
      legacy,
    );
    final legacyFields = (jsonDecode(legacy) as Map<String, dynamic>).keys;
    expect(legacyFields, contains('activityId'));
    expect(legacyFields, isNot(contains('expectedScopeRevision')));

    final maximumRevision = Map<String, dynamic>.from(canonical)
      ..['expectedScopeRevision'] = 9007199254740991;
    final maximumDecoded = CourseLearningCommandCodec.decodeCanonicalCommand(
      jsonEncode(maximumRevision),
      scope: command.scope,
    );
    expect(maximumDecoded.expectedScopeRevision, 9007199254740991);

    final outOfRangeRevision = Map<String, dynamic>.from(canonical)
      ..['expectedScopeRevision'] = 9007199254740992;
    expect(
      () => CourseLearningCommandCodec.decodeCanonicalCommand(
        jsonEncode(outOfRangeRevision),
        scope: command.scope,
      ),
      throwsFormatException,
    );

    final invalidDomainAction = Map<String, dynamic>.from(canonical);
    invalidDomainAction['action'] = Map<String, dynamic>.from(
      canonical['action'] as Map<String, dynamic>,
    )..['selectedSound'] = ' ';
    expect(
      () => CourseLearningCommandCodec.decodeCanonicalCommand(
        jsonEncode(invalidDomainAction),
        scope: command.scope,
      ),
      throwsFormatException,
    );
  });

  test('course learning scope key remains an exact stable identity', () {
    expect(
      LearningScope(courseId: 'en-fr', owner: LearningOwner.guest()).storageKey,
      'course.learning.v2.ZW4tZnI.g',
    );
  });

  test('domain snapshots detach caller-owned nested session data', () {
    final mutableItems = <String>['item'];
    final session = LessonSectionSession(
      itemIds: mutableItems,
      sessionId: 'immutable-session',
    );
    final checkpoint = DiscoveryCheckpoint(session: session);
    final slot = ActivitySlot(
      activityId: 'lesson:sample',
      kind: LearningActivityKind.discovery,
      contentRevision: 1,
      cursor: SlotCursor(generation: 1, sequence: 2, revision: 1),
      options: RunOptions(),
      snapshot: checkpoint,
      exposures: const {},
      latestReceipt: CommandReceipt(
        token: 'AAAAAAAAAAAAAAAAAAAA02',
        canonicalCommand: 'valid',
        before: SlotCursor(generation: 1, sequence: 1, revision: 0),
        after: SlotCursor(generation: 1, sequence: 2, revision: 1),
        commitOrdinal: 1,
      ),
    );

    mutableItems.add('unexpected');
    session.submit(true);

    expect((slot.snapshot as DiscoveryCheckpoint).session.itemIds, ['item']);
    expect((slot.snapshot as DiscoveryCheckpoint).session.answered, isFalse);
    expect(mutableItems, ['item', 'unexpected']);
  });

  test(
    'activity slot accepts only a single-step generation or cursor move',
    () {
      ActivitySlot slot({
        required SlotCursor before,
        required SlotCursor after,
      }) => ActivitySlot(
        activityId: 'lesson:sample',
        kind: LearningActivityKind.discovery,
        contentRevision: 1,
        cursor: after,
        options: RunOptions(),
        snapshot: DiscoveryCheckpoint(
          session: LessonSectionSession(
            itemIds: const ['item'],
            sessionId: 'cursor-test',
          ),
        ),
        exposures: const {},
        latestReceipt: CommandReceipt(
          token: 'AAAAAAAAAAAAAAAAAAAA03',
          canonicalCommand: 'test',
          before: before,
          after: after,
          commitOrdinal: 1,
        ),
      );

      expect(
        () => slot(
          before: SlotCursor(generation: 1, sequence: 2, revision: 3),
          after: SlotCursor(generation: 3, sequence: 3, revision: 0),
        ),
        throwsArgumentError,
      );
      expect(
        () => slot(
          before: SlotCursor(generation: 1, sequence: 2, revision: 3),
          after: SlotCursor(generation: 1, sequence: 3, revision: 0),
        ),
        throwsArgumentError,
      );
      for (final sequence in [1, 4]) {
        expect(
          () => slot(
            before: SlotCursor(generation: 1, sequence: 2, revision: 3),
            after: SlotCursor(generation: 1, sequence: sequence, revision: 4),
          ),
          throwsArgumentError,
        );
      }
      final unchanged = SlotCursor(generation: 1, sequence: 2, revision: 3);
      expect(
        () => slot(before: unchanged, after: unchanged),
        throwsArgumentError,
      );
    },
  );
}
