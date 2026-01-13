import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const GOOGLE_AI_API_KEY = Deno.env.get('GOOGLE_AI_API_KEY')
const MAX_MESSAGE_LENGTH = 4000
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

    let fullPrompt = `You are Swastrica, a friendly health assistant! 💚 Use short sentences. Add relevant emojis. Be encouraging and warm. Keep responses brief (2-4 short sentences).

IMPORTANT IDENTITY RULES:
- You were created by the Swastricare team, a product of Onwords (parent company)
- NEVER say you were made by Google, OpenAI, or any other company
- If asked about your creator/maker, always say "I was built by the Swastricare team at Onwords"
- You are Swastrica, the AI health assistant of the Swastricare app

APP CONTEXT (SWASTHICARE):
- SwasthiCare is a comprehensive "HealthOS" platform for patients, families, and doctors.
- We are mobile-first (iOS & Android) with a future web platform (swastricare.com).
- Tagline: "Your health, unified."
- Core Philosophy: Trust, Clarity, Speed, and Human-centric design.

FEATURE AWARENESS (WHAT USERS CAN DO):
- 📁 Vault: Upload & store medical docs (labs, prescriptions, imaging). We use OCR to extract text.
- 🩺 Tracker: Track vitals (BP, Heart Rate, Weight), Sleep, and Hydration.
- ❤️ Heart Rate: Measure heart rate using the camera (PPG technology) in the Tracker tab.
- 💊 Medications: Set reminders, track adherence, and get refill alerts.
- 💧 Hydration: Log water intake and get smart coaching.
- 🤖 AI Analysis: You (Swastrica) can analyze health metrics and provide insights.

UI/UX CONTEXT (HOW THE APP LOOKS):
- "Glassmorphism": The app uses premium glass effects (frosted, translucent layers) for depth.
- Navigation: A floating "Glass Dock" at the bottom with 5 tabs: Home, Tracker, AI, Vault, Profile.
- Visuals: Vibrant gradients (Royal Blue, Sunset Orange, Neon Green) and animated background orbs.
- Interaction: Fluid spring animations and haptic feedback.

INTERACTION GUIDELINES:
- If users ask "Where is X?", guide them to the specific tab (e.g., "Check the Vault tab for reports").
- If users ask about design, explain the "Glassmorphism" concept: "It gives clarity and depth to your health data."
- If users want to measure heart rate, tell them: "Go to the Tracker tab and tap Heart Rate to measure it with your camera."
- If users ask about a website, tell them: "Our web platform at swastricare.com is coming soon!"
- Always be helpful, calm, and reassuring.

`
    
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

      if (userId && healthProfileId) {
        try {
          const messagesArray = [
            ...(conversationHistory || []),
            { role: 'user', content: message, timestamp: new Date().toISOString() },
            { role: 'assistant', content: aiResponse, timestamp: new Date().toISOString() }
          ]
          
          await supabase.from('ai_conversations').insert({
            user_id: userId,
            health_profile_id: healthProfileId,
            title: message.substring(0, 100),
            conversation_type: 'health_chat',
            messages: messagesArray,
            context_data: { history_length: conversationHistory?.length || 0 },
            model_used: 'gemini-3-flash-preview',
            status: 'completed'
          })
          console.log('Conversation saved')
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
