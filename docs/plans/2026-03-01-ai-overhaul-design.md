# SwasthiCare AI Overhaul — Design Document

**Date:** 2026-03-01
**Approach:** Phased (Fix foundations → Quality improvements → Proactive nudges)
**Default AI Model:** MiniMax M2.5-highspeed (`https://api.minimax.io/v1`)
**Vision Model:** Stays on Gemini/MedGemma (MiniMax doesn't support vision)

---

## Phase 1: MiniMax Migration + Foundation Fixes

### 1.1 MiniMax Backend Migration

Replace Gemini with MiniMax M2.5-highspeed in all text-based edge functions:

| Function | Current Model | New Model |
|----------|--------------|-----------|
| `ai-chat` | `gemini-3-flash-preview` | `MiniMax-M2.5-highspeed` |
| `ai-router` | routes to others | routes to others (same logic) |
| `medgemma-chat` | `gemini-2.0-flash-exp` | `MiniMax-M2.5-highspeed` (medical prompt) |
| `ai-health-analysis` | `gemini-3-flash-preview` | `MiniMax-M2.5-highspeed` |
| `ai-text-generation` | `gemini-pro` | `MiniMax-M2.5-highspeed` |
| `medgemma-vision` | MedGemma 4B / Gemini Flash | **No change** (vision) |
| `ai-image-analysis` | `gemini-1.5-flash` | **No change** (vision) |

API integration via OpenAI-compatible endpoint:
- `POST https://api.minimax.io/v1/chat/completions`
- `Authorization: Bearer $MINIMAX_API_KEY`
- Standard `messages` array with `role: system/user/assistant`

New Supabase secrets: `MINIMAX_API_KEY`, `MINIMAX_BASE_URL`, `MINIMAX_MODEL`.

### 1.2 Activate ai-router as Single Entry Point

**Current (broken):** AIViewModel manually routes `.general` → `ai-chat`, `.medical` → `ai-chat` (with medical prompt), image → `medgemma-vision`. The `ai-router` edge function exists but is never called. `sendSmartMessage()` in AIService exists but is never called.

**New:** AIViewModel always calls `aiService.sendSmartMessage()` → `ai-router` → auto-routes:
- Emergency keywords → immediate response (no model call)
- Image data present → `medgemma-vision` (Gemini)
- Medical keywords OR `forceModel: "medical"` → `medgemma-chat` (MiniMax with medical prompt)
- Default → `ai-chat` (MiniMax)

The mode selector (General/Medical) becomes a hint passed to `ai-router` via `forceModel` parameter. The ViewModel's routing logic (`sendMessage()`) simplifies to a single `sendSmartMessage()` call.

### 1.3 Fix Double-Save Race Condition

Remove the conversation upsert from `ai-chat` edge function. `AIService.saveChatHistory()` on the iOS side is the single source of truth for conversation persistence. Edge functions return response text only.

### 1.4 Persist Medical Consent

On disclaimer acknowledgment, insert into `ai_medical_consent` table:
```sql
INSERT INTO ai_medical_consent (user_id, consent_type, consent_version, device_type, app_version)
VALUES ($1, 'initial_disclaimer', '1.0', 'ios', $2)
ON CONFLICT (user_id, consent_type, consent_version) DO NOTHING;
```

On app launch (when authenticated), query this table to pre-set `hasAcknowledgedMedicalDisclaimer`. Returning users skip the disclaimer.

### 1.5 Persist Bookmarks and Feedback

Add `is_bookmarked` and `user_feedback` fields to the messages JSONB array inside `ai_conversations`. When toggling a bookmark or submitting feedback, update the conversation record via `AIService`.

### 1.6 Restore AI Personality Picker

Uncomment the personality roster UI in AIView. The 5 personalities (Swastri, Coach, Nutri, Zen, Luna) are already defined with system prompts in `AIModels.swift` — just needs the UI selector back.

---

## Phase 2: AI Quality Improvements

### 2.1 Proper System/User Message Separation

Use MiniMax's `messages` format with explicit roles:
```json
{
  "messages": [
    { "role": "system", "content": "[personality prompt + health context]" },
    { "role": "user", "content": "original user message" },
    { "role": "assistant", "content": "previous response" },
    { "role": "user", "content": "new user message" }
  ]
}
```

Eliminates the `CONTEXT_DATA:` / `USER_QUERY:` text-level hack.

### 2.2 Smarter Context Window

Replace hard-coded 10-message limit with token-aware truncation. Keep system prompt + recent messages within ~6000 tokens. Always include the first user message for topic awareness. MiniMax M2.5 supports up to 1M tokens but staying lean keeps responses fast and cost-effective.

### 2.3 Conversation Search and Filter

Add search bar to `ConversationHistoryView` — client-side text filtering on conversation titles. Add date grouping: Today, This Week, This Month, Older.

### 2.4 Re-enable Evening Quick Actions

Uncomment the evening slot (5pm–10pm) quick actions: Day Summary, Wind Down Tips, Dinner Ideas. Currently only late-night (10pm+) has suggestions.

### 2.5 Rewrite System Prompts for MiniMax

Tune all prompts for MiniMax M2.5 behavior:
- More concise instructions (MiniMax responds well to direct guidance)
- Explicit output format guidance
- Maintain SwasthiCare personality voice
- This is iterative — initial rewrite then tune based on response quality

---

## Phase 3: Proactive AI Health Nudges

### 3.1 Architecture

```
Supabase pg_cron (every 2 hours)
  → ai-nudge-generator edge function
    → Query recent health data for active users
    → Send to MiniMax with nudge system prompt
    → Parse structured JSON response
    → Save to ai_nudges table
    → Send push notifications for high/medium priority nudges via APNs
```

### 3.2 Nudge Types

| Type | Trigger | Priority | Push? |
|------|---------|----------|-------|
| `inactivity` | <500 steps in last 3 hours (daytime) | medium | yes |
| `hydration` | No water logged in 4+ hours | medium | yes |
| `medication_missed` | Scheduled med not marked taken | high | yes |
| `sleep_deficit` | <6h sleep 2+ consecutive nights | medium | no |
| `step_goal_close` | 80%+ of daily goal by 6pm | low | no |
| `heart_rate_elevated` | Resting HR trend >10% above baseline | high | yes |
| `streak_at_risk` | Active streak breaks if no action today | medium | yes |
| `weekly_insight` | End-of-week health summary | low | no |

### 3.3 Database: `ai_nudges` Table

```sql
CREATE TABLE ai_nudges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  health_profile_id UUID REFERENCES health_profiles(id),
  user_id UUID REFERENCES auth.users(id),
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
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE ai_nudges ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own nudges" ON ai_nudges
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update own nudges" ON ai_nudges
  FOR UPDATE USING (auth.uid() = user_id);
```

### 3.4 New Edge Function: `ai-nudge-generator`

- Triggered by pg_cron every 2 hours (or Supabase webhook)
- Queries `daily_health_metrics`, `hydration_logs`, `medication_logs`, `vital_signs`, `user_streaks` for each active user
- Sends health snapshot to MiniMax with a nudge-specific system prompt requesting structured JSON output
- Parses response into individual nudge records
- Inserts into `ai_nudges`
- For high/medium priority nudges: sends push notification via APNs using tokens from `push_tokens` table

### 3.5 iOS Components

**`NudgeCardsView`** — horizontal scrollable card strip:
- Shown on HomeView (above vitals section) and AIView (above quick actions when no messages)
- Each card: icon (by nudge type), title, message, action button (deep-links via `action_deeplink`), dismiss button
- Cards fade out on dismiss with animation

**`NudgeService`** — new service conforming to `NudgeServiceProtocol`:
- Polls `ai_nudges` for non-dismissed, non-expired nudges on app foreground
- Methods: `fetchActiveNudges()`, `dismissNudge(id:)`, `markActedOn(id:)`
- Added to `DependencyContainer`

**HomeViewModel integration:**
- New `@Published var nudges: [HealthNudge]` property
- Loads nudges on `loadTodaysData()`
- No new ViewModel needed — integrates into existing HomeViewModel

**Push notifications:**
- New notification category `ai_nudge` with `action_deeplink` in payload
- `NotificationService` handles routing tapped nudge notifications to `DeepLinkHandler`

---

## Files Changed Summary

### Phase 1
- `supabase/functions/ai-chat/index.ts` — MiniMax API, remove DB save
- `supabase/functions/ai-router/index.ts` — MiniMax API
- `supabase/functions/medgemma-chat/index.ts` — MiniMax API
- `supabase/functions/ai-health-analysis/index.ts` — MiniMax API
- `supabase/functions/ai-text-generation/index.ts` — MiniMax API
- `swastricare-mobile-swift/ViewModels/AIViewModel.swift` — route through sendSmartMessage, persist consent/bookmarks/feedback
- `swastricare-mobile-swift/Services/AIService.swift` — activate sendSmartMessage, add consent/bookmark persistence methods
- `swastricare-mobile-swift/Views/AI/AIView.swift` — uncomment personality picker, wire consent persistence
- `swastricare-mobile-swift/Models/AIModels.swift` — clean up dead MedicalAIModel enum

### Phase 2
- Edge functions — proper messages array format, update system prompts
- `AIViewModel.swift` — smarter context truncation
- `AIView.swift` — search bar in history sheet, evening quick actions
- `Views/AI/ConversationHistoryView.swift` (or equivalent) — search + date grouping

### Phase 3
- New migration: `create_ai_nudges` table
- New edge function: `supabase/functions/ai-nudge-generator/index.ts`
- New: `swastricare-mobile-swift/Services/NudgeService.swift`
- New: `swastricare-mobile-swift/Views/Components/NudgeCardsView.swift`
- Modified: `Core/DependencyContainer.swift` — add NudgeService
- Modified: `ViewModels/HomeViewModel.swift` — nudges property
- Modified: `Views/Home/HomeView.swift` — NudgeCardsView integration
- Modified: `Views/AI/AIView.swift` — NudgeCardsView in empty state
- Modified: `Services/NotificationService.swift` — ai_nudge category
- Modified: `Helpers/DeepLinkHandler.swift` — nudge deep link handling
