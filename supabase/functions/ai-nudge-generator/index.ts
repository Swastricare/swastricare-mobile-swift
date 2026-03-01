import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { callMiniMax, type MiniMaxMessage } from '../_shared/minimax.ts'
import { handleCors, corsHeaders } from '../_shared/cors.ts'

const NUDGE_SYSTEM_PROMPT = `You are a health nudge generator. Given a user's recent health data and a nudge trigger, generate a brief, warm, actionable nudge message.

Rules:
- Keep messages under 100 characters for push notification compatibility
- Use 1 relevant emoji at the start
- Be encouraging, not nagging
- Be specific to the data provided
- Return valid JSON: { "title": "...", "message": "..." }`

serve(async (req) => {
  try {
    const corsResponse = handleCors(req)
    if (corsResponse) return corsResponse

    // Use service role for server-side operations
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { user_id } = await req.json().catch(() => ({}))

    console.log('🔔 NUDGE GENERATOR: Starting', user_id ? `for user ${user_id}` : 'for all users')

    // Get active users (or specific user)
    let usersQuery = supabase
      .from('health_profiles')
      .select('id, user_id')
      .eq('is_primary', true)

    if (user_id) {
      usersQuery = usersQuery.eq('user_id', user_id)
    }

    const { data: profiles, error: profilesError } = await usersQuery.limit(100)
    if (profilesError || !profiles?.length) {
      console.log('🔔 No profiles found:', profilesError?.message)
      return new Response(JSON.stringify({ nudges_generated: 0 }), {
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      })
    }

    let totalNudges = 0

    for (const profile of profiles) {
      const nudges = await generateNudgesForUser(supabase, profile)
      totalNudges += nudges.length

      if (nudges.length > 0) {
        // Insert nudges
        const { error: insertError } = await supabase.from('ai_nudges').insert(nudges)
        if (insertError) {
          console.error('🔔 Insert error:', insertError.message)
          continue
        }

        // Send push for medium/high priority
        const pushNudges = nudges.filter((n: any) => n.priority !== 'low')
        for (const nudge of pushNudges) {
          await sendPushNotification(supabase, profile.user_id, nudge)
        }
      }
    }

    console.log(`🔔 NUDGE GENERATOR: Done. Generated ${totalNudges} nudges.`)

    return new Response(JSON.stringify({ nudges_generated: totalNudges }), {
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    })
  } catch (error) {
    console.error('🔔 Nudge generator error:', error.message)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    })
  }
})

// Check trigger conditions and generate nudges for one user
async function generateNudgesForUser(supabase: any, profile: any) {
  const nudges: any[] = []
  const now = new Date()
  const hour = now.getUTCHours()

  // Skip overnight (11pm-6am UTC — approximate; real impl would use user timezone)
  if (hour >= 23 || hour < 6) return nudges

  // Don't generate more than 3 nudges per 2-hour window
  const { data: recentNudges } = await supabase
    .from('ai_nudges')
    .select('id')
    .eq('user_id', profile.user_id)
    .gte('created_at', new Date(now.getTime() - 2 * 3600 * 1000).toISOString())

  if (recentNudges && recentNudges.length >= 3) return nudges

  const today = now.toISOString().split('T')[0]

  // Check hydration
  const { data: recentWater } = await supabase
    .from('hydration_logs')
    .select('created_at')
    .eq('health_profile_id', profile.id)
    .order('created_at', { ascending: false })
    .limit(1)

  const lastWater = recentWater?.[0]?.created_at
  if (lastWater) {
    const hoursSinceWater = (now.getTime() - new Date(lastWater).getTime()) / 3600000
    if (hoursSinceWater >= 4) {
      const msg = await generateNudgeMessage('hydration', `No water logged in ${Math.floor(hoursSinceWater)} hours`)
      nudges.push({
        health_profile_id: profile.id,
        user_id: profile.user_id,
        nudge_type: 'hydration',
        title: msg.title,
        message: msg.message,
        priority: 'medium',
        action_deeplink: 'swastricare://hydration',
        source_data: { hours_since_water: Math.floor(hoursSinceWater) },
        expires_at: new Date(now.getTime() + 4 * 3600 * 1000).toISOString(),
      })
    }
  }

  // Check daily steps (from daily_health_metrics)
  const { data: todayMetrics } = await supabase
    .from('daily_health_metrics')
    .select('steps')
    .eq('health_profile_id', profile.id)
    .eq('date', today)
    .single()

  if (todayMetrics?.steps !== undefined && hour >= 10) {
    if (todayMetrics.steps < 500) {
      const msg = await generateNudgeMessage('inactivity', `Only ${todayMetrics.steps} steps today`)
      nudges.push({
        health_profile_id: profile.id,
        user_id: profile.user_id,
        nudge_type: 'inactivity',
        title: msg.title,
        message: msg.message,
        priority: 'medium',
        action_deeplink: 'swastricare://steps',
        source_data: { steps: todayMetrics.steps },
        expires_at: new Date(now.getTime() + 3 * 3600 * 1000).toISOString(),
      })
    } else if (todayMetrics.steps >= 8000 && hour >= 18) {
      // Close to goal — encouraging nudge
      const msg = await generateNudgeMessage('step_goal_close', `${todayMetrics.steps} steps — almost at 10k!`)
      nudges.push({
        health_profile_id: profile.id,
        user_id: profile.user_id,
        nudge_type: 'step_goal_close',
        title: msg.title,
        message: msg.message,
        priority: 'low',
        action_deeplink: 'swastricare://steps',
        source_data: { steps: todayMetrics.steps },
        expires_at: new Date(now.getTime() + 6 * 3600 * 1000).toISOString(),
      })
    }
  }

  return nudges
}

async function generateNudgeMessage(nudgeType: string, context: string): Promise<{ title: string, message: string }> {
  try {
    const messages: MiniMaxMessage[] = [
      { role: 'system', content: NUDGE_SYSTEM_PROMPT },
      { role: 'user', content: `Nudge type: ${nudgeType}\nContext: ${context}` }
    ]
    const response = await callMiniMax(messages, { temperature: 0.8, maxTokens: 200, responseFormat: 'json_object' })
    return JSON.parse(response)
  } catch {
    // Fallback to static message
    return { title: 'Health Reminder', message: context }
  }
}

async function sendPushNotification(supabase: any, userId: string, nudge: any) {
  try {
    const { data: tokens } = await supabase
      .from('push_tokens')
      .select('device_token, platform')
      .eq('user_id', userId)
      .eq('is_active', true)

    if (!tokens?.length) return

    // APNs push would be sent here via the existing push infrastructure
    // For now, log it — actual APNs integration uses the hydration-reminder pattern
    console.log(`🔔 Push to ${userId}: ${nudge.title} - ${nudge.message}`)
  } catch (e) {
    console.log('🔔 Push failed:', e.message)
  }
}
