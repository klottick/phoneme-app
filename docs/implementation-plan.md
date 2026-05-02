# Phoneme App Broad Implementation Plan

## Phase 0: Product Definition (Week 1)
- Define v1 scope as listening discrimination only for English, French, and Japanese.
- Identify initial learner profiles and first target path(s).
- Define success metrics: D1/D7 retention, sessions per week, confusion-pair improvement.
- Confirm curriculum unit structure: phoneme inventory -> minimal pairs -> review loops.

## Phase 1: Learning Architecture and Content Model (Weeks 1-2)
- Build canonical phoneme schema per language.
- Define drill types:
  - identify phoneme
  - minimal pair A/B
  - odd-one-out
  - adaptive review
- Define progression logic: introduction -> guided drill -> mixed drill -> spaced review.
- Lock localization strategy for UI and learning content metadata.

## Phase 2: Supabase Foundation (Week 2)
- Set up Supabase Auth, Postgres, Storage, and Edge Functions.
- Create tables:
  - users profile metadata
  - languages
  - phonemes
  - minimal pairs
  - audio assets
  - lessons
  - attempts
  - user progress
  - review queue
- Enable RLS and least-privilege policies.
- Create storage buckets for phoneme and minimal-pair audio.
- Add event telemetry table for learning analytics.

## Phase 3: Flutter Foundation (Weeks 2-3)
- Initialize Flutter app with flavors for local/staging/production.
- Set up state management, routing, and dependency injection.
- Implement auth, onboarding, and language selection.
- Build a reusable design system supporting IPA and Japanese scripts.
- Add local cache and resilient network handling.

## Phase 4: Core Learning Experience (Weeks 3-6)
- IPA explorer per language with tap-to-play phoneme audio.
- Minimal-pair drill engine with immediate feedback.
- Session loop for 5-10 minute practice blocks.
- Progress and mastery views by phoneme group and confusion areas.
- Optimize audio prefetch and playback latency.

## Phase 5: Spaced Repetition and Adaptivity (Weeks 6-7)
- Implement review scheduling algorithm.
- Track per-user confusion matrix and repeated misses.
- Personalize upcoming drills toward weak contrasts.
- Add daily review target and reminder hooks.

## Phase 6: Content Operations Pipeline (Parallel)
- Define audio quality and normalization standards.
- Produce multi-speaker clips for all supported languages.
- Add a repeatable ingestion process with validation checks.
- Version content so updates do not invalidate user progress.

## Phase 7: QA, Beta, and Launch Readiness (Weeks 7-8)
- Validate on iOS and Android across low/mid/high device classes.
- Test offline behavior and unstable network handling.
- Add crash reporting and analytics funnel instrumentation.
- Prepare store assets, policy docs, and licensing checks.

## Phase 8: Post-v1 Expansion
- Add speaking mode (record + compare) before automated scoring.
- Introduce model-based pronunciation feedback in v2.
- Expand language and L1-specific learning paths.
- Add prosody and connected-speech modules.

## Recommended v1 Deliverable
- Three learning languages: English, French, Japanese.
- Start with listening-focused drills and adaptive review.
- Target 8-12 weeks to closed/public beta with a polished mobile UX.
