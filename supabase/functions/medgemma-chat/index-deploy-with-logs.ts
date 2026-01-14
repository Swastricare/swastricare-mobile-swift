import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const GOOGLE_AI_API_KEY = Deno.env.get('GOOGLE_AI_API_KEY')
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
    if (req.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        },
      })
    }

    const { message, conversationHistory, healthContext } = await req.json()
    
    if (!message || typeof message !== 'string') {
      return new Response(JSON.stringify({ 
        response: "Please provide a valid medical question.",
        model: "medgemma-27b"
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
        console.log('Auth failed:', e.message)
      }
    }

    let fullPrompt = MEDICAL_SYSTEM_PROMPT + "\n\n"
    
    if (conversationHistory && Array.isArray(conversationHistory) && conversationHistory.length > 0) {
      fullPrompt += "PREVIOUS CONVERSATION:\n"
      conversationHistory.slice(-10).forEach((msg) => {
        if (msg.role && msg.content) {
          fullPrompt += `${msg.role === 'user' ? 'Patient' : 'Swastrica'}: ${msg.content}\n`
        }
      })
      fullPrompt += "\n"
    }
    
    fullPrompt += `Patient Question: ${message}\n\nSwastrica Medical Response:`

    console.log('=== MEDGEMMA CHAT ===')
    console.log('Model: Gemini 2.0 Flash (Medical Mode)')
    console.log('User message:', message.substring(0, 200))
    console.log('Full prompt length:', fullPrompt.length, 'characters')
    console.log('Has health context:', !!healthContext)
    console.log('Has conversation history:', !!(conversationHistory && conversationHistory.length > 0))
    console.log('Prompt preview:', fullPrompt.substring(0, 300) + '...')
    
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 45000)
    
    try {
      console.log('=== API CALL ===')
      console.log('Model: gemini-2.0-flash')
      console.log('API endpoint: https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent')
      
      const apiPayload = {
        contents: [{ parts: [{ text: fullPrompt }] }],
        generationConfig: { 
          temperature: 0.4,
          maxOutputTokens: 1024 
        },
        safetySettings: [
          { category: "HARM_CATEGORY_MEDICAL", threshold: "BLOCK_NONE" }
        ]
      }
      console.log('API payload:', JSON.stringify(apiPayload, null, 2).substring(0, 500) + '...')
      
      const geminiResponse = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GOOGLE_AI_API_KEY}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(apiPayload),
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
        throw new Error('No response from AI')
      }
      
      let aiResponse = geminiData.candidates[0].content.parts[0].text.trim() + MEDICAL_DISCLAIMER
      
      console.log('=== RESPONSE GENERATED ===')
      console.log('Model used: gemini-medical')
      console.log('Response length:', aiResponse.length, 'characters')
      console.log('Response preview:', aiResponse.substring(0, 200) + '...')

      if (userId && healthProfileId) {
        try {
          await supabase.from('ai_medical_interactions').insert({
            user_id: userId,
            health_profile_id: healthProfileId,
            query_type: 'medical_chat',
            model_used: 'gemini-medical',
            query_summary: message.substring(0, 200),
            has_health_context: !!healthContext,
            created_at: new Date().toISOString()
          })
          console.log('Medical interaction logged')
        } catch (e) {
          console.log('DB log failed:', e.message)
        }
      }

      return new Response(JSON.stringify({ 
        response: aiResponse,
        model: 'gemini-medical',
        isMedical: true,
        hasDisclaimer: true
      }), {
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      })
      
    } catch (fetchError) {
      clearTimeout(timeoutId)
      throw fetchError
    }
    
  } catch (error) {
    console.error('MedGemma error:', error)
    return new Response(JSON.stringify({ 
      response: "I apologize, but I'm having trouble processing your medical question right now. For any urgent health concerns, please contact your healthcare provider or call emergency services." + MEDICAL_DISCLAIMER,
      model: "error",
      isMedical: true,
      error: true
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
})
