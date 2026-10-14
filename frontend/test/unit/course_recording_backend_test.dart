// FR-03 Task 2: isolated lazy recording sessions.
//
// These tests execute the real adapter (`AudioplayersRecordingSession`)
// end to end: a real `AudioPlayer` (audioplayers 6.6.0), real
// `AudioCache` resolution of the bundled Unicode asset, and the real event
// plumbing — only the plugin platform interface and `path_provider` are
// faked. Fake-plugin tests are not manual device or browser certification.
//
// The trailing group pins the deterministic `FakeCourseRecordingSession`
// double used by Task 3 facade tests (gates, call log, dispatch wait and
// event injectors).
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
// Test-only platform-interface doubles: these packages are transitive
// dependencies of `audioplayers` / `path_provider`, imported directly only
// to mock the platform boundary.
// ignore: depend_on_referenced_packages
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio_contract.dart';
import 'package:linguist/src/core/course/course_recording_backend.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../support/fake_course_recording_session.dart';

/// Diagnostic failure injected through the fake plugin platform.
class _FakePreparationError implements Exception {
  const _FakePreparationError();

  @override
  String toString() => 'FakePreparationError';
}

/// `path_provider` substitute so the real `AudioCache` can stage the asset
/// in the host temp directory during `flutter test`.
class _TestPathProvider extends PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;
}

/// `AudioCache` test double that holds the bundled-asset fetch.
///
/// `loadAsset` is the plugin's own `@visibleForTesting` seam for the
/// staged-asset read; holding it keeps a real `prepare` in flight at the
/// staging point so a `stop` landing there fences real work. Releasing the
/// hold throws the carried failure, which then propagates through
/// `fetchToMemory` -> `loadPath` -> `setSourceAsset` exactly like a
/// corrupted or missing bundled asset would.
class _HeldStagingCache extends AudioCache {
  _HeldStagingCache() : super(prefix: '');

  /// When set, `loadAsset` awaits it before reading the asset. Completing
  /// it with an error releases the staged read as a failure.
  Completer<void>? gate;
  Object? error;

  /// True once [loadAsset] has reached its hold.
  bool held = false;

  @override
  Future<ByteData> loadAsset(String path) async {
    final Completer<void>? hold = gate;
    if (hold != null) {
      held = true;
      await hold.future;
    }
    final Object? failure = error;
    if (failure != null) throw failure;
    return super.loadAsset(path);
  }
}

/// One recorded platform `setSourceUrl` dispatch.
class FakeSourceCall {
  FakeSourceCall(this.playerId, this.url, this.isLocal, this.mimeType);

  final String playerId;
  final String url;
  final bool? isLocal;
  final String? mimeType;
}

/// Fake audioplayers 6.6.0 platform: records every call per player
/// identity, can hold `create`/`resume`/`prepared`, and injects complete,
/// error and prepared events. Methods the adapter must never drive throw
/// immediately, so any mis-routing fails loudly.
class FakeAudioplayersPlatform
    implements
        AudioplayersPlatformInterface,
        GlobalAudioplayersPlatformInterface {
  final List<String> calls = [];
  final List<FakeSourceCall> sourceCalls = [];
  final List<String> createdPlayerIds = [];
  final List<String> resumedPlayerIds = [];
  final List<String> stoppedPlayerIds = [];
  final List<String> releasedPlayerIds = [];
  final List<String> disposedPlayerIds = [];
  int initCount = 0;

  /// Error `create` throws when its hold is released with a failure.
  Object? createError;

  /// Holds `create` until completed.
  Completer<void>? createGate;

  /// Holds `resume` after the dispatch is recorded.
  Completer<void>? resumeGate;

  /// When set, `stop` records the dispatch and then throws it.
  Object? stopError;

  /// When set, `release` records the dispatch and then throws it.
  Object? releaseError;

  /// When set, `dispose` records the dispatch and then throws it.
  Object? disposeError;

  /// When set, the next `positionErrorsRemaining` platform position reads
  /// record the call and then throw this failure (later reads succeed).
  Object? positionError;

  /// Budget of reads that [positionError] will fail (`0` = reads always
  /// succeed).
  int positionErrorsRemaining = 0;

  /// Number of platform position reads dispatched so far.
  int positionReads = 0;

  /// When true, `setSourceUrl` (local) is followed by a `prepared` event,
  /// like a real platform.
  bool autoPrepared = true;

  final Map<String, StreamController<AudioEvent>> _playerEvents = {};

  void reset() {
    calls.clear();
    sourceCalls.clear();
    createdPlayerIds.clear();
    resumedPlayerIds.clear();
    stoppedPlayerIds.clear();
    releasedPlayerIds.clear();
    disposedPlayerIds.clear();
    initCount = 0;
    createError = null;
    createGate = null;
    resumeGate = null;
    stopError = null;
    releaseError = null;
    disposeError = null;
    positionError = null;
    positionErrorsRemaining = 0;
    positionReads = 0;
    autoPrepared = true;
    for (final StreamController<AudioEvent> controller
        in _playerEvents.values) {
      unawaited(controller.close());
    }
    _playerEvents.clear();
  }

  /// The identity of the most recently created player.
  String get lastPlayerId => createdPlayerIds.last;

  StreamController<AudioEvent> _controllerFor(String playerId) =>
      _playerEvents.putIfAbsent(
        playerId,
        () => StreamController<AudioEvent>.broadcast(),
      );

  void emitEvent(String playerId, AudioEvent event) {
    _controllerFor(playerId).add(event);
  }

  /// Injects a stream error for [playerId]. When [stackTrace] is given it
  /// is the diagnostic attached to the error delivery.
  void failPlayerStream(
    String playerId,
    Object error, [
    StackTrace? stackTrace,
  ]) {
    _controllerFor(playerId).addError(error, stackTrace);
  }

  /// Signals source readiness for [lastPlayerId].
  void emitPrepared() => emitEvent(
        lastPlayerId,
        const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
      );

  /// Signals completion for [lastPlayerId].
  void emitComplete() => emitEvent(
        lastPlayerId,
        const AudioEvent(eventType: AudioEventType.complete),
      );

  /// Injects a stream error for [lastPlayerId].
  void failPrepared(Object error) =>
      failPlayerStream(lastPlayerId, error);

  // -- AudioplayersPlatformInterface --

  @override
  Future<void> init() async {
    initCount++;
  }

  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() =>
      StreamController<GlobalAudioEvent>.broadcast().stream;

  @override
  Future<void> create(String playerId) async {
    createdPlayerIds.add(playerId);
    calls.add('create:$playerId');
    final Completer<void>? gate = createGate;
    if (gate != null) await gate.future;
    final Object? error = createError;
    if (error != null) throw error;
  }

  @override
  Stream<AudioEvent> getEventStream(String playerId) =>
      _controllerFor(playerId).stream;

  @override
  Future<void> setSourceUrl(
    String playerId,
    String url, {
    bool? isLocal,
    String? mimeType,
  }) async {
    sourceCalls.add(FakeSourceCall(playerId, url, isLocal, mimeType));
    calls.add('setSourceUrl:$playerId');
    if (autoPrepared) {
      scheduleMicrotask(() => emitEvent(
            playerId,
            const AudioEvent(
                eventType: AudioEventType.prepared, isPrepared: true),
          ));
    }
  }

  @override
  Future<void> resume(String playerId) async {
    resumedPlayerIds.add(playerId);
    calls.add('resume:$playerId');
    final Completer<void>? gate = resumeGate;
    if (gate != null) await gate.future;
  }

  @override
  Future<void> stop(String playerId) async {
    stoppedPlayerIds.add(playerId);
    calls.add('stop:$playerId');
    final Object? error = stopError;
    if (error != null) throw error;
  }

  @override
  Future<void> release(String playerId) async {
    releasedPlayerIds.add(playerId);
    calls.add('release:$playerId');
    final Object? error = releaseError;
    if (error != null) throw error;
  }

  @override
  Future<void> dispose(String playerId) async {
    disposedPlayerIds.add(playerId);
    calls.add('dispose:$playerId');
    final Object? error = disposeError;
    if (error != null) throw error;
  }

  @override
  Future<int?> getDuration(String playerId) async => null;

  @override
  Future<int?> getCurrentPosition(String playerId) async {
    positionReads++;
    final Object? error = positionError;
    if (error != null && positionErrorsRemaining > 0) {
      positionErrorsRemaining--;
      throw error;
    }
    return null;
  }

  // -- Methods the adapter must never drive --

  @override
  Future<void> pause(String playerId) async => _notExpected('pause');

  @override
  Future<void> seek(String playerId, Duration position) async =>
      _notExpected('seek');

  @override
  Future<void> setBalance(String playerId, double balance) async =>
      _notExpected('setBalance');

  @override
  Future<void> setVolume(String playerId, double volume) async =>
      _notExpected('setVolume');

  @override
  Future<void> setReleaseMode(
          String playerId, ReleaseMode releaseMode) async =>
      _notExpected('setReleaseMode');

  @override
  Future<void> setPlaybackRate(
          String playerId, double playbackRate) async =>
      _notExpected('setPlaybackRate');

  @override
  Future<void> setSourceBytes(
    String playerId,
    List<int> bytes, {
    String? mimeType,
  }) async =>
      _notExpected('setSourceBytes');

  @override
  Future<void> setAudioContext(
    String playerId,
    AudioContext audioContext,
  ) async =>
      _notExpected('setAudioContext');

  @override
  Future<void> setPlayerMode(
    String playerId,
    PlayerMode playerMode,
  ) async =>
      _notExpected('setPlayerMode');

  @override
  Future<void> setGlobalAudioContext(AudioContext ctx) async =>
      _notExpected('setGlobalAudioContext');

  @override
  Future<void> emitGlobalLog(String message) async =>
      _notExpected('emitGlobalLog');

  @override
  Future<void> emitGlobalError(String code, String message) async =>
      _notExpected('emitGlobalError');

  @override
  Future<void> emitLog(String playerId, String message) async =>
      _notExpected('emitLog');

  @override
  Future<void> emitError(
    String playerId,
    String code,
    String message,
  ) async =>
      _notExpected('emitError');

  Never _notExpected(String method) => throw StateError(
      'FakeAudioplayersPlatform: $method must not be used');
}

/// Hand-derived from the bundled manifest entry `fr-word-île`
/// (`frontend/assets/audio/fr/manifest.json`); the asset key is the
/// repository-to-asset conversion of its `assetPath`.
final CourseAudioRecording _ileRecording = CourseAudioRecording(
  assetKey: 'assets/audio/fr/words/île.wav',
  byteLength: 69362,
  duration: const Duration(milliseconds: 786),
  source: CourseAudioSource.unverifiedRecording,
);

AudioplayersRecordingSession _sessionWith(List<AudioPlayer> players) =>
    AudioplayersRecordingSession(
      playerFactory: () {
        final AudioPlayer player = AudioPlayer();
        players.add(player);
        return player;
      },
    );

Future<void> _settle([int turns = 4]) async {
  for (int i = 0; i < turns; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Advances pending work until the fake platform observed the source setup
/// dispatch for [fake]. In audioplayers 6.6.0 the plugin attaches its
/// `prepared` subscription just before that dispatch, so injection helpers
/// are race-free from that moment on.
Future<void> _untilSourceDispatched(FakeAudioplayersPlatform fake) async {
  for (int i = 0; i < 1000 && fake.sourceCalls.isEmpty; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(fake.sourceCalls, isNotEmpty);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final FakeAudioplayersPlatform fake = FakeAudioplayersPlatform();
  PathProviderPlatform.instance = _TestPathProvider();
  AudioplayersPlatformInterface.instance = fake;
  GlobalAudioplayersPlatformInterface.instance = fake;

  setUp(fake.reset);

  group('AudioplayersRecordingSession against the real AudioPlayer', () {
    test('idle construction, stop and dispose construct no player', () async {
      int factoryCalls = 0;
      final CourseRecordingSession session = AudioplayersRecordingSession(
        playerFactory: () {
          factoryCalls++;
          return AudioPlayer();
        },
      );
      await session.stop();
      await session.dispose();
      expect(factoryCalls, 0);
      expect(fake.createdPlayerIds, isEmpty);
      expect(fake.resumedPlayerIds, isEmpty);
      expect(fake.sourceCalls, isEmpty);
    });

    test('createCourseRecordingSession builds a lazy session', () async {
      final CourseRecordingSession session = createCourseRecordingSession();
      await session.stop();
      await session.dispose();
      expect(fake.createdPlayerIds, isEmpty);
      expect(fake.sourceCalls, isEmpty);
    });

    test('idle dispose is idempotent', () async {
      final CourseRecordingSession session = _sessionWith(<AudioPlayer>[]);
      await expectLater(session.dispose(), completes);
      await expectLater(session.dispose(), completes);
      expect(fake.createdPlayerIds, isEmpty);
    });

    test(
        'prepare resolves the Unicode asset with one prefix as local '
        'audio/wav, without a remote URL source', () async {
      final List<AudioPlayer> players = [];
      final CourseRecordingSession session = _sessionWith(players);
      await session.prepare(_ileRecording);
      final AudioPlayer player = players.single;
      // Ownership is a bundled asset, never a remote URL or bytes source.
      expect(player.source, isA<AssetSource>());
      expect(player.source, isNot(isA<UrlSource>()));
      expect(player.source, isNot(isA<BytesSource>()));
      expect(fake.sourceCalls, hasLength(1));
      final FakeSourceCall call = fake.sourceCalls.single;
      expect(call.playerId, player.playerId);
      expect(call.isLocal, isTrue);
      expect(call.mimeType, 'audio/wav');
      // Exactly one Flutter asset prefix: the staged file ends in exactly
      // the validated asset key, never a doubled assets/assets/ path.
      expect(call.url, endsWith('assets/audio/fr/words/île.wav'));
      expect(call.url, isNot(contains('assets/assets/')));
      expect(call.url.split('assets/').length, 2);
      await session.dispose();
    });

    test('start acknowledgement is not completion; same player only', () async {
      final List<AudioPlayer> players = [];
      final CourseRecordingSession session = _sessionWith(players);
      final List<Object> received = [];
      final StreamSubscription<void> sub = session.events.listen(
        received.add,
        onError: (Object error) => received.add(error),
      );
      await session.prepare(_ileRecording);
      await session.start();
      await _settle();
      expect(fake.resumedPlayerIds, [players.single.playerId]);
      expect(received, isEmpty,
          reason: 'a resume acknowledgement alone is not completion');

      // A complete event on a different player identity stays isolated.
      final AudioPlayer other = AudioPlayer();
      fake.emitEvent(
          other.playerId, const AudioEvent(eventType: AudioEventType.complete));
      await _settle();
      expect(received, isEmpty);

      // Only this session's own player completion is terminal.
      fake.emitEvent(
          players.single.playerId,
          const AudioEvent(eventType: AudioEventType.complete));
      await _settle();
      expect(received, [CourseRecordingEvent.completed]);

      await session.dispose();
      await other.dispose();
      await sub.cancel();
    });

    test('stop during held preparation prevents resume (success release)',
        () async {
      fake.autoPrepared = false;
      final List<AudioPlayer> players = [];
      final CourseRecordingSession session = _sessionWith(players);
      final Future<void> prepareFuture = session.prepare(_ileRecording);
      // Let prepare reach its held point (source dispatched, readiness
      // subscription live, readiness event pending).
      await _untilSourceDispatched(fake);
      final Future<void> stopFuture = session.stop();
      // Release the held preparation after stop is already enqueued.
      fake.emitPrepared();
      await expectLater(prepareFuture, completes);
      await expectLater(stopFuture, completes);
      expect(fake.resumedPlayerIds, isEmpty);
      expect(fake.disposedPlayerIds, contains(players.single.playerId));
      // Retirement is permanent: no future start.
      await expectLater(session.start(), throwsA(isA<StateError>()));
    });

    test('stop during held preparation prevents resume (error release)',
        () async {
      // The failure is released through the held bundled-asset staging
      // (the plugin's own `@visibleForTesting` `loadAsset` seam): a
      // distinct bundled-asset I/O failure path on the `Future<void>`
      // chain, released deterministically while the stop is already
      // queued. The separate plugin `prepared` event-stream error path is
      // covered directly by the live/retired stream-error tests below; on
      // the pinned SDK that exact pipeline was probed and preserved the
      // injected cause with zero uncaught zone errors once the pipeline
      // is attached before injection (the earlier blanket "uninterceptable
      // SDK quirk" claim was refuted: a 30s hang there is a pre-attach
      // broadcast drop, not an intrinsic plugin limitation).
      final _HeldStagingCache staging = _HeldStagingCache()
        ..gate = Completer<void>();
      const Object failure = _FakePreparationError();
      final List<AudioPlayer> players = [];
      final CourseRecordingSession session = AudioplayersRecordingSession(
        playerFactory: () {
          final AudioPlayer player = AudioPlayer();
          players.add(player);
          return player;
        },
        audioCacheFactory: () => staging,
      );
      final Future<void> prepareFuture = session.prepare(_ileRecording);
      // Observe the preparing call immediately: once the held staging is
      // released with the failure this call fails, and an unobserved failed
      // future is reported as an unhandled async error.
      final Future<dynamic> expectPrepareFailure = expectLater(
        prepareFuture,
        // The diagnostic cause is preserved on the preparing call (the
        // original object, not a copy).
        throwsA(predicate<Object>((Object error) => identical(error, failure))),
      );
      // Let prepare reach its held point (the staged-asset read in flight).
      for (int i = 0; i < 1000 && !staging.held; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(staging.held, isTrue);
      final Future<void> stopFuture = session.stop();
      // Release the held staging with the failure after stop is already
      // enqueued.
      staging.gate!.completeError(failure);
      await expectLater(stopFuture, completes);
      await expectPrepareFailure;
      expect(fake.resumedPlayerIds, isEmpty);
      expect(fake.disposedPlayerIds, contains(players.single.playerId));
      await expectLater(session.start(), throwsA(isA<StateError>()));
    });

    test('late resume is fenced by stop and stopped after its ack', () async {
      final List<AudioPlayer> players = [];
      final CourseRecordingSession session = _sessionWith(players);
      await session.prepare(_ileRecording);
      final Completer<void> gate = Completer<void>();
      fake.resumeGate = gate;
      final Future<void> startFuture = session.start();
      await _settle();
      expect(fake.resumedPlayerIds, [players.single.playerId]);
      final Future<void> stopFuture = session.stop();
      // Acknowledge the held resume: the session must fence it and stop the
      // retired identity after the acknowledgement.
      gate.complete();
      await expectLater(startFuture, completes);
      await expectLater(stopFuture, completes);
      final String id = players.single.playerId;
      final int resumeIndex = fake.calls.indexOf('resume:$id');
      final int stopIndex = fake.calls.indexOf('stop:$id');
      expect(resumeIndex, greaterThanOrEqualTo(0));
      expect(stopIndex, greaterThan(resumeIndex),
          reason: 'a stop on the retired identity must follow the ack');
      expect(fake.disposedPlayerIds, contains(id));
      // Retirement is permanent: no future start or prepare.
      await expectLater(session.start(), throwsA(isA<StateError>()));
      await expectLater(
          session.prepare(_ileRecording), throwsA(isA<StateError>()));
    });

    test('retired completion and error events are drained quietly', () async {
      final List<AudioPlayer> players = [];
      final CourseRecordingSession session = _sessionWith(players);
      final List<Object> received = [];
      final StreamSubscription<void> sub = session.events.listen(
        received.add,
        onError: (Object error) => received.add(error),
      );
      await session.prepare(_ileRecording);
      await session.start();
      await session.stop();
      // After retirement, late plugin events must neither complete the
      // session nor escape as unhandled async failures.
      fake.emitComplete();
      fake.failPrepared(const _FakePreparationError());
      await _settle();
      expect(received, isEmpty);
      await session.dispose();
      await sub.cancel();
    });

    test('dispose settles a held creation before releasing it', () async {
      final Completer<void> gate = Completer<void>();
      fake.createGate = gate;
      final List<AudioPlayer> players = [];
      final CourseRecordingSession session = _sessionWith(players);
      final Future<void> prepareFuture = session.prepare(_ileRecording);
      final Future<void> disposeFuture = session.dispose();
      gate.complete();
      await expectLater(prepareFuture, completes);
      await expectLater(disposeFuture, completes);
      expect(fake.disposedPlayerIds, contains(players.single.playerId));
      expect(fake.resumedPlayerIds, isEmpty);
    });

    test(
        'dispose on failed creation propagates the shared cause conservatively',
        () async {
      const Object failure = _FakePreparationError();
      fake.createError = failure;
      final List<AudioPlayer> players = [];
      final CourseRecordingSession session = _sessionWith(players);
      final Future<void> prepareFuture = session.prepare(_ileRecording);
      // Observe the preparing call immediately: the failing creation
      // surfaces on it, and an unobserved failed future is reported as an
      // unhandled async error.
      final Future<dynamic> expectPrepareFailure = expectLater(
        prepareFuture,
        // The diagnostic cause must reach the preparing call (the original
        // object, not a copy).
        throwsA(predicate<Object>((Object error) => identical(error, failure))),
      );
      final Future<void> disposeFuture = session.dispose();
      // The creation phase cannot be proved from the locked public API
      // (the drained read first awaits creation and may independently fail
      // as a platform position read; `creatingCompleter` is
      // `@visibleForTesting`), so the teardown failure is never silently
      // absorbed: it fails the shared retirement for every retirement
      // caller with the original cause.
      final Future<dynamic> expectDisposeFailure = expectLater(
        disposeFuture,
        throwsA(predicate<Object>(
            (Object error) => identical(error, failure))),
      );
      await expectDisposeFailure;
      await expectPrepareFailure;
      expect(players, hasLength(1));
      expect(fake.resumedPlayerIds, isEmpty);
      // The failed player never reached any platform control call, and
      // the unpopulated late event fields were never touched (the locked
      // plugin rethrows before that point).
      expect(fake.stoppedPlayerIds, isEmpty);
      expect(fake.releasedPlayerIds, isEmpty);
      expect(fake.disposedPlayerIds, isEmpty);
      // A later retirement caller sees the same shared failure, never a
      // fresh quiescence.
      await expectLater(
        session.dispose(),
        throwsA(predicate<Object>(
            (Object error) => identical(error, failure))),
      );
      await expectLater(session.start(), throwsA(isA<StateError>()));
    });

    test('start before prepare is rejected without constructing a player',
        () async {
      final List<AudioPlayer> players = [];
      final CourseRecordingSession session = _sessionWith(players);
      await expectLater(session.start(), throwsA(isA<StateError>()));
      expect(players, isEmpty);
      expect(fake.createdPlayerIds, isEmpty);
      await session.dispose();
    });

    // -- I1: teardown failures must not read as successful quiescence --

    test('stop propagates a failed platform stop, after the dispatch',
        () async {
      final List<AudioPlayer> players = [];
      final CourseRecordingSession session = _sessionWith(players);
      const Object failure = _FakePreparationError();
      await session.prepare(_ileRecording);
      fake.stopError = failure;
      final Future<void> stopFuture = session.stop();
      // Observe the retiring call before the failure can fire.
      final Future<dynamic> expectStopFailure = expectLater(
        stopFuture,
        throwsA(predicate<Object>(
            (Object error) => identical(error, failure))),
      );
      await expectStopFailure;
      final String id = players.single.playerId;
      // The dispatch was attempted and recorded; the plugin chain
      // (release after stop) never reached the platform release or
      // disposal, yet the stop must not have advertised quiescence.
      expect(fake.stoppedPlayerIds, contains(id));
      expect(fake.releasedPlayerIds, isEmpty);
      expect(fake.disposedPlayerIds, isEmpty);
      expect(fake.resumedPlayerIds, isEmpty);
      // Retirement is permanent even though quiescence failed.
      await expectLater(session.start(), throwsA(isA<StateError>()));
    });

    test('stop propagates a failed platform release', () async {
      final List<AudioPlayer> players = [];
      final CourseRecordingSession session = _sessionWith(players);
      const Object failure = _FakePreparationError();
      await session.prepare(_ileRecording);
      fake.releaseError = failure;
      final Future<void> stopFuture = session.stop();
      final Future<dynamic> expectStopFailure = expectLater(
        stopFuture,
        throwsA(predicate<Object>(
            (Object error) => identical(error, failure))),
      );
      await expectStopFailure;
      final String id = players.single.playerId;
      // Stop succeeded, release dispatch was attempted, and the chain
      // blocked platform disposal — without a successful stop.
      expect(fake.stoppedPlayerIds, contains(id));
      expect(fake.releasedPlayerIds, contains(id));
      expect(fake.disposedPlayerIds, isEmpty);
      await expectLater(session.start(), throwsA(isA<StateError>()));
    });

    test('stop propagates a failed platform dispose', () async {
      final List<AudioPlayer> players = [];
      final CourseRecordingSession session = _sessionWith(players);
      const Object failure = _FakePreparationError();
      await session.prepare(_ileRecording);
      fake.disposeError = failure;
      final Future<void> stopFuture = session.stop();
      final Future<dynamic> expectStopFailure = expectLater(
        stopFuture,
        throwsA(predicate<Object>(
            (Object error) => identical(error, failure))),
      );
      await expectStopFailure;
      final String id = players.single.playerId;
      // Stop and release succeeded, the platform dispose dispatch was
      // attempted, and the failure must still fail the stop.
      expect(fake.stoppedPlayerIds, contains(id));
      expect(fake.releasedPlayerIds, contains(id));
      expect(fake.disposedPlayerIds, contains(id));
      await expectLater(session.start(), throwsA(isA<StateError>()));
    });

    // -- F1: a position-read failure is not evidence of a creation
    //      failure; such a cleanup failure must propagate, not be
    //      absorbed (fix round 2). --

    test(
        'first position read failure never excuses an identical stop failure',
        () async {
      // Creation succeeds; the construction-time position probe fails with
      // object `failure`; the later platform stop fails with that same
      // object. The identity is not proof of a creation failure, so the
      // stop must fail — never a false quiescence — and the failed
      // retirement must be shared by every retirement caller.
      final List<AudioPlayer> players = [];
      final CourseRecordingSession session = _sessionWith(players);
      const Object failure = _FakePreparationError();
      fake.positionError = failure;
      fake.positionErrorsRemaining = 1; // only the probe read fails
      final Future<void> prepareFuture = session.prepare(_ileRecording);
      // Creation and source setup are unaffected by the probe: prepare
      // completes. (The probe result must never feed a creation
      // classification.)
      await expectLater(prepareFuture, completes);
      expect(fake.positionReads, greaterThanOrEqualTo(1));
      fake.stopError = failure; // same object, later platform stop failure
      final Future<void> stopFuture = session.stop();
      // Observe the retiring call before the failure can fire.
      final Future<dynamic> expectStopFailure = expectLater(
        stopFuture,
        throwsA(predicate<Object>(
            (Object error) => identical(error, failure))),
      );
      await expectStopFailure;
      final String id = players.single.playerId;
      // The stop dispatch was recorded; the chain blocked release/dispose.
      expect(fake.stoppedPlayerIds, contains(id));
      expect(fake.releasedPlayerIds, isEmpty);
      expect(fake.disposedPlayerIds, isEmpty);
      // Shared failed retirement: later callers see the same cause.
      await expectLater(
        session.stop(),
        throwsA(predicate<Object>(
            (Object error) => identical(error, failure))),
      );
      await expectLater(
        session.dispose(),
        throwsA(predicate<Object>(
            (Object error) => identical(error, failure))),
      );
      await expectLater(session.start(), throwsA(isA<StateError>()));
    });

    test(
        'repeated position failures through the dispose chain still fail the stop',
        () async {
      // A recurring position-read failure (creation succeeded) surfaces
      // again inside the plugin's disposal chain (`stop` awaits
      // `PositionUpdater.stopAndUpdate()` -> another position read); its
      // identical failure must abort release/disposal and fail the stop —
      // no false quiescence, failure shared by every caller.
      final List<AudioPlayer> players = [];
      final CourseRecordingSession session = _sessionWith(players);
      const Object failure = _FakePreparationError();
      fake.positionError = failure;
      fake.positionErrorsRemaining = 100; // the read keeps failing
      final Future<void> prepareFuture = session.prepare(_ileRecording);
      // Observe the preparing call before the failure can settle: the
      // prepare chain ends with a position update, so it fails with the
      // same object.
      final Future<dynamic> expectPrepareFailure = expectLater(
        prepareFuture,
        throwsA(predicate<Object>(
            (Object error) => identical(error, failure))),
      );
      await expectPrepareFailure;
      final Future<void> stopFuture = session.stop();
      final Future<dynamic> expectStopFailure = expectLater(
        stopFuture,
        throwsA(predicate<Object>(
            (Object error) => identical(error, failure))),
      );
      await expectStopFailure;
      final String id = players.single.playerId;
      // The platform stop dispatch succeeded and was recorded, but the
      // chain's own position read aborted release/disposal.
      expect(fake.positionReads, greaterThanOrEqualTo(3));
      expect(fake.stoppedPlayerIds, contains(id));
      expect(fake.releasedPlayerIds, isEmpty);
      expect(fake.disposedPlayerIds, isEmpty);
      await expectLater(
        session.stop(),
        throwsA(predicate<Object>(
            (Object error) => identical(error, failure))),
      );
      await expectLater(
        session.dispose(),
        throwsA(predicate<Object>(
            (Object error) => identical(error, failure))),
      );
      await expectLater(session.start(), throwsA(isA<StateError>()));
    });

    // -- I2: shared retirement across repeated/overlapping callers --
    test('two stop callers both await the held late-resume fence', () async {
      final List<AudioPlayer> players = [];
      final CourseRecordingSession session = _sessionWith(players);
      await session.prepare(_ileRecording);
      final Completer<void> gate = Completer<void>();
      fake.resumeGate = gate;
      final Future<void> startFuture = session.start();
      await _settle();
      final String id = players.single.playerId;
      expect(fake.resumedPlayerIds, [id]);
      final Future<void> stopOne = session.stop();
      final Future<void> stopTwo = session.stop();
      int settled = 0;
      stopOne.whenComplete(() => settled++);
      stopTwo.whenComplete(() => settled++);
      await _settle();
      expect(settled, 0,
          reason: 'a second stop must not observe early quiescence');
      // Release the held acknowledgement: every stop caller settles only
      // after the late ack and the teardown settle.
      gate.complete();
      await expectLater(startFuture, completes);
      await expectLater(stopOne, completes);
      await expectLater(stopTwo, completes);
      await _settle();
      expect(settled, 2);
      final int resumeIndex = fake.calls.indexOf('resume:$id');
      final int stopIndex = fake.calls.indexOf('stop:$id');
      expect(resumeIndex, greaterThanOrEqualTo(0));
      expect(stopIndex, greaterThan(resumeIndex),
          reason: 'the fence must stop the retired identity after the ack');
      await expectLater(session.start(), throwsA(isA<StateError>()));
    });

    test('stop during an in-flight dispose shares the pending fence', () async {
      // A held bundled-asset staging keeps the prepare task in flight, so
      // the dispose's queued teardown is pending when the stop lands.
      final _HeldStagingCache staging = _HeldStagingCache()
        ..gate = Completer<void>();
      final List<AudioPlayer> players = [];
      final CourseRecordingSession session = AudioplayersRecordingSession(
        playerFactory: () {
          final AudioPlayer player = AudioPlayer();
          players.add(player);
          return player;
        },
        audioCacheFactory: () => staging,
      );
      final Future<void> prepareFuture = session.prepare(_ileRecording);
      for (int i = 0; i < 1000 && !staging.held; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(staging.held, isTrue);
      final Future<void> disposeFuture = session.dispose();
      final Future<void> stopFuture = session.stop();
      int settled = 0;
      disposeFuture.whenComplete(() => settled++);
      stopFuture.whenComplete(() => settled++);
      await _settle();
      expect(settled, 0,
          reason: 'stop during dispose must share the pending fence');
      // Release the held staging with success: every caller settles only
      // after the in-flight prepare and the teardown settle.
      staging.gate!.complete();
      await expectLater(prepareFuture, completes);
      await expectLater(stopFuture, completes);
      await expectLater(disposeFuture, completes);
      expect(fake.disposedPlayerIds, contains(players.single.playerId));
      await expectLater(session.start(), throwsA(isA<StateError>()));
    });

    test('a failing teardown is shared by every subsequent caller',
        () async {
      final List<AudioPlayer> players = [];
      final CourseRecordingSession session = _sessionWith(players);
      const Object failure = _FakePreparationError();
      await session.prepare(_ileRecording);
      fake.stopError = failure;
      final Future<void> stopOne = session.stop();
      final Future<dynamic> expectStopFailureOne = expectLater(
        stopOne,
        throwsA(predicate<Object>(
            (Object error) => identical(error, failure))),
      );
      await expectStopFailureOne;
      // The failure is the retirement outcome: later stops and the
      // dispose all observe it, never an early success or a dropped
      // player.
      await expectLater(
        session.stop(),
        throwsA(predicate<Object>(
            (Object error) => identical(error, failure))),
      );
      await expectLater(
        session.dispose(),
        throwsA(predicate<Object>(
            (Object error) => identical(error, failure))),
      );
      // No platform disposal occurred while the identity is retained.
      expect(fake.disposedPlayerIds, isEmpty);
      expect(fake.releasedPlayerIds, isEmpty);
      await expectLater(session.start(), throwsA(isA<StateError>()));
    });

    // -- I3: the actual preparation-stream error path, live and retired --

    test('pending preparation stream error reaches prepare; stop settles',
        () async {
      fake.autoPrepared = false;
      final List<AudioPlayer> players = [];
      final CourseRecordingSession session = _sessionWith(players);
      const Object failure = _FakePreparationError();
      final Future<void> prepareFuture = session.prepare(_ileRecording);
      // Source dispatched: the plugin's prepared pipeline is attached, so
      // the injection below is race-free.
      await _untilSourceDispatched(fake);
      // Observe the preparing call before the error injection.
      final Future<dynamic> expectPrepareFailure = expectLater(
        prepareFuture,
        throwsA(predicate<Object>(
            (Object error) => identical(error, failure))),
      );
      fake.failPrepared(failure);
      await expectPrepareFailure;
      // The session still retires cleanly: quiescence is established and
      // no uncaught error remains (flutter_test would fail otherwise).
      await expectLater(session.stop(), completes);
      expect(fake.disposedPlayerIds, contains(players.single.playerId));
      expect(fake.resumedPlayerIds, isEmpty);
      await expectLater(session.start(), throwsA(isA<StateError>()));
    });

    test(
        'stream error after retirement but before teardown settles '
        'preserves the cause; stop settles', () async {
      fake.autoPrepared = false;
      final List<AudioPlayer> players = [];
      final CourseRecordingSession session = _sessionWith(players);
      const Object failure = _FakePreparationError();
      final Future<void> prepareFuture = session.prepare(_ileRecording);
      await _untilSourceDispatched(fake);
      final Future<void> stopFuture = session.stop();
      // Observe the preparing call before the error injection.
      final Future<dynamic> expectPrepareFailure = expectLater(
        prepareFuture,
        throwsA(predicate<Object>(
            (Object error) => identical(error, failure))),
      );
      // The retired preparation is still pending: its late failure must
      // settle the fence without an uncaught error.
      fake.failPrepared(failure);
      await expectPrepareFailure;
      await expectLater(stopFuture, completes);
      expect(fake.disposedPlayerIds, contains(players.single.playerId));
      expect(fake.resumedPlayerIds, isEmpty);
      await expectLater(session.start(), throwsA(isA<StateError>()));
    });

    test('live error after successful prepare is delivered with its cause',
        () async {
      final List<AudioPlayer> players = [];
      final CourseRecordingSession session = _sessionWith(players);
      await session.prepare(_ileRecording);
      await session.start();
      final List<Object> receivedErrors = [];
      final StreamSubscription<void> sub = session.events.listen(
        (CourseRecordingEvent event) {},
        onError: (Object error, StackTrace stackTrace) {
          receivedErrors.add(error);
        },
      );
      await _settle();
      const Object failure = _FakePreparationError();
      // Listener attached before injection: delivery is race-free.
      fake.failPlayerStream(players.single.playerId, failure);
      await _settle();
      // The diagnostic cause is delivered to the session events, the
      // original object, not a copy. (The locked plugin's own single-arg
      // platform-stream forwarding attaches its own stack trace to the
      // re-emitted error; stack provenance is therefore asserted on the
      // adapter's forwarding itself, not across the plugin boundary.)
      expect(receivedErrors, hasLength(1));
      expect(identical(receivedErrors.single, failure), isTrue);
      await sub.cancel();
      await session.dispose();
    });
  });

  group('FakeCourseRecordingSession double contract', () {
    test('holds gates and logs the dispatch order', () async {
      final FakeCourseRecordingSession session = FakeCourseRecordingSession();
      final Completer<void> gate = Completer<void>();
      session.prepareGate = gate.future;
      final Future<void> prepareFuture = session.prepare(_ileRecording);
      await _settle();
      expect(session.calls, ['prepare']);
      expect(session.preparedRecording, isNull);
      gate.complete();
      await expectLater(prepareFuture, completes);
      expect(session.preparedRecording, same(_ileRecording));
    });

    test('a failed gate releases prepare as a failure', () async {
      final FakeCourseRecordingSession session = FakeCourseRecordingSession();
      const Object failure = _FakePreparationError();
      final Completer<void> gate = Completer<void>();
      session.prepareGate = gate.future;
      final Future<void> prepareFuture = session.prepare(_ileRecording);
      gate.completeError(failure);
      await expectLater(
          prepareFuture,
          throwsA(predicate<Object>(
              (Object error) => identical(error, failure))));
    });

    test('waitForStart resolves on dispatch before the held acknowledgement',
        () async {
      final FakeCourseRecordingSession session = FakeCourseRecordingSession();
      await session.prepare(_ileRecording);
      final Completer<void> gate = Completer<void>();
      session.startGate = gate.future;
      final Future<void> startFuture = session.start();
      await _settle();
      // The dispatch is observable while the acknowledgement is still
      // held: this is the raw-quiescence shape the facade needs.
      bool dispatched = false;
      unawaited(session.waitForStart().then<void>((_) {
        dispatched = true;
      }));
      await _settle();
      bool startSettled = false;
      unawaited(startFuture.then<void>((_) {
        startSettled = true;
      }));
      expect(dispatched, isTrue,
          reason: 'dispatch must be observable before the ack releases');
      expect(startSettled, isFalse, reason: 'the held gate must hold the ack');
      gate.complete();
      await expectLater(startFuture, completes);
      expect(session.calls, ['prepare', 'start']);
      await session.dispose();
    });

    test('stop fences a held start and settles after its late ack', () async {
      final FakeCourseRecordingSession session = FakeCourseRecordingSession();
      await session.prepare(_ileRecording);
      final Completer<void> gate = Completer<void>();
      session.startGate = gate.future;
      final Future<void> startFuture = session.start();
      unawaited(session.waitForStart().then<void>((_) {}));
      await _settle();
      final Future<void> stopFuture = session.stop();
      bool startSettled = false;
      bool stopSettled = false;
      unawaited(startFuture.then<void>((_) {
        startSettled = true;
      }));
      unawaited(stopFuture.then<void>((_) {
        stopSettled = true;
      }));
      await _settle();
      expect(stopSettled, isFalse,
          reason: 'stop must not settle while the start is unacknowledged');
      // Release the acknowledgement after stop: the late ack of the
      // already-dispatched work is represented, and only then does the
      // fence settle.
      gate.complete();
      await _settle();
      expect(startSettled, isTrue);
      expect(stopSettled, isTrue);
      await expectLater(startFuture, completes);
      await expectLater(stopFuture, completes);
      await expectLater(session.start(), throwsA(isA<StateError>()));
    });

    test('the stop fence settles even when the held start ack fails',
        () async {
      final FakeCourseRecordingSession session = FakeCourseRecordingSession();
      await session.prepare(_ileRecording);
      const Object failure = _FakePreparationError();
      final Completer<void> gate = Completer<void>();
      session.startGate = gate.future;
      final Future<void> startFuture = session.start();
      unawaited(session.waitForStart().then<void>((_) {}));
      await _settle();
      final Future<void> stopFuture = session.stop();
      // Observe the failing operation before the failure release.
      final Future<dynamic> expectStartFailure = expectLater(
        startFuture,
        throwsA(predicate<Object>(
            (Object error) => identical(error, failure))),
      );
      gate.completeError(failure);
      await expectStartFailure;
      // Quiescence means every dispatched op settled, whatever its
      // outcome: the stop still settles.
      await expectLater(stopFuture, completes);
      await expectLater(session.start(), throwsA(isA<StateError>()));
    });

    test('repeated stops share the fence behind a held start', () async {
      final FakeCourseRecordingSession session = FakeCourseRecordingSession();
      await session.prepare(_ileRecording);
      final Completer<void> gate = Completer<void>();
      session.startGate = gate.future;
      final Future<void> startFuture = session.start();
      unawaited(session.waitForStart().then<void>((_) {}));
      await _settle();
      final Future<void> stopOne = session.stop();
      final Future<void> stopTwo = session.stop();
      int settled = 0;
      unawaited(stopOne.then<void>((_) {
        settled++;
      }));
      unawaited(stopTwo.then<void>((_) {
        settled++;
      }));
      await _settle();
      expect(settled, 0,
          reason: 'no stop may settle while the start is unacknowledged');
      gate.complete();
      await _settle();
      expect(settled, 2);
      await expectLater(startFuture, completes);
      await expectLater(stopOne, completes);
      await expectLater(stopTwo, completes);
    });

    test('dispose fences a held start and shares it with a concurrent stop',
        () async {
      final FakeCourseRecordingSession session = FakeCourseRecordingSession();
      await session.prepare(_ileRecording);
      final Completer<void> gate = Completer<void>();
      session.startGate = gate.future;
      final Future<void> startFuture = session.start();
      unawaited(session.waitForStart().then<void>((_) {}));
      await _settle();
      final Future<void> disposeFuture = session.dispose();
      final Future<void> stopFuture = session.stop();
      int settled = 0;
      unawaited(disposeFuture.then<void>((_) {
        settled++;
      }));
      unawaited(stopFuture.then<void>((_) {
        settled++;
      }));
      await _settle();
      expect(settled, 0,
          reason: 'dispose must fence the pending start like stop does');
      gate.complete();
      await _settle();
      expect(settled, 2);
      await expectLater(startFuture, completes);
      await expectLater(disposeFuture, completes);
      await expectLater(stopFuture, completes);
      await expectLater(session.start(), throwsA(isA<StateError>()));
    });

    test('a held stop gate keeps every retirement caller pending', () async {
      final FakeCourseRecordingSession session = FakeCourseRecordingSession();
      await session.prepare(_ileRecording);
      final Completer<void> gate = Completer<void>();
      session.stopGate = gate.future;
      final Future<void> stopFuture = session.stop();
      final Future<void> disposeFuture = session.dispose();
      int settled = 0;
      unawaited(stopFuture.then<void>((_) {
        settled++;
      }));
      unawaited(disposeFuture.then<void>((_) {
        settled++;
      }));
      await _settle();
      expect(settled, 0,
          reason: 'dispose must share the held stop settlement');
      gate.complete();
      await _settle();
      expect(settled, 2);
      await expectLater(session.start(), throwsA(isA<StateError>()));
    });

    test(
        'a failing stop gate while the start is held: no uncaught error, no premature settlement, shared original failure',
        () async {
      // F2 (fix round 2): a stop-gate failure released while a dispatched
      // start is still held must be observed immediately (zero uncaught
      // zone errors) even though retirement still waits for raw
      // quiescence; after the held start settles, every retirement caller
      // receives the identical original gate failure.
      final FakeCourseRecordingSession session = FakeCourseRecordingSession();
      await session.prepare(_ileRecording);
      const Object failure = _FakePreparationError();
      final Completer<void> gate = Completer<void>();
      session.stopGate = gate.future;
      final Completer<void> startHold = Completer<void>();
      session.startGate = startHold.future;
      final Future<void> startFuture = session.start();
      // Observe the public retirement callers BEFORE the failure
      // injection.
      final Future<void> stopFuture = session.stop();
      final Future<dynamic> expectStopFailure = expectLater(
        stopFuture,
        throwsA(predicate<Object>(
            (Object error) => identical(error, failure))),
      );
      final Future<void> disposeFuture = session.dispose();
      final Future<dynamic> expectDisposeFailure = expectLater(
        disposeFuture,
        throwsA(predicate<Object>(
            (Object error) => identical(error, failure))),
      );
      // Release the stop gate with the failure while the start is still
      // held: its failure must already be observed (an unhandled report
      // would fail this test in flutter_test), and retirement must not
      // settle before the raw operation does.
      gate.completeError(failure);
      bool stopSettled = false;
      // Settle probe observes BOTH outcomes: the retirement is expected
      // to SETTLE (with the shared gate failure), not to succeed.
      unawaited(stopFuture.then<void>(
        (_) {
          stopSettled = true;
        },
        onError: (Object _) {
          stopSettled = true;
        },
      ));
      bool startSettled = false;
      unawaited(startFuture.then<void>((_) {
        startSettled = true;
      }));
      await _settle();
      expect(stopSettled, isFalse,
          reason: 'retirement must still wait for the held start');
      expect(startSettled, isFalse);
      // Release the held start: the late ack settles, and only then do
      // all retirement callers fail with the identical gate failure.
      startHold.complete();
      await _settle();
      expect(startSettled, isTrue);
      expect(stopSettled, isTrue);
      await expectStopFailure;
      await expectDisposeFailure;
      await expectLater(session.start(), throwsA(isA<StateError>()));
    });

    test('a failed stop gate fails the shared retirement', () async {
      final FakeCourseRecordingSession session = FakeCourseRecordingSession();
      await session.prepare(_ileRecording);
      const Object failure = _FakePreparationError();
      final Completer<void> gate = Completer<void>();
      session.stopGate = gate.future;
      final Future<void> stopFuture = session.stop();
      // Observe the retiring call before the failure release.
      final Future<dynamic> expectStopFailure = expectLater(
        stopFuture,
        throwsA(predicate<Object>(
            (Object error) => identical(error, failure))),
      );
      gate.completeError(failure);
      await expectStopFailure;
      // The failed retirement outcome is shared with a later dispose.
      await expectLater(
        session.dispose(),
        throwsA(predicate<Object>(
            (Object error) => identical(error, failure))),
      );
      await expectLater(session.start(), throwsA(isA<StateError>()));
    });

    test('emits completed and error events on events', () async {
      final FakeCourseRecordingSession session = FakeCourseRecordingSession();
      const Object failure = _FakePreparationError();
      final List<Object> received = [];
      final StreamSubscription<void> sub = session.events.listen(
        received.add,
        onError: (Object error) => received.add(error),
      );
      session.emitCompleted();
      session.emitError(failure);
      await _settle();
      expect(received, hasLength(2));
      expect(received.first, CourseRecordingEvent.completed);
      expect(received.last, same(failure));
      await sub.cancel();
      await session.dispose();
    });

    test('stop retires the session permanently', () async {
      final FakeCourseRecordingSession session = FakeCourseRecordingSession();
      await session.prepare(_ileRecording);
      await session.stop();
      await expectLater(session.start(), throwsA(isA<StateError>()));
      await expectLater(
          session.prepare(_ileRecording), throwsA(isA<StateError>()));
      await expectLater(session.dispose(), completes);
      expect(session.calls, ['prepare', 'stop', 'dispose']);
    });
  });
}
