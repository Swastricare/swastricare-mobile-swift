import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { callMiniMax, MiniMaxMessage } from '../_shared/minimax.ts'
import { handleCors, corsHeaders } from '../_shared/cors.ts'

const MEDICAL_DISCLAIMER = "\n\n⚕️ *This information is for educational purposes only and is not a substitute for professional medical advice, diagnosis, or treatment. Always consult a qualified healthcare provider with any questions about your health.*"

const MEDICAL_SYSTEM_PROMPT = `You are Swastrica Medical AI, a knowledgeable health assistant created by the Swastricare team (product of Onwords).

IDENTITY RULES:
- You were created by the Swastricare team, a product of Onwords
- NEVER claim to be made by Google, OpenAI, or any other company
- You are Swastrica, the medical AI assistant of the Swastricare app

MEDICAL GUIDELINES:
1. Provide accurate, evidence-based medical information
2. Always recommend consulting a healthcare professional for diagnosis and treatment
3. Never provide specific dosages or prescribe medications
4. Flag potential emergency symptoms and recommend immediate medical attention
5. Use clear, simple language that patients can understand
6. Cite general medical knowledge without making definitive diagnoses
7. Be empathetic and supportive while maintaining accuracy

RESPONSE STYLE:
- Use short, clear sentences
- Include relevant emojis for warmth (💚 🏥 💊 🩺)
- Break complex information into bullet points
- Always include appropriate disclaimers
- Be encouraging but honest about limitations

SAFETY PRIORITIES:
- If symptoms suggest emergency (chest pain, difficulty breathing, stroke signs), immediately advise calling emergency services
- Never downplay potentially serious symptoms
- Recommend professional evaluation for persistent or worsening symptoms
- Do not provide advice that could delay necessary medical care`

serve(async (req) => {
  try {
    const corsResponse = handleCors(req)
    if (corsResponse) return corsResponse

    const { message, conversationHistory, healthContext, systemContext } = await req.json()

    console.log('📥 MEDGEMMA CHAT REQUEST')
    console.log('Message:', message?.substring(0, 100))

    if (!message || typeof message !== 'string') {
      return new Response(JSON.stringify({
        response: "Please provide a valid medical question.",
        model: "minimax-medical"
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
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
        console.log('⚠️ Auth failed:', e.message)
      }
    }

    // Build the messages array for MiniMax
    const messages: MiniMaxMessage[] = []

    // System message: base prompt + optional contexts from iOS
    let systemContent = MEDICAL_SYSTEM_PROMPT
    if (systemContext && typeof systemContext === 'string') {
      systemContent += '\n\n' + systemContext
    }
    if (healthContext) {
      systemContent += `\n\nHealth Context: ${healthContext}`
    }
    messages.push({ role: 'system', content: systemContent })

    // Conversation history as alternating user/assistant messages
    if (conversationHistory && Array.isArray(conversationHistory) && conversationHistory.length > 0) {
      conversationHistory.slice(-8).forEach((msg) => {
        if (msg.role && msg.content) {
          messages.push({
            role: msg.role === 'user' ? 'user' : 'assistant',
            content: msg.content,
          })
        }
      })
    }

    // Final user message
    messages.push({ role: 'user', content: message })

    console.log('📝 Messages count:', messages.length)

    console.log('🔄 Calling MiniMax API...')

    const aiResponse = await callMiniMax(messages, {
      temperature: 0.4,
      maxTokens: 2048,
    })

    const responseWithDisclaimer = aiResponse.trim() + MEDICAL_DISCLAIMER

    console.log('✅ Response generated:', responseWithDisclaimer.length, 'chars')

    // Audit log
    if (userId && healthProfileId) {
      try {
        await supabase.from('ai_medical_interactions').insert({
          user_id: userId,
          health_profile_id: healthProfileId,
          query_type: 'medical_chat',
          model_used: 'minimax-medical',
          query_summary: message.substring(0, 200),
          has_health_context: !!healthContext,
          created_at: new Date().toISOString()
        })
      } catch (e) {
        console.log('⚠️ DB log failed:', e.message)
      }
    }

    return new Response(JSON.stringify({
      response: responseWithDisclaimer,
      model: 'minimax-medical',
      isMedical: true,
      hasDisclaimer: true
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    console.error('❌ MedGemma error:', error.message)
    return new Response(JSON.stringify({
      response: "I apologize, but I'm having trouble processing your medical question right now. Please try again in a moment. For any urgent health concerns, please contact your healthcare provider or call emergency services." + MEDICAL_DISCLAIMER,
      model: "error",
      isMedical: true,
      error: true
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
