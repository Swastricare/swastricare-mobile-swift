import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const GOOGLE_AI_API_KEY = Deno.env.get('GOOGLE_AI_API_KEY')
const MAX_MESSAGE_LENGTH = 1000
const MAX_HISTORY_LENGTH = 10

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
    
    // Input validation
    if (!message || typeof message !== 'string') {
      return new Response(JSON.stringify({ 
        response: "Please provide a valid message."
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      })
    }

    if (message.length > MAX_MESSAGE_LENGTH) {
      return new Response(JSON.stringify({ 
        response: "Message is too long. Please keep it under 1000 characters."
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
    if (authHeader) {
      try {
        const { data: { user } } = await supabase.auth.getUser()
        userId = user?.id
      } catch (e) {
        console.log('Auth failed')
      }
    }

    let fullPrompt = `You are a helpful health assistant. Provide accurate health guidance, be encouraging. Keep responses concise (2-4 sentences).\n\n`
    
    if (conversationHistory && Array.isArray(conversationHistory) && conversationHistory.length > 0) {
      fullPrompt += "Previous:\n"
      conversationHistory.slice(-MAX_HISTORY_LENGTH).forEach((msg) => {
        if (msg.role && msg.content) {
          fullPrompt += `${msg.role === 'user' ? 'User' : 'Assistant'}: ${msg.content}\n`
        }
      })
      fullPrompt += "\n"
    }
    
    fullPrompt += `User: ${message}\n\nAssistant:`

    console.log('Calling Gemini...')
    
    // Add timeout to Gemini API call
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 30000) // 30 second timeout
    
    try {
      const geminiResponse = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=${GOOGLE_AI_API_KEY}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{ parts: [{ text: fullPrompt }] }],
            generationConfig: { temperature: 0.8, maxOutputTokens: 512 }
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
          console.log('DB insert failed:', e.message)
        }
      }

      return new Response(JSON.stringify({ response: aiResponse }), {
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
      response: "I'm having trouble right now. Please try again in a moment."
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
})
