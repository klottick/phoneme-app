import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/lesson_section.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';

void main() {
  final itemIds = frenchUySection.items.map((i) => i.id).toList();

  LessonSectionSession newSection(
      {LessonPolicy? policy, List<String>? ids, int contentRevision = 1}) {
    return LessonSectionSession(
        itemIds: ids ?? itemIds,
        sessionId: 'session-1',
        contentRevision: contentRevision,
        policy: policy);
  }

  void expectSameState(
      LessonSectionSession restored, LessonSectionSession origin) {
    expect(restored.itemIds, origin.itemIds);
    expect(restored.queue, origin.queue);
    expect(restored.position, origin.position);
    expect(restored.round, origin.round);
    expect(restored.attemptCount, origin.attemptCount);
    expect(restored.sessionId, origin.sessionId);
    expect(restored.contentRevision, origin.contentRevision);
    expect(restored.phase, origin.phase);
    expect(restored.answered, origin.answered);
    expect(restored.lastCorrect, origin.lastCorrect);
    expect(restored.currentItemId, origin.currentItemId);
    expect(restored.latestAnswers, origin.latestAnswers);
    expect(restored.correctCount, origin.correctCount);
    expect(restored.unresolvedItemIds, origin.unresolvedItemIds);
    expect(restored.canComplete, origin.canComplete);
    expect(restored.policy.toJson(), origin.policy.toJson());
  }

  Map<String, dynamic> baseJson() {
    return Map<String, dynamic>.from(newSection().toJson());
  }

  Map<String, dynamic> debriefJson({bool allCorrect = true}) {
    final origin = newSection();
    for (var i = 0; i < itemIds.length; i++) {
      origin.submit(allCorrect);
      origin.advance();
    }
    return Map<String, dynamic>.from(origin.toJson());
  }

  void expectCorrupt(Map<String, dynamic> json,
      {int contentRevision = 1, List<String>? ids}) {
    expect(
        () => LessonSectionSession.fromJson(json,
            itemIds: ids ?? itemIds, contentRevision: contentRevision),
        throwsFormatException,
        reason: json.toString());
  }

  group('construction', () {
    test('starts a fresh exercise round with validated inputs', () {
      expect(itemIds, [
        'tout',
        'tu',
        'rouge',
        'rue',
        'vous',
        'lune',
        'doux',
        'jus',
        'loup',
        'mur'
      ]);
      final session = newSection();
      expect(session.itemIds, itemIds);
      expect(session.queue, itemIds);
      expect(session.position, 0);
      expect(session.round, 1);
      expect(session.attemptCount, 0);
      expect(session.sessionId, 'session-1');
      expect(session.contentRevision, 1);
      expect(session.phase, LessonSectionPhase.exercise);
      expect(session.policy.completionThresholdPercent, 80);
      expect(session.answered, isFalse,
          reason: 'the fresh current item is not submitted this round');
      expect(session.answeredItemCount, 0);
      expect(session.lastCorrect, isNull);
      expect(session.currentItemId, 'tout');
      expect(session.correctCount, 0);
      expect(session.unresolvedItemIds, isEmpty,
          reason: 'no latest outcome is wrong yet');
      expect(session.latestAnswers, isEmpty);
      expect(session.canComplete, isFalse);
    });

    test('keeps a configured policy and content revision', () {
      final session = LessonSectionSession(
          itemIds: const ['a', 'b', 'c'],
          sessionId: 's',
          contentRevision: 7,
          policy: LessonPolicy(completionThresholdPercent: 90));
      expect(session.contentRevision, 7);
      expect(session.policy.toJson(), const {'completionThresholdPercent': 90});
    });

    test('rejects empty id lists, empty ids, and duplicate ids', () {
      expect(
          () => LessonSectionSession(itemIds: const <String>[], sessionId: 's'),
          throwsArgumentError);
      expect(
          () => LessonSectionSession(itemIds: const ['a', ''], sessionId: 's'),
          throwsArgumentError);
      expect(
          () => LessonSectionSession(itemIds: const ['a', 'a'], sessionId: 's'),
          throwsArgumentError);
    });

    test('rejects an empty session id and a nonpositive revision', () {
      expect(() => LessonSectionSession(itemIds: const ['a'], sessionId: ''),
          throwsArgumentError);
      expect(
          () => LessonSectionSession(
              itemIds: const ['a'], sessionId: 's', contentRevision: 0),
          throwsArgumentError);
      expect(
          () => LessonSectionSession(
              itemIds: const ['a'], sessionId: 's', contentRevision: -1),
          throwsArgumentError);
    });
  });

  group('invalid transitions', () {
    test('rejects advancing an unsubmitted item', () {
      final session = newSection();
      expect(() => session.advance(), throwsStateError);
      expect(() => session.advance(), throwsStateError);
    });

    test('rejects submitting the current item twice in one round', () {
      final session = newSection();
      session.submit(true);
      expect(session.attemptCount, 1);
      expect(session.answered, isTrue,
          reason: 'the current item was just submitted this round');
      expect(session.answeredItemCount, 1);
      expect(session.lastCorrect, isTrue);
      expect(session.phase, LessonSectionPhase.exercise);
      expect(() => session.submit(true), throwsStateError);
      expect(() => session.submit(false), throwsStateError);
      expect(session.attemptCount, 1);
    });

    test('rejects reviewing before the debrief', () {
      final session = newSection();
      session.submit(false);
      expect(session.unresolvedItemIds, ['tout']);
      expect(() => session.reviewMistakes(), throwsStateError);
      session.advance();
      expect(() => session.reviewMistakes(), throwsStateError);
    });

    test('rejects submitting in the debrief', () {
      final session = newSection();
      for (var i = 0; i < itemIds.length; i++) {
        session.submit(true);
        session.advance();
      }
      expect(session.phase, LessonSectionPhase.debrief);
      expect(() => session.submit(true), throwsStateError);
      expect(session.currentItemId, isNull);
    });
  });

  group('first pass and completion boundaries', () {
    test('completion cannot be reached before the debrief', () {
      final session = newSection();
      for (var i = 0; i < itemIds.length - 1; i++) {
        session.submit(true);
        expect(session.canComplete, isFalse,
            reason: 'while item ${itemIds[i]} is current (exercise phase)');
        session.advance();
      }
      // Last item answered but round not advanced: still the exercise phase.
      expect(session.phase, LessonSectionPhase.exercise);
      session.submit(true);
      expect(session.answeredItemCount, 10);
      expect(session.canComplete, isFalse,
          reason: 'last item answered but round not advanced');
      session.advance();
      expect(session.phase, LessonSectionPhase.debrief);
      expect(session.canComplete, isTrue);
    });

    test('the debrief is reachable even with 0/10, with all items unresolved',
        () {
      final session = newSection();
      for (var i = 0; i < itemIds.length; i++) {
        session.submit(false);
        session.advance();
      }
      expect(session.phase, LessonSectionPhase.debrief);
      expect(session.correctCount, 0);
      expect(session.answeredItemCount, 10);
      expect(session.canComplete, isFalse);
      expect(session.unresolvedItemIds, itemIds);
    });

    test('7/10 fails and 8/10 passes under the default policy', () {
      LessonSectionSession pass(int correct) {
        final session = newSection();
        for (var i = 0; i < itemIds.length; i++) {
          session.submit(i < correct);
          session.advance();
        }
        return session;
      }

      expect(pass(6).canComplete, isFalse);
      expect(pass(7).canComplete, isFalse);
      expect(pass(7).correctCount, 7);
      expect(pass(8).canComplete, isTrue);
      expect(pass(10).canComplete, isTrue);
    });

    test('the threshold is honored from the configured policy', () {
      final session =
          newSection(policy: LessonPolicy(completionThresholdPercent: 90));
      for (var i = 0; i < itemIds.length; i++) {
        session.submit(i < 8);
        session.advance();
      }
      expect(session.correctCount, 8);
      expect(session.canComplete, isFalse);
    });
  });

  group('review rounds', () {
    test('queues only unresolved items in original order', () {
      final session = newSection();
      for (var i = 0; i < itemIds.length; i++) {
        session.submit(i != 2 && i != 4); // rouge and vous wrong
        session.advance();
      }
      expect(session.phase, LessonSectionPhase.debrief);
      session.reviewMistakes();
      expect(session.phase, LessonSectionPhase.exercise);
      expect(session.round, 2);
      expect(session.queue, ['rouge', 'vous']);
      expect(session.position, 0);
      expect(session.answeredItemCount, 10, reason: 'earlier answers retained');
      expect(session.lastCorrect, isTrue);
    });

    test('a successful retry updates coverage without erasing attempts', () {
      final session = newSection();
      for (var i = 0; i < itemIds.length; i++) {
        session.submit(i != 6); // doux wrong
        session.advance();
      }
      expect(session.correctCount, 9);
      expect(session.unresolvedItemIds, ['doux']);
      session.reviewMistakes();
      session.submit(true);
      expect(session.correctCount, 10);
      expect(session.attemptCount, 11,
          reason: 'aggregate attempts must be retained');
      session.advance();
      expect(session.phase, LessonSectionPhase.debrief);
      expect(session.unresolvedItemIds, isEmpty);
      expect(session.canComplete, isTrue);
    });

    test('repeating a correct answer cannot inflate coverage', () {
      final session =
          LessonSectionSession(itemIds: const ['a', 'b', 'c'], sessionId: 's');
      session.submit(true);
      session.advance();
      session.submit(true);
      session.advance();
      session.submit(false);
      session.advance();
      expect(session.phase, LessonSectionPhase.debrief);
      expect(session.correctCount, 2);
      expect(session.canComplete, isFalse);
      session.reviewMistakes();
      expect(session.queue, ['c']);
      session.submit(true);
      expect(session.correctCount, 3,
          reason: 'only the fixed item may change coverage');
      expect(session.attemptCount, 4);
      session.advance();
      expect(session.canComplete, isTrue);
    });

    test('rejects a review round when every latest outcome is correct', () {
      final session = newSection();
      for (var i = 0; i < itemIds.length; i++) {
        session.submit(true);
        session.advance();
      }
      expect(() => session.reviewMistakes(), throwsStateError);
    });

    test('every round is finite and returns to the debrief', () {
      final session = newSection();
      var attempts = 0;
      do {
        for (var i = 0; i < session.queue.length; i++) {
          session.submit(true);
          session.advance();
          attempts += 1;
          expect(attempts, lessThanOrEqualTo(20),
              reason: 'rounds must terminate');
        }
        if (session.unresolvedItemIds.isEmpty) {
          break;
        }
        session.reviewMistakes();
      } while (true);
      expect(session.phase, LessonSectionPhase.debrief);
      expect(attempts, 10);
    });

    test('a wrong retry keeps the item unresolved and the round still ends',
        () {
      final session = newSection();
      for (var i = 0; i < itemIds.length; i++) {
        session.submit(i != 2); // rouge wrong
        session.advance();
      }
      expect(session.attemptCount, 10);
      // 9/10 still passes the default 80% threshold...
      expect(session.canComplete, isTrue);
      session.reviewMistakes();
      session.submit(false); // still wrong on retry
      session.advance();
      expect(session.phase, LessonSectionPhase.debrief);
      expect(session.unresolvedItemIds, ['rouge']);
      expect(session.correctCount, 9);
      expect(session.canComplete, isTrue,
          reason: 'review remains available while the section still passes');
      expect(session.attemptCount, 11);
    });
  });

  group('serialization round trips', () {
    test('round trips an unanswered exercise session through a JSON string',
        () {
      // Exercises real JSON text encoding of every serialized value.
      final origin = newSection();
      final json = jsonEncode(origin.toJson());
      expect(() => jsonDecode(json), returnsNormally);
      final restored = LessonSectionSession.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
        itemIds: itemIds,
        contentRevision: 1,
      );
      expectSameState(restored, origin);
      expect(restored.toJson(), origin.toJson());
    });

    test('round trips an answered exercise session mid-item', () {
      final origin = newSection();
      origin.submit(true); // answered, still on first item
      final restored = LessonSectionSession.fromJson(
        jsonDecode(jsonEncode(origin.toJson())) as Map<String, dynamic>,
        itemIds: itemIds,
        contentRevision: 1,
      );
      expectSameState(restored, origin);
      expect(restored.currentItemId, 'tout');
      expect(restored.latestAnswers, {'tout': true});
      expect(restored.toJson(), origin.toJson());
    });

    test('round trips a debrief session with partial coverage', () {
      final origin = newSection();
      for (var i = 0; i < itemIds.length; i++) {
        origin.submit(i != 4 && i != 7); // 8 correct
        origin.advance();
      }
      expect(origin.phase, LessonSectionPhase.debrief);
      expect(origin.canComplete, isTrue);
      final restored = LessonSectionSession.fromJson(
        jsonDecode(jsonEncode(origin.toJson())) as Map<String, dynamic>,
        itemIds: itemIds,
        contentRevision: 1,
      );
      expectSameState(restored, origin);
      expect(restored.toJson(), origin.toJson());
    });

    test('round trips a review round state', () {
      final origin = newSection();
      for (var i = 0; i < itemIds.length; i++) {
        origin.submit(i != 3); // rue wrong
        origin.advance();
      }
      origin.reviewMistakes();
      origin.submit(false); // still wrong in round 2
      expect(origin.phase, LessonSectionPhase.exercise);
      expect(origin.round, 2);
      expect(origin.queue, ['rue']);
      expect(origin.position, 0);
      final restored = LessonSectionSession.fromJson(
        jsonDecode(jsonEncode(origin.toJson())) as Map<String, dynamic>,
        itemIds: itemIds,
        contentRevision: 1,
      );
      expectSameState(restored, origin);
      expect(restored.toJson(), origin.toJson());
    });

    test('round trips with a non-default content revision and threshold', () {
      final origin = newSection(
          policy: LessonPolicy(completionThresholdPercent: 63),
          contentRevision: 9);
      origin.submit(true);
      final restored = LessonSectionSession.fromJson(
        origin.toJson(),
        itemIds: itemIds,
        contentRevision: 9,
      );
      expect(restored.contentRevision, 9);
      expect(
          restored.policy.toJson(), const {'completionThresholdPercent': 63});
      expect(restored.toJson(), origin.toJson());
    });

    test('round trips across multiple review rounds with mixed outcomes', () {
      const ids = ['a', 'b', 'c'];
      final origin = LessonSectionSession(itemIds: ids, sessionId: 's');
      origin.submit(true); // a correct
      origin.advance();
      origin.submit(false); // b wrong
      origin.advance();
      origin.submit(false); // c wrong
      origin.advance();
      expect(origin.phase, LessonSectionPhase.debrief);
      expect(origin.unresolvedItemIds, ['b', 'c']);
      origin.reviewMistakes(); // round 2 queues [b, c]
      origin.submit(true); // fix b
      origin.advance();
      expect(origin.unresolvedItemIds, ['c']);
      origin.submit(false); // c still wrong
      origin.advance();
      expect(origin.phase, LessonSectionPhase.debrief);
      expect(origin.attemptCount, 5);
      expect(origin.correctCount, 2);

      origin.reviewMistakes(); // round 3 queues [c]
      expect(origin.round, 3);
      expect(origin.queue, ['c']);
      expect(origin.answered, isFalse,
          reason: 'review start: c has a prior answer but none this round');

      final restored = LessonSectionSession.fromJson(
        jsonDecode(jsonEncode(origin.toJson())) as Map<String, dynamic>,
        itemIds: ids,
        contentRevision: 1,
      );
      expectSameState(restored, origin);
      expect(restored.toJson(), origin.toJson());
    });

    test('serializes recognized keys with an integer version', () {
      final json = newSection().toJson();
      expect(json['version'], 1);
      expect(json['version'], isA<int>());
      expect(json['answered'], isA<bool>());
      expect(json.keys,
          containsAll(['sessionId', 'contentRevision', 'itemIds', 'queue']));
      expect(json['policy'], const {'completionThresholdPercent': 80});
    });
  });

  group('corrupt snapshot rejection (atomic FormatException)', () {
    test('rejects unknown, wrong-typed, and double versions', () {
      var json = baseJson()..['version'] = 2;
      expectCorrupt(json);
      json = baseJson()..['version'] = '1';
      expectCorrupt(json);
      json = baseJson()..['version'] = 1.0;
      expectCorrupt(json);
      json = baseJson()..['version'] = true;
      expectCorrupt(json);
    });

    test('rejects a content revision mismatch or wrong type', () {
      var json = baseJson()..['contentRevision'] = 2;
      expect(
          () => LessonSectionSession.fromJson(json,
              itemIds: itemIds, contentRevision: 1),
          throwsFormatException);
      json = baseJson()..['contentRevision'] = 3;
      expect(
          () => LessonSectionSession.fromJson(json,
              itemIds: itemIds, contentRevision: 3),
          returnsNormally);
      json = baseJson()..['contentRevision'] = 1.0;
      expect(
          () => LessonSectionSession.fromJson(json,
              itemIds: itemIds, contentRevision: 1),
          throwsFormatException);
    });

    test('rejects item IDs that differ from the section content', () {
      final rotated = [...itemIds.sublist(1), itemIds.first];
      var json = baseJson()..['itemIds'] = rotated;
      expectCorrupt(json);
      json = baseJson()..['itemIds'] = itemIds.sublist(0, 9);
      expectCorrupt(json);
      json = baseJson()..['itemIds'] = [...itemIds, 'inconnu'];
      expectCorrupt(json);
      json = baseJson()..['itemIds'] = ['tout', ...itemIds];
      expectCorrupt(json);
      json = baseJson()..['itemIds'] = ['tout', 'tout', ...itemIds.sublist(1)];
      expectCorrupt(json);
      json = baseJson()..['itemIds'] = ['tout', 2, ...itemIds.sublist(2)];
      expectCorrupt(json);
      json = baseJson()..['itemIds'] = <String>[];
      expectCorrupt(json);
    });

    test('rejects unknown, duplicate, or empty queue entries', () {
      var json = baseJson()..['queue'] = ['zulu', ...itemIds.sublist(1)];
      expectCorrupt(json);
      json = baseJson()..['queue'] = ['tout', 'tout', ...itemIds.sublist(1)];
      expectCorrupt(json);
      json = baseJson()..['queue'] = <String>[];
      expectCorrupt(json);
      json = baseJson()..['queue'] = [1, ...itemIds.sublist(1)];
      expectCorrupt(json);
    });

    test('rejects bad positions and types', () {
      var json = baseJson()..['position'] = -1;
      expectCorrupt(json);
      json = baseJson()..['position'] = itemIds.length + 1;
      expectCorrupt(json);
      json = baseJson()..['position'] = '0';
      expectCorrupt(json);
      json = baseJson()..['position'] = 0.0;
      expectCorrupt(json);
    });

    test('rejects bad rounds, attempt counts, and null-ish fields', () {
      var json = baseJson()..['round'] = 0;
      expectCorrupt(json);
      json = baseJson()..['round'] = true;
      expectCorrupt(json);
      json = baseJson()..['attemptCount'] = -1;
      expectCorrupt(json);
      json = baseJson()..['attemptCount'] = '3';
      expectCorrupt(json);
      json = baseJson()..['attemptCount'] = 3.0;
      expectCorrupt(json);
      json = baseJson()..['sessionId'] = '';
      expectCorrupt(json);
      json = baseJson()..['lastCorrect'] = 'true';
      expectCorrupt(json);
    });

    test('rejects unknown or wrong-typed phase/state combinations', () {
      var json = baseJson()..['phase'] = 'paused';
      expectCorrupt(json);
      json = baseJson()..['phase'] = 1;
      expectCorrupt(json);
      json = baseJson()..['phase'] = null;
      expectCorrupt(json);

      // A valid all-correct debrief to corrupt the invariants below.
      final origin = newSection();
      for (var i = 0; i < itemIds.length; i++) {
        origin.submit(true);
        origin.advance();
      }
      final base = Map<String, dynamic>.from(origin.toJson());
      var bad = Map<String, dynamic>.from(base)..['position'] = 9;
      expectCorrupt(bad);
      bad = Map<String, dynamic>.from(base)
        ..['submittedThisRound'] = <String>[];
      expectCorrupt(bad);

      // Exercise with an exhausted queue.
      bad = Map<String, dynamic>.from(newSection().toJson());
      bad['position'] = itemIds.length;
      expectCorrupt(bad);

      // Debrief omitting a first-pass answer (impossible coverage).
      bad = Map<String, dynamic>.from(base)
        ..['answered'] = false
        ..['latestAnswers'] =
            Map<String, dynamic>.from(base['latestAnswers'] as Map);
      (bad['latestAnswers'] as Map).remove('mur');
      expectCorrupt(bad);
    });

    test('rejects wrong-typed latest outcomes and unknown outcome IDs', () {
      var json = baseJson();
      json['submittedThisRound'] = ['tout'];
      json['answered'] = true;
      json['lastCorrect'] = true;
      json['latestAnswers'] = <String, dynamic>{};
      expectCorrupt(json);
      json = baseJson();
      json['latestAnswers'] = {'zulu': true};
      expectCorrupt(json);
      json = baseJson();
      json['submittedThisRound'] = ['tout'];
      json['answered'] = true;
      json['lastCorrect'] = true;
      json['latestAnswers'] = {'tout': 1};
      expectCorrupt(json);
    });

    test('rejects submitted items beyond the current exercise position', () {
      final origin = newSection();
      origin.submit(true);
      final json = Map<String, dynamic>.from(origin.toJson());
      json['submittedThisRound'] = ['tout', 'tu'];
      expectCorrupt(json);
    });

    test('rejects a policy with a double threshold, no type coercion', () {
      var json = baseJson();
      json['policy'] = {'completionThresholdPercent': 80.0};
      expectCorrupt(json);
      json = baseJson();
      json['policy'] = null;
      expectCorrupt(json);
      json = baseJson();
      json['policy'] = '80';
      expectCorrupt(json);
      json = baseJson();
      json['policy'] = {'completionThresholdPercent': 0};
      expectCorrupt(json);
    });
  });

  group('answered is the current-round submission status (bool)', () {
    test(
        'false fresh, true after submit, false after advance, false at debrief',
        () {
      final session = newSection();
      expect(session.answered, isFalse);
      session.submit(true);
      expect(session.answered, isTrue);
      session.advance();
      expect(session.position, 1);
      expect(session.answered, isFalse,
          reason: 'the next current item has not been submitted yet');
      expect(session.answeredItemCount, 1,
          reason: 'aggregate coverage is separate from the answered flag');
    });

    test(
        'false at a review round start even though the item has a prior answer',
        () {
      final session = newSection();
      for (var i = 0; i < itemIds.length; i++) {
        session.submit(i != 2); // rouge wrong
        session.advance();
      }
      session.reviewMistakes();
      expect(session.round, 2);
      expect(session.currentItemId, 'rouge');
      expect(session.latestAnswers['rouge'], isFalse,
          reason: 'a historical outcome exists for rouge');
      expect(session.answered, isFalse,
          reason: 'a previous answer is not a current-round submission');
      session.submit(true);
      expect(session.answered, isTrue);
      expect(session.answeredItemCount, 10,
          reason: 'coverage unchanged; the flag is per current item');
    });

    test('is a boolean field in the serialized snapshot', () {
      final json = newSection().toJson();
      expect(json['answered'], isA<bool>());
      expect(json['answered'], isFalse);

      final advanced = newSection();
      advanced.submit(true);
      expect(advanced.toJson()['answered'], isTrue);
    });
  });

  group('reachability regression: impossible snapshots are rejected', () {
    test('rejects lastCorrect that contradicts the submitted current outcome',
        () {
      final origin = newSection()..submit(false);
      expect(origin.lastCorrect, isFalse);
      final json = origin.toJson()..['lastCorrect'] = true;
      expectCorrupt(json);
    });

    test('keeps lastCorrect null exactly when no outcome is recorded', () {
      final fresh = baseJson();
      expect(fresh['lastCorrect'], isNull);
      expect(fresh['attemptCount'], 0);
      // A fresh session with no outcomes and null lastCorrect restores.
      LessonSectionSession.fromJson(fresh,
          itemIds: itemIds, contentRevision: 1);
      // A fresh session claiming a prior outcome is impossible.
      expectCorrupt(baseJson()..['lastCorrect'] = true);
      expectCorrupt(baseJson()..['lastCorrect'] = false);
    });

    test('rejects a review start that loses its retained lastCorrect', () {
      const ids = ['a', 'b'];
      final origin = LessonSectionSession(itemIds: ids, sessionId: 's');
      origin.submit(true);
      origin.advance();
      origin.submit(false); // last outcome of round 1
      origin.advance();
      origin.reviewMistakes(); // round 2 start retains the prior outcome
      expect(origin.lastCorrect, isFalse,
          reason: 'the review round retains the previous round outcome');
      expect(origin.latestAnswers, {'a': true, 'b': false});
      // The valid review start with a retained outcome still restores.
      LessonSectionSession.fromJson(origin.toJson(),
          itemIds: ids, contentRevision: 1);
      // Losing the retained outcome must fail atomically: null, and missing.
      expectCorrupt(origin.toJson()..['lastCorrect'] = null, ids: ids);
      final removed = <String, dynamic>{...origin.toJson()}
        ..remove('lastCorrect');
      expectCorrupt(removed, ids: ids);
    });

    test('rejects a submitted current item that has no outcome', () {
      final json = Map<String, dynamic>.from(baseJson())
        ..['submittedThisRound'] = ['tout']
        ..['answered'] = true
        ..['latestAnswers'] = <String, dynamic>{};
      expectCorrupt(json);
    });

    test('rejects a non-bool serialized answered flag', () {
      expectCorrupt(baseJson()..['answered'] = ['tout']);
      expectCorrupt(baseJson()..['answered'] = 1);
      expectCorrupt(baseJson()..['answered'] = null);
      expectCorrupt(baseJson()..remove('answered'));
    });

    test('rejects an answered flag inconsistent with the round state', () {
      // Exercise, nothing submitted yet, but answered claims otherwise.
      expectCorrupt(baseJson()..['answered'] = true);
      // Exercise, current item already submitted, but answered denies it.
      final submitted = (newSection()..submit(true)).toJson()
        ..['answered'] = false;
      expectCorrupt(submitted);
      // Debrief never has a submitted current item.
      final debrief = Map<String, dynamic>.from(debriefJson())
        ..['answered'] = true;
      expectCorrupt(debrief);
    });

    test('rejects a shortened or reordered first-pass queue', () {
      expectCorrupt(baseJson()..['queue'] = itemIds.sublist(0, 1));
      final swapped = [itemIds[1], ...itemIds];
      expectCorrupt(baseJson()..['queue'] = swapped);
    });

    test('rejects first-pass outcomes for items that were not submitted', () {
      final json = Map<String, dynamic>.from(baseJson())
        ..['latestAnswers'] = <String, dynamic>{'tout': true, 'tu': true};
      expectCorrupt(json);
    });

    test('rejects an inflated first-pass attempt count', () {
      final json = (newSection()..submit(false)).toJson()
        ..['attemptCount'] = 999;
      expectCorrupt(json);
    });

    test('rejects a review queue that includes an already-correct item', () {
      LessonSectionSession reviewState() {
        final origin = LessonSectionSession(
            itemIds: const ['a', 'b', 'c'], sessionId: 's');
        origin.submit(true); // a correct
        origin.advance();
        origin.submit(false); // b wrong
        origin.advance();
        origin.submit(false); // c wrong
        origin.advance();
        origin.reviewMistakes(); // round 2, queue [b, c]
        return origin;
      }

      final origin = reviewState();
      expect(origin.queue, ['b', 'c']);
      // 'a' was correct on the first pass, so it must not be re-queued.
      final json = origin.toJson()..['queue'] = ['a'];
      expectCorrupt(json, ids: const ['a', 'b', 'c']);
    });

    test('rejects a review state that lacks full first-pass coverage', () {
      final origin =
          LessonSectionSession(itemIds: const ['a', 'b', 'c'], sessionId: 's');
      origin.submit(true);
      origin.advance();
      origin.submit(false);
      origin.advance();
      origin.submit(false);
      origin.advance();
      origin.reviewMistakes();
      final json = origin.toJson()
        ..['latestAnswers'] = <String, dynamic>{'b': false};
      expectCorrupt(json, ids: const ['a', 'b', 'c']);
    });

    test('rejects infeasible review attempt counts (below or above bounds)',
        () {
      final origin =
          LessonSectionSession(itemIds: const ['a', 'b', 'c'], sessionId: 's');
      origin.submit(true);
      origin.advance();
      origin.submit(false);
      origin.advance();
      origin.submit(false);
      origin.advance();
      origin.reviewMistakes(); // round 2, 3 first-pass attempts so far
      expect(origin.attemptCount, 3);

      // n=3, round=2, queue=2, submitted=0 => min=max=3 for a review start.
      expectCorrupt(origin.toJson()..['attemptCount'] = 2,
          ids: const ['a', 'b', 'c']);
      expectCorrupt(origin.toJson()..['attemptCount'] = 7,
          ids: const ['a', 'b', 'c']);
    });
  });

  group('unmodifiable session views', () {
    test('callers cannot mutate the queued or recorded state', () {
      final session = newSection();
      session.submit(false); // keep 'tout' unresolved
      expect(() => session.queue.removeAt(0), throwsUnsupportedError);
      expect(() => session.itemIds.add('x'), throwsUnsupportedError);
      expect(() => session.latestAnswers['tu'] = true, throwsUnsupportedError);
      expect(
          () => session.latestAnswers.remove('tout'), throwsUnsupportedError);
      expect(session.latestAnswers, {'tout': false});
      expect(session.queue, itemIds);

      // unresolvedItemIds is an unmodifiable copy: element replacement,
      // insertion, and removal must all be rejected.
      final unresolved = session.unresolvedItemIds;
      expect(unresolved, ['tout']);
      expect(() => unresolved[0] = 'zulu', throwsUnsupportedError);
      expect(() => unresolved.insert(0, 'zulu'), throwsUnsupportedError);
      expect(() => unresolved.removeAt(0), throwsUnsupportedError);
      expect(session.unresolvedItemIds, ['tout']);
    });
  });
}
