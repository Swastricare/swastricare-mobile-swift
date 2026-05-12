import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { handleCors, corsHeaders } from '../_shared/cors.ts'

// Medical keywords for routing to medical chat
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

// Health & wellness keywords — if ANY of these appear, the message is on-topic
const HEALTH_KEYWORDS = [
  // General health & wellness
  'health', 'wellness', 'wellbeing', 'well-being', 'fitness', 'exercise', 'workout',
  'yoga', 'meditation', 'stretching', 'walk', 'run', 'jog', 'gym', 'cardio', 'strength',
  'weight', 'bmi', 'body', 'muscle', 'bone', 'joint', 'posture',

  // Nutrition & diet
  'nutrition', 'diet', 'calorie', 'protein', 'carb', 'fat', 'fiber', 'vitamin',
  'mineral', 'food', 'meal', 'eat', 'hydration', 'water', 'drink', 'fasting',
  'macro', 'nutrient', 'supplement', 'iron', 'calcium', 'zinc', 'omega',

  // Medical & symptoms (extends MEDICAL_KEYWORDS)
  ...MEDICAL_KEYWORDS,

  // Mental health
  'stress', 'mental health', 'mindfulness', 'sleep', 'rest', 'relaxation',
  'burnout', 'mood', 'emotion', 'self-care', 'self care', 'wellbeing',

  // Hygiene & prevention
  'hygiene', 'vaccine', 'vaccination', 'immunity', 'immune', 'prevention',
  'first aid', 'wound', 'bandage', 'sanitize', 'disinfect',

  // App-related
  'swastricare', 'swastrica', 'swasthicare', 'tracker', 'vault', 'app',
  'heart rate', 'steps', 'medication reminder', 'hydration tracker',

  // Indian health context
  'ayurveda', 'ayurvedic', 'homeopathy', 'unani', 'pranayama', 'asana',

  // Vital signs & metrics
  'pulse', 'temperature', 'fever', 'bp', 'sugar level', 'hemoglobin',

  // Greeting & identity (always allowed)
  'hello', 'hi', 'hey', 'good morning', 'good evening', 'good night',
  'thank', 'thanks', 'who are you', 'what can you do', 'help',
  'your name', 'what are you',
]

// Clearly off-topic keywords — things that have nothing to do with health
const OFF_TOPIC_KEYWORDS = [
  // Programming & tech
  'code', 'coding', 'programming', 'javascript', 'python', 'java', 'html', 'css',
  'react', 'flutter', 'swift', 'kotlin', 'api', 'database', 'server', 'deploy',
  'github', 'git', 'debug', 'compile', 'algorithm', 'software', 'hardware',

  // Business & finance
  'tax', 'invoice', 'gst', 'accounting', 'stock market', 'shares', 'mutual fund',
  'crypto', 'bitcoin', 'trading', 'investment', 'loan', 'emi', 'mortgage',
  'business plan', 'startup', 'revenue', 'profit', 'marketing', 'seo',

  // Entertainment
  'movie', 'film', 'song', 'music', 'lyrics', 'cricket', 'football', 'ipl',
  'world cup', 'game', 'gaming', 'playstation', 'xbox', 'netflix', 'anime',
  'celebrity', 'actor', 'actress', 'bollywood', 'hollywood',

  // Education (non-health)
  'math', 'physics', 'chemistry', 'history', 'geography', 'algebra', 'calculus',
  'essay', 'homework', 'assignment', 'exam', 'syllabus',

  // General knowledge
  'capital of', 'president of', 'prime minister', 'population', 'country',
  'planet', 'solar system', 'universe', 'language', 'translate',

  // Travel
  'flight', 'hotel', 'booking', 'tourist', 'visa', 'passport', 'itinerary',

  // Shopping & products
  'buy', 'purchase', 'amazon', 'flipkart', 'discount', 'coupon', 'price of',

  // Social media
  'instagram', 'facebook', 'twitter', 'tiktok', 'snapchat', 'whatsapp',

  // Politics & religion
  'election', 'vote', 'political', 'party', 'government', 'policy',

  // Creative writing
  'write a story', 'write a poem', 'joke', 'riddle', 'tell me a story',

  // Weather (non-health context)
  'weather forecast', 'rain today', 'temperature outside',

  // Miscellaneous
  'recipe', 'cook', 'bake', 'restaurant', 'car', 'bike', 'vehicle',
  'real estate', 'property', 'rent', 'house',
]

// Check if message is health-related
function isHealthRelated(message: string): boolean {
  const lowerMessage = message.toLowerCase()
  return HEALTH_KEYWORDS.some(keyword => lowerMessage.includes(keyword))
}

// Check if message is clearly off-topic
function isOffTopicQuery(message: string): boolean {
  const lowerMessage = message.toLowerCase()

  // Short generic messages like "ok", "yes", "tell me more" — let the LLM handle via system prompt
  if (lowerMessage.trim().split(/\s+/).length <= 3) {
    return false
  }

  // If it contains health keywords, it's on-topic regardless
  if (isHealthRelated(message)) {
    return false
  }

  // Check for off-topic keywords
  return OFF_TOPIC_KEYWORDS.some(keyword => lowerMessage.includes(keyword))
}

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

// Food keywords for detecting food image analysis requests
const FOOD_KEYWORDS = [
  'food', 'meal', 'dish', 'cuisine', 'eat', 'calories', 'nutrition',
  'identify the food', 'what food', 'biryani', 'curry', 'rice', 'roti',
  'dosa', 'idli', 'snack', 'fruit', 'vegetable', 'breakfast', 'lunch',
  'dinner', 'serving', 'protein', 'carbs', 'fat', 'fiber', 'macros'
]

// Check if message is requesting food image analysis
function isFoodImageRequest(message: string): boolean {
  const lowerMessage = message.toLowerCase()
  return FOOD_KEYWORDS.some(keyword => lowerMessage.includes(keyword))
}

serve(async (req) => {
  try {
    const corsResponse = handleCors(req)
    if (corsResponse) return corsResponse

    const payload = await req.json()
    const { message, conversationHistory, imageData, forceModel, systemContext, healthContext } = payload

    // Family-member chats pass a structured "today's snapshot" via healthContext.
    // Merge it into systemContext so downstream chat functions consume one
    // unified context string. healthContext takes precedence (more recent /
    // member-specific data).
    const mergedSystemContext = [healthContext, systemContext]
      .filter(s => typeof s === 'string' && s.trim().length > 0)
      .join('\n\n')

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
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      })
    }

    // Determine which model to use
    let targetModel = 'minimax' // default
    let targetFunction = 'ai-chat'

    // Check for emergency first (always, regardless of forceModel)
    if (isEmergencyQuery(message)) {
      return new Response(JSON.stringify({
        response: "🚨 EMERGENCY DETECTED\n\nIf you or someone else is experiencing a medical emergency, please:\n\n1. Call emergency services immediately (911 in US, 112 in EU, 108 in India)\n2. Stay calm and follow dispatcher instructions\n3. Do not delay seeking professional help\n\nThis AI cannot provide emergency medical care. Your safety is the priority.",
        model: "emergency",
        isEmergency: true,
        disclaimer: "If this is a life-threatening emergency, call emergency services immediately."
      }), {
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      })
    }

    // Block off-topic messages before they reach any LLM
    if (isOffTopicQuery(message)) {
      console.log('=== OFF-TOPIC BLOCKED ===')
      console.log(`Message: ${message.substring(0, 100)}`)
      return new Response(JSON.stringify({
        response: "I'm Swastrica, your health assistant! 💚 I can only help with health and wellness topics like nutrition, fitness, symptoms, medications, mental health, and more.\n\nFeel free to ask me anything related to your well-being! 🌿",
        model: "off-topic-filter",
        isOffTopic: true
      }), {
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      })
    }

    // Check for forced model selection
    if (forceModel) {
      if (forceModel === 'medical' || forceModel === 'medgemma' || forceModel === 'medgemma-27b') {
        targetModel = 'minimax-medical'
        targetFunction = 'medgemma-chat'
      } else if (forceModel === 'medgemma-4b' || forceModel === 'medgemma-vision' || forceModel === 'vision') {
        targetModel = 'medgemma-vision'
        targetFunction = 'medgemma-vision'
      }
    } else {
      // Auto-detect based on content

      // Check for image data - route to MedGemma Vision (stays on Gemini)
      if (hasImageData(payload)) {
        targetModel = 'medgemma-vision'
        targetFunction = 'medgemma-vision'
      }
      // Check for medical keywords - route to medical chat (MiniMax with medical prompt)
      else if (isMedicalQuery(message)) {
        targetModel = 'minimax-medical'
        targetFunction = 'medgemma-chat'
      }
    }

    console.log('=== ROUTING DECISION ===')
    console.log(`Selected model: ${targetModel}`)
    console.log(`Target function: ${targetFunction}`)
    console.log(`Reason: ${hasImageData(payload) ? 'Image data present' : isMedicalQuery(message) ? 'Medical keywords detected' : 'General chat (default)'}`)

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
      ...(mergedSystemContext && { systemContext: mergedSystemContext }),
      ...(hasImageData(payload) && isFoodImageRequest(message) && { analysisType: 'food' }),
      routedFrom: 'ai-router',
      originalModel: targetModel
    }

    console.log('=== FORWARDING REQUEST ===')
    console.log(`URL: ${functionUrl}`)

    // Helper to call a downstream function with auth fallback
    const callFunction = async (url: string, body: object): Promise<Response> => {
      // First try with user's auth token
      const res = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': authHeader || `Bearer ${supabaseAnonKey}`,
          'apikey': supabaseAnonKey
        },
        body: JSON.stringify(body)
      })

      // If 401 (expired JWT), retry with anon key only
      if (res.status === 401 && authHeader) {
        console.log('Auth token rejected (401), retrying with anon key...')
        return await fetch(url, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${supabaseAnonKey}`,
            'apikey': supabaseAnonKey
          },
          body: JSON.stringify(body)
        })
      }

      return res
    }

    const response = await callFunction(functionUrl, forwardPayload)

    if (!response.ok) {
      const errorText = await response.text()
      console.error(`${targetFunction} error (${response.status}):`, errorText)

      // Fallback to general chat if medical chat fails
      if (targetModel === 'minimax-medical') {
        console.log('Falling back to general chat...')
        const fallbackResponse = await callFunction(
          `${supabaseUrl}/functions/v1/ai-chat`,
          { message, conversationHistory }
        )

        if (fallbackResponse.ok) {
          const fallbackData = await fallbackResponse.json()
          return new Response(JSON.stringify({
            ...fallbackData,
            model: 'minimax-fallback',
            note: 'Medical AI temporarily unavailable, using general AI'
          }), {
            headers: { 'Content-Type': 'application/json', ...corsHeaders },
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
      isMedical: targetModel === 'minimax-medical' || targetModel === 'medgemma-vision'
    }), {
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    })

  } catch (error) {
    console.error('Router error:', error)
    return new Response(JSON.stringify({
      response: "I'm having trouble processing your request. Please try again.",
      model: "error",
      error: true
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    })
  }
})
