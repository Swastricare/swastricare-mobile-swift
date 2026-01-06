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

    const { message, conversationHistory } = await req.json()
    
    const authHeader = req.headers.get('Authorization')
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: authHeader ? { Authorization: authHeader } : {} } }
    )

    let userId = null
    if (authHeader) {
      try {
        const { data: { user } } = await supabase.auth.getUser()
        userId = user?.id
      } catch (e) {
        console.log('Auth failed')
      }
    }

    let fullPrompt = `You are a helpful health assistant. Provide accurate health guidance, be encouraging. Keep responses concise (2-4 sentences).\n\n`
    
    if (conversationHistory && conversationHistory.length > 0) {
      fullPrompt += "Previous:\n"
      conversationHistory.slice(-6).forEach((msg) => {
        fullPrompt += `${msg.role === 'user' ? 'User' : 'Assistant'}: ${msg.content}\n`
      })
      fullPrompt += "\n"
    }
    
    fullPrompt += `User: ${message}\n\nAssistant:`

    console.log('Calling Gemini...')
    const geminiResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=${GOOGLE_AI_API_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: fullPrompt }] }],
          generationConfig: { temperature: 0.8, maxOutputTokens: 512 }
        })
      }
    )

    if (!geminiResponse.ok) {
      const errorText = await geminiResponse.text()
      console.error('Gemini error:', errorText)
      throw new Error(`Gemini: ${geminiResponse.statusText}`)
    }

    const geminiData = await geminiResponse.json()
    const aiResponse = geminiData.candidates[0].content.parts[0].text.trim()
    console.log('Got response')

    if (userId) {
      try {
        await supabase.from('ai_conversations').insert({
          user_id: userId,
          message,
          response: aiResponse,
          context: { history: conversationHistory || [] }
        })
      } catch (e) {
        console.log('DB insert failed')
      }
    }

    return new Response(JSON.stringify({ response: aiResponse }), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  } catch (error) {
    console.error('Error:', error)
    return new Response(JSON.stringify({ 
      response: "I'm here to help with health questions! What would you like to know?"
    }), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
})
