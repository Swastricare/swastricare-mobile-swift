# Vault Screen UI Redesign - Design Document

**Date:** 2026-03-09
**Platform:** Android (Kotlin/Jetpack Compose)

## Summary

Redesign the Vault document upload and detail experience to be more professional, add appointment reminders with notifications, fix broken MoreVert menu, add shimmer loading, improve the detail sheet with hero image preview, add edit capabilities, and integrate an "Ask AI" feature for document analysis.

## Changes

### 1. Shimmer/Skeleton Loading

Replace `CircularProgressIndicator` with shimmer skeleton cards matching document card layout. Show 3-4 animated placeholder cards while loading. Use a `shimmerBrush` composable with infinite animation on a linear gradient.

### 2. Document Detail Sheet - Redesigned

Layout (top to bottom):
- **Hero image/PDF preview**: full-width, rounded top corners, ~200dp. PDFs show styled icon card.
- **Title + category chip**: bold title, colored category pill
- **Metadata section**: doctor name, appointment date, location (primary). File size, type, upload date (secondary/de-emphasized).
- **Notes/Tags section**: expandable if present
- **Action buttons row**: "View Full", "Ask AI", "Edit", "Delete"

View mode and edit mode toggle within the same sheet.

### 3. Edit Mode in Detail Sheet

Editable fields: title, category (dropdown), notes, tags (chip input), appointment date (date picker), doctor name, location. Save/Cancel buttons at bottom. Triggered by Edit action from sheet or MoreVert menu.

### 4. Ask AI (Inline + Navigate)

- "Ask AI" button sends document image to AI router via existing `AIConversationRepository`
- Shows inline loading shimmer, then brief AI summary card
- "Continue in AI Chat" link navigates to AI screen with document context pre-loaded
- Uses existing `ai-router` edge function (image analysis routes to MedGemma 4B)

### 5. Appointment Date & Notifications

- Date picker in edit mode for appointment date
- On save, schedule two notifications via `AlarmManager` with `BroadcastReceiver`:
  - 1 day before appointment
  - 1 hour before appointment
- New notification channel: `vault_appointment` in `NotificationService`
- Cancel existing notifications when appointment date is updated or removed
- Notification content: "Appointment tomorrow: {document title}" / "Appointment in 1 hour: {document title}"

### 6. MoreVert Menu - Fixed

Replace empty `onMoreClick` callback with `DropdownMenu`:
- **View**: opens document viewer (signed URL)
- **Edit**: opens detail sheet in edit mode
- **Delete**: shows confirmation dialog, then deletes

### 7. Upload Sheet Polish

- Cleaner layout with file type icon + filename + formatted size
- Category selector as horizontal chips
- File size/type shown smaller, not priority views

## Files to Modify

| File | Changes |
|------|---------|
| `VaultScreen.kt` | Shimmer loading, MoreVert dropdown, upload sheet improvements |
| `VaultComponents.kt` | Shimmer composables, updated DocumentCard with working menu |
| `DocumentDetailSheet.kt` | Full redesign: hero image, edit mode, Ask AI, appointment date |
| `AddDocumentSheet.kt` | Polished upload UI with chip category selector |
| `VaultViewModel.kt` | AI analysis state, appointment scheduling, edit state |
| `MedicalDocument.kt` | Verify appointmentDate/reminderDate fields are used |
| `NotificationService.kt` | New vault_appointment channel |
| New: `VaultNotificationReceiver.kt` | BroadcastReceiver for appointment reminders |
| New: `ShimmerEffect.kt` | Reusable shimmer/skeleton composables |
| `AndroidManifest.xml` | Register BroadcastReceiver |

## Non-Goals

- No changes to iOS vault screen
- No changes to Supabase schema (appointmentDate field already exists)
- No changes to AI router edge function
