//
//  DocumentPicker.swift
//  swastricare-mobile-swift
//
//  Created by Nikhil Deepak on 06/01/26.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

// MARK: - File Validation

struct FileValidator {
    static let maxFileSize: Int64 = 10 * 1024 * 1024 // 10MB
    
    static let allowedExtensions = ["pdf", "jpg", "jpeg", "png", "heic", "txt", "rtf", "doc", "docx", "csv"]
    
    static let allowedUTTypes: [UTType] = [
        .pdf,
        .jpeg,
        .png,
        .heic,
        .plainText,
        .rtf,
        .commaSeparatedText,
        UTType(filenameExtension: "doc") ?? .data,
        UTType(filenameExtension: "docx") ?? .data
    ]
    
    static func validate(data: Data, fileName: String) -> (isValid: Bool, error: String?) {
        // Check if empty
        if data.isEmpty {
            return (false, "File is empty")
        }
        
        // Check file size
        if Int64(data.count) > maxFileSize {
            let maxMB = maxFileSize / (1024 * 1024)
            return (false, "File too large. Maximum size is \(maxMB)MB")
        }
        
        // Check file extension
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        
        if fileExtension.isEmpty {
            return (false, "Unknown file type")
        }
        
        if !allowedExtensions.contains(fileExtension) {
            return (false, "Unsupported format. Allowed: PDF, Images, DOC, DOCX, TXT, RTF, CSV")
        }
        
        return (true, nil)
    }
    
    static func getFileType(from fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.uppercased()
        return ext.isEmpty ? "UNKNOWN" : ext
    }
}

// MARK: - Document Picker (Files App)

struct DocumentPicker: UIViewControllerRepresentable {
    let onDocumentPicked: (Data, String) -> Void
    let onCancel: () -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: FileValidator.allowedUTTypes,
            asCopy: true
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onDocumentPicked: onDocumentPicked, onCancel: onCancel)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onDocumentPicked: (Data, String) -> Void
        let onCancel: () -> Void
        
        init(onDocumentPicked: @escaping (Data, String) -> Void, onCancel: @escaping () -> Void) {
            self.onDocumentPicked = onDocumentPicked
            self.onCancel = onCancel
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onCancel()
                return
            }
            
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                print("DocumentPicker: Failed to access security-scoped resource")
                onCancel()
                return
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            do {
                let data = try Data(contentsOf: url)
                let fileName = url.lastPathComponent
                onDocumentPicked(data, fileName)
            } catch {
                print("DocumentPicker: Error loading document - \(error)")
                onCancel()
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}

// MARK: - Image Picker (Photos Library)

struct ImagePicker: UIViewControllerRepresentable {
    let onImagePicked: (Data, String) -> Void
    let onCancel: () -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, onCancel: onCancel)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImagePicked: (Data, String) -> Void
        let onCancel: () -> Void
        
        init(onImagePicked: @escaping (Data, String) -> Void, onCancel: @escaping () -> Void) {
            self.onImagePicked = onImagePicked
            self.onCancel = onCancel
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else {
                onCancel()
                return
            }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("ImagePicker: Error loading image - \(error)")
                        DispatchQueue.main.async {
                            self.onCancel()
                        }
                        return
                    }
                    
                    guard let uiImage = image as? UIImage else {
                        DispatchQueue.main.async {
                            self.onCancel()
                        }
                        return
                    }
                    
                    // Convert to JPEG with good quality
                    guard let imageData = uiImage.jpegData(compressionQuality: 0.85) else {
                        DispatchQueue.main.async {
                            self.onCancel()
                        }
                        return
                    }
                    
                    // Generate unique filename
                    let timestamp = Int(Date().timeIntervalSince1970)
                    let fileName = "photo_\(timestamp).jpg"
                    
                    DispatchQueue.main.async {
                        self.onImagePicked(imageData, fileName)
                    }
                }
            } else {
                onCancel()
            }
        }
    }
}

// MARK: - Unified File Picker Sheet

struct FilePicker: View {
    @Binding var isPresented: Bool
    let onFilePicked: (Data, String) -> Void
    
    @State private var showDocumentPicker = false
    @State private var showImagePicker = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    // Photos option
                    Button {
                        showImagePicker = true
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Choose from Photos")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Select an image from your library")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Documents option
                    Button {
                        showDocumentPicker = true
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Choose Document")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("PDF, Word, Text, and more")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("Select Source")
                } footer: {
                    Text("Supported formats: PDF, JPG, PNG, HEIC, DOC, DOCX, TXT, RTF, CSV\nMaximum file size: 10MB")
                        .font(.caption2)
                }
            }
            .navigationTitle("Upload Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker(
                    onDocumentPicked: { data, fileName in
                        showDocumentPicker = false
                        isPresented = false
                        onFilePicked(data, fileName)
                    },
                    onCancel: {
                        showDocumentPicker = false
                    }
                )
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(
                    onImagePicked: { data, fileName in
                        showImagePicker = false
                        isPresented = false
                        onFilePicked(data, fileName)
                    },
                    onCancel: {
                        showImagePicker = false
                    }
                )
            }
        }
    }
}
