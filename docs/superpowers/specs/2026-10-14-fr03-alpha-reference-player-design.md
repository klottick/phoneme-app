# FR-03 — Shared reference-audio player for the alpha

## Intent and approval stage

Enable the 24 existing French word recordings in the alpha's normal practice
flows, with reliable completion, cancellation and retry behavior. Preserve
existing callers and progress; do not turn playback into pronunciation approval.

The user approved all conversational design sections: recording-first playback
through the existing `audioplayers` dependency, a reference-ID contract, no silent
TTS substitution after recording errors, real completion, safe cancellation,
accurate credits, regression tests and honest platform limitations.

**This written spec awaits user review.** No product implementation is authorized
by writing it. After written-spec approval, prepare a separate implementation
plan for user review and execution selection.

## Explicit alpha scope override

The user instructed: "you can just enable the recordings, but mark in repo that
they are unverified. Goal is to build an alpha, not a production ready app".

This permits registering and playing the unchanged pending candidates in normal
alpha practice, superseding the earlier no-runtime-candidate restriction for this
scope. It does not authorize reviewer sign-off, new assessment content, scorer
integration, binary repair or a production/store release.

- Keep manifest `catalogueStatus: candidate`, `review.status: pending`, null
  reviewer/date, empty review evidence, and unverified speaker qualification.
- Repository documentation and in-app credits identify these recordings as
  linguistically unverified alpha material, not certified pronunciation examples.
- Do not change `frenchAudioResources` to `reviewedRecording` or clear existing
  readiness findings. Runtime source selection is separate from reviewed-resource
  readiness; its explanatory comments may be updated to reflect that distinction.
- Legacy lesson/game correctness and practice-progress behavior remain unchanged.
  That existing feedback is not a newly validated assessment or proficiency claim.
- FR-15 evaluation stays pending; no tools, models, uploads or benchmarks.

The published baseline is PR [#23](https://github.com/klottick/phoneme-app/pull/23),
merge `64009a65717d68c1b21625d28890cff822619eb8`. Preserve unpublished Sound Match
work and other branches/worktrees; do not import them to satisfy a ticket example.

## Selected architecture

Reuse `audioplayers` already declared in `frontend/pubspec.yaml` (locked 6.6.0),
behind a small injectable recording-engine interface. Do not replace the generic
`AudioService`, which also serves other audio and learner-recording playback.

Keep `CourseAudio.speak(String)` and `stop()` unchanged as public signatures.
Existing `implements CourseAudio` fakes and provider overrides remain valid.
Add a separate reference-player interface and typed results alongside the legacy
interface, rather than adding required methods to every existing implementation.

The default `courseAudioProvider` delegates to the shared alpha player. A typed
reference-player provider exposes the same underlying instance; it must not
create a second owner/engine. Provider disposal invalidates requests immediately
and schedules guarded resource cleanup without unhandled asynchronous errors.

The runtime units have separate responsibilities:

| Unit | Responsibility |
| --- | --- |
| `course_audio_catalog.dart` | Load and validate bundled metadata; resolve reference ID, text, source path, review state and attribution |
| `course_audio.dart` | Reference policy, outcomes, request ownership, deadlines, legacy bridge and provider lifetime |
| Focused recording-backend file beside it | Lazy `audioplayers` session, source preparation, actual completion/error events, stop and disposal |
| Settings audio-credit view | Display per-file credits, source/licence URLs, notices, unchanged status and bundled legal texts |

An alternative separate player requiring migration of all screens was rejected:
it adds churn and would leave existing `speak(word)` flows using TTS. No new
playback package, custom browser decoder or retained spike code is needed.

## Catalogue and bundled files

Register manifest, provenance, the 24 WAVs and both complete licence texts under
`assets/audio/fr/` in `pubspec.yaml`. Preserve every original byte and filename,
including `île.wav` and the approved archived `mur`.

The catalogue reads the existing schema-version-1 manifest and provenance, not a
second manually maintained 24-file catalogue. It checks supported schema/language,
required runtime field types, unique IDs and paths, reference kind/text parity
with the authored curriculum, positive finite audio properties, and source/
licence/credit associations needed for display. Restrict paths to the registered
asset directory; reject traversal, remote URLs and unknown review status.

Translate the `frontend/` prefix only at the repository-to-Flutter asset boundary.
Keep stored IDs/paths unchanged; configure `AudioCache`/`AssetSource` consistently
so Flutter's `assets/` prefix is not accidentally doubled. Do not derive paths
from arbitrary caller text or fetch recordings from their source URLs.

Load/cache metadata on the first catalogue-dependent request; cache immutable
successful data, not a permanent failure that makes Retry ineffective. Looking
at credits may load metadata/legal text but must not initialize an audio engine.

The existing strict offline package verifier remains the binary/hash/provenance
authority and must pass before integration. Bundle tests check actual registered
coverage and byte identity. Runtime validation is not a second implementation of
the entire forensic verifier, and none of these checks establishes French truth.

Only words currently have recordings. The reference API recognizes the existing
word/sound/sentence/paragraph kinds, without inventing corresponding assets.
Support a requested normal or separately recorded slow variant; when no slow
variant exists, return unavailable. Do not alter playback rate or label the normal
recording as a reviewed slow version. Adding catalogue coverage is later scope.

## Playback policy and public outcomes

Reference requests include an explicit use policy: **alpha practice** or
**reviewed-only**. Normal alpha callers use alpha practice. Reviewed-only rejects
every current candidate before constructing an engine; it also rejects TTS.
It is an audio-source gate, not permission to create or enable assessments.

A reference request returns exactly one terminal outcome:

- **Completed:** the selected engine reported actual completion.
- **Cancelled:** Stop, disposal or a newer request revoked ownership.
- **Failed:** resolution, policy, capability, setup, playback or cleanup failed.

Include reference ID, selected source (`unverifiedRecording`, `reviewedRecording`
or `practiceTts`) when known, and a stable failure reason for UI/tests. Never label
an unverified recording reviewed because it played, nor claim a source was played
when selection failed before startup.

Use stable reasons for unknown reference, unavailable variant/missing asset,
unreviewed source, invalid catalogue, unsupported playback/decoding, browser
gesture restriction, unavailable French voice, startup/completion timeout and
stop/cleanup failure. These are retryable or alternative-practice states, not
wrong-answer outcomes. Preserve the underlying diagnostic cause for debugging.

### Recording-first legacy bridge and TTS

`speak(word)` resolves an exact authored word/reference. Covered words play the
bundled recording by default, so existing lessons, discovery and arcade use it
without changing their saved identities. No trimming, case-folding or alternate
Unicode slug is used to create a different content identity.

If a declared reference has no recording, TTS is permitted only under explicit
practice-fallback policy. The legacy compatibility path retains practice TTS for
text not covered by the bundled catalogue, including existing drill content.
Label that path as device speech/practice-only in the relevant UI; never imply
every legacy text has a human recording. Unknown reference IDs in the new API
fail rather than accepting arbitrary text disguised as a reference.

If a recording is declared but loading/playback fails, do not automatically
switch to TTS. Display Retry/unavailable; a later explicit TTS choice, if offered,
must be a separately labelled practice request, not a rescued completed recording.
No new fallback-choice screen is required for this slice.

The legacy bridge resolves `Future<void>` only for Completed. Failed raises a
typed audio exception; Cancelled raises a distinct cancellation exception so
existing success continuations cannot mark the word heard. Screens suppress
cancel feedback where appropriate and never unlock answers on cancellation.

Keep direct `FrenchWordAudio` behavior and its regression tests compatible. Its
existing quiet stale-result behavior is not the completion contract of the new
default facade; the facade retains its own ownership/outcome checks around TTS.
Construct the TTS adapter only if that request selects TTS.

## Completion, concurrency and lifecycle

No `AudioPlayer` is constructed during provider creation, catalogue resolution,
failed policy checks or a Stop with no active engine. The locked plugin's
constructor starts platform creation, so lazy initialization must be real.

Recording completion comes from the active session's completion event, subscribed
before starting playback. `AudioPlayer.play()`/`resume()` returning means startup,
not the recording ended. Stop, elapsed duration, disposal and timeout are not
successful completion. No looping is used for reference playback.

Each request has a monotonically increasing ownership token. New requests and
Stop invalidate old ownership synchronously, before awaiting platform work.
Check ownership after every asynchronous boundary, on success and failure.
An abandoned setup must not dispatch a later resume, publish a completion/error
to the new request, stop the new engine or write heard/progress state.

Each request settles only once. Cleanup errors after an already reported terminal
outcome are retained as cleanup/capability state, not a second result or a stale
error delivered to another caller. Do not report a cancelled request Completed
when its late completion arrives.

Use isolated recording sessions/player identities per request. Completion events
do not carry a content ID, so a late event from an older session must not complete
another request merely because a listener was replaced. Retire old sessions and
drain stale work safely; serialize required teardown before new audible playback.
If teardown cannot establish the old session is stopped, fail the new request
rather than risk overlapping audio. In particular, a late platform start command
must be stopped on its own retired session without touching the newer one.

Separate source preparation from resume so cancellation can be checked before
the command that starts audio. User-visible cancellation settles promptly even
when a platform future is held; late results are observed/drained, not left as
unhandled errors. Timeouts do not cancel platform futures, so they need the same
ownership and late-cleanup treatment.

Bound catalogue/setup, stop/cleanup and completion waits with injectable deadlines.
Default catalogue/setup allowance is 10 seconds, stop/cleanup 5 seconds, and
recording completion `max(10 seconds, declared duration + 5 seconds)` after resume
dispatch. Preserve the existing TTS 12-second utterance bound and bound its setup.
Tests use shorter injected deadlines; do not change global plugin timeout values
or treat a deadline as proof sound stopped.

Existing screen navigation/background hooks continue to call Stop. Add missing
hooks or request-generation guards in directly affected callers where necessary
(notably drill navigation), without unrelated screen/scoring redesign. Stop must
also invalidate in-flight catalogue loading before any engine exists.

## User feedback and licensing

Keep Play/Replay user-initiated. Browser autoplay/gesture rejection is a retryable
capability failure; do not bypass it through automatic retries. Async setup cannot
be assumed to preserve a browser gesture, so actual Flutter/plugin checks matter.

Use generic recording-capability guidance for recording errors; do not tell users
to install a TTS voice when a bundled WAV failed. Retain voice-specific guidance
only for an actual TTS request. Cancelled operations do not show a wrong-answer
message or mark audio heard.

Replace the generic Wikipedia CC BY-SA 3.0 credit with accurate package credits:
LoquaxFR, per-file source/audited revision URL, exact CC BY-SA 4.0 or CC BY 4.0
licence, attribution and notices, unchanged binary status, and accessible bundled
legal text. The `sans` exception and archived `mur` provenance caveat remain
visible. Selectable URLs are sufficient; no new link-launcher dependency is needed.
Keep code MIT visibly separate from third-party audio licences; root `LICENSE`
remains untouched. Include the unverified-alpha notice in this credit view.

Update `docs/french-reference-audio.md` and the FR-03 ticket to distinguish the
new alpha runtime authorization from pending linguistic/assessment readiness.
Preserve historical reports/specs as history rather than rewriting past scope.
Store/effective-DRM and broader release checks remain open; this work does not
publish to stores or certify redistribution terms.

## Verification and acceptance for this alpha slice

Test first using an injected catalogue/recording backend and controlled futures/
events. Include lazy creation; all terminal outcomes; exact word/ID/Unicode
resolution; missing/corrupt catalogue/assets; denied review policy; unsupported
variant/kind coverage; no error-triggered TTS; and actual completion vs startup.

Hold each async boundary and test Stop/replacement on both success/error paths.
Exercise stale completion, concurrent plays/stops, disposal, missing completion,
timeouts, late startup, teardown failure and retry. Cancelled or failed playback
must not unlock choices or record new evidence. Keep fake backend tests distinct
from actual plugin-event wiring tests and real-platform evidence.

Run existing TTS/cancellation tests, relevant lesson/discovery/drill/arcade and
credits widget tests, actual manifest/asset checks, strict Python verifier/tests,
full Flutter suite and analyzer. The ticket's `sound_word_help_test.dart` is not
present on this published baseline; do not claim it ran or pull unpublished work
to obtain it. Add focused compatibility coverage for the published help flow if
needed and retain existing API guarantees for the unpublished caller.

Check the actual Flutter app's recording path in an available browser, including
Replay/Stop, real completion and source-error behavior. Recheck bytes unchanged.
Exercise all 24 unchanged WAVs through the actual recording backend where the
browser environment permits, not just one successful word. The earlier raw
Chromium probe is useful feasibility evidence, not proof the
Flutter plugin path works. No sandbox exception is inherited for a future run.

Native iOS/Android, human listening and qualified French review remain explicit
pending checks if environments/reviewers are unavailable. These do not block the
user-approved alpha implementation, but no native/full-FR-03/production or
linguistic acceptance claim may replace that missing evidence. Report a blocked
manual browser check honestly; do not substitute mocked events as a platform pass.

Alpha implementation acceptance requires working bundled registration/default
recording selection, verified lifecycle/outcome behavior, truthful unverified/
TTS labels and credits, preserved saved identities/progress, passing applicable
automated checks, and an explicit manual-check results/limitations record.

## Delivery and exclusions

After written-spec and implementation-plan approval, use sequential
`ollama/qwen3.8:27b` implementation workers with explicit owned files and acceptance
criteria. Each dependent task starts from its predecessor's reviewed, merged
published `origin/main`. Workers cannot spawn workers or merge PRs.

Push scoped branches and open PRs against `main`; independently review code and
run controller verification on the exact head/base before normal guarded PR
merge. Missing CI is not a pass. Verify the published result and preserve all
branches/worktrees/local evidence, including unpublished Sound Match work.

No microphone changes, audio uploads, grading, new curriculum content, scoring
policy, progress migrations, model/tool evaluation, purchases or new audio
acquisition. No conversion, trimming, waveform repair, invented reviewed status,
production rollout, store publication or unrelated refactor.

Reference handoffs: [FR-03 ticket](../plans/2026-10-10-french-learning-path-tickets.md),
[candidate package guide](../../french-reference-audio.md), and
[playback spike/tool research](../research/2026-10-13-french-audio-playback-validation-spike.md).
