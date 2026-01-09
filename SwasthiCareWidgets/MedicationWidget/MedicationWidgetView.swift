//
//  MedicationWidgetView.swift
//  SwasthiCareWidgets
//
//  Widget views for medication tracking (Small & Medium)
//

import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Small Widget View

struct MedicationWidgetSmallView: View {
    let entry: MedicationWidgetEntry
    
    var body: some View {
        VStack(spacing: 8) {
            if entry.hasMedications {
                // Show next/overdue medication
                if let med = entry.overdueMedication ?? entry.nextMedication {
                    VStack(spacing: 6) {
                        // Status icon
                        Image(systemName: med.typeIcon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(statusColor(for: med))
                        
                        // Medication name
                        Text(med.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        
                        // Time
                        HStack(spacing: 4) {
                            Image(systemName: med.isOverdue ? "exclamationmark.triangle.fill" : "clock")
                                .font(.system(size: 10))
                            Text(med.formattedTime)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(med.isOverdue ? .red : .secondary)
                        
                        // Progress
                        Text("\(entry.takenCount)/\(entry.totalCount) taken")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // All done state
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(.green)
                        
                        Text("All Done!")
                            .font(.system(size: 14, weight: .semibold))
                        
                        Text("\(entry.takenCount)/\(entry.totalCount)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                // No medications
                VStack(spacing: 8) {
                    Image(systemName: "pills")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    
                    Text("No medications")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    Text("Tap to add")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
        .widgetURL(URL(string: "swasthicare://medications"))
    }
    
    private func statusColor(for med: WidgetMedicationItem) -> Color {
        switch med.status {
        case .pending:
            return med.isOverdue ? .red : .blue
        case .taken:
            return .green
        case .missed:
            return .red
        case .skipped:
            return .orange
        }
    }
}

// MARK: - Medium Widget View

struct MedicationWidgetMediumView: View {
    let entry: MedicationWidgetEntry
    
    var body: some View {
        HStack(spacing: 12) {
            // Left side - Summary
            VStack(alignment: .leading, spacing: 8) {
                // Title
                HStack {
                    Image(systemName: "pills.fill")
                        .foregroundStyle(.blue)
                    Text("Medications")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                
                if entry.hasMedications {
                    // Progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        
                        Circle()
                            .trim(from: 0, to: entry.adherencePercentage)
                            .stroke(
                                progressColor,
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 0) {
                            Text("\(entry.takenCount)")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            Text("/\(entry.totalCount)")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 60, height: 60)
                    
                    // Status message
                    Text(entry.status.message)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(statusColor)
                } else {
                    Spacer()
                    Text("No medications\nscheduled")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
            }
            .frame(width: 100)
            
            Divider()
            
            // Right side - Medication list
            VStack(alignment: .leading, spacing: 6) {
                if entry.hasMedications {
                    // Show up to 3 medications
                    ForEach(entry.medications.prefix(3)) { med in
                        MedicationRowView(medication: med)
                    }
                    
                    if entry.medications.count > 3 {
                        Text("+\(entry.medications.count - 3) more")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.blue)
                            Text("Add medication")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
        .widgetURL(URL(string: "swasthicare://medications"))
    }
    
    private var progressColor: Color {
        switch entry.status {
        case .overdue:
            return .red
        case .allTaken:
            return .green
        default:
            return .blue
        }
    }
    
    private var statusColor: Color {
        switch entry.status {
        case .overdue:
            return .red
        case .allTaken:
            return .green
        default:
            return .secondary
        }
    }
}

// MARK: - Medication Row View

struct MedicationRowView: View {
    let medication: WidgetMedicationItem
    
    var body: some View {
        HStack(spacing: 8) {
            // Status icon
            Image(systemName: statusIcon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(width: 16)
            
            // Medication info
            VStack(alignment: .leading, spacing: 1) {
                Text(medication.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(medication.dosage)
                    Text("•")
                    Text(medication.formattedTime)
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            
            Spacer(minLength: 0)
            
            // Quick action button (iOS 17+)
            if #available(iOS 17.0, *), medication.status == .pending {
                Button(intent: MarkMedicationTakenIntent(medicationId: medication.id.uuidString)) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusIcon: String {
        switch medication.status {
        case .pending:
            return medication.isOverdue ? "exclamationmark.circle.fill" : "clock"
        case .taken:
            return "checkmark.circle.fill"
        case .missed:
            return "xmark.circle.fill"
        case .skipped:
            return "minus.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch medication.status {
        case .pending:
            return medication.isOverdue ? .red : .orange
        case .taken:
            return .green
        case .missed:
            return .red
        case .skipped:
            return .gray
        }
    }
}

// MARK: - Main Widget View

struct MedicationWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: MedicationWidgetEntry
    
    var body: some View {
        switch family {
        case .systemSmall:
            MedicationWidgetSmallView(entry: entry)
        case .systemMedium:
            MedicationWidgetMediumView(entry: entry)
        default:
            MedicationWidgetSmallView(entry: entry)
        }
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    MedicationWidget()
} timeline: {
    MedicationWidgetEntry.placeholder
    MedicationWidgetEntry.empty
}

#Preview("Medium", as: .systemMedium) {
    MedicationWidget()
} timeline: {
    MedicationWidgetEntry.placeholder
}
