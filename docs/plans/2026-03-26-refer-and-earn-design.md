# Refer & Earn — AI Access Gate Design

**Date:** 2026-03-26
**Platform:** iOS (Swift/SwiftUI) + Supabase backend
**Approach:** Supabase-only (no third-party attribution)

## Summary

SwasthiCare is free to use. To access the AI feature, users must refer one person who completes signup. Once the referred person signs up, the referrer gets lifetime AI access.

## Decisions

- Hybrid referral mechanism: unique deep link + manual code entry
- Referrer gets AI access as soon as referred person completes signup
- Refer exactly 1 person to unlock (no tiers, no leaderboard)
- Full block on AI tab until unlocked (no preview/soft gate)

## Database Schema

### New table: `referrals`

```sql
CREATE TABLE public.referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  referred_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  referral_code VARCHAR(8) NOT NULL,
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'completed')),
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Alter `users` table

```sql
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS ai_unlocked BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS referral_code VARCHAR(8) UNIQUE;
```

### RLS

- Users can read their own referral data
- Referral completion runs via SECURITY DEFINER function

## Referral Code Format

6 characters: first 3 from user's name (uppercased, padded with 'X' if short) + 3 random alphanumeric. Example: `SYA7K2`. Retry up to 3 times on collision.

## Flow

### Referrer (existing user)

1. Taps AI tab → sees AIReferralGateView (full block)
2. Taps "Share" → generates/retrieves referral code
3. iOS Share Sheet opens with message + deep link: `swastricareapp://referral?code=SYA7K2`

### Referred person

- **App installed:** Deep link opens app, code auto-filled in signup
- **App not installed:** Installs from App Store, enters code manually via "Have a referral code?" field on signup

### Completion trigger

1. Referred user completes signup
2. Server-side function: insert into `referrals` with status='completed', set `ai_unlocked = true` on referrer's `users` row
3. Referrer's next AI tab visit loads unlocked state

## iOS Architecture

### New files

| File | Purpose |
|------|---------|
| `Services/ReferralService.swift` | Protocol + Supabase CRUD for referral operations |
| `ViewModels/ReferralViewModel.swift` | Referral state, share action, code generation |
| `Views/AI/AIReferralGateView.swift` | Full-block gate screen on AI tab |

### Modified files

| File | Change |
|------|--------|
| `Views/AI/AIView.swift` | Wrap in `if aiUnlocked { chatView } else { AIReferralGateView }` |
| `Core/DependencyContainer.swift` | Add ReferralService + ReferralViewModel |
| `Helpers/DeepLinkHandler.swift` | Add `referral` route |
| `ViewModels/AuthViewModel.swift` | Apply pending referral code on signup |
| `App/swastricare_mobile_swiftApp.swift` | Pass referral deep link |

### Gate screen UI

- PremiumBackground gradient
- Sparkle/AI icon
- "Unlock SwasthiCare AI" title
- "Refer a friend to unlock AI — free, forever" subtitle
- Primary Share button (ScaleButtonStyle)
- Secondary "I have a referral code" link
- Referral code display with copy button

## Error Handling

| Scenario | Handling |
|----------|----------|
| Invalid referral code | Inline error, retry or skip |
| User tries own code | Server-side reject, "You can't refer yourself" |
| Duplicate referral | Idempotent, no duplicate row, still unlock |
| Network error | Cache `ai_unlocked` in UserDefaults, use offline |
| Race condition (multiple signups) | Both count, boolean flip is idempotent |
| Referred user deletes account | No rollback, referrer keeps AI |
| Code collision | Retry with different random suffix (up to 3) |

## Caching & Offline

- Fetch `ai_unlocked` from `users` table on auth, cache in UserDefaults
- AI tab checks cached value first (no flicker)
- Background refresh on app foreground
- `clearOnSignOut()` clears cached flag
