//
//  ReceiptScannerService.swift
//  iExpense
//
//  On-device receipt OCR via Vision — extracts line items, prices, and totals.
//

import Foundation
import Vision
import UIKit

struct ReceiptLineItem: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var price: Double
    var isSelected: Bool = true
    var suggestedCategoryID: String
}

struct ReceiptScanResult {
    var merchant: String?
    var items: [ReceiptLineItem]
    var total: Double?
    var rawText: String
    var photoData: Data?

    var selectedTotal: Double {
        items.filter(\.isSelected).reduce(0) { $0 + $1.price }
    }
}

enum ReceiptScannerError: LocalizedError {
    case noTextFound
    case noPricesFound
    case imageProcessingFailed

    var errorDescription: String? {
        switch self {
        case .noTextFound:
            return "Couldn't read any text from this photo. Try a clearer shot of the receipt."
        case .noPricesFound:
            return "Found text, but no prices. Make sure prices are visible on the receipt."
        case .imageProcessingFailed:
            return "Couldn't process this image."
        }
    }
}

final class ReceiptScannerService {
    static let shared = ReceiptScannerService()

    func scan(image: UIImage) async throws -> ReceiptScanResult {
        guard let cgImage = image.cgImage else {
            throw ReceiptScannerError.imageProcessingFailed
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        let observations = request.results ?? []
        let lines = observations.compactMap { $0.topCandidates(1).first?.string }
        let rawText = lines.joined(separator: "\n")

        guard !lines.isEmpty else {
            throw ReceiptScannerError.noTextFound
        }

        let merchant = detectMerchant(from: lines)
        let items = parseLineItems(from: lines)
        let total = detectTotal(from: lines) ?? (items.isEmpty ? nil : items.reduce(0) { $0 + $1.price })

        guard !items.isEmpty || total != nil else {
            throw ReceiptScannerError.noPricesFound
        }

        let photoData = image.jpegData(compressionQuality: 0.7)

        // If no line items but we have a total, create a single grocery spend
        if items.isEmpty, let total {
            let fallback = ReceiptLineItem(
                name: merchant ?? "Receipt purchase",
                price: total,
                suggestedCategoryID: Category.food.categoryID
            )
            return ReceiptScanResult(
                merchant: merchant,
                items: [fallback],
                total: total,
                rawText: rawText,
                photoData: photoData
            )
        }

        return ReceiptScanResult(
            merchant: merchant,
            items: items,
            total: total,
            rawText: rawText,
            photoData: photoData
        )
    }

    // MARK: - Parsing

    private func detectMerchant(from lines: [String]) -> String? {
        let skip = ["total", "subtotal", "tax", "change", "cash", "card", "visa", "mastercard", "receipt", "thank"]
        for line in lines.prefix(6) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 3, trimmed.count <= 40 else { continue }
            let lower = trimmed.lowercased()
            if skip.contains(where: { lower.contains($0) }) { continue }
            if trimmed.rangeOfCharacter(from: .decimalDigits) != nil { continue }
            return trimmed
        }
        return nil
    }

    private func detectTotal(from lines: [String]) -> Double? {
        let totalKeywords = ["total", "amount due", "balance due", "grand total", "amount"]
        for line in lines.reversed() {
            let lower = line.lowercased()
            guard totalKeywords.contains(where: { lower.contains($0) }) else { continue }
            if lower.contains("subtotal") || lower.contains("sub total") { continue }
            if let price = extractPrice(from: line) {
                return price
            }
        }
        // Fallback: largest price-looking number near the bottom
        let bottom = lines.suffix(8)
        let prices = bottom.compactMap { extractPrice(from: $0) }
        return prices.max()
    }

    private func parseLineItems(from lines: [String]) -> [ReceiptLineItem] {
        var items: [ReceiptLineItem] = []
        let skipKeywords = ["total", "subtotal", "tax", "vat", "change", "cash", "visa", "mastercard", "debit", "credit", "balance", "amount due", "thank you", "tel", "phone", "www", "http"]

        for line in lines {
            let lower = line.lowercased()
            if skipKeywords.contains(where: { lower.contains($0) }) { continue }
            guard let price = extractPrice(from: line) else { continue }
            guard price > 0, price < 100_000 else { continue }

            var name = stripPrice(from: line)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            // Remove trailing qty markers like "x2"
            name = name.replacingOccurrences(of: #"\s*[xX]\s*\d+\s*$"#, with: "", options: .regularExpression)
            name = name.trimmingCharacters(in: CharacterSet(charactersIn: "-–—:."))

            guard name.count >= 2 else { continue }

            items.append(
                ReceiptLineItem(
                    name: name.prefix(48).description,
                    price: price,
                    suggestedCategoryID: suggestCategory(for: name)
                )
            )
        }

        // Deduplicate near-identical consecutive lines
        var unique: [ReceiptLineItem] = []
        for item in items {
            if let last = unique.last, last.name == item.name, abs(last.price - item.price) < 0.01 {
                continue
            }
            unique.append(item)
        }
        return unique
    }

    private func extractPrice(from line: String) -> Double? {
        // Matches 12.34, $12.34, 12,34, 1,234.56
        let patterns = [
            #"[$€£]?\s*(\d{1,3}(?:,\d{3})*\.\d{2})"#,
            #"[$€£]?\s*(\d+\.\d{2})"#,
            #"(\d+,\d{2})\s*[$€£]?"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            let matches = regex.matches(in: line, range: range)
            guard let match = matches.last, let swiftRange = Range(match.range(at: 1), in: line) else { continue }
            var raw = String(line[swiftRange])
            // European comma decimals
            if raw.contains(",") && !raw.contains(".") {
                raw = raw.replacingOccurrences(of: ",", with: ".")
            } else {
                raw = raw.replacingOccurrences(of: ",", with: "")
            }
            if let value = Double(raw) {
                return value
            }
        }
        return nil
    }

    private func stripPrice(from line: String) -> String {
        var result = line
        let patterns = [
            #"[$€£]?\s*\d{1,3}(?:,\d{3})*\.\d{2}"#,
            #"[$€£]?\s*\d+\.\d{2}"#,
            #"\d+,\d{2}\s*[$€£]?"#
        ]
        for pattern in patterns {
            result = result.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        return result
    }

    private func suggestCategory(for name: String) -> String {
        let lower = name.lowercased()

        // Keyword scoring: better than first-match.
        let keywordsByCategory: [Category: [String: Int]] = [
            .food: [
                "milk": 5, "bread": 5, "egg": 5, "cheese": 5, "yogurt": 4, "butter": 4,
                "apple": 3, "banana": 3, "chicken": 3, "beef": 3, "rice": 3, "pasta": 3,
                "fruit": 2, "veg": 2, "salad": 2, "grocery": 4, "water": 2, "juice": 2,
                "coffee": 3, "tea": 3
            ],
            .eatingOut: [
                "burger": 5, "pizza": 5, "sushi": 5, "latte": 4, "espresso": 4,
                "restaurant": 4, "meal": 3, "combo": 3, "fries": 2, "sandwich": 3,
                "taco": 4, "ramen": 4, "burrito": 4
            ],
            .transportation: [
                "uber": 7, "lyft": 7, "taxi": 7, "toll": 5,
                "fuel": 4, "gas": 4, "parking": 4, "metro": 3, "transit": 3,
                "bus": 3, "train": 3
            ],
            .shopping: [
                "amazon": 5, "walmart": 4, "ikea": 4, "target": 4,
                "shirt": 3, "pants": 3, "shoe": 3, "bag": 3, "store": 3
            ],
            .utilities: [
                "electric": 6, "electricity": 6, "internet": 6, "wifi": 6,
                "phone": 5, "phone bill": 5, "utility": 4, "water bill": 6, "gas bill": 6
            ],
            .rent: [
                "rent": 10, "landlord": 3
            ],
            .healthcare: [
                "pharmacy": 8, "pharm": 7, "prescription": 9,
                "doctor": 5, "dentist": 6, "hospital": 5
            ],
            .subscriptions: [
                "subscription": 8, "netflix": 7, "spotify": 7, "icloud": 5,
                "prime": 4, "cloud": 4
            ],
            .education: [
                "school": 6, "course": 5, "tuition": 8, "university": 6
            ],
            .entertainment: [
                "movie": 6, "cinema": 6, "concert": 7,
                "ticket": 4, "streaming": 4
            ]
        ]

        var bestCategory: Category = .others
        var bestScore = 0

        for (category, table) in keywordsByCategory {
            var score = 0
            for (keyword, keywordScore) in table where lower.contains(keyword) {
                score += keywordScore
            }
            if score > bestScore {
                bestScore = score
                bestCategory = category
            }
        }

        return bestScore > 0 ? bestCategory.categoryID : Category.others.categoryID
    }
}
