import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_codec.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
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
  test('unsupported version never becomes empty progress', () {
    expect(() => codec.decode('{"schemaVersion":99}', guestScope),
        throwsA(isA<LearningUnsupportedVersionException>()));
  });
  test('malformed nested receipt and scope are corrupt', () {
    expect(() => codec.decode('{"schemaVersion":2}', accountAScope),
        throwsA(isA<LearningCorruptException>()));
  });
  test('canonical command ignores map insertion order but not list order', () {
    final one =
        sampleCommand(draws: const [RandomDraw(upperBound: 3, value: 1)]);
    final same =
        sampleCommand(draws: const [RandomDraw(upperBound: 3, value: 1)]);
    final different =
        sampleCommand(draws: const [RandomDraw(upperBound: 3, value: 2)]);
    expect(codec.canonicalCommand(one), codec.canonicalCommand(same));
    expect(
        codec.canonicalCommand(one), isNot(codec.canonicalCommand(different)));
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
        cursor: const SlotCursor(generation: 1, sequence: 0, revision: 0),
        options: RunOptions(),
        snapshot: checkpoint,
        exposures: const {},
        latestReceipt: const CommandReceipt(
            token: 't',
            canonicalCommand: '',
            before: SlotCursor(generation: 1, sequence: 0, revision: 0),
            after: SlotCursor(generation: 1, sequence: 0, revision: 0),
            commitOrdinal: 0));
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
