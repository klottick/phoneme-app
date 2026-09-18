# Linguist App - Project Review & Roadmap

> Historical review of the language-only prototype. See `course-arcade.md` and
> `roadmap-status.md` for the current English → French course direction.

## Current State (v0.1.0)

### What's Built

#### Frontend (Flutter/Dart)
| Component | Files | Status |
|-----------|-------|--------|
| **App Entry** | `main.dart`, `app.dart` | ✅ |
| **Screens** | 6 screens (home, onboarding, IPA, drill, speak, progress, review) | ✅ |
| **State** | Riverpod providers | ✅ |
| **Routing** | GoRouter with auth guards | ✅ |
| **Models** | Phoneme, MinimalPair, ReviewItem | ✅ |
| **Repositories** | Curriculum, Progress | ✅ |
| **Services** | Audio, TTS, Recording, Streak | ✅ |
| **Tests** | 6 test files | ✅ |

#### Backend (Supabase)
| Component | Files | Status |
|-----------|-------|--------|
| **Schema** | 10+ tables | ✅ |
| **Migrations** | 3 migrations | ✅ |
| **Seed Data** | 3 languages, 60+ phonemes, 40+ pairs | ✅ |
| **Edge Functions** | 2 (next-review, submit-attempt) | ✅ |
| **Storage** | 3 buckets configured | ✅ |

#### Data Pipeline
| Component | Files | Status |
|-----------|-------|--------|
| **Generator** | `scripts/generate_minimal_pairs.py` | ✅ |
| **ipa-dict Integration** | MIT-licensed 125K+ words | ✅ |

### Architecture

```
frontend/lib/
├── main.dart                 # Entry point
├── src/
│   ├── app.dart              # MaterialApp.router
│   ├── routing/
│   │   └── app_router.dart   # Route guards
│   ├── core/
│   │   ├── constants/         # Supported languages
│   │   ├── models/            # Phoneme, MinimalPair, ReviewItem
│   │   ├── providers/        # Riverpod providers
│   │   ├── repositories/     # Curriculum, Progress
│   │   └── services/          # Audio, TTS, Recording, Streak
│   └── features/
│       ├── onboarding/        # Language selection
│       ├── home/             # Dashboard
│       ├── ipa/             # IPA Explorer
│       ├── drills/            # Minimal pair drills
│       ├── speak/            # Speaking practice
│       ├── progress/          # Progress tracking
│       └── review/            # Due review queue

backend/supabase/
├── migrations/               # Schema evolution
├── functions/                # Edge functions
├── seed.sql                  # Initial data
└── config.toml              # Project config
```

## Strengths

1. **Clean architecture** - Separation of concerns, testable
2. **MIT license** - Fully open, no licensing worries
3. **Expandable** - Easy to add languages/phonemes
4. **Offline-first** - Graceful degradation when backend unavailable
5. **Data pipeline** - Automated from ipa-dict

## Gaps to Address

### High Priority
- [ ] No authentication (Supabase Auth not wired)
- [ ] Real audio playback needs Supabase Storage URLs
- [ ] No user profile screen
- [ ] Progress calculations are placeholder

### Medium Priority
- [ ] No analytics/events tracking in UI
- [ ] No achievements/badges
- [ ] No daily reminders/notifications
- [ ] No settings screen

### Low Priority
- [ ] Dark mode
- [ ] Multiple speaker voices in TTS
- [ ] Voice recording playback in Speak screen

## Roadmap

### Phase 1: Core Completion (This Week)
- [ ] Wire Supabase Auth
- [ ] Connect user profile
- [ ] Connect real audio URLs from Supabase Storage
- [ ] Show real progress from backend

### Phase 2: Engagement (Next Week)
- [ ] Add daily streak notifications
- [ ] Add achievements UI
- [ ] Add settings (language swap, volume, TTS voice)
- [ ] Add analytics dashboard

### Phase 3: Polish (Week 3)
- [ ] Dark mode
- [ ] Onboarding tutorial for new users
- [ ] Performance optimization
- [ ] iOS build

### Phase 4: Expansion (Month 2)
- [ ] Add German, Spanish
- [ ] Add audio recording comparison
- [ ] Add pronunciation scoring (basic)
- [ ] App Store / Play Store submission

## Quick Wins to Add Now

1. **Settings Screen** - 30 min
```dart
// Add settings for:
// - TTS voice selection
// - Volume
// - Reset progress
// - Switch language
```

2. **Profile Screen** - 1 hour
```dart
// Show:
// - Current streak
// - Longest streak
// - Total practice time
// - Languages learned
```

3. **Achievement Badges** - 2 hours
```dart
// Badges:
// - First words
// - 7 day streak
// - 30 day streak
// - Perfect drill (10/10)
```

## Resources Needed

- **Audio recording** - Native speaker recordings for phonemes/minimal pairs
- **Time estimate** - 10-15 hours/week for full MVP

## Recommended Next Steps

1. Wire Supabase Auth in onboarding
2. Add user profile screen
3. Connect audio URLs from Storage
4. Deploy first beta to TestFlight/Play Store internal testing

The foundation is solid. Next priority is connecting authentication and real user data flows.
