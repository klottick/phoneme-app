# Phoneme App

Starter monorepo for a phoneme-learning mobile app.

## Structure
- `docs/implementation-plan.md`: broad implementation plan.
- `frontend/`: Flutter client scaffold.
- `backend/supabase/`: Supabase config, migration, and edge-function scaffold.

## Frontend quick start
1. Install Flutter SDK.
2. Copy `frontend/.env.example` to `frontend/.env` and set real values.
3. Run:
   - `flutter pub get`
   - `flutter run`

## Backend quick start
1. Install Supabase CLI.
2. From `backend/`, run:
   - `supabase start`
   - `supabase db reset`
3. Deploy function later with:
   - `supabase functions deploy next-review`
