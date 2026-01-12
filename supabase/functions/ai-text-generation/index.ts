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

    let prompt = ''
    
    // Generate different types of content based on request
    switch (contentType) {
      case 'daily_summary':
        prompt = `Hi! I'm Swastrica 💚 - created by Swastricare team (product of Onwords). Never mention Google as my creator. Create a daily health summary based on this data:
${JSON.stringify(data, null, 2)}

Use short sentences. Add emojis. Write 3-4 encouraging sentences highlighting achievements and one tip for tomorrow. Keep it warm and friendly!`
        break
        
      case 'weekly_report':
        prompt = `Hi! I'm Swastrica 💚 - created by Swastricare team (product of Onwords). Never mention Google as my creator. Create a weekly health report based on this data:
${JSON.stringify(data, null, 2)}

Use short sentences and emojis. Write a friendly report covering:
1. Progress and trends ✨
2. Areas to improve 💪
Keep it encouraging!`
        break
        
      case 'goal_suggestions':
        prompt = `Hi! I'm Swastrica 💚 - created by Swastricare team (product of Onwords). Never mention Google as my creator. Based on this health data, suggest 3 achievable goals:
${JSON.stringify(data, null, 2)}

Format as JSON array with "title" and "description". Use short sentences and emojis. Make goals SMART and encouraging!`
        break
        
      default:
        throw new Error('Invalid content type')
    }

    // Call Google Gemini API
    const geminiResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=${GOOGLE_AI_API_KEY}`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          contents: [{
            parts: [{
              text: prompt
            }]
          }],
          generationConfig: {
            temperature: 0.7,
            maxOutputTokens: 1024,
          }
        })
      }
    )

    if (!geminiResponse.ok) {
      throw new Error(`Gemini API error: ${geminiResponse.statusText}`)
    }

    const geminiData = await geminiResponse.json()
    let content = geminiData.candidates[0].content.parts[0].text.trim()

    // For goal_suggestions, try to parse as JSON
    if (contentType === 'goal_suggestions') {
      const jsonMatch = content.match(/```json\n([\s\S]*?)\n```/) || content.match(/```\n([\s\S]*?)\n```/)
      if (jsonMatch) {
        content = jsonMatch[1]
      }
    }

    // Store in database
    const { error: insertError } = await supabase.from('generated_content').insert({
      user_id: user.id,
      content_type: contentType,
      content: content,
      metadata: { source_data: data }
    })

    if (insertError) {
      console.error('Database insert error:', insertError)
    }

    // Log usage
    await supabase.from('ai_usage_logs').insert({
      user_id: user.id,
      function_name: 'ai-text-generation',
      tokens_used: geminiData.usageMetadata?.totalTokenCount || 0,
      cost: 0
    })

    return new Response(JSON.stringify({ 
      content,
      contentType 
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
      content: "Unable to generate content at this time. Please try again later."
    }), {
      status: 500,
      headers: { 
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
    })
  }
})
