import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/comparison_content.dart';
import 'package:linguist/src/core/course/comparison_learning_codec.dart';
import 'package:linguist/src/core/course/comparison_learning_command.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/comparison_learning_transition.dart';
import 'package:linguist/src/core/course/course_learning_codec.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_audio_contract.dart';
import 'package:linguist/src/core/course/french_comparison_content.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';

void main() {
  test('empty comparison document uses exact schema and round trips', () {
    final scope =
        ComparisonProfileScope(courseId: 'en-fr', owner: LearningOwner.guest());
    const codec = ComparisonLearningCodec();
    final state = ComparisonLearningState.empty(scope);
    final encoded = codec.encode(state);
    final json = jsonDecode(encoded) as Map<String, Object?>;
    expect(json.keys.toList(), [
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
    ]);
    expect(
        codec.decode(encoded, scope, loadFrenchComparisonCatalogue()).revision,
        0);
    expect(codec.keyFor(scope), 'course.learning.comparison.v1.ZW4tZnI.g');
  });

  test('standard JSON decoder collapses duplicate textual keys (limitation)',
      () {
    // The strict codec sees only the object produced by dart:convert; it has no
    // raw-token visibility to distinguish these source bytes.
    expect(jsonDecode('{"schemaVersion":1,"schemaVersion":2}'),
        {'schemaVersion': 2});
  });

  test(
      'ordinary document map order is irrelevant but fingerprint order is exact',
      () {
    final d = _CodecDriver(LearningOwner.guest());
    d.submit(StartComparisonRun(sessionId: 'ordered', policy: LessonPolicy()));
    final document = jsonDecode(d.codec.encode(d.state));
    final reordered = jsonEncode(_reverseMaps(document));
    final decoded = d.codec.decode(reordered, d.scope, d.catalogue);
    expect(decoded.slot!.latestReceipt.canonicalCommand,
        d.state.slot!.latestReceipt.canonicalCommand);
    final command = jsonDecode(d.state.slot!.latestReceipt.canonicalCommand)
        as Map<String, Object?>;
    final wrongOrder = jsonEncode(_reverseMaps(command));
    final receiptDocument =
        jsonDecode(d.codec.encode(d.state)) as Map<String, Object?>;
    (receiptDocument['receipts'] as List).first['canonicalCommand'] =
        wrongOrder;
    ((receiptDocument['slot'] as Map<String, Object?>)['latestReceipt']
        as Map<String, Object?>)['canonicalCommand'] = wrongOrder;
    expect(
        () => d.codec.decode(jsonEncode(receiptDocument), d.scope, d.catalogue),
        throwsA(isA<ComparisonUnavailableException>()));
  });

  test('empty retained receipts preserve a valid latest slot without repair',
      () {
    final d = _CodecDriver(LearningOwner.guest());
    d.submit(StartComparisonRun(sessionId: 'pruned', policy: LessonPolicy()));
    final document =
        jsonDecode(d.codec.encode(d.state)) as Map<String, Object?>;
    document['receipts'] = <Object?>[];
    final restored = d.codec.decode(jsonEncode(document), d.scope, d.catalogue);
    expect(restored.receipts, isEmpty);
    expect(
        restored.slot!.latestReceipt.token, d.state.slot!.latestReceipt.token);
  });

  test(
      'slot latest answer validates catalogue binding without retained receipts',
      () {
    final d = _CodecDriver(LearningOwner.guest());
    d.submit(StartComparisonRun(sessionId: 's', policy: LessonPolicy()));
    d.answerFirstPair();
    final document =
        jsonDecode(d.codec.encode(d.state)) as Map<String, Object?>;
    document['attempts'] = <Object?>[];
    document['receipts'] = <Object?>[];
    final latest = (document['slot'] as Map<String, Object?>)['latestReceipt']
        as Map<String, Object?>;
    final command = jsonDecode(latest['canonicalCommand'] as String)
        as Map<String, Object?>;
    final observations =
        ((command['action'] as Map<String, Object?>)['observations'] as List);
    (observations.last as Map<String, Object?>)['uiGeneration'] = 100;
    latest['canonicalCommand'] = jsonEncode(command);
    expect(() => d.codec.decode(jsonEncode(document), d.scope, d.catalogue),
        throwsA(isA<ComparisonUnavailableException>()));
  });

  test('pruned answer fingerprint rejects mismatched playback epochs and round',
      () {
    final d = _CodecDriver(LearningOwner.guest());
    d.submit(StartComparisonRun(sessionId: 's', policy: LessonPolicy()));
    d.answerFirstPair();
    final original =
        jsonDecode(d.codec.encode(d.state)) as Map<String, Object?>;
    original['attempts'] = <Object?>[];
    final receipt = (original['receipts'] as List).last as Map<String, Object?>;
    final command = jsonDecode(receipt['canonicalCommand'] as String)
        as Map<String, Object?>;
    final obs =
        ((command['action'] as Map<String, Object?>)['observations'] as List);
    (obs.last as Map<String, Object?>)['uiGeneration'] = 78;
    final changed = jsonEncode(command);
    receipt['canonicalCommand'] = changed;
    ((original['slot'] as Map<String, Object?>)['latestReceipt']
        as Map<String, Object?>)['canonicalCommand'] = changed;
    expect(() => d.codec.decode(jsonEncode(original), d.scope, d.catalogue),
        throwsA(isA<ComparisonUnavailableException>()));

    final zeroRound =
        jsonDecode(d.codec.encode(d.state)) as Map<String, Object?>;
    zeroRound['attempts'] = <Object?>[];
    final zeroReceipt =
        (zeroRound['receipts'] as List).last as Map<String, Object?>;
    final zeroCommand = jsonDecode(zeroReceipt['canonicalCommand'] as String)
        as Map<String, Object?>;
    final zeroObs = ((zeroCommand['action']
        as Map<String, Object?>)['observations'] as List);
    (zeroObs.first as Map<String, Object?>)['round'] = 0;
    final zeroRaw = jsonEncode(zeroCommand);
    zeroReceipt['canonicalCommand'] = zeroRaw;
    ((zeroRound['slot'] as Map<String, Object?>)['latestReceipt']
        as Map<String, Object?>)['canonicalCommand'] = zeroRaw;
    expect(() => d.codec.decode(jsonEncode(zeroRound), d.scope, d.catalogue),
        throwsA(isA<ComparisonUnavailableException>()));
  });

  test('future and unknown comparison bytes are unavailable without repair',
      () {
    final scope =
        ComparisonProfileScope(courseId: 'en-fr', owner: LearningOwner.guest());
    const codec = ComparisonLearningCodec();
    final base = jsonDecode(codec.encode(ComparisonLearningState.empty(scope)))
        as Map<String, Object?>;
    for (final mutation in [
      (Map<String, Object?>.of(base)..['schemaVersion'] = 2),
      (Map<String, Object?>.of(base)..['unknown'] = true),
    ]) {
      final raw = jsonEncode(mutation);
      expect(() => codec.decode(raw, scope, loadFrenchComparisonCatalogue()),
          throwsA(isA<ComparisonUnavailableException>()));
      expect(raw, jsonEncode(mutation));
    }
  });

  test('populated comparison state round trips canonical receipts and evidence',
      () {
    final driver = _CodecDriver(LearningOwner.account('acct-1'));
    driver.submit(StartComparisonRun(sessionId: 'run', policy: LessonPolicy()));
    driver.answerFirstPair();
    final raw = driver.codec.encode(driver.state);
    final decoded = driver.codec.decode(raw, driver.scope, driver.catalogue);
    expect(decoded.slot!.checkpoint.sessionId, 'run');
    expect(decoded.receipts.last.canonicalCommand,
        driver.state.receipts.last.canonicalCommand);
    expect(driver.codec.encode(decoded), raw);
  });

  test('strict decoder rejects foreign and malformed populated variants', () {
    final d = _CodecDriver(LearningOwner.guest());
    d.submit(StartComparisonRun(sessionId: 's', policy: LessonPolicy()));
    d.answerFirstPair();
    final original = d.codec.encode(d.state);
    const v2FixtureBytes =
        '{"schemaVersion":2,"courseId":"en-fr","owner":{"kind":"guest"},"revision":0,"commitOrdinal":0,"history":[],"activities":[],"mistakes":[],"summaries":[],"completions":[],"bestScores":{},"pending":[]}';
    final v2Bytes = const LearningDocumentCodec().encode(
        CourseLearningState.empty(
            LearningScope(courseId: 'en-fr', owner: LearningOwner.guest())));
    expect(v2Bytes, v2FixtureBytes);
    Map<String, Object?> clone() =>
        jsonDecode(original) as Map<String, Object?>;
    final invalid = <Map<String, Object?>>[];
    invalid.add(clone()..['family'] = 'v2');
    invalid.add(clone()..['courseId'] = 'fr-fr');
    invalid
        .add(clone()..['owner'] = {'kind': 'account', 'userId': 'elsewhere'});
    final unknown = clone();
    (unknown['slot'] as Map<String, Object?>)['unexpected'] = true;
    invalid.add(unknown);
    final unknownAttempt = clone();
    ((unknownAttempt['attempts'] as List).first
        as Map<String, Object?>)['extra'] = 1;
    invalid.add(unknownAttempt);
    final unknownObservation = clone();
    final unknownAttemptMap =
        (unknownObservation['attempts'] as List).first as Map<String, Object?>;
    ((unknownAttemptMap['observations'] as List).first
        as Map<String, Object?>)['extra'] = 1;
    invalid.add(unknownObservation);
    final unknownReceipt = clone();
    ((unknownReceipt['receipts'] as List).first
        as Map<String, Object?>)['extra'] = 1;
    invalid.add(unknownReceipt);
    final unknownMistake = clone();
    ((unknownMistake['mistakes'] as Map).values.single
        as Map<String, Object?>)['extra'] = 1;
    invalid.add(unknownMistake);
    final unknownSummary = clone();
    ((unknownSummary['summaries'] as Map).values.single
        as Map<String, Object?>)['extra'] = 1;
    invalid.add(unknownSummary);
    final badPolicy = clone();
    final checkpoint = (badPolicy['slot'] as Map<String, Object?>)['checkpoint']
        as Map<String, Object?>;
    (checkpoint['policy'] as Map<String, Object?>)['unknown'] = 1;
    invalid.add(badPolicy);
    final unknownSessionPolicy = clone();
    final nestedSession =
        (((unknownSessionPolicy['slot'] as Map<String, Object?>)['checkpoint']
            as Map<String, Object?>)['session'] as Map<String, Object?>);
    (nestedSession['policy'] as Map<String, Object?>)['unexpected'] = true;
    invalid.add(unknownSessionPolicy);
    final badPhase = clone();
    final session = (((badPhase['slot'] as Map<String, Object?>)['checkpoint']
        as Map<String, Object?>)['session'] as Map<String, Object?>);
    session['phase'] = 'future';
    invalid.add(badPhase);
    final duplicateAttempt = clone();
    (duplicateAttempt['attempts'] as List)
        .add((duplicateAttempt['attempts'] as List).first);
    invalid.add(duplicateAttempt);
    final duplicateReceipt = clone();
    (duplicateReceipt['receipts'] as List)
        .add((duplicateReceipt['receipts'] as List).first);
    invalid.add(duplicateReceipt);
    final badDate = clone();
    ((badDate['attempts'] as List).first
        as Map<String, Object?>)['answeredAt'] = '2026-01-01T00:00:00+01:00';
    invalid.add(badDate);
    final overflow = clone()..['revision'] = 9007199254740992;
    invalid.add(overflow);
    final badFingerprint = clone();
    ((badFingerprint['receipts'] as List).first
        as Map<String, Object?>)['canonicalCommand'] = '{}';
    invalid.add(badFingerprint);
    final badReference = clone();
    final attempt =
        (badReference['attempts'] as List).first as Map<String, Object?>;
    ((attempt['observations'] as List).last
        as Map<String, Object?>)['referenceId'] = 'fr-word-rue';
    invalid.add(badReference);
    final badBool = clone()..['revision'] = true;
    invalid.add(badBool);
    final badCursor = clone();
    ((badCursor['slot'] as Map<String, Object?>)['cursor']
        as Map<String, Object?>)['revision'] = 99;
    invalid.add(badCursor);
    final badTuple = clone();
    badTuple['summaries'] = {
      '["en-fr-phoneme-comparison","fr07b-pair-01",01]': {}
    };
    invalid.add(badTuple);
    final badSession = clone();
    (((((badSession['slot'] as Map)['checkpoint'] as Map)['session']
        as Map)))['unknown'] = 'x';
    invalid.add(badSession);
    final badPairSnapshot = clone();
    final answerReceipt =
        ((badPairSnapshot['receipts'] as List).last as Map<String, Object?>);
    final canonical = jsonDecode(answerReceipt['canonicalCommand'] as String)
        as Map<String, Object?>;
    final action = canonical['action'] as Map<String, Object?>;
    action['expectedRelationSnapshot'] = 'same';
    answerReceipt['canonicalCommand'] = jsonEncode(canonical);
    ((badPairSnapshot['slot'] as Map<String, Object?>)['latestReceipt']
        as Map<String, Object?>)['canonicalCommand'] = jsonEncode(canonical);
    invalid.add(badPairSnapshot);
    for (final value in invalid) {
      final raw = jsonEncode(value);
      expect(() => d.codec.decode(raw, d.scope, d.catalogue),
          throwsA(isA<ComparisonUnavailableException>()));
      expect(jsonEncode(value), raw);
      expect(
          const LearningDocumentCodec().encode(CourseLearningState.empty(
              LearningScope(courseId: 'en-fr', owner: LearningOwner.guest()))),
          v2Bytes);
    }
    expect(
        d.codec.decode(original, d.scope, d.catalogue).attempts, hasLength(1));
  });

  test('codec round trips completion, pair mistakes and durable summaries', () {
    final d = _CodecDriver(LearningOwner.guest());
    d.submit(StartComparisonRun(sessionId: 'complete', policy: LessonPolicy()));
    d.answerFirstPair();
    d.submit(const AdvanceComparisonPair());
    for (var i = 1; i < 10; i++) {
      d.answerCurrent(true);
      d.submit(const AdvanceComparisonPair());
    }
    d.submit(const FinishComparisonRun(recordCompletion: true));
    d.submit(const ReviewComparisonPairs());
    final raw = d.codec.encode(d.state);
    final decoded = d.codec.decode(raw, d.scope, d.catalogue);
    expect(decoded.completions, hasLength(1));
    expect(decoded.summaries, hasLength(10));
    expect(decoded.mistakes, hasLength(1));
    expect(d.codec.encode(decoded), raw);
    expect(decoded.receipts.map((r) => r.canonicalCommand).join(),
        contains('"kind":"review"'));
    final pruned = jsonDecode(raw) as Map<String, Object?>;
    pruned['receipts'] = <Object?>[];
    expect(d.codec.decode(jsonEncode(pruned), d.scope, d.catalogue).completions,
        hasLength(1),
        reason: 'completion remains valid after its Finish receipt is pruned');
    final mutation = jsonDecode(raw) as Map<String, Object?>;
    ((mutation['completions'] as List).single
        as Map<String, Object?>)['extra'] = true;
    expect(() => d.codec.decode(jsonEncode(mutation), d.scope, d.catalogue),
        throwsA(isA<ComparisonUnavailableException>()));
  });

  test('pruned answer receipt still binds expected relation to catalogue', () {
    final d = _CodecDriver(LearningOwner.guest());
    d.submit(StartComparisonRun(sessionId: 's', policy: LessonPolicy()));
    d.answerFirstPair();
    final document =
        jsonDecode(d.codec.encode(d.state)) as Map<String, Object?>;
    document['attempts'] = <Object?>[];
    final receipts = document['receipts'] as List;
    final answerReceipt = receipts.last as Map<String, Object?>;
    final command = jsonDecode(answerReceipt['canonicalCommand'] as String)
        as Map<String, Object?>;
    (command['action'] as Map<String, Object?>)['expectedRelationSnapshot'] =
        'same';
    final tampered = jsonEncode(command);
    answerReceipt['canonicalCommand'] = tampered;
    ((document['slot'] as Map<String, Object?>)['latestReceipt']
        as Map<String, Object?>)['canonicalCommand'] = tampered;
    expect(() => d.codec.decode(jsonEncode(document), d.scope, d.catalogue),
        throwsA(isA<ComparisonUnavailableException>()));
  });

  test('latest start cannot restore a forged answered checkpoint', () {
    final d = _CodecDriver(LearningOwner.guest());
    d.submit(StartComparisonRun(sessionId: 'fresh', policy: LessonPolicy()));
    final raw = jsonDecode(d.codec.encode(d.state)) as Map<String, Object?>;
    final ids = d.catalogue.exercises.map((exercise) => exercise.id).toList();
    final forged = LessonSectionSession(itemIds: ids, sessionId: 'fresh');
    for (var index = 0; index < ids.length; index++) {
      forged.submit(true);
      forged.advance();
    }
    final checkpoint = ((raw['slot'] as Map<String, Object?>)['checkpoint']
        as Map<String, Object?>);
    checkpoint['session'] = forged.toJson();
    expect(() => d.codec.decode(jsonEncode(raw), d.scope, d.catalogue),
        throwsA(isA<ComparisonUnavailableException>()));
  });

  test('latest start policy must match saved checkpoint policy', () {
    final d = _CodecDriver(LearningOwner.guest());
    d.submit(StartComparisonRun(sessionId: 'policy', policy: LessonPolicy()));
    final raw = jsonDecode(d.codec.encode(d.state)) as Map<String, Object?>;
    final receipts = raw['receipts'] as List;
    final receipt = receipts.single as Map<String, Object?>;
    final canonical = jsonDecode(receipt['canonicalCommand'] as String)
        as Map<String, Object?>;
    final action = canonical['action'] as Map<String, Object?>;
    (action['policy'] as Map<String, Object?>)['completionThresholdPercent'] =
        70;
    final changed = jsonEncode(canonical);
    receipt['canonicalCommand'] = changed;
    final latest = ((raw['slot'] as Map<String, Object?>)['latestReceipt']
        as Map<String, Object?>);
    latest['canonicalCommand'] = changed;
    expect(() => d.codec.decode(jsonEncode(raw), d.scope, d.catalogue),
        throwsA(isA<ComparisonUnavailableException>()));
  });

  test('latest answer correctness must agree with saved checkpoint', () {
    final d = _CodecDriver(LearningOwner.guest());
    d.submit(StartComparisonRun(sessionId: 'answer', policy: LessonPolicy()));
    d.answerFirstPair();
    final raw = jsonDecode(d.codec.encode(d.state)) as Map<String, Object?>;
    final session = (((raw['slot'] as Map<String, Object?>)['checkpoint']
        as Map<String, Object?>)['session'] as Map<String, Object?>);
    (session['latestAnswers'] as Map<String, Object?>)['fr07b-pair-01'] = true;
    session['lastCorrect'] = true;
    expect(() => d.codec.decode(jsonEncode(raw), d.scope, d.catalogue),
        throwsA(isA<ComparisonUnavailableException>()));
  });

  test('latest answer must agree with an available retained attempt', () {
    final d = _CodecDriver(LearningOwner.guest());
    d.submit(StartComparisonRun(sessionId: 'attempt', policy: LessonPolicy()));
    d.answerFirstPair();
    final raw = jsonDecode(d.codec.encode(d.state)) as Map<String, Object?>;
    raw['receipts'] = <Object?>[];
    final attempt = (raw['attempts'] as List).single as Map<String, Object?>;
    attempt['selectedRelation'] = 'different';
    attempt['correct'] = true;
    final summary =
        (raw['summaries'] as Map).values.single as Map<String, Object?>;
    summary['firstInRun'] = {'correct': 1, 'total': 1};
    expect(() => d.codec.decode(jsonEncode(raw), d.scope, d.catalogue),
        throwsA(isA<ComparisonUnavailableException>()));
  });

  test('zero-commit document cannot contain phantom completion', () {
    final scope =
        ComparisonProfileScope(courseId: 'en-fr', owner: LearningOwner.guest());
    const codec = ComparisonLearningCodec();
    final raw = jsonDecode(codec.encode(ComparisonLearningState.empty(scope)))
        as Map<String, Object?>;
    raw['completions'] = [
      {
        'activityId': 'en-fr-phoneme-comparison',
        'contentRevision': 1,
        'policyRevision': 1,
        'thresholdPercent': 80,
        'committedAt': '2026-01-01T00:00:00.000Z'
      }
    ];
    expect(
        () => codec.decode(
            jsonEncode(raw), scope, loadFrenchComparisonCatalogue()),
        throwsA(isA<ComparisonUnavailableException>()));
  });

  test('recorded finish receipt must retain its completion identity', () {
    final d = _CodecDriver(LearningOwner.guest());
    d.submit(StartComparisonRun(sessionId: 'finish', policy: LessonPolicy()));
    for (var index = 0; index < d.catalogue.exercises.length; index++) {
      d.answerCurrent(true);
      d.submit(const AdvanceComparisonPair());
    }
    d.submit(const FinishComparisonRun(recordCompletion: true));
    final raw = jsonDecode(d.codec.encode(d.state)) as Map<String, Object?>;
    raw['completions'] = <Object?>[];
    expect(() => d.codec.decode(jsonEncode(raw), d.scope, d.catalogue),
        throwsA(isA<ComparisonUnavailableException>()));
  });

  test('summary cannot relabel a retained wrong attempt as a success', () {
    final d = _CodecDriver(LearningOwner.guest());
    d.submit(StartComparisonRun(sessionId: 'summary', policy: LessonPolicy()));
    d.answerFirstPair();
    final raw = jsonDecode(d.codec.encode(d.state)) as Map<String, Object?>;
    final summaries = raw['summaries'] as Map<String, Object?>;
    final summary = summaries.values.single as Map<String, Object?>;
    summary['firstInRun'] = {'correct': 1, 'total': 1};
    expect(() => d.codec.decode(jsonEncode(raw), d.scope, d.catalogue),
        throwsA(isA<ComparisonUnavailableException>()));
  });

  test('round two attempts cannot be relabeled as first-pass evidence', () {
    final d = _CodecDriver(LearningOwner.guest());
    d.submit(StartComparisonRun(sessionId: 'rounds', policy: LessonPolicy()));
    for (var index = 0; index < d.catalogue.exercises.length; index++) {
      d.answerCurrent(false);
      d.submit(const AdvanceComparisonPair());
    }
    d.submit(const ReviewComparisonPairs());
    d.answerCurrent(false);
    d.submit(const AdvanceComparisonPair());
    final raw = jsonDecode(d.codec.encode(d.state)) as Map<String, Object?>;
    raw['receipts'] = <Object?>[];
    final attempt = (raw['attempts'] as List).last as Map<String, Object?>;
    expect(attempt['round'], 2);
    attempt['presentation'] = 'firstInRun';
    attempt['afterDebrief'] = false;
    final pairId = attempt['pairId'] as String;
    final summary = (raw['summaries'] as Map<String, Object?>)
        .entries
        .singleWhere((entry) => (jsonDecode(entry.key) as List)[1] == pairId)
        .value as Map<String, Object?>;
    final first = summary['firstInRun'] as Map<String, Object?>;
    final repeat = summary['repeatInRun'] as Map<String, Object?>;
    final after = summary['afterDebrief'] as Map<String, Object?>;
    final correct = attempt['correct'] as bool;
    first['total'] = (first['total'] as int) + 1;
    first['correct'] = (first['correct'] as int) + (correct ? 1 : 0);
    repeat['total'] = (repeat['total'] as int) - 1;
    repeat['correct'] = (repeat['correct'] as int) - (correct ? 1 : 0);
    after['total'] = (after['total'] as int) - 1;
    after['correct'] = (after['correct'] as int) - (correct ? 1 : 0);
    expect(() => d.codec.decode(jsonEncode(raw), d.scope, d.catalogue),
        throwsA(isA<ComparisonUnavailableException>()));
  });

  test('saved comparison review counters must fit safe integer bounds', () {
    final d = _CodecDriver(LearningOwner.guest());
    d.submit(StartComparisonRun(sessionId: 'large', policy: LessonPolicy()));
    for (var index = 0; index < d.catalogue.exercises.length; index++) {
      d.answerCurrent(index != 0);
      d.submit(const AdvanceComparisonPair());
    }
    d.submit(const ReviewComparisonPairs());
    final raw = jsonDecode(d.codec.encode(d.state)) as Map<String, Object?>;
    final checkpoint = ((raw['slot'] as Map<String, Object?>)['checkpoint']
        as Map<String, Object?>);
    final session = _mutableSession(d.state.checkpoint!.sessionJson);
    session['round'] = 9007199254740992;
    session['attemptCount'] = 9007199254741000;
    checkpoint['session'] = session;
    expect(() => d.codec.decode(jsonEncode(raw), d.scope, d.catalogue),
        throwsA(isA<ComparisonUnavailableException>()));
  });

  test('advance checkpoint outcomes agree with latest current-run answers', () {
    final d = _CodecDriver(LearningOwner.guest());
    d.submit(
        StartComparisonRun(sessionId: 'advance-facts', policy: LessonPolicy()));
    d.answerFirstPair();
    d.submit(const AdvanceComparisonPair());
    final raw = jsonDecode(d.codec.encode(d.state)) as Map<String, Object?>;
    final session = (((raw['slot'] as Map<String, Object?>)['checkpoint']
        as Map<String, Object?>)['session'] as Map<String, Object?>);
    (session['latestAnswers'] as Map<String, Object?>)['fr07b-pair-01'] = true;
    session['lastCorrect'] = true;
    expect(() => d.codec.decode(jsonEncode(raw), d.scope, d.catalogue),
        throwsA(isA<ComparisonUnavailableException>()));
  });

  test('review checkpoint preserves corrected latest evidence', () {
    final d = _CodecDriver(LearningOwner.guest());
    d.submit(
        StartComparisonRun(sessionId: 'review-facts', policy: LessonPolicy()));
    for (var index = 0; index < d.catalogue.exercises.length; index++) {
      d.answerCurrent(index > 1);
      d.submit(const AdvanceComparisonPair());
    }
    d.submit(const ReviewComparisonPairs());
    d.answerCurrent(true);
    d.submit(const AdvanceComparisonPair());
    final raw = jsonDecode(d.codec.encode(d.state)) as Map<String, Object?>;
    expect(d.codec.decode(jsonEncode(raw), d.scope, d.catalogue).checkpoint,
        isNotNull);
    final session = (((raw['slot'] as Map<String, Object?>)['checkpoint']
        as Map<String, Object?>)['session'] as Map<String, Object?>);
    (session['latestAnswers'] as Map<String, Object?>)['fr07b-pair-01'] = false;
    session['lastCorrect'] = false;
    expect(() => d.codec.decode(jsonEncode(raw), d.scope, d.catalogue),
        throwsA(isA<ComparisonUnavailableException>()));
  });

  test('latest finish checkpoint agrees with all available answer evidence',
      () {
    final d = _CodecDriver(LearningOwner.guest());
    d.submit(
        StartComparisonRun(sessionId: 'finish-facts', policy: LessonPolicy()));
    for (var index = 0; index < d.catalogue.exercises.length; index++) {
      d.answerCurrent(true);
      d.submit(const AdvanceComparisonPair());
    }
    d.submit(const FinishComparisonRun(recordCompletion: true));
    final raw = jsonDecode(d.codec.encode(d.state)) as Map<String, Object?>;
    final session = (((raw['slot'] as Map<String, Object?>)['checkpoint']
        as Map<String, Object?>)['session'] as Map<String, Object?>);
    (session['latestAnswers'] as Map<String, Object?>)['fr07b-pair-01'] = false;
    expect(() => d.codec.decode(jsonEncode(raw), d.scope, d.catalogue),
        throwsA(isA<ComparisonUnavailableException>()));
  });

  test(
      'new run ignores prior-generation outcomes and pruned evidence stays optional',
      () {
    final d = _CodecDriver(LearningOwner.guest());
    d.submit(StartComparisonRun(sessionId: 'old-run', policy: LessonPolicy()));
    d.answerFirstPair();
    d.submit(StartComparisonRun(sessionId: 'new-run', policy: LessonPolicy()));
    expect(
        d.codec
            .decode(d.codec.encode(d.state), d.scope, d.catalogue)
            .checkpoint!
            .sessionJson['latestAnswers'],
        isEmpty);

    d.answerFirstPair();
    d.submit(const AdvanceComparisonPair());
    final raw = jsonDecode(d.codec.encode(d.state)) as Map<String, Object?>;
    raw['attempts'] = <Object?>[];
    raw['receipts'] = <Object?>[];
    expect(d.codec.decode(jsonEncode(raw), d.scope, d.catalogue).checkpoint,
        isNotNull);
  });

  test('completion contradicted by retained initial Start receipt is rejected',
      () {
    final d = _CodecDriver(LearningOwner.guest());
    d.submit(StartComparisonRun(sessionId: 'phantom', policy: LessonPolicy()));
    final raw = jsonDecode(d.codec.encode(d.state)) as Map<String, Object?>;
    raw['completions'] = [
      {
        'activityId': d.catalogue.activityId,
        'contentRevision': d.catalogue.contentRevision,
        'policyRevision': 1,
        'thresholdPercent': 80,
        'committedAt': '2026-01-01T00:00:00.000Z'
      }
    ];
    expect(() => d.codec.decode(jsonEncode(raw), d.scope, d.catalogue),
        throwsA(isA<ComparisonUnavailableException>()));
  });

  test('latest ordinal-one Start header proves pruned history cannot finish',
      () {
    final d = _CodecDriver(LearningOwner.guest());
    d.submit(StartComparisonRun(
        sessionId: 'phantom-pruned', policy: LessonPolicy()));
    final raw = jsonDecode(d.codec.encode(d.state)) as Map<String, Object?>;
    raw['receipts'] = <Object?>[];
    raw['completions'] = [
      {
        'activityId': d.catalogue.activityId,
        'contentRevision': d.catalogue.contentRevision,
        'policyRevision': 1,
        'thresholdPercent': 80,
        'committedAt': '2026-01-01T00:00:00.000Z'
      }
    ];
    expect(() => d.codec.decode(jsonEncode(raw), d.scope, d.catalogue),
        throwsA(isA<ComparisonUnavailableException>()));
  });

  test('retained Finish completion must match the run start threshold', () {
    final d = _CodecDriver(LearningOwner.guest());
    d.submit(StartComparisonRun(
        sessionId: 'threshold-finish', policy: LessonPolicy()));
    for (var index = 0; index < d.catalogue.exercises.length; index++) {
      d.answerCurrent(true);
      d.submit(const AdvanceComparisonPair());
    }
    d.submit(const FinishComparisonRun(recordCompletion: true));
    final raw = jsonDecode(d.codec.encode(d.state)) as Map<String, Object?>;
    ((raw['completions'] as List).single
        as Map<String, Object?>)['thresholdPercent'] = 90;
    expect(() => d.codec.decode(jsonEncode(raw), d.scope, d.catalogue),
        throwsA(isA<ComparisonUnavailableException>()));
  });

  test('complete receipt history justifies completion by its run policy', () {
    final d = _CodecDriver(LearningOwner.guest());
    d.submit(
        StartComparisonRun(sessionId: 'completed-80', policy: LessonPolicy()));
    for (var index = 0; index < d.catalogue.exercises.length; index++) {
      d.answerCurrent(true);
      d.submit(const AdvanceComparisonPair());
    }
    d.submit(const FinishComparisonRun(recordCompletion: true));
    d.submit(StartComparisonRun(
        sessionId: 'unfinished-90',
        policy: LessonPolicy(completionThresholdPercent: 90)));
    final raw = jsonDecode(d.codec.encode(d.state)) as Map<String, Object?>;
    expect(d.codec.decode(jsonEncode(raw), d.scope, d.catalogue).completions,
        hasLength(1));
    final pruned = jsonDecode(jsonEncode(raw)) as Map<String, Object?>;
    pruned['receipts'] = <Object?>[];
    expect(d.codec.decode(jsonEncode(pruned), d.scope, d.catalogue).completions,
        hasLength(1),
        reason: 'older completion may predate pruned receipt history');
    final mismatchedFinish =
        jsonDecode(jsonEncode(raw)) as Map<String, Object?>;
    ((mismatchedFinish['completions'] as List).single
        as Map<String, Object?>)['thresholdPercent'] = 90;
    expect(
        () =>
            d.codec.decode(jsonEncode(mismatchedFinish), d.scope, d.catalogue),
        throwsA(isA<ComparisonUnavailableException>()));
    final completions = raw['completions'] as List;
    completions.add({
      'activityId': d.catalogue.activityId,
      'contentRevision': d.catalogue.contentRevision,
      'policyRevision': 1,
      'thresholdPercent': 90,
      'committedAt': '2026-01-01T00:05:00.000Z'
    });
    expect(() => d.codec.decode(jsonEncode(raw), d.scope, d.catalogue),
        throwsA(isA<ComparisonUnavailableException>()));
  });

  test('Finish false cannot justify completion in complete receipt history',
      () {
    final d = _CodecDriver(LearningOwner.guest());
    d.submit(
        StartComparisonRun(sessionId: 'review-only', policy: LessonPolicy()));
    for (var index = 0; index < d.catalogue.exercises.length; index++) {
      d.answerCurrent(true);
      d.submit(const AdvanceComparisonPair());
    }
    d.submit(const FinishComparisonRun(recordCompletion: false));
    final raw = jsonDecode(d.codec.encode(d.state)) as Map<String, Object?>;
    raw['completions'] = [
      {
        'activityId': d.catalogue.activityId,
        'contentRevision': d.catalogue.contentRevision,
        'policyRevision': 1,
        'thresholdPercent': 80,
        'committedAt': '2026-01-01T00:05:00.000Z'
      }
    ];
    expect(() => d.codec.decode(jsonEncode(raw), d.scope, d.catalogue),
        throwsA(isA<ComparisonUnavailableException>()));
  });
}

final class _CodecDriver {
  _CodecDriver(LearningOwner owner)
      : scope = ComparisonProfileScope(courseId: 'en-fr', owner: owner),
        catalogue = loadFrenchComparisonCatalogue() {
    engine = ComparisonLearningTransitionEngine(catalogue: catalogue);
    state = ComparisonLearningState.empty(scope);
  }
  final ComparisonProfileScope scope;
  final ComparisonCatalogue catalogue;
  final codec = const ComparisonLearningCodec();
  late final ComparisonLearningTransitionEngine engine;
  late ComparisonLearningState state;
  int n = 0;
  void submit(ComparisonAction action) {
    n++;
    final command = engine.prepare(
        state: state,
        activityId: catalogue.activityId,
        action: action,
        authGeneration: 3,
        token: 'token${n.toString().padLeft(17, '0')}',
        submittedAt: DateTime.utc(2026, 1, 1, 0, 0, n));
    state = engine
        .evaluate(
            state: state,
            command: command,
            committedAt: DateTime.utc(2026, 1, 1, 0, 0, n + 1))
        .nextState;
  }

  void answerFirstPair() {
    final pair = catalogue.exercise('fr07b-pair-01');
    final observations = [
      for (final sample in [pair.sampleA, pair.sampleB])
        ComparisonPlaybackObservation(
            slot: sample.slot,
            referenceId: sample.referenceId,
            outcome: CourseAudioOutcome.completed,
            source: CourseAudioSource.unverifiedRecording,
            activityId: catalogue.activityId,
            runGeneration: state.slot!.cursor.generation,
            round: 1,
            pairId: pair.id,
            profile: scope,
            uiGeneration: 77)
    ];
    submit(AnswerComparisonPair(ComparePhonemesAnswer(
        selectedRelation: PhonemeRelation.same,
        expectedRelationSnapshot: pair.expectedRelation,
        observations: observations)));
  }

  void answerCurrent(bool correct) {
    final session = LessonSectionSession.fromJson(
        _mutableSession(state.checkpoint!.sessionJson),
        itemIds: catalogue.exercises.map((e) => e.id).toList(),
        contentRevision: catalogue.contentRevision);
    final id = session.currentItemId!;
    final pair = catalogue.exercise(id);
    final selected = correct
        ? pair.expectedRelation
        : (pair.expectedRelation == PhonemeRelation.same
            ? PhonemeRelation.different
            : PhonemeRelation.same);
    final observations = [
      for (final sample in [pair.sampleA, pair.sampleB])
        ComparisonPlaybackObservation(
            slot: sample.slot,
            referenceId: sample.referenceId,
            outcome: CourseAudioOutcome.completed,
            source: CourseAudioSource.unverifiedRecording,
            activityId: catalogue.activityId,
            runGeneration: state.slot!.cursor.generation,
            round: session.round,
            pairId: id,
            profile: scope,
            uiGeneration: n + 1)
    ];
    submit(AnswerComparisonPair(ComparePhonemesAnswer(
        selectedRelation: selected,
        expectedRelationSnapshot: pair.expectedRelation,
        observations: observations)));
  }
}

Map<String, dynamic> _mutableSession(Map<String, Object?> input) {
  Object? copy(Object? v) {
    if (v is Map) {
      return <String, dynamic>{
        for (final e in v.entries) e.key as String: copy(e.value)
      };
    }
    if (v is List) {
      final xs = v.map(copy).toList();
      if (xs.every((x) => x is String)) return xs.cast<String>();
      return xs;
    }
    return v;
  }

  return copy(input) as Map<String, dynamic>;
}

Object? _reverseMaps(Object? value) {
  if (value is Map) {
    final entries = value.entries.toList().reversed;
    return <String, Object?>{
      for (final entry in entries)
        entry.key as String: _reverseMaps(entry.value)
    };
  }
  if (value is List) return value.map(_reverseMaps).toList();
  return value;
}
