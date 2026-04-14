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

        // File type icon
        Icon(
            imageVector = getFileIcon(document.fileType),
            contentDescription = null,
            tint = getCategoryColor(document.category),
            modifier = Modifier.size(20.dp)
        )
        Spacer(modifier = Modifier.width(12.dp))

        // Title + metadata
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = document.title,
                fontSize = 15.sp,
                color = AppColors.onBackground,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = document.category,
                    fontSize = 11.sp,
                    color = getCategoryColor(document.category)
                )
                if (document.documentDate != null) {
                    Text(
                        text = " \u2022 ",
                        fontSize = 11.sp,
                        color = AppColors.onBackground.copy(alpha = 0.3f)
                    )
                    Text(
                        text = document.documentDate.substringBefore("T"),
                        fontSize = 11.sp,
                        color = AppColors.onBackground.copy(alpha = 0.4f)
                    )
                }
                if (document.doctorName != null) {
                    Text(
                        text = " \u2022 ",
                        fontSize = 11.sp,
                        color = AppColors.onBackground.copy(alpha = 0.3f)
                    )
                    Text(
                        text = document.doctorName,
                        fontSize = 11.sp,
                        color = AppColors.onBackground.copy(alpha = 0.4f),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
        }

        if (!isSelectionMode) {
            var showMenu by remember { mutableStateOf(false) }
            Box {
                Icon(
                    Icons.Outlined.ChevronRight,
                    contentDescription = null,
                    modifier = Modifier
                        .size(18.dp)
                        .clickable { showMenu = true },
                    tint = AppColors.onBackground.copy(alpha = 0.25f)
                )
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

// Keep the old DocumentCard as an alias for backward compat in FolderDetailView
@Composable
fun DocumentCard(
    document: MedicalDocument,
    isSelectionMode: Boolean,
    isSelected: Boolean,
    onTap: () -> Unit,
    onViewClick: (MedicalDocument) -> Unit,
    onEditClick: (MedicalDocument) -> Unit,
    onDeleteClick: (MedicalDocument) -> Unit
) {
    DocumentRow(
        document = document,
        isSelectionMode = isSelectionMode,
        isSelected = isSelected,
        onTap = onTap,
        onViewClick = onViewClick,
        onEditClick = onEditClick,
        onDeleteClick = onDeleteClick
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

// Keep the old FolderCard for backward compat
@Composable
fun FolderCard(
    folderName: String,
    count: Int,
    color: Color,
    onClick: () -> Unit
) {
    FolderRow(folderName = folderName, count = count, onClick = onClick)
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
        "jpg", "jpeg", "png" -> Icons.Default.Image
        else -> Icons.Default.InsertDriveFile
    }
}
