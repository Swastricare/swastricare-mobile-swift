import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Medical keywords for routing to MedGemma
const MEDICAL_KEYWORDS = [
  // Symptoms
  'symptom', 'pain', 'ache', 'hurt', 'sore', 'fever', 'nausea', 'dizzy', 'fatigue',
  'headache', 'migraine', 'cough', 'cold', 'flu', 'infection', 'swelling', 'rash',
  'bleeding', 'vomiting', 'diarrhea', 'constipation', 'cramp', 'numbness', 'tingling',
  
  // Medical terms
  'medication', 'medicine', 'drug', 'prescription', 'dose', 'dosage', 'side effect',
  'diagnosis', 'condition', 'disease', 'illness', 'disorder', 'syndrome',
  'treatment', 'therapy', 'surgery', 'procedure', 'test', 'scan', 'x-ray', 'mri',
  
  // Body parts (medical context)
  'chest', 'abdomen', 'liver', 'kidney', 'lung', 'heart', 'brain', 'spine',
  
  // Healthcare
  'doctor', 'physician', 'hospital', 'clinic', 'emergency', 'ambulance',
  'specialist', 'cardiologist', 'dermatologist', 'neurologist',
  
  // Vitals & metrics
  'blood pressure', 'glucose', 'cholesterol', 'bmi', 'oxygen', 'saturation',
  
  // Conditions
  'diabetes', 'hypertension', 'asthma', 'allergy', 'arthritis', 'cancer',
  'depression', 'anxiety', 'insomnia', 'anemia', 'thyroid'
]

// Emergency keywords that need immediate attention
const EMERGENCY_KEYWORDS = [
  'chest pain', 'heart attack', 'stroke', 'cant breathe', 'cannot breathe',
  'difficulty breathing', 'unconscious', 'seizure', 'severe bleeding',
  'overdose', 'suicide', 'suicidal', 'dying', 'emergency'
]

// Check if message contains medical keywords
function isMedicalQuery(message: string): boolean {
  const lowerMessage = message.toLowerCase()
  return MEDICAL_KEYWORDS.some(keyword => lowerMessage.includes(keyword))
}

// Check if message is an emergency
function isEmergencyQuery(message: string): boolean {
  const lowerMessage = message.toLowerCase()
  return EMERGENCY_KEYWORDS.some(keyword => lowerMessage.includes(keyword))
}

// Check if request contains image data
function hasImageData(payload: any): boolean {
  return payload.imageData || payload.image || payload.imageBase64
}

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

    const payload = await req.json()
    const { message, conversationHistory, imageData, forceModel } = payload
    
    console.log('=== AI ROUTER ===')
    console.log('Incoming payload:', {
      message: message?.substring(0, 100),
      hasHistory: !!conversationHistory,
      historyLength: conversationHistory?.length || 0,
      hasImage: !!imageData,
      forceModel: forceModel || 'auto'
    })
    
    // Input validation
    if (!message || typeof message !== 'string') {
      return new Response(JSON.stringify({ 
        response: "Please provide a valid message.",
        model: "none",
        error: true
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      })
    }

    // Determine which model to use
    let targetModel = 'gemini' // default
    let targetFunction = 'ai-chat'
    
    // Check for forced model selection
    if (forceModel) {
      if (forceModel === 'medgemma' || forceModel === 'medgemma-27b') {
        targetModel = 'medgemma-27b'
        targetFunction = 'medgemma-chat'
      } else if (forceModel === 'medgemma-4b' || forceModel === 'medgemma-vision') {
        targetModel = 'medgemma-4b'
        targetFunction = 'medgemma-vision'
      }
    } else {
      // Auto-detect based on content
      
      // Check for emergency first
      if (isEmergencyQuery(message)) {
        // Return emergency response immediately
        return new Response(JSON.stringify({
          response: "🚨 EMERGENCY DETECTED\n\nIf you or someone else is experiencing a medical emergency, please:\n\n1. Call emergency services immediately (911 in US, 112 in EU, 108 in India)\n2. Stay calm and follow dispatcher instructions\n3. Do not delay seeking professional help\n\nThis AI cannot provide emergency medical care. Your safety is the priority.",
          model: "emergency",
          isEmergency: true,
          disclaimer: "If this is a life-threatening emergency, call emergency services immediately."
        }), {
          headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
        })
      }
      
      // Check for image data - route to MedGemma 4B
      if (hasImageData(payload)) {
        targetModel = 'medgemma-4b'
        targetFunction = 'medgemma-vision'
      }
      // Check for medical keywords - route to MedGemma 27B
      else if (isMedicalQuery(message)) {
        targetModel = 'medgemma-27b'
        targetFunction = 'medgemma-chat'
      }
    }

    console.log('=== ROUTING DECISION ===')
    console.log(`Selected model: ${targetModel}`)
    console.log(`Target function: ${targetFunction}`)
    console.log(`Reason: ${isEmergencyQuery(message) ? 'Emergency detected' : hasImageData(payload) ? 'Image data present' : isMedicalQuery(message) ? 'Medical keywords detected' : 'General chat (default)'}`)
    
    // Get the base URL for internal function calls
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    
    // Forward the request to the appropriate function
    const authHeader = req.headers.get('Authorization')
    
    const functionUrl = `${supabaseUrl}/functions/v1/${targetFunction}`
    
    const forwardPayload = {
      message,
      conversationHistory,
      ...(imageData && { imageData }),
      routedFrom: 'ai-router',
      originalModel: targetModel
    }
    
    console.log('=== FORWARDING REQUEST ===')
    console.log(`URL: ${functionUrl}`)
    console.log('Payload:', {
      message: message.substring(0, 100),
      hasHistory: !!conversationHistory,
      hasImage: !!imageData,
      routedFrom: 'ai-router',
      originalModel: targetModel
    })
    
    const response = await fetch(functionUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': authHeader || `Bearer ${supabaseAnonKey}`,
        'apikey': supabaseAnonKey
      },
      body: JSON.stringify(forwardPayload)
    })
    
    if (!response.ok) {
      const errorText = await response.text()
      console.error(`${targetFunction} error:`, errorText)
      
      // Fallback to Gemini if MedGemma fails
      if (targetModel.startsWith('medgemma')) {
        console.log('Falling back to Gemini...')
        const fallbackResponse = await fetch(`${supabaseUrl}/functions/v1/ai-chat`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': authHeader || `Bearer ${supabaseAnonKey}`,
            'apikey': supabaseAnonKey
          },
          body: JSON.stringify({ message, conversationHistory })
        })
        
        if (fallbackResponse.ok) {
          const fallbackData = await fallbackResponse.json()
          return new Response(JSON.stringify({
            ...fallbackData,
            model: 'gemini-fallback',
            note: 'Medical AI temporarily unavailable, using general AI'
          }), {
            headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
          })
        }
      }
      
      throw new Error(`Function ${targetFunction} failed: ${errorText}`)
    }
    
    const data = await response.json()
    
    // Add metadata about which model was used
    return new Response(JSON.stringify({
      ...data,
      model: targetModel,
      isMedical: targetModel.startsWith('medgemma')
    }), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
    
  } catch (error) {
    console.error('Router error:', error)
    return new Response(JSON.stringify({ 
      response: "I'm having trouble processing your request. Please try again.",
      model: "error",
      error: true
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
})
