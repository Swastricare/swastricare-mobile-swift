import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY')
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
        response: "Message is too long. Please keep it under 4000 characters."
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      })
    }

    if (!ANTHROPIC_API_KEY) {
      console.error('ANTHROPIC_API_KEY not set')
      return new Response(JSON.stringify({
        response: "Opus service is not configured. Please contact support."
      }), {
        status: 500,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      })
    }

    // Auth check
    const authHeader = req.headers.get('Authorization')
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: authHeader ? { Authorization: authHeader } : {} } }
    )

    let userId: string | null = null
    let healthProfileId: string | null = null
    if (authHeader) {
      try {
        const { data: { user } } = await supabase.auth.getUser()
        userId = user?.id ?? null

        if (userId) {
          const { data: profile } = await supabase
            .from('health_profiles')
            .select('id')
            .eq('user_id', userId)
            .eq('is_primary', true)
            .single()
          healthProfileId = profile?.id ?? null
        }
      } catch (e) {
        console.log('Auth/profile fetch failed:', (e as Error).message)
      }
    }

    // Build messages array for Claude API
    const systemPrompt = `You are Swastrica (powered by Claude Opus 4.6), the advanced AI health assistant in the Swastricare app, built by the Swastricare team at Onwords.

IMPORTANT IDENTITY RULES:
- You are Swastrica, the AI health assistant of the Swastricare app
- You were created by the Swastricare team, a product of Onwords (parent company)
- You are powered by Claude Opus 4.6 from Anthropic for advanced reasoning
- NEVER say you were made by Google, OpenAI, or any other company besides Anthropic/Swastricare
- If asked about your creator/maker, say "I was built by the Swastricare team at Onwords, powered by Claude from Anthropic"

APP CONTEXT (SWASTHICARE):
- SwasthiCare is a comprehensive "HealthOS" platform for patients, families, and doctors
- Mobile-first (iOS & Android) with a future web platform (swastricare.com)
- Tagline: "Your health, unified."
- Core Philosophy: Trust, Clarity, Speed, and Human-centric design

FEATURE AWARENESS:
- Vault: Upload & store medical docs (labs, prescriptions, imaging) with OCR
- Tracker: Track vitals (BP, Heart Rate, Weight), Sleep, and Hydration
- Heart Rate: Measure heart rate using camera (PPG technology) in the Tracker tab
- Medications: Set reminders, track adherence, and get refill alerts
- Hydration: Log water intake and get smart coaching
- AI Analysis: Analyze health metrics and provide insights
- Family Sharing: Share health data with family members and caregivers

BEHAVIOR:
- Provide thorough, well-reasoned responses with clear structure
- Use your advanced reasoning capabilities for complex health questions
- Be warm, empathetic, and encouraging
- Always recommend consulting healthcare professionals for medical decisions
- Never prescribe medications or dosages
- Use relevant emojis sparingly to enhance readability
- For health data questions, reference the user's metrics if provided in context`

    // Format conversation history into Claude messages format
    const claudeMessages: Array<{ role: string; content: string }> = []

    if (conversationHistory && Array.isArray(conversationHistory)) {
      conversationHistory.slice(-MAX_HISTORY_LENGTH).forEach((msg: { role?: string; content?: string }) => {
        if (msg.role && msg.content) {
          claudeMessages.push({
            role: msg.role === 'user' ? 'user' : 'assistant',
            content: msg.content
          })
        }
      })
    }

    // Add the current user message
    claudeMessages.push({ role: 'user', content: message })

    console.log('Calling Claude Opus 4.6...')

    // Call Anthropic Messages API with timeout
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 90000) // 90 second timeout for Opus

    try {
      const claudeResponse = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': ANTHROPIC_API_KEY,
          'anthropic-version': '2023-06-01'
        },
        body: JSON.stringify({
          model: 'claude-opus-4-6',
          max_tokens: 4096,
          system: systemPrompt,
          messages: claudeMessages
        }),
        signal: controller.signal
      })
      clearTimeout(timeoutId)

      if (!claudeResponse.ok) {
        const errorText = await claudeResponse.text()
        console.error('Claude API error:', errorText)
        throw new Error(`Claude: ${claudeResponse.statusText}`)
      }

      const claudeData = await claudeResponse.json()

      if (!claudeData.content || !claudeData.content[0]) {
        throw new Error('No response from Claude')
      }

      const aiResponse = claudeData.content[0].text.trim()
      const modelUsed = claudeData.model || 'claude-opus-4-6'
      console.log('Got Claude response, model:', modelUsed)

      // Save conversation to database
      if (userId && healthProfileId) {
        try {
          const messagesArray = [
            ...(conversationHistory || []),
            { role: 'user', content: message, timestamp: new Date().toISOString() },
            { role: 'assistant', content: aiResponse, timestamp: new Date().toISOString() }
          ]

          const { data: existingConversations } = await supabase
            .from('ai_conversations')
            .select('id')
            .eq('user_id', userId)
            .eq('health_profile_id', healthProfileId)
            .eq('status', 'active')
            .order('updated_at', { ascending: false })
            .limit(1)

          if (existingConversations && existingConversations.length > 0) {
            await supabase
              .from('ai_conversations')
              .update({
                messages: messagesArray,
                updated_at: new Date().toISOString(),
                title: message.substring(0, 100),
                model_used: modelUsed
              })
              .eq('id', existingConversations[0].id)
          } else {
            await supabase
              .from('ai_conversations')
              .insert({
                user_id: userId,
                health_profile_id: healthProfileId,
                title: message.substring(0, 100),
                conversation_type: 'general_health',
                messages: messagesArray,
                context_data: { history_length: conversationHistory?.length || 0 },
                model_used: modelUsed,
                status: 'active'
              })
          }
        } catch (e) {
          console.log('DB save failed:', (e as Error).message)
        }
      }

      return new Response(JSON.stringify({
        response: aiResponse,
        model: modelUsed
      }), {
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      })
    } catch (fetchError) {
      clearTimeout(timeoutId)
      if ((fetchError as Error).name === 'AbortError') {
        throw new Error('Request timeout - Claude Opus may need more time for complex queries')
      }
      throw fetchError
    }
  } catch (error) {
    console.error('Error:', error)
    return new Response(JSON.stringify({
      response: "I'm having trouble connecting to Opus right now. Please try again in a moment.",
      model: "claude-opus-4-6"
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
})
