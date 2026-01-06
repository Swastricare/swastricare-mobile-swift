//
//  DocumentViewer.swift
//  swastricare-mobile-swift
//
//  Created by Nikhil Deepak on 06/01/26.
//

import SwiftUI
import PDFKit

// MARK: - Document Viewer
struct DocumentViewer: View {
    let document: MedicalDocument
    @StateObject private var vaultManager = VaultManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var documentData: Data?
    @State private var isLoading = true
    @State private var showShareSheet = false
    @State private var showDeleteAlert = false
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading document...")
                } else if let data = documentData {
                    if document.fileType.uppercased() == "PDF" {
                        PDFViewerRepresentable(data: data)
                    } else {
                        // Image viewer
                        if let uiImage = UIImage(data: data) {
                            ImageViewerContent(image: uiImage)
                        } else {
                            Text("Unable to load image")
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text("Failed to load document")
                            .font(.headline)
                        Button("Try Again") {
                            Task {
                                await loadDocument()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showShareSheet = true
                        }) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(role: .destructive, action: {
                            showDeleteAlert = true
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let data = documentData {
                    ShareSheet(items: [data])
                }
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
        .task {
            await loadDocument()
        }
    }
    
    private func loadDocument() async {
        isLoading = true
        documentData = await vaultManager.downloadDocument(document)
        isLoading = false
    }
    
    private func deleteDocument() async {
        await vaultManager.deleteDocument(document)
        presentationMode.wrappedValue.dismiss()
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
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        if let pdfDocument = PDFDocument(data: data) {
            pdfView.document = pdfDocument
        }
    }
}

// MARK: - Image Viewer
struct ImageViewerContent: View {
    let image: UIImage
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width * scale, height: geometry.size.height * scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                scale = scale * delta
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                if scale < 1.0 {
                                    withAnimation {
                                        scale = 1.0
                                        offset = .zero
                                    }
                                } else if scale > 4.0 {
                                    withAnimation {
                                        scale = 4.0
                                    }
                                }
                            }
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onTapGesture(count: 2) {
            withAnimation {
                if scale > 1.0 {
                    scale = 1.0
                    offset = .zero
                    lastOffset = .zero
                } else {
                    scale = 2.0
                }
            }
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Document Info View
struct DocumentInfoView: View {
    let document: MedicalDocument
    @StateObject private var vaultManager = VaultManager.shared
    
    var body: some View {
        List {
            Section("Document Details") {
                InfoRow(label: "Title", value: document.title)
                InfoRow(label: "Category", value: document.category)
                InfoRow(label: "File Type", value: document.fileType)
                InfoRow(label: "Size", value: vaultManager.formatFileSize(document.fileSize))
                InfoRow(label: "Uploaded", value: vaultManager.formatDate(document.uploadedAt))
            }
            
            if let notes = document.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                        .font(.body)
                }
            }
        }
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
        }
    }
}
