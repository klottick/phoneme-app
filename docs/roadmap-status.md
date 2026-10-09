# Roadmap status — English → French courses

## Implemented
- Directional course onboarding and a guided five-lesson English → French path.
- Shared curated French words with explicit phoneme membership and spelling hints.
- Sound Match: swap-to-match-three, cascades, stars, optional listening bonuses.
- Word Match: silent word chains, obstacles, stars, fading spelling hints.
- 60-second rounds, continuation, background pause, account/course-scoped checkpoints.
- Local lesson completion, separate listening/spelling evidence, next-day reviews,
  and arcade scores. Optional idempotent Supabase upload with a persistent outbox.
- Automated engine, flow, persistence, audio-failure and SQL isolation tests.

## Next validation priorities
1. Playtest on iOS and Android: touch/drag feel, French voice availability, microphone
   handling, screen sizes, and whether the games feel primarily recreational.
2. Replace device TTS references with a linguistically reviewed recording set.
3. Tune challenge frequency, targets, power-ups and lesson sequence from playtests.
4. Add cross-device cloud download/merge; current cloud integration backs up
   signed-in events while dashboards read local progress.
5. Expand Word Match beyond the initial /u/–/y/ contrast and author additional
   directional courses only after English → French is validated.

Older services and screens remain in the repository as supporting/legacy tools.
They should not be interpreted as fully integrated features of the new course path.

## Known arcade follow-up
- Sound Match currently awards a star when simultaneous three-tile matches clear
  at least four tiles in total. Align eligibility with the advertised rule of a
  single match of four or more tiles; learning evidence and persistence are unaffected.
