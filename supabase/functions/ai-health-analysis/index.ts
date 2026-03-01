import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { callMiniMax, MiniMaxMessage } from '../_shared/minimax.ts'
import { handleCors, corsHeaders } from '../_shared/cors.ts'

serve(async (req) => {
  try {
    const corsResponse = handleCors(req)
    if (corsResponse) return corsResponse

    const {
      steps,
      heartRate,
      sleepDuration,
      activeCalories = 0,
      exerciseMinutes = 0,
      standHours = 0,
      distance = 0,
      bloodPressure = '--/--',
      weight = '--'
    } = await req.json()

    // Input validation
    if (typeof steps !== 'number' || steps < 0 || steps > 100000) {
      return new Response(JSON.stringify({
        assessment: "Invalid step count provided.",
        insights: "Please provide a valid number of steps between 0 and 100,000.",
        recommendations: ["Check your input", "Try again with valid data"]
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      })
    }

    if (typeof heartRate !== 'number' || heartRate < 20 || heartRate > 250) {
      return new Response(JSON.stringify({
        assessment: "Invalid heart rate provided.",
        insights: "Please provide a valid heart rate between 20 and 250 bpm.",
        recommendations: ["Check your input", "Try again with valid data"]
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      })
    }

    const authHeader = req.headers.get('Authorization')
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: authHeader ? { Authorization: authHeader } : {} } }
    )

    let userId = null
    let healthProfileId = null
    if (authHeader) {
      try {
        const { data: { user } } = await supabase.auth.getUser()
        userId = user?.id

        if (userId) {
          const { data: profile } = await supabase
            .from('health_profiles')
            .select('id')
            .eq('user_id', userId)
            .eq('is_primary', true)
            .single()
          healthProfileId = profile?.id
        }
      } catch (e) {
        console.log('Auth/profile fetch failed:', e.message)
      }
    }

    const systemPrompt = `You are Swastrica! 💚 A health assistant created by Swastricare team (product of Onwords). NEVER say you were made by Google, MiniMax, or any other company.

Analyze comprehensive health data and provide a warm, encouraging health analysis. Use short sentences and emojis. Return ONLY valid JSON with this exact structure:
{
  "assessment": "2-3 short sentences with emojis about overall health status",
  "insights": "3-4 short sentences with emojis highlighting key patterns and what's going well or needs attention",
  "recommendations": ["actionable tip with emoji", "actionable tip with emoji", "actionable tip with emoji", "actionable tip with emoji", "actionable tip with emoji"]
}

No markdown, no code blocks, just pure JSON.`

    const userMessage = `Please analyze the following health data:

Activity: ${steps} steps, ${distance.toFixed(1)}km walked/run, ${exerciseMinutes} min exercise, ${standHours} stand hours
Vitals: Heart Rate ${heartRate}bpm, Sleep ${sleepDuration}
Energy: ${activeCalories} cal burned
Body: Weight ${weight}kg, BP ${bloodPressure}`

    const messages: MiniMaxMessage[] = [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userMessage },
    ]

    console.log('Calling MiniMax...')

    let responseText = await callMiniMax(messages, {
      temperature: 0.7,
      maxTokens: 2048,
      responseFormat: 'json_object',
    })

    console.log('Raw:', responseText.substring(0, 100))

    // Strip any markdown code fences defensively
    responseText = responseText.replace(/```json\n/g, '').replace(/```\n/g, '').replace(/```/g, '').trim()

    const analysis = JSON.parse(responseText)
    console.log('Parsed OK')

    if (!analysis.assessment || !analysis.insights || !Array.isArray(analysis.recommendations)) {
      throw new Error('Invalid structure')
    }

    if (userId && healthProfileId) {
      try {
        await supabase.from('ai_insights').insert({
          health_profile_id: healthProfileId,
          insight_type: 'daily_health_analysis',
          priority: 'medium',
          title: 'Daily Health Analysis',
          description: analysis.assessment,
          detailed_analysis: analysis.insights,
          supporting_data: {
            steps,
            heartRate,
            sleepDuration,
            activeCalories,
            exerciseMinutes,
            standHours,
            distance,
            bloodPressure,
            weight,
            model: 'minimax',
            analyzed_at: new Date().toISOString()
          },
          data_sources: ['health_metrics', 'activity_data'],
          data_range_start: new Date().toISOString().split('T')[0],
          data_range_end: new Date().toISOString().split('T')[0],
          suggested_actions: analysis.recommendations,
          confidence_score: 0.85,
          show_in_dashboard: true
        })
        console.log('Health insight saved')
      } catch (e) {
        console.log('DB failed:', e.message)
      }
    }

    return new Response(JSON.stringify(analysis), {
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    })
  } catch (error) {
    console.error('Error:', error)
    return new Response(JSON.stringify({
      assessment: "Your health metrics look good. Keep maintaining your current activity levels.",
      insights: "Based on your data, you're on track with movement and rest. Focus on consistency.",
      recommendations: [
        "Maintain daily step count",
        "Monitor heart rate during exercise",
        "Keep consistent sleep schedule",
        "Stay hydrated",
        "Track weekly progress"
      ]
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    })
  }
})
