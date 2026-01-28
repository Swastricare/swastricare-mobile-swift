import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface RunActivity {
  id?: string
  external_id?: string
  source: string
  activity_type: string
  activity_name?: string
  started_at: string
  ended_at: string
  duration_seconds: number
  distance_meters: number
  steps: number
  calories_burned: number
  avg_heart_rate?: number
  max_heart_rate?: number
  min_heart_rate?: number
  avg_pace_seconds_per_km?: number
  route_coordinates?: { lat: number; lng: number; alt?: number; ts?: string }[]
  start_latitude?: number
  start_longitude?: number
  end_latitude?: number
  end_longitude?: number
  notes?: string
  tags?: string[]
}

interface ActivitySummaryRequest {
  start_date: string
  end_date: string
}

interface ActivityGoals {
  daily_steps_goal: number
  daily_distance_meters: number
  daily_calories_goal: number
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    const url = new URL(req.url)
    const pathParts = url.pathname.split('/').filter(Boolean)
    const action = pathParts[pathParts.length - 1] || ''

    // Initialize Supabase client
    const authHeader = req.headers.get('Authorization')
    const apikey = req.headers.get('apikey') || (Deno.env.get('SUPABASE_ANON_KEY') ?? '')
    
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Authorization required' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { 
        global: { 
          headers: { 
            Authorization: authHeader,
            apikey: apikey
          } 
        } 
      }
    )

    // Get authenticated user
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      console.error('Auth error:', authError?.message || 'No user found', 'Header present:', !!authHeader)
      return new Response(JSON.stringify({ 
        error: 'Invalid authentication',
        details: authError?.message || 'User not found'
      }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Get user's health profile
    const { data: profile, error: profileError } = await supabase
      .from('health_profiles')
      .select('id')
      .eq('user_id', user.id)
      .eq('is_primary', true)
      .single()

    if (profileError || !profile) {
      return new Response(JSON.stringify({ error: 'Health profile not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const healthProfileId = profile.id

    // Route handlers
    switch (req.method) {
      case 'GET':
        return await handleGet(supabase, healthProfileId, url, action)
      case 'POST':
        return await handlePost(supabase, healthProfileId, await req.json(), action)
      case 'PUT':
        return await handlePut(supabase, healthProfileId, await req.json(), url)
      case 'DELETE':
        return await handleDelete(supabase, healthProfileId, url)
      default:
        return new Response(JSON.stringify({ error: 'Method not allowed' }), {
          status: 405,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
    }
  } catch (error) {
    console.error('Error:', error)
    return new Response(JSON.stringify({ error: 'Internal server error', details: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})

// GET handlers
async function handleGet(supabase: any, healthProfileId: string, url: URL, action: string) {
  const params = url.searchParams

  switch (action) {
    case 'activities':
      return await getActivities(supabase, healthProfileId, params)
    case 'summary':
      return await getDailySummary(supabase, healthProfileId, params)
    case 'weekly-comparison':
      return await getWeeklyComparison(supabase, healthProfileId)
    case 'goals':
      return await getGoals(supabase, healthProfileId)
    case 'stats':
      return await getStats(supabase, healthProfileId, params)
    default:
      // Get single activity by ID
      const activityId = action
      if (activityId && activityId !== 'run-activities') {
        return await getActivityById(supabase, healthProfileId, activityId)
      }
      return await getActivities(supabase, healthProfileId, params)
  }
}

async function getActivities(supabase: any, healthProfileId: string, params: URLSearchParams) {
  const startDate = params.get('start_date')
  const endDate = params.get('end_date')
  const activityType = params.get('type')
  const limit = parseInt(params.get('limit') || '50')
  const offset = parseInt(params.get('offset') || '0')

  let query = supabase
    .from('run_activities')
    .select('*')
    .eq('health_profile_id', healthProfileId)
    .is('deleted_at', null)
    .order('started_at', { ascending: false })
    .range(offset, offset + limit - 1)

  if (startDate) {
    query = query.gte('started_at', startDate)
  }
  if (endDate) {
    query = query.lte('started_at', endDate)
  }
  if (activityType) {
    query = query.eq('activity_type', activityType)
  }

  const { data, error } = await query

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  return new Response(JSON.stringify({ activities: data }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

async function getActivityById(supabase: any, healthProfileId: string, activityId: string) {
  const { data, error } = await supabase
    .from('run_activities')
    .select('*')
    .eq('health_profile_id', healthProfileId)
    .eq('id', activityId)
    .is('deleted_at', null)
    .single()

  if (error) {
    return new Response(JSON.stringify({ error: 'Activity not found' }), {
      status: 404,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  return new Response(JSON.stringify({ activity: data }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

async function getDailySummary(supabase: any, healthProfileId: string, params: URLSearchParams) {
  const startDate = params.get('start_date') || new Date(Date.now() - 14 * 24 * 60 * 60 * 1000).toISOString().split('T')[0]
  const endDate = params.get('end_date') || new Date().toISOString().split('T')[0]

  const { data, error } = await supabase
    .from('daily_activity_summaries')
    .select('*')
    .eq('health_profile_id', healthProfileId)
    .gte('summary_date', startDate)
    .lte('summary_date', endDate)
    .order('summary_date', { ascending: false })

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  // Calculate totals for the period
  const totals = {
    total_steps: data.reduce((sum: number, d: any) => sum + (d.total_steps || 0), 0),
    total_distance_meters: data.reduce((sum: number, d: any) => sum + parseFloat(d.total_distance_meters || 0), 0),
    total_calories: data.reduce((sum: number, d: any) => sum + (d.total_calories || 0), 0),
    total_points: data.reduce((sum: number, d: any) => sum + (d.total_points || 0), 0),
    active_days: data.filter((d: any) => d.total_steps > 0).length,
    avg_daily_steps: 0,
    avg_daily_distance: 0,
  }

  const activeDays = totals.active_days || 1
  totals.avg_daily_steps = Math.round(totals.total_steps / activeDays)
  totals.avg_daily_distance = totals.total_distance_meters / activeDays

  return new Response(JSON.stringify({ summaries: data, totals }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

async function getWeeklyComparison(supabase: any, healthProfileId: string) {
  const { data, error } = await supabase
    .from('weekly_activity_comparison')
    .select('*')
    .eq('health_profile_id', healthProfileId)
    .order('week_start', { ascending: false })
    .limit(4)

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  // Calculate percentage changes
  let comparison = null
  if (data && data.length >= 2) {
    const currentWeek = data[0]
    const previousWeek = data[1]

    const prevAvgDist = parseFloat(previousWeek.avg_daily_distance || 0)
    const currAvgDist = parseFloat(currentWeek.avg_daily_distance || 0)
    
    const percentageChange = prevAvgDist > 0 
      ? ((currAvgDist - prevAvgDist) / prevAvgDist) * 100 
      : 0

    comparison = {
      current_week: {
        week_start: currentWeek.week_start,
        avg_daily_distance_km: currAvgDist / 1000,
        total_steps: parseInt(currentWeek.total_steps),
        active_days: parseInt(currentWeek.active_days),
      },
      previous_week: {
        week_start: previousWeek.week_start,
        avg_daily_distance_km: prevAvgDist / 1000,
        total_steps: parseInt(previousWeek.total_steps),
        active_days: parseInt(previousWeek.active_days),
      },
      percentage_change: Math.round(percentageChange * 10) / 10,
      trend: percentageChange >= 0 ? 'increase' : 'decrease',
    }
  }

  return new Response(JSON.stringify({ weeks: data, comparison }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

async function getGoals(supabase: any, healthProfileId: string) {
  const { data, error } = await supabase
    .from('activity_goals')
    .select('*')
    .eq('health_profile_id', healthProfileId)
    .single()

  if (error && error.code !== 'PGRST116') {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  // Return default goals if none set
  const goals = data || {
    daily_steps_goal: 10000,
    daily_distance_meters: 8000,
    daily_calories_goal: 500,
    daily_active_minutes: 30,
    weekly_steps_goal: 70000,
    weekly_distance_meters: 50000,
    current_steps_streak: 0,
    longest_steps_streak: 0,
    level: 1,
    total_xp: 0,
  }

  return new Response(JSON.stringify({ goals }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

async function getStats(supabase: any, healthProfileId: string, params: URLSearchParams) {
  const days = parseInt(params.get('days') || '14')
  const startDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString()

  // Get today's stats
  const today = new Date().toISOString().split('T')[0]
  const { data: todayData } = await supabase
    .from('daily_activity_summaries')
    .select('*')
    .eq('health_profile_id', healthProfileId)
    .eq('summary_date', today)
    .single()

  // Get yesterday's stats
  const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().split('T')[0]
  const { data: yesterdayData } = await supabase
    .from('daily_activity_summaries')
    .select('*')
    .eq('health_profile_id', healthProfileId)
    .eq('summary_date', yesterday)
    .single()

  // Get period stats
  const { data: periodData } = await supabase
    .from('daily_activity_summaries')
    .select('*')
    .eq('health_profile_id', healthProfileId)
    .gte('summary_date', startDate.split('T')[0])

  const periodTotals = periodData?.reduce((acc: any, day: any) => ({
    steps: acc.steps + (day.total_steps || 0),
    distance: acc.distance + parseFloat(day.total_distance_meters || 0),
    calories: acc.calories + (day.total_calories || 0),
    points: acc.points + (day.total_points || 0),
  }), { steps: 0, distance: 0, calories: 0, points: 0 }) || { steps: 0, distance: 0, calories: 0, points: 0 }

  // Calculate percentage change
  const prevPeriodStart = new Date(Date.now() - days * 2 * 24 * 60 * 60 * 1000).toISOString().split('T')[0]
  const prevPeriodEnd = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString().split('T')[0]
  
  const { data: prevPeriodData } = await supabase
    .from('daily_activity_summaries')
    .select('*')
    .eq('health_profile_id', healthProfileId)
    .gte('summary_date', prevPeriodStart)
    .lt('summary_date', prevPeriodEnd)

  const prevPeriodTotals = prevPeriodData?.reduce((acc: any, day: any) => ({
    distance: acc.distance + parseFloat(day.total_distance_meters || 0),
  }), { distance: 0 }) || { distance: 0 }

  const percentageChange = prevPeriodTotals.distance > 0
    ? ((periodTotals.distance - prevPeriodTotals.distance) / prevPeriodTotals.distance) * 100
    : 0

  return new Response(JSON.stringify({
    today: {
      steps: todayData?.total_steps || 0,
      distance_km: (todayData?.total_distance_meters || 0) / 1000,
      calories: todayData?.total_calories || 0,
      points: todayData?.total_points || 0,
    },
    yesterday: {
      distance_km: (yesterdayData?.total_distance_meters || 0) / 1000,
    },
    period: {
      days,
      total_steps: periodTotals.steps,
      total_distance_km: periodTotals.distance / 1000,
      total_calories: periodTotals.calories,
      total_points: periodTotals.points,
      percentage_change: Math.round(percentageChange),
    },
  }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

// POST handlers
async function handlePost(supabase: any, healthProfileId: string, body: any, action: string) {
  switch (action) {
    case 'sync':
      return await syncActivities(supabase, healthProfileId, body)
    case 'goals':
      return await upsertGoals(supabase, healthProfileId, body)
    default:
      return await createActivity(supabase, healthProfileId, body)
  }
}

async function createActivity(supabase: any, healthProfileId: string, activity: RunActivity) {
  // Calculate points
  const points = calculatePoints(activity.steps, activity.distance_meters, activity.calories_burned)

  const { data, error } = await supabase
    .from('run_activities')
    .insert({
      health_profile_id: healthProfileId,
      external_id: activity.external_id,
      source: activity.source || 'app',
      activity_type: activity.activity_type,
      activity_name: activity.activity_name,
      started_at: activity.started_at,
      ended_at: activity.ended_at,
      duration_seconds: activity.duration_seconds,
      distance_meters: activity.distance_meters,
      steps: activity.steps,
      calories_burned: activity.calories_burned,
      points_earned: points,
      avg_heart_rate: activity.avg_heart_rate,
      max_heart_rate: activity.max_heart_rate,
      min_heart_rate: activity.min_heart_rate,
      avg_pace_seconds_per_km: activity.avg_pace_seconds_per_km,
      route_coordinates: activity.route_coordinates || [],
      start_latitude: activity.start_latitude,
      start_longitude: activity.start_longitude,
      end_latitude: activity.end_latitude,
      end_longitude: activity.end_longitude,
      notes: activity.notes,
      tags: activity.tags,
    })
    .select()
    .single()

  if (error) {
    // Handle duplicate
    if (error.code === '23505') {
      return new Response(JSON.stringify({ error: 'Activity already exists', duplicate: true }), {
        status: 409,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  return new Response(JSON.stringify({ activity: data }), {
    status: 201,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

async function syncActivities(supabase: any, healthProfileId: string, body: { activities: RunActivity[] }) {
  const { activities } = body
  const results = { synced: 0, duplicates: 0, errors: [] as string[] }

  for (const activity of activities) {
    const points = calculatePoints(activity.steps, activity.distance_meters, activity.calories_burned)

    const { error } = await supabase
      .from('run_activities')
      .upsert({
        health_profile_id: healthProfileId,
        external_id: activity.external_id,
        source: activity.source,
        activity_type: activity.activity_type,
        activity_name: activity.activity_name,
        started_at: activity.started_at,
        ended_at: activity.ended_at,
        duration_seconds: activity.duration_seconds,
        distance_meters: activity.distance_meters,
        steps: activity.steps,
        calories_burned: activity.calories_burned,
        points_earned: points,
        avg_heart_rate: activity.avg_heart_rate,
        max_heart_rate: activity.max_heart_rate,
        min_heart_rate: activity.min_heart_rate,
        route_coordinates: activity.route_coordinates || [],
        start_latitude: activity.start_latitude,
        start_longitude: activity.start_longitude,
        end_latitude: activity.end_latitude,
        end_longitude: activity.end_longitude,
        synced_to_healthkit: true,
        synced_at: new Date().toISOString(),
      }, {
        onConflict: 'health_profile_id,external_id,source',
        ignoreDuplicates: false,
      })

    if (error) {
      if (error.code === '23505') {
        results.duplicates++
      } else {
        results.errors.push(error.message)
      }
    } else {
      results.synced++
    }
  }

  return new Response(JSON.stringify({ results }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

async function upsertGoals(supabase: any, healthProfileId: string, goals: ActivityGoals) {
  const { data, error } = await supabase
    .from('activity_goals')
    .upsert({
      health_profile_id: healthProfileId,
      daily_steps_goal: goals.daily_steps_goal,
      daily_distance_meters: goals.daily_distance_meters,
      daily_calories_goal: goals.daily_calories_goal,
    }, {
      onConflict: 'health_profile_id',
    })
    .select()
    .single()

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  return new Response(JSON.stringify({ goals: data }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

// PUT handler
async function handlePut(supabase: any, healthProfileId: string, body: any, url: URL) {
  const activityId = url.searchParams.get('id')
  if (!activityId) {
    return new Response(JSON.stringify({ error: 'Activity ID required' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  const { data, error } = await supabase
    .from('run_activities')
    .update({
      activity_name: body.activity_name,
      notes: body.notes,
      tags: body.tags,
      updated_at: new Date().toISOString(),
    })
    .eq('health_profile_id', healthProfileId)
    .eq('id', activityId)
    .select()
    .single()

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  return new Response(JSON.stringify({ activity: data }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

// DELETE handler (soft delete)
async function handleDelete(supabase: any, healthProfileId: string, url: URL) {
  const activityId = url.searchParams.get('id')
  if (!activityId) {
    return new Response(JSON.stringify({ error: 'Activity ID required' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  const { error } = await supabase
    .from('run_activities')
    .update({ deleted_at: new Date().toISOString() })
    .eq('health_profile_id', healthProfileId)
    .eq('id', activityId)

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  return new Response(JSON.stringify({ success: true }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

// Helper function to calculate points
function calculatePoints(steps: number, distanceMeters: number, calories: number): number {
  const pointsPerThousandSteps = 10
  const pointsPerKm = 20
  const pointsPerCalorie = 0.1

  return Math.round(
    (steps / 1000 * pointsPerThousandSteps) +
    (distanceMeters / 1000 * pointsPerKm) +
    (calories * pointsPerCalorie)
  )
}
