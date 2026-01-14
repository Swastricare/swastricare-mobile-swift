import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const GOOGLE_AI_API_KEY = Deno.env.get('GOOGLE_AI_API_KEY')

serve(async (req) => {
  try {
    if (req.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        },
      })
    }

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

    const prompt = `You are Swastrica! 💚 A health assistant created by Swastricare team (product of Onwords). NEVER say you were made by Google or any other company.

Analyze comprehensive health data:

Activity: ${steps} steps, ${distance.toFixed(1)}km walked/run, ${exerciseMinutes} min exercise, ${standHours} stand hours
Vitals: Heart Rate ${heartRate}bpm, Sleep ${sleepDuration}
Energy: ${activeCalories} cal burned
Body: Weight ${weight}kg, BP ${bloodPressure}

Provide a warm, encouraging health analysis. Use short sentences and emojis. Return ONLY valid JSON:
{
  "assessment": "2-3 short sentences with emojis about overall health status",
  "insights": "3-4 short sentences with emojis highlighting key patterns and what's going well or needs attention",
  "recommendations": ["actionable tip with emoji", "actionable tip with emoji", "actionable tip with emoji", "actionable tip with emoji", "actionable tip with emoji"]
}

No markdown, no code blocks, just pure JSON.`

    console.log('Calling Gemini...')
    
    // Add timeout
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 60000) // Increased from 30s to 60s
    
    try {
      const geminiResponse = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=${GOOGLE_AI_API_KEY}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: {
              temperature: 0.7,
              maxOutputTokens: 2048, // Increased from 1024
              responseMimeType: "application/json"
            }
          }),
          signal: controller.signal
        }
      )
      clearTimeout(timeoutId)

      if (!geminiResponse.ok) {
        const errorText = await geminiResponse.text()
        console.error('Gemini error:', errorText)
        throw new Error(`Gemini: ${geminiResponse.statusText}`)
      }

      const geminiData = await geminiResponse.json()
      
      if (!geminiData.candidates || !geminiData.candidates[0]) {
        throw new Error('No response from Gemini')
      }
      
      let responseText = geminiData.candidates[0].content.parts[0].text.trim()
      console.log('Raw:', responseText.substring(0, 100))

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
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      })
    } catch (fetchError) {
      clearTimeout(timeoutId)
      if (fetchError.name === 'AbortError') {
        throw new Error('Request timeout')
      }
      throw fetchError
    }
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
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
})
