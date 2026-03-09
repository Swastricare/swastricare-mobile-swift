# AI Chat Screen — Glassmorphic Visual Redesign

**Goal:** Replace the flat, skeleton-like AI chat UI with a premium glassmorphic design that matches the app's existing visual language (PremiumBackground, glass() modifier, PremiumColor gradients).

**Platform:** Android (Jetpack Compose)

**Files:** `AIScreen.kt` (complete rewrite of visual layer), `Color.kt` and `Theme.kt` (reference only, no changes)

---

## Section 1 — Empty State (Intro View)

**AI Avatar:** 100dp circle with animated radial gradient (PrimaryColor → RoyalBlueEnd). Subtle pulse animation using `rememberInfiniteTransition` scaling between 1.0–1.06 over 3s. Centered "AI" icon inside (Icons.Rounded.AutoAwesome, white).

**Quick Action Grid:** 2×2 LazyVerticalGrid of glass cards. Each card uses the `glass()` modifier from HomeComponents.kt for the frosted semi-transparent look. Icon + title layout inside each card. Staggered entrance animation: each card fades+slides in with 80ms delay offset using `AnimatedVisibility` + `slideInVertically` + `fadeIn`.

**Welcome Text:** "How can I help you today?" in `TextSecondaryDark`/`TextSecondaryLight`, centered below avatar.

---

## Section 2 — Message Bubbles

**User Bubble:**
- `glass()` modifier base (semi-transparent surface with frosted border)
- Left border accent: 2dp vertical line in PrimaryColor on the leading edge
- Shape: `RoundedCornerShape(16.dp)` — uniform, no chat-tail asymmetry
- Text: `AppColors.onSurface` for readability
- Alignment: end-aligned with 48dp start padding

**AI Bubble:**
- Full-width, no bubble background — text renders directly on PremiumBackground
- Text: white with 0.95 alpha for contrast on dark gradient
- Markdown rendered inline (bold, code, italic, headers preserved from existing parseMarkdown)
- Alignment: start-aligned with 16dp horizontal padding

**Typing Indicator:**
- Glass pill shape (48×28dp) using `glass()` modifier
- Three dots with indigo (PrimaryColor) tint instead of grey
- Existing staggered keyframe animation preserved (DOT_CYCLE_MS=900, DOT_STAGGER_MS=150)

**Image Thumbnails (user bubbles):**
- Existing AsyncImage implementation preserved
- Rounded corners match bubble shape (16dp)
- Placed above text content inside the glass bubble

---

## Section 3 — Input Bar

**Container:** Glass bar pinned to bottom, `glass()` modifier, 56dp height, horizontal padding 12dp.

**Text Field:** Transparent background, no outline, placeholder "Ask anything..." in `AppColors.onSurfaceVariant`.

**Send Button:** 40dp circle with linear gradient fill (PrimaryColor → Color(0xFF7C3AED) violet). White arrow icon. `scaleIn` animation on appear when text is non-empty.

**Follow-Up Chips:** Row of glass pills above input bar when AI provides suggestions. Each chip uses `glass()` with PrimaryColor text. Horizontal scroll, 8dp spacing.

---

## Section 4 — Health Insight Card

**Enhancement to existing HealthInsightCard:**
- Keep glass() base from current implementation
- Add subtle radial gradient glow behind the card: `drawBehind` with `drawCircle` using PrimaryColor at 0.08 alpha, radius 200dp
- Metric values in PrimaryColor for emphasis
- Keep existing MetricChip layout

---

## Section 5 — Scroll FAB & History Sheet

**Scroll-to-Bottom FAB:**
- Glass circle (48dp) using `glass()` modifier
- Down-arrow icon in PrimaryColor
- Appears when scrolled up >2 items (existing derivedStateOf logic preserved)
- `scaleIn` + `fadeIn` entrance animation

**Chat History Sheet:**
- ModalBottomSheet with PremiumBackground inside
- Each history row uses `glass()` modifier
- Title + timestamp layout preserved
- Selected/current conversation highlighted with PrimaryColor left border (2dp)

---

## Design Principles

1. **glass() everywhere** — Every interactive surface uses the existing glass() modifier for visual consistency
2. **AI messages are borderless** — Only user messages get bubble treatment; AI text floats on the gradient
3. **PrimaryColor as accent** — Indigo used sparingly for borders, icons, interactive elements
4. **Existing logic preserved** — All animations (typewriter, dots), markdown parsing, ViewModel integration, message interactions (copy/share/bookmark) remain unchanged
5. **PremiumBackground as canvas** — The animated dark gradient is the base layer for the entire screen
