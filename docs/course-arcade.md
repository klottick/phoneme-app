# Language-pair course and sound arcade

## Product intention

Linguist is a phoneme, listening and pronunciation app organized by a directional
source → target language course. English → French is the sole authored demo.
General vocabulary, grammar and translation curricula are outside this iteration.

Home emphasizes Continue lesson, Review sounds and Play for a minute. Lessons
provide English explanations informed by English-speaker difficulties; French words
and citation pronunciations supply the learning material. Other language resources
are preserved as historical material, not offered as authored courses.

## Content and lessons

`french_course.dart` defines course identity, five ordered lessons, and a shared
word bank. Each word has its meaning, IPA, explicit constituent phonemes and a
spelling hint. Membership is never inferred with string matching on orthography.
The small curated set uses contemporary metropolitan French citation forms;
connected-speech variation is not assessed.

Lesson answers are deliberate listening selections made after successful playback.
The focus sound is present in the word and distractors are absent. Recording is
optional self-comparison, not automated pronunciation certification. Existing
experimental scoring services do not determine course completion.

## Sound Match

- 6×6 board, four visually distinct sound families: /u/, /y/, /i/, /o/.
- Two adjacent taps swap gems. A swap without a match is reverted.
- Matches clear, columns fall and refill, and cascades multiply points.
- A match of at least four creates a star. Matching a star clears a row.
- Every approximately 12 active seconds after the last answered challenge, a
  French word cue is chosen from a sound family with a legal match on the board.
- The next unambiguous, single-family deliberate match answers the cue and can
  earn +100. Incorrect answers keep the ordinary move's points. Multi-family
  matches and automatic cascades provide no listening evidence.
- If the correct move disappears, retire the cue unscored. Failed audio can be
  retried and never creates an incorrect learning record.

## Word Match

- 4×4 board of French words; initially practice /u/ and /y/.
- Connect three or more neighboring matching words; diagonals are permitted,
  repeats are rejected, and dragging back one tile undoes the last selection.
- Drag-and-release or tap-and-Link controls are supported.
- Long chains earn a star. A star in a valid chain clears its row automatically.
- Outlined obstacles are cleared along with their word and award +50 each.
- Chain combos multiply points up to ×5; a mistaken chain resets the combo.
- Targets rotate every four successful moves. Initial spelling hints fade after
  the first four moves. Long-press tooltips provide English meanings.
- Invalid chains do not clear tiles. Feedback gives the mistaken word's IPA.
- Automatic clears do not become learning evidence. Word selections are recorded
  as sound–spelling evidence, never listening evidence.
- Every board has a legal chain; replenish target tiles if necessary.

The game/learning ratio is a qualitative playtesting goal, not a measured property.
Word Match naturally involves more explicit sound knowledge; repeat targets,
combos and special-tile goals are intended to support fluent puzzle play.

## Sessions, persistence and backend

Games have 60 seconds of active play, paused for playback and backgrounding. End of
round is a stopping point, not a loss condition. Continue retains the board/score.
Checkpoint round, time, score, board, target, obstacles and stars in preferences.
Malformed checkpoints fall back to a fresh board with an explanatory message.
There are no lives or daily limits.

Local progress is namespaced by course and signed-in user (or guest). Serialize
writes to avoid lost answers. Lesson completion, spelling/listening evidence and
game scores are independent. Correct answers are due tomorrow, incorrect answers
now; these transparent intervals are the initial review policy, not a mastery model.

The additive migration creates courses, course lessons, event receipts, sound
progress, completions and best scores. Existing language-only data is untouched.
`record_course_events` derives ownership from authentication, validates batches,
deduplicates event IDs and updates aggregates atomically. Read policies isolate
users. Signed-in local events retain their account owner in the retryable outbox.
Guest history is not automatically uploaded on sign-in. Cloud download/merge is
not yet implemented; course dashboards explicitly report device-local progress.

## Verification

Unit tests exercise playable-board generation over repeated moves, rejected swaps
and chains, separate learning evidence, board serialization, concurrent writes and
round continuation. Widget tests exercise onboarding, navigation, lesson completion,
silent play, audio failure and background pause. SQL tests run in a rolled-back
transaction and check idempotency, separate skills and user isolation.

Manual device checks remain necessary for native TTS, microphone recording and
touch feel. The demo uses device French TTS rather than shipped native recordings.
