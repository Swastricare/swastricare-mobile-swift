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
    
    console.log('📥 MEDGEMMA CHAT REQUEST')
    console.log('Message:', message?.substring(0, 100))
    console.log('API Key present:', !!GOOGLE_AI_API_KEY)
    
    if (!message || typeof message !== 'string') {
      return new Response(JSON.stringify({ 
        response: "Please provide a valid medical question.",
        model: "gemini-medical"
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      })
    }
    
    if (!GOOGLE_AI_API_KEY) {
      console.error('❌ GOOGLE_AI_API_KEY not set')
      throw new Error('API key not configured')
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

    let fullPrompt = MEDICAL_SYSTEM_PROMPT + "\n\n"
    
    if (healthContext) {
      fullPrompt += `Health Context: ${healthContext}\n\n`
    }
    
    if (conversationHistory && Array.isArray(conversationHistory) && conversationHistory.length > 0) {
      fullPrompt += "Previous Conversation:\n"
      conversationHistory.slice(-8).forEach((msg) => {
        if (msg.role && msg.content) {
          fullPrompt += `${msg.role === 'user' ? 'Patient' : 'Swastrica'}: ${msg.content}\n`
        }
      })
      fullPrompt += "\n"
    }
    
    fullPrompt += `Patient Question: ${message}\n\nSwastrica Medical Response:`

    console.log('📝 Prompt length:', fullPrompt.length, 'chars')
    
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 25000) // 25 second timeout
    
    try {
      console.log('🔄 Calling Gemini API...')
      
      const geminiResponse = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=${GOOGLE_AI_API_KEY}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{ parts: [{ text: fullPrompt }] }],
            generationConfig: { 
              temperature: 0.4,
              maxOutputTokens: 1024 
            },
            safetySettings: [
              { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_ONLY_HIGH" },
              { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_ONLY_HIGH" },
              { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_ONLY_HIGH" },
              { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_ONLY_HIGH" }
            ]
          }),
          signal: controller.signal
        }
      )
      clearTimeout(timeoutId)

      console.log('📡 Gemini response status:', geminiResponse.status)

      if (!geminiResponse.ok) {
        const errorText = await geminiResponse.text()
        console.error('❌ Gemini error:', errorText)
        throw new Error(`Gemini API error: ${geminiResponse.status}`)
      }

      const geminiData = await geminiResponse.json()
      
      if (!geminiData.candidates || !geminiData.candidates[0]) {
        console.error('❌ No candidates in response')
        throw new Error('No response from AI')
      }
      
      let aiResponse = geminiData.candidates[0].content.parts[0].text.trim() + MEDICAL_DISCLAIMER
      
      console.log('✅ Response generated:', aiResponse.length, 'chars')

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
        } catch (e) {
          console.log('⚠️ DB log failed:', e.message)
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
      if (fetchError.name === 'AbortError') {
        console.error('⏱️ Request timeout')
        throw new Error('Request timeout')
      }
      throw fetchError
    }
    
  } catch (error) {
    console.error('❌ MedGemma error:', error.message)
    return new Response(JSON.stringify({ 
      response: "I apologize, but I'm having trouble processing your medical question right now. Please try again in a moment. For any urgent health concerns, please contact your healthcare provider or call emergency services." + MEDICAL_DISCLAIMER,
      model: "error",
      isMedical: true,
      error: true
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
})
