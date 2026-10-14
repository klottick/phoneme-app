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

  void failPlayerStream(String playerId, Object error) {
    _controllerFor(playerId).addError(error);
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
  }

  @override
  Future<void> release(String playerId) async {
    releasedPlayerIds.add(playerId);
    calls.add('release:$playerId');
  }

  @override
  Future<void> dispose(String playerId) async {
    disposedPlayerIds.add(playerId);
    calls.add('dispose:$playerId');
  }

  @override
  Future<int?> getDuration(String playerId) async => null;

  @override
  Future<int?> getCurrentPosition(String playerId) async => null;

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
      // (the plugin's own `@visibleForTesting` `loadAsset` seam), the
      // immediate-error vehicle of the bundled pipeline on the
      // `Future<void>` chain: the original cause then reaches the prepare
      // call directly, fast and deterministically.
      // A stream error on the plugin's `prepared` event stream is
      // deliberately avoided: plugin 6.6.0 routes that stream through
      // `firstWhere(...).timeout(...)` on a `Future<bool>`, and errors
      // delivered there hit a Dart SDK quirk (a void-typed listener result
      // cast) that reports an uninterceptable
      // `ArgumentError("Invalid argument(s) (onError): ...")` to the zone
      // and never settles the prepare call within the plugin's own 30s
      // `preparationTimeout` window — a plugin-internal path no session
      // code can fence, and slower than any sane test bound.
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

    test('dispose drains a failed creation; no unhandled failure', () async {
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
      await expectLater(disposeFuture, completes);
      await expectPrepareFailure;
      expect(fake.resumedPlayerIds, isEmpty);
      // The failed player never reached platform disposal and the late
      // event subscription field was never populated.
      expect(fake.disposedPlayerIds, isEmpty);
      expect(fake.releasedPlayerIds, isEmpty);
      // A second dispose stays quiet.
      await expectLater(session.dispose(), completes);
      expect(players, hasLength(1));
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

    test('waitForStart resolves when start dispatches', () async {
      final FakeCourseRecordingSession session = FakeCourseRecordingSession();
      await session.prepare(_ileRecording);
      final Completer<void> gate = Completer<void>();
      session.startGate = gate.future;
      final Future<void> startFuture = session.start();
      await _settle();
      bool started = false;
      session.waitForStart().then((void _) => started = true);
      await _settle();
      expect(started, isFalse, reason: 'the held gate must not dispatch start');
      gate.complete();
      await expectLater(startFuture, completes);
      await _settle();
      expect(started, isTrue, reason: 'start must dispatch after the gate');
      expect(session.calls, ['prepare', 'start']);
      await session.dispose();
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
