# WhatsApp Nudge Delivery Design

**Goal:** Send proactive health nudges to users via WhatsApp using WaSenderAPI, alongside existing push notifications.

**Approach:** Extend the existing `ai-nudge-generator` edge function (Approach A — inline, no new functions).

## Provider

- **WaSenderAPI** (wasenderapi.com) — unofficial WhatsApp API, no Meta approval needed
- Endpoint: `POST https://wasenderapi.com/api/send-message`
- Auth: `Bearer {WASENDER_API_KEY}` header
- JID format: `{phone_digits}@s.whatsapp.net`
- Supabase secret: `WASENDER_API_KEY`

## Data Flow

1. `ai-nudge-generator` generates nudge → inserts into `ai_nudges`
2. Checks `user_settings.whatsapp_nudges_enabled` for the user
3. If enabled, fetches `users.phone`, formats JID, sends via WaSenderAPI
4. Marks `ai_nudges.whatsapp_sent = true`
5. Errors are logged but don't block other nudges

## Database Changes

- `user_settings`: add `whatsapp_nudges_enabled BOOLEAN DEFAULT false`
- `ai_nudges`: add `whatsapp_sent BOOLEAN DEFAULT false`

## iOS Changes

- Add a toggle in notification settings: "WhatsApp Nudges"
- Reads/writes `user_settings.whatsapp_nudges_enabled` via Supabase
- If no phone number on file, prompt user to add one first

## Opt-in

- In-app toggle (Settings > Notifications)
- All nudge priority levels sent to WhatsApp
- Respects existing quiet hours

## Error Handling

- 5-second timeout on WaSenderAPI calls
- try/catch per user — failures don't block other users
- Log errors, continue processing
