//
//  VaultView.swift
//  swastricare-mobile-swift
//
//  Created by Nikhil Deepak on 06/01/26.
//

import SwiftUI

struct VaultView: View {
    // Mock Data
    private let categories = [
        VaultCategory(name: "Lab Reports", icon: "testtube.2", color: .blue),
        VaultCategory(name: "Prescriptions", icon: "pills.fill", color: .green),
        VaultCategory(name: "Insurance", icon: "shield.fill", color: .orange),
        VaultCategory(name: "Imaging", icon: "waveform.path.ecg", color: .purple)
    ]
    
    private let recentFiles = [
        VaultFile(name: "Blood Test Result", date: "Jan 5, 2026", type: "PDF", icon: "doc.text.fill", color: .red),
        VaultFile(name: "Vaccination Cert", date: "Dec 12, 2025", type: "PDF", icon: "checkmark.seal.fill", color: .blue),
        VaultFile(name: "MRI Scan - Knee", date: "Nov 20, 2025", type: "DICOM", icon: "film.fill", color: .gray),
        VaultFile(name: "Prescription #128", date: "Oct 05, 2025", type: "IMG", icon: "photo.fill", color: .green)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HeroHeader(
                    title: "Medical Vault",
                    subtitle: "Secure Storage",
                    icon: "lock.shield.fill"
                )
                
                // Search Bar (Glass)
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    Text("Search records...")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
                .glass(cornerRadius: 16)
                .padding(.horizontal)
                
                // Categories Grid
                VStack(alignment: .leading, spacing: 15) {
                    Text("Categories")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                        ForEach(categories) { category in
                            VaultCategoryCard(category: category)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Recent Files
                VStack(alignment: .leading, spacing: 15) {
                    Text("Recent Uploads")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        ForEach(recentFiles) { file in
                            VaultFileRow(file: file)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Bottom Padding for Dock
                Color.clear.frame(height: 100)
            }
            .padding(.top)
        }
    }
}

// MARK: - Vault Helpers

struct VaultCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
}

struct VaultFile: Identifiable {
    let id = UUID()
    let name: String
    let date: String
    let type: String
    let icon: String
    let color: Color
}

struct VaultCategoryCard: View {
    let category: VaultCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Circle()
                .fill(
                    LinearGradient(colors: [category.color.opacity(0.2), category.color.opacity(0.1)], startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: category.icon)
                        .foregroundColor(category.color)
                        .font(.title3)
                )
            
            Text(category.name)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glass(cornerRadius: 20)
    }
}

struct VaultFileRow: View {
    let file: VaultFile
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: file.icon)
                .font(.title2)
                .foregroundColor(file.color)
                .padding(10)
                .background(file.color.opacity(0.1))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("\(file.date) • \(file.type)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .glass(cornerRadius: 16)
    }
}
