//
//  YogaModels.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Models Layer
//  Yoga Poses and Categories from yoga-api
//

import Foundation
import SwiftUI

// MARK: - Difficulty Level

enum YogaDifficultyLevel: String, Codable, CaseIterable, Identifiable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case expert = "Expert"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
    var color: Color {
        switch self {
        case .beginner: return Color(hex: "4ECDC4")
        case .intermediate: return Color(hex: "FFB347")
        case .expert: return Color(hex: "FF6B6B")
        }
    }
    
    var icon: String {
        switch self {
        case .beginner: return "leaf.fill"
        case .intermediate: return "flame.fill"
        case .expert: return "star.fill"
        }
    }
}

// MARK: - Yoga Pose

struct YogaPose: Identifiable, Codable, Equatable {
    let id: Int
    let categoryName: String?
    let difficultyLevel: String?
    let englishName: String
    let sanskritNameAdapted: String
    let sanskritName: String
    let translationName: String
    let poseDescription: String?
    let poseBenefits: String
    let urlSvg: String
    let urlPng: String
    let urlSvgAlt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case categoryName = "category_name"
        case difficultyLevel = "difficulty_level"
        case englishName = "english_name"
        case sanskritNameAdapted = "sanskrit_name_adapted"
        case sanskritName = "sanskrit_name"
        case translationName = "translation_name"
        case poseDescription = "pose_description"
        case poseBenefits = "pose_benefits"
        case urlSvg = "url_svg"
        case urlPng = "url_png"
        case urlSvgAlt = "url_svg_alt"
    }
    
    var difficulty: YogaDifficultyLevel? {
        guard let level = difficultyLevel else { return nil }
        return YogaDifficultyLevel(rawValue: level)
    }
    
    var imageURL: URL? {
        URL(string: urlPng)
    }
    
    var benefitsList: [String] {
        poseBenefits
            .components(separatedBy: ".")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Yoga Category

struct YogaCategory: Identifiable, Codable, Equatable {
    let id: Int
    let categoryName: String
    let categoryDescription: String
    let poses: [YogaPose]
    
    enum CodingKeys: String, CodingKey {
        case id
        case categoryName = "category_name"
        case categoryDescription = "category_description"
        case poses
    }
    
    var icon: String {
        switch categoryName.lowercased() {
        case let name where name.contains("core"):
            return "figure.core.training"
        case let name where name.contains("seated"):
            return "figure.mind.and.body"
        case let name where name.contains("standing"):
            return "figure.stand"
        case let name where name.contains("chest"):
            return "heart.fill"
        case let name where name.contains("backbend"):
            return "figure.flexibility"
        case let name where name.contains("forward"):
            return "arrow.down.forward"
        case let name where name.contains("hip"):
            return "figure.walk"
        case let name where name.contains("restorative"):
            return "moon.stars.fill"
        case let name where name.contains("arm"):
            return "figure.strengthtraining.traditional"
        case let name where name.contains("balance"):
            return "figure.yoga"
        case let name where name.contains("inversion"):
            return "arrow.up.arrow.down"
        default:
            return "figure.yoga"
        }
    }
    
    var color: Color {
        switch id % 6 {
        case 0: return Color(hex: "5856D6")
        case 1: return Color(hex: "4ECDC4")
        case 2: return Color(hex: "FF6B6B")
        case 3: return Color(hex: "C6FF00")
        case 4: return Color(hex: "FFB347")
        case 5: return Color(hex: "45B7D1")
        default: return Color(hex: "5856D6")
        }
    }
}

// MARK: - Poses by Level Response

struct PosesByLevelResponse: Codable {
    let id: Int
    let difficultyLevel: String
    let poses: [YogaPose]
    
    enum CodingKeys: String, CodingKey {
        case id
        case difficultyLevel = "difficulty_level"
        case poses
    }
}

// MARK: - API Error Response

struct YogaAPIError: Codable {
    let message: String
}

// MARK: - Sample Data for Previews

extension YogaPose {
    static let sample = YogaPose(
        id: 1,
        categoryName: "Core Yoga",
        difficultyLevel: "Beginner",
        englishName: "Boat",
        sanskritNameAdapted: "Navasana",
        sanskritName: "Nāvāsana",
        translationName: "nāva = boat, āsana = posture",
        poseDescription: "From a seated position, the legs are lifted up to a 45 degree angle with the torso.",
        poseBenefits: "Strengthens the abdomen, hip flexors, and spine. Stimulates the kidneys, thyroid and prostate glands, and intestines. Helps relieve stress. Improves digestion.",
        urlSvg: "https://res.cloudinary.com/dko1be2jy/image/upload/fl_sanitize/v1676483074/yoga-api/1_txmirf.svg",
        urlPng: "https://res.cloudinary.com/dko1be2jy/image/upload/fl_sanitize/v1676483074/yoga-api/1_txmirf.png",
        urlSvgAlt: nil
    )
    
    static let samples: [YogaPose] = [
        sample,
        YogaPose(
            id: 5,
            categoryName: "Seated Yoga",
            difficultyLevel: "Beginner",
            englishName: "Butterfly",
            sanskritNameAdapted: "Baddha Konasana",
            sanskritName: "Baddha Koṇāsana",
            translationName: "baddha = bound, koṇa = angle, āsana = posture",
            poseDescription: "In sitting position, bend both knees and drop the knees to each side, opening the hips.",
            poseBenefits: "Opens the hips and groins. Stretches the shoulders, rib cage and back. Stimulates the abdominal organs, lungs and heart.",
            urlSvg: "https://res.cloudinary.com/dko1be2jy/image/upload/fl_sanitize/v1676483074/yoga-api/5_i64gif.svg",
            urlPng: "https://res.cloudinary.com/dko1be2jy/image/upload/fl_sanitize/v1676483074/yoga-api/5_i64gif.png",
            urlSvgAlt: nil
        ),
        YogaPose(
            id: 8,
            categoryName: "Backbend Yoga",
            difficultyLevel: "Beginner",
            englishName: "Cow",
            sanskritNameAdapted: "Bitilasana",
            sanskritName: "Bitilāsana",
            translationName: "bitil = cow, āsana = posture",
            poseDescription: nil,
            poseBenefits: "From box neutral the ribcage is lifted with a gentle sway in the low back. The tailbone lifts up into dog tilt. The eyes are soft and the gaze is to the sky.",
            urlSvg: "https://res.cloudinary.com/dko1be2jy/image/upload/fl_sanitize/v1676483077/yoga-api/8_wi10sn.svg",
            urlPng: "https://res.cloudinary.com/dko1be2jy/image/upload/fl_sanitize/v1676483077/yoga-api/8_wi10sn.png",
            urlSvgAlt: nil
        )
    ]
}

extension YogaCategory {
    static let sample = YogaCategory(
        id: 1,
        categoryName: "Core Yoga",
        categoryDescription: "Engage your abdominal muscles with core yoga poses that build a strong and stable center like Boat Pose, Dolphin Pose and Side Plank Pose.",
        poses: YogaPose.samples
    )
}
