# Android Family Monitoring — Design

**Date:** 2026-05-12
**Platform:** Android (with shared Supabase backend changes)
**Status:** Approved

## Goal

Give the family owner (and caregivers, gated by permission bits) the ability to:
1. View any family member's vitals, medications, hydration, and vault from a per-member dashboard
2. Send push-notification nudges (preset + custom) to a member
3. Ask the in-app AI about a specific member using their health data as context
4. Get real-time push alerts when a member misses a medication
5. Customize alert preferences (caregiver-side) and the member's reminder schedules (member-side)

## Design Decisions

| # | Question | Decision |
|---|---|---|
| 1 | Who has monitoring powers? | Owner + Caregiver, using existing `family_members` permission bits (`can_view`, `can_edit`, `can_manage_members`) |
| 2 | UI shape | Dedicated per-member dashboard under the Family section; existing screens untouched |
| 3 | Push delivery | Real FCM end-to-end. `device_tokens` table + `send-family-nudge` edge function |
| 4 | Nudge taxonomy | Presets (one-tap) + optional free-form custom message |
| 5 | Missed-med detection | Server-side `pg_cron` job + edge function fans out FCM to all caregivers with `can_view` |
| 6 | Reminder customization scope | Both: caregiver-side alert preferences AND remote editing of the member's reminders (`can_edit`) |

## Architecture

### Client (Android)

**New surfaces**
- `FamilyMemberDashboardScreen` — per-member dashboard. Cards: today's vitals snapshot, today's medication doses with adherence ring, hydration progress, vault list (read-only), diet summary. Action row: **Nudge**, **Ask AI**, **Edit reminders**, **Alert prefs**.
- `FamilyNudgeSheet` — reusable bottom sheet showing preset chips + custom message field, dispatches via `FamilyNudgeRepository`.
- `FamilyMemberAIScreen` — variant of the AI chat scoped to a target `health_profile_id`; reuses `AIRepository` with a member-aware context builder.
- `FamilyAlertPreferencesScreen` — caregiver's per-member alert prefs: which alert types, quiet hours, missed-med grace minutes.
- `FamilyMemberRemindersScreen` — gated by `can_edit`. Lets the caregiver edit the member's medication schedule times, snooze duration, escalation policy.
- `FcmService` — `FirebaseMessagingService` subclass. Registers tokens on auth, handles inbound pushes, routes payloads to `NotificationService`.

**Reused (no breaking changes)**
- `MedicationRepositoryImpl`, `HydrationRepositoryImpl`, `HeartRateRepositoryImpl`, `SleepRepositoryImpl`, `VaultRepositoryImpl`, `DietRepository`, `AIRepository` — all already take `health_profile_id`. The dashboard simply passes the target member's id.
- `NotificationService` — extended with FCM message routing; the 8 existing channels cover all nudge types.
- `FamilyRepositoryImpl` + `has_family_access()` SQL — already enforces cross-member access.

**New repositories & use cases**
- `FamilyNudgeRepository` + `SendFamilyNudgeUseCase`
- `FamilyAlertPreferencesRepository` + `GetAlertPreferencesUseCase`, `UpdateAlertPreferencesUseCase`
- `DeviceTokenRepository` — register/refresh FCM token, deregister on logout
- `FamilyMemberContextBuilder` — builds an AI prompt context block from a target member's last-N days of vitals/meds/hydration

### Backend (Supabase)

**New tables**
- `device_tokens` — `(user_id, fcm_token, platform, app_version, updated_at)`, unique on `(user_id, fcm_token)`
- `family_alert_preferences` — `(caregiver_user_id, target_health_profile_id, missed_medication_alerts bool, low_hydration_alerts bool, missed_vitals_alerts bool, custom_nudge_alerts bool, quiet_hours_start time, quiet_hours_end time, missed_med_grace_minutes int default 30)`, PK `(caregiver_user_id, target_health_profile_id)`

**Updated tables**
- `health_nudges` — add `sender_user_id uuid null`, `recipient_user_id uuid` (already keyed to profile; we keep that and add explicit recipient user for push fan-out)
- RLS on `medical_documents` (Vault) — extend to allow access via `has_family_access(health_profile_id, 'view')`

**New edge functions**
- `send-family-nudge` — `POST { recipient_user_id, target_health_profile_id, preset_key | custom_message, category }`. Inserts `health_nudges` row, looks up recipient's `device_tokens`, respects quiet hours, calls FCM HTTP v1 with a payload that includes `notification` + `data` (deep link, category). Returns success/error per token.
- `detect-missed-medications` — invoked by `pg_cron` every 5 min. Finds `medication_logs` where `status='PENDING'` AND `scheduled_at < now() - grace_period`. For each: mark `MISSED`, look up family caregivers with `can_view=true`, fan out via `send-family-nudge` (skipping caregivers who disabled `missed_medication_alerts` for that member). De-duplicated by `medication_log_id` using a `missed_alert_sent_at` column.

**SQL function additions**
- Extend `has_family_access()` if needed to cover Vault.
- `pg_cron` schedule for `detect-missed-medications` every 5 min.

### Data Flow Examples

**Send a preset nudge**
```
Owner taps "💧 Drink water" on John's dashboard
  → FamilyNudgeRepository.sendNudge(target=John, preset=HYDRATION)
  → POST /functions/v1/send-family-nudge
  → Edge fn: insert health_nudges + lookup John's device_tokens + check quiet hours
  → FCM HTTP v1 push with data={ nudge_id, deep_link: "swastricareapp://nudge/{id}", category: hydration }
  → John's FcmService.onMessageReceived
  → NotificationService.show on CHANNEL_HYDRATION
  → John taps notification → DeepLinkHandler routes to in-app nudge sheet
```

**Missed medication alert**
```
pg_cron tick (every 5 min)
  → detect-missed-medications edge fn
  → SELECT medication_logs WHERE status='PENDING' AND scheduled_at < now() - grace
  → For each log: UPDATE status='MISSED', missed_alert_sent_at=now()
  → For each caregiver in family with can_view=true AND alert_prefs.missed_medication_alerts=true:
      → send-family-nudge(category=MEDICATION_MISSED)
  → Caregiver's phone receives FCM on CHANNEL_MEDICATION
```

### Permission & Privacy Model

- **View cards:** RLS via `has_family_access(profile_id, 'view')` — already wired for most tables.
- **Edit reminders:** RLS via `has_family_access(profile_id, 'edit')` — requires `can_edit=true` on the caregiver's `family_members` row.
- **Send nudges:** Edge function checks caller is an active member of the same family group as the recipient.
- **AI context:** Server-side context builder only pulls data accessible via `has_family_access` for the *calling* user — prevents prompt injection from exposing data the caller shouldn't see.
- **Quiet hours:** Edge function checks recipient's `quiet_hours_start/end`; if inside the window and not a critical category (medication-missed is always critical), defer (insert nudge row but skip FCM push). Recipient sees on next app open.

### Error Handling

- **FCM token missing/invalid:** Insert nudge anyway, return success with `delivered=false`; client picks up via in-app nudge list. Stale tokens auto-pruned by FCM `UNREGISTERED` response.
- **Recipient not in family / permission denied:** Edge function returns 403; client surfaces "You no longer have access to this member."
- **Cron job overlap:** `missed_alert_sent_at IS NULL` check prevents double-sending.
- **Quiet hours edge:** Crossing midnight handled (`start > end` interpreted as overnight window).
- **AI privacy leak:** Context builder always re-runs `has_family_access` checks server-side; never trust the client-passed `health_profile_id`.

### Testing

- Manual end-to-end on the user's OnePlus 8T (adb `acac8d4b`) with a second test account on the simulator/another device acting as the member.
- SQL: verify `detect-missed-medications` correctly picks up overdue PENDING logs and skips already-MISSED.
- FCM: verify push lands on a device with the app closed (force-stopped) — the hardest delivery case.
- Permission: log in as a non-family user and confirm dashboard requests 403 cleanly.
- Quiet hours: schedule a non-critical nudge inside the window — confirm no push, but the nudge appears in-app.

## Out of Scope (v1)

- iOS — design transfers, but implementation is Android-only this pass.
- Notification *snoozing/escalation chains* (e.g., re-nudge after 15 min if not acked).
- Editing a member's *non-medication* reminders (hydration cadence, diet logging prompts) — only medication reminders editable in v1.
- Group nudges (broadcasting to multiple members in one tap).
- Apple Watch / wearables companion alerts.

## Phasing

Single phase v1; everything ships together as agreed in brainstorming Q6.
