import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { callMiniMax, type MiniMaxMessage } from '../_shared/minimax.ts'
import { handleCors, corsHeaders } from '../_shared/cors.ts'

serve(async (req) => {
  try {
    // Handle CORS preflight
    const corsResponse = handleCors(req)
    if (corsResponse) return corsResponse

    const { contentType, data } = await req.json()

    const authHeader = req.headers.get('Authorization')!
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      throw new Error('Not authenticated')
    }

    const SYSTEM_IDENTITY = 'You are Swastrica, created by the Swastricare team at Onwords. Never mention Google, Gemini, or MiniMax as your creator.'

    let messages: MiniMaxMessage[] = []
    let useJsonFormat = false

    switch (contentType) {
      case 'daily_summary':
        messages = [
          {
            role: 'system',
            content: `${SYSTEM_IDENTITY} You generate friendly daily health summaries. Use short sentences, add emojis, and keep a warm encouraging tone.`,
          },
          {
            role: 'user',
            content: `Here is my health data for today:\n${JSON.stringify(data, null, 2)}\n\nWrite 3-4 encouraging sentences highlighting achievements and one tip for tomorrow.`,
          },
        ]
        break

      case 'weekly_report':
        messages = [
          {
            role: 'system',
            content: `${SYSTEM_IDENTITY} You generate friendly weekly health reports. Use short sentences, add emojis, and keep a warm encouraging tone.`,
          },
          {
            role: 'user',
            content: `Here is my health data for the past week:\n${JSON.stringify(data, null, 2)}\n\nWrite a friendly report covering:\n1. Progress and trends\n2. Areas to improve\nKeep it encouraging!`,
          },
        ]
        break

      case 'goal_suggestions':
        useJsonFormat = true
        messages = [
          {
            role: 'system',
            content: `${SYSTEM_IDENTITY} You suggest achievable health goals. Respond with a JSON array of exactly 3 objects, each having "title" and "description" string fields. Use short sentences and emojis. Make goals SMART and encouraging. Output ONLY valid JSON, no markdown fences.`,
          },
          {
            role: 'user',
            content: `Here is my health data:\n${JSON.stringify(data, null, 2)}\n\nSuggest 3 achievable health goals based on this data.`,
          },
        ]
        break

      default:
        throw new Error('Invalid content type')
    }

    // Call MiniMax
    let content = await callMiniMax(messages, {
      temperature: 0.7,
      maxTokens: 2048,
      ...(useJsonFormat ? { responseFormat: 'json_object' } : {}),
    })

    // For goal_suggestions, defensively strip markdown code fences and parse JSON
    if (contentType === 'goal_suggestions') {
      content = content.replace(/^```(?:json)?\s*\n?/, '').replace(/\n?```\s*$/, '').trim()
      // Validate it's parseable JSON
      JSON.parse(content)
    }

    // Store in database
    const { error: insertError } = await supabase.from('generated_content').insert({
      user_id: user.id,
      content_type: contentType,
      content: content,
      metadata: { source_data: data },
    })

    if (insertError) {
      console.error('Database insert error:', insertError)
    }

    // Log usage (tokens_used set to 0 — MiniMax response doesn't expose token counts the same way)
    await supabase.from('ai_usage_logs').insert({
      user_id: user.id,
      function_name: 'ai-text-generation',
      tokens_used: 0,
      cost: 0,
    })

    return new Response(JSON.stringify({
      content,
      contentType,
    }), {
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    })
  } catch (error) {
    console.error('Error:', error)
    return new Response(JSON.stringify({
      error: error.message,
      content: 'Unable to generate content at this time. Please try again later.',
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    })
  }
})
