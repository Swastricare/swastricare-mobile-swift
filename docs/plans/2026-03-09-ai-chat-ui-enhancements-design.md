# AI Chat Screen UI & Feature Enhancements — Design

**Date:** 2026-03-09
**Platform:** Android (Kotlin / Jetpack Compose)
**Files affected:** `AIScreen.kt`, `AIModels.kt`, `AIViewModel.kt`

## Overview

Improve the AI chat screen with polished animations, message interaction features, rich health metric cards, and image thumbnails in chat bubbles. All changes follow Approach A: layered additions with minimal model changes, no new files, no schema changes to the backend.

## Section 1 — Animations & Performance

### Bubble Entry Animation
- Wrap each `ChatBubble` in `AnimatedVisibility` with `slideInVertically + fadeIn`
- User bubbles slide in from the bottom-right, AI bubbles from the bottom-left
- Duration: 300ms, easing: `EaseOutQuart`
- Controlled by a `visible` state that starts `false` and flips to `true` in a `LaunchedEffect`

### Staggered Typing Dots
- Replace the current uniform pulse in `TypingIndicator` with `keyframes`-based animation
- Dot 1: delay 0ms, Dot 2: delay 150ms, Dot 3: delay 300ms
- Creates a natural left-to-right wave instead of all dots pulsing together

### Follow-Up Suggestion Chips
- After each AI response, a `LazyRow` of suggestion chips renders directly below the last AI bubble (inline in the message list, not in the input bar)
- Uses `AnimatedVisibility` with `fadeIn + expandVertically`
- Tapping a chip sets `inputText` and calls `sendMessage()` immediately
- Chips disappear when the next user message is sent
- The `followUpSuggestions` list is already generated in `AIViewModel` — just needs UI rendering

### Scroll-to-Bottom FAB
- A small `FloatingActionButton` (32dp, ghost glass style) appears via `AnimatedVisibility` when `listState.firstVisibleItemIndex < messages.size - 2`
- Positioned at bottom-end of the message list area
- Tapping it calls `listState.animateScrollToItem(messages.size - 1)`

### Markdown Improvements
- `parseMarkdown()` gains support for:
  - `# Heading` / `## Heading` → bold + increased font size (20sp / 17sp)
  - `- item` or `* item` → `• item` prefix
  - `` `code` `` → monospace typeface + `AppColors.primaryContainer` tinted background span
  - `*italic*` or `_italic_` → `FontStyle.Italic`
- Bold (`**text**`) already works, keep it

## Section 2 — Message Interactions (Feature A)

### Long-Press Context Menu
- `ChatBubble` uses `combinedClickable` to detect long-press
- On long-press, a local `var showMenu by remember { mutableStateOf(false) }` flips to `true`
- A `DropdownMenu` anchors to the bubble with 3 items:
  - **Copy** — `ClipboardManager.setText(message.content)`, calls `viewModel.onMessageCopied()` (triggers existing snackbar "Message copied")
  - **Share** — fires `Intent(Intent.ACTION_SEND)` with `message.content` as plain text
  - **Bookmark** (AI messages only) — calls `viewModel.onMessageBookmarked()` (snackbar "Message bookmarked")
- Menu appears with a subtle `scaleIn` from the long-press anchor point
- Both user and AI messages get Copy + Share; only AI messages get Bookmark

## Section 3 — Rich Health Cards (Feature B)

### Inline Health Insight Card
- After an AI bubble renders, the `ChatMessage` content is scanned with a pure string check for 2+ of: "steps", "heart rate", "sleep", "calories", "blood pressure", "weight"
- If matched AND `analysisState is AnalysisState.Completed`, a `HealthInsightCard` composable renders as a sibling below the AI bubble in the `Column` (not replacing the text)
- `HealthInsightCard` layout:
  - Glass card (existing `glass()` modifier), `AppColors.primaryContainer` tint
  - Header row: AutoAwesome icon + "Health Snapshot" label
  - 2×3 grid of metric tiles (icon + value + label), same data from `AnalysisState.Completed.result.metrics`
  - No new data fetching — reuses already-loaded analysis data
- If no analysis has run, no card renders (graceful no-op)

## Section 4 — Image Thumbnails in Chat (Feature C)

### Model Change
- `ChatMessage` gains one new nullable field: `imageUri: String? = null`
- `ChatMessage.userMessage()` gets an overload: `fun userMessage(content: String, imageUri: String?) = ChatMessage(..., imageUri = imageUri)`

### ViewModel Change
- In `sendImageForAnalysis(imageType)`, the user `ChatMessage` is created with `imageUri = _uiState.value.pendingImageUri`

### Bubble Rendering Change
- In `ChatBubble`, when `message.isUser && message.imageUri != null`:
  - Show a `coil` `AsyncImage` with rounded corners (12dp), max height 180dp, full bubble width
  - Below the image, show a small chip: `[image type label]` using `AppColors.primaryContainer` + `AppColors.primary` text
  - The text content (which currently says `[Image: X-Ray] Please analyze...`) is hidden
- Coil (`io.coil-kt:coil-compose`) is used — check if already in `build.gradle`; add if missing

## Out of Scope
- Bookmark persistence to database
- Real-time streaming of AI responses (token by token)
- Image capture from camera (existing gallery picker stays)
- Mode switching UI (General / Medical tabs already in ViewModel, out of scope for this task)
