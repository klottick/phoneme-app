# FR-03 — TTS practice-speech error policy addendum (alpha override, round 3)

## Status

Addendum to, not a rewrite of, the approved design at
`docs/superpowers/specs/2026-10-14-fr03-alpha-reference-player-design.md`
(linked by path; its historical approvals are unchanged). This addendum
records the user's binding alpha override adopted in Task 3 fix round 3 and
the exact, still-open limitations of the adopted policy. It claims no
browser, device, native, linguistic, French-content, or French reference
audio approval; those gates remain pending or deferred.

## Approved user override (round 3, binding)

After being explained that **callback-only failures may timeout, not
immediate error, and never completion**, the user stated verbatim:

> **Option 1 is fine, continue**

Option 1, as adopted:

1. **Remove identity-free callback sources of outcomes, direct AND session
   path.** The locked `flutter_tts` (4.2.5) delivers `speak.onError`
   identity-free over one global, last-constructed-wins `MethodChannel`;
   with no handler installed, the callback is drained by the locked global
   handler with zero side effects. The adapter installs no error handler,
   arms no sink, and correlates no callback to any request. There is no
   pretend correlation and no arming API.
2. **A genuine one-attempt practice guard before init/dispatch.**
   `FrenchPracticeSpeechSession.speak` is accepted exactly once per session
   instance; the attempt is consumed before dispatch and stays consumed
   even if the first attempt fails. A second attempt is rejected (it may
   not re-dispatch against the same engine), so no attempt can inherit a
   predecessor's callback or a replayed signal. Successive facade sessions
   are isolated by that guard plus the facade's one-active-owner and
   raw-quiescence fence.
3. **Preserve the method-future cause and the raw fence.** The request
   settles only from the raw method future or the owned typed deadline
   (created on `onTimeout`); the original cause, message and stack are
   preserved on every path. A failed raw op never blocks the fence's
   settlement accounting (`eagerError:false`): only a failed retirement
   gate persists. A callback-only failure while the raw speak is held must
   not complete or fail the latest request immediately, must not count as
   heard playback, and its own bounded grace window may elapse as a typed
   failure; unresolved raw work still prevents unsafe re-playback because
   the next owner waits on the raw fence.
4. **Timeout policy.** A timeout is a failure, never a successful
   playback, and never re-labels a source diagnostic as an owned phase.

## Ownership-timeout policy (round 3, F2)

- **Owned deadlines create the typed phase on `onTimeout`.** Every facade
  backstop (catalogue load, prepare, start acknowledgment, completion
  floor, speech backstop, cleanup blocker) throws
  `PhaseTimeoutException(phase)` from its own `onTimeout`; the direct
  adapter does the same for its setup and utterance bounds. The typed
  phase (`startupTimeout` / `completionTimeout` / the blocker's
  `cleanupFailed`) is classified from the typed cause.
- **Raw source timeouts are conservative.** A source
  `TimeoutException` (or any source error) that settles before the owned
  allowance keeps its original object, message and stack and classifies as
  the conservative generic reason (`unsupportedPlayback`) — never as an
  inferred expired phase. The facade's durable cleanup-blocker semantics
  (a failed retirement blocks the next owner with the original
  cause/stack) are a cleanup-state report, not a phase claim, and are
  unchanged.
- **Injection seams for raw-diagnostics proof.** The adapter constructor
  accepts an optional injected `FlutterTts` (second optional positional
  parameter; all existing positional callers unchanged) so an actual
  `FlutterTts` subclass can fail a method with an explicit cause/stack —
  proving object/message/stack identity through the REAL adapter pipeline
  without the `MethodChannel` envelope. The facade's existing
  `speechFactory`/`recordingFactory` seams are used the same way.
  Channel-mock tests remain channel-transport coverage only; they do not
  demonstrate raw object identity.

## Exact limitations and pending gates

- The locked engine remains identity-free for `speak.onError` delivery
  (global, last-constructed-wins). The adopted policy treats that as a
  channel-level fact and excludes callbacks from outcomes entirely; it does
  NOT rely on, and does not claim, any last-constructed-wins "safe
  boundary" under arbitrary session interleaving (that assumption was
  rejected in review).
- The browser recognition boundary (`isBrowserAutoplayRejection`) has a
  VM stub that is conservative by construction; the web implementation is
  compile-verified in this round, but the browser test gate is **PENDING**
  (no browser binary in the worker environment). Browser, device, native,
  linguistic and French content/approval gates are all NOT claimed here.
- M1/M2 (deferred from earlier tasks) are unchanged and out of scope.
- `courseAudioProvider`'s default switch remains a later task; this
  addendum changes no dependency, asset, legal, license, backend, or
  default-provider configuration.
