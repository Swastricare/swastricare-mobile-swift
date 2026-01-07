//
//  DocumentViewer.swift
//  swastricare-mobile-swift
//
//  Created by Nikhil Deepak on 06/01/26.
//

import SwiftUI
import PDFKit
import UIKit

// MARK: - Document Viewer

struct DocumentViewer: View {
    let document: MedicalDocument
    
    @StateObject private var viewModel = DependencyContainer.shared.vaultViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var documentData: Data?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showShareSheet = false
    @State private var showDeleteAlert = false
    @State private var showInfoSheet = false
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    loadingView
                } else if let error = loadError {
                    errorView(error)
                } else if let data = documentData {
                    contentView(data: data)
                } else {
                    errorView("Document data not available")
                }
            }
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showInfoSheet = true
                        } label: {
                            Label("Info", systemImage: "info.circle")
                        }
                        
                        if documentData != nil {
                            Button {
                                showShareSheet = true
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let data = documentData {
                    ShareSheet(items: [data], fileName: document.title)
                }
            }
            .sheet(isPresented: $showInfoSheet) {
                DocumentInfoSheet(document: document)
            }
            .alert("Delete Document", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteDocument()
                    }
                }
            } message: {
                Text("Are you sure you want to delete \"\(document.title)\"? This action cannot be undone.")
            }
        }
        .task(id: document.id) {
            await loadDocument()
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading document...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Failed to Load")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                Task {
                    await loadDocument()
                }
            } label: {
                Text("Retry")
                    .fontWeight(.medium)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func contentView(data: Data) -> some View {
        let fileType = document.fileType.uppercased()
        
        if fileType == "PDF" {
            PDFViewerRepresentable(data: data)
        } else if ["JPG", "JPEG", "PNG", "HEIC"].contains(fileType) {
            if let image = UIImage(data: data) {
                ZoomableImageView(image: image)
            } else {
                errorView("Unable to load image")
            }
        } else {
            // Text-based files
            if let text = String(data: data, encoding: .utf8) {
                TextDocumentView(text: text)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("Preview not available for this file type")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadDocument() async {
        isLoading = true
        loadError = nil
        
        do {
            let data = try await viewModel.downloadDocument(document)
            await MainActor.run {
                documentData = data
                isLoading = false
            }
        } catch {
            // Handle cancellation gracefully
            if error is CancellationError {
                await MainActor.run {
                    isLoading = false
                }
                return
            }
            
            // Provide user-friendly error messages
            let errorMessage: String
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet, .networkConnectionLost:
                    errorMessage = "No internet connection. Please check your network and try again."
                case .timedOut:
                    errorMessage = "Request timed out. Please try again."
                default:
                    errorMessage = "Network error: \(urlError.localizedDescription)"
                }
            } else {
                errorMessage = error.localizedDescription
            }
            
            await MainActor.run {
                loadError = errorMessage
                isLoading = false
            }
        }
    }
    
    private func deleteDocument() async {
        let success = await viewModel.deleteDocument(document)
        if success {
            dismiss()
        }
    }
}

// MARK: - PDF Viewer

struct PDFViewerRepresentable: UIViewRepresentable {
    let data: Data
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .systemBackground
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document == nil, let document = PDFDocument(data: data) {
            pdfView.document = document
        }
    }
}

// MARK: - Zoomable Image View

struct ZoomableImageView: View {
    let image: UIImage
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                scale = min(max(scale * delta, 1.0), 5.0)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                if scale < 1.0 {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        scale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                guard scale > 1.0 else { return }
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            if scale > 1.0 {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.5
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - Text Document View

struct TextDocumentView: View {
    let text: String
    
    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(.body, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var fileName: String?
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        // If we have a fileName, try to create a temporary file for better sharing
        var shareItems: [Any] = []
        
        if let data = items.first as? Data, let name = fileName {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            do {
                try data.write(to: tempURL)
                shareItems = [tempURL]
            } catch {
                shareItems = items
            }
        } else {
            shareItems = items
        }
        
        let controller = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Document Info Sheet

struct DocumentInfoSheet: View {
    let document: MedicalDocument
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Document Details") {
                    InfoRow(label: "Title", value: document.title)
                    InfoRow(label: "Category", value: document.category)
                    InfoRow(label: "File Type", value: document.fileType)
                    InfoRow(label: "Size", value: formattedSize)
                    InfoRow(label: "Uploaded", value: formattedDate)
                }
                
                if let notes = document.notes, !notes.isEmpty {
                    Section("Notes") {
                        Text(notes)
                            .font(.body)
                    }
                }
            }
            .navigationTitle("Document Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: document.fileSize)
    }
    
    private var formattedDate: String {
        guard let date = document.uploadedAt else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
    }
}
