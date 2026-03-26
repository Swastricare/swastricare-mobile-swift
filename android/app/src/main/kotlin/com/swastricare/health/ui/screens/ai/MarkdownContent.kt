package com.swastricare.health.ui.screens.ai

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.material3.MaterialTheme
import com.mikepenz.markdown.m3.Markdown
import com.mikepenz.markdown.m3.markdownColor
import com.mikepenz.markdown.m3.markdownTypography
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.PrimaryColor

/**
 * Represents a block of content in a markdown document.
 */
sealed class ContentBlock {
    /**
     * A standard markdown block.
     */
    data class Markdown(val text: String) : ContentBlock()

    /**
     * A table block (detected by pipe characters).
     */
    data class Table(val text: String) : ContentBlock()
}

/**
 * Splits raw markdown content into separate blocks of markdown and table content.
 *
 * Tables are detected by consecutive lines containing at least 2 pipe (|) characters.
 * Everything else is treated as markdown.
 */
fun splitContentBlocks(content: String): List<ContentBlock> {
    val blocks = mutableListOf<ContentBlock>()
    val lines = content.lines()

    var i = 0
    val currentMarkdown = StringBuilder()

    while (i < lines.size) {
        val line = lines[i]

        // Check if this line looks like a table row (contains at least 2 pipes)
        if (line.count { it == '|' } >= 2) {
            // Flush any accumulated markdown
            if (currentMarkdown.isNotEmpty()) {
                blocks.add(ContentBlock.Markdown(currentMarkdown.toString().trim()))
                currentMarkdown.clear()
            }

            // Collect all consecutive table lines
            val tableLines = mutableListOf<String>()
            while (i < lines.size && lines[i].count { it == '|' } >= 2) {
                tableLines.add(lines[i])
                i++
            }

            blocks.add(ContentBlock.Table(tableLines.joinToString("\n")))
        } else {
            // Regular markdown line
            currentMarkdown.append(line).append("\n")
            i++
        }
    }

    // Flush any remaining markdown
    if (currentMarkdown.isNotEmpty()) {
        blocks.add(ContentBlock.Markdown(currentMarkdown.toString().trim()))
    }

    return blocks
}

/**
 * Renders markdown content with support for tables.
 *
 * Automatically detects and extracts table blocks, rendering them separately
 * while using the markdown library for standard content.
 */
@Composable
fun MarkdownContent(
    content: String,
    modifier: Modifier = Modifier
) {
    val blocks = remember(content) { splitContentBlocks(content) }

    val isDark = isSystemInDarkTheme()

    val mdColors = markdownColor(
        text = AppColors.onBackground,
        codeText = if (isDark) Color(0xFFD4D4D8) else Color(0xFF1E1E2E),
        codeBackground = if (isDark) Color(0xFF1E1E2E) else Color(0xFFF5F5F7),
        inlineCodeText = AppColors.onBackground,
        inlineCodeBackground = AppColors.surfaceVariant.copy(alpha = 0.5f),
        linkText = PrimaryColor,
        dividerColor = AppColors.outlineVariant.copy(alpha = 0.3f)
    )

    val mdTypography = markdownTypography(
        h1 = MaterialTheme.typography.headlineSmall.copy(
            fontFamily = Poppins,
            fontWeight = FontWeight.Bold
        ),
        h2 = MaterialTheme.typography.titleLarge.copy(
            fontFamily = Poppins,
            fontWeight = FontWeight.Bold
        ),
        h3 = MaterialTheme.typography.titleMedium.copy(
            fontFamily = Poppins,
            fontWeight = FontWeight.SemiBold
        ),
        h4 = MaterialTheme.typography.titleSmall.copy(
            fontFamily = Poppins,
            fontWeight = FontWeight.SemiBold
        ),
        h5 = MaterialTheme.typography.bodyLarge.copy(
            fontFamily = Poppins,
            fontWeight = FontWeight.SemiBold
        ),
        h6 = MaterialTheme.typography.bodyLarge.copy(
            fontFamily = Poppins,
            fontWeight = FontWeight.Medium
        ),
        text = MaterialTheme.typography.bodyLarge.copy(fontFamily = Poppins),
        code = MaterialTheme.typography.bodyMedium.copy(fontFamily = FontFamily.Monospace),
        quote = MaterialTheme.typography.bodyLarge.copy(
            fontFamily = Poppins,
            fontStyle = FontStyle.Italic,
            color = AppColors.onSurfaceVariant
        ),
        paragraph = MaterialTheme.typography.bodyLarge.copy(fontFamily = Poppins),
        ordered = MaterialTheme.typography.bodyLarge.copy(fontFamily = Poppins),
        bullet = MaterialTheme.typography.bodyLarge.copy(fontFamily = Poppins),
        list = MaterialTheme.typography.bodyLarge.copy(fontFamily = Poppins)
    )

    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        blocks.forEach { block ->
            when (block) {
                is ContentBlock.Markdown -> {
                    Markdown(
                        content = block.text,
                        colors = mdColors,
                        typography = mdTypography,
                        modifier = Modifier.fillMaxWidth()
                    )
                }
                is ContentBlock.Table -> {
                    MarkdownTable(rawTable = block.text)
                }
            }
        }
    }
}
