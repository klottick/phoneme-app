# Linguist

A mobile application for mastering phonemes to become a better language learner. Designed for iOS and Android with Flutter and Supabase.

## Goals

- Help users develop phoneme-level listening discrimination
- Support English, French, and Japanese as initial target languages
- Provide adaptive spaced repetition practice
- Track learner progress and identify confusion pairs

## Why This App Exists

Most language learners struggle with pronunciation not because they don't know vocabulary, but because they can't hear the difference between sounds in their target language. This app targets that specific problem:

- **Phoneme discrimination** — training the ear to distinguish between similar sounds
- **Minimal pair drills** — practice with word pairs that differ by only one sound
- **Spaced repetition** — optimize review timing for long-term retention
- **Adaptive learning** — personalize practice based on individual confusion patterns

## Target Audience

- Language learners who want clearer pronunciation
- Students preparing for listening exams (JLPT, DELF, etc.)
- Anyone who wants to improve their ear for foreign languages

## Tech Stack

- **Frontend**: Flutter (Dart) — single codebase for iOS/Android
- **Backend**: Supabase (PostgreSQL + Auth + Storage + Edge Functions)
- **State Management**: Riverpod
- **Routing**: GoRouter

## Project Structure

```
linguist/
├── README.md                   # This file
├── docs/
│   └── implementation-plan.md  # Detailed phase-by-phase plan
├── frontend/                   # Flutter application
│   ├── lib/
│   │   ├── src/
│   │   │   ├── core/         # Models, repositories, providers
│   │   │   ├── features/      # Screens (drills, ipa, progress, review)
│   │   │   └── routing/      # App router configuration
│   │   └── main.dart
│   └── pubspec.yaml
└── backend/                   # Supabase backend
    └── supabase/
        ├── migrations/       # Database schema migrations
        ├── functions/       # Edge functions
        ├── seed.sql         # Initial data
        └── config.toml     # Supabase project config
```

## Quick Start

### Prerequisites

- Flutter SDK (>= 3.x)
- Supabase CLI

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

## Current Features

- [x] Onboarding with language selection
- [x] IPA Explorer showing all phonemes for a language
- [x] Minimal pair discrimination drills
- [x] Progress tracking per phoneme
- [x] Due review queue display
- [x] Spaced repetition algorithm (SM-2 based)
- [x] Adaptive practice focused on weak pairs

## Data Model

### Core Tables

- `languages` — supported languages (English, French, Japanese)
- `phonemes` — IPA symbols and descriptors per language
- `minimal_pairs` — word pairs that differ by one phoneme
- `lessons` — named drill sessions
- `attempts` — individual learner responses
- `user_progress` — mastery scores per phoneme
- `review_queue` — spaced repetition queue

### Analytics Tables

- `confusion_pairs` — pairings that are commonly confused
- `user_confusion_stats` — per-user confusion tracking
- `learning_events` — event telemetry

## Milestones

### v1 (MVP)
- Language selection flow
- IPA chart per language
- Minimal pair listening drills
- Basic progress tracking
- Spaced repetition review queue

### v2 (Planned)
- Audio playback with waveform display
- Voice recording and self-comparison
- Speaking assessment (basic scoring)
- Additional language paths

## License

MIT License — see LICENSE file for details.