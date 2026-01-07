import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

// APNS (Apple Push Notification Service) configuration
const APNS_KEY_ID = Deno.env.get('APNS_KEY_ID') || ''
const APNS_TEAM_ID = Deno.env.get('APNS_TEAM_ID') || ''
const APNS_TOPIC = Deno.env.get('APNS_TOPIC') || 'com.swastricare.mobile'
const APNS_KEY = Deno.env.get('APNS_KEY') || ''
const APNS_ENDPOINT = Deno.env.get('APNS_ENDPOINT') || 'https://api.sandbox.push.apple.com' // Use api.push.apple.com for production

interface HydrationData {
  user_id: string
  daily_goal: number
  current_intake: number
  effective_intake: number
  progress: number
  streak: number
}

interface NotificationPayload {
  aps: {
    alert: {
      title: string
      body: string
    }
    sound: string
    badge: number
    category: string
  }
  type: string
  progress: number
  remainingMl: number
}

serve(async (req) => {
  try {
    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Get current time info
    const now = new Date()
    const hour = now.getHours()
    const today = now.toISOString().split('T')[0]

    console.log(`🔔 Hydration reminder job started at ${now.toISOString()}`)

    // Skip during quiet hours (10 PM to 7 AM) - this is a default, user preferences override
    if (hour < 7 || hour >= 22) {
      console.log(`⏰ Quiet hours - skipping reminders`)
      return new Response(JSON.stringify({ message: 'Quiet hours', sent: 0 }), {
        headers: { 'Content-Type': 'application/json' }
      })
    }

    // Fetch users who need reminders
    // 1. Get all active users with push tokens
    const { data: pushTokens, error: tokensError } = await supabase
      .from('push_tokens')
      .select('user_id, device_token')
      .order('updated_at', { ascending: false })

    if (tokensError) {
      console.error('❌ Error fetching push tokens:', tokensError)
      throw tokensError
    }

    if (!pushTokens || pushTokens.length === 0) {
      console.log('ℹ️ No push tokens registered')
      return new Response(JSON.stringify({ message: 'No tokens', sent: 0 }), {
        headers: { 'Content-Type': 'application/json' }
      })
    }

    console.log(`📱 Found ${pushTokens.length} registered devices`)

    // 2. Get user hydration preferences
    const userIds = [...new Set(pushTokens.map(t => t.user_id))]
    const { data: preferences, error: prefsError } = await supabase
      .from('hydration_preferences')
      .select('*')
      .in('user_id', userIds)

    if (prefsError) {
      console.error('❌ Error fetching preferences:', prefsError)
    }

    // 3. Get today's hydration entries for all users
    const { data: entries, error: entriesError } = await supabase
      .from('hydration_entries')
      .select('user_id, amount_ml, drink_type, logged_at')
      .gte('logged_at', `${today}T00:00:00Z`)
      .lte('logged_at', `${today}T23:59:59Z`)
      .in('user_id', userIds)

    if (entriesError) {
      console.error('❌ Error fetching entries:', entriesError)
    }

    // Process each user
    const notifications: Array<{ deviceToken: string, payload: NotificationPayload }> = []
    
    for (const token of pushTokens) {
      const userId = token.user_id
      const userPrefs = preferences?.find(p => p.user_id === userId)
      const userEntries = entries?.filter(e => e.user_id === userId) || []

      // Calculate daily goal (simplified - default 2500ml)
      const dailyGoal = userPrefs?.custom_goal_ml || 2500

      // Calculate effective intake (with drink type multipliers)
      let effectiveIntake = 0
      for (const entry of userEntries) {
        const multiplier = getDrinkMultiplier(entry.drink_type)
        effectiveIntake += Math.floor(entry.amount_ml * multiplier)
      }

      const progress = Math.min(1.0, effectiveIntake / dailyGoal)
      const remainingMl = Math.max(0, dailyGoal - effectiveIntake)

      // Get user's streak from insights (simplified - just check yesterday)
      const streak = 1 // TODO: Calculate actual streak

      // Determine if user needs a reminder
      const needsReminder = shouldSendReminder(progress, hour)

      if (needsReminder) {
        const message = generateMessage(progress, remainingMl, effectiveIntake, dailyGoal, hour, streak)
        
        const payload: NotificationPayload = {
          aps: {
            alert: {
              title: message.title,
              body: message.body
            },
            sound: 'default',
            badge: 1,
            category: 'HYDRATION_REMINDER'
          },
          type: 'hydration_reminder',
          progress: Math.floor(progress * 100),
          remainingMl: remainingMl
        }

        notifications.push({
          deviceToken: token.device_token,
          payload
        })
      }
    }

    console.log(`📤 Sending ${notifications.length} notifications`)

    // Send notifications via APNS
    let sentCount = 0
    for (const notification of notifications) {
      try {
        await sendAPNSNotification(notification.deviceToken, notification.payload)
        sentCount++
      } catch (error) {
        console.error(`❌ Failed to send to ${notification.deviceToken}:`, error)
      }
    }

    console.log(`✅ Successfully sent ${sentCount}/${notifications.length} notifications`)

    return new Response(
      JSON.stringify({ 
        message: 'Reminders sent', 
        sent: sentCount,
        total: notifications.length 
      }), {
        headers: { 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('❌ Error in hydration-reminder function:', error)
    return new Response(
      JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      }
    )
  }
})

// Helper functions

function getDrinkMultiplier(drinkType: string): number {
  const multipliers: Record<string, number> = {
    water: 1.0,
    tea: 0.85,
    coffee: 0.8,
    juice: 0.9,
    milk: 0.9,
    sports_drink: 1.0,
    other: 0.9
  }
  return multipliers[drinkType] || 0.9
}

function shouldSendReminder(progress: number, hour: number): boolean {
  // Goal already met
  if (progress >= 1.0) {
    return false
  }

  // Behind schedule at noon
  if (hour >= 12 && progress < 0.3) {
    return true
  }

  // On track - send every 3 hours
  if (progress >= 0.3 && progress < 0.7 && hour % 3 === 0) {
    return true
  }

  // Ahead - send every 4 hours
  if (progress >= 0.7 && hour % 4 === 0) {
    return true
  }

  return false
}

function generateMessage(
  progress: number,
  remainingMl: number,
  effectiveIntake: number,
  dailyGoal: number,
  hour: number,
  streak: number
): { title: string, body: string } {
  const percent = Math.floor(progress * 100)
  
  // Goal met
  if (progress >= 1.0) {
    return {
      title: '🎉 Goal Achieved!',
      body: `You've reached your daily goal of ${effectiveIntake}ml! Keep it up!`
    }
  }

  // Morning (7-12)
  if (hour < 12) {
    if (progress < 0.3) {
      return {
        title: '☀️ Good Morning!',
        body: "Start your day with a glass of water 💧"
      }
    }
    return {
      title: '☕ Great Start!',
      body: `You're ${percent}% toward your goal! Keep it up!`
    }
  }

  // Afternoon (12-17)
  if (hour < 17) {
    if (progress < 0.3) {
      return {
        title: '🚨 Hydration Alert',
        body: `You're at ${percent}%. Time to catch up! ${remainingMl}ml to go.`
      }
    }
    return {
      title: '📊 Hydration Check',
      body: `You're ${percent}% toward your goal. ${remainingMl}ml remaining!`
    }
  }

  // Evening (17-22)
  if (progress < 0.5) {
    return {
      title: '⏰ Evening Reminder',
      body: `You still need ${remainingMl}ml. Let's reach that goal!`
    }
  }
  
  return {
    title: '🌆 Almost There!',
    body: `Just ${remainingMl}ml more to hit your goal!`
  }
}

async function sendAPNSNotification(deviceToken: string, payload: NotificationPayload): Promise<void> {
  // Generate JWT token for APNS authentication
  const jwt = await generateAPNSToken()

  const response = await fetch(
    `${APNS_ENDPOINT}/3/device/${deviceToken}`,
    {
      method: 'POST',
      headers: {
        'authorization': `bearer ${jwt}`,
        'apns-topic': APNS_TOPIC,
        'apns-push-type': 'alert',
        'apns-priority': '10',
        'content-type': 'application/json'
      },
      body: JSON.stringify(payload)
    }
  )

  if (!response.ok) {
    const error = await response.text()
    throw new Error(`APNS error: ${response.status} - ${error}`)
  }
}

async function generateAPNSToken(): Promise<string> {
  // For now, return a placeholder
  // In production, you would generate a proper JWT using the APNS key
  // This requires crypto libraries which are available in Deno
  
  // TODO: Implement proper JWT generation with APNS key
  // See: https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/establishing_a_token-based_connection_to_apns
  
  console.warn('⚠️ APNS JWT generation not implemented - using placeholder')
  return 'placeholder-jwt-token'
}
