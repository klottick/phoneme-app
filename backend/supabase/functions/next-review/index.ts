import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response('Missing authorization header', { status: 401 });
  }

  const client = createClient(supabaseUrl, supabaseServiceRoleKey);
  const token = authHeader.replace('Bearer ', '');
  const {
    data: { user },
    error: authError,
  } = await client.auth.getUser(token);

  if (authError || !user) {
    return new Response('Unauthorized', { status: 401 });
  }

  const { data, error } = await client
    .from('review_queue')
    .select(
      `id, due_at, interval_days, ease_factor,
      phonemes!inner(id, ipa_symbol, descriptor, language_id,
      languages!inner(code, name))`,
    )
    .eq('user_id', user.id)
    .lte('due_at', new Date().toISOString())
    .order('due_at', { ascending: true })
    .limit(12);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  return new Response(
    JSON.stringify({
      items: data,
      status: 'ok',
    }),
    {
      headers: {
        'Content-Type': 'application/json',
      },
    },
  );
});
