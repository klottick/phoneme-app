import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

serve(async (_req: Request) => {
  return new Response(
    JSON.stringify({
      message: 'next-review function scaffolded',
      status: 'ok',
    }),
    {
      headers: {
        'Content-Type': 'application/json',
      },
    },
  );
});
