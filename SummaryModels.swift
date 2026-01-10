import SwiftUI
import Foundation

// MARK: - Time Slice

enum SummaryTimeSlice: String, CaseIterable, Identifiable {
    case day = "Today"
    case week = "This Week"
    case month = "This Month"
    
    var id: String { rawValue }
    
    /// Number of data points for trend charts
    var dataPointCount: Int {
        switch self {
        case .day: return 24      // hourly
        case .week: return 7      // daily
        case .month: return 4     // weekly
        }
    }
    
    /// Rolling average window size
    var rollingAverageWindow: Int {
        switch self {
        case .day: return 3       // 3-hour window
        case .week: return 2      // 2-day window
        case .month: return 2     // 2-week window
        }
    }
    
    /// Date range for filtering entries
    var dateRange: (start: Date, end: Date) {
        let now = Date()
        let calendar = Calendar.current
        switch self {
        case .day:
            let start = calendar.startOfDay(for: now)
            return (start, now)
        case .week:
            let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
            return (start, now)
        case .month:
            let start = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now))!
            return (start, now)
        }
    }
    
    /// Format string for x-axis labels
    func periodLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        switch self {
        case .day:
            formatter.dateFormat = "ha" // "9AM"
            return formatter.string(from: date)
        case .week:
            formatter.dateFormat = "EEE" // "Mon"
            return formatter.string(from: date)
        case .month:
            formatter.dateFormat = "M/d" // "1/5"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Trend Direction

enum TrendDirection: String, CaseIterable {
    case increasing
    case decreasing
    case stable
    
    var symbol: String {
        switch self {
        case .increasing: return "↑"
        case .decreasing: return "↓"
        case .stable: return "→"
        }
    }
    
    var color: Color {
        switch self {
        case .increasing: return .green    // more resistance time = good!
        case .decreasing: return .red      // less resistance time = concerning
        case .stable: return .orange
        }
    }
    
    var accessibilityLabel: String {
        switch self {
        case .increasing: return "increasing"
        case .decreasing: return "decreasing"
        case .stable: return "stable"
        }
    }
}

// MARK: - Trend Data Point

struct TrendDataPoint: Identifiable {
    let id = UUID()
    let periodLabel: String        // "9AM", "Mon", "Jan 5" depending on slice
    let periodStart: Date
    let count: Int                 // number of cravings in this period
    let averageResistanceSeconds: TimeInterval?
}

// MARK: - Craving Configuration

struct CravingConfiguration: Identifiable, Hashable {
    let id = UUID()
    let tags: [UrgeTag]            // combination of tags
    let count: Int                 // occurrences
    let trendDirection: TrendDirection
    let averageResistanceSeconds: TimeInterval  // avg resistance for this combo
    
    var displayEmojis: String {
        tags.map(\.emoji).joined()
    }
    
    var formattedResistance: String {
        let totalSeconds = Int(averageResistanceSeconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CravingConfiguration, rhs: CravingConfiguration) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Craving Trend Data

struct CravingTrendData: Identifiable {
    let id = UUID()
    let tag: UrgeTag
    let timeSlice: SummaryTimeSlice
    let dataPoints: [TrendDataPoint]
    let rollingAverageDirection: TrendDirection
    let topConfigurations: [CravingConfiguration]
    
    /// Calculate trend direction based on average resistance time comparison
    /// Compare first half average vs second half average of resistance times
    static func calculateDirection(from dataPoints: [TrendDataPoint]) -> TrendDirection {
        guard dataPoints.count >= 2 else { return .stable }
        
        let midpoint = dataPoints.count / 2
        let firstHalf = dataPoints.prefix(midpoint)
        let secondHalf = dataPoints.suffix(dataPoints.count - midpoint)
        
        // Get average resistance times, filtering out nil values
        let firstResistances = firstHalf.compactMap(\.averageResistanceSeconds)
        let secondResistances = secondHalf.compactMap(\.averageResistanceSeconds)
        
        guard !firstResistances.isEmpty, !secondResistances.isEmpty else {
            return .stable
        }
        
        let firstAvg = firstResistances.reduce(0, +) / Double(firstResistances.count)
        let secondAvg = secondResistances.reduce(0, +) / Double(secondResistances.count)
        
        guard firstAvg > 0 else {
            return secondAvg > 0 ? .increasing : .stable
        }
        
        let percentChange = (secondAvg - firstAvg) / firstAvg
        let threshold = 0.15 // 15% change threshold for resistance time
        
        if percentChange > threshold {
            return .increasing  // Resistance time increased (good!)
        } else if percentChange < -threshold {
            return .decreasing  // Resistance time decreased (concerning)
        } else {
            return .stable
        }
    }
}

// MARK: - Summary Statistics

struct CravingSummaryStats {
    let timeSlice: SummaryTimeSlice
    let entries: [UrgeEntryModel]
    
    // MARK: - Computed Properties
    
    var isEmpty: Bool {
        entries.isEmpty
    }
    
    var totalCount: Int {
        entries.count
    }
    
    // MARK: - Top Craving Type (Single Tag with Highest Count)
    
    /// Returns the single tag with highest count
    var topCravingType: (tag: UrgeTag, count: Int)? {
        let tagCounts = countBySingleTag()
        guard let topEntry = tagCounts.max(by: { $0.value < $1.value }) else {
            return nil
        }
        return (topEntry.key, topEntry.value)
    }
    
    // MARK: - Top 3 Tag Combinations (Global)
    
    /// Returns top 3 tag combinations across ALL entries with their average resistance times
    var topTagCombinations: [CravingConfiguration] {
        // Group all entries by their full tag set (sorted for consistency)
        var configGroups: [[UrgeTag]: [UrgeEntryModel]] = [:]
        for entry in entries {
            let sortedTags = entry.tags.sorted { $0.emoji < $1.emoji }
            configGroups[sortedTags, default: []].append(entry)
        }
        
        // Build configurations with trend direction and average resistance
        let configurations: [CravingConfiguration] = configGroups.map { tags, configEntries in
            let dataPoints = generateDataPoints(for: configEntries)
            let direction = CravingTrendData.calculateDirection(from: dataPoints)
            
            // Calculate average resistance for ALL entries (all statuses)
            let avgResistance: TimeInterval = configEntries.map(\.durationSeconds).reduce(0, +) / Double(configEntries.count)
            
            return CravingConfiguration(
                tags: tags,
                count: configEntries.count,
                trendDirection: direction,
                averageResistanceSeconds: avgResistance
            )
        }
        
        // Return top 3 by count
        return Array(configurations.sorted { $0.count > $1.count }.prefix(3))
    }
    
    // MARK: - Top Tag Combinations By Average Time
    
    /// Returns top 5 tag combinations sorted by average resistance time (longest first)
    var topTagCombinationsByAverageTime: [CravingConfiguration] {
        // Group all entries by their full tag set (sorted for consistency)
        var configGroups: [[UrgeTag]: [UrgeEntryModel]] = [:]
        for entry in entries {
            let sortedTags = entry.tags.sorted { $0.emoji < $1.emoji }
            configGroups[sortedTags, default: []].append(entry)
        }
        
        // Build configurations with trend direction and average resistance
        let configurations: [CravingConfiguration] = configGroups.map { tags, configEntries in
            let dataPoints = generateDataPoints(for: configEntries)
            let direction = CravingTrendData.calculateDirection(from: dataPoints)
            
            // Calculate average resistance for ALL entries (all statuses)
            let avgResistance: TimeInterval = configEntries.map(\.durationSeconds).reduce(0, +) / Double(configEntries.count)
            
            return CravingConfiguration(
                tags: tags,
                count: configEntries.count,
                trendDirection: direction,
                averageResistanceSeconds: avgResistance
            )
        }
        
        // Sort by average resistance time (longest first), then return top 5
        return Array(configurations.sorted { 
            $0.averageResistanceSeconds > $1.averageResistanceSeconds
        }.prefix(5))
    }
    
    // MARK: - All Tags By Frequency
    
    /// Returns all unique tags sorted by frequency
    var allTagsByFrequency: [UrgeTag] {
        let tagCounts = countBySingleTag()
        return tagCounts.sorted { $0.value > $1.value }.map(\.key)
    }
    
    // MARK: - Trend Data
    
    /// Returns trend data for a specific tag
    func trendData(for tag: UrgeTag) -> CravingTrendData {
        let tagEntries = entries.filter { $0.tags.contains(tag) }
        let dataPoints = generateDataPoints(for: tagEntries)
        let direction = CravingTrendData.calculateDirection(from: dataPoints)
        let configurations = topConfigurations(for: tag)
        
        return CravingTrendData(
            tag: tag,
            timeSlice: timeSlice,
            dataPoints: dataPoints,
            rollingAverageDirection: direction,
            topConfigurations: configurations
        )
    }
    
    /// Returns trend data for all tags (for the carousel)
    var allTrendData: [CravingTrendData] {
        allTagsByFrequency.map { trendData(for: $0) }
    }
    
    // MARK: - Private Helpers
    
    /// Count occurrences of individual tags (for "most frequent" single tag)
    private func countBySingleTag() -> [UrgeTag: Int] {
        var counts: [UrgeTag: Int] = [:]
        for entry in entries {
            for tag in entry.tags {
                counts[tag, default: 0] += 1
            }
        }
        return counts
    }
    
    func generateDataPoints(for tagEntries: [UrgeEntryModel]) -> [TrendDataPoint] {
        let calendar = Calendar.current
        let range = timeSlice.dateRange
        var dataPoints: [TrendDataPoint] = []
        
        // Filter out "Beat it!" entries - we only want to track resistance time for entries where they gave in
        let resistanceEntries = tagEntries.filter { $0.status != .beatIt }
        
        switch timeSlice {
        case .day:
            // Generate hourly data points
            var currentHour = calendar.startOfDay(for: range.start)
            for _ in 0..<24 {
                let nextHour = calendar.date(byAdding: .hour, value: 1, to: currentHour)!
                let periodEntries = resistanceEntries.filter {
                    $0.createdAt >= currentHour && $0.createdAt < nextHour
                }
                // Calculate average resistance for entries where they gave in (excluding beatIt)
                let avgResistance: TimeInterval? = periodEntries.isEmpty ? nil :
                    periodEntries.map(\.durationSeconds).reduce(0, +) / Double(periodEntries.count)
                
                dataPoints.append(TrendDataPoint(
                    periodLabel: timeSlice.periodLabel(for: currentHour),
                    periodStart: currentHour,
                    count: periodEntries.count,
                    averageResistanceSeconds: avgResistance
                ))
                currentHour = nextHour
            }
            
        case .week, .month:
            if timeSlice == .week {
                // Generate daily data points for week view
                var currentDay = calendar.startOfDay(for: range.start)
                for _ in 0..<7 {
                    let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay)!
                    let periodEntries = resistanceEntries.filter {
                        $0.createdAt >= currentDay && $0.createdAt < nextDay
                    }
                    // Calculate average resistance for entries where they gave in (excluding beatIt)
                    let avgResistance: TimeInterval? = periodEntries.isEmpty ? nil :
                        periodEntries.map(\.durationSeconds).reduce(0, +) / Double(periodEntries.count)
                    
                    dataPoints.append(TrendDataPoint(
                        periodLabel: timeSlice.periodLabel(for: currentDay),
                        periodStart: currentDay,
                        count: periodEntries.count,
                        averageResistanceSeconds: avgResistance
                    ))
                    currentDay = nextDay
                }
            } else {
                // Generate weekly data points for month view
                var currentWeek = calendar.startOfDay(for: range.start)
                let weekCount = 4 // Show 4 weeks for the month view
                
                for weekIndex in 0..<weekCount {
                    let nextWeek = calendar.date(byAdding: .day, value: 7, to: currentWeek)!
                    let periodEntries = resistanceEntries.filter {
                        $0.createdAt >= currentWeek && $0.createdAt < nextWeek
                    }
                    // Calculate average resistance for entries where they gave in (excluding beatIt)
                    let avgResistance: TimeInterval? = periodEntries.isEmpty ? nil :
                        periodEntries.map(\.durationSeconds).reduce(0, +) / Double(periodEntries.count)
                    
                    // Label as "Week 1", "Week 2", etc.
                    let weekLabel = "W\(weekIndex + 1)"
                    
                    dataPoints.append(TrendDataPoint(
                        periodLabel: weekLabel,
                        periodStart: currentWeek,
                        count: periodEntries.count,
                        averageResistanceSeconds: avgResistance
                    ))
                    currentWeek = nextWeek
                }
            }
        }
        
        return dataPoints
    }
    
    /// Find top 3 tag combinations for a given primary tag
    func topConfigurations(for primaryTag: UrgeTag, limit: Int = 3) -> [CravingConfiguration] {
        // Filter entries containing the primary tag
        let tagEntries = entries.filter { $0.tags.contains(primaryTag) }
        
        // Group by full tag set (sorted for consistency)
        var configCounts: [[UrgeTag]: [UrgeEntryModel]] = [:]
        for entry in tagEntries {
            let sortedTags = entry.tags.sorted { $0.emoji < $1.emoji }
            configCounts[sortedTags, default: []].append(entry)
        }
        
        // Build configurations with trend direction and average resistance
        let configurations: [CravingConfiguration] = configCounts.map { tags, configEntries in
            let dataPoints = generateDataPoints(for: configEntries)
            let direction = CravingTrendData.calculateDirection(from: dataPoints)
            
            // Calculate average resistance for ALL entries (all statuses)
            let avgResistance: TimeInterval = configEntries.map(\.durationSeconds).reduce(0, +) / Double(configEntries.count)
            
            return CravingConfiguration(
                tags: tags,
                count: configEntries.count,
                trendDirection: direction,
                averageResistanceSeconds: avgResistance
            )
        }
        
        // Return top N by count
        return Array(configurations.sorted { $0.count > $1.count }.prefix(limit))
    }
}


