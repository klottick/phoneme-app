# FR-03 Alpha Reference-Audio Player Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable the 24 unchanged, explicitly unverified French recordings in normal alpha practice with real completion, safe cancellation, retryable errors and correct credits.

**Architecture:** Load immutable metadata from the bundled candidate package; resolve reference IDs through an ownership-aware facade over isolated recording sessions. Preserve the legacy `CourseAudio.speak(String)`/`stop()` interface and provider overrides, with explicit practice TTS policy and no recording-error substitution. Enable the default recording-first provider only with caller lifecycle/error regressions in Task 4.

**Tech Stack:** Dart/Flutter, Riverpod, existing audioplayers (locked 6.6.0), flutter_tts, Flutter tests and the existing Python stdlib package verifier. No new package is required.

**Spec:** `docs/superpowers/specs/2026-10-14-fr03-alpha-reference-player-design.md` (user approved at `71e1be8`, 2026-10-14).

## Global Constraints

- Alpha playback may use pending candidates; keep `catalogueStatus: candidate`, `review.status: pending`, null reviewer/date, empty review evidence and unverified speaker qualification.
- Do not change `frenchAudioResources` to `reviewedRecording` or clear existing readiness findings; runtime selection is separate from reviewed-resource readiness.
- Keep `CourseAudio.speak(String)` and `stop()` unchanged as public signatures; existing `implements CourseAudio` mocks/provider overrides must compile unchanged.
- Preserve version 1, contentRevision 1, `en-fr`, `en-fr-u-y`, `en-fr-u-y-listening`, saved word order/identities, scoring and progress behavior.
- Preserve all WAV/manifest/provenance/legal-text bytes, including Unicode `île` and the approved archived `mur`; no repair, conversion, trimming or rate manipulation.
- Catalogue/setup allowance 10 seconds; stop/cleanup 5 seconds; recording completion `max(10 seconds, declared duration + 5 seconds)` after resume dispatch; TTS utterance 12 seconds with bounded setup. Inject shorter deadlines in tests; no global plugin timeout changes.
- Cancellation and timeout are not successful playback. Never silently substitute TTS after a declared recording fails.
- FR-15 remains pending; no evaluation/models, recording uploads, microphone changes, new content, production/store rollout or root `LICENSE` changes.
- Native/iOS/Android and qualified French review may remain pending without blocking this alpha; missing evidence must never be reported as a pass.
- Use sequential `ollama/qwen3.8:27b` implementers, each starting from current published `origin/main` after the preceding PR is reviewed/merged. Workers cannot delegate or merge.
- Every task ends in a scoped pushed branch/PR against `main`, independent code review, controller verification/head-base/checks review, normal guarded PR merge and published-tree verification. Preserve branches/worktrees/evidence; absent CI is not a pass.

## Review Focus

1. A completion/error from a retired player must not finish, stop or unlock a newer request; pin session identity in Tasks 2–3.
2. A delayed platform resume after Stop/timeout must be fenced and stopped on its own session; unknown teardown must block overlapping playback, including TTS, in Tasks 2–3.
3. Corrupt/retried metadata and asset-prefix/Unicode errors must fail clearly, recover on Retry and never fall back to a derived URL/text; pin in Tasks 1, 3–4.
4. Stop/navigation/background and late UI continuations must not mark audio heard or save evidence; pin existing and missing caller hooks in Task 4.
5. Broad alpha/TTS labels and grouped credits must not imply reviewed audio, hide `sans`'s CC BY exception or relabel audio MIT; pin credit content in Task 1 and practice labels in Task 4.

---

## File map and shared interfaces

Product responsibilities: `course_audio_contract.dart` holds shared interfaces/results; `course_audio_catalog.dart` loads metadata; `course_recording_backend.dart` handles isolated plugin sessions; `course_reference_audio.dart` coordinates policy/ownership; existing `course_audio.dart` retains legacy TTS and owns providers. Settings gets a focused `french_audio_credits.dart` view. Do not refactor the generic `AudioService`.

### Task 1 contract (`frontend/lib/src/core/course/course_audio_contract.dart`)

Move the existing two-method `CourseAudio` declaration here without changing it; re-export it from `course_audio.dart`. Define these exact shared names:

```dart
enum CourseAudioUse { alphaPractice, reviewedOnly }
enum CourseAudioVariant { normal, slow }
enum CourseAudioSource { unverifiedRecording, reviewedRecording, practiceTts }
enum CourseAudioOutcome { completed, cancelled, failed }
enum CourseAudioFailureReason {
  unknownReference, unavailableVariant, missingAsset, invalidCatalogue,
  unreviewedSource, unsupportedPlayback, userGestureRequired,
  unavailableVoice, startupTimeout, completionTimeout, cleanupFailed,
}
abstract interface class CourseReferenceAudio implements CourseAudio {
  Future<CourseAudioResult> playReference(String referenceId, {
    CourseAudioUse use = CourseAudioUse.alphaPractice,
    CourseAudioVariant variant = CourseAudioVariant.normal,
    bool allowPracticeTts = false,
  });
  Future<void> dispose();
}
```

`CourseAudioFailure({required CourseAudioFailureReason reason, Object? cause, StackTrace? stackTrace})` has immutable corresponding fields. `CourseAudioResult` has immutable `outcome`, nullable `referenceId`/`source`, and nullable `failure`, with `completed({required String? referenceId, required CourseAudioSource source})`, `cancelled({String? referenceId, CourseAudioSource? source})`, and `failed({String? referenceId, CourseAudioSource? source, required CourseAudioFailure failure})` named constructors. Invalid terminal-field combinations cannot be constructed.

`CourseAudioException(CourseAudioFailure failure)` and `CourseAudioCancelledException()` are distinct exceptions for the legacy bridge. `const CourseAudioDeadlines({Duration setup = const Duration(seconds: 10), Duration cleanup = const Duration(seconds: 5), Duration completionFloor = const Duration(seconds: 10), Duration completionSlack = const Duration(seconds: 5), Duration ttsUtterance = const Duration(seconds: 12)})` exposes those fields and `Duration recordingCompletion(Duration duration)` implementing the specified maximum. Its `void validate()` rejects nonpositive values; facade/speech-factory construction calls it before using injected deadlines, without constructing an engine.

`CourseAudioRecording({required String assetKey, required int byteLength, required Duration duration, required CourseAudioSource source})` is immutable and represents an already validated bundled recording, never a remote source or TTS.

### Task 1 catalogue (`course_audio_catalog.dart`)

- `CourseAudioCredit({required String referenceId, required String spokenText, required String creator, required String sourceUrl, required String auditedRevisionUrl, required String licenseId, required String licenseUrl, required String licenseTextAssetKey, required String attribution, required List<String> notices, required bool unchanged, String? provenanceCaveat})`: immutable corresponding fields and notice copy. Preserve per-file associations; archived `mur` gets a faithful caveat, not a new historical claim.
- `CourseAudioEntry({required CourseAudioReference reference, required Map<CourseAudioVariant, CourseAudioRecording> recordings, required CourseAudioCredit credit})` has immutable copies of these fields.
- `CourseAudioCatalog({required List<CourseAudioReference> references, required List<CourseAudioEntry> entries})` indexes immutable unique references/entries; exposes `references`, `entries`, `CourseAudioReference? referenceById(String id)`, `CourseAudioReference? wordReferenceByText(String text)`, `CourseAudioRecording? recordingFor(String id, CourseAudioVariant variant)`. Exact text/Unicode equality, no derived IDs/paths.
- `CourseAudioCatalog.fromJson(Map<String, dynamic> manifest, Map<String, dynamic> provenance, {required List<CourseAudioReference> references})` validates the current pending schema and credit associations, throwing `CourseAudioException` with `invalidCatalogue` on bad metadata. The actual JSON loader requires all 24 current word entries in authored order; injected catalogue fixtures may represent missing coverage/future kinds for policy tests, without changing the shipped manifest.
- `CourseAudioCatalogLoader({required AssetBundle bundle, required List<CourseAudioReference> references})` exposes `Future<CourseAudioCatalog> load()`: coalesce concurrent loads, cache success, clear failed in-flight work for Retry. Convert repository paths by removing `frontend/` exactly once, validate before conversion.
- `courseAudioCatalogLoaderProvider`: `Provider<CourseAudioCatalogLoader>` using `rootBundle` and `frenchCurriculum.audioReferences`, with no audio-engine initialization.

### Task 2 backend (`course_recording_backend.dart`)

```dart
enum CourseRecordingEvent { completed }
abstract interface class CourseRecordingSession {
  Stream<CourseRecordingEvent> get events;
  Future<void> prepare(CourseAudioRecording recording);
  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
}
CourseRecordingSession createCourseRecordingSession();
```

The production implementation is `AudioplayersRecordingSession({AudioPlayer Function()? playerFactory})`. A session is permanently retired by Stop/dispose; `stop()` establishes quiescence, including fencing a pending start. It cannot mean merely that an early stop command was dispatched. Session streams emit errors with diagnostic causes; the facade normalizes them. Default factory constructs a lazy session, not an `AudioPlayer`.

### Task 3 facade and TTS boundary

`CoursePracticeSpeechSession` in the shared contract exposes `Future<void> speak(String text)`, `stop()` and `dispose()`. Stop establishes quiescence of its raw platform work, not just settlement of a timed-out public future. `createFrenchPracticeSpeechSession({CourseAudioDeadlines deadlines = const CourseAudioDeadlines()})` in `course_audio.dart` provides a lazy adapter backed by existing French TTS behavior; direct `FrenchWordAudio` callers keep their tested cancellation/error behavior.

`FrenchReferenceAudio({required Future<CourseAudioCatalog> Function() loadCatalog, required CourseRecordingSession Function() recordingFactory, required CoursePracticeSpeechSession Function() speechFactory, CourseAudioDeadlines deadlines = const CourseAudioDeadlines()})` in `course_reference_audio.dart` implements `CourseReferenceAudio`. No factory is called in its constructor. It implements the reference method above, `Future<void> speak(String word)`, `stop()` and `dispose()`.

Task 4 declares `courseReferenceAudioProvider: Provider<CourseReferenceAudio>` in `course_audio.dart`, injects loader/factories and owns disposal. Existing `courseAudioProvider: Provider<CourseAudio>` delegates to that same instance; existing overrides remain valid. Task 3 does not switch the default provider before Task 4's caller safeguards.

---

## Task 1: Bundle catalogue and truthful audio credits

**Owned files:**
- Create: `frontend/lib/src/core/course/course_audio_contract.dart`, `frontend/lib/src/core/course/course_audio_catalog.dart`.
- Modify: `frontend/lib/src/core/course/course_audio.dart` only interface extraction/re-export; `frontend/pubspec.yaml` only asset registration.
- Create: `frontend/lib/src/features/settings/french_audio_credits.dart`.
- Modify: `frontend/lib/src/features/settings/settings_screen.dart` only audio/code credit content.
- Create: `frontend/test/unit/course_audio_catalog_test.dart`, `frontend/test/widget/french_audio_credits_test.dart`.
- Modify: `docs/french-reference-audio.md` only current loader/registration/alpha-policy status, keeping playback pending until Task 4.

**Consumes:** unchanged manifest/provenance/legal texts; existing authored `CourseAudioReference` list.
**Produces:** Task 1 shared types/catalogue/loader/provider above; `const FrenchAudioCredits({super.key})` widget reading that loader, with Retry and offline legal-text access. Playback defaults remain unchanged.

- [ ] **1. Write failing catalogue tests.** Pin the actual catalogue and these mutations:

```dart
test('bundled catalogue preserves exact pending word identities', () async {
  final catalog = await loader.load();
  expect(catalog.entries.length, 24);
  expect(catalog.wordReferenceByText('île')!.id, 'fr-word-île');
  expect(catalog.wordReferenceByText('ile'), isNull);
  expect(catalog.recordingFor('fr-word-tout', CourseAudioVariant.normal)!.source,
      CourseAudioSource.unverifiedRecording);
  expect(catalog.recordingFor('fr-word-tout', CourseAudioVariant.slow), isNull);
});
```

Use a real loader with injected test AssetBundle for metadata tests; runtime load rejects missing/wrong JSON root and unsupported pending schema. Add named tests rejecting duplicate IDs/paths, unsupported schema/language/status, wrong reference kind/text, unsafe/remote paths, booleans/nonfinite/nonpositive audio properties, and mismatched provenance/licence/credit associations. `failed load is retryable and successful concurrent loads coalesce` must see a second bundle read after failure, one shared read during success, no permanent failed cache. `registered bytes match originals` reads every registered WAV/legal text from `rootBundle`, compares bytes against test-only filesystem originals, and checks AssetManifest coverage; no production `dart:io`. Contract tests pin terminal-field invariants and all deadline defaults; `validate()` rejects zero/negative injection.

- [ ] **2. Write failing credits tests.** Use real catalogue: show all 24 IDs/credits (scroll as needed), source/audited revision/licence URLs, unchanged status/notices, `sans` CC BY 4.0 exception, archived `mur` caveat, accessible complete legal texts and separate code MIT. Pin `French recordings are unverified alpha material.`; reject a generic CC BY-SA 3.0 notice for this package. A malformed first load shows Retry, a good second load succeeds, and viewing credits never constructs an audio engine.
- [ ] **3. Run RED.** From `frontend/`: `flutter test --no-pub test/unit/course_audio_catalog_test.dart test/widget/french_audio_credits_test.dart`. Expect compile/missing API or assertion failures attributable to unimplemented behavior; preserve red log.
- [ ] **4. Implement contracts/catalogue and bundle.** Use the interfaces above; register `assets/audio/fr/manifest.json`, `assets/audio/fr/provenance.json`, `assets/audio/fr/words/`, `assets/audio/fr/licenses/`. Preserve all dependencies/lockfile and all asset bytes. Do not import test helpers into production or create a duplicate handwritten manifest.
- [ ] **5. Implement credits view.** Add a focused expandable/scrollable per-file view; selectable URLs and locally loaded legal-text view suffice, no link-launcher dependency. Keep settings theme/reset/TTS controls unchanged. Update the guide's current status without rewriting historical research/specs.
- [ ] **6. Run GREEN and compatibility.** Run the RED command plus `flutter test --no-pub test/unit/french_audio_manifest_test.dart test/unit/course_audio_test.dart test/unit/course_audio_cancellation_test.dart test/widget/settings_test.dart`; run `flutter analyze --no-pub`. From repo root: `python3 scripts/verify_french_audio.py --repo-root .`. Expect all pass, analyzer clean, verifier still reports 24 pending candidates. Diff/hash checks must confirm unchanged package/root licence/dependencies.
- [ ] **7. Commit owned files, push scoped PR and hand off.** Commit `feat: bundle unverified French alpha audio catalogue and credits`. Record RED/GREEN, scope and remaining player/manual gates in PR/local evidence. Independent review and controller normal guarded merge/publication are required before Task 2 starts; a worker report is not delivery.

## Task 2: Isolated lazy recording sessions with real plugin events

**Owned files:** create `frontend/lib/src/core/course/course_recording_backend.dart`, `frontend/test/unit/course_recording_backend_test.dart`; create `frontend/test/support/fake_course_recording_session.dart` for subsequent facade tests. No provider/default changes.

**Consumes:** Task 1 `CourseAudioRecording`/failure types. **Produces:** Task 2 backend interfaces/factory above and `FakeCourseRecordingSession` with controllable `prepareGate`, `startGate`, `stopGate`, call log, `Future<void> waitForStart()` (resolves on start dispatch), `emitCompleted()` and `emitError(Object error)`.

- [ ] **1. Write failing real-adapter tests.** Inject a recording `AudioPlayer` factory and fake audioplayers platform/events; execute the actual adapter, not a stub of the adapter. Pin:
  - `construction and idle stop/dispose create no player`: factory count 0.
  - `prepare uses one Flutter asset prefix including Unicode`: selected `assets/audio/fr/words/île.wav` resolves without doubled prefix; MIME `audio/wav`, no source URL fetch.
  - `start acknowledgement is not completion`: completing resume alone emits no Completed; only the same player's plugin complete event emits it.
  - `stop during preparation prevents resume`: release held prepare successfully and with error; resume count remains 0.
  - `late resume is fenced before stop settles`: revoke during held resume; acknowledge later and require a stop on that retired identity after acknowledgement; no future start allowed.
  - `retired completion and error are drained`: no successful terminal event after retirement; no unhandled async failures.
  - `dispose is idempotent and releases subscriptions/resources`: include failed/held creation and preparation; do not assume uninitialized plugin late fields exist.
- [ ] **2. Run RED.** `flutter test --no-pub test/unit/course_recording_backend_test.dart` from `frontend/`; expect missing backend/behavior failures, preserve log.
- [ ] **3. Implement the recording adapter.** Construct an `AudioPlayer` only on requested prepare; configure its `AudioCache(prefix: '')` because the validated asset key already includes `assets/`. Subscribe before playback; `setSourceAsset(..., mimeType: 'audio/wav')`, ownership check, then separate `resume()`. Use normal non-looping playback. Isolate identities, guard retired startup, fence raw pending control work, route errors and dispose safely. No static/global plugin timeout mutations.
- [ ] **4. Add the deterministic fake.** Match the session interface; callers can hold/release success/error at all three gates and inspect operations/identities without any plugin/device.
- [ ] **5. Run GREEN.** Run backend/catalogue tests and analyzer; repeat failed/retired test paths with captured zone errors. Expect no early Completed, no retired resume, correct asset prefix and no unhandled exceptions. Run full Flutter tests before publication.
- [ ] **6. Commit owned files, push and obtain reviewed publication.** Commit `feat: add cancellable bundled recording sessions`. Include fake-vs-plugin distinction and no manual-device certification. Start Task 3 only after PR merge/current published baseline verification.

## Task 3: Ownership-aware reference facade and bounded practice speech

**Owned files:** create `frontend/lib/src/core/course/course_reference_audio.dart`; modify `frontend/lib/src/core/course/course_audio_contract.dart` only speech-session contract; modify `frontend/lib/src/core/course/course_audio.dart` only lazy/bounded TTS adapter/factory (do not switch default provider yet). Create `frontend/test/unit/course_reference_audio_test.dart`, `frontend/test/support/fake_course_speech_session.dart`; extend `frontend/test/unit/course_audio_test.dart`/`frontend/test/unit/course_audio_cancellation_test.dart` for preserved direct TTS behavior and raw-work fences.

**Consumes:** Tasks 1–2 interfaces/catalogue and fake. **Produces:** `FrenchReferenceAudio` and practice speech factory above, with one terminal result per request; default app still uses existing TTS until Task 4. `FakeCourseSpeechSession` implements the shared speech contract, with held speak/stop/dispose futures, call log and success/error releases. Facade tests construct their own immutable catalogue fixtures and inject these factories; no undefined external fixture package or device is needed.

- [ ] **1. Write failing selection/outcome tests.** Use injected catalogues, recording sessions and speech sessions. The following test asserts the terminal distinction without a device:

```dart
test('recording startup does not resolve playback', () async {
  final pending = audio.playReference('fr-word-tout');
  var settled = false;
  pending.then((_) => settled = true);
  await session.waitForStart(); // fake helper waits for dispatch, not a timer
  expect(settled, isFalse);
  session.emitCompleted();
  final result = await pending;
  expect(result.outcome, CourseAudioOutcome.completed);
  expect(result.source, CourseAudioSource.unverifiedRecording);
});
```

Also pin `reviewedOnly denies all shipped candidates before factory creation`, `unknown ID fails without text-derived TTS`, `missing slow variant is unavailable`, `missing declared asset never invokes speech`, `no recording-error TTS`, `explicit practice fallback alone permits a declared unrecorded word`, `reviewedOnly never permits TTS`, and `legacy unmapped text uses practice speech and resolves only on completion`. Inject future-kind references with no recordings and ensure unavailable/unknown outcomes, not fabricated word-path playback.

`failure classification retains diagnostic cause` asserts invalid catalogue, missing asset, denied review policy, setup/completion deadline and cleanup reasons separately. Recognizable browser gesture failures map to `userGestureRequired`, French voice unavailability to `unavailableVoice`, and other decoder/platform failures to `unsupportedPlayback`; unknown causes stay generic rather than inventing a voice/permission diagnosis. Preserve `cause`/`stackTrace`, and classify the selected source rather than all errors as TTS.

- [ ] **2. Write failing race/deadline tests.** For catalogue load, preparation, resume/start, completion, speech setup/utterance, stop and disposal: hold success and error, revoke with Stop/replacement, then release. Require prompt Cancelled, no later audible dispatch, no new owner mutated by stale events, and exactly one terminal result. `idle stop and policy denial are lazy` asserts both factory counts 0. `older completion cannot complete newer session` and `older failure cannot stop newer session` assert identity separation. `blocked retirement fails replacement rather than overlapping` holds stop beyond injected cleanup deadline; late stop targets only old identity, retry may proceed only after confirmed quiescence. Add retry after load/prepare/start error, completion timeout and disposal; disposed objects cannot restart.
- [ ] **3. Write TTS boundary regressions.** Keep direct `FrenchWordAudio` null/native-success/error/stale-draining tests. Bound its setup at 10 seconds and utterance at 12 without losing original causes for active failures. Track raw platform work separately from timeout futures; the practice-session wrapper fences a held raw speak/control operation before reporting quiescence, while the facade returns Cancelled promptly. Old speech completion cannot complete a recording request or unlock callers. Factories/providers remain lazy.
- [ ] **4. Run RED.** `flutter test --no-pub test/unit/course_reference_audio_test.dart test/unit/course_audio_test.dart test/unit/course_audio_cancellation_test.dart`. Expect targeted unimplemented behavior failures; preserve logs, not unrelated platform/config failures.
- [ ] **5. Implement facade/policy/legacy bridge.** Use an ownership token plus isolated engine sessions, attach event/error observation before dispatch, validate after every awaited boundary, normalize failures to the shared stable reasons. `speak` maps Completed to return, Cancelled to `CourseAudioCancelledException`, Failed to `CourseAudioException`; do not let cancelled legacy futures resolve as success. No declared recording failure changes source. Keep held raw operations observed after user-facing cancellation/timeouts; do not mistake elapsed duration for completion or released futures for stopped sound.
- [ ] **6. Implement bounded practice speech.** Preserve direct adapter API/tests; wrap raw-work retirement in the separate session interface. Stop/dispose with no initialized TTS must not initialize it. Cleanup failure blocks new audible ownership until resolved; it does not deliver a second outcome to a retired request. Use injected deadlines, not sleeps/global settings.
- [ ] **7. Run GREEN and exact-deadline assertions.** Run RED command plus backend/catalogue tests, full Flutter suite and analyzer. Verify production default fields `10/5/10/5/12` seconds and duration+slack maximum independently of injected test durations; verifier/package hashes remain unchanged. No device/browser success claim from mocks.
- [ ] **8. Commit owned files, push and obtain reviewed publication.** Commit `feat: coordinate reference audio outcomes and safe cancellation`. Review especially hung raw TTS/control operations, stale events and terminal-result identity. Default recording selection is deliberately deferred to Task 4; report that honestly.

## Task 4: Enable recording-first alpha practice and verify the integrated app

**Owned files:** modify `frontend/lib/src/core/course/course_audio.dart` only provider wiring; modify `frontend/lib/src/core/course/french_course.dart` only readiness-vs-runtime explanatory comments if needed (no data changes). Modify directly affected callers `frontend/lib/src/features/course/course_lesson_screen.dart`, `frontend/lib/src/features/course/discovery_lesson_screen.dart`, `frontend/lib/src/features/arcade/arcade_screen.dart`, `frontend/lib/src/features/drills/drill_screen.dart` only audio lifecycle/generation guards/error/source labels. Create `frontend/test/unit/course_audio_provider_test.dart`, `frontend/test/widget/course_audio_lifecycle_test.dart`, `frontend/test/widget/drill_audio_lifecycle_test.dart`; extend existing `frontend/test/widget/course_flow_test.dart`, `frontend/test/widget/discovery_lesson_test.dart`, `frontend/test/widget/arcade_switch_test.dart` only needed audio regressions. Modify `docs/french-reference-audio.md`, `docs/superpowers/plans/2026-10-10-french-learning-path-tickets.md`; create `docs/superpowers/research/2026-10-14-fr03-alpha-playback-verification.md` as the results/limitations handoff. No extra production probe route or retained spike code.

**Consumes:** `FrenchReferenceAudio`, lazy backend/speech factories and catalogue loader. **Produces:** shared providers, recording-first existing practice flows, truthful labels/retry UX and a dated evidence record. This completes the alpha slice, not full linguistic/native/production FR-03 acceptance.

- [ ] **1. Write failing provider integration tests.** Read both providers and assert identical underlying object, zero engines before Play, exact reference resolution for all 24 current words and recording engine selected without TTS. Existing `courseAudioProvider.overrideWithValue` mocks compile/run unchanged. Provider disposal invalidates a held catalogue/start without late playback or unhandled failures.
- [ ] **2. Write failing caller tests.** For published lessons/discovery/arcade/drills, hold completion and ensure choices/evidence remain locked until actual success; fail/cancel and verify no heard/progress/new evidence. Navigate/background during setup/playback, release late success/error and ensure stale busy/message/heard state cannot overwrite a new owner/item. Exercise the drill's Play/Stop control and end-session/dispose hooks; preserve streak/progress and answer semantics. Recording failure shows Retry/unavailable, not "Install a French voice". Only an actual speech failure may use voice-specific copy.
- [ ] **3. Pin alpha/TTS disclosure.** Relevant listening/practice surfaces show `Alpha audio: recordings are unverified; device speech is practice-only.` without changing authored content/answer keys. Test an unmapped drill word with speech selected so the fallback is not presented as a reviewed/human recording. Settings keeps Task 1's full credits/notice. No new assessment readiness, grade or persistent field is introduced.
- [ ] **4. Run RED.** `flutter test --no-pub test/unit/course_audio_provider_test.dart test/widget/course_audio_lifecycle_test.dart test/widget/drill_audio_lifecycle_test.dart` from `frontend/`; expect old-default/lifecycle/label assertion failures. Preserve logs.
- [ ] **5. Wire providers and caller safeguards.** New provider owns `FrenchReferenceAudio`; old provider delegates. Add missing stop/lifecycle/request-generation checks narrowly, suppress cancellation alerts and use source-appropriate errors. Do not change generic `AudioService`, recording capture, backup or scoring rules. Keep recorded audio classified pending in readiness validators.
- [ ] **6. Run integrated GREEN.** From `frontend/`, run the RED command; run `flutter test --no-pub` and `flutter analyze --no-pub`. From root run `python3 -m unittest discover -s scripts -p 'test_*.py' -v` and `python3 scripts/verify_french_audio.py --repo-root .`. Expect all tests pass/analyzer clean and 24-pending verifier pass. Recheck manifest/legal/WAV byte identity, saved IDs/order and unchanged structural/35 readiness baseline; do not rely on old test-count totals as evidence.
- [ ] **7. Check actual Flutter browser/plugin playback.** Controller prepares an available local Flutter web build, e.g. `flutter build web --no-pub --debug`, with any existing app configuration handled as nonsecret environment setup, not a committed override. Serve locally; user-initiated existing practice actions must exercise recording selection/end and Replay/Stop. A throwaway external driver may exercise all 24 using the actual Dart catalogue/facade/backend if UI coverage is inconvenient, but fake completion/raw JS decoder results are not plugin evidence. Capture build/browser/plugin versions, all-file results, cancellation/error checks, console errors and source hashes; mute/headless limitations remain explicit. No inherited no-sandbox permission: ask separately if a sandbox-capable browser is unavailable. Never upload audio or create a production test route.
- [ ] **8. Record native/manual gates honestly.** Write the handoff document with real command exit statuses/results, exact tested tree, binary identities, browser evidence or blocker, and untested native/human/listening/release gates. Actual native checks are optional when environment unavailable; mark pending, not failed/passed. If browser check is blocked by tooling, say why and keep that platform gate open; code may be reviewed as an alpha slice, never as tested cross-platform playback. A real functional blocker discovered in an available environment must be fixed/reviewed, not reclassified as a missing-tool limitation.
- [ ] **9. Update current documentation.** Guide/ticket explain enabled, linguistically unverified alpha recordings; separate runtime availability from pending assessed-readiness. Retain per-file rights/RIFF/archive caveats, pending FR-15 and missing reference types; preserve historical evidence. Do not blanket-complete FR-02 or full FR-03.
- [ ] **10. Commit owned files and publish final scoped PR.** Commit `feat: enable unverified French recordings for alpha practice`. PR includes source/rights scope, RED/GREEN, actual manual results/limits and unresolved release gates. Obtain whole-integrated code review in addition to scoped task review, controller fresh exact-head/base verification/checks, then normal guarded merge only with no code blockers. Independently verify published tree/tests/assets; record PR URL, reviewed head, merge commit, commands and outstanding gates locally. Preserve all worktrees and unpublished Sound Match work.

## Controller execution checkpoints

- [ ] User reviews this written plan and confirms it captures the desired alpha. Preserve sequential `ollama/qwen3.8:27b` workers; do not silently change to native implementation or parallel workers.
- [ ] Before dispatch, select each worker's exact owned files/task acceptance, create an isolated branch/worktree from latest published `origin/main`, and record baseline. Workers read both this plan and spec/root `AGENTS.md`; no nested agents/merges.
- [ ] For each PR, review actual diff/independent feedback, confirm owned scope/package preservation, run applicable verification independently and check exact head/base/checks before merging. Re-evaluate if base/head changed; no admin bypass or direct main push.
- [ ] After each merge, verify published result and record delivery; only then dispatch dependent task. Final whole-tree review covers late events/cleanup fences, default recording selection, labels/licensing, callers/progress and honest platform coverage.
- [ ] Report alpha implementation separately from full reviewed/assessed/native/store readiness. No FR-15 evaluation starts under this plan.

## Plan self-review / execution gate

Controller self-review completed: Task 1 covers schema/bundle/credits and shared
contracts; Task 2 covers plugin events/session fences; Task 3 covers source policy,
legacy results/deadlines/TTS raw-work retirement; Task 4 covers default wiring,
caller lifecycle/labels/progress/manual evidence/current docs and final delivery.
All five Review Focus items have explicit owning regressions; shared names/types,
deadline values, file ownership and sequential publication are consistent.
No code bodies or retained probe are prescribed as product implementation.
Do not treat this review or a draft PR as user approval: execution waits for the
user's plan review and confirmation of the preserved worker method.
