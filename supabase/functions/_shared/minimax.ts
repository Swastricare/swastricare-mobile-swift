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
  if (!MINIMAX_API_KEY) {
    throw new Error('MINIMAX_API_KEY not configured')
  }

  const {
    temperature = 0.7,
    maxTokens = 2048,
    responseFormat,
    timeoutMs = 60000,
  } = options

  const controller = new AbortController()
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs)

  try {
    const body: Record<string, unknown> = {
      model: MINIMAX_MODEL,
      messages,
      temperature,
      max_tokens: maxTokens,
      // Disable thinking to prevent <think> tags in response
      thinking: { type: "text" },
    }

    if (responseFormat === 'json_object') {
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

export { MINIMAX_MODEL }
