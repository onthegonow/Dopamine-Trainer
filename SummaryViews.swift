import SwiftUI
import Charts
#if os(iOS)
import UIKit
#endif

// MARK: - Summary Dashboard Container

struct CravingSummaryDashboard: View {
    @ObservedObject var store: UrgeStore
    @State private var selectedTimeSlice: SummaryTimeSlice = .week

    private let phoneCarouselHeight: CGFloat = 320
    
    private var isPhone: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .phone
        #else
        return false
        #endif
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Time slice picker
            TimeSlicePicker(selection: $selectedTimeSlice)
                .padding(.horizontal)
            
            if stats.isEmpty {
                EmptySummaryView(timeSlice: selectedTimeSlice)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                if isPhone {
                    // iPhone: present cards as a paged carousel to avoid horizontal overflow
                    VStack(spacing: 12) {
                        TabView {
                            TopCravingCard(stats: stats)
                                .padding(.horizontal)
                            
                            TopCombinationsCard(stats: stats)
                                .padding(.horizontal)
                            
                            TrendCarouselCard(stats: stats)
                                .padding(.horizontal)
                        }
                        #if os(iOS)
                        .tabViewStyle(.page)
                        .indexViewStyle(.page(backgroundDisplayMode: .automatic))
                        #endif
                        .frame(height: phoneCarouselHeight)
                    }
                } else {
                    // macOS/iPad/etc: show the full dashboard with fixed card widths
                    HStack {
                        Spacer()
                        
                        HStack(spacing: 16) {
                            TopCravingCard(stats: stats)
                                .frame(width: 180)
                            
                            TopCombinationsCard(stats: stats)
                                .frame(width: 220)
                            
                            TrendCarouselCard(stats: stats)
                                .frame(width: 320)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical)
    }
    
    private var stats: CravingSummaryStats {
        store.summaryStats(for: selectedTimeSlice)
    }
}

// MARK: - Time Slice Picker

struct TimeSlicePicker: View {
    @Binding var selection: SummaryTimeSlice
    
    var body: some View {
        Picker("Time Period", selection: $selection) {
            ForEach(SummaryTimeSlice.allCases) { slice in
                Text(slice.rawValue).tag(slice)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

// MARK: - Empty State

struct EmptySummaryView: View {
    let timeSlice: SummaryTimeSlice
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No cravings recorded")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Start tracking to see your \(timeSlice.rawValue.lowercased()) summary")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Insufficient Data View

struct InsufficientDataView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 28))
                .foregroundColor(.secondary.opacity(0.6))
            
            Text("Insufficient Data")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("Keep tracking")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Top Craving Card (Single Most Frequent Tag)

struct TopCravingCard: View {
    let stats: CravingSummaryStats
    
    var body: some View {
        SummaryCard {
            VStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 16))  // +4 from caption (12 → 16)
                        .foregroundColor(.yellow)
                    Text("Most Frequent")
                        .font(.system(size: 16))  // +4 from caption (12 → 16)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                if let (tag, count) = stats.topCravingType {
                    VStack(spacing: 4) {
                        Text(tag.emoji)
                            .font(.system(size: 48))
                        
                        Text("\(count)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        
                        Text("cravings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(tag.label): \(count) cravings, most frequent")
                } else {
                    InsufficientDataView()
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Average Times Card

struct TopCombinationsCard: View {
    let stats: CravingSummaryStats
    
    var body: some View {
        SummaryCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 16))  // +4 from caption (12 → 16)
                        .foregroundColor(.orange)
                    Text("Average Times")
                        .font(.system(size: 16))  // +4 from caption (12 → 16)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                if stats.topTagCombinationsByAverageTime.isEmpty {
                    Spacer()
                    InsufficientDataView()
                    Spacer()
                } else {
                    VStack(spacing: 10) {
                        ForEach(stats.topTagCombinationsByAverageTime) { config in
                            AverageTimeRow(configuration: config)
                        }
                    }
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Average Time Row

struct AverageTimeRow: View {
    let configuration: CravingConfiguration
    
    var body: some View {
        HStack(spacing: 8) {
            // Emoji combination
            Text(configuration.displayEmojis)
                .font(.system(size: 30))  // +2 from title2 (28 → 30)
            
            VStack(alignment: .leading, spacing: 2) {
                // Average resistance time (primary focus)
                Text(configuration.formattedResistance)
                    .font(.system(size: 21, design: .rounded))  // +2 from headline (19 → 21)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // Count as secondary info
                HStack(spacing: 4) {
                    Text("\(configuration.count) times")
                        .font(.system(size: 14))  // +2 from caption (12 → 14)
                        .foregroundColor(.secondary)
                    
                    Text(configuration.trendDirection.symbol)
                        .font(.system(size: 13))  // +2 from caption2 (11 → 13)
                        .foregroundColor(configuration.trendDirection.color)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }
    
    private var accessibilityDescription: String {
        var desc = configuration.tags.map(\.label).joined(separator: " and ")
        desc += ", average time \(configuration.formattedResistance)"
        desc += ", \(configuration.count) times"
        desc += ", trend \(configuration.trendDirection.accessibilityLabel)"
        return desc
    }
}

// MARK: - Trend Carousel Card

struct TrendCarouselCard: View {
    let stats: CravingSummaryStats
    @State private var currentPage = 0
    
    var body: some View {
        SummaryCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 16))  // +4 from caption (12 → 16)
                        .foregroundColor(.green)
                    Text("Resistance Trends")
                        .font(.system(size: 16))  // +4 from caption (12 → 16)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                if stats.allTrendData.isEmpty {
                    Spacer()
                    InsufficientDataView()
                    Spacer()
                } else {
                    TabView(selection: $currentPage) {
                        ForEach(Array(stats.allTrendData.enumerated()), id: \.element.id) { index, trendData in
                            TrendChartPage(trendData: trendData)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.automatic)
                    .frame(height: 180)
                    
                    // Page indicator
                    HStack(spacing: 6) {
                        Spacer()
                        ForEach(0..<stats.allTrendData.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.primary : Color.secondary.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                        Spacer()
                    }
                }
            }
        }
    }
}

// MARK: - Trend Chart Page

struct TrendChartPage: View {
    let trendData: CravingTrendData
    
    /// Determines the appropriate Y-axis scale unit based on the data range
    private var yAxisConfig: (unit: String, divisor: Double, domain: ClosedRange<Double>) {
        let resistanceValues = trendData.dataPoints.compactMap(\.averageResistanceSeconds)
        
        guard !resistanceValues.isEmpty else {
            return ("min", 60, 0...60)
        }
        
        let minValue = resistanceValues.min() ?? 0
        let maxValue = resistanceValues.max() ?? 0
        let range = maxValue - minValue
        
        // If the range or max value suggests hours are more appropriate
        if maxValue >= 3600 || range >= 1800 {
            // Use hours
            let minHours = floor(minValue / 3600)
            let maxHours = ceil(maxValue / 3600) + 0.5
            return ("hr", 3600, max(0, minHours)...max(1, maxHours))
        } else {
            // Use minutes
            let minMinutes = floor(minValue / 60)
            let maxMinutes = ceil(maxValue / 60) + 5
            return ("min", 60, max(0, minMinutes)...max(10, maxMinutes))
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with emoji, label, and trend indicator
            HStack {
                Text(trendData.tag.emoji)
                    .font(.title3)
                Text(trendData.tag.label.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(trendData.rollingAverageDirection.symbol)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(trendData.rollingAverageDirection.color)
            }
            
            // Line chart with dynamic Y-axis
            let config = yAxisConfig
            Chart(trendData.dataPoints) { point in
                if let resistance = point.averageResistanceSeconds {
                    LineMark(
                        x: .value("Period", point.periodLabel),
                        y: .value("Resistance", resistance / config.divisor)
                    )
                    .foregroundStyle(Color.blue)
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Period", point.periodLabel),
                        y: .value("Resistance", resistance / config.divisor)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                    
                    PointMark(
                        x: .value("Period", point.periodLabel),
                        y: .value("Resistance", resistance / config.divisor)
                    )
                    .foregroundStyle(Color.blue)
                    .symbolSize(20)
                }
            }
            .chartYScale(domain: config.domain)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    if let val = value.as(Double.self) {
                        AxisValueLabel {
                            Text("\(Int(val))\(config.unit)")
                                .font(.caption2)
                        }
                    }
                    AxisGridLine()
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            .frame(height: 80)
            
            // Top configurations for this tag
            if !trendData.topConfigurations.isEmpty {
                HStack(spacing: 12) {
                    Text("Patterns:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    ForEach(trendData.topConfigurations.prefix(3)) { config in
                        ConfigurationBadge(configuration: config)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(trendAccessibilityLabel)
    }
    
    private var trendAccessibilityLabel: String {
        let direction = trendData.rollingAverageDirection.accessibilityLabel
        return "\(trendData.tag.label) resistance time trend is \(direction)"
    }
}

// MARK: - Configuration Badge

struct ConfigurationBadge: View {
    let configuration: CravingConfiguration
    
    var body: some View {
        HStack(spacing: 2) {
            Text(configuration.displayEmojis)
                .font(.caption)
            
            Text("(\(configuration.count))")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(configuration.trendDirection.symbol)
                .font(.caption)
                .foregroundColor(configuration.trendDirection.color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Summary Card Container

struct SummaryCard<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
    }
}

// MARK: - Preview

#Preview {
    CravingSummaryDashboard(store: UrgeStore.shared)
        .frame(width: 800, height: 300)
        .onAppear {
            UrgeStore.shared.loadDummyHistory()
        }
}
