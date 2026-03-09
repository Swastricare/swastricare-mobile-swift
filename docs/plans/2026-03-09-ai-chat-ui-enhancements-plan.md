# AI Chat Screen UI & Feature Enhancements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Polish the Android AI chat screen with entry animations, staggered typing dots, inline follow-up chips, scroll-to-bottom FAB, rich markdown, long-press message actions, inline health metric cards, and image thumbnails inside chat bubbles.

**Architecture:** Approach A — all changes are additive overlays on the existing `AIScreen.kt` + `AIModels.kt` + `AIViewModel.kt`. No new files. No backend changes. One small nullable field added to `ChatMessage`.

**Tech Stack:** Kotlin, Jetpack Compose, Material3, Coil (already in build.gradle at 2.5.0), Android ClipboardManager, Android Intent

---

## Task 1: Staggered Typing Indicator Dots

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIScreen.kt` (the `TypingIndicator` composable, ~lines 387–403)

**Context:** The current `TypingIndicator` has all 3 dots share the same `alpha` value — they pulse in unison. Replace this with 3 separate phase-offset animations to create a wave.

**Step 1: Replace the `TypingIndicator` composable**

Find the existing `TypingIndicator` function (starts at `fun TypingIndicator()`) and replace it entirely with:

```kotlin
@Composable
fun TypingIndicator() {
    val transition = rememberInfiniteTransition(label = "typing")

    @Composable
    fun dot(delayMillis: Int): Float {
        val alpha by transition.animateFloat(
            initialValue = 0.3f,
            targetValue = 1f,
            animationSpec = infiniteRepeatable(
                animation = keyframes {
                    durationMillis = 900
                    0.3f at delayMillis using LinearEasing
                    1f at delayMillis + 300 using LinearEasing
                    0.3f at delayMillis + 600 using LinearEasing
                    0.3f at 900 using LinearEasing
                },
                repeatMode = RepeatMode.Restart
            ),
            label = "dot$delayMillis"
        )
        return alpha
    }

    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        val a1 = dot(0)
        val a2 = dot(200)
        val a3 = dot(400)
        Box(modifier = Modifier.size(8.dp).background(AppColors.onSurfaceVariant.copy(alpha = a1), CircleShape))
        Box(modifier = Modifier.size(8.dp).background(AppColors.onSurfaceVariant.copy(alpha = a2), CircleShape))
        Box(modifier = Modifier.size(8.dp).background(AppColors.onSurfaceVariant.copy(alpha = a3), CircleShape))
    }
}
```

**Step 2: Build and verify**

```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -20
```

Expected: `BUILD SUCCESSFUL`

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIScreen.kt
git commit -m "feat(android/ai): staggered wave animation for typing indicator dots"
```

---

## Task 2: Chat Bubble Entry Animations

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIScreen.kt` (the `ChatBubble` composable, ~lines 254–296)

**Context:** Bubbles currently appear instantly. We want each bubble to slide up and fade in when it first appears.

**Step 1: Add `AnimatedVisibility` wrapper to `ChatBubble`**

At the top of `ChatBubble`, add a `visible` state that starts `false` and immediately flips `true` via `LaunchedEffect`. Wrap the entire `Column` with `AnimatedVisibility`. User bubbles slide from the right; AI bubbles from the left.

Replace the entire `ChatBubble` composable with:

```kotlin
@Composable
fun ChatBubble(message: ChatMessage, onAnimationComplete: () -> Unit = {}) {
    val isUser = message.isUser
    val align = if (isUser) Alignment.End else Alignment.Start
    val bgColor = if (isUser) AppColors.primaryContainer else AppColors.surfaceVariant
    val textColor = if (isUser) AppColors.onPrimaryContainer else AppColors.onSurfaceVariant
    val shape = if (isUser) RoundedCornerShape(20.dp, 4.dp, 20.dp, 20.dp) else RoundedCornerShape(4.dp, 20.dp, 20.dp, 20.dp)

    var visible by remember { mutableStateOf(false) }
    LaunchedEffect(message.id) { visible = true }

    AnimatedVisibility(
        visible = visible,
        enter = slideInVertically(
            initialOffsetY = { it / 2 },
            animationSpec = tween(300, easing = FastOutSlowInEasing)
        ) + fadeIn(animationSpec = tween(300))
    ) {
        Column(modifier = Modifier.fillMaxWidth(), horizontalAlignment = align) {
            if (!isUser) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Icon(Icons.Default.AutoAwesome, contentDescription = null, modifier = Modifier.size(12.dp), tint = AppColors.primary)
                    Text("Swastri", style = MaterialTheme.typography.labelSmall, color = AppColors.secondary)
                }
                Spacer(modifier = Modifier.height(4.dp))
            }

            Box(
                modifier = Modifier
                    .widthIn(max = 280.dp)
                    .background(bgColor, shape)
                    .padding(horizontal = 16.dp, vertical = 12.dp)
            ) {
                if (message.isLoading) {
                    TypingIndicator()
                } else if (!isUser && message.shouldAnimate) {
                    TypewriterText(
                        fullText = message.content,
                        color = textColor,
                        style = MaterialTheme.typography.bodyLarge,
                        onAnimationComplete = onAnimationComplete
                    )
                } else {
                    Text(
                        text = parseMarkdown(message.content),
                        color = textColor,
                        style = MaterialTheme.typography.bodyLarge
                    )
                }
            }
        }
    }
}
```

**Note:** Add `import androidx.compose.animation.core.FastOutSlowInEasing` if not already present. The `mutableStateOf` import is already in the file.

**Step 2: Build**

```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -20
```

Expected: `BUILD SUCCESSFUL`

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIScreen.kt
git commit -m "feat(android/ai): slide-up fade-in entry animation for chat bubbles"
```

---

## Task 3: Improved Markdown Parser

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIScreen.kt` (the `parseMarkdown` function, ~lines 357–384)

**Context:** `parseMarkdown` currently only handles `**bold**`. Extend it to handle headings, bullets, inline code, and italic.

**Step 1: Replace `parseMarkdown` with an extended version**

Find `fun parseMarkdown(text: String): AnnotatedString {` and replace the entire function with:

```kotlin
fun parseMarkdown(text: String): AnnotatedString {
    val builder = AnnotatedString.Builder()
    val lines = text.split("\n")

    lines.forEachIndexed { lineIndex, rawLine ->
        if (lineIndex > 0) builder.append("\n")

        val line = when {
            rawLine.startsWith("## ") -> { builder.pushStyle(SpanStyle(fontWeight = FontWeight.Bold, fontSize = 17.sp)); rawLine.removePrefix("## ") }
            rawLine.startsWith("# ") -> { builder.pushStyle(SpanStyle(fontWeight = FontWeight.Bold, fontSize = 20.sp)); rawLine.removePrefix("# ") }
            rawLine.startsWith("- ") || rawLine.startsWith("* ") -> "• ${rawLine.drop(2)}"
            else -> rawLine
        }
        val isHeading = rawLine.startsWith("# ") || rawLine.startsWith("## ")

        // Inline parsing: bold, italic, code
        val inlineRegex = "\\*\\*(.*?)\\*\\*|\\*(.*?)\\*|_(.*?)_|`(.*?)`".toRegex()
        var cursor = 0
        for (match in inlineRegex.findAll(line)) {
            if (match.range.first > cursor) builder.append(line.substring(cursor, match.range.first))
            val full = match.value
            when {
                full.startsWith("**") -> builder.withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(match.groupValues[1]) }
                full.startsWith("`") -> builder.withStyle(SpanStyle(fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace, background = androidx.compose.ui.graphics.Color(0x22AAAAAA))) { append(match.groupValues[4]) }
                full.startsWith("*") || full.startsWith("_") -> {
                    val inner = if (full.startsWith("*")) match.groupValues[2] else match.groupValues[3]
                    builder.withStyle(SpanStyle(fontStyle = FontStyle.Italic)) { append(inner) }
                }
            }
            cursor = match.range.last + 1
        }
        if (cursor < line.length) builder.append(line.substring(cursor))
        if (isHeading) builder.pop()
    }

    return builder.toAnnotatedString()
}
```

**Note:** Ensure `import androidx.compose.ui.unit.sp` and `import androidx.compose.ui.text.font.FontStyle` are present at top of file. Both are already imported.

**Step 2: Build**

```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -20
```

Expected: `BUILD SUCCESSFUL`

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIScreen.kt
git commit -m "feat(android/ai): extend markdown parser to support headings, bullets, italic, code"
```

---

## Task 4: Inline Follow-Up Suggestion Chips

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIScreen.kt` (the `LazyColumn` in `AIScreen`, ~lines 129–141)

**Context:** `followUpSuggestions` is already populated in the ViewModel after each AI response but is never shown in the UI. Render chips inline below the last AI message in the list.

**Step 1: Add a `FollowUpChips` composable**

Add this new composable anywhere in `AIScreen.kt` (e.g., after `QuickActionButton`):

```kotlin
@Composable
fun FollowUpChips(suggestions: List<String>, onChipClick: (String) -> Unit) {
    AnimatedVisibility(
        visible = suggestions.isNotEmpty(),
        enter = fadeIn() + expandVertically()
    ) {
        LazyRow(
            contentPadding = PaddingValues(horizontal = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.padding(top = 8.dp)
        ) {
            items(suggestions) { suggestion ->
                SuggestionChip(
                    onClick = { onChipClick(suggestion) },
                    label = {
                        Text(
                            text = suggestion,
                            style = MaterialTheme.typography.bodySmall,
                            maxLines = 1,
                            overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis
                        )
                    },
                    modifier = Modifier.widthIn(max = 220.dp),
                    colors = SuggestionChipDefaults.suggestionChipColors(
                        containerColor = AppColors.primaryContainer.copy(alpha = 0.4f)
                    )
                )
            }
        }
    }
}
```

**Step 2: Render chips below the last AI bubble**

In the `LazyColumn` inside `AIScreen`, change:

```kotlin
items(uiState.messages, key = { it.id }) { message ->
    ChatBubble(
        message = message,
        onAnimationComplete = { viewModel.markMessageAnimated(message.id) }
    )
}
```

To:

```kotlin
itemsIndexed(uiState.messages, key = { _, msg -> msg.id }) { index, message ->
    ChatBubble(
        message = message,
        onAnimationComplete = { viewModel.markMessageAnimated(message.id) }
    )
    // Show follow-up chips only below the last AI message
    val isLastMessage = index == uiState.messages.size - 1
    if (isLastMessage && !message.isUser && !message.isLoading) {
        FollowUpChips(
            suggestions = uiState.followUpSuggestions,
            onChipClick = { viewModel.sendFollowUp(it) }
        )
    }
}
```

**Note:** `itemsIndexed` is already imported (`import androidx.compose.foundation.lazy.itemsIndexed`). Also add `import androidx.compose.material3.SuggestionChip` and `import androidx.compose.material3.SuggestionChipDefaults`.

**Step 3: Build**

```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -20
```

Expected: `BUILD SUCCESSFUL`

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIScreen.kt
git commit -m "feat(android/ai): show follow-up suggestion chips inline below last AI message"
```

---

## Task 5: Scroll-to-Bottom FAB

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIScreen.kt` (the `Box` that wraps the message list, ~lines 122–143)

**Context:** When the user scrolls up to read old messages, there's no way to jump back to the bottom. Add a small FAB that appears when scrolled up.

**Step 1: Add FAB inside the `Box(modifier = Modifier.weight(1f))`**

The current structure is:
```kotlin
Box(modifier = Modifier.weight(1f)) {
    if (uiState.messages.isEmpty() && uiState.showEmptyState) {
        IntroView(...)
    } else {
        LazyColumn(...)
    }
}
```

Replace it with:

```kotlin
Box(modifier = Modifier.weight(1f)) {
    if (uiState.messages.isEmpty() && uiState.showEmptyState) {
        IntroView(
            onAnalyzeClick = { viewModel.sendQuickAction(QuickAction.suggestions[0]) },
            modifier = Modifier.align(Alignment.Center)
        )
    } else {
        LazyColumn(
            state = listState,
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier.fillMaxSize()
        ) {
            itemsIndexed(uiState.messages, key = { _, msg -> msg.id }) { index, message ->
                ChatBubble(
                    message = message,
                    onAnimationComplete = { viewModel.markMessageAnimated(message.id) }
                )
                val isLastMessage = index == uiState.messages.size - 1
                if (isLastMessage && !message.isUser && !message.isLoading) {
                    FollowUpChips(
                        suggestions = uiState.followUpSuggestions,
                        onChipClick = { viewModel.sendFollowUp(it) }
                    )
                }
            }
        }

        // Scroll-to-bottom FAB
        val showScrollFab = remember { derivedStateOf { listState.firstVisibleItemIndex < uiState.messages.size - 2 } }
        AnimatedVisibility(
            visible = showScrollFab.value && uiState.messages.size > 2,
            enter = fadeIn() + scaleIn(),
            exit = fadeOut() + scaleOut(),
            modifier = Modifier.align(Alignment.BottomEnd).padding(8.dp)
        ) {
            SmallFloatingActionButton(
                onClick = {
                    scope.launch { listState.animateScrollToItem(uiState.messages.size - 1) }
                },
                containerColor = AppColors.primaryContainer,
                contentColor = AppColors.primary,
                modifier = Modifier
                    .glass(cornerRadius = 16.dp)
            ) {
                Icon(
                    Icons.Default.ArrowUpward,
                    contentDescription = "Scroll to bottom",
                    modifier = Modifier
                        .size(18.dp)
                        .scale(1f, -1f) // flip to point downward
                )
            }
        }
    }
}
```

**Note:** Add `import androidx.compose.animation.scaleIn`, `import androidx.compose.animation.scaleOut`, `import androidx.compose.animation.fadeOut`, `import androidx.compose.material3.SmallFloatingActionButton`, and `import androidx.compose.runtime.derivedStateOf`. The `scope` coroutine is already declared at the top of `AIScreen`.

**Step 2: Build**

```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -20
```

Expected: `BUILD SUCCESSFUL`

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIScreen.kt
git commit -m "feat(android/ai): scroll-to-bottom FAB with animated visibility"
```

---

## Task 6: Long-Press Message Actions (Copy / Share / Bookmark)

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIScreen.kt` (`ChatBubble`, imports)

**Context:** Add long-press detection to each bubble to show a `DropdownMenu` with Copy, Share, and (for AI messages) Bookmark.

**Step 1: Add required imports**

At the top of `AIScreen.kt`, add:

```kotlin
import androidx.compose.foundation.combinedClickable
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.IosShare
import androidx.compose.material.icons.filled.BookmarkBorder
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import android.content.Intent
```

**Step 2: Add long-press and menu state to `ChatBubble`**

Inside `ChatBubble`, after the existing `val shape = ...` line, add:

```kotlin
var showMenu by remember { mutableStateOf(false) }
val clipboardManager = LocalClipboardManager.current
val context = LocalContext.current
```

**Step 3: Wrap the message `Box` with `combinedClickable`**

The `Box` that currently has `.widthIn(max = 280.dp).background(bgColor, shape).padding(...)` — add `combinedClickable` to it:

```kotlin
Box(
    modifier = Modifier
        .widthIn(max = 280.dp)
        .background(bgColor, shape)
        .combinedClickable(
            onClick = {},
            onLongClick = { if (!message.isLoading) showMenu = true }
        )
        .padding(horizontal = 16.dp, vertical = 12.dp)
) {
    // existing content unchanged

    DropdownMenu(
        expanded = showMenu,
        onDismissRequest = { showMenu = false }
    ) {
        DropdownMenuItem(
            text = { Text("Copy") },
            leadingIcon = { Icon(Icons.Default.ContentCopy, contentDescription = null, modifier = Modifier.size(18.dp)) },
            onClick = {
                clipboardManager.setText(AnnotatedString(message.content))
                showMenu = false
                // Note: viewModel.onMessageCopied() needs to be passed in — see Step 4
            }
        )
        DropdownMenuItem(
            text = { Text("Share") },
            leadingIcon = { Icon(Icons.Default.IosShare, contentDescription = null, modifier = Modifier.size(18.dp)) },
            onClick = {
                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, message.content)
                }
                context.startActivity(Intent.createChooser(intent, "Share message"))
                showMenu = false
            }
        )
        if (!isUser) {
            DropdownMenuItem(
                text = { Text("Bookmark") },
                leadingIcon = { Icon(Icons.Default.BookmarkBorder, contentDescription = null, modifier = Modifier.size(18.dp)) },
                onClick = {
                    showMenu = false
                    // Note: onBookmark callback — see Step 4
                }
            )
        }
    }
}
```

**Step 4: Thread callbacks through `ChatBubble`**

Change the `ChatBubble` signature to accept callbacks:

```kotlin
@Composable
fun ChatBubble(
    message: ChatMessage,
    onAnimationComplete: () -> Unit = {},
    onCopy: () -> Unit = {},
    onBookmark: () -> Unit = {}
)
```

Wire them in the `DropdownMenuItem` onClick blocks:
- Copy: call `onCopy()`
- Bookmark: call `onBookmark()`

Update the call sites in `AIScreen` (in the `LazyColumn`):

```kotlin
ChatBubble(
    message = message,
    onAnimationComplete = { viewModel.markMessageAnimated(message.id) },
    onCopy = { viewModel.onMessageCopied() },
    onBookmark = { viewModel.onMessageBookmarked() }
)
```

**Note:** `combinedClickable` requires `ExperimentalFoundationApi`. Add `@OptIn(ExperimentalFoundationApi::class)` on `ChatBubble` and add `import androidx.compose.foundation.ExperimentalFoundationApi`.

**Step 5: Build**

```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -20
```

Expected: `BUILD SUCCESSFUL`

**Step 6: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIScreen.kt
git commit -m "feat(android/ai): long-press bubble menu with copy, share, bookmark actions"
```

---

## Task 7: Inline Health Metric Card

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIScreen.kt`

**Context:** After a health analysis, AI responses that mention metrics should show a visual metric snapshot card below the AI bubble. Reuses existing `AnalysisState.Completed` data — no new fetching.

**Step 1: Add `HealthInsightCard` composable**

Add this composable after `MetricChip` (~line 644):

```kotlin
@Composable
fun HealthInsightCard(metrics: HealthMetrics) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp)
            .glass(cornerRadius = 16.dp)
            .padding(16.dp)
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Icon(
                    Icons.Default.AutoAwesome,
                    contentDescription = null,
                    tint = AppColors.primary,
                    modifier = Modifier.size(14.dp)
                )
                Text(
                    "Health Snapshot",
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.primary
                )
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceAround
            ) {
                MetricChip("Steps", "${metrics.steps}")
                MetricChip("Heart Rate", "${metrics.heartRate} bpm")
                MetricChip("Calories", "${metrics.activeCalories} kcal")
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceAround
            ) {
                MetricChip("Sleep", metrics.sleep)
                MetricChip("Exercise", "${metrics.exerciseMinutes} min")
                if (metrics.bloodPressure != "--/--") MetricChip("BP", metrics.bloodPressure)
            }
        }
    }
}
```

**Step 2: Define the health keyword detector**

Add this top-level function near `parseMarkdown`:

```kotlin
private fun containsHealthMetrics(text: String): Boolean {
    val lower = text.lowercase()
    val keywords = listOf("steps", "heart rate", "sleep", "calorie", "blood pressure", "exercise", "weight")
    return keywords.count { lower.contains(it) } >= 2
}
```

**Step 3: Render `HealthInsightCard` in the message list**

In the `itemsIndexed` block in `AIScreen`, after the `ChatBubble(...)` call and before the `FollowUpChips`, add:

```kotlin
// Health metric card — show below AI bubble if response discusses metrics and analysis data exists
if (!message.isUser && !message.isLoading && containsHealthMetrics(message.content)) {
    val completedState = uiState.analysisState as? AnalysisState.Completed
    if (completedState != null) {
        HealthInsightCard(metrics = completedState.result.metrics)
    }
}
```

**Step 4: Build**

```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -20
```

Expected: `BUILD SUCCESSFUL`

**Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIScreen.kt
git commit -m "feat(android/ai): inline health metric snapshot card below relevant AI responses"
```

---

## Task 8: Image Thumbnails in User Bubbles

### Task 8a: Extend `ChatMessage` model

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/models/AIModels.kt`

**Step 1: Add `imageUri` field to `ChatMessage`**

Find:
```kotlin
data class ChatMessage(
    val id: String = UUID.randomUUID().toString(),
    val content: String,
    val isUser: Boolean,
    val timestamp: Long = System.currentTimeMillis(),
    val isLoading: Boolean = false,
    val shouldAnimate: Boolean = false
)
```

Replace with:
```kotlin
data class ChatMessage(
    val id: String = UUID.randomUUID().toString(),
    val content: String,
    val isUser: Boolean,
    val timestamp: Long = System.currentTimeMillis(),
    val isLoading: Boolean = false,
    val shouldAnimate: Boolean = false,
    val imageUri: String? = null
)
```

Also update the `userMessage` companion factory to add an overload:
```kotlin
companion object {
    fun userMessage(content: String) = ChatMessage(content = content, isUser = true)
    fun userMessage(content: String, imageUri: String?) = ChatMessage(content = content, isUser = true, imageUri = imageUri)
    fun assistantMessage(content: String) = ChatMessage(content = content, isUser = false, shouldAnimate = true)
    fun loadingMessage() = ChatMessage(content = "", isUser = false, isLoading = true)
}
```

**Step 2: Build to verify no breakage**

```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -20
```

Expected: `BUILD SUCCESSFUL`

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/data/models/AIModels.kt
git commit -m "feat(android/ai): add imageUri field to ChatMessage for image bubble support"
```

### Task 8b: Pass imageUri through ViewModel

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIViewModel.kt` (`sendImageForAnalysis`, ~line 317)

**Step 1: Update `sendImageForAnalysis` to attach imageUri**

Find in `sendImageForAnalysis`:
```kotlin
val userMessage = ChatMessage.userMessage(userText)
```

Replace with:
```kotlin
val userMessage = ChatMessage.userMessage(userText, _uiState.value.pendingImageUri)
```

**Step 2: Build**

```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -20
```

Expected: `BUILD SUCCESSFUL`

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIViewModel.kt
git commit -m "feat(android/ai): attach image URI to user message for thumbnail rendering"
```

### Task 8c: Render image thumbnail in `ChatBubble`

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIScreen.kt`

**Step 1: Add coil import**

At the top of `AIScreen.kt`, add:
```kotlin
import coil.compose.AsyncImage
import androidx.compose.ui.layout.ContentScale
import android.net.Uri
```

**Step 2: Add image thumbnail rendering inside `ChatBubble`**

In `ChatBubble`, inside the `Box` that shows the message content, before the existing `if (message.isLoading)` check, add a conditional for image rendering. The full content section becomes:

```kotlin
// existing: if (message.isLoading) ...
// NEW: if the user sent an image, show thumbnail instead of the placeholder text
if (message.isUser && message.imageUri != null) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        AsyncImage(
            model = Uri.parse(message.imageUri),
            contentDescription = "Attached image",
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(max = 180.dp)
                .clip(RoundedCornerShape(12.dp))
        )
        // Image type chip extracted from content "[Image: X-Ray]..."
        val typeLabel = message.content
            .removePrefix("[Image: ")
            .substringBefore("]")
        if (typeLabel.isNotBlank() && typeLabel != message.content) {
            Box(
                modifier = Modifier
                    .background(AppColors.primary.copy(alpha = 0.15f), RoundedCornerShape(8.dp))
                    .padding(horizontal = 8.dp, vertical = 4.dp)
            ) {
                Text(
                    typeLabel,
                    style = MaterialTheme.typography.labelSmall,
                    color = AppColors.primary,
                    fontWeight = FontWeight.Medium
                )
            }
        }
    }
} else if (message.isLoading) {
    TypingIndicator()
} else if (!isUser && message.shouldAnimate) {
    TypewriterText(
        fullText = message.content,
        color = textColor,
        style = MaterialTheme.typography.bodyLarge,
        onAnimationComplete = onAnimationComplete
    )
} else {
    Text(
        text = parseMarkdown(message.content),
        color = textColor,
        style = MaterialTheme.typography.bodyLarge
    )
}
```

**Step 3: Build**

```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -20
```

Expected: `BUILD SUCCESSFUL`

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIScreen.kt
git commit -m "feat(android/ai): show image thumbnail and type chip in user chat bubble"
```

---

## Final Verification

```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -5
```

Expected: `BUILD SUCCESSFUL` with 0 errors.

All 8 tasks complete. Features delivered:
1. Staggered wave typing indicator
2. Slide-up fade-in bubble entry animations
3. Markdown: headings, bullets, inline code, italic
4. Inline follow-up suggestion chips below last AI message
5. Scroll-to-bottom FAB
6. Long-press copy / share / bookmark menu
7. Inline health metric snapshot card
8. Image thumbnails in user bubbles (model + ViewModel + UI)
