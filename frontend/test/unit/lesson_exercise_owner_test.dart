import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:linguist/src/core/course/comparison_content.dart';
import 'package:linguist/src/core/course/course_audio_contract.dart';
import 'package:linguist/src/features/course/lesson_exercise_owner.dart';

void main() {
  group('FrozenExerciseSave', () {
    test('claims synchronously and retry reuses the identical command',
        () async {
      final fence = ExerciseLifecycleFence();
      final command = Object();
      final result = Object();
      final submitted = <Object>[];
      var fail = true;
      var callbacks = 0;
      var pendingWasClearedInCallback = false;
      late FrozenExerciseSave<Object, Object> save;
      save = FrozenExerciseSave<Object, Object>(
        fence: fence,
        submit: (value) async {
          submitted.add(value);
          if (fail) {
            fail = false;
            throw StateError('write failed');
          }
          return result;
        },
        stillOwnsStoreAuthRoute: () => true,
        onAcknowledged: (value) async {
          callbacks++;
          pendingWasClearedInCallback = save.pendingCommand == null;
        },
      );
      final first = save.claimAndSubmit(command);
      final firstFailure = expectLater(first, throwsA(isA<StateError>()));
      expect(save.claimed, isTrue);
      expect(identical(save.pendingCommand, command), isTrue);
      expect(await save.claimAndSubmit(Object()), isNull);
      await firstFailure;
      expect(identical(save.pendingCommand, command), isTrue);
      expect(await save.retry(), same(result));
      expect(submitted.length, 2);
      expect(identical(submitted[0], command), isTrue);
      expect(identical(submitted[1], command), isTrue);
      expect(callbacks, 1);
      expect(pendingWasClearedInCallback, isTrue);
      expect(save.pendingCommand, isNull);
      expect(await save.retry(), isNull);
    });

    test('ineligible owner and lifecycle cannot claim or acknowledge',
        () async {
      final fence = ExerciseLifecycleFence();
      var eligible = false;
      var submissions = 0;
      var callbacks = 0;
      final save = FrozenExerciseSave<Object, Object>(
        fence: fence,
        submit: (_) async {
          submissions++;
          return Object();
        },
        stillOwnsStoreAuthRoute: () => eligible,
        onAcknowledged: (_) async {
          callbacks++;
        },
      );
      expect(await save.claimAndSubmit(Object()), isNull);
      expect(save.claimed, isFalse);
      expect(submissions, 0);
      eligible = true;
      fence.suspend();
      expect(await save.claimAndSubmit(Object()), isNull);
      expect(save.claimed, isFalse);
      expect(submissions, 0);
      fence.resume();
      fence.dispose();
      expect(await save.claimAndSubmit(Object()), isNull);
      expect(save.claimed, isFalse);
      expect(callbacks, 0);
    });

    test('rapid retry coalesces with an eligible held write', () async {
      final gate = Completer<Object>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete(Object());
      });
      final command = Object();
      var submissions = 0;
      final save = FrozenExerciseSave<Object, Object>(
        fence: ExerciseLifecycleFence(),
        submit: (_) {
          submissions++;
          return gate.future;
        },
        stillOwnsStoreAuthRoute: () => true,
        onAcknowledged: (_) async {},
      );
      final first = save.claimAndSubmit(command);
      final firstOutcome = expectLater(first, completion(isNotNull));
      expect(await save.retry(), isNull);
      expect(submissions, 1);
      gate.complete(Object());
      await firstOutcome;
    });

    test(
        'owner loss before acknowledgement retains command and suppresses callback',
        () async {
      final gate = Completer<Object>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete(Object());
      });
      var eligible = true;
      var callbacks = 0;
      final command = Object();
      final save = FrozenExerciseSave<Object, Object>(
        fence: ExerciseLifecycleFence(),
        submit: (_) => gate.future,
        stillOwnsStoreAuthRoute: () => eligible,
        onAcknowledged: (_) async {
          callbacks++;
        },
      );
      final write = save.claimAndSubmit(command);
      eligible = false;
      final outcome = expectLater(write, completion(isNull));
      gate.complete(Object());
      await outcome;
      expect(save.pendingCommand, same(command));
      expect(save.claimed, isTrue);
      expect(callbacks, 0);
      expect(await save.retry(), isNull);
    });

    test(
        'callback failure is separate from saved result and cannot restart write',
        () async {
      final result = Object();
      final callbackError = StateError('navigation failed');
      var submissions = 0;
      final save = FrozenExerciseSave<Object, Object>(
        fence: ExerciseLifecycleFence(),
        submit: (_) async {
          submissions++;
          return result;
        },
        stillOwnsStoreAuthRoute: () => true,
        onAcknowledged: (_) async {
          throw callbackError;
        },
      );
      expect(await save.claimAndSubmit(Object()), same(result));
      expect(save.pendingCommand, isNull);
      expect(save.acknowledgementError, same(callbackError));
      expect(await save.retry(), isNull);
      expect(submissions, 1);
    });

    test('pause orphans held write and resumed retry retains same command',
        () async {
      final oldGate = Completer<Object>();
      final newGate = Completer<Object>();
      addTearDown(() {
        if (!oldGate.isCompleted) oldGate.complete(Object());
        if (!newGate.isCompleted) newGate.complete(Object());
      });
      final command = Object();
      final oldResult = Object(), newResult = Object();
      var submissions = 0;
      var callbacks = 0;
      final fence = ExerciseLifecycleFence();
      final save = FrozenExerciseSave<Object, Object>(
        fence: fence,
        submit: (value) {
          expect(identical(value, command), isTrue);
          submissions++;
          return submissions == 1 ? oldGate.future : newGate.future;
        },
        stillOwnsStoreAuthRoute: () => true,
        onAcknowledged: (_) async {
          callbacks++;
        },
      );
      final oldWrite = save.claimAndSubmit(command);
      fence.suspend();
      expect(save.pendingCommand, same(command));
      fence.resume();
      final retry = save.retry();
      expect(submissions, 2);
      oldGate.complete(oldResult);
      expect(await oldWrite, isNull);
      expect(save.pendingCommand, same(command));
      expect(callbacks, 0);
      newGate.complete(newResult);
      expect(await retry, same(newResult));
      expect(save.pendingCommand, isNull);
      expect(callbacks, 1);
    });

    test('stale submit error is ignored but current error propagates unchanged',
        () async {
      final oldGate = Completer<Object>();
      final currentGate = Completer<Object>();
      addTearDown(() {
        if (!oldGate.isCompleted) oldGate.complete(Object());
        if (!currentGate.isCompleted) currentGate.complete(Object());
      });
      final command = Object();
      final staleError = StateError('stale write');
      final currentError = StateError('current domain conflict');
      var submissions = 0;
      final fence = ExerciseLifecycleFence();
      final save = FrozenExerciseSave<Object, Object>(
        fence: fence,
        submit: (_) {
          submissions++;
          return submissions == 1 ? oldGate.future : currentGate.future;
        },
        stillOwnsStoreAuthRoute: () => true,
        onAcknowledged: (_) async {},
      );
      final oldWrite = save.claimAndSubmit(command);
      fence.suspend();
      fence.resume();
      final newWrite = save.retry();
      final oldOutcome = expectLater(oldWrite, completion(isNull));
      oldGate.completeError(staleError);
      await oldOutcome;
      expect(save.pendingCommand, same(command));
      final newOutcome = expectLater(newWrite, throwsA(same(currentError)));
      currentGate.completeError(currentError);
      await newOutcome;
      expect(save.pendingCommand, same(command));
      expect(identical(save.pendingCommand, command), isTrue);
    });

    test('explicit conflict reload retires operation and permits a new claim',
        () async {
      final oldGate = Completer<Object>();
      final newGate = Completer<Object>();
      addTearDown(() {
        if (!oldGate.isCompleted) oldGate.complete(Object());
        if (!newGate.isCompleted) newGate.complete(Object());
      });
      final command = Object();
      var submissions = 0;
      final fence = ExerciseLifecycleFence();
      final save = FrozenExerciseSave<Object, Object>(
        fence: fence,
        submit: (_) {
          submissions++;
          return submissions == 1 ? oldGate.future : newGate.future;
        },
        stillOwnsStoreAuthRoute: () => true,
        onAcknowledged: (_) async {},
      );
      final oldWrite = save.claimAndSubmit(command);
      final oldOutcome = expectLater(oldWrite, completion(isNull));
      save.onConflictReloaded();
      expect(save.pendingCommand, isNull);
      expect(save.claimed, isFalse);
      final next = Object();
      final newWrite = save.claimAndSubmit(next);
      expect(submissions, 2);
      oldGate.complete(Object());
      await oldOutcome;
      expect(save.pendingCommand, same(next));
      save.retireOwner();
      newGate.complete(Object());
      expect(await newWrite, isNull);
      expect(save.pendingCommand, isNull);
      expect(submissions, 2);
    });

    test('older callback failure cannot overwrite error state of next claim',
        () async {
      final firstResult = Object(), secondResult = Object();
      final secondGate = Completer<Object>();
      addTearDown(() {
        if (!secondGate.isCompleted) secondGate.complete(Object());
      });
      final firstCallbackError = StateError('old callback');
      var submissions = 0;
      Future<Object?>? nextClaim;
      late FrozenExerciseSave<Object, Object> save;
      save = FrozenExerciseSave<Object, Object>(
        fence: ExerciseLifecycleFence(),
        submit: (_) {
          submissions++;
          return submissions == 1
              ? Future.value(firstResult)
              : secondGate.future;
        },
        stillOwnsStoreAuthRoute: () => true,
        onAcknowledged: (_) async {
          if (submissions == 1) {
            nextClaim = save.claimAndSubmit(Object());
            throw firstCallbackError;
          }
        },
      );
      expect(await save.claimAndSubmit(Object()), same(firstResult));
      expect(save.acknowledgementError, isNull);
      expect(save.pendingCommand, isNotNull);
      secondGate.complete(secondResult);
      expect(await nextClaim, same(secondResult));
      expect(save.pendingCommand, isNull);
      expect(save.acknowledgementError, isNull);
      expect(submissions, 2);
    });
  });

  group('Exercise identities', () {
    test('equivalent reconstructed identities compare by value', () {
      // ignore: prefer_const_constructors
      final first = ExercisePromptIdentity(
        activityId: 'activity',
        runGeneration: 1,
        round: 2,
        itemId: 'item',
      );
      // ignore: prefer_const_constructors
      final equivalent = ExercisePromptIdentity(
        activityId: 'activity',
        runGeneration: 1,
        round: 2,
        itemId: 'item',
      );
      expect(equivalent, first);
      expect(equivalent.hashCode, first.hashCode);

      final request = ExerciseRequestIdentity(
        prompt: first,
        sample: ComparisonSample.a,
        referenceId: 'reference',
        lifecycleEpoch: 7,
        playbackNonce: 1,
      );
      final equivalentRequest = ExerciseRequestIdentity(
        prompt: equivalent,
        sample: ComparisonSample.a,
        referenceId: 'reference',
        lifecycleEpoch: 7,
        playbackNonce: 1,
      );
      expect(equivalentRequest, request);
      expect(equivalentRequest.hashCode, request.hashCode);
      expect(identical(first, equivalent), isFalse);
      expect(identical(request, equivalentRequest), isFalse);
      expect({request}.contains(equivalentRequest), isTrue);
      expect(
        {
          const ExercisePromptIdentity(
              activityId: 'other', runGeneration: 1, round: 2, itemId: 'item'),
          const ExercisePromptIdentity(
              activityId: 'activity',
              runGeneration: 2,
              round: 2,
              itemId: 'item'),
          const ExercisePromptIdentity(
              activityId: 'activity',
              runGeneration: 1,
              round: 3,
              itemId: 'item'),
          const ExercisePromptIdentity(
              activityId: 'activity',
              runGeneration: 1,
              round: 2,
              itemId: 'other'),
        }.length,
        4,
      );
      expect(
          {
            request,
            ExerciseRequestIdentity(
                prompt: first,
                sample: ComparisonSample.b,
                referenceId: 'reference',
                lifecycleEpoch: 7,
                playbackNonce: 1),
            ExerciseRequestIdentity(
                prompt: first,
                sample: ComparisonSample.a,
                referenceId: 'other',
                lifecycleEpoch: 7,
                playbackNonce: 1),
            ExerciseRequestIdentity(
                prompt: first,
                sample: ComparisonSample.a,
                referenceId: 'reference',
                lifecycleEpoch: 8,
                playbackNonce: 1),
            ExerciseRequestIdentity(
                prompt: first,
                sample: ComparisonSample.a,
                referenceId: 'reference',
                lifecycleEpoch: 7,
                playbackNonce: 2),
          }.length,
          5);
    });
  });

  group('ExerciseAudioGrants', () {
    test('grants require exact current requests and one discovery sample', () {
      // ignore: prefer_const_constructors
      final prompt = ExercisePromptIdentity(
        activityId: comparisonActivityId,
        runGeneration: 1,
        round: 1,
        itemId: 'fr07b-pair-01',
      );
      final grants = ExerciseAudioGrants<CourseAudioSource>(
        requiredSamples: {ComparisonSample.a, ComparisonSample.b},
      )..beginPrompt(prompt);
      final aRequest = ExerciseRequestIdentity(
        prompt: prompt,
        sample: ComparisonSample.a,
        referenceId: 'fr-word-tout',
        lifecycleEpoch: 7,
        playbackNonce: 1,
      );
      grants.beginSample(aRequest);
      expect(
        grants.acceptSuccess(
          // ignore: prefer_const_constructors
          request: ExerciseRequestIdentity(
            // ignore: prefer_const_constructors
            prompt: ExercisePromptIdentity(
              activityId: comparisonActivityId,
              runGeneration: 1,
              round: 1,
              itemId: 'fr07b-pair-01',
            ),
            sample: ComparisonSample.a,
            referenceId: 'fr-word-tout',
            lifecycleEpoch: 7,
            playbackNonce: 1,
          ),
          actualReferenceId: 'fr-word-tout',
          outcome: CourseAudioOutcome.completed,
          actualSource: CourseAudioSource.unverifiedRecording,
        ),
        isTrue,
      );
      expect(grants.grantFor(ComparisonSample.a)?.request.playbackNonce, 1);
      expect(grants.canAnswer, isFalse);
      final bRequest = ExerciseRequestIdentity(
        prompt: prompt,
        sample: ComparisonSample.b,
        referenceId: 'fr-word-tu',
        lifecycleEpoch: 7,
        playbackNonce: 2,
      );
      grants.beginSample(bRequest);
      expect(
        grants.acceptSuccess(
          request: bRequest,
          actualReferenceId: 'fr-word-tu',
          outcome: CourseAudioOutcome.completed,
          actualSource: CourseAudioSource.unverifiedRecording,
        ),
        isTrue,
      );
      expect(grants.canAnswer, isTrue);
      grants.beginSample(ExerciseRequestIdentity(
        prompt: prompt,
        sample: ComparisonSample.a,
        referenceId: 'fr-word-tout',
        lifecycleEpoch: 7,
        playbackNonce: 3,
      ));
      expect(
        grants.acceptSuccess(
          request: aRequest,
          actualReferenceId: 'fr-word-tout',
          outcome: CourseAudioOutcome.completed,
          actualSource: CourseAudioSource.unverifiedRecording,
        ),
        isFalse,
      );
      expect(grants.grantFor(ComparisonSample.b), isNotNull);
      expect(grants.canAnswer, isFalse);

      final discovery = ExerciseAudioGrants<CourseAudioSource>(
        requiredSamples: {null},
      )..beginPrompt(prompt);
      final legacyRequest = ExerciseRequestIdentity(
        prompt: prompt,
        sample: null,
        referenceId: 'legacy-item',
        lifecycleEpoch: 7,
        playbackNonce: 4,
      );
      discovery.beginSample(legacyRequest);
      expect(
        discovery.acceptSuccess(
          request: legacyRequest,
          actualReferenceId: 'legacy-item',
          outcome: CourseAudioOutcome.completed,
          actualSource: CourseAudioSource.unverifiedRecording,
        ),
        isTrue,
      );
      expect(discovery.canAnswer, isTrue);
    });

    test('grants from different lifecycle epochs cannot combine', () {
      const prompt = ExercisePromptIdentity(
          activityId: 'activity', runGeneration: 1, round: 1, itemId: 'item');
      final grants = ExerciseAudioGrants<String>(
          requiredSamples: {ComparisonSample.a, ComparisonSample.b})
        ..beginPrompt(prompt);
      ExerciseRequestIdentity request(
              ComparisonSample sample, int epoch, int nonce) =>
          ExerciseRequestIdentity(
              prompt: prompt,
              sample: sample,
              referenceId: sample.name,
              lifecycleEpoch: epoch,
              playbackNonce: nonce);
      final a = request(ComparisonSample.a, 7, 1);
      grants.beginSample(a);
      expect(
          grants.acceptSuccess(
              request: a,
              actualReferenceId: 'a',
              outcome: CourseAudioOutcome.completed,
              actualSource: 'recording'),
          isTrue);
      final b = request(ComparisonSample.b, 8, 2);
      grants.beginSample(b);
      expect(
          grants.acceptSuccess(
              request: b,
              actualReferenceId: 'b',
              outcome: CourseAudioOutcome.completed,
              actualSource: 'recording'),
          isTrue);
      expect(grants.canAnswer, isFalse);
      expect(
          grants.acceptSuccess(
              request: a,
              actualReferenceId: 'a',
              outcome: CourseAudioOutcome.completed,
              actualSource: 'recording'),
          isFalse);
    });

    test('older beginSample cannot replace the latest nonce', () {
      const prompt = ExercisePromptIdentity(
          activityId: 'activity', runGeneration: 1, round: 1, itemId: 'item');
      final grants =
          ExerciseAudioGrants<String>(requiredSamples: {ComparisonSample.a})
            ..beginPrompt(prompt);
      ExerciseRequestIdentity request(int nonce) => ExerciseRequestIdentity(
          prompt: prompt,
          sample: ComparisonSample.a,
          referenceId: 'a',
          lifecycleEpoch: 7,
          playbackNonce: nonce);
      final latest = request(3), old = request(2);
      grants.beginSample(latest);
      grants.beginSample(old);
      expect(
          grants.acceptSuccess(
              request: latest,
              actualReferenceId: 'a',
              outcome: CourseAudioOutcome.completed,
              actualSource: 'recording'),
          isTrue);
      expect(
          grants.acceptSuccess(
              request: old,
              actualReferenceId: 'a',
              outcome: CourseAudioOutcome.completed,
              actualSource: 'recording'),
          isFalse);
    });

    test('failure, cancellation and mismatched playback cannot grant hearing',
        () {
      const prompt = ExercisePromptIdentity(
          activityId: 'activity', runGeneration: 1, round: 1, itemId: 'item');
      final grants =
          ExerciseAudioGrants<String>(requiredSamples: {ComparisonSample.a})
            ..beginPrompt(prompt);
      const request = ExerciseRequestIdentity(
          prompt: prompt,
          sample: ComparisonSample.a,
          referenceId: 'a',
          lifecycleEpoch: 7,
          playbackNonce: 1);
      const otherPrompt = ExercisePromptIdentity(
          activityId: 'activity', runGeneration: 1, round: 1, itemId: 'other');
      final cases = <({
        ExerciseRequestIdentity request,
        String? ref,
        CourseAudioOutcome outcome,
        String? source
      })>[
        (
          request: request,
          ref: 'wrong',
          outcome: CourseAudioOutcome.completed,
          source: 'recording'
        ),
        (
          request: request,
          ref: 'a',
          outcome: CourseAudioOutcome.cancelled,
          source: 'recording'
        ),
        (
          request: request,
          ref: 'a',
          outcome: CourseAudioOutcome.failed,
          source: 'recording'
        ),
        (
          request: request,
          ref: 'a',
          outcome: CourseAudioOutcome.completed,
          source: null
        ),
        (
          request: const ExerciseRequestIdentity(
              prompt: otherPrompt,
              sample: ComparisonSample.a,
              referenceId: 'a',
              lifecycleEpoch: 7,
              playbackNonce: 1),
          ref: 'a',
          outcome: CourseAudioOutcome.completed,
          source: 'recording'
        ),
        (
          request: const ExerciseRequestIdentity(
              prompt: prompt,
              sample: ComparisonSample.b,
              referenceId: 'a',
              lifecycleEpoch: 7,
              playbackNonce: 1),
          ref: 'a',
          outcome: CourseAudioOutcome.completed,
          source: 'recording'
        ),
      ];
      for (final testCase in cases) {
        grants.beginSample(request);
        expect(
            grants.acceptSuccess(
                request: testCase.request,
                actualReferenceId: testCase.ref,
                outcome: testCase.outcome,
                actualSource: testCase.source),
            isFalse);
        expect(grants.canAnswer, isFalse);
      }
    });

    test('new prompt and retirement clear grants and reject late completion',
        () {
      const first = ExercisePromptIdentity(
          activityId: 'activity', runGeneration: 1, round: 1, itemId: 'first');
      const next = ExercisePromptIdentity(
          activityId: 'activity', runGeneration: 1, round: 1, itemId: 'next');
      final grants =
          ExerciseAudioGrants<String>(requiredSamples: {ComparisonSample.a})
            ..beginPrompt(first);
      const request = ExerciseRequestIdentity(
          prompt: first,
          sample: ComparisonSample.a,
          referenceId: 'a',
          lifecycleEpoch: 7,
          playbackNonce: 1);
      grants.beginSample(request);
      expect(
          grants.acceptSuccess(
              request: request,
              actualReferenceId: 'a',
              outcome: CourseAudioOutcome.completed,
              actualSource: 'recording'),
          isTrue);
      grants.beginPrompt(next);
      expect(grants.grantFor(ComparisonSample.a), isNull);
      grants.retire();
      expect(
          grants.acceptSuccess(
              request: request,
              actualReferenceId: 'a',
              outcome: CourseAudioOutcome.completed,
              actualSource: 'recording'),
          isFalse);
      expect(grants.canAnswer, isFalse);
    });
  });

  group('ExerciseLifecycleFence', () {
    test(
        'playback nonce is separate from lifecycle epoch and suspension retires old epoch',
        () {
      final fence = ExerciseLifecycleFence();
      final epoch = fence.lifecycleEpoch;
      expect(fence.owns(epoch), isTrue);
      expect(fence.beginPlayback(), 1);
      expect(fence.lifecycleEpoch, epoch);
      fence.suspend();
      final suspendedEpoch = fence.lifecycleEpoch;
      expect(fence.owns(epoch), isFalse);
      expect(fence.beginPlayback(), 1);
      fence.resume();
      fence.resume();
      expect(fence.owns(suspendedEpoch), isTrue);
      fence.replaceOwner();
      expect(fence.owns(suspendedEpoch), isFalse);
      expect(fence.isSuspended, isFalse);
      final disposed = ExerciseLifecycleFence();
      final disposedEpoch = disposed.lifecycleEpoch;
      disposed.dispose();
      expect(disposed.owns(disposedEpoch), isFalse);
    });
  });
}
