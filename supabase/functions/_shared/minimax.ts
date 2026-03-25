// Shared MiniMax API helper for Supabase Edge Functions
// All text-based AI functions use this to call MiniMax M2.5-highspeed

const MINIMAX_BASE_URL = Deno.env.get('MINIMAX_BASE_URL') || 'https://api.minimax.io/v1'
const MINIMAX_API_KEY = Deno.env.get('MINIMAX_API_KEY')
const MINIMAX_MODEL = Deno.env.get('MINIMAX_MODEL') || 'MiniMax-M2.5-highspeed'

export interface MiniMaxMessage {
  role: 'system' | 'user' | 'assistant'
  content: string
}

export interface MiniMaxOptions {
  temperature?: number
  maxTokens?: number
  responseFormat?: 'text' | 'json_object'
  timeoutMs?: number
}

/**
 * Call MiniMax chat completions API (OpenAI-compatible).
 * Returns the assistant's response text.
 */
export async function callMiniMax(
  messages: MiniMaxMessage[],
  options: MiniMaxOptions = {}
): Promise<string> {
  const {
    temperature = 0.7,
    maxTokens = 2048,
    responseFormat,
    timeoutMs = 60000,
  } = options

  // Try MiniMax first if key is available
  if (MINIMAX_API_KEY) {
    try {
      const result = await callMiniMaxDirect(messages, { temperature, maxTokens, responseFormat, timeoutMs })
      if (result) return result
    } catch (error) {
      console.error('MiniMax failed, falling back to Gemini:', error.message)
    }
  } else {
    console.log('MINIMAX_API_KEY not configured, using Gemini fallback')
  }

  // Fallback to Gemini
  return callGeminiFallback(messages, { temperature, maxTokens, timeoutMs })
}

async function callMiniMaxDirect(
  messages: MiniMaxMessage[],
  options: { temperature: number; maxTokens: number; responseFormat?: string; timeoutMs: number }
): Promise<string> {
  const controller = new AbortController()
  const timeoutId = setTimeout(() => controller.abort(), options.timeoutMs)

  try {
    const body: Record<string, unknown> = {
      model: MINIMAX_MODEL,
      messages,
      temperature: options.temperature,
      max_tokens: options.maxTokens,
      // Disable thinking to prevent <think> tags in response
      thinking: { type: "text" },
    }

    if (options.responseFormat === 'json_object') {
      body.response_format = { type: 'json_object' }
    }

    const response = await fetch(`${MINIMAX_BASE_URL}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${MINIMAX_API_KEY}`,
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    })

    clearTimeout(timeoutId)

    if (!response.ok) {
      const errorText = await response.text()
      console.error('MiniMax API error:', response.status, errorText)
      throw new Error(`MiniMax API error: ${response.status}`)
    }

    const data = await response.json()

    if (!data.choices?.[0]?.message?.content) {
      throw new Error('No response content from MiniMax')
    }

    // Strip thinking tags from response
    let content = data.choices[0].message.content.trim()
    content = content.replace(/<think>[\s\S]*?<\/think>/g, '').trim()

    return content
  } catch (error) {
    clearTimeout(timeoutId)
    if (error.name === 'AbortError') {
      throw new Error('MiniMax request timeout')
    }
    throw error
  }
}

async function callGeminiFallback(
  messages: MiniMaxMessage[],
  options: { temperature: number; maxTokens: number; timeoutMs: number }
): Promise<string> {
  const GOOGLE_AI_API_KEY = Deno.env.get('GOOGLE_AI_API_KEY')
  if (!GOOGLE_AI_API_KEY) {
    throw new Error('Neither MINIMAX_API_KEY nor GOOGLE_AI_API_KEY configured')
  }

  console.log('Using Gemini fallback...')

  const controller = new AbortController()
  const timeoutId = setTimeout(() => controller.abort(), options.timeoutMs)

  try {
    // Convert MiniMax messages to Gemini format
    const systemMessage = messages.find(m => m.role === 'system')?.content || ''
    const chatMessages = messages.filter(m => m.role !== 'system')

    const contents = chatMessages.map(msg => ({
      role: msg.role === 'assistant' ? 'model' : 'user',
      parts: [{ text: msg.content }]
    }))

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GOOGLE_AI_API_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          systemInstruction: systemMessage ? { parts: [{ text: systemMessage }] } : undefined,
          contents,
          generationConfig: {
            temperature: options.temperature,
            maxOutputTokens: options.maxTokens,
          }
        }),
        signal: controller.signal,
      }
    )

    clearTimeout(timeoutId)

    if (!response.ok) {
      const errorText = await response.text()
      console.error('Gemini API error:', response.status, errorText)
      throw new Error(`Gemini API error: ${response.status}`)
    }

    const data = await response.json()

    if (!data.candidates?.[0]?.content?.parts?.[0]?.text) {
      throw new Error('No response content from Gemini')
    }

    return data.candidates[0].content.parts[0].text.trim()
  } catch (error) {
    clearTimeout(timeoutId)
    if (error.name === 'AbortError') {
      throw new Error('Gemini request timeout')
    }
    throw error
  }
}

export { MINIMAX_MODEL }
