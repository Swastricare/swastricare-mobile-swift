// send-family-nudge
// ----------------------------------------------------------------------------
// Inserts a row into ai_nudges for the recipient, then (if outside the
// recipient's quiet hours) pushes via FCM HTTP v1 to all of the recipient's
// device tokens.
//
// Request body:
//   {
//     recipient_user_id: UUID,                 // required
//     target_health_profile_id?: UUID,         // optional context (e.g. who the nudge is about)
//     preset_key?: 'MEDICATION'|'HYDRATION'|'VITALS'|'APPOINTMENT'|'CHECKIN'|...,
//     custom_message?: string,                 // overrides preset body if provided
//     category: string,                        // free-form nudge_type (e.g. 'MEDICATION', 'MEDICATION_MISSED')
//     is_critical?: boolean,                   // critical nudges bypass quiet hours
//     internal_caller?: boolean                // true when called by another edge function (skip auth/share check)
//   }
//
// Response:
//   { delivered: boolean, nudge_id?: string, reason?: string, results?: any[] }
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import { corsHeaders, handleCors } from '../_shared/cors.ts'

// ---------------------------------------------------------------------------
// Preset templates
// ---------------------------------------------------------------------------
type Preset = { title: string; body: string }
const PRESETS: Record<string, Preset> = {
  MEDICATION: {
    title: '💊 Time for your medication',
    body: 'Your family is reminding you to take your medication.',
  },
  HYDRATION: {
    title: '💧 Drink water',
    body: 'Stay hydrated — your family is checking in.',
  },
  VITALS: {
    title: '🩺 Log your vitals',
    body: 'Take a moment to log your vitals.',
  },
  APPOINTMENT: {
    title: '📅 Upcoming appointment',
    body: "Don't miss your appointment.",
  },
  CHECKIN: {
    title: '❤️ Just checking in',
    body: 'Your family is thinking of you.',
  },
}

function resolveTitleAndBody(
  presetKey: string | undefined,
  customMessage: string | undefined,
): { title: string; body: string } {
  const preset = presetKey ? PRESETS[presetKey] : undefined
  if (preset && customMessage) {
    return { title: preset.title, body: customMessage }
  }
  if (preset) return preset
  if (customMessage) {
    return { title: 'Swastricare', body: customMessage }
  }
  return { title: 'Swastricare', body: 'Your family sent you a nudge.' }
}

// ---------------------------------------------------------------------------
// Quiet hours
// ---------------------------------------------------------------------------
// Parses 'HH:MM:SS' or 'HH:MM' into minutes-since-midnight (UTC clock from now()).
function parseTimeToMinutes(t: string | null | undefined): number | null {
  if (!t) return null
  const parts = t.split(':')
  if (parts.length < 2) return null
  const h = parseInt(parts[0], 10)
  const m = parseInt(parts[1], 10)
  if (Number.isNaN(h) || Number.isNaN(m)) return null
  return h * 60 + m
}

// Returns true if "now" falls inside [start, end). Handles overnight ranges
// where start > end (e.g. 22:00 → 07:00).
function isWithinQuietHours(startMin: number, endMin: number, nowMin: number): boolean {
  if (startMin === endMin) return false // zero-length window
  if (startMin < endMin) {
    return nowMin >= startMin && nowMin < endMin
  }
  // Overnight: inside if now >= start OR now < end
  return nowMin >= startMin || nowMin < endMin
}

// ---------------------------------------------------------------------------
// FCM OAuth (HTTP v1)
// ---------------------------------------------------------------------------
// Service account JSON is provided base64-encoded in FCM_SERVICE_ACCOUNT_JSON.
// We mint a short-lived OAuth access token via JWT bearer flow and cache it
// in module scope for the lifetime of this isolate.
type ServiceAccount = {
  client_email: string
  private_key: string
  token_uri: string
}

let cachedAccessToken: { token: string; expiresAt: number } | null = null

function base64UrlEncode(bytes: Uint8Array): string {
  let s = btoa(String.fromCharCode(...bytes))
  return s.replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_')
}

function base64UrlEncodeString(s: string): string {
  return base64UrlEncode(new TextEncoder().encode(s))
}

function pemToDer(pem: string): Uint8Array {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s+/g, '')
  const bin = atob(b64)
  const out = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i)
  return out
}

async function getFcmAccessToken(serviceAccount: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  if (cachedAccessToken && cachedAccessToken.expiresAt > now + 60) {
    return cachedAccessToken.token
  }

  const header = { alg: 'RS256', typ: 'JWT' }
  const claim = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: serviceAccount.token_uri,
    iat: now,
    exp: now + 3600,
  }

  const headerSegment = base64UrlEncodeString(JSON.stringify(header))
  const claimSegment = base64UrlEncodeString(JSON.stringify(claim))
  const signingInput = `${headerSegment}.${claimSegment}`

  const keyData = pemToDer(serviceAccount.private_key)
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    keyData,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const signatureBytes = new Uint8Array(
    await crypto.subtle.sign('RSASSA-PKCS1-v1_5', cryptoKey, new TextEncoder().encode(signingInput)),
  )
  const signature = base64UrlEncode(signatureBytes)
  const assertion = `${signingInput}.${signature}`

  const params = new URLSearchParams()
  params.set('grant_type', 'urn:ietf:params:oauth:grant-type:jwt-bearer')
  params.set('assertion', assertion)

  const res = await fetch(serviceAccount.token_uri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: params.toString(),
  })
  if (!res.ok) {
    const txt = await res.text()
    throw new Error(`FCM token mint failed: ${res.status} ${txt}`)
  }
  const data = await res.json()
  const expiresIn = typeof data.expires_in === 'number' ? data.expires_in : 3600
  cachedAccessToken = {
    token: data.access_token,
    expiresAt: now + expiresIn,
  }
  return cachedAccessToken.token
}

function loadServiceAccount(): ServiceAccount {
  const b64 = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON')
  if (!b64) throw new Error('FCM_SERVICE_ACCOUNT_JSON env var not set')
  let jsonText: string
  try {
    jsonText = atob(b64)
  } catch (_e) {
    // Allow raw JSON fallback (some deploys may set the raw JSON instead of base64).
    jsonText = b64
  }
  const parsed = JSON.parse(jsonText)
  if (!parsed.client_email || !parsed.private_key) {
    throw new Error('FCM_SERVICE_ACCOUNT_JSON missing client_email or private_key')
  }
  return {
    client_email: parsed.client_email,
    private_key: parsed.private_key,
    token_uri: parsed.token_uri || 'https://oauth2.googleapis.com/token',
  }
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------
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
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    const body = await req.json().catch(() => ({}))
    const {
      recipient_user_id,
      target_health_profile_id,
      preset_key,
      custom_message,
      category,
      is_critical,
      internal_caller,
    } = body ?? {}

    if (!recipient_user_id || typeof recipient_user_id !== 'string') {
      return new Response(JSON.stringify({ error: 'recipient_user_id required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    if (!category || typeof category !== 'string') {
      return new Response(JSON.stringify({ error: 'category required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // ----- Auth + share check (skipped for internal callers) -----
    let senderUserId: string | null = null
    if (!internal_caller) {
      const authHeader = req.headers.get('Authorization')
      if (!authHeader) {
        return new Response(JSON.stringify({ error: 'Authorization required' }), {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }
      const userClient = createClient(supabaseUrl, supabaseAnonKey, {
        global: { headers: { Authorization: authHeader } },
      })
      const { data: { user }, error: authError } = await userClient.auth.getUser()
      if (authError || !user) {
        return new Response(JSON.stringify({ error: 'Invalid authentication' }), {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }
      senderUserId = user.id

      // A caller may legitimately send themselves a nudge (e.g. self-reminder),
      // so only require share-family when sender != recipient.
      if (senderUserId !== recipient_user_id) {
        const { data: shareData, error: shareErr } = await userClient.rpc('users_share_family', {
          user_a: senderUserId,
          user_b: recipient_user_id,
        })
        if (shareErr) {
          console.error('users_share_family RPC error:', shareErr)
          return new Response(JSON.stringify({ error: 'Family check failed' }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          })
        }
        if (!shareData) {
          return new Response(JSON.stringify({ error: 'Not in the same family group' }), {
            status: 403,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          })
        }
      }
    }

    // Admin client for all subsequent DB ops.
    const admin = createClient(supabaseUrl, supabaseServiceKey)

    // ----- Resolve title/body -----
    const { title, body: messageBody } = resolveTitleAndBody(preset_key, custom_message)

    // ----- Resolve recipient's primary health_profile_id -----
    // (ai_nudges.health_profile_id is a NOT-NULL-ish FK; pick the recipient's
    // primary profile so the row is anchored to a valid profile.)
    let recipientPrimaryProfileId: string | null = null
    {
      const { data: hp, error: hpErr } = await admin
        .from('health_profiles')
        .select('id, is_primary, created_at')
        .eq('user_id', recipient_user_id)
        .order('is_primary', { ascending: false })
        .order('created_at', { ascending: true })
        .limit(1)
        .maybeSingle()
      if (hpErr) {
        console.error('Resolve recipient primary profile error:', hpErr)
      }
      recipientPrimaryProfileId = hp?.id ?? null
    }

    if (!recipientPrimaryProfileId) {
      return new Response(JSON.stringify({ error: 'Recipient has no health profile' }), {
        status: 422,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // ----- Insert the nudge row -----
    const priority = is_critical ? 'high' : 'medium'
    const sourceData: Record<string, unknown> = {}
    if (target_health_profile_id) sourceData.target_health_profile_id = target_health_profile_id
    if (senderUserId) sourceData.sender_user_id = senderUserId

    const { data: inserted, error: insertErr } = await admin
      .from('ai_nudges')
      .insert({
        health_profile_id: recipientPrimaryProfileId,
        user_id: recipient_user_id, // owner column = recipient (cross-user nudge convention)
        nudge_type: category,
        title,
        message: messageBody,
        priority,
        sender_user_id: senderUserId,
        recipient_user_id,
        preset_key: preset_key ?? null,
        is_critical: !!is_critical,
        source_data: sourceData,
        push_sent: false,
      })
      .select('id')
      .single()

    if (insertErr || !inserted) {
      console.error('ai_nudges insert error:', insertErr)
      return new Response(JSON.stringify({ error: 'Failed to insert nudge', details: insertErr?.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const nudgeId: string = inserted.id
    const deepLink = `swastricareapp://nudge/${nudgeId}`

    // Patch the action_deeplink with the real id (best-effort).
    await admin
      .from('ai_nudges')
      .update({ action_deeplink: deepLink })
      .eq('id', nudgeId)

    // ----- Quiet hours check (non-critical only) -----
    if (!is_critical) {
      const { data: prefRow, error: prefErr } = await admin
        .from('family_alert_preferences')
        .select('quiet_hours_start, quiet_hours_end')
        .eq('caregiver_user_id', recipient_user_id)
        .not('quiet_hours_start', 'is', null)
        .not('quiet_hours_end', 'is', null)
        .limit(1)
        .maybeSingle()
      if (prefErr) {
        console.error('quiet_hours lookup error:', prefErr)
      }
      const startMin = parseTimeToMinutes(prefRow?.quiet_hours_start)
      const endMin = parseTimeToMinutes(prefRow?.quiet_hours_end)
      if (startMin !== null && endMin !== null) {
        const nowD = new Date()
        const nowMin = nowD.getUTCHours() * 60 + nowD.getUTCMinutes()
        if (isWithinQuietHours(startMin, endMin, nowMin)) {
          return new Response(
            JSON.stringify({ delivered: false, reason: 'quiet_hours', nudge_id: nudgeId }),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
          )
        }
      }
    }

    // ----- Look up FCM tokens for recipient -----
    const { data: tokenRows, error: tokensErr } = await admin
      .from('device_tokens')
      .select('id, fcm_token')
      .eq('user_id', recipient_user_id)
    if (tokensErr) {
      console.error('device_tokens lookup error:', tokensErr)
      return new Response(JSON.stringify({ error: 'Failed to look up device tokens' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    if (!tokenRows || tokenRows.length === 0) {
      return new Response(
        JSON.stringify({ delivered: false, reason: 'no_tokens', nudge_id: nudgeId }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    // ----- Send to FCM -----
    const projectId = Deno.env.get('FCM_PROJECT_ID')
    if (!projectId) {
      console.error('FCM_PROJECT_ID env var not set')
      return new Response(JSON.stringify({ error: 'FCM not configured' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    let accessToken: string
    try {
      accessToken = await getFcmAccessToken(loadServiceAccount())
    } catch (e) {
      console.error('FCM access token error:', e)
      return new Response(JSON.stringify({ error: 'FCM auth failed', details: String(e) }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`
    const androidPriority = is_critical ? 'HIGH' : 'NORMAL'

    const results: Array<{ token: string; ok: boolean; status: number; error?: string }> = []
    let anyOk = false
    for (const row of tokenRows) {
      const token = row.fcm_token as string
      const payload = {
        message: {
          token,
          notification: { title, body: messageBody },
          data: {
            nudge_id: nudgeId,
            category,
            deep_link: deepLink,
          },
          android: { priority: androidPriority },
        },
      }
      try {
        const res = await fetch(fcmUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify(payload),
        })
        if (res.ok) {
          anyOk = true
          results.push({ token, ok: true, status: res.status })
        } else {
          const errText = await res.text()
          results.push({ token, ok: false, status: res.status, error: errText })
          // Stale token cleanup on 404 / 400 (UNREGISTERED / INVALID_ARGUMENT).
          if (res.status === 404 || res.status === 400) {
            await admin.from('device_tokens').delete().eq('id', row.id)
          }
        }
      } catch (e) {
        results.push({ token, ok: false, status: 0, error: String(e) })
      }
    }

    if (anyOk) {
      await admin.from('ai_nudges').update({ push_sent: true }).eq('id', nudgeId)
    }

    return new Response(
      JSON.stringify({ delivered: anyOk, nudge_id: nudgeId, results }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (error) {
    console.error('send-family-nudge error:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
