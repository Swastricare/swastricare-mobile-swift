//
//  VaultDocSummary.swift
//  swastricare-mobile-swift
//
//  Family Monitoring — lightweight vault doc summary scoped by health_profile_id,
//  used by the family member dashboard. RLS allows the caregiver to read this
//  via `has_family_access(profile_id, 'view')`.
//

import Foundation
import Supabase

// MARK: - DTO

struct VaultDocSummary: Codable, Identifiable, Sendable {
    let id: String
    let name: String          // mapped from "title"
    let docType: String?      // mapped from "document_type"
    let uploadedAt: String    // mapped from "created_at"
    let fileUrl: String?      // mapped from "file_url"
    let fileName: String?     // mapped from "file_name"
    let fileSizeBytes: Int?   // mapped from "file_size_bytes"
    let mimeType: String?     // mapped from "mime_type"

    enum CodingKeys: String, CodingKey {
        case id
        case name = "title"
        case docType = "document_type"
        case uploadedAt = "created_at"
        case fileUrl = "file_url"
        case fileName = "file_name"
        case fileSizeBytes = "file_size_bytes"
        case mimeType = "mime_type"
    }
}

// MARK: - Profile-scoped accessor

extension SupabaseManager {

    /// Lists vault documents for the given health profile id.
    /// RLS enforces caregiver access via `has_family_access(profile_id, 'view')`.
    func listVaultForProfile(_ profileId: String) async throws -> [VaultDocSummary] {
        let rows: [VaultDocSummary] = try await client
            .from("medical_documents")
            .select("id, title, document_type, created_at, file_url, file_name, file_size_bytes, mime_type")
            .eq("health_profile_id", value: profileId)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows
    }
}
