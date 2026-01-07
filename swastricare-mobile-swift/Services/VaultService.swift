//
//  VaultService.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Services Layer
//  Handles document storage operations with Supabase
//

import Foundation

// MARK: - Vault Service Protocol

protocol VaultServiceProtocol {
    func fetchDocuments() async throws -> [MedicalDocument]
    func uploadDocument(fileData: Data, fileName: String, category: String, notes: String?) async throws -> MedicalDocument
    func deleteDocument(_ document: MedicalDocument) async throws
    func downloadDocument(storagePath: String) async throws -> Data
}

// MARK: - Vault Service Implementation

final class VaultService: VaultServiceProtocol {
    
    static let shared = VaultService()
    
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    // MARK: - Fetch Documents
    
    func fetchDocuments() async throws -> [MedicalDocument] {
        try await supabase.fetchUserDocuments()
    }
    
    // MARK: - Upload Document
    
    func uploadDocument(fileData: Data, fileName: String, category: String, notes: String?) async throws -> MedicalDocument {
        guard !fileData.isEmpty else {
            throw VaultError.emptyFile
        }
        
        return try await supabase.uploadDocument(
            fileData: fileData,
            fileName: fileName,
            category: category,
            notes: notes
        )
    }
    
    // MARK: - Delete Document
    
    func deleteDocument(_ document: MedicalDocument) async throws {
        try await supabase.deleteDocument(document: document)
    }
    
    // MARK: - Download Document
    
    func downloadDocument(storagePath: String) async throws -> Data {
        try await supabase.downloadDocument(storagePath: storagePath)
    }
}

// MARK: - Vault Errors

enum VaultError: LocalizedError {
    case emptyFile
    case uploadFailed
    case deleteFailed
    case downloadFailed
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .emptyFile: return "File is empty"
        case .uploadFailed: return "Failed to upload document"
        case .deleteFailed: return "Failed to delete document"
        case .downloadFailed: return "Failed to download document"
        case .notFound: return "Document not found"
        }
    }
}

