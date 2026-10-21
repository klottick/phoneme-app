# Linguist — French pronunciation for English speakers

Linguist teaches listening and pronunciation through **directional language-pair
courses**. The first available course is **English → French**: English explanations,
French examples, and a guided path through sounds that matter to English speakers.

## Current experience

- **Learn:** five short lessons covering steady vowels, `/u/` versus `/y/`, nasal
  vowels, French R, and mixed practice. Listen, identify a focus sound, optionally
  record yourself, and compare. Completing the activities advances the path;
  heuristic pronunciation scores do not gate learning.
- **Sound Match:** a 6×6 match-three puzzle with swaps, cascades, row-clearing stars,
  and occasional French listening challenges. Requires a French device TTS voice.
- **Word Match:** a silent 4×4 word-chain puzzle. Link neighboring French words
  containing the target phoneme, clear obstacles, and earn row-clearing stars.
  Drag a chain or tap tiles and select **Link**. Long-press a word for its meaning.
- **One-minute play:** each game lasts 60 seconds of active play, then offers
  **Continue this board** or **Finish**. Boards save at round boundaries and when
  finishing/backgrounding. Backgrounding pauses play until explicitly resumed.
- **Course progress:** lesson completion, listening evidence, sound–spelling
  evidence, and arcade best scores are tracked separately. Incorrect sound answers
  are due for review now; correct answers return the next day.

The demo works without an account or Supabase. Word Match never initializes audio.
French words and explicit phoneme annotations are shared by lessons and games;
answers are not guessed from spelling. Early Word Match rounds include letter hints.

## Run the demo

```bash
cd frontend
flutter pub get
flutter run
# Browser demo:
flutter run -d web-server
```

No `.env` file is required. Choose **Start English → French**, then **Continue
lesson** or **Play for a minute**. Install a French voice in your device's speech
settings for listening activities. Failed audio never counts as a wrong answer.
Recording/self-comparison requires microphone permission and native device support.

### Persistent localhost demo (Linux/systemd)

From the **primary repo checkout**, with a clean tracked working tree and the
approved Flutter SDK (currently 3.47.7):

```bash
python3 scripts/local_demo.py update --flutter /absolute/path/to/flutter
python3 scripts/local_demo.py install
```

Open **http://127.0.0.1:8088**. No account, Supabase, root access, Docker, or
public hosting is needed. This is a local pre-alpha demo, not release acceptance.
The listener binds only to IPv4 loopback, not the LAN. Choose this exact URL each
time: browser progress belongs to its origin/profile and is not cloud-synced.

Builds and the generated `phoneme-demo.service` stay in the repo's ignored
`build/local-demo/` directory. `install` enables a **user** service by linking that
unit into systemd's per-user configuration; no system-wide unit is installed.
The service runs independently of this terminal, agents, or temporary worktrees,
starts with your user service manager (normally at login), and restarts after
failure. It cannot serve while the computer is asleep/off. The helper does not
enable lingering or alter login/boot policy.

```bash
python3 scripts/local_demo.py status
python3 scripts/local_demo.py logs
python3 scripts/local_demo.py stop
python3 scripts/local_demo.py start
# Explicitly rebuild/update after reviewing and merging source changes:
python3 scripts/local_demo.py update --flutter /absolute/path/to/flutter
```

Updates build into a fresh release directory, check the main app/SQLite worker
assets, then atomically switch `build/local-demo/current`. Failed builds leave
the current release untouched; prior releases are retained. `/demo-build.json`
identifies the source commit. Refresh the browser after a successful update.
There are no automatic pulls, dependency upgrades, rebuilds, or data resets.
Do not remove the repo or `build/local-demo/` while this service is in use.

To stop automatic startup, run `systemctl --user disable --now phoneme-demo.service`.
If you move the repo or change the Python executable, stop/disable the old service
and inspect/remove its old generated unit and registration link before reinstalling
from the new location. The helper refuses to overwrite another service definition.

## Optional Supabase backup

Apply `backend/supabase/migrations/202609180001_language_pair_courses.sql` using
your normal Supabase migration workflow, then run:

```bash
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY
```

Signed-in practice is stored in an account-specific local namespace and queued for
idempotent cloud backup through `record_course_events`. Failed requests retain the
outbox; the progress screen offers **Sync saved progress** to retry. Guest practice
stays on the device. Cross-device download/merging is not implemented yet.
Legacy language-only progress is preserved and is not silently assigned to a course.

## Development and verification

```bash
cd frontend
flutter test
flutter analyze
flutter build web
```

Native permission/configuration checks (from the repository root):

```bash
python3 scripts/test_mobile_configuration.py
```

Backend regression test (against local Supabase, from the repository root):

```bash
PGPASSWORD=postgres psql -h 127.0.0.1 -p 54322 -U postgres -d postgres \
  -v ON_ERROR_STOP=1 -f backend/supabase/tests/seed.sql \
  -f backend/supabase/tests/course_events.sql
```

The seed test validates curriculum inserts inside a rolled-back transaction. The
course test creates the new schema inside a transaction, verifies event
deduplication, skill separation and user isolation, then rolls back. Run these
before applying the course migration to the local database.

### Main implementation areas

- `frontend/lib/src/core/course/`: course content, word annotations, French audio,
  local progress and cloud outbox.
- `frontend/lib/src/features/course/`: guided lessons, progress and reviews.
- `frontend/lib/src/features/arcade/`: pure Dart game engines and shared session UI.
- `docs/course-arcade.md`: design, rules and remaining validation work.

<details>
<summary>Historical prototype documentation (superseded by the course experience above)</summary>

The following notes describe the earlier language-only prototype. Its feature
checklist and roadmap are historical, not release-readiness claims for this version.

## 🎯 Features

### 🔊 Phoneme Identification
- **Hear a phoneme** spoken in isolation
- **Identify from list** - Choose the correct phoneme from 4 options
- **Feedback** - Immediate correctness indicator with explanations
- **Spaced repetition** - Reviews scheduled based on SM-2 algorithm

### 🎤 Phoneme Test (Speaking)
- **Record yourself** saying a phoneme
- **AI assessment** - Local acoustic analysis + optional Whisper API
- **Score breakdown** - Clarity, rhythm, intonation feedback
- **Word context** - Practice saying phonemes within words

### 📚 IPA Explorer
- **Browse all phonemes** by language (EN/FR/JA)
- **Hear pronunciation** - TTS playback for each phoneme
- **Search & filter** - By category (vowel/consonant) and difficulty
- **IPA keyboard** - Type IPA symbols easily
- **Bookmarks** - Save difficult phonemes for quick access

### 📊 Minimal Pairs Drills
- **Word pairs** - Practice with minimal pairs (ship/sheep, etc.)
- **Contrastive listening** - Train ear to hear subtle differences
- **Audio comparison** - Compare reference vs your recording
- **20+ pairs per language**

### 📈 Progress Tracking
- **Mastery bars** - Visual progress per phoneme
- **Streak calendar** - Daily practice tracking
- **Heatmap** - Practice intensity visualization
- **Charts** - Accuracy trends over time
- **Insights** - Personalized statistics

### 🎮 Learning Modes
- **Challenge mode** - Timed practice with scoring
- **Marathon** - Extended practice sessions
- **Zen mode** - Relaxed, no-pressure practice

### 📅 Curriculum & Content
- **Lesson plans** - Structured learning paths for EN/FR/JA
- **Custom phonemes** - Add your own phonemes
- **Word of the Day** - Daily phoneme with word examples
- **Daily goals** - Set phoneme/minute targets

### 🏆 Achievements & Gamification
- **15+ achievements** for milestones
- **XP system** - Earn points for practice
- **Difficulty progression** - 5 levels from Beginner to Expert

### 🔔 Accessibility
- **Font scaling** - Adjustable text size
- **High contrast** - Enhanced visual accessibility
- **Reduce motion** - For motion-sensitive users
- **Haptic feedback** - Tactile responses

### 📱 Session Features
- **Practice timer** - Track session duration
- **Sound wave visualizer** - See your voice waveform
- **Practice reminders** - Customizable notifications

## 🎯 Goals

- Help users develop phoneme-level listening discrimination
- Support English, French, and Japanese as initial target languages
- Provide adaptive spaced repetition practice
- Track learner progress and identify confusion patterns

## 🌟 Why This App Exists

Most language learners struggle with pronunciation not because they don't know vocabulary, but because they can't **hear the difference** between sounds in their target language. This app targets that specific problem:

- **Phoneme discrimination** — training the ear to distinguish between similar sounds
- **Minimal pair drills** — practice with word pairs that differ by only one sound
- **Spaced repetition** — optimize review timing for long-term retention
- **Adaptive learning** — personalize practice based on individual confusion patterns

## 👥 Target Audience

- Language learners who want clearer pronunciation
- Students preparing for listening exams (JLPT, DELF, etc.)
- Anyone who wants to improve their ear for foreign languages
- Linguists studying phonetics

## 💻 Tech Stack

- **Frontend**: Flutter (Dart) — single codebase for iOS/Android
- **Backend**: Supabase (PostgreSQL + Auth + Storage + Edge Functions)
- **State Management**: Riverpod
- **Routing**: GoRouter
- **Local Storage**: SharedPreferences
- **Audio**: record, audioplayers, flutter_tts

## 📂 Project Structure

```
linguist/
├── README.md                   # This file
├── docs/
│   ├── implementation-plan.md  # Detailed phase-by-phase plan
│   ├── project-review.md      # Code review document
│   ├── roadmap-status.md      # Current status
│   └── audio-resources.md     # Audio dataset references
├── frontend/                   # Flutter application
│   ├── lib/
│   │   ├── src/
│   │   │   ├── core/
│   │   │   │   ├── models/       # Phoneme, MinimalPair, ReviewItem
│   │   │   │   ├── repositories/ # Curriculum, Progress repos
│   │   │   │   ├── services/     # 20+ services (auth, streaks, SRS, etc.)
│   │   │   │   ├── providers/    # Riverpod providers
│   │   │   ├── theme/       # Design system
│   │   │   └── widgets/     # Reusable widgets (IPA keyboard)
│   │   ├── features/
│   │   │   ├── home/          # Main dashboard
│   │   │   ├── phoneme_id/    # Identification screen
│   │   │   ├── phoneme_test/  # Speaking test screen
│   │   │   ├── audio/         # Audio comparison
│   │   │   ├── drills/        # Minimal pairs drills
│   │   │   ├── modes/         # Learning modes
│   │   │   ├── content/      # Custom content manager
│   │   │   ├── progress/     # Progress screens
│   │   │   ├── settings/     # App settings
│   │   │   ├── ipa/          # IPA explorer
│   │   │   ├── search/       # Phoneme search
│   │   │   ├── auth/         # Login/signup
│   │   │   ├── onboarding/   # Language selection
│   │   │   └── review/       # Review screen
│   │   ├── routing/        # GoRouter configuration
│   │   └── main.dart
│   ├── test/
│   │   ├── unit/           # 50+ unit tests
│   │   └── widget/         # Widget tests
│   ├── pubspec.yaml
│   └── analysis_options.yaml
└── backend/                   # Supabase backend
    └── supabase/
        ├── migrations/       # Database schema migrations
        ├── functions/       # Edge functions
        ├── seed.sql         # Initial data
        └── config.toml     # Supabase project config
```

## 🚀 Quick Start

### Prerequisites

- Flutter SDK (>=3.3.0)
- Supabase CLI
- Dart SDK

### Frontend Setup

```bash
cd frontend

# Copy environment file and edit with your Supabase credentials
cp .env.example .env

# Get dependencies
flutter pub get

# Run on connected device or emulator
flutter run
```

### Backend Setup

```bash
cd backend/supabase

# Start local Supabase instance
supabase start

# Apply migrations
supabase db reset

# (Optional) Deploy edge functions
supabase functions deploy next-review
supabase functions deploy submit-attempt
```

## 📊 Current Features Status

| Feature | Status | Description |
|---------|--------|-------------|
| Onboarding | ✅ | Language selection flow |
| IPA Explorer | ✅ | Browse all phonemes per language |
| Phoneme ID | ✅ | Listen and identify phonemes |
| Phoneme Test | ✅ | Record and assess speaking |
| Minimal Pairs | ✅ | Contrastive listening drills |
| Audio Compare | ✅ | Reference vs user recording |
| Progress Analytics | ✅ | Mastery charts, streaks, heatmap |
| Spaced Repetition | ✅ | SM-2 algorithm queue |
| Learning Modes | ✅ | Challenge, Marathon, Zen |
| Curriculum | ✅ | Lesson plans for EN/FR/JA |
| Custom Content | ✅ | Add your own phonemes |
| Achievements | ✅ | 15+ gamification badges |
| Word of the Day | ✅ | Daily phoneme with examples |
| Daily Goals | ✅ | Set practice targets |
| Accessibility | ✅ | Font scale, contrast, haptics |
| Session Timer | ✅ | Practice duration tracking |
| Sound Visualizer | ✅ | Waveform display |
| Bookmarks | ✅ | Save difficult phonemes |
| Search | ✅ | Find phonemes quickly |
| IPA Keyboard | ✅ | Type IPA symbols |
| Notifications | ✅ | Practice reminders |
| Data Export/Import | ✅ | Backup and restore |
| Social Sharing | ✅ | Share achievements |

## 📂 Data Model

### Core Tables

- `languages` — supported languages (English, French, Japanese)
- `phonemes` — IPA symbols and descriptors per language (78+ phonemes)
- `minimal_pairs` — word pairs that differ by one phoneme (33+ pairs)
- `lessons` — structured learning sessions
- `attempts` — individual learner responses
- `user_progress` — mastery scores per phoneme
- `review_queue` — spaced repetition queue

### Analytics Tables

- `confusion_pairs` — pairings that are commonly confused
- `user_confusion_stats` — per-user confusion tracking
- `learning_events` — event telemetry

## 🎯 Phoneme Spelling Rules

### English (EN)

| Phoneme | Example Words | Spelling Patterns | Context Notes |
|---------|---------------|------------------|--------------|
| /iː/ | fleece, see, sea | ee, ea, ie, ei | "ea" can also be /ɛ/ (head) |
| /ɪ/ | kit, sit, gym | i, y, ui | Short vowel in closed syllables |
| /ɛ/ | dress, bed, head | e, ea | Check "ea" words carefully |
| /æ/ | trap, cat, plaid | a | Not in open syllables |
| /ɑː/ | father, car, heart | ar, a (before r) | Lengthened before /r/ |
| /ɒ/ | lot, stop, want | o, a (before l/k) | "-" sound in many dialects |
| /ɔː/ | thought, law, more | or, ore, au, aw | Lengthened in most contexts |
| /ʊ/ | foot, put, could | u, oo | Short, near-close |
| /uː/ | goose, two, move | oo, u, ue, ew | Long, close back |
| /ʌ/ | strut, cup, love | u, o | Always short |
| /ɜː/ | nurse, bird, word | er, ir, ur, or (after w) | R-colored vowel |
| /ə/ | about, comma, doctor | a, e, i, o, u | Schwa - unstressed syllables |
| /eɪ/ | face, say, weight | ay, a_e, ea, ey | Diphthong |
| /aɪ/ | price, my, eye | i_e, y, uy, ie | Diphthong |
| /ɔɪ/ | choice, boy, oil | oy, oi | Diphthong |
| /aʊ/ | mouth, now, out | ow, ou | Diphthong |
| /əʊ/ | goat, go, show | o_e, ow, oe | Diphthong |
| /ɪə/ | near, here, beer | ear, eer, ier | Diphthong with schwa |
| /ɛə/ | square, hair, bear | air, are, ear | Diphthong with schwa |
| /ʊə/ | tour, poor, moor | our, oor, ure | Diphthong with schwa |
| /p/ | pen, top, happy | p, pp | Voiceless bilabial plosive |
| /b/ | bed, rob, rub | b, bb | Voiced bilabial plosive |
| /t/ | tea, sit, stopped | t, tt, ed | Voiceless alveolar plosive |
| /d/ | day, bed, married | d, dd, ed | Voiced alveolar plosive |
| /k/ | cat, tick, school | k, c, ck, ch | Voiceless velar plosive |
| /g/ | go, dog, ghost | g, gg, gh | Voiced velar plosive |
| /tʃ/ | chain, church, nature | ch, tch, t (+ure) | Voiceless postalveolar affricate |
| /dʒ/ | jet, judge, soldier | j, dg, g (+e,i,y) | Voiced postalveolar affricate |
| /f/ | fish, coffee, photo | f, ff, ph, gh | Voiceless labiodental fricative |
| /v/ | voice, love, of | v | Voiced labiodental fricative |
| /θ/ | think, thing, athle | th | Voiceless dental fricative |
| /ð/ | this, mother, them | th | Voiced dental fricative |
| /s/ | see, city, dance | s, c, sc, ps | Voiceless alveolar fricative |
| /z/ | zoo, buzz, dogs | z, s (between vowels) | Voiced alveolar fricative |
| /ʃ/ | she, sugar, issue | sh, ti, ci, si | Voiceless postalveolar fricative |
| /ʒ/ | measure, usual, visual | s, z, g (+e,i,y) | Voiced postalveolar fricative |
| /h/ | hat, who, whole | h, wh | Voiceless glottal fricative |
| /m/ | man, summer, comb | m, mm, mb | Bilabial nasal |
| /n/ | no, sunny, knife | n, nn, kn | Alveolar nasal |
| /ŋ/ | sing, finger, bank | ng, n (+k,g) | Velar nasal |
| /l/ | leg, bell, people | l, ll | Alveolar lateral approximant |
| /r/ | red, very, car | r, rr, wr | Alveolar approximant |
| /j/ | yes, use, onion | y, i (+ vowel) | Palatal approximant |
| /w/ | we, quick, language | w, qu | Labial-velar approximant |
| /ʔ/ | chip, watch, nature | ch (+ar,ar,ua) | Voiceless postalveolar affricate |
| /ʕ/ | joke, bridge, soldier | j (+ust,uge) | Voiced postalveolar affricate |

### French (FR)

| Phoneme | Example Words | Spelling Patterns | Context Notes |
|---------|---------------|------------------|--------------|
| /i/ | vile, ici, si | i, i, y | Close front unrounded |
| /y/ | tu, sur, rue | u | Close front rounded |
| /u/ | coup, tout, où | ou | Close back rounded |
| /e/ | blé, été, mes | é, er, es | Close-mid front unrounded |
| /ø/ | deux, peu, sœur | eu, œu | Close-mid front rounded |
| /ɛ/ | mère, fait, leur | è, ai, ei | Open-mid front unrounded |
| /œ/ | sœur, bœuf, jeune | œu, eu | Open-mid front rounded |
| /a/ | patte, bas, tas | a | Open front unrounded |
| /ɑ/ | pâte, grâce, tâton | â, asse | Open back unrounded |
| /ɔ/ | hotte, cause, chaud | au, eau, ô | Open-mid back rounded |
| /ɑ̃/ | tant, sans, champ | an, en, em | Nasal - front |
| /ɛ̃/ | vin, main, sein | in, im, yn | Nasal - front |
| /ɔ̃/ | bon, mon, son | on, om | Nasal - back |
| /œ̃/ | un, lundi, chacun | un, um | Nasal - front rounded |
| /p/ | pas, apprendre, trop | p, pp | Voiceless bilabial |
| /b/ | bon, robe, nabab | b, bb | Voiced bilabial |
| /t/ | tant, tout, statue | t, tt | Voiceless alveolar |
| /d/ | dans, vide, sud | d, dd | Voiced alveolar |
| /k/ | cas, école, qui | k, c, qu, ck | Voiceless velar |
| /g/ | gant, guerre, long | g, gg, gu | Voiced velar |
| /f/ | feu, vif, neuf | f, ff, ph | Voiceless labiodental |
| /v/ | vie, rêve, wagon | v, w | Voiced labiodental |
| /s/ | si, assez, sac | s, ss, c (+e,i,y) | Voiceless alveolar |
| /z/ | zoo, rose, musée | z, s (between vowels) | Voiced alveolar |
| /ʃ/ | chat, cher, schéma | ch | Voiceless postalveolar |
| /ʒ/ | joue, âge, magicien | j, g (+e,i,y) | Voiced postalveolar |
| /ʁ/ | roi, rond, parler | r | Voiced uvular fricative |
| /m/ | maman, somme, pomme | m, mm | Bilabial nasal |
| /n/ | non, année, sonne | n, nn | Alveolar nasal |
| /ɲ/ | agneau, oignon, campagne | gn | Palatal nasal |
| /l/ | loup, elle, seul | l, ll | Alveolar lateral |
| /ʀ/ | huit, huile, ahuri | h | Voiceless glottal |

### Japanese (JA)

| Phoneme | Example Words | Spelling (Hiragana/Katakana) | Context Notes |
|---------|---------------|-------------------------------|--------------|
| /a/ | あ (a) | あ, ア | Open central |
| /i/ | い (i) | い, イ | Close front |
| /u/ | う (u) | う, ウ | Close back compressed |
| /e/ | え (e) | え, エ | Close-mid front |
| /o/ | お (o) | お, オ | Close-mid back |
| /ka/ | か (ka) | か, カ | Voiceless velar plosive |
| /ga/ | が (ga) | が, ガ | Voiced velar plosive |
| /ki/ | き (ki) | き, キ | Palatalized k |
| /gi/ | ぎ (gi) | ぎ, ギ | Palatalized g |
| /ku/ | く (ku) | く, ク | Velar plosive |
| /gu/ | ぐ (gu) | ぐ, グ | Velar plosive |
| /ke/ | け (ke) | け, ケ | Velar plosive |
| /ge/ | げ (ge) | げ, ゲ | Velar plosive |
| /ko/ | こ (ko) | こ, コ | Velar plosive |
| /go/ | ご (go) | ご, ゴ | Velar plosive |
| /sa/ | さ (sa) | さ, サ | Voiceless alveolar fricative |
| /za/ | ざ (za) | ざ, ザ | Voiced alveolar fricative |
| /ɕi/ | し (shi) | し, シ | Voiceless palatal fricative |
| /dʑi/ | じ (ji) | じ, ジ | Voiced palatal fricative |
| /su/ | す (su) | す, ス | Alveolar fricative |
| /zu/ | ず (zu) | ず, ズ | Alveolar fricative |
| /se/ | せ (se) | せ, セ | Alveolar fricative |
| /ze/ | ぜ (ze) | ぜ, ゼ | Alveolar fricative |
| /so/ | そ (so) | そ, ソ | Alveolar fricative |
| /zo/ | ぞ (zo) | ぞ, ゾ | Alveolar fricative |
| /ta/ | た (ta) | た, タ | Voiceless alveolar plosive |
| /da/ | だ (da) | だ, ダ | Voiced alveolar plosive |
| /tɕi/ | ち (chi) | ち, チ | Voiceless postalveolar affricate |
| /dʕi/ | ぢ (ji) | ぢ, ヂ | Voiced postalveolar affricate |
| /tsu/ | つ (tsu) | つ, ツ | Alveolar affricate |
| /dzu/ | づ (dzu) | づ, ヅ | Voiced affricate |
| /te/ | て (te) | て, テ | Alveolar plosive |
| /de/ | で (de) | で, デ | Alveolar plosive |
| /to/ | と (to) | と, ト | Alveolar plosive |
| /do/ | ど (do) | ど, ド | Alveolar plosive |
| /na/ | な (na) | な, ナ | Alveolar nasal |
| /ni/ | に (ni) | に, ニ | Alveolar nasal |
| /nu/ | ぬ (nu) | ぬ, ヌ | Alveolar nasal |
| /ne/ | ね (ne) | ね, ネ | Alveolar nasal |
| /no/ | の (no) | の, ノ | Alveolar nasal |
| /ha/ | は (ha) | は, ハ | Voiceless glottal fricative |
| /ba/ | ば (ba) | ば, バ | Voiced bilabial plosive |
| /pa/ | ぱ (pa) | ぱ, パ | Voiceless bilabial plosive |
| /hi/ | ひ (hi) | ひ, ヒ | Voiceless glottal fricative |
| /bi/ | び (bi) | び, ビ | Voiced bilabial plosive |
| /pi/ | ぴ (pi) | ぴ, ピ | Voiceless bilabial plosive |
| /fu/ | ふ (fu) | ふ, フ | Labiodental fricative |
| /bu/ | ぶ (bu) | ぶ, ブ | Voiced bilabial plosive |
| /pu/ | ぷ (pu) | ぷ, プ | Voiceless bilabial plosive |
| /he/ | へ (he) | へ, ヘ | Voiceless glottal fricative |
| /be/ | べ (be) | べ, ベ | Voiced bilabial plosive |
| /pe/ | ぺ (pe) | ぺ, ペ | Voiceless bilabial plosive |
| /ho/ | ほ (ho) | ほ, ホ | Voiceless glottal fricative |
| /bo/ | ぼ (bo) | ぼ, ボ | Voiced bilabial plosive |
| /po/ | ぽ (po) | ぽ, ポ | Voiceless bilabial plosive |
| /ma/ | ま (ma) | ま, マ | Bilabial nasal |
| /mi/ | み (mi) | み, ミ | Bilabial nasal |
| /mu/ | む (mu) | む, ム | Bilabial nasal |
| /me/ | め (me) | め, メ | Bilabial nasal |
| /mo/ | も (mo) | も, モ | Bilabial nasal |
| /ja/ | や (ya) | や, ヤ | Palatal approximant |
| /ju/ | ゆ (yu) | ゆ, ユ | Palatal approximant |
| /jo/ | よ (yo) | よ, ヨ | Palatal approximant |
| /ra/ | ら (ra) | ら, ラ | Alveolar tap |
| /ri/ | り (ri) | り, リ | Alveolar tap |
| /ru/ | る (ru) | る, ル | Alveolar tap |
| /re/ | れ (re) | れ, レ | Alveolar tap |
| /ro/ | ろ (ro) | ろ, ロ | Alveolar tap |
| /wa/ | わ (wa) | わ, ワ | Labial-velar approximant |
| /wo/ | を (wo) | を, ヲ | Labial-velar approximant |
| /n/ | ん (n) | ん, ン | Alveolar nasal (syllable-final) |

## 🧪 Milestones

### v1.0 (MVP) - ✅ Complete
- Language selection flow
- IPA chart per language
- Minimal pair listening drills
- Basic progress tracking
- Spaced repetition review queue

### v2.0 (Planned)
- Audio playback with waveform display
- Voice recording and self-comparison
- Speaking assessment (basic scoring)
- Additional language paths
- Social sharing features

## 🔒 Security

- MIT License — see LICENSE file for details
- Supabase handles authentication securely
- Local data stored via SharedPreferences (encrypted on iOS)
- No personal data shared without consent

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📞 Tests

```bash
cd frontend

# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run analysis
dart analyze
```

## 📄 License

MIT License — see [LICENSE](LICENSE) file for details.

---

**Made with ❤️ using Flutter and Supabase**

</details>
