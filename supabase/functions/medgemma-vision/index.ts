import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Environment variables
const GOOGLE_AI_API_KEY = Deno.env.get('GOOGLE_AI_API_KEY')
const VERTEX_AI_PROJECT = Deno.env.get('GOOGLE_VERTEX_AI_PROJECT_ID')
const VERTEX_AI_LOCATION = Deno.env.get('GOOGLE_VERTEX_AI_LOCATION') || 'us-central1'
const MEDGEMMA_API_KEY = Deno.env.get('MEDGEMMA_API_KEY')

// Medical disclaimer
const MEDICAL_DISCLAIMER = "\n\n⚕️ *This analysis is for informational purposes only. Always consult a qualified healthcare provider for proper diagnosis and treatment. Do not make medical decisions based solely on this AI analysis.*"

// System prompt for medical image analysis
const VISION_SYSTEM_PROMPT = `You are Swastrica Medical Vision AI, a specialized assistant for analyzing medical documents and images, created by the Swastricare team (product of Onwords).

IDENTITY:
- Created by Swastricare team at Onwords
- NEVER claim to be made by Google, OpenAI, or other companies

CAPABILITIES:
1. Read and extract information from prescriptions
2. Interpret lab reports and blood test results
3. Identify medications from images
4. Read medical documents and summaries
5. Basic analysis of medical imaging (X-rays, scans) - with strong disclaimers

GUIDELINES:
1. Extract all visible text and data accurately
2. Organize information in a clear, readable format
3. Highlight any values outside normal ranges (if lab results)
4. Explain medical terms in simple language
5. NEVER make definitive diagnoses from images
6. Always recommend professional interpretation for imaging

OUTPUT FORMAT:
- Use clear headings and bullet points
- Include relevant emojis (📋 💊 🔬 📊)
- Highlight important findings
- Add context for medical terms
- Include uncertainty when appropriate

SAFETY:
- Flag any urgent findings requiring immediate attention
- Do not interpret complex imaging (CT, MRI) definitively
- Recommend follow-up with healthcare provider for all findings
- Note image quality limitations if applicable`

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

    const { message, imageData, imageType, analysisType, routedFrom } = await req.json()
    
    // Validate image data
    if (!imageData) {
      return new Response(JSON.stringify({ 
        response: "Please provide an image to analyze.",
        model: "medgemma-4b",
        error: true
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      })
    }

    // Detect image type if not provided
    const detectedType = imageType || detectImageType(imageData)
    if (!detectedType) {
      return new Response(JSON.stringify({ 
        response: "Unable to process this image format. Please use JPEG, PNG, or WebP.",
        model: "medgemma-4b",
        error: true
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      })
    }

    // Setup Supabase for user context
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

    // Build analysis prompt based on type
    let analysisPrompt = VISION_SYSTEM_PROMPT + "\n\n"
    
    switch (analysisType) {
      case 'prescription':
        analysisPrompt += `TASK: Analyze this prescription image
Extract:
- Patient name (if visible)
- Doctor name and credentials
- Date of prescription
- Medications prescribed (name, dosage, frequency, duration)
- Special instructions
- Any warnings or precautions

Format the output clearly with each medication on a separate line.`
        break
        
      case 'lab_report':
        analysisPrompt += `TASK: Analyze this lab report image
Extract:
- Test name and date
- All test results with values and units
- Reference ranges
- Flag any values outside normal range (↑ high, ↓ low)
- Provide brief explanations for abnormal values

Organize by category if multiple tests are present.`
        break
        
      case 'medical_document':
        analysisPrompt += `TASK: Analyze this medical document
Extract:
- Document type
- Key information and findings
- Important dates
- Relevant medical history mentioned
- Recommendations or follow-up actions

Summarize the main points clearly.`
        break
        
      case 'xray':
      case 'imaging':
        analysisPrompt += `TASK: Provide general observations about this medical image
NOTE: This is NOT a diagnostic analysis. Only a qualified radiologist can provide diagnosis.

Describe:
- Type of image (X-ray, ultrasound, etc.)
- Body region shown
- General quality of the image
- Any obvious visible features (without making diagnoses)

IMPORTANT: Strongly recommend professional radiologist interpretation.`
        break
        
      default:
        analysisPrompt += `TASK: Analyze this medical-related image
Identify the type of document/image and extract relevant information.
If it's a prescription, lab report, or medical document, extract the key details.
If it's a medical image, provide only general observations with strong disclaimers.`
    }
    
    if (message) {
      analysisPrompt += `\n\nUser's specific question: ${message}`
    }

    console.log('Calling MedGemma 4B Vision...')
    
    // Add timeout (longer for image processing)
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 60000) // 60 second timeout
    
    try {
      let aiResponse = ''
      let modelUsed = 'medgemma-4b'
      
      // Try MedGemma 4B via Vertex AI first
      if (VERTEX_AI_PROJECT && MEDGEMMA_API_KEY) {
        try {
          const vertexResponse = await callVertexAIMedGemmaVision(
            analysisPrompt, 
            imageData, 
            detectedType,
            controller.signal
          )
          if (vertexResponse) {
            aiResponse = vertexResponse
          }
        } catch (vertexError) {
          console.log('Vertex AI MedGemma Vision failed, falling back to Gemini:', vertexError.message)
        }
      }
      
      // Fallback to Gemini Vision if MedGemma unavailable
      if (!aiResponse) {
        modelUsed = 'gemini-vision'
        
        // Clean base64 data (remove data URL prefix if present)
        let cleanImageData = imageData
        if (imageData.includes(',')) {
          cleanImageData = imageData.split(',')[1]
        }
        
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
                temperature: 0.2, // Very low for accuracy
                maxOutputTokens: 2048 
              }
            }),
            signal: controller.signal
          }
        )
        clearTimeout(timeoutId)

        if (!geminiResponse.ok) {
          const errorText = await geminiResponse.text()
          console.error('Gemini Vision error:', errorText)
          throw new Error(`Gemini Vision: ${geminiResponse.statusText}`)
        }

        const geminiData = await geminiResponse.json()
        
        if (!geminiData.candidates || !geminiData.candidates[0]) {
          throw new Error('No response from Vision AI')
        }
        
        aiResponse = geminiData.candidates[0].content.parts[0].text.trim()
      }
      
      // Add medical disclaimer
      aiResponse += MEDICAL_DISCLAIMER
      
      console.log('Got vision analysis response')

      // Log the interaction
      if (userId && healthProfileId) {
        try {
          await supabase.from('ai_medical_interactions').insert({
            user_id: userId,
            health_profile_id: healthProfileId,
            query_type: 'image_analysis',
            model_used: modelUsed,
            query_summary: `Image analysis: ${analysisType || 'general'}`,
            has_health_context: false,
            metadata: {
              imageType: detectedType,
              analysisType: analysisType || 'general'
            },
            created_at: new Date().toISOString()
          })
          console.log('Image analysis logged')
        } catch (e) {
          console.log('DB log failed:', e.message)
        }
      }

      return new Response(JSON.stringify({ 
        response: aiResponse,
        model: modelUsed,
        isMedical: true,
        isImageAnalysis: true,
        analysisType: analysisType || 'general',
        hasDisclaimer: true
      }), {
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      })
      
    } catch (fetchError) {
      clearTimeout(timeoutId)
      if (fetchError.name === 'AbortError') {
        throw new Error('Image analysis timeout - please try with a smaller image')
      }
      throw fetchError
    }
    
  } catch (error) {
    console.error('MedGemma Vision error:', error)
    return new Response(JSON.stringify({ 
      response: "I apologize, but I'm having trouble analyzing this image. Please try again with a clearer image, or consult your healthcare provider directly for interpretation." + MEDICAL_DISCLAIMER,
      model: "error",
      isMedical: true,
      isImageAnalysis: true,
      error: true
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
})

// Helper function to detect image type from base64 data
function detectImageType(base64Data: string): string | null {
  // Check for data URL prefix
  if (base64Data.startsWith('data:image/jpeg') || base64Data.startsWith('data:image/jpg')) {
    return 'jpeg'
  }
  if (base64Data.startsWith('data:image/png')) {
    return 'png'
  }
  if (base64Data.startsWith('data:image/webp')) {
    return 'webp'
  }
  if (base64Data.startsWith('data:image/gif')) {
    return 'gif'
  }
  
  // Try to detect from raw base64 magic bytes
  try {
    const decoded = atob(base64Data.substring(0, 20))
    
    // JPEG starts with FFD8FF
    if (decoded.charCodeAt(0) === 0xFF && decoded.charCodeAt(1) === 0xD8) {
      return 'jpeg'
    }
    
    // PNG starts with 89504E47
    if (decoded.charCodeAt(0) === 0x89 && decoded.substring(1, 4) === 'PNG') {
      return 'png'
    }
    
    // WebP starts with RIFF....WEBP
    if (decoded.substring(0, 4) === 'RIFF' && decoded.substring(8, 12) === 'WEBP') {
      return 'webp'
    }
  } catch (e) {
    // Decoding failed, try common formats
  }
  
  // Default to JPEG if can't detect
  return 'jpeg'
}

// Helper function to call Vertex AI MedGemma Vision
async function callVertexAIMedGemmaVision(
  prompt: string, 
  imageData: string, 
  imageType: string,
  signal: AbortSignal
): Promise<string | null> {
  const projectId = Deno.env.get('GOOGLE_VERTEX_AI_PROJECT_ID')
  const location = Deno.env.get('GOOGLE_VERTEX_AI_LOCATION') || 'us-central1'
  const apiKey = Deno.env.get('MEDGEMMA_API_KEY')
  
  if (!projectId || !apiKey) {
    return null
  }
  
  // Clean base64 data
  let cleanImageData = imageData
  if (imageData.includes(',')) {
    cleanImageData = imageData.split(',')[1]
  }
  
  // Vertex AI endpoint for MedGemma 4B (multimodal)
  const endpoint = `https://${location}-aiplatform.googleapis.com/v1/projects/${projectId}/locations/${location}/publishers/google/models/medgemma-4b:generateContent`
  
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`
    },
    body: JSON.stringify({
      contents: [{
        parts: [
          { text: prompt },
          {
            inlineData: {
              mimeType: `image/${imageType}`,
              data: cleanImageData
            }
          }
        ]
      }],
      generationConfig: {
        temperature: 0.2,
        maxOutputTokens: 2048,
        topP: 0.8,
        topK: 40
      }
    }),
    signal
  })
  
  if (!response.ok) {
    const errorText = await response.text()
    console.error('Vertex AI Vision error:', errorText)
    return null
  }
  
  const data = await response.json()
  
  if (!data.candidates || !data.candidates[0]) {
    return null
  }
  
  return data.candidates[0].content.parts[0].text.trim()
}
