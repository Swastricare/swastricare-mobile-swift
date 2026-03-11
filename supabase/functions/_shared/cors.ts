// Shared CORS headers for Supabase Edge Functions

export const corsHeaders = {
  // Note: '*' is acceptable for mobile app backends since requests come from native apps, not browsers
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

export function handleCors(req: Request): Response | null {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }
  return null
}
