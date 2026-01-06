//
//  DocumentPicker.swift
//  swastricare-mobile-swift
//
//  Created by Nikhil Deepak on 06/01/26.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Document Picker for PDFs
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedFileData: Data?
    @Binding var selectedFileName: String?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                return
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            do {
                let data = try Data(contentsOf: url)
                parent.selectedFileData = data
                parent.selectedFileName = url.lastPathComponent
            } catch {
                print("Error loading document: \(error)")
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Image Picker using PhotosUI
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImageData: Data?
    @Binding var selectedFileName: String?
    @Environment(\.presentationMode) var presentationMode
    
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
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            guard let provider = results.first?.itemProvider else { return }
            
            // Handle different image formats
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                    guard let self = self, let image = image as? UIImage else { return }
                    
                    DispatchQueue.main.async {
                        // Convert to JPEG data
                        if let imageData = image.jpegData(compressionQuality: 0.8) {
                            self.parent.selectedImageData = imageData
                            
                            // Generate filename with timestamp
                            let timestamp = Date().timeIntervalSince1970
                            self.parent.selectedFileName = "image_\(Int(timestamp)).jpg"
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Unified File Picker Sheet
struct FilePicker: View {
    @Binding var isPresented: Bool
    let onFilePicked: (Data, String) -> Void
    
    @State private var selectedFileData: Data?
    @State private var selectedFileName: String?
    @State private var showDocumentPicker = false
    @State private var showImagePicker = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(action: {
                        showImagePicker = true
                    }) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                                .foregroundColor(.blue)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Choose from Photos")
                                    .font(.headline)
                                Text("Select an image from your library")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 8)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Button(action: {
                        showDocumentPicker = true
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.red)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Choose PDF")
                                    .font(.headline)
                                Text("Select a PDF document")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 8)
                        }
                        .padding(.vertical, 8)
                    }
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
                DocumentPicker(selectedFileData: $selectedFileData, selectedFileName: $selectedFileName)
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImageData: $selectedFileData, selectedFileName: $selectedFileName)
            }
            .onChange(of: selectedFileData) { newValue in
                if let data = newValue, let name = selectedFileName {
                    onFilePicked(data, name)
                    isPresented = false
                }
            }
        }
    }
}
