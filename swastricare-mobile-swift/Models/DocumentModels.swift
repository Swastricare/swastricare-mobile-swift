//
//  DocumentModels.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Models Layer
//  Note: MedicalDocument is defined in SupabaseManager.swift to match API types
//

import Foundation
import SwiftUI

// MARK: - Vault Category (UI representation for document categories)

enum VaultCategory: String, CaseIterable, Identifiable {
    case prescriptions = "Prescriptions"
    case labReports = "Lab Reports"
    case imaging = "Imaging"
    case insurance = "Insurance"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .prescriptions: return "pills.fill"
        case .labReports: return "flask.fill"
        case .imaging: return "waveform.path.ecg"
        case .insurance: return "shield.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .prescriptions: return .blue
        case .labReports: return .purple
        case .imaging: return .orange
        case .insurance: return .green
        }
    }
}

// MARK: - Document Upload State

struct DocumentUploadState: Equatable {
    var isUploading: Bool = false
    var progress: Double = 0.0
    var error: String?
    
    static let idle = DocumentUploadState()
}

// MARK: - Vault State

enum VaultState: Equatable {
    case idle
    case loading
    case loaded([MedicalDocument])
    case error(String)
    
    var documents: [MedicalDocument] {
        if case .loaded(let docs) = self { return docs }
        return []
    }
    
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

// MARK: - Document Helpers

extension MedicalDocument {
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    var formattedDate: String {
        guard let date = createdAt else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    var icon: String {
        switch fileType.uppercased() {
        case "PDF": return "doc.text.fill"
        case "JPG", "JPEG", "PNG", "HEIC": return "photo.fill"
        case "DOC", "DOCX": return "doc.richtext.fill"
        case "TXT", "RTF": return "doc.plaintext.fill"
        case "CSV": return "tablecells.fill"
        default: return "doc.fill"
        }
    }
    
    var iconColor: Color {
        switch fileType.uppercased() {
        case "PDF": return .red
        case "JPG", "JPEG", "PNG", "HEIC": return .blue
        case "DOC", "DOCX": return .indigo
        case "TXT", "RTF": return .gray
        case "CSV": return .green
        default: return .gray
        }
    }
}

