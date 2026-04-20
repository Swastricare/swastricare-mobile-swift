package com.swastricare.health.ui.screens.vault

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swastricare.health.data.model.MedicalDocument
import com.swastricare.health.data.model.VaultCategory
import com.swastricare.health.ui.theme.AppColors
import java.time.LocalDate
import java.time.format.DateTimeFormatter

// ═══════════════════════════════════════════════════════
// Section building blocks (matching Settings screen design)
// ═══════════════════════════════════════════════════════

@Composable
fun VaultSectionHeader(title: String) {
    Text(
        title.uppercase(),
        fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
        color = AppColors.onBackground.copy(alpha = 0.35f),
        letterSpacing = 0.8.sp,
        modifier = Modifier.padding(start = 20.dp, top = 20.dp, bottom = 6.dp)
    )
}

@Composable
fun VaultSectionCard(content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(AppColors.surface)
            .padding(horizontal = 16.dp, vertical = 4.dp),
        content = content
    )
}

@Composable
fun VaultCleanDivider() {
    HorizontalDivider(color = AppColors.onBackground.copy(alpha = 0.06f), thickness = 0.5.dp)
}

// ═══════════════════════════════════════════════════════
// Filter Pill
// ═══════════════════════════════════════════════════════

@Composable
fun FilterPill(
    title: String,
    count: Int,
    isSelected: Boolean,
    colorHex: Long,
    onClick: () -> Unit
) {
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(50),
        color = if (isSelected) Color(colorHex) else Color.Transparent,
        border = if (isSelected) null else androidx.compose.foundation.BorderStroke(1.dp, Color.Gray.copy(alpha = 0.3f)),
        modifier = Modifier.padding(end = 8.dp)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = title,
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                color = if (isSelected) Color.White else AppColors.onSurface
            )
            Spacer(modifier = Modifier.width(5.dp))
            Surface(
                color = if (isSelected) Color.White.copy(alpha = 0.2f) else AppColors.surfaceVariant,
                shape = RoundedCornerShape(4.dp)
            ) {
                Text(
                    text = count.toString(),
                    style = MaterialTheme.typography.labelSmall,
                    modifier = Modifier.padding(horizontal = 4.dp, vertical = 1.dp),
                    color = if (isSelected) Color.White else AppColors.onSurfaceVariant
                )
            }
        }
    }
}

// ═══════════════════════════════════════════════════════
// Document Row (clean row style, no background — parent card provides it)
// ═══════════════════════════════════════════════════════

@Composable
fun DocumentRow(
    document: MedicalDocument,
    isSelectionMode: Boolean,
    isSelected: Boolean,
    onTap: () -> Unit,
    onViewClick: (MedicalDocument) -> Unit,
    onEditClick: (MedicalDocument) -> Unit,
    onDeleteClick: (MedicalDocument) -> Unit
) {
    val categoryColor = getCategoryColor(document.category)
    var showMenu by remember { mutableStateOf(false) }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onTap() }
            .padding(vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (isSelectionMode) {
            Icon(
                imageVector = if (isSelected) Icons.Default.CheckCircle else Icons.Outlined.Circle,
                contentDescription = null,
                tint = if (isSelected) AppColors.primary else AppColors.onBackground.copy(alpha = 0.3f),
                modifier = Modifier.size(22.dp)
            )
            Spacer(modifier = Modifier.width(12.dp))
        }

        // Colored category tile with file type icon
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(categoryColor.copy(alpha = 0.14f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = getFileIcon(document.fileType),
                contentDescription = null,
                tint = categoryColor,
                modifier = Modifier.size(20.dp)
            )
        }
        Spacer(modifier = Modifier.width(12.dp))

        // Title + metadata
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = document.title,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                color = AppColors.onBackground,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(modifier = Modifier.height(2.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = document.category,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Medium,
                    color = categoryColor
                )
                val date = formatDocumentDate(document.documentDate)
                if (date.isNotEmpty()) {
                    MetadataDot()
                    Text(
                        text = date,
                        fontSize = 11.sp,
                        color = AppColors.onBackground.copy(alpha = 0.5f)
                    )
                }
                if (!document.doctorName.isNullOrBlank()) {
                    MetadataDot()
                    Text(
                        text = document.doctorName,
                        fontSize = 11.sp,
                        color = AppColors.onBackground.copy(alpha = 0.5f),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
        }

        if (!isSelectionMode) {
            Box {
                IconButton(
                    onClick = { showMenu = true },
                    modifier = Modifier.size(32.dp)
                ) {
                    Icon(
                        Icons.Default.MoreVert,
                        contentDescription = "More",
                        modifier = Modifier.size(18.dp),
                        tint = AppColors.onBackground.copy(alpha = 0.45f)
                    )
                }
                DropdownMenu(
                    expanded = showMenu,
                    onDismissRequest = { showMenu = false }
                ) {
                    DropdownMenuItem(
                        text = { Text("View") },
                        onClick = { showMenu = false; onViewClick(document) },
                        leadingIcon = { Icon(Icons.Default.Visibility, contentDescription = null, modifier = Modifier.size(20.dp)) }
                    )
                    DropdownMenuItem(
                        text = { Text("Edit") },
                        onClick = { showMenu = false; onEditClick(document) },
                        leadingIcon = { Icon(Icons.Default.Edit, contentDescription = null, modifier = Modifier.size(20.dp)) }
                    )
                    HorizontalDivider()
                    DropdownMenuItem(
                        text = { Text("Delete", color = AppColors.error) },
                        onClick = { showMenu = false; onDeleteClick(document) },
                        leadingIcon = { Icon(Icons.Default.Delete, contentDescription = null, tint = AppColors.error, modifier = Modifier.size(20.dp)) }
                    )
                }
            }
        }
    }
}

@Composable
private fun MetadataDot() {
    Text(
        text = " \u2022 ",
        fontSize = 11.sp,
        color = AppColors.onBackground.copy(alpha = 0.3f)
    )
}

// ═══════════════════════════════════════════════════════
// Folder Row (clean row style for list layout)
// ═══════════════════════════════════════════════════════

@Composable
fun FolderRow(
    folderName: String,
    count: Int,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            Icons.Outlined.Folder,
            contentDescription = null,
            modifier = Modifier.size(20.dp),
            tint = AppColors.onBackground.copy(alpha = 0.5f)
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(folderName, fontSize = 15.sp, color = AppColors.onBackground)
            Text(
                "$count ${if (count == 1) "document" else "documents"}",
                fontSize = 12.sp,
                color = AppColors.onBackground.copy(alpha = 0.4f)
            )
        }
        Icon(
            Icons.Outlined.ChevronRight,
            contentDescription = null,
            modifier = Modifier.size(18.dp),
            tint = AppColors.onBackground.copy(alpha = 0.25f)
        )
    }
}

// ═══════════════════════════════════════════════════════
// Utility functions
// ═══════════════════════════════════════════════════════

fun getCategoryColor(categoryName: String): Color {
    val category = VaultCategory.fromValue(categoryName)
    return Color(category.colorHex)
}

fun getFileIcon(fileType: String): ImageVector {
    return when (fileType.lowercase()) {
        "pdf" -> Icons.Default.Description
        "jpg", "jpeg", "png", "webp" -> Icons.Default.Image
        else -> Icons.Default.InsertDriveFile
    }
}

/** "Today", "Yesterday", "8 Apr" (this year) or "8 Apr 2025" (other years). */
fun formatDocumentDate(iso: String?): String {
    if (iso.isNullOrBlank()) return ""
    return try {
        val date = LocalDate.parse(iso.substringBefore("T"))
        val today = LocalDate.now()
        when (date) {
            today -> "Today"
            today.minusDays(1) -> "Yesterday"
            else -> {
                val pattern = if (date.year == today.year) "d MMM" else "d MMM yyyy"
                date.format(DateTimeFormatter.ofPattern(pattern))
            }
        }
    } catch (_: Exception) {
        iso.substringBefore("T")
    }
}

/** Timeline group headers: "Today", "Yesterday", full "8 April 2026" otherwise. */
fun formatTimelineDate(iso: String): String {
    if (iso == "Unknown Date") return iso
    return try {
        val date = LocalDate.parse(iso)
        val today = LocalDate.now()
        when (date) {
            today -> "Today"
            today.minusDays(1) -> "Yesterday"
            else -> date.format(DateTimeFormatter.ofPattern("d MMMM yyyy"))
        }
    } catch (_: Exception) {
        iso
    }
}
