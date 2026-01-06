import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const GOOGLE_AI_API_KEY = Deno.env.get('GOOGLE_AI_API_KEY')

serve(async (req) => {
  try {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        },
      })
    }

    const { imageData, analysisType } = await req.json()
    
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

    let prompt = ''
    
    switch (analysisType) {
      case 'meal':
        prompt = 'Analyze this meal image. Identify the foods, estimate calories, and provide nutritional insights. Be specific about portion sizes and macro nutrients.'
        break
      case 'workout':
        prompt = 'Analyze this workout or exercise image. Identify the activity, suggest form improvements if visible, and provide encouragement.'
        break
      case 'supplement':
        prompt = 'Analyze this supplement or medication image. Identify what you can see and provide general wellness information. Always remind to consult healthcare providers.'
        break
      default:
        prompt = 'Analyze this health-related image and provide relevant insights.'
    }

    // Call Google Gemini Vision API
    const geminiResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GOOGLE_AI_API_KEY}`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          contents: [{
            parts: [
              {
                text: prompt
              },
              {
                inline_data: {
                  mime_type: "image/jpeg",
                  data: imageData // base64 encoded image
                }
              }
            ]
          }],
          generationConfig: {
            temperature: 0.7,
            maxOutputTokens: 1024,
          }
        })
      }
    )

    if (!geminiResponse.ok) {
      const errorText = await geminiResponse.text()
      throw new Error(`Gemini API error: ${geminiResponse.statusText} - ${errorText}`)
    }

    const geminiData = await geminiResponse.json()
    const analysis = geminiData.candidates[0].content.parts[0].text.trim()

    // Store in database
    const { error: insertError } = await supabase.from('image_analysis').insert({
      user_id: user.id,
      image_url: null, // Could store in Supabase Storage if needed
      analysis_type: analysisType,
      results: { analysis, timestamp: new Date().toISOString() }
    })

    if (insertError) {
      console.error('Database insert error:', insertError)
    }

    // Log usage
    await supabase.from('ai_usage_logs').insert({
      user_id: user.id,
      function_name: 'ai-image-analysis',
      tokens_used: geminiData.usageMetadata?.totalTokenCount || 0,
      cost: 0
    })

    return new Response(JSON.stringify({ 
      analysis,
      analysisType 
    }), {
      headers: { 
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    })
  } catch (error) {
    console.error('Error:', error)
    return new Response(JSON.stringify({ 
      error: error.message,
      analysis: "Unable to analyze image at this time. Please ensure the image is clear and try again."
    }), {
      status: 500,
      headers: { 
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    })
  }
})
