//
//  DrugSearchService.swift
//  swastricare-mobile-swift
//
//  OpenFDA Drug Label API integration for medication search
//

import Foundation

// MARK: - API Response Models

struct FdaDrugResponse: Decodable {
    let results: [FdaDrugResult]?
}

struct FdaDrugResult: Decodable {
    let openfda: FdaOpenFda?
    let indicationsAndUsage: [String]?
    let dosageAndAdministration: [String]?
    let warnings: [String]?

    enum CodingKeys: String, CodingKey {
        case openfda
        case indicationsAndUsage = "indications_and_usage"
        case dosageAndAdministration = "dosage_and_administration"
        case warnings
    }
}

struct FdaOpenFda: Decodable {
    let brandName: [String]?
    let genericName: [String]?

    enum CodingKeys: String, CodingKey {
        case brandName = "brand_name"
        case genericName = "generic_name"
    }
}

// MARK: - Domain Models

struct DrugSearchResult: Identifiable, Equatable {
    let id: String
    let brandName: String
    let genericName: String?
    let dosage: String?
    let dosageUnit: String?
    let displayName: String
}

struct DrugDetails: Equatable {
    let description: String?
    let warnings: String?
    let dosageInfo: String?
}

// MARK: - Service Protocol

protocol DrugSearchServiceProtocol {
    func searchDrugs(query: String) async -> [DrugSearchResult]
    func getDrugDetails(brandName: String) async -> DrugDetails?
}

// MARK: - Service Implementation

final class DrugSearchService: DrugSearchServiceProtocol {
    static let shared = DrugSearchService()

    private let baseURL = "https://api.fda.gov/drug/label.json"
    private let session: URLSession
    private let dosageRegex = try! NSRegularExpression(
        pattern: #"(\d+(?:\.\d+)?)\s*(mg|mcg|g|ml|IU)"#,
        options: .caseInsensitive
    )

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)
    }

    func searchDrugs(query: String) async -> [DrugSearchResult] {
        guard let url = buildURL(search: "openfda.brand_name:\(query)*", limit: 5) else {
            return []
        }

        do {
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(FdaDrugResponse.self, from: data)

            guard let results = response.results else { return [] }

            var seen = Set<String>()
            return results.compactMap { result -> DrugSearchResult? in
                guard let brand = result.openfda?.brandName?.first else { return nil }
                let generic = result.openfda?.genericName?.first
                let rawDosage = result.dosageAndAdministration?.first

                let (dosageValue, dosageUnit) = extractDosage(from: rawDosage)

                let displayName: String
                if let dv = dosageValue, let du = dosageUnit {
                    displayName = "\(brand) \(dv)\(du)"
                } else {
                    displayName = brand
                }

                guard !seen.contains(displayName) else { return nil }
                seen.insert(displayName)

                return DrugSearchResult(
                    id: displayName,
                    brandName: brand,
                    genericName: generic,
                    dosage: dosageValue,
                    dosageUnit: dosageUnit,
                    displayName: displayName
                )
            }
        } catch {
            print("DrugSearch: search failed - \(error.localizedDescription)")
            return []
        }
    }

    func getDrugDetails(brandName: String) async -> DrugDetails? {
        guard let url = buildURL(search: "openfda.brand_name:\"\(brandName)\"", limit: 1) else {
            return nil
        }

        do {
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(FdaDrugResponse.self, from: data)
            let result = response.results?.first

            return DrugDetails(
                description: result?.indicationsAndUsage?.first,
                warnings: result?.warnings?.first,
                dosageInfo: result?.dosageAndAdministration?.first
            )
        } catch {
            print("DrugSearch: details failed - \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Private Helpers

    private func buildURL(search: String, limit: Int) -> URL? {
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "search", value: search),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return components?.url
    }

    private func extractDosage(from text: String?) -> (String?, String?) {
        guard let text = text else { return (nil, nil) }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = dosageRegex.firstMatch(in: text, range: range) else {
            return (nil, nil)
        }
        let value = (text as NSString).substring(with: match.range(at: 1))
        let unit = (text as NSString).substring(with: match.range(at: 2))
        return (value, unit)
    }
}
