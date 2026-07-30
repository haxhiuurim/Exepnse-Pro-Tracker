//
//  TripSummaryWidget.swift
//  iExpenseWidgetExtension
//
//  Configurable trip widget: spend, balances, quick add expense.
//

import WidgetKit
import SwiftUI
import AppIntents

private struct WidgetTripSnapshot: Codable, Hashable, Identifiable {
    let id: Int
    var name: String
    var currency: String
    var mySpent: Double
    var totalSpent: Double
    var netBalance: Double
}

private func loadTripSnapshots() -> [WidgetTripSnapshot] {
    guard let data = UserDefaults(suiteName: appGroupID)?.data(forKey: "tripWidgetSnapshots"),
          let decoded = try? JSONDecoder().decode([WidgetTripSnapshot].self, from: data) else {
        return []
    }
    return decoded
}

struct TripEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Trip")
    static var defaultQuery = TripEntityQuery()

    var id: Int
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct TripEntityQuery: EntityQuery {
    func entities(for identifiers: [Int]) async throws -> [TripEntity] {
        let snaps = loadTripSnapshots()
        return identifiers.compactMap { id in
            snaps.first(where: { $0.id == id }).map { TripEntity(id: $0.id, name: $0.name) }
        }
    }

    func suggestedEntities() async throws -> [TripEntity] {
        loadTripSnapshots().map { TripEntity(id: $0.id, name: $0.name) }
    }

    func defaultResult() async -> TripEntity? {
        try? await suggestedEntities().first
    }
}

enum TripWidgetMetric: String, AppEnum {
    case mySpent
    case totalSpent
    case owedToYou
    case youOwe

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Metric")
    static var caseDisplayRepresentations: [TripWidgetMetric: DisplayRepresentation] = [
        .mySpent: "Amount I spent",
        .totalSpent: "Total trip spend",
        .owedToYou: "Owed to me",
        .youOwe: "I owe"
    ]
}

struct TripWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Trip"
    static var description = IntentDescription("Show a shared trip summary.")

    @Parameter(title: "Trip")
    var trip: TripEntity?

    @Parameter(title: "Show", default: .totalSpent)
    var metric: TripWidgetMetric
}

struct TripWidgetEntry: TimelineEntry {
    let date: Date
    let tripID: Int?
    let name: String
    let currency: String
    let metric: TripWidgetMetric
    let value: Double
    let mySpent: Double
    let totalSpent: Double
    let owedToYou: Double
    let youOwe: Double
}

struct TripWidgetProvider: AppIntentTimelineProvider {
    typealias Intent = TripWidgetConfigurationIntent

    func placeholder(in context: Context) -> TripWidgetEntry {
        TripWidgetEntry(
            date: .now,
            tripID: 1,
            name: "Weekend",
            currency: "USD",
            metric: .totalSpent,
            value: 240,
            mySpent: 80,
            totalSpent: 240,
            owedToYou: 20,
            youOwe: 0
        )
    }

    func snapshot(for configuration: TripWidgetConfigurationIntent, in context: Context) async -> TripWidgetEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: TripWidgetConfigurationIntent, in context: Context) async -> Timeline<TripWidgetEntry> {
        Timeline(entries: [entry(for: configuration)], policy: .after(Date().addingTimeInterval(900)))
    }

    private func entry(for configuration: TripWidgetConfigurationIntent) -> TripWidgetEntry {
        let snaps = loadTripSnapshots()
        let snap = configuration.trip.flatMap { trip in snaps.first(where: { $0.id == trip.id }) }
            ?? snaps.first
        let metric = configuration.metric
        guard let snap else {
            return TripWidgetEntry(
                date: .now,
                tripID: nil,
                name: "No trip yet",
                currency: getAppCurrency(),
                metric: metric,
                value: 0,
                mySpent: 0,
                totalSpent: 0,
                owedToYou: 0,
                youOwe: 0
            )
        }
        let owed = max(0, snap.netBalance)
        let owe = max(0, -snap.netBalance)
        let value: Double
        switch metric {
        case .mySpent: value = snap.mySpent
        case .totalSpent: value = snap.totalSpent
        case .owedToYou: value = owed
        case .youOwe: value = owe
        }
        return TripWidgetEntry(
            date: .now,
            tripID: snap.id,
            name: snap.name,
            currency: snap.currency,
            metric: metric,
            value: value,
            mySpent: snap.mySpent,
            totalSpent: snap.totalSpent,
            owedToYou: owed,
            youOwe: owe
        )
    }
}

struct TripSummaryWidgetView: View {
    var entry: TripWidgetEntry
    @Environment(\.widgetFamily) private var family

    private var metricLabel: String {
        switch entry.metric {
        case .mySpent: return "I spent"
        case .totalSpent: return "Trip total"
        case .owedToYou: return "Owed to me"
        case .youOwe: return "I owe"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.name)
                    .font(.system(size: family == .systemSmall ? 13 : 15, weight: .heavy))
                    .foregroundStyle(Color(red: 0.055, green: 0.110, blue: 0.102))
                    .lineLimit(1)
                Spacer()
                if let tripID = entry.tripID {
                    Button(intent: OpenTripQuickAddIntent(tripID: tripID)) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color(red: 0.059, green: 0.624, blue: 0.455))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 0)

            Text(entry.value, format: .currency(code: entry.currency))
                .font(.system(size: family == .systemSmall ? 22 : 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.055, green: 0.110, blue: 0.102))
                .minimumScaleFactor(0.55)
                .lineLimit(1)

            Text(metricLabel.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(red: 0.431, green: 0.506, blue: 0.478))

            if family != .systemSmall {
                HStack(spacing: 8) {
                    miniStat("Spent", entry.mySpent)
                    miniStat("Total", entry.totalSpent)
                    miniStat(entry.owedToYou >= entry.youOwe ? "Owed" : "Owe",
                             entry.owedToYou >= entry.youOwe ? entry.owedToYou : entry.youOwe)
                }
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.933, green: 0.953, blue: 0.945),
                    Color(red: 0.894, green: 0.929, blue: 0.914)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func miniStat(_ title: String, _ amount: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color(red: 0.431, green: 0.506, blue: 0.478))
            Text(amount, format: .currency(code: entry.currency))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.055, green: 0.110, blue: 0.102))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            Color(red: 0.886, green: 0.922, blue: 0.906),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }
}

struct OpenTripQuickAddIntent: AppIntent {
    static var title: LocalizedStringResource = "Add trip expense"
    static var openAppWhenRun = true

    @Parameter(title: "Trip ID")
    var tripID: Int

    init() { tripID = 0 }
    init(tripID: Int) { self.tripID = tripID }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: appGroupID)
        defaults?.set(tripID, forKey: "pendingTripQuickAddID")
        defaults?.set(true, forKey: "pendingTripShowAdd")
        defaults?.synchronize()
        return .result()
    }
}

struct TripSummaryWidget: Widget {
    let kind = "TripSummaryWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: TripWidgetConfigurationIntent.self, provider: TripWidgetProvider()) { entry in
            TripSummaryWidgetView(entry: entry)
        }
        .supportedFamilies([.systemSmall, .systemMedium])
        .configurationDisplayName("Trip")
        .description("Track a shared trip’s spend and balances, then add an expense.")
        .contentMarginsDisabled()
    }
}
