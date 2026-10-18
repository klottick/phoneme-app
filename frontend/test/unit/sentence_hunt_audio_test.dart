import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_audio_catalog.dart';
import 'package:linguist/src/core/course/course_exercise.dart';
import 'package:linguist/src/core/course/french_course.dart';
import 'package:linguist/src/core/course/french_sentence_package.dart';
import 'package:linguist/src/core/course/course_reference_audio.dart';

import '../support/fake_course_recording_session.dart';
import '../support/fake_course_speech_session.dart';
import '../support/sentence_hunt_fixtures.dart';

const String _sentenceReferenceId = 'fr08-vowel-01-audio';
const String _wordReferenceText = 'tout';

final class _FileAssetBundle extends AssetBundle {
  _FileAssetBundle({this.failuresRemaining = 0});

  int failuresRemaining;

  @override
  Future<ByteData> load(String key, {bool cache = true}) async {
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw FlutterError('injected bundle read failure: $key');
    }
    final Uint8List bytes = Uint8List.fromList(File(key).readAsBytesSync());
    return ByteData.sublistView(bytes);
  }
}

final class _FixtureAssetBundle extends AssetBundle {
  _FixtureAssetBundle(
    SentenceHuntPackageFixture fixture, {
    this.failuresRemaining = 0,
    this.gate,
    this.failureAfterGate,
  }) : _files = <String, String>{
          'assets/audio/fr-sentences/manifest.json': fixture.manifestJson,
          'assets/audio/fr-sentences/provenance.json': fixture.provenanceJson,
          'assets/audio/fr-sentences/annotations.json': fixture.annotationsJson,
          'assets/audio/fr-sentences/source-evidence.json':
              fixture.sourceEvidenceJson,
        };

  final Map<String, String> _files;
  final Completer<void>? gate;
  final Object? failureAfterGate;
  final List<String> loads = <String>[];
  int failuresRemaining;

  @override
  Future<ByteData> load(String key, {bool cache = true}) async {
    loads.add(key);
    final Completer<void>? hold = gate;
    if (hold != null) await hold.future;
    final Object? failure = failureAfterGate;
    if (failure != null) throw failure;
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw FlutterError('injected fixture read failure: $key');
    }
    final String? content = _files[key];
    if (content == null) throw FlutterError('unexpected fixture key: $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(content)));
  }
}

final class _FactoryCounts {
  final List<FakeCourseRecordingSession> recordings =
      <FakeCourseRecordingSession>[];
  final List<FakeCourseSpeechSession> speeches = <FakeCourseSpeechSession>[];
}

ProviderContainer _productionBody({
  required CourseAudioCatalogLoader wordLoader,
  required FrenchSentencePackageLoader sentenceLoader,
  required _FactoryCounts counts,
  List<FakeCourseRecordingSession> firstRecordings =
      const <FakeCourseRecordingSession>[],
  List<FakeCourseSpeechSession> firstSpeeches =
      const <FakeCourseSpeechSession>[],
}) {
  return ProviderContainer(overrides: <Override>[
    courseAudioCatalogLoaderProvider.overrideWithValue(wordLoader),
    sentencePackageLoaderProvider.overrideWithValue(sentenceLoader),
    courseRecordingSessionFactoryProvider.overrideWithValue(() {
      final FakeCourseRecordingSession session = firstRecordings.isNotEmpty
          ? firstRecordings.removeAt(0)
          : FakeCourseRecordingSession();
      counts.recordings.add(session);
      return session;
    }),
    courseSpeechSessionFactoryProvider.overrideWithValue(() {
      final FakeCourseSpeechSession session = firstSpeeches.isNotEmpty
          ? firstSpeeches.removeAt(0)
          : FakeCourseSpeechSession();
      counts.speeches.add(session);
      return session;
    }),
  ]);
}

CourseAudioCatalogLoader _wordLoader(AssetBundle bundle) =>
    CourseAudioCatalogLoader(
      bundle: bundle,
      references: frenchCurriculum.audioReferences,
    );

CourseAudioCatalog _sentenceCatalog(
  String id, {
  CourseAudioSource source = CourseAudioSource.reviewedRecording,
}) {
  const String text = 'Tu vois tout, tu souris.';
  final CourseAudioReference reference = CourseAudioReference(
    id: id,
    kind: AudioReferenceKind.sentence,
    spokenText: text,
  );
  return CourseAudioCatalog(
    references: <CourseAudioReference>[reference],
    entries: <CourseAudioEntry>[
      CourseAudioEntry(
        reference: reference,
        recordings: <CourseAudioVariant, CourseAudioRecording>{
          CourseAudioVariant.normal: CourseAudioRecording(
            assetKey: 'assets/audio/fr-sentences/clips/$id.wav',
            byteLength: 64,
            duration: const Duration(milliseconds: 2),
            source: source,
          ),
        },
        credit: CourseAudioCredit(
          referenceId: id,
          spokenText: text,
          creator: 'Synthetic fixture creator',
          sourceUrl: 'https://example.test/source',
          auditedRevisionUrl: 'https://example.test/source/revision/1',
          licenseId: 'CC-BY-4.0',
          licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
          licenseTextAssetKey:
              'assets/audio/fr-sentences/licenses/CC-BY-4.0.txt',
          attribution: 'Synthetic fixture attribution.',
          notices: const <String>['Synthetic test data only.'],
          unchanged: false,
        ),
      ),
    ],
  );
}

final class _DirectHarness {
  _DirectHarness({
    required Future<CourseAudioCatalog> Function() loadCatalog,
    required Future<CourseAudioCatalog> Function(String referenceId)
        loadReferenceCatalog,
    List<FakeCourseRecordingSession> firstRecordings =
        const <FakeCourseRecordingSession>[],
    List<FakeCourseSpeechSession> firstSpeeches =
        const <FakeCourseSpeechSession>[],
    CourseAudioDeadlines deadlines = const CourseAudioDeadlines(
      setup: Duration(milliseconds: 150),
      cleanup: Duration(milliseconds: 200),
      completionFloor: Duration(milliseconds: 50),
      completionSlack: Duration(milliseconds: 80),
      ttsUtterance: Duration(milliseconds: 150),
    ),
  })  : _loadCatalog = loadCatalog,
        _loadReferenceCatalog = loadReferenceCatalog,
        _recordings = List<FakeCourseRecordingSession>.of(firstRecordings),
        _speeches = List<FakeCourseSpeechSession>.of(firstSpeeches),
        _deadlines = deadlines {
    facade = FrenchReferenceAudio(
      loadCatalog: _loadCatalog,
      loadReferenceCatalog: _loadReferenceCatalog,
      recordingFactory: () {
        final FakeCourseRecordingSession session = _recordings.isNotEmpty
            ? _recordings.removeAt(0)
            : FakeCourseRecordingSession();
        counts.recordings.add(session);
        return session;
      },
      speechFactory: () {
        final FakeCourseSpeechSession session = _speeches.isNotEmpty
            ? _speeches.removeAt(0)
            : FakeCourseSpeechSession();
        counts.speeches.add(session);
        return session;
      },
      deadlines: _deadlines,
    );
  }

  final Future<CourseAudioCatalog> Function() _loadCatalog;
  final Future<CourseAudioCatalog> Function(String referenceId)
      _loadReferenceCatalog;
  final List<FakeCourseRecordingSession> _recordings;
  final List<FakeCourseSpeechSession> _speeches;
  final CourseAudioDeadlines _deadlines;
  final _FactoryCounts counts = _FactoryCounts();
  late final FrenchReferenceAudio facade;
}

Future<void> _until(bool Function() condition, String reason) async {
  final Stopwatch stopwatch = Stopwatch()..start();
  while (!condition()) {
    if (stopwatch.elapsed > const Duration(seconds: 5)) {
      fail('timed out waiting for $reason');
    }
    await pumpEventQueue();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('optional resolver is per-reference while speak remains word-only',
      () async {
    final AssetBundle words = _FileAssetBundle();
    final CourseAudioCatalogLoader wordLoader = _wordLoader(words);
    final List<String> resolvedIds = <String>[];
    var wordLoads = 0;
    final FakeCourseRecordingSession sentenceSession =
        FakeCourseRecordingSession();
    final FakeCourseRecordingSession wordSession = FakeCourseRecordingSession();
    final FrenchSentencePackageLoader sentenceLoader =
        FrenchSentencePackageLoader(
      bundle: _FixtureAssetBundle(syntheticSentencePackage(reviewed: true)),
    );
    final _DirectHarness harness = _DirectHarness(
      loadCatalog: () {
        wordLoads++;
        return wordLoader.load();
      },
      loadReferenceCatalog: (String id) {
        resolvedIds.add(id);
        return sentenceLoader.loadAudioForReference(id);
      },
      firstRecordings: <FakeCourseRecordingSession>[
        sentenceSession,
        wordSession,
      ],
    );
    addTearDown(harness.facade.dispose);

    final Future<CourseAudioResult> sentence = harness.facade.playReference(
      _sentenceReferenceId,
      use: CourseAudioUse.reviewedOnly,
      variant: CourseAudioVariant.normal,
      allowPracticeTts: false,
    );
    await sentenceSession.waitForStart();
    sentenceSession.emitCompleted();
    final CourseAudioResult sentenceResult = await sentence;
    expect(sentenceResult.source, CourseAudioSource.reviewedRecording);
    expect(sentenceResult.referenceId, _sentenceReferenceId);
    expect(resolvedIds, <String>[_sentenceReferenceId]);
    expect(wordLoads, 0);

    final Future<void> legacy = harness.facade.speak(_wordReferenceText);
    await wordSession.waitForStart();
    wordSession.emitCompleted();
    await legacy;
    expect(wordLoads, 1,
        reason: 'legacy speak continues through the original word loader');
    expect(resolvedIds, <String>[_sentenceReferenceId],
        reason: 'legacy speak must not call the optional resolver');
    expect(harness.counts.speeches, isEmpty);
  });

  test('resolver source failures retain typed classification without fallback',
      () async {
    final StateError cause = StateError('sentence source unavailable');
    var wordLoads = 0;
    final _DirectHarness failureHarness = _DirectHarness(
      loadCatalog: () async {
        wordLoads++;
        return CourseAudioCatalog(
            references: const <CourseAudioReference>[],
            entries: const <CourseAudioEntry>[]);
      },
      loadReferenceCatalog: (_) => Future<CourseAudioCatalog>.error(
        CourseAudioException(CourseAudioFailure(
          reason: CourseAudioFailureReason.invalidCatalogue,
          cause: cause,
        )),
      ),
      firstRecordings: <FakeCourseRecordingSession>[
        FakeCourseRecordingSession(),
      ],
      firstSpeeches: <FakeCourseSpeechSession>[FakeCourseSpeechSession()],
    );
    addTearDown(failureHarness.facade.dispose);
    final CourseAudioResult failed = await failureHarness.facade.playReference(
      _sentenceReferenceId,
      use: CourseAudioUse.reviewedOnly,
      variant: CourseAudioVariant.normal,
      allowPracticeTts: false,
    );
    expect(failed.failure!.reason, CourseAudioFailureReason.invalidCatalogue);
    expect(identical(failed.failure!.cause, cause), isTrue);
    expect(wordLoads, 0,
        reason: 'resolver failure must not fall through to the word loader');
    expect(failureHarness.counts.recordings, isEmpty);
    expect(failureHarness.counts.speeches, isEmpty);

    final PhaseTimeoutException sourcePhase = PhaseTimeoutException(
      CourseAudioFailureReason.completionTimeout,
      'source phase timeout',
    );
    final _DirectHarness typedHarness = _DirectHarness(
      loadCatalog: () async => CourseAudioCatalog(
          references: const <CourseAudioReference>[],
          entries: const <CourseAudioEntry>[]),
      loadReferenceCatalog: (_) =>
          Future<CourseAudioCatalog>.error(sourcePhase),
    );
    addTearDown(typedHarness.facade.dispose);
    final CourseAudioResult typed = await typedHarness.facade.playReference(
      _sentenceReferenceId,
      use: CourseAudioUse.reviewedOnly,
      variant: CourseAudioVariant.normal,
      allowPracticeTts: false,
    );
    expect(typed.failure!.reason, CourseAudioFailureReason.completionTimeout);
    expect(identical(typed.failure!.cause, sourcePhase), isTrue);
  });

  test('raw resolver timeout is conservative and preserves source diagnostics',
      () async {
    final TimeoutException cause =
        TimeoutException('sentence resolver source timeout');
    final StackTrace sourceStack = StackTrace.fromString(
        '#0 sentence resolver source\n#1 synthetic source boundary');
    var wordLoads = 0;
    final _DirectHarness harness = _DirectHarness(
      loadCatalog: () async {
        wordLoads++;
        return CourseAudioCatalog(
            references: const <CourseAudioReference>[],
            entries: const <CourseAudioEntry>[]);
      },
      loadReferenceCatalog: (_) =>
          Future<CourseAudioCatalog>.error(cause, sourceStack),
      firstRecordings: <FakeCourseRecordingSession>[
        FakeCourseRecordingSession(),
      ],
      firstSpeeches: <FakeCourseSpeechSession>[FakeCourseSpeechSession()],
    );
    addTearDown(harness.facade.dispose);

    final CourseAudioResult result = await harness.facade.playReference(
      _sentenceReferenceId,
      use: CourseAudioUse.alphaPractice,
      variant: CourseAudioVariant.normal,
      allowPracticeTts: true,
    );

    expect(result.outcome, CourseAudioOutcome.failed);
    expect(result.failure!.reason, CourseAudioFailureReason.unsupportedPlayback,
        reason: 'a raw source TimeoutException is not an owned phase expiry');
    expect(identical(result.failure!.cause, cause), isTrue);
    expect(identical(result.failure!.stackTrace, sourceStack), isTrue);
    expect(wordLoads, 0,
        reason: 'resolver failure must not fall through to the word loader');
    expect(harness.counts.recordings, isEmpty,
        reason: 'resolver failure cannot select or construct a recording');
    expect(harness.counts.speeches, isEmpty,
        reason: 'resolver failure cannot fall back to practice speech');
  });

  test('reviewedOnly rejects an unexpected sentence source before factories',
      () async {
    final _DirectHarness harness = _DirectHarness(
      loadCatalog: () async => CourseAudioCatalog(
          references: const <CourseAudioReference>[],
          entries: const <CourseAudioEntry>[]),
      loadReferenceCatalog: (String id) async =>
          _sentenceCatalog(id, source: CourseAudioSource.unverifiedRecording),
      firstRecordings: <FakeCourseRecordingSession>[
        FakeCourseRecordingSession(),
      ],
      firstSpeeches: <FakeCourseSpeechSession>[FakeCourseSpeechSession()],
    );
    addTearDown(harness.facade.dispose);

    final CourseAudioResult result = await harness.facade.playReference(
      _sentenceReferenceId,
      use: CourseAudioUse.reviewedOnly,
      variant: CourseAudioVariant.normal,
      allowPracticeTts: false,
    );
    expect(result.failure!.reason, CourseAudioFailureReason.unreviewedSource);
    expect(harness.counts.recordings, isEmpty);
    expect(harness.counts.speeches, isEmpty);
  });

  test('resolver setup deadline is owned and late success cannot start audio',
      () async {
    final Completer<CourseAudioCatalog> gate = Completer<CourseAudioCatalog>();
    addTearDown(() {
      if (!gate.isCompleted) {
        gate.complete(_sentenceCatalog(_sentenceReferenceId));
      }
    });
    var resolutions = 0;
    final _DirectHarness harness = _DirectHarness(
      loadCatalog: () async => CourseAudioCatalog(
          references: const <CourseAudioReference>[],
          entries: const <CourseAudioEntry>[]),
      loadReferenceCatalog: (_) {
        resolutions++;
        return gate.future;
      },
      firstRecordings: <FakeCourseRecordingSession>[
        FakeCourseRecordingSession(),
      ],
      deadlines: const CourseAudioDeadlines(
        setup: Duration(milliseconds: 20),
        cleanup: Duration(milliseconds: 40),
        completionFloor: Duration(milliseconds: 20),
        completionSlack: Duration(milliseconds: 20),
        ttsUtterance: Duration(milliseconds: 40),
      ),
    );
    addTearDown(harness.facade.dispose);

    final CourseAudioResult result = await harness.facade.playReference(
      _sentenceReferenceId,
      use: CourseAudioUse.reviewedOnly,
      variant: CourseAudioVariant.normal,
      allowPracticeTts: false,
    );
    expect(result.failure!.reason, CourseAudioFailureReason.startupTimeout);
    expect(result.failure!.cause, isA<PhaseTimeoutException>());
    expect(resolutions, 1);
    expect(harness.counts.recordings, isEmpty);

    gate.complete(_sentenceCatalog(_sentenceReferenceId));
    await pumpEventQueue();
    expect(harness.counts.recordings, isEmpty,
        reason: 'a late timeout settlement cannot select a recording');
  });

  test('stale resolver success or error cannot affect the successor owner',
      () async {
    for (final bool failLate in <bool>[false, true]) {
      final Completer<CourseAudioCatalog> gate =
          Completer<CourseAudioCatalog>();
      addTearDown(() {
        if (!gate.isCompleted) {
          gate.complete(_sentenceCatalog(_sentenceReferenceId));
        }
      });
      final CourseAudioCatalogLoader words = _wordLoader(_FileAssetBundle());
      final FakeCourseRecordingSession currentSession =
          FakeCourseRecordingSession();
      final _DirectHarness harness = _DirectHarness(
        loadCatalog: words.load,
        loadReferenceCatalog: (String id) =>
            id == _sentenceReferenceId ? gate.future : words.load(),
        firstRecordings: <FakeCourseRecordingSession>[currentSession],
      );
      addTearDown(harness.facade.dispose);

      final Future<CourseAudioResult> stale = harness.facade.playReference(
        _sentenceReferenceId,
        use: CourseAudioUse.reviewedOnly,
        variant: CourseAudioVariant.normal,
        allowPracticeTts: false,
      );
      await pumpEventQueue();
      final Future<CourseAudioResult> current = harness.facade.playReference(
        'fr-word-tout',
        use: CourseAudioUse.alphaPractice,
        variant: CourseAudioVariant.normal,
        allowPracticeTts: false,
      );
      await currentSession.waitForStart();
      expect((await stale).outcome, CourseAudioOutcome.cancelled);

      if (failLate) {
        gate.completeError(StateError('late sentence catalogue failure'));
      } else {
        gate.complete(_sentenceCatalog(_sentenceReferenceId));
      }
      await pumpEventQueue();
      expect(harness.counts.recordings,
          <FakeCourseRecordingSession>[currentSession]);
      expect(currentSession.calls, isNot(contains('stop')),
          reason: 'a stale resolver cannot stop the current engine');

      currentSession.emitCompleted();
      expect((await current).outcome, CourseAudioOutcome.completed);
      expect(harness.counts.speeches, isEmpty);
    }
  });

  test('resolver waits behind retirement and a failed retirement blocks it',
      () async {
    final FakeCourseRecordingSession predecessor = FakeCourseRecordingSession();
    final Completer<void> retirement = Completer<void>();
    predecessor.stopGate = retirement.future;
    addTearDown(() {
      if (!retirement.isCompleted) {
        retirement.complete();
      }
    });
    var resolverCalls = 0;
    final _DirectHarness harness = _DirectHarness(
      loadCatalog: () async => CourseAudioCatalog(
          references: const <CourseAudioReference>[],
          entries: const <CourseAudioEntry>[]),
      loadReferenceCatalog: (String id) async {
        resolverCalls++;
        return _sentenceCatalog(id);
      },
      firstRecordings: <FakeCourseRecordingSession>[
        predecessor,
        FakeCourseRecordingSession(),
      ],
    );
    addTearDown(harness.facade.dispose);

    final Future<CourseAudioResult> first = harness.facade.playReference(
      'fr08-first-sentence-audio',
      use: CourseAudioUse.reviewedOnly,
      variant: CourseAudioVariant.normal,
      allowPracticeTts: false,
    );
    await predecessor.waitForStart();
    predecessor.emitCompleted();
    expect((await first).outcome, CourseAudioOutcome.completed);
    await _until(() => predecessor.calls.contains('stop'), 'retirement');

    final Future<CourseAudioResult> replacement = harness.facade.playReference(
      'fr08-next-sentence-audio',
      use: CourseAudioUse.reviewedOnly,
      variant: CourseAudioVariant.normal,
      allowPracticeTts: false,
    );
    await pumpEventQueue();
    expect(resolverCalls, 1,
        reason: 'resolution cannot begin while retirement is still pending');

    final StateError cause = StateError('sentence predecessor cleanup failed');
    retirement.completeError(cause);
    final CourseAudioResult blocked = await replacement;
    expect(blocked.failure!.reason, CourseAudioFailureReason.cleanupFailed);
    expect(identical(blocked.failure!.cause, cause), isTrue);
    expect(resolverCalls, 1,
        reason: 'a retirement failure must not reach the resolver');
    expect(
        harness.counts.recordings, <FakeCourseRecordingSession>[predecessor]);
  });

  test('sentence_reviewed_only_rejects_pending_and_unexpected_sources',
      () async {
    final _FactoryCounts pendingCounts = _FactoryCounts();
    final AssetBundle files = _FileAssetBundle();
    final ProviderContainer pendingContainer = _productionBody(
      wordLoader: _wordLoader(files),
      sentenceLoader: FrenchSentencePackageLoader(bundle: files),
      counts: pendingCounts,
    );
    addTearDown(pendingContainer.dispose);

    final CourseReferenceAudio pendingAudio =
        pendingContainer.read(courseReferenceAudioProvider);
    final CourseAudioResult pending = await pendingAudio.playReference(
      _sentenceReferenceId,
      use: CourseAudioUse.reviewedOnly,
      variant: CourseAudioVariant.normal,
      allowPracticeTts: false,
    );
    expect(pending.outcome, CourseAudioOutcome.failed);
    expect(pending.failure!.reason, CourseAudioFailureReason.unreviewedSource);
    expect(pendingCounts.recordings, isEmpty,
        reason: 'the real pending packet must be denied before recording');
    expect(pendingCounts.speeches, isEmpty,
        reason: 'the real pending packet must be denied before speech');

    final CourseAudioResult unknown = await pendingAudio.playReference(
      'fr08-vowel-unknown-audio',
      use: CourseAudioUse.reviewedOnly,
      variant: CourseAudioVariant.normal,
      allowPracticeTts: false,
    );
    expect(unknown.failure!.reason, CourseAudioFailureReason.unknownReference);
    expect(pendingCounts.recordings, isEmpty);
    expect(pendingCounts.speeches, isEmpty);

    final SentenceHuntPackageFixture invalidFixture =
        syntheticSentencePackage(reviewed: true);
    final Map<String, dynamic> firstSection =
        (invalidFixture.manifest['sections']! as List<dynamic>).first
            as Map<String, dynamic>;
    (firstSection['items']! as List<dynamic>).removeAt(0);
    final _FactoryCounts invalidCounts = _FactoryCounts();
    final ProviderContainer invalidContainer = _productionBody(
      wordLoader: _wordLoader(_FileAssetBundle()),
      sentenceLoader: FrenchSentencePackageLoader(
        bundle: _FixtureAssetBundle(invalidFixture),
      ),
      counts: invalidCounts,
    );
    addTearDown(invalidContainer.dispose);
    final CourseAudioResult invalid =
        await invalidContainer.read(courseReferenceAudioProvider).playReference(
              _sentenceReferenceId,
              use: CourseAudioUse.reviewedOnly,
              variant: CourseAudioVariant.normal,
              allowPracticeTts: false,
            );
    expect(invalid.failure!.reason, CourseAudioFailureReason.invalidCatalogue);
    expect(invalidCounts.recordings, isEmpty);
    expect(invalidCounts.speeches, isEmpty);

    final _FactoryCounts reviewedCounts = _FactoryCounts();
    final FakeCourseRecordingSession reviewedSession =
        FakeCourseRecordingSession();
    final ProviderContainer reviewedContainer = _productionBody(
      wordLoader: _wordLoader(_FileAssetBundle()),
      sentenceLoader: FrenchSentencePackageLoader(
        bundle: _FixtureAssetBundle(syntheticSentencePackage(reviewed: true)),
      ),
      counts: reviewedCounts,
      firstRecordings: <FakeCourseRecordingSession>[reviewedSession],
    );
    addTearDown(reviewedContainer.dispose);
    final Future<CourseAudioResult> reviewedPending =
        reviewedContainer.read(courseReferenceAudioProvider).playReference(
              _sentenceReferenceId,
              use: CourseAudioUse.reviewedOnly,
              variant: CourseAudioVariant.normal,
              allowPracticeTts: false,
            );
    await reviewedSession.waitForStart();
    expect(reviewedSession.preparedRecording!.assetKey,
        'assets/audio/fr-sentences/clips/fr08-vowel-01.wav');
    reviewedSession.emitCompleted();
    final CourseAudioResult reviewed = await reviewedPending;
    expect(reviewed.outcome, CourseAudioOutcome.completed);
    expect(reviewed.source, CourseAudioSource.reviewedRecording);
    expect(reviewed.referenceId, _sentenceReferenceId);
    expect(reviewedCounts.recordings, <FakeCourseRecordingSession>[
      reviewedSession,
    ]);
    expect(reviewedCounts.speeches, isEmpty);
  });

  test('sentence_catalogue_failure_does_not_break_word_playback', () async {
    final _FactoryCounts counts = _FactoryCounts();
    final FakeCourseRecordingSession wordSession = FakeCourseRecordingSession();
    final FakeCourseRecordingSession sentenceRetrySession =
        FakeCourseRecordingSession();
    final _FixtureAssetBundle sentenceBundle = _FixtureAssetBundle(
      syntheticSentencePackage(reviewed: true),
      failuresRemaining: 1,
    );
    final ProviderContainer container = _productionBody(
      wordLoader: _wordLoader(_FileAssetBundle()),
      sentenceLoader: FrenchSentencePackageLoader(bundle: sentenceBundle),
      counts: counts,
      firstRecordings: <FakeCourseRecordingSession>[
        wordSession,
        sentenceRetrySession,
      ],
    );
    addTearDown(container.dispose);

    final CourseReferenceAudio reference =
        container.read(courseReferenceAudioProvider);
    final CourseAudioResult firstSentence = await reference.playReference(
      _sentenceReferenceId,
      use: CourseAudioUse.reviewedOnly,
      variant: CourseAudioVariant.normal,
      allowPracticeTts: false,
    );
    expect(firstSentence.outcome, CourseAudioOutcome.failed);
    expect(firstSentence.failure!.reason,
        CourseAudioFailureReason.invalidCatalogue);

    final Future<void> word = container.read(courseAudioProvider).speak(
          _wordReferenceText,
        );
    await wordSession.waitForStart();
    expect(wordSession.preparedRecording!.assetKey,
        'assets/audio/fr/words/tout.wav');
    wordSession.emitCompleted();
    await word;
    expect(counts.speeches, isEmpty,
        reason: 'legacy covered-word playback remains recording-only');

    final Future<CourseAudioResult> retried = reference.playReference(
      _sentenceReferenceId,
      use: CourseAudioUse.reviewedOnly,
      variant: CourseAudioVariant.normal,
      allowPracticeTts: false,
    );
    await sentenceRetrySession.waitForStart();
    sentenceRetrySession.emitCompleted();
    expect((await retried).source, CourseAudioSource.reviewedRecording);

    final _FactoryCounts reverseCounts = _FactoryCounts();
    final FakeCourseRecordingSession sentenceAfterWordFailure =
        FakeCourseRecordingSession();
    final ProviderContainer reverseContainer = _productionBody(
      wordLoader: _wordLoader(_FileAssetBundle(failuresRemaining: 1)),
      sentenceLoader: FrenchSentencePackageLoader(
        bundle: _FixtureAssetBundle(syntheticSentencePackage(reviewed: true)),
      ),
      counts: reverseCounts,
      firstRecordings: <FakeCourseRecordingSession>[
        sentenceAfterWordFailure,
      ],
    );
    addTearDown(reverseContainer.dispose);
    await expectLater(
      reverseContainer.read(courseAudioProvider).speak(_wordReferenceText),
      throwsA(isA<CourseAudioException>()),
    );
    final Future<CourseAudioResult> sentenceAfterFailure =
        reverseContainer.read(courseReferenceAudioProvider).playReference(
              _sentenceReferenceId,
              use: CourseAudioUse.reviewedOnly,
              variant: CourseAudioVariant.normal,
              allowPracticeTts: false,
            );
    await sentenceAfterWordFailure.waitForStart();
    sentenceAfterWordFailure.emitCompleted();
    expect((await sentenceAfterFailure).source,
        CourseAudioSource.reviewedRecording);
    expect(reverseCounts.speeches, isEmpty);
  });

  test('stale sentence resolution cannot start or stop a newer word owner',
      () async {
    for (final bool failLate in <bool>[false, true]) {
      final Completer<void> release = Completer<void>();
      final _FixtureAssetBundle sentenceBundle = _FixtureAssetBundle(
        syntheticSentencePackage(reviewed: true),
        gate: release,
        failureAfterGate:
            failLate ? StateError('stale sentence package failure') : null,
      );
      final _FactoryCounts counts = _FactoryCounts();
      final FakeCourseRecordingSession wordSession =
          FakeCourseRecordingSession();
      final ProviderContainer container = _productionBody(
        wordLoader: _wordLoader(_FileAssetBundle()),
        sentenceLoader: FrenchSentencePackageLoader(bundle: sentenceBundle),
        counts: counts,
        firstRecordings: <FakeCourseRecordingSession>[wordSession],
      );
      addTearDown(container.dispose);

      final CourseReferenceAudio reference =
          container.read(courseReferenceAudioProvider);
      final Future<CourseAudioResult> staleSentence = reference.playReference(
        _sentenceReferenceId,
        use: CourseAudioUse.reviewedOnly,
        variant: CourseAudioVariant.normal,
        allowPracticeTts: false,
      );
      await _until(
          () => sentenceBundle.loads.isNotEmpty, 'sentence package read');

      final Future<void> currentWord =
          container.read(courseAudioProvider).speak(_wordReferenceText);
      await wordSession.waitForStart();
      expect((await staleSentence).outcome, CourseAudioOutcome.cancelled);

      release.complete();
      await pumpEventQueue();
      expect(counts.recordings, <FakeCourseRecordingSession>[wordSession],
          reason: 'late sentence success/error must not create another owner');
      expect(wordSession.calls, contains('start'),
          reason: 'late sentence settlement must not stop the word owner');
      expect(counts.speeches, isEmpty,
          reason: 'sentence resolver errors never become speech fallback');

      wordSession.emitCompleted();
      await currentWord;
      expect(wordSession.preparedRecording!.assetKey,
          'assets/audio/fr/words/tout.wav');
    }
  });
}
