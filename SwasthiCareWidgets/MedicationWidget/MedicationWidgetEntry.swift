//
//  MedicationWidgetEntry.swift
//  SwasthiCareWidgets
//
//  Timeline entry for medication widget
//

import WidgetKit
import Foundation

struct MedicationWidgetEntry: TimelineEntry {
    let date: Date
    let medicationData: WidgetMedicationData
    let configuration: MedicationWidgetConfigurationIntent?
    
    init(
        date: Date = Date(),
        medicationData: WidgetMedicationData = .empty,
        configuration: MedicationWidgetConfigurationIntent? = nil
    ) {
        self.date = date
        self.medicationData = medicationData
        self.configuration = configuration
    }
    
    // Convenience properties
    var medications: [WidgetMedicationItem] { medicationData.medications }
    var takenCount: Int { medicationData.takenCount }
    var totalCount: Int { medicationData.totalCount }
    var adherencePercentage: Double { medicationData.adherencePercentage }
    var nextMedication: WidgetMedicationItem? { medicationData.nextMedication }
    var overdueMedication: WidgetMedicationItem? { medicationData.overdueMedication }
    
    var hasMedications: Bool {
        !medications.isEmpty
    }
    
    var hasUpcoming: Bool {
        nextMedication != nil
    }
    
    var hasOverdue: Bool {
        overdueMedication != nil
    }
    
    // Status
    var status: MedicationWidgetStatus {
        if hasOverdue {
            return .overdue
        } else if adherencePercentage >= 1.0 {
            return .allTaken
        } else if hasUpcoming {
            return .upcoming
        } else {
            return .normal
        }
    }
    
    // Formatted strings
    var progressText: String {
        "\(takenCount)/\(totalCount)"
    }
    
    var percentageText: String {
        "\(Int(adherencePercentage * 100))%"
    }
    
    // Placeholder/preview entry
    static let placeholder = MedicationWidgetEntry(
        date: Date(),
        medicationData: .placeholder
    )
    
    static let empty = MedicationWidgetEntry(
        date: Date(),
        medicationData: .empty
    )
}

// MARK: - Widget Status

enum MedicationWidgetStatus {
    case normal
    case upcoming
    case overdue
    case allTaken
    
    var message: String {
        switch self {
        case .normal:
            return "No medications due"
        case .upcoming:
            return "Coming up"
        case .overdue:
            return "Overdue!"
        case .allTaken:
            return "All done! 🎉"
        }
    }
    
    var iconName: String {
        switch self {
        case .normal:
            return "pills"
        case .upcoming:
            return "clock"
        case .overdue:
            return "exclamationmark.triangle.fill"
        case .allTaken:
            return "checkmark.circle.fill"
        }
    }
}

// MARK: - Configuration Intent (for future customization)

struct MedicationWidgetConfigurationIntent {
    // Placeholder for future widget configuration options
    // e.g., show specific medication, notification style
}
