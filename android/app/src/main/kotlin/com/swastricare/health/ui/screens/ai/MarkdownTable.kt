package com.swastricare.health.ui.screens.ai

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.swastricare.health.ui.theme.AppColors
import com.swastricare.health.ui.theme.PrimaryColor

/**
 * Parses a markdown table string into headers and data rows.
 *
 * @param raw The raw markdown table string
 * @return Pair of (headers, dataRows) where headers is a list of column names
 *         and dataRows is a list of rows, each row being a list of cell values
 */
fun parseMarkdownTable(raw: String): Pair<List<String>, List<List<String>>> {
    val lines = raw.lines()
        .map { it.trim() }
        .filter { it.isNotEmpty() && it.startsWith("|") && it.endsWith("|") }

    if (lines.isEmpty()) {
        return Pair(emptyList(), emptyList())
    }

    // Parse each line into cells
    val parsedLines = lines.map { line ->
        line.split("|")
            .drop(1) // Drop first empty entry before initial |
            .dropLast(1) // Drop last empty entry after final |
            .map { it.trim() }
    }

    // Find separator row (contains ---)
    val separatorIndex = parsedLines.indexOfFirst { row ->
        row.any { cell -> cell.contains("---") || cell.contains("—") }
    }

    val headers: List<String>
    val dataRows: List<List<String>>

    if (separatorIndex != -1) {
        // Standard markdown table with separator
        headers = if (separatorIndex > 0) {
            parsedLines[0]
        } else {
            emptyList()
        }
        dataRows = parsedLines.drop(separatorIndex + 1)
    } else {
        // No separator found, treat first row as header
        headers = parsedLines.firstOrNull() ?: emptyList()
        dataRows = parsedLines.drop(1)
    }

    if (headers.isEmpty()) {
        return Pair(emptyList(), emptyList())
    }

    // Normalize column counts: pad shorter rows with empty strings
    val columnCount = headers.size
    val normalizedDataRows = dataRows.map { row ->
        if (row.size < columnCount) {
            row + List(columnCount - row.size) { "" }
        } else {
            row.take(columnCount)
        }
    }

    return Pair(headers, normalizedDataRows)
}

/**
 * Renders a markdown table with glassmorphic styling.
 *
 * @param rawTable The raw markdown table string to render
 * @param modifier Optional modifier for the container
 */
@Composable
fun MarkdownTable(
    rawTable: String,
    modifier: Modifier = Modifier
) {
    val (headers, dataRows) = remember(rawTable) {
        parseMarkdownTable(rawTable)
    }

    // Don't render if no headers found
    if (headers.isEmpty()) {
        return
    }

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .border(
                width = 0.5.dp,
                color = AppColors.outlineVariant.copy(alpha = 0.3f),
                shape = RoundedCornerShape(12.dp)
            )
    ) {
        Column(
            modifier = Modifier.horizontalScroll(rememberScrollState())
        ) {
            // Header row
            Row(
                modifier = Modifier
                    .background(PrimaryColor.copy(alpha = 0.08f))
                    .padding(horizontal = 12.dp, vertical = 10.dp)
            ) {
                headers.forEach { header ->
                    Text(
                        text = header,
                        fontFamily = Poppins,
                        fontWeight = FontWeight.SemiBold,
                        style = androidx.compose.material3.MaterialTheme.typography.labelMedium,
                        color = PrimaryColor,
                        modifier = Modifier
                            .width(IntrinsicSize.Min)
                            .widthIn(min = 80.dp, max = 160.dp)
                            .padding(end = 8.dp)
                    )
                }
            }

            // Divider
            HorizontalDivider(
                color = AppColors.outlineVariant.copy(alpha = 0.3f),
                thickness = 0.5.dp
            )

            // Data rows
            dataRows.forEachIndexed { index, row ->
                val backgroundColor = if (index % 2 == 0) {
                    androidx.compose.ui.graphics.Color.Transparent
                } else {
                    AppColors.surfaceVariant.copy(alpha = 0.05f)
                }

                Row(
                    modifier = Modifier
                        .background(backgroundColor)
                        .padding(horizontal = 12.dp, vertical = 8.dp)
                ) {
                    row.forEach { cell ->
                        Text(
                            text = cell,
                            fontFamily = Poppins,
                            style = androidx.compose.material3.MaterialTheme.typography.bodySmall,
                            color = AppColors.onBackground,
                            modifier = Modifier
                                .width(IntrinsicSize.Min)
                                .widthIn(min = 80.dp, max = 160.dp)
                                .padding(end = 8.dp)
                        )
                    }
                }
            }
        }
    }
}
