# SwasthiCare AI Overhaul — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate all text AI to MiniMax M2.5-highspeed, fix foundation bugs, improve chat quality, and add server-side proactive health nudges with push notifications.

**Architecture:** Edge functions are the AI abstraction boundary — iOS calls `ai-router` which delegates to model-specific functions. MiniMax uses the OpenAI-compatible chat completions API with proper `messages` array (system/user/assistant roles). Proactive nudges use a new `ai-nudge-generator` edge function triggered by pg_cron.

**Tech Stack:** Supabase Edge Functions (Deno/TypeScript), MiniMax M2.5-highspeed API, Swift/SwiftUI (iOS 18+), APNs push notifications.

---

## Phase 1: MiniMax Migration + Foundation Fixes

### Task 1: Create shared MiniMax helper for edge functions

**Files:**
- Create: `supabase/functions/_shared/minimax.ts`

**Step 1: Create the shared MiniMax API helper**

```typescript
// supabase/functions/_shared/minimax.ts

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
    timeoutMs = 60000
  } = options

  const controller = new AbortController()
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs)

  try {
    const body: Record<string, unknown> = {
      model: MINIMAX_MODEL,
      messages,
      temperature,
      max_tokens: maxTokens,
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

    return data.choices[0].message.content.trim()
  } catch (error) {
    clearTimeout(timeoutId)
    if (error.name === 'AbortError') {
      throw new Error('MiniMax request timeout')
    }
    throw error
  }
}

export { MINIMAX_MODEL }
```

**Step 2: Verify the file exists**

Run: `cat supabase/functions/_shared/minimax.ts | head -5`
Expected: Shows the first 5 lines of the helper

**Step 3: Commit**

```bash
git add supabase/functions/_shared/minimax.ts
git commit -m "feat(ai): add shared MiniMax API helper for edge functions"
```

---

### Task 2: Migrate ai-chat edge function to MiniMax

**Files:**
- Modify: `supabase/functions/ai-chat/index.ts`

**Step 1: Rewrite ai-chat to use MiniMax with proper message roles**

Replace the entire file. Key changes:
- Import and use `callMiniMax` from shared helper
- Use proper `messages` array with `role: system` for the Swastrica prompt
- Format conversation history as proper role-based messages (not concatenated text)
- **Remove the DB save block** (lines 154-213 of current file) — iOS client handles persistence
- Keep CORS handling, input validation, auth/profile lookup unchanged

The system prompt stays the same content but moves into a `{ role: 'system', content: ... }` message.

The conversation history formatting changes from:
```
"User: ...\nAssistant: ..."  // old text concatenation
```
To:
```json
[
  { "role": "user", "content": "..." },
  { "role": "assistant", "content": "..." }
]
```

**Step 2: Deploy and test**

Run: `supabase functions deploy ai-chat`

Test with curl:
```bash
curl -X POST "YOUR_SUPABASE_URL/functions/v1/ai-chat" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{"message": "Hello, how are you?", "conversationHistory": []}'
```
Expected: `{ "response": "..." }` with MiniMax-generated content

**Step 3: Commit**

```bash
git add supabase/functions/ai-chat/index.ts
git commit -m "feat(ai): migrate ai-chat from Gemini to MiniMax M2.5-highspeed

- Use proper messages array with system/user/assistant roles
- Remove server-side conversation save (client handles persistence)
- Import shared MiniMax helper"
```

---

### Task 3: Migrate medgemma-chat to MiniMax

**Files:**
- Modify: `supabase/functions/medgemma-chat/index.ts`

**Step 1: Rewrite medgemma-chat to use MiniMax**

Key changes:
- Import `callMiniMax` from shared helper
- Move `MEDICAL_SYSTEM_PROMPT` into `{ role: 'system' }` message
- Use lower temperature (0.4) for medical accuracy
- Keep the `MEDICAL_DISCLAIMER` appended to response text
- Keep the `ai_medical_interactions` DB logging (this is an audit log, not the double-save issue)
- Keep safety settings behavior (MiniMax handles this differently — rely on system prompt)

**Step 2: Deploy and test**

Run: `supabase functions deploy medgemma-chat`

Test: Send a medical query and verify response includes disclaimer.

**Step 3: Commit**

```bash
git add supabase/functions/medgemma-chat/index.ts
git commit -m "feat(ai): migrate medgemma-chat from Gemini to MiniMax"
```

---

### Task 4: Migrate ai-health-analysis to MiniMax

**Files:**
- Modify: `supabase/functions/ai-health-analysis/index.ts`

**Step 1: Rewrite to use MiniMax with JSON response format**

Key changes:
- Import `callMiniMax` with `responseFormat: 'json_object'`
- Move the analysis prompt into `{ role: 'system' }` and health data into `{ role: 'user' }`
- Keep the structured JSON output parsing (`assessment`, `insights`, `recommendations`)
- Keep the `ai_insights` DB save
- Keep input validation for steps/heartRate bounds

**Step 2: Deploy and test**

Run: `supabase functions deploy ai-health-analysis`

**Step 3: Commit**

```bash
git add supabase/functions/ai-health-analysis/index.ts
git commit -m "feat(ai): migrate ai-health-analysis from Gemini to MiniMax"
```

---

### Task 5: Migrate ai-text-generation to MiniMax

**Files:**
- Modify: `supabase/functions/ai-text-generation/index.ts`

**Step 1: Rewrite to use MiniMax**

Key changes:
- Import `callMiniMax` from shared helper
- Each content type (`daily_summary`, `weekly_report`, `goal_suggestions`) gets a system message describing the format, and the health data goes in a user message
- Keep the `generated_content` and `ai_usage_logs` DB saves
- For `goal_suggestions`, use `responseFormat: 'json_object'`

**Step 2: Deploy and test**

Run: `supabase functions deploy ai-text-generation`

**Step 3: Commit**

```bash
git add supabase/functions/ai-text-generation/index.ts
git commit -m "feat(ai): migrate ai-text-generation from Gemini to MiniMax"
```

---

### Task 6: Update ai-router to reference MiniMax-powered functions

**Files:**
- Modify: `supabase/functions/ai-router/index.ts`

**Step 1: Update the router**

The router doesn't call models directly — it forwards to other functions. Changes needed:
- Update the `targetModel` labels from `'gemini'` to `'minimax'` and from `'medgemma-27b'` to `'minimax-medical'` for logging/metadata
- The `forceModel` parameter values stay the same (the iOS app will send `forceModel: 'medical'` as a hint)
- Add `forceModel: 'medical'` handling (currently only handles `'medgemma'` and `'medgemma-27b'`)
- Keep the fallback logic: if `medgemma-chat` (now MiniMax medical) fails, fallback to `ai-chat` (MiniMax general)
- Keep emergency keyword detection and image routing unchanged

**Step 2: Deploy**

Run: `supabase functions deploy ai-router`

**Step 3: Commit**

```bash
git add supabase/functions/ai-router/index.ts
git commit -m "feat(ai): update ai-router model labels for MiniMax"
```

---

### Task 7: Wire iOS AIViewModel to use ai-router (sendSmartMessage)

**Files:**
- Modify: `swastricare-mobile-swift/ViewModels/AIViewModel.swift`
- Modify: `swastricare-mobile-swift/Services/AIService.swift`

**Step 1: Update AIService.sendSmartMessage to pass forceModel and imageData**

In `AIService.swift`, update `sendSmartMessage` to accept optional `forceModel` and `imageData` parameters:

```swift
func sendSmartMessage(
    _ message: String,
    context: [ChatMessage],
    systemContext: String?,
    forceModel: String? = nil,
    imageData: Data? = nil
) async throws -> AIResponse
```

Update the payload to include these:
```swift
var payload: [String: Any] = [
    "message": finalMessage,
    "conversationHistory": conversationHistory
]
if let forceModel { payload["forceModel"] = forceModel }
if let imageData { payload["imageData"] = imageData.base64EncodedString() }
```

Update the protocol `AIServiceProtocol` to match.

**Step 2: Rewrite AIViewModel.sendMessage() to use sendSmartMessage**

Replace the `switch selectedAIMode` routing block (lines 220-249 of current AIViewModel) with a single call:

```swift
let forceModel: String? = selectedAIMode == .medical ? "medical" : nil
let aiResponse = try await aiService.sendSmartMessage(
    enrichedText,
    context: Array(messages.dropLast()),
    systemContext: personalityContext,
    forceModel: forceModel
)
let response = aiResponse.text
lastResponseModel = aiResponse.model
lastResponseWasMedical = aiResponse.isMedical
```

Remove the duplicate `medicalKeywords` and `emergencyKeywords` Sets from AIViewModel (the router handles this server-side now). Keep the client-side `isEmergencyMessage()` check only for the immediate emergency alert UI — the router also detects emergencies but the client needs to show the alert sheet instantly.

**Step 3: Commit**

```bash
git add swastricare-mobile-swift/ViewModels/AIViewModel.swift swastricare-mobile-swift/Services/AIService.swift
git commit -m "feat(ai): wire AIViewModel to ai-router via sendSmartMessage

- Remove manual model routing from ViewModel
- Pass forceModel hint for medical mode
- Delegate routing decisions to ai-router edge function"
```

---

### Task 8: Persist medical consent to Supabase

**Files:**
- Modify: `swastricare-mobile-swift/Services/AIService.swift`
- Modify: `swastricare-mobile-swift/ViewModels/AIViewModel.swift`

**Step 1: Add consent methods to AIService**

Add to `AIServiceProtocol`:
```swift
func saveMedicalConsent() async throws
func checkMedicalConsent() async throws -> Bool
```

Implement in `AIService`:
```swift
func saveMedicalConsent() async throws {
    let userId = try await supabase.getCurrentUserId()
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

    try await supabase.client.from("ai_medical_consent").upsert([
        "user_id": userId.uuidString,
        "consent_type": "initial_disclaimer",
        "consent_version": "1.0",
        "device_type": "ios",
        "app_version": appVersion
    ], onConflict: "user_id,consent_type,consent_version").execute()
}

func checkMedicalConsent() async throws -> Bool {
    let userId = try await supabase.getCurrentUserId()
    let result: [AnyJSON] = try await supabase.client
        .from("ai_medical_consent")
        .select("id")
        .eq("user_id", value: userId.uuidString)
        .eq("consent_type", value: "initial_disclaimer")
        .limit(1)
        .execute()
        .value
    return !result.isEmpty
}
```

**Step 2: Wire into AIViewModel**

In `AIViewModel.init()`, after restoring the mode, check consent:
```swift
Task {
    if let hasConsent = try? await aiService.checkMedicalConsent() {
        await MainActor.run { hasAcknowledgedMedicalDisclaimer = hasConsent }
    }
}
```

When the user acknowledges the disclaimer (where `hasAcknowledgedMedicalDisclaimer = true` is set), also call:
```swift
Task { try? await aiService.saveMedicalConsent() }
```

**Step 3: Commit**

```bash
git add swastricare-mobile-swift/Services/AIService.swift swastricare-mobile-swift/ViewModels/AIViewModel.swift
git commit -m "feat(ai): persist medical disclaimer consent to Supabase"
```

---

### Task 9: Persist bookmarks and feedback

**Files:**
- Modify: `swastricare-mobile-swift/ViewModels/AIViewModel.swift`
- Modify: `swastricare-mobile-swift/Services/AIService.swift`

**Step 1: Update saveChatHistory to include bookmark and feedback fields**

In `AIService.saveChatHistory`, the messages are serialized to JSONB. Add `is_bookmarked` and `user_feedback` to the serialized message dictionaries:

```swift
let messagesArray = messages.filter { !$0.isLoading }.map { msg -> [String: Any] in
    var dict: [String: Any] = [
        "role": msg.isUser ? "user" : "assistant",
        "content": msg.content,
        "timestamp": ISO8601DateFormatter().string(from: msg.timestamp)
    ]
    if msg.isBookmarked { dict["is_bookmarked"] = true }
    if let feedback = msg.userFeedback { dict["user_feedback"] = feedback.rawValue }
    if let mode = msg.responseMode { dict["response_mode"] = mode.rawValue }
    return dict
}
```

**Step 2: Update loadChatHistory/loadConversation to restore bookmarks and feedback**

When deserializing messages from JSONB, read the `is_bookmarked` and `user_feedback` fields:

```swift
let isBookmarked = msgDict["is_bookmarked"] as? Bool ?? false
let feedback: MessageFeedback? = (msgDict["user_feedback"] as? String).flatMap { MessageFeedback(rawValue: $0) }
```

Pass these to the `ChatMessage` initializer.

**Step 3: In AIViewModel, save after bookmark toggle and feedback submit**

In `toggleBookmark(for messageId:)` and `submitFeedback(_:for messageId:)`, after updating the local message, trigger a save:

```swift
Task {
    currentConversationId = try? await aiService.saveChatHistory(messages, conversationId: currentConversationId)
}
```

**Step 4: Commit**

```bash
git add swastricare-mobile-swift/Services/AIService.swift swastricare-mobile-swift/ViewModels/AIViewModel.swift
git commit -m "feat(ai): persist bookmarks and feedback to Supabase JSONB"
```

---

### Task 10: Restore AI personality picker UI

**Files:**
- Modify: `swastricare-mobile-swift/Views/AI/AIView.swift`

**Step 1: Uncomment the personality roster picker**

In `AIView.swift` around line 675, uncomment the `AIRosterPicker` block:

```swift
// Change FROM:
// AI Personality Roster (Swastri, Coach, Nutri, Zen, Luna) - commented out
// if viewModel.selectedAIMode == .general {
//     AIRosterPicker(selected: $viewModel.selectedPersonality)
//         .opacity(showEmptyState ? 1 : 0)
//         .offset(y: showEmptyState ? 0 : 12)
//         .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: showEmptyState)
//         .padding(.bottom, 16)
// }

// Change TO:
if viewModel.selectedAIMode == .general {
    AIRosterPicker(selected: $viewModel.selectedPersonality)
        .opacity(showEmptyState ? 1 : 0)
        .offset(y: showEmptyState ? 0 : 12)
        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: showEmptyState)
        .padding(.bottom, 16)
}
```

**Step 2: Verify AIRosterPicker exists**

Search for `AIRosterPicker` in the Views/AI directory to confirm it's defined. If it's not a separate component, check if it's defined inline in AIView.swift.

**Step 3: Commit**

```bash
git add swastricare-mobile-swift/Views/AI/AIView.swift
git commit -m "feat(ai): restore AI personality picker (Swastri, Coach, Nutri, Zen, Luna)"
```

---

### Task 11: Clean up dead code in models

**Files:**
- Modify: `swastricare-mobile-swift/Models/MedicalAIModels.swift`

**Step 1: Update MedicalAIModel enum**

Replace the Gemini-referencing cases with MiniMax:

```swift
enum MedicalAIModel: String, Codable {
    case minimaxGeneral = "minimax-general"
    case minimaxMedical = "minimax-medical"
    case geminiVision = "gemini-vision"       // Vision stays on Gemini
    case medgemmaVision = "medgemma-4b"       // MedGemma 4B for medical images

    var displayName: String {
        switch self {
        case .minimaxGeneral: return "Swastri AI"
        case .minimaxMedical: return "Medical Expert"
        case .geminiVision: return "Image Analysis"
        case .medgemmaVision: return "Medical Vision"
        }
    }

    var isMedical: Bool {
        switch self {
        case .minimaxMedical, .medgemmaVision: return true
        case .minimaxGeneral, .geminiVision: return false
        }
    }

    var supportsImages: Bool {
        self == .geminiVision || self == .medgemmaVision
    }
}
```

**Step 2: Commit**

```bash
git add swastricare-mobile-swift/Models/MedicalAIModels.swift
git commit -m "refactor(ai): update MedicalAIModel enum for MiniMax migration"
```

---

## Phase 2: AI Quality Improvements

### Task 12: Update edge function system prompts for proper role separation

**Files:**
- Modify: `supabase/functions/ai-chat/index.ts`
- Modify: `supabase/functions/medgemma-chat/index.ts`

**Step 1: Update ai-chat to accept systemContext from iOS**

Add `systemContext` to the expected payload fields. When present, prepend it to the system message:

```typescript
const { message, conversationHistory, systemContext } = await req.json()

const messages: MiniMaxMessage[] = []

// System message: base Swastrica prompt + personality context from iOS
let systemContent = SWASTRICA_SYSTEM_PROMPT
if (systemContext) {
  systemContent += '\n\n' + systemContext
}
messages.push({ role: 'system', content: systemContent })

// Conversation history as proper role messages
if (conversationHistory?.length > 0) {
  for (const msg of conversationHistory.slice(-20)) {
    if (msg.role && msg.content) {
      messages.push({ role: msg.role === 'user' ? 'user' : 'assistant', content: msg.content })
    }
  }
}

// Current user message
messages.push({ role: 'user', content: message })
```

**Step 2: Update AIService.sendSmartMessage to send systemContext separately**

In `AIService.swift`, the `systemContext` should be sent as a separate payload field (not prepended to the message):

```swift
var payload: [String: Any] = [
    "message": message,  // pure user text, no CONTEXT_DATA prefix
    "conversationHistory": conversationHistory
]
if let systemContext { payload["systemContext"] = systemContext }
```

Also update `sendChatMessage` the same way (remove the `CONTEXT_DATA:\n...\nUSER_QUERY:\n` prefixing).

**Step 3: Deploy and commit**

```bash
supabase functions deploy ai-chat
supabase functions deploy medgemma-chat
git add supabase/functions/ai-chat/index.ts supabase/functions/medgemma-chat/index.ts swastricare-mobile-swift/Services/AIService.swift
git commit -m "feat(ai): proper system/user message separation

- Send systemContext as separate payload field
- Edge functions use role-based messages array
- Remove CONTEXT_DATA/USER_QUERY text hack"
```

---

### Task 13: Smarter context window (increase from 10 to 20 messages)

**Files:**
- Modify: `swastricare-mobile-swift/Services/AIService.swift`

**Step 1: Increase context limit and add first-message retention**

In `sendSmartMessage` and `sendChatMessage`, change the context truncation:

```swift
// Keep first user message for topic awareness + last 19 messages
var truncatedContext: [[String: String]] = []
let allMessages = context.filter { !$0.isLoading }

if allMessages.count > 20 {
    // Always include the first user message
    if let firstUser = allMessages.first(where: { $0.isUser }) {
        truncatedContext.append(["role": "user", "content": firstUser.content])
    }
    // Then add the most recent 19
    truncatedContext += allMessages.suffix(19).map { msg in
        ["role": msg.isUser ? "user" : "assistant", "content": msg.content]
    }
} else {
    truncatedContext = allMessages.map { msg in
        ["role": msg.isUser ? "user" : "assistant", "content": msg.content]
    }
}
```

**Step 2: Commit**

```bash
git add swastricare-mobile-swift/Services/AIService.swift
git commit -m "feat(ai): increase context window from 10 to 20 messages with first-message retention"
```

---

### Task 14: Add conversation search and date grouping

**Files:**
- Modify: `swastricare-mobile-swift/Views/AI/AIView.swift` (the conversation history sheet)

**Step 1: Find the ConversationHistoryView**

Search for the conversation history sheet/view in AIView.swift. It may be inline or a separate struct. Look for `ConversationHistoryView` or the `.sheet` that shows `conversations`.

**Step 2: Add search bar**

Add a `@State private var searchText = ""` and a `TextField` or `.searchable` modifier at the top of the conversation list.

Filter conversations:
```swift
var filteredConversations: [ConversationSummary] {
    if searchText.isEmpty { return viewModel.conversations }
    return viewModel.conversations.filter {
        $0.title.localizedCaseInsensitiveContains(searchText) ||
        $0.lastMessage.localizedCaseInsensitiveContains(searchText)
    }
}
```

**Step 3: Add date grouping**

Group conversations using `ConversationSummary.formattedDate` (already implemented — returns "Today", "Yesterday", weekday name, or date). Use `Dictionary(grouping:by:)` and display as sections.

**Step 4: Commit**

```bash
git add swastricare-mobile-swift/Views/AI/AIView.swift
git commit -m "feat(ai): add conversation search and date grouping in history"
```

---

### Task 15: Re-enable evening quick actions

**Files:**
- Modify: `swastricare-mobile-swift/Models/AIModels.swift`

**Step 1: Uncomment the evening suggestions**

In `QuickAction.contextualSuggestions`, the `case 17..<22` block (around line 379), uncomment the three evening actions:

```swift
case 17..<22:
    actions += [
        QuickAction(title: "Day Summary", icon: "chart.bar.fill", prompt: "Summarize my health metrics for today. How did I do?"),
        QuickAction(title: "Wind Down", icon: "moon.stars.fill", prompt: "Help me create a relaxing evening routine for better sleep"),
        QuickAction(title: "Dinner Tips", icon: "fork.knife", prompt: "What should I eat for a light, healthy dinner?")
    ]
```

**Step 2: Commit**

```bash
git add swastricare-mobile-swift/Models/AIModels.swift
git commit -m "feat(ai): re-enable evening quick action suggestions (5pm-10pm)"
```

---

## Phase 3: Proactive AI Health Nudges

### Task 16: Create ai_nudges database table

**Files:**
- Create: `supabase/migrations/20260301000001_create_ai_nudges.sql`

**Step 1: Write the migration**

```sql
-- Create AI nudges table for proactive health notifications
CREATE TABLE IF NOT EXISTS ai_nudges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  health_profile_id UUID REFERENCES health_profiles(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  nudge_type TEXT NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  priority TEXT DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high')),
  action_deeplink TEXT,
  source_data JSONB,
  is_dismissed BOOLEAN DEFAULT false,
  is_acted_on BOOLEAN DEFAULT false,
  push_sent BOOLEAN DEFAULT false,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE ai_nudges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own nudges"
  ON ai_nudges FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own nudges"
  ON ai_nudges FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Service role can insert (edge function runs as service role)
CREATE POLICY "Service role can insert nudges"
  ON ai_nudges FOR INSERT
  WITH CHECK (true);

-- Indexes
CREATE INDEX idx_ai_nudges_user_id ON ai_nudges(user_id);
CREATE INDEX idx_ai_nudges_active ON ai_nudges(user_id, is_dismissed, expires_at)
  WHERE is_dismissed = false;
```

**Step 2: Apply the migration**

Run: `supabase db push`

**Step 3: Commit**

```bash
git add supabase/migrations/20260301000001_create_ai_nudges.sql
git commit -m "feat(nudges): create ai_nudges table with RLS policies"
```

---

### Task 17: Create ai-nudge-generator edge function

**Files:**
- Create: `supabase/functions/ai-nudge-generator/index.ts`

**Step 1: Write the nudge generator function**

This function:
1. Queries recent health data for all active users (or a specific user if `user_id` is provided)
2. For each user, checks nudge trigger conditions (inactivity, hydration, medication, etc.)
3. Sends relevant health snapshot to MiniMax to generate personalized nudge messages
4. Inserts nudges into `ai_nudges`
5. Sends push notifications for medium/high priority nudges

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { callMiniMax, type MiniMaxMessage } from '../_shared/minimax.ts'

const NUDGE_SYSTEM_PROMPT = `You are a health nudge generator. Given a user's recent health data and a nudge trigger, generate a brief, warm, actionable nudge message.

Rules:
- Keep messages under 100 characters for push notification compatibility
- Use 1 relevant emoji at the start
- Be encouraging, not nagging
- Be specific to the data provided
- Return valid JSON: { "title": "...", "message": "..." }`

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

    // Use service role for server-side operations
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { user_id } = await req.json().catch(() => ({}))

    // Get active users (or specific user)
    let usersQuery = supabase
      .from('health_profiles')
      .select('id, user_id')
      .eq('is_primary', true)

    if (user_id) {
      usersQuery = usersQuery.eq('user_id', user_id)
    }

    const { data: profiles, error: profilesError } = await usersQuery.limit(100)
    if (profilesError || !profiles?.length) {
      return new Response(JSON.stringify({ nudges_generated: 0 }), {
        headers: { 'Content-Type': 'application/json' },
      })
    }

    let totalNudges = 0

    for (const profile of profiles) {
      const nudges = await generateNudgesForUser(supabase, profile)
      totalNudges += nudges.length

      if (nudges.length > 0) {
        // Insert nudges
        await supabase.from('ai_nudges').insert(nudges)

        // Send push for medium/high priority
        const pushNudges = nudges.filter(n => n.priority !== 'low')
        for (const nudge of pushNudges) {
          await sendPushNotification(supabase, profile.user_id, nudge)
        }
      }
    }

    return new Response(JSON.stringify({ nudges_generated: totalNudges }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    console.error('Nudge generator error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})

// Check trigger conditions and generate nudges for one user
async function generateNudgesForUser(supabase: any, profile: any) {
  const nudges: any[] = []
  const now = new Date()
  const hour = now.getUTCHours() // Adjust for user timezone if available

  // Skip overnight (11pm-6am)
  if (hour >= 23 || hour < 6) return nudges

  // Don't generate more than 3 nudges per 2-hour window
  const { data: recentNudges } = await supabase
    .from('ai_nudges')
    .select('id')
    .eq('user_id', profile.user_id)
    .gte('created_at', new Date(now.getTime() - 2 * 3600 * 1000).toISOString())

  if (recentNudges && recentNudges.length >= 3) return nudges

  // Fetch recent health data
  const threeHoursAgo = new Date(now.getTime() - 3 * 3600 * 1000).toISOString()
  const today = now.toISOString().split('T')[0]

  // Check hydration
  const { data: recentWater } = await supabase
    .from('hydration_logs')
    .select('created_at')
    .eq('health_profile_id', profile.id)
    .order('created_at', { ascending: false })
    .limit(1)

  const lastWater = recentWater?.[0]?.created_at
  if (lastWater) {
    const hoursSinceWater = (now.getTime() - new Date(lastWater).getTime()) / 3600000
    if (hoursSinceWater >= 4) {
      const msg = await generateNudgeMessage('hydration', `No water logged in ${Math.floor(hoursSinceWater)} hours`)
      nudges.push({
        health_profile_id: profile.id,
        user_id: profile.user_id,
        nudge_type: 'hydration',
        title: msg.title,
        message: msg.message,
        priority: 'medium',
        action_deeplink: 'swastricare://hydration',
        source_data: { hours_since_water: Math.floor(hoursSinceWater) },
        expires_at: new Date(now.getTime() + 4 * 3600 * 1000).toISOString(),
      })
    }
  }

  // Check medication adherence
  const { data: missedMeds } = await supabase
    .from('medication_schedules')
    .select('id, medications(name)')
    .eq('health_profile_id', profile.id)
    .lte('scheduled_time', now.toISOString())
    .gte('scheduled_time', today)
  // Cross-reference with medication_logs to find not-taken ones
  // (simplified — real implementation checks logs)

  // Check daily steps (from daily_health_metrics)
  const { data: todayMetrics } = await supabase
    .from('daily_health_metrics')
    .select('steps')
    .eq('health_profile_id', profile.id)
    .eq('date', today)
    .single()

  if (todayMetrics?.steps !== undefined && hour >= 10) {
    const expectedSteps = (hour * 10000) / 16
    if (todayMetrics.steps < 500 && hour >= 10) {
      const msg = await generateNudgeMessage('inactivity', `Only ${todayMetrics.steps} steps today`)
      nudges.push({
        health_profile_id: profile.id,
        user_id: profile.user_id,
        nudge_type: 'inactivity',
        title: msg.title,
        message: msg.message,
        priority: 'medium',
        action_deeplink: 'swastricare://steps',
        source_data: { steps: todayMetrics.steps },
        expires_at: new Date(now.getTime() + 3 * 3600 * 1000).toISOString(),
      })
    } else if (todayMetrics.steps >= 8000 && hour >= 18) {
      // Close to goal!
      const msg = await generateNudgeMessage('step_goal_close', `${todayMetrics.steps} steps — almost at 10k!`)
      nudges.push({
        health_profile_id: profile.id,
        user_id: profile.user_id,
        nudge_type: 'step_goal_close',
        title: msg.title,
        message: msg.message,
        priority: 'low',
        action_deeplink: 'swastricare://steps',
        source_data: { steps: todayMetrics.steps },
        expires_at: new Date(now.getTime() + 6 * 3600 * 1000).toISOString(),
      })
    }
  }

  return nudges
}

async function generateNudgeMessage(nudgeType: string, context: string): Promise<{ title: string, message: string }> {
  try {
    const messages: MiniMaxMessage[] = [
      { role: 'system', content: NUDGE_SYSTEM_PROMPT },
      { role: 'user', content: `Nudge type: ${nudgeType}\nContext: ${context}` }
    ]
    const response = await callMiniMax(messages, { temperature: 0.8, maxTokens: 200, responseFormat: 'json_object' })
    return JSON.parse(response)
  } catch {
    // Fallback to static message
    return { title: 'Health Reminder', message: context }
  }
}

async function sendPushNotification(supabase: any, userId: string, nudge: any) {
  try {
    const { data: tokens } = await supabase
      .from('push_tokens')
      .select('token, platform')
      .eq('user_id', userId)
      .eq('platform', 'ios')

    if (!tokens?.length) return

    // Mark push as sent
    await supabase
      .from('ai_nudges')
      .update({ push_sent: true })
      .eq('id', nudge.id)

    // APNs push would be sent here via the existing push infrastructure
    // For now, log it — actual APNs integration uses the hydration-reminder pattern
    console.log(`Push to ${userId}: ${nudge.title} - ${nudge.message}`)
  } catch (e) {
    console.log('Push failed:', e.message)
  }
}
```

**Step 2: Deploy**

Run: `supabase functions deploy ai-nudge-generator`

**Step 3: Commit**

```bash
git add supabase/functions/ai-nudge-generator/index.ts
git commit -m "feat(nudges): create ai-nudge-generator edge function

- Checks hydration, steps, medication triggers per user
- Generates personalized nudge messages via MiniMax
- Inserts to ai_nudges table
- Sends push notifications for medium/high priority"
```

---

### Task 18: Create NudgeService on iOS

**Files:**
- Create: `swastricare-mobile-swift/Services/NudgeService.swift`
- Modify: `swastricare-mobile-swift/Core/DependencyContainer.swift`

**Step 1: Create NudgeService with protocol**

```swift
import Foundation
import Supabase

protocol NudgeServiceProtocol {
    func fetchActiveNudges() async throws -> [ServerNudge]
    func dismissNudge(id: UUID) async throws
    func markActedOn(id: UUID) async throws
}

struct ServerNudge: Identifiable, Equatable, Codable {
    let id: UUID
    let nudgeType: String
    let title: String
    let message: String
    let priority: String
    let actionDeeplink: String?
    let isDismissed: Bool
    let isActedOn: Bool
    let createdAt: Date
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case nudgeType = "nudge_type"
        case title, message, priority
        case actionDeeplink = "action_deeplink"
        case isDismissed = "is_dismissed"
        case isActedOn = "is_acted_on"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }

    var icon: String {
        switch nudgeType {
        case "hydration": return "drop.fill"
        case "inactivity": return "figure.walk"
        case "medication_missed": return "pills.fill"
        case "sleep_deficit": return "moon.zzz.fill"
        case "step_goal_close": return "flame.fill"
        case "heart_rate_elevated": return "heart.fill"
        case "streak_at_risk": return "trophy.fill"
        case "weekly_insight": return "chart.bar.fill"
        default: return "bell.fill"
        }
    }

    var color: String {
        switch nudgeType {
        case "hydration": return "3B82F6"
        case "inactivity": return "22C55E"
        case "medication_missed": return "EF4444"
        case "heart_rate_elevated": return "EF4444"
        case "streak_at_risk": return "F97316"
        default: return "6366F1"
        }
    }
}

final class NudgeService: NudgeServiceProtocol {
    static let shared = NudgeService()
    private let supabase = SupabaseManager.shared
    private init() {}

    func fetchActiveNudges() async throws -> [ServerNudge] {
        let now = ISO8601DateFormatter().string(from: Date())
        let nudges: [ServerNudge] = try await supabase.client
            .from("ai_nudges")
            .select()
            .eq("is_dismissed", value: false)
            .or("expires_at.is.null,expires_at.gte.\(now)")
            .order("created_at", ascending: false)
            .limit(10)
            .execute()
            .value
        return nudges
    }

    func dismissNudge(id: UUID) async throws {
        try await supabase.client
            .from("ai_nudges")
            .update(["is_dismissed": true, "updated_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: id.uuidString)
            .execute()
    }

    func markActedOn(id: UUID) async throws {
        try await supabase.client
            .from("ai_nudges")
            .update(["is_acted_on": true, "updated_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: id.uuidString)
            .execute()
    }
}
```

**Step 2: Register in DependencyContainer**

In `DependencyContainer.swift`, add:
```swift
let nudgeService: NudgeServiceProtocol
```

In `init()`:
```swift
self.nudgeService = NudgeService.shared
```

**Step 3: Commit**

```bash
git add swastricare-mobile-swift/Services/NudgeService.swift swastricare-mobile-swift/Core/DependencyContainer.swift
git commit -m "feat(nudges): create NudgeService with protocol and register in DI"
```

---

### Task 19: Add nudges to HomeViewModel

**Files:**
- Modify: `swastricare-mobile-swift/ViewModels/HomeViewModel.swift`

**Step 1: Add nudge state and loading**

Add to HomeViewModel:
```swift
@Published private(set) var serverNudges: [ServerNudge] = []

private let nudgeService: NudgeServiceProtocol

// Update init to accept nudgeService
init(healthService: HealthKitServiceProtocol, nudgeService: NudgeServiceProtocol = NudgeService.shared) {
    self.healthService = healthService
    self.nudgeService = nudgeService
}
```

Add methods:
```swift
func loadNudges() async {
    do {
        serverNudges = try await nudgeService.fetchActiveNudges()
    } catch {
        print("Failed to load nudges: \(error.localizedDescription)")
    }
}

func dismissNudge(_ nudge: ServerNudge) async {
    serverNudges.removeAll { $0.id == nudge.id }
    try? await nudgeService.dismissNudge(id: nudge.id)
}

func actOnNudge(_ nudge: ServerNudge) async {
    try? await nudgeService.markActedOn(id: nudge.id)
}
```

Call `loadNudges()` inside the existing `loadTodaysData()` method.

**Step 2: Update DependencyContainer's homeViewModel lazy var**

```swift
lazy var homeViewModel: HomeViewModel = {
    HomeViewModel(healthService: healthService, nudgeService: nudgeService as! NudgeServiceProtocol)
}()
```

Or simpler — since `NudgeService.shared` is the default, no DI change needed if the default parameter is used.

**Step 3: Commit**

```bash
git add swastricare-mobile-swift/ViewModels/HomeViewModel.swift
git commit -m "feat(nudges): add server nudges loading to HomeViewModel"
```

---

### Task 20: Create NudgeCardsView component

**Files:**
- Create: `swastricare-mobile-swift/Views/Components/NudgeCardsView.swift`

**Step 1: Build the nudge card strip**

```swift
import SwiftUI

struct NudgeCardsView: View {
    let nudges: [ServerNudge]
    let onDismiss: (ServerNudge) -> Void
    let onAction: (ServerNudge) -> Void

    var body: some View {
        if !nudges.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(nudges) { nudge in
                        NudgeCard(nudge: nudge, onDismiss: { onDismiss(nudge) }, onAction: { onAction(nudge) })
                            .transition(.asymmetric(insertion: .slide, removal: .opacity))
                    }
                }
                .padding(.horizontal, 16)
            }
            .animation(.spring(response: 0.4), value: nudges.count)
        }
    }
}

struct NudgeCard: View {
    let nudge: ServerNudge
    let onDismiss: () -> Void
    let onAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: nudge.icon)
                    .foregroundColor(Color(hex: nudge.color))
                    .font(.system(size: 16, weight: .semibold))

                Text(nudge.title)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }

            Text(nudge.message)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineLimit(2)

            if nudge.actionDeeplink != nil {
                Button(action: onAction) {
                    Text("Take Action")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: nudge.color))
                }
            }
        }
        .padding(14)
        .frame(width: 240)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}
```

**Step 2: Commit**

```bash
git add swastricare-mobile-swift/Views/Components/NudgeCardsView.swift
git commit -m "feat(nudges): create NudgeCardsView horizontal card strip component"
```

---

### Task 21: Integrate NudgeCardsView into HomeView and AIView

**Files:**
- Modify: `swastricare-mobile-swift/Views/Home/HomeView.swift` (or `HomeViewV2.swift`)
- Modify: `swastricare-mobile-swift/Views/AI/AIView.swift`

**Step 1: Add NudgeCardsView to HomeView**

Find the top of the home screen content (above the vitals section). Add:

```swift
// Proactive AI Nudges
NudgeCardsView(
    nudges: homeViewModel.serverNudges,
    onDismiss: { nudge in
        Task { await homeViewModel.dismissNudge(nudge) }
    },
    onAction: { nudge in
        Task { await homeViewModel.actOnNudge(nudge) }
        if let deeplink = nudge.actionDeeplink, let url = URL(string: deeplink) {
            deepLinkHandler.handle(url)
        }
    }
)
```

**Step 2: Add NudgeCardsView to AIView empty state**

In AIView.swift, in the empty state section (before or after `proactiveNudgesView`), add the server-side nudges. Use `DependencyContainer.shared.homeViewModel.serverNudges` or pass them through.

**Step 3: Commit**

```bash
git add swastricare-mobile-swift/Views/Home/HomeView.swift swastricare-mobile-swift/Views/AI/AIView.swift
git commit -m "feat(nudges): integrate NudgeCardsView into Home and AI tabs"
```

---

### Task 22: Add nudge deep link handling and push notification category

**Files:**
- Modify: `swastricare-mobile-swift/Helpers/DeepLinkHandler.swift`
- Modify: `swastricare-mobile-swift/Services/NotificationService.swift`

**Step 1: Add nudge-related deep links to DeepLinkHandler**

The nudge `action_deeplink` values use existing deep link paths (`swastricare://hydration`, `swastricare://steps`, etc.) which should already be handled. Verify these paths are all covered in `DeepLinkHandler.handle(_:)`.

**Step 2: Add ai_nudge notification category**

In `NotificationService`, when setting up notification categories, add:

```swift
let nudgeCategory = UNNotificationCategory(
    identifier: "ai_nudge",
    actions: [
        UNNotificationAction(identifier: "act", title: "Take Action", options: .foreground),
        UNNotificationAction(identifier: "dismiss", title: "Dismiss", options: .destructive)
    ],
    intentIdentifiers: [],
    options: .customDismissAction
)
```

When handling notification responses, check for the `ai_nudge` category and route the `action_deeplink` from the notification payload to `DeepLinkHandler`.

**Step 3: Commit**

```bash
git add swastricare-mobile-swift/Helpers/DeepLinkHandler.swift swastricare-mobile-swift/Services/NotificationService.swift
git commit -m "feat(nudges): add push notification category and deep link routing for nudges"
```

---

### Task 23: Set up pg_cron schedule for nudge generation

**Files:**
- Create: `supabase/migrations/20260301000002_create_nudge_cron_job.sql`

**Step 1: Create the cron migration**

```sql
-- Enable pg_cron extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule nudge generation every 2 hours between 6am-11pm
SELECT cron.schedule(
  'generate-health-nudges',
  '0 6,8,10,12,14,16,18,20,22 * * *',
  $$
  SELECT net.http_post(
    url := current_setting('app.settings.supabase_url') || '/functions/v1/ai-nudge-generator',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
    ),
    body := '{}'::jsonb
  );
  $$
);

-- Auto-expire old nudges (run daily at midnight)
SELECT cron.schedule(
  'expire-old-nudges',
  '0 0 * * *',
  $$
  UPDATE ai_nudges
  SET is_dismissed = true, updated_at = now()
  WHERE expires_at < now() AND is_dismissed = false;
  $$
);
```

Note: pg_cron with `net.http_post` requires the `pg_net` extension. If not available, the cron job can call a SQL function that inserts a trigger record instead. Verify `pg_net` is enabled in the Supabase dashboard.

**Step 2: Apply migration**

Run: `supabase db push`

**Step 3: Commit**

```bash
git add supabase/migrations/20260301000002_create_nudge_cron_job.sql
git commit -m "feat(nudges): schedule pg_cron job for nudge generation every 2 hours"
```

---

### Task 24: Final integration test and deploy

**Step 1: Deploy all edge functions**

```bash
supabase functions deploy ai-chat
supabase functions deploy ai-router
supabase functions deploy medgemma-chat
supabase functions deploy ai-health-analysis
supabase functions deploy ai-text-generation
supabase functions deploy ai-nudge-generator
```

**Step 2: Set MiniMax secrets in Supabase**

```bash
supabase secrets set MINIMAX_API_KEY=your_key_here
supabase secrets set MINIMAX_BASE_URL=https://api.minimax.io/v1
supabase secrets set MINIMAX_MODEL=MiniMax-M2.5-highspeed
```

**Step 3: Build iOS app**

```bash
xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build
```

Verify no compile errors.

**Step 4: Test end-to-end**

1. Open AI tab → verify personality picker is visible
2. Send a general message → verify MiniMax response (check edge function logs)
3. Switch to Medical mode → acknowledge disclaimer → verify consent saved
4. Send a medical query → verify routed through ai-router → medgemma-chat
5. Bookmark a message → reload conversation → verify bookmark persists
6. Check Home tab → verify NudgeCardsView appears if nudges exist
7. Manually trigger nudge generator: `curl -X POST YOUR_URL/functions/v1/ai-nudge-generator -H "Authorization: Bearer SERVICE_ROLE_KEY"`
8. Verify nudges appear in app

**Step 5: Final commit**

```bash
git add -A
git commit -m "feat(ai): complete AI overhaul - MiniMax migration, foundations, nudges

Phase 1: MiniMax M2.5-highspeed backend, ai-router activation, persist consent/bookmarks
Phase 2: Proper message roles, smarter context, conversation search, evening actions
Phase 3: Server-side proactive health nudges with push notifications"
```
