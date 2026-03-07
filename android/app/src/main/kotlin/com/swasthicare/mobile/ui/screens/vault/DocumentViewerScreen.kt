package com.swasthicare.mobile.ui.screens.vault

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.ParcelFileDescriptor
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.rememberTransformableState
import androidx.compose.foundation.gestures.transformable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.BrokenImage
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import coil.compose.AsyncImagePainter
import coil.request.ImageRequest
import com.swasthicare.mobile.data.model.MedicalDocument
import com.swasthicare.mobile.ui.screens.home.PremiumBackground
import com.swasthicare.mobile.ui.theme.AppColors
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DocumentViewerScreen(
    document: MedicalDocument,
    onBack: () -> Unit
) {
    val context = LocalContext.current
    val fileType = document.fileType.lowercase()
    val isImage = fileType in listOf("jpg", "jpeg", "png", "webp", "gif", "bmp")
    val isPdf = fileType == "pdf"

    Box(modifier = Modifier.fillMaxSize()) {
        PremiumBackground()

        Scaffold(
            containerColor = Color.Transparent,
            contentWindowInsets = WindowInsets(0, 0, 0, 0),
            topBar = {
                TopAppBar(
                    title = {
                        Text(
                            text = document.title,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            fontWeight = FontWeight.SemiBold
                        )
                    },
                    navigationIcon = {
                        IconButton(onClick = onBack) {
                            Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                        }
                    },
                    actions = {
                        IconButton(onClick = {
                            val shareIntent = Intent(Intent.ACTION_SEND).apply {
                                type = when {
                                    isPdf -> "application/pdf"
                                    isImage -> "image/*"
                                    else -> "*/*"
                                }
                                putExtra(Intent.EXTRA_TEXT, "Sharing: ${document.title}")
                                // In production, use a FileProvider URI for the actual file
                                if (document.fileUrl.startsWith("content://") || document.fileUrl.startsWith("file://")) {
                                    putExtra(Intent.EXTRA_STREAM, Uri.parse(document.fileUrl))
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                }
                            }
                            context.startActivity(Intent.createChooser(shareIntent, "Share Document"))
                        }) {
                            Icon(Icons.Default.Share, contentDescription = "Share")
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = Color.Transparent
                    ),
                    windowInsets = WindowInsets(0, 0, 0, 0)
                )
            }
        ) { innerPadding ->
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding)
            ) {
                when {
                    isImage -> ImageViewer(document = document)
                    isPdf -> PdfViewer(document = document)
                    else -> UnsupportedFileView(fileType = document.fileType)
                }
            }
        }
    }
}

@Composable
private fun ImageViewer(document: MedicalDocument) {
    var scale by remember { mutableFloatStateOf(1f) }
    var offset by remember { mutableStateOf(Offset.Zero) }
    var isLoading by remember { mutableStateOf(true) }
    var isError by remember { mutableStateOf(false) }

    val transformableState = rememberTransformableState { zoomChange, panChange, _ ->
        scale = (scale * zoomChange).coerceIn(0.5f, 5f)
        offset = Offset(
            x = offset.x + panChange.x,
            y = offset.y + panChange.y
        )
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.05f)),
        contentAlignment = Alignment.Center
    ) {
        AsyncImage(
            model = ImageRequest.Builder(LocalContext.current)
                .data(document.fileUrl)
                .crossfade(true)
                .build(),
            contentDescription = document.title,
            contentScale = ContentScale.Fit,
            onState = { state ->
                when (state) {
                    is AsyncImagePainter.State.Loading -> {
                        isLoading = true
                        isError = false
                    }
                    is AsyncImagePainter.State.Success -> {
                        isLoading = false
                        isError = false
                    }
                    is AsyncImagePainter.State.Error -> {
                        isLoading = false
                        isError = true
                    }
                    else -> {}
                }
            },
            modifier = Modifier
                .fillMaxSize()
                .transformable(state = transformableState)
                .pointerInput(Unit) {
                    detectTapGestures(
                        onDoubleTap = {
                            if (scale > 1.5f) {
                                scale = 1f
                                offset = Offset.Zero
                            } else {
                                scale = 3f
                            }
                        }
                    )
                }
                .graphicsLayer {
                    scaleX = scale
                    scaleY = scale
                    translationX = offset.x
                    translationY = offset.y
                }
        )

        // Loading indicator
        AnimatedVisibility(
            visible = isLoading,
            enter = fadeIn(),
            exit = fadeOut()
        ) {
            CircularProgressIndicator(
                color = AppColors.primary
            )
        }

        // Error state
        if (isError) {
            ErrorView(message = "Failed to load image")
        }
    }
}

@Composable
private fun PdfViewer(document: MedicalDocument) {
    val context = LocalContext.current
    var pageCount by remember { mutableIntStateOf(0) }
    var isLoading by remember { mutableStateOf(true) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var renderedPages by remember { mutableStateOf<Map<Int, Bitmap>>(emptyMap()) }
    var pdfRenderer by remember { mutableStateOf<PdfRenderer?>(null) }
    var tempPdfFile by remember { mutableStateOf<File?>(null) }

    val listState = rememberLazyListState()
    val currentVisiblePage by remember {
        derivedStateOf {
            listState.firstVisibleItemIndex + 1
        }
    }

    // Zoom state
    var scale by remember { mutableFloatStateOf(1f) }
    var offset by remember { mutableStateOf(Offset.Zero) }

    val transformableState = rememberTransformableState { zoomChange, panChange, _ ->
        scale = (scale * zoomChange).coerceIn(0.5f, 4f)
        offset = Offset(
            x = offset.x + panChange.x,
            y = offset.y + panChange.y
        )
    }

    // Initialize PDF renderer and clean up on dispose
    DisposableEffect(document.fileUrl) {
        onDispose {
            pdfRenderer?.close()
            // Recycle all remaining bitmaps to free native memory
            renderedPages.values.forEach { it.recycle() }
            renderedPages = emptyMap()
            // Delete temp file downloaded from remote URL
            tempPdfFile?.delete()
        }
    }

    LaunchedEffect(document.fileUrl) {
        isLoading = true
        errorMessage = null
        try {
            withContext(Dispatchers.IO) {
                val fileUrl = document.fileUrl
                val parcelFd: ParcelFileDescriptor? = when {
                    fileUrl.startsWith("content://") -> {
                        context.contentResolver.openFileDescriptor(Uri.parse(fileUrl), "r")
                    }
                    fileUrl.startsWith("file://") || fileUrl.startsWith("/") -> {
                        val path = if (fileUrl.startsWith("file://")) fileUrl.removePrefix("file://") else fileUrl
                        ParcelFileDescriptor.open(File(path), ParcelFileDescriptor.MODE_READ_ONLY)
                    }
                    fileUrl.startsWith("http://") || fileUrl.startsWith("https://") -> {
                        // For remote PDFs, download to cache first
                        try {
                            val url = java.net.URL(fileUrl)
                            val connection = url.openConnection()
                            connection.connect()
                            val input = connection.getInputStream()
                            val downloadedFile = File.createTempFile("pdf_", ".pdf", context.cacheDir)
                            downloadedFile.outputStream().use { output ->
                                input.copyTo(output)
                            }
                            tempPdfFile = downloadedFile
                            ParcelFileDescriptor.open(downloadedFile, ParcelFileDescriptor.MODE_READ_ONLY)
                        } catch (e: Exception) {
                            null
                        }
                    }
                    else -> null
                }

                if (parcelFd != null) {
                    val renderer = PdfRenderer(parcelFd)
                    pdfRenderer = renderer
                    pageCount = renderer.pageCount

                    // Render the initial viewport pages eagerly (matches sliding window of ±1)
                    val initialPages = mutableMapOf<Int, Bitmap>()
                    val pagestoRender = minOf(2, renderer.pageCount)
                    for (i in 0 until pagestoRender) {
                        val page = renderer.openPage(i)
                        val bitmap = Bitmap.createBitmap(
                            page.width * 2,
                            page.height * 2,
                            Bitmap.Config.ARGB_8888
                        )
                        bitmap.eraseColor(android.graphics.Color.WHITE)
                        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                        page.close()
                        initialPages[i] = bitmap
                    }
                    renderedPages = initialPages
                } else {
                    errorMessage = "Could not open PDF file"
                }
            }
            isLoading = false
        } catch (e: Exception) {
            isLoading = false
            errorMessage = "Failed to render PDF: ${e.message}"
        }
    }

    // Lazy-load pages in a sliding window and evict pages outside it
    LaunchedEffect(currentVisiblePage) {
        val renderer = pdfRenderer ?: return@LaunchedEffect
        // currentVisiblePage is 1-based; convert to 0-based index for the window
        val currentIndex = (currentVisiblePage - 1).coerceIn(0, (pageCount - 1).coerceAtLeast(0))
        val keepRange = (currentIndex - 1).coerceAtLeast(0)..(currentIndex + 1).coerceAtMost(pageCount - 1)

        // Evict pages outside window (don't recycle — let GC handle it)
        val evicted = renderedPages.filterKeys { it in keepRange }
        renderedPages = evicted

        // Render missing pages on IO thread
        val newPages = mutableMapOf<Int, Bitmap>()
        for (pageIndex in keepRange) {
            if (renderedPages.containsKey(pageIndex)) continue
            withContext(Dispatchers.IO) {
                try {
                    val page = renderer.openPage(pageIndex)
                    val bitmap = Bitmap.createBitmap(
                        page.width * 2,
                        page.height * 2,
                        Bitmap.Config.ARGB_8888
                    )
                    bitmap.eraseColor(android.graphics.Color.WHITE)
                    page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                    page.close()
                    newPages[pageIndex] = bitmap
                } catch (_: Exception) {
                    // Page might already be open or renderer closed
                }
            }
        }
        // State write on main thread
        renderedPages = renderedPages + newPages
    }

    Box(modifier = Modifier.fillMaxSize()) {
        when {
            isLoading -> {
                Column(
                    modifier = Modifier.align(Alignment.Center),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    CircularProgressIndicator()
                    Text(
                        "Loading PDF...",
                        style = MaterialTheme.typography.bodyMedium,
                        color = AppColors.onSurfaceVariant
                    )
                }
            }
            errorMessage != null -> {
                ErrorView(message = errorMessage!!)
            }
            else -> {
                LazyColumn(
                    state = listState,
                    modifier = Modifier
                        .fillMaxSize()
                        .transformable(state = transformableState)
                        .pointerInput(Unit) {
                            detectTapGestures(
                                onDoubleTap = {
                                    if (scale > 1.5f) {
                                        scale = 1f
                                        offset = Offset.Zero
                                    } else {
                                        scale = 2.5f
                                    }
                                }
                            )
                        }
                        .graphicsLayer {
                            scaleX = scale
                            scaleY = scale
                            translationX = offset.x
                            translationY = offset.y
                        },
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    itemsIndexed(
                        items = (0 until pageCount).toList()
                    ) { index, pageIndex ->
                        val bitmap = renderedPages[pageIndex]

                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(8.dp),
                            elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
                        ) {
                            if (bitmap != null) {
                                androidx.compose.foundation.Image(
                                    bitmap = bitmap.asImageBitmap(),
                                    contentDescription = "Page ${pageIndex + 1}",
                                    contentScale = ContentScale.FillWidth,
                                    modifier = Modifier.fillMaxWidth()
                                )
                            } else {
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .height(400.dp),
                                    contentAlignment = Alignment.Center
                                ) {
                                    CircularProgressIndicator(
                                        modifier = Modifier.size(32.dp),
                                        strokeWidth = 2.dp
                                    )
                                }
                            }
                        }
                    }
                }

                // Page indicator
                if (pageCount > 1) {
                    Surface(
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .padding(bottom = 24.dp),
                        shape = RoundedCornerShape(20.dp),
                        color = AppColors.surface.copy(alpha = 0.9f),
                        shadowElevation = 4.dp
                    ) {
                        Text(
                            text = "Page $currentVisiblePage of $pageCount",
                            style = MaterialTheme.typography.labelLarge,
                            fontWeight = FontWeight.Medium,
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun UnsupportedFileView(fileType: String) {
    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            imageVector = Icons.Default.BrokenImage,
            contentDescription = null,
            modifier = Modifier.size(80.dp),
            tint = AppColors.onSurfaceVariant.copy(alpha = 0.5f)
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = "Unsupported File Type",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = "Cannot preview .$fileType files in the app",
            style = MaterialTheme.typography.bodyMedium,
            color = AppColors.onSurfaceVariant
        )
    }
}

@Composable
private fun ErrorView(message: String) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            imageVector = Icons.Default.BrokenImage,
            contentDescription = null,
            modifier = Modifier.size(64.dp),
            tint = AppColors.error.copy(alpha = 0.7f)
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = "Could Not Load Document",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = message,
            style = MaterialTheme.typography.bodyMedium,
            color = AppColors.onSurfaceVariant
        )
    }
}
