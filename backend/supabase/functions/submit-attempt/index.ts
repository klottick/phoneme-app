import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

type AttemptPayload = {
  lesson_id: string;
  minimal_pair_id: string | null;
  phoneme_id: string;
  is_correct: boolean;
  response_time_ms: number | null;
};

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

function getNextReview(
  currentIntervalDays: number,
  currentEaseFactor: number,
  isCorrect: boolean,
): { intervalDays: number; easeFactor: number; dueAt: string } {
  const boundedEase = Math.min(2.8, Math.max(1.3, currentEaseFactor));
  const nextEase = isCorrect
    ? Math.min(2.8, boundedEase + 0.05)
    : Math.max(1.3, boundedEase - 0.2);

  const nextInterval = isCorrect
    ? Math.max(1, Math.round(currentIntervalDays * nextEase))
    : 1;

  const dueDate = new Date();
  dueDate.setUTCDate(dueDate.getUTCDate() + nextInterval);

  return {
    intervalDays: nextInterval,
    easeFactor: nextEase,
    dueAt: dueDate.toISOString(),
  };
}

serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response('Missing authorization header', { status: 401 });
  }

  const payload = (await req.json()) as AttemptPayload;
  const client = createClient(supabaseUrl, supabaseServiceRoleKey);

  const {
    data: { user },
    error: authError,
  } = await client.auth.getUser(authHeader.replace('Bearer ', ''));

  if (authError || !user) {
    return new Response('Unauthorized', { status: 401 });
  }

  const insertAttempt = await client.from('attempts').insert({
    user_id: user.id,
    lesson_id: payload.lesson_id,
    minimal_pair_id: payload.minimal_pair_id,
    is_correct: payload.is_correct,
    response_time_ms: payload.response_time_ms,
  });

  if (insertAttempt.error) {
    return new Response(JSON.stringify({ error: insertAttempt.error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const queueEntry = await client
    .from('review_queue')
    .select('id, interval_days, ease_factor')
    .eq('user_id', user.id)
    .eq('phoneme_id', payload.phoneme_id)
    .maybeSingle();

  const currentInterval = queueEntry.data?.interval_days ?? 1;
  const currentEase = Number(queueEntry.data?.ease_factor ?? 2.5);
  const next = getNextReview(currentInterval, currentEase, payload.is_correct);

  const upsertQueue = await client.from('review_queue').upsert(
    {
      user_id: user.id,
      phoneme_id: payload.phoneme_id,
      interval_days: next.intervalDays,
      ease_factor: next.easeFactor,
      due_at: next.dueAt,
    },
    { onConflict: 'user_id,phoneme_id' },
  );

  if (upsertQueue.error) {
    return new Response(JSON.stringify({ error: upsertQueue.error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  return new Response(
    JSON.stringify({
      status: 'ok',
      review: next,
    }),
    { headers: { 'Content-Type': 'application/json' } },
  );
});
