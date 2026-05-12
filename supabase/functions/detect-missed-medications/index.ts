// detect-missed-medications
// ----------------------------------------------------------------------------
// Cron-driven endpoint (every 5 minutes via pg_cron + pg_net). For every
// overdue medication dose detected by `detect_overdue_medications()`:
//   1. Insert a `medication_logs` row with status='missed' (idempotency-guarded
//      via the missed_alert_sent_at column and a +/-1h window in the RPC).
//   2. Look up caregivers (active family members with can_view=true).
//   3. For each caregiver whose `family_alert_preferences.missed_medication_alerts`
//      is true (default true), invoke `send-family-nudge` with is_critical=true.
//
// Auth: requires header `x-cron-secret: <CRON_SHARED_SECRET>`. Returns 403
// otherwise so this is not callable by unauthenticated mobile clients.
//
// Returns: { processed: number, fanouts: number }
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import { corsHeaders, handleCors } from '../_shared/cors.ts'

type OverdueRow = {
  schedule_id: string
  health_profile_id: string
  medication_id: string
  medication_name: string
  member_name: string
  expected_time: string
}

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  try {
    const cronSecret = Deno.env.get('CRON_SHARED_SECRET')
    const provided = req.headers.get('x-cron-secret')
    if (!cronSecret || provided !== cronSecret) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const admin = createClient(supabaseUrl, supabaseServiceKey)

    // Allow the cron body to override the grace window (optional).
    let graceMinutes = 30
    try {
      const bodyText = await req.text()
      if (bodyText && bodyText.trim().length > 0) {
        const parsed = JSON.parse(bodyText)
        if (typeof parsed?.grace_minutes === 'number') {
          graceMinutes = parsed.grace_minutes
        }
      }
    } catch (_e) {
      // No-op; default grace_minutes
    }

    // ----- 1. Detect overdue medications -----
    const { data: overdueData, error: overdueErr } = await admin.rpc(
      'detect_overdue_medications',
      { grace_minutes: graceMinutes },
    )
    if (overdueErr) {
      console.error('detect_overdue_medications RPC error:', overdueErr)
      return new Response(JSON.stringify({ error: 'RPC failed', details: overdueErr.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const overdue: OverdueRow[] = Array.isArray(overdueData) ? (overdueData as OverdueRow[]) : []
    let processed = 0
    let fanouts = 0

    for (const row of overdue) {
      // ----- 2. Insert a missed medication_logs row -----
      const { error: insertErr } = await admin
        .from('medication_logs')
        .insert({
          medication_id: row.medication_id,
          schedule_id: row.schedule_id,
          health_profile_id: row.health_profile_id,
          scheduled_time: row.expected_time,
          status: 'missed',
          missed_alert_sent_at: new Date().toISOString(),
          logged_by: 'system',
        })
      if (insertErr) {
        console.error('medication_logs insert error:', insertErr, 'row:', row)
        // Keep going — a duplicate insert (race) shouldn't stop the fanout.
      } else {
        processed += 1
      }

      // ----- 3. Look up caregivers for the affected health profile -----
      const { data: caregivers, error: cgErr } = await admin.rpc(
        'get_caregivers_for_profile',
        { profile_id: row.health_profile_id },
      )
      if (cgErr) {
        console.error('get_caregivers_for_profile RPC error:', cgErr, 'row:', row)
        continue
      }
      const caregiverIds: string[] = Array.isArray(caregivers)
        ? caregivers.map((c: { user_id: string }) => c.user_id).filter(Boolean)
        : []
      if (caregiverIds.length === 0) continue

      // ----- 4. For each caregiver, check alert prefs and fan out a nudge -----
      for (const caregiverId of caregiverIds) {
        const { data: prefRow, error: prefErr } = await admin
          .from('family_alert_preferences')
          .select('missed_medication_alerts')
          .eq('caregiver_user_id', caregiverId)
          .eq('target_health_profile_id', row.health_profile_id)
          .maybeSingle()
        if (prefErr) {
          console.error('alert_preferences lookup error:', prefErr)
        }
        // Default to true if no row exists (matches DEFAULT TRUE in schema).
        const allowed = prefRow ? prefRow.missed_medication_alerts !== false : true
        if (!allowed) continue

        const customMessage = `${row.member_name} missed their ${row.medication_name} dose.`
        try {
          const res = await fetch(`${supabaseUrl}/functions/v1/send-family-nudge`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${supabaseServiceKey}`,
              apikey: supabaseServiceKey,
            },
            body: JSON.stringify({
              recipient_user_id: caregiverId,
              target_health_profile_id: row.health_profile_id,
              category: 'MEDICATION_MISSED',
              preset_key: 'MEDICATION',
              custom_message: customMessage,
              is_critical: true,
              internal_caller: true,
            }),
          })
          if (!res.ok) {
            const txt = await res.text()
            console.error(`send-family-nudge fanout failed (${res.status}):`, txt)
          } else {
            fanouts += 1
          }
        } catch (e) {
          console.error('send-family-nudge fanout error:', e)
        }
      }
    }

    return new Response(JSON.stringify({ processed, fanouts }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (error) {
    console.error('detect-missed-medications error:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
