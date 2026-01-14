import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const GOOGLE_AI_API_KEY = Deno.env.get('GOOGLE_AI_API_KEY')
const MEDICAL_DISCLAIMER = "\n\n⚕️ *This analysis is for informational purposes only. Always consult a qualified healthcare provider for proper diagnosis and treatment.*"

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

    const { message, imageData, imageType, analysisType } = await req.json()
    
    console.log('=== MEDGEMMA VISION ===')
    console.log('Model: Gemini 2.0 Flash Vision')
    console.log('Analysis type:', analysisType || 'general')
    console.log('User message:', message || 'none')
    console.log('Image type:', imageType || 'jpeg')
    console.log('Image data length:', imageData?.length || 0, 'characters')
    
    if (!imageData) {
      return new Response(JSON.stringify({ 
        response: "Please provide an image to analyze.",
        model: "gemini-vision",
        error: true
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

    let analysisPrompt = "You are a medical AI assistant. Analyze this medical image/document and extract key information.\n\n"
    
    switch (analysisType) {
      case 'prescription':
        analysisPrompt += "Extract: medications, dosages, doctor name, date"
        break
      case 'lab_report':
        analysisPrompt += "Extract: test results, values, reference ranges, flag abnormals"
        break
      default:
        analysisPrompt += "Identify document type and extract relevant medical information"
    }
    
    if (message) {
      analysisPrompt += `\n\nUser question: ${message}`
    }

    let cleanImageData = imageData
    if (imageData.includes(',')) {
      cleanImageData = imageData.split(',')[1]
    }

    const detectedType = imageType || 'jpeg'
    
    console.log('=== VISION API CALL ===')
    console.log('Analysis prompt:', analysisPrompt)
    console.log('Image mime type:', `image/${detectedType}`)
    console.log('Clean image data length:', cleanImageData.length, 'characters')
    console.log('API endpoint: https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent')
    
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 60000)
    
    try {
      const visionPayload = {
        contents: [{
          parts: [
            { text: analysisPrompt },
            {
              inlineData: {
                mimeType: `image/${detectedType}`,
                data: '[BASE64_IMAGE_DATA]' // Not logging actual image data
              }
            }
          ]
        }],
        generationConfig: { 
          temperature: 0.2,
          maxOutputTokens: 2048 
        }
      }
      console.log('Vision payload structure:', JSON.stringify(visionPayload, null, 2))
      
      const geminiResponse = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GOOGLE_AI_API_KEY}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{
              parts: [
                { text: analysisPrompt },
                {
                  inlineData: {
                    mimeType: `image/${detectedType}`,
                    data: cleanImageData
                  }
                }
              ]
            }],
            generationConfig: { 
              temperature: 0.2,
              maxOutputTokens: 2048 
            }
          }),
          signal: controller.signal
        }
      )
      clearTimeout(timeoutId)

      if (!geminiResponse.ok) {
        throw new Error(`Gemini Vision: ${geminiResponse.statusText}`)
      }

      const geminiData = await geminiResponse.json()
      
      if (!geminiData.candidates || !geminiData.candidates[0]) {
        throw new Error('No response from Vision AI')
      }
      
      const aiResponse = geminiData.candidates[0].content.parts[0].text.trim() + MEDICAL_DISCLAIMER
      
      console.log('=== VISION RESPONSE ===')
      console.log('Response length:', aiResponse.length, 'characters')
      console.log('Response preview:', aiResponse.substring(0, 200) + '...')
      
      if (userId && healthProfileId) {
        try {
          await supabase.from('ai_medical_interactions').insert({
            user_id: userId,
            health_profile_id: healthProfileId,
            query_type: 'image_analysis',
            model_used: 'gemini-vision',
            query_summary: `Image analysis: ${analysisType || 'general'}`,
            created_at: new Date().toISOString()
          })
        } catch (e) {
          console.log('DB log failed:', e.message)
        }
      }

      return new Response(JSON.stringify({ 
        response: aiResponse,
        model: 'gemini-vision',
        isMedical: true,
        isImageAnalysis: true,
        analysisType: analysisType || 'general',
        hasDisclaimer: true
      }), {
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      })
      
    } catch (fetchError) {
      clearTimeout(timeoutId)
      throw fetchError
    }
    
  } catch (error) {
    console.error('Vision error:', error)
    return new Response(JSON.stringify({ 
      response: "I'm having trouble analyzing this image. Please try again with a clearer image." + MEDICAL_DISCLAIMER,
      model: "error",
      error: true
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
})
