import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { callMiniMax, MiniMaxMessage } from '../_shared/minimax.ts'
import { handleCors, corsHeaders } from '../_shared/cors.ts'

const MAX_MESSAGE_LENGTH = 4000
const MAX_HISTORY_LENGTH = 10

const SYSTEM_PROMPT = `You are Swastrica, a friendly health assistant! 💚 Use short sentences. Add relevant emojis. Be encouraging and warm. Keep responses brief (2-4 short sentences).

CRITICAL RESPONSE RULES:
- NEVER add disclaimers, warnings, or "consult a professional/doctor" notes at the end of responses
- NEVER say "This is for general knowledge only", "I'm not a doctor", "consult a healthcare professional", or any variation
- The app already displays a medical disclaimer in the UI — adding one yourself is redundant and annoying
- Just answer the question directly and helpfully. No caveats, no hedging, no liability language.

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
- Always be helpful, calm, and reassuring.`

serve(async (req) => {
  // Handle CORS preflight
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    const { message, conversationHistory, systemContext } = await req.json()

    // Input validation
    if (!message || typeof message !== 'string') {
      return new Response(JSON.stringify({
        response: "Please provide a valid message."
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      })
    }

    if (message.length > MAX_MESSAGE_LENGTH) {
      return new Response(JSON.stringify({
        response: "Message is too long. Please keep it under 1000 characters."
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
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

    // Build messages array for MiniMax
    // Base system prompt + personality/health context from iOS (if present)
    let systemContent = SYSTEM_PROMPT
    if (systemContext && typeof systemContext === 'string') {
      systemContent += '\n\n' + systemContext
    }

    const messages: MiniMaxMessage[] = [
      { role: 'system', content: systemContent },
    ]

    // Append conversation history as alternating user/assistant messages
    if (conversationHistory && Array.isArray(conversationHistory) && conversationHistory.length > 0) {
      conversationHistory.slice(-MAX_HISTORY_LENGTH).forEach((msg: { role?: string; content?: string }) => {
        if (msg.role && msg.content) {
          messages.push({
            role: msg.role === 'user' ? 'user' : 'assistant',
            content: msg.content,
          })
        }
      })
    }

    // Append the current user message
    messages.push({ role: 'user', content: message })

    console.log('Calling MiniMax...')

    const aiResponse = await callMiniMax(messages, {
      temperature: 0.8,
      maxTokens: 2048,
    })

    console.log('Got response')

    return new Response(JSON.stringify({ response: aiResponse }), {
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    })
  } catch (error) {
    console.error('Error:', error)
    return new Response(JSON.stringify({
      response: "I'm having trouble right now. Please try again in a moment."
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    })
  }
})
