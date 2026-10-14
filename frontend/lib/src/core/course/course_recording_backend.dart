/// FR-03 alpha bundled-recording backend (Task 2).
///
/// Isolated lazy recording sessions: the `AudioPlayer` is constructed only
/// when `prepare` is requested, never at session creation. A session is
/// permanently retired by `stop`/`dispose`; `stop` establishes plugin
/// quiescence, including fencing an in-flight `start` dispatch, so it can
/// never mean merely that an early stop command was dispatched. Session
/// streams emit errors with diagnostic causes; the facade normalizes them.
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'course_audio_contract.dart';

/// Terminal events a recording session can emit.
enum CourseRecordingEvent { completed }

/// One isolated single-use bundled-recording playback session.
///
/// Retirement is permanent: after `stop` or `dispose`, `prepare` and
/// `start` throw and no plugin work is ever dispatched again on this
/// session's identity.
abstract interface class CourseRecordingSession {
  /// `completed` fires only on this session's own player completion.
  Stream<CourseRecordingEvent> get events;

  /// Loads [recording]'s already validated bundled asset without starting
  /// playback.
  Future<void> prepare(CourseAudioRecording recording);

  /// Starts playback of the prepared asset.
  Future<void> start();

  /// Fences in-flight raw plugin work, then retires the session
  /// permanently.
  Future<void> stop();

  /// Releases subscriptions and plugin resources. Idempotent.
  Future<void> dispose();
}

/// Default factory: constructs a lazy session, not an [AudioPlayer].
CourseRecordingSession createCourseRecordingSession() =>
    AudioplayersRecordingSession();

/// Production session backed by one lazily constructed [AudioPlayer].
///
/// All raw plugin work (prepare chain, start dispatch, teardown) is
/// serialized on an internal queue so `stop`/`dispose` always fence work
/// that is still in flight, and a failing operation never poisons the
/// queue for the next one. Each operation's future still carries the
/// original diagnostic cause for the facade.
final class AudioplayersRecordingSession implements CourseRecordingSession {
  /// [playerFactory] overrides the real [AudioPlayer] construction for
  /// tests; the player is built only on a requested `prepare`.
  /// [audioCacheFactory] overrides the [AudioCache] used to stage the
  /// bundled asset for tests; the default is the production staging
  /// behavior (cache prefix `''`, because the validated asset key already
  /// includes the single `assets/` prefix).
  AudioplayersRecordingSession({
    AudioPlayer Function()? playerFactory,
    AudioCache Function()? audioCacheFactory,
  })  : _buildPlayer = playerFactory ?? (() => AudioPlayer()),
        _buildCache = audioCacheFactory ?? (() => AudioCache(prefix: ''));

  final AudioPlayer Function() _buildPlayer;
  final AudioCache Function() _buildCache;
  final StreamController<CourseRecordingEvent> _events =
      StreamController<CourseRecordingEvent>.broadcast();

  /// Settled (error-tolerant) tail of the serialized work queue.
  Completer<void> _tail = Completer<void>()..complete();
  AudioPlayer? _player;
  StreamSubscription<AudioEvent>? _playerEvents;
  bool _retired = false;
  bool _prepared = false;

  /// Shared retirement outcome (the enqueued teardown), success or
  /// failure, held by every `stop`/`dispose` caller.
  Future<void>? _retirement;

  @override
  Stream<CourseRecordingEvent> get events => _events.stream;

  @override
  Future<void> prepare(CourseAudioRecording recording) async {
    _requireActive();
    // A prepare already in flight when stop lands still settles on its
    // plugin outcome (success or the original error); retirement only
    // blocks its side effects and every later operation.
    await _enqueue(() async {
      final AudioPlayer player = _ensurePlayer();
      // The validated asset key already includes the single 'assets/'
      // prefix, so the default cache must not prepend its own one.
      player.audioCache = _buildCache();
      await player.setSourceAsset(recording.assetKey, mimeType: 'audio/wav');
      if (!_retired) {
        _prepared = true;
      }
    });
  }

  @override
  Future<void> start() async {
    _requireActive();
    await _enqueue(() async {
      _requireActive();
      final AudioPlayer? player = _player;
      if (!_prepared || player == null) {
        throw StateError('start() requires a prepared source');
      }
      await player.resume();
      if (_retired) {
        // A stop landed before this dispatch settled: the late
        // acknowledgement may have begun playback, so stop the retired
        // identity after the acknowledgement.
        await player.stop();
      }
    });
  }

  @override
  Future<void> stop() async {
    _retired = true;
    await _retire();
  }

  @override
  Future<void> dispose() async {
    _retired = true;
    try {
      await _retire();
    } finally {
      if (!_events.isClosed) {
        await _events.close();
      }
    }
  }

  /// Shared retirement: whichever of `stop`/`dispose` starts it first
  /// owns the enqueued teardown; every later caller awaits the same
  /// outcome — success or failure — instead of observing an early
  /// quiescence while raw work is still in flight.
  Future<void> _retire() {
    final Future<void>? existing = _retirement;
    if (existing != null) return existing;
    _retirement = _enqueue(_teardown);
    return _retirement!;
  }

  /// Teardown is the one shared retirement work. It cleans what can be
  /// cleaned independently — the session's own event subscription first,
  /// so a failed cancellation cannot skip the player — and propagates the
  /// first original cleanup cause: a failed `stop`/`dispose` means
  /// quiescence was not established, never that it was.
  Future<void> _teardown() async {
    Object? cleanupFailure;
    final StreamSubscription<AudioEvent>? subscription = _playerEvents;
    _playerEvents = null;
    if (subscription != null) {
      try {
        await subscription.cancel();
      } on Object catch (error) {
        cleanupFailure ??= error;
      }
    }
    // The player identity is only cleared once its own cleanup settled,
    // so a failed teardown never discards it before cleanup succeeded.
    final AudioPlayer? player = _player;
    if (player != null) {
      try {
        await player.dispose();
        _player = null;
      } on Object catch (error) {
        // The rethrown cause may be a creation failure or an interrupted
        // active-player cleanup; the locked public API cannot prove
        // which (the drained read first awaits creation and may then
        // fail independently as a platform position read, and even a
        // successful read is not a creation-success predicate), so the
        // failure is propagated conservatively and shared by every
        // retirement caller with the original object — never silently
        // absorbed as if quiescence held.
        cleanupFailure ??= error;
      }
    }
    _prepared = false;
    if (cleanupFailure != null) {
      throw cleanupFailure;
    }
  }

  AudioPlayer _ensurePlayer() {
    AudioPlayer? player = _player;
    if (player == null) {
      player = _buildPlayer();
      _player = player;
      // Subscribe before playback, keeping the diagnostic cause on plugin
      // error events; terminal events are delivered only while the session
      // is live.
      _playerEvents = player.eventStream.listen(
        (AudioEvent event) {
          if (_retired) return;
          if (event.eventType != AudioEventType.complete) return;
          _events.add(CourseRecordingEvent.completed);
        },
        onError: (Object error, StackTrace stackTrace) {
          if (_retired) return;
          // Forward the diagnostic cause together with the stack trace the
          // adapter receives (the locked plugin's own single-arg platform
          // forwarding attaches its own stack; the adapter must not drop
          // the one it is handed).
          _events.addError(error, stackTrace);
        },
      );
      // audioplayers 6.6.0 reports a failed platform `create` through the
      // player's creation future; the first control call that awaits it is
      // the only observer. The real `AudioCache` performs asset-staging
      // I/O before the plugin call inside `setSourceAsset`, so the owning
      // prepare call can miss the completion window and the failure would
      // escape as an unhandled async error. Attaching a drained read at
      // construction observes it immediately; the diagnostic still reaches
      // the prepare future exactly once. The probe's own result feeds NO
      // session decision — neither its failure (which may be merely a
      // position read on a successfully created player) nor its success
      // is treated as a creation-phase predicate.
      unawaited(
        player
            .getCurrentPosition()
            .then<void>(_ignoreSettled, onError: _ignoreSettled),
      );
    }
    return player;
  }

  /// Runs [task] after every previously enqueued task settles (success or
  /// failure), registers it on the queue before suspending, and returns
  /// [task]'s own result so the caller keeps the original error while a
  /// failed task never blocks the queue.
  Future<void> _enqueue(Future<void> Function() task) {
    final Completer<void> settled = Completer<void>();
    final Future<void> run = _runInQueue(_tail.future, task, settled);
    unawaited(_observeSettledQuietly(run));
    _tail = settled;
    return run;
  }

  Future<void> _runInQueue(
    Future<void> previous,
    Future<void> Function() task,
    Completer<void> settled,
  ) async {
    try {
      await previous;
    } catch (_) {
      // A previous operation's failure is already owned by its caller;
      // the queue only tracks quiescence.
    }
    try {
      // Rethrows into [run]: the operation's future keeps the original
      // diagnostic cause.
      await task();
    } finally {
      if (!settled.isCompleted) settled.complete();
    }
  }

  /// Observes [run] without altering its outcome, so an operation never
  /// leaves an unobserved failure behind even if its caller lets it go.
  Future<void> _observeSettledQuietly(Future<void> run) async {
    try {
      await run;
    } catch (_) {
      // The operation's caller already receives the original cause.
    }
  }

  void _requireActive() {
    if (_retired) {
      throw StateError('recording session is retired; construct a new session');
    }
  }
}

/// Drain handler for the creation probe: observes the settlement without
/// acting on it either way; the result feeds no session decision.
void _ignoreSettled(Object? value) {}
