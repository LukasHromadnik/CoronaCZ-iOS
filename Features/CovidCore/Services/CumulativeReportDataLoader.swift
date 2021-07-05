//
//  DataLoader.swift
//  Bars
//
//  Created by Lukáš Hromadník on 24.04.2021.
//

import UIKit
import SwiftUI

public final class CumulativeReportDataLoader: ObservableObject {
    @Published public var items: [Int] = []
    @Published public var sizes: [CGFloat] = []
    @Published public var r: [Double] = []
    
    private let dataFetcher: DataFetcher<CumulativeReportItem>
    private let dateProvider: DateProvider
    
    public init(
        dataFetcher: DataFetcher<CumulativeReportItem>,
        dateProvider: DateProvider
    ) {
        self.dataFetcher = dataFetcher
        self.dateProvider = dateProvider
        
        refresh()
    }
    
    public func refresh() {
        dataFetcher.load { [weak self] in
            guard let items = $0 else { return }
            self?.processItems(items)
        }
    }
    
    private func processItems(_ allItems: [CumulativeReportItem]) {
        let prirustky = zip(allItems.dropFirst(), allItems)
            .map { $0.total - $1.total }

        self.r = Array(0..<prirustky.count - 12)
            .map { i in
                let first = prirustky[i ..< i + 7].reduce(0, +)
                let second = prirustky[i + 5 ..< i + 12].reduce(0, +)
                return Double(second) / Double(first)
            }
            .suffix(60)
        
        // Don't run the processing on empty collection
        guard !allItems.isEmpty else { return }
        
        // Check if the current date is monday, if so then go back three weeks
        let weekShift = dateProvider.date().startOfWeek().addingTimeInterval(.days(1)) > Date() ? -3 : -2
        
        // Get date of monday 3 weeks ago
        let firstWeekDate = dateProvider.date().startOfWeek().addingTimeInterval(.weeks(weekShift))

        // Format the date to match the API format
        let formattedDate = Formatters.Date.api.string(from: firstWeekDate)
        
        // Find index of the element for that monday
        guard let index = allItems.firstIndex(where: { $0.date == formattedDate }) else { assertionFailure(); return }
        
        // Use only items within last 3 weeks
        // Index has to be shifted one back
        // because we have to compute the increase by ourselves
        let previousValues = allItems[(index - 1)...]
        let currentValues = allItems[index...]
        let usableItems = zip(currentValues, previousValues).map { $0.total - $1.total }
        
        // Compute maximum values from `usableItems`
        let maxValue = CGFloat(usableItems.max()!)
        
        // Append zeros to match total number of days in 3 weeks
        let missingValues = 21 - usableItems.count
        let items = usableItems + Array(repeating: -1, count: missingValues)
        
        // Reorder array to grouped values for each weekday
        let reorderedItems: [[Int]] = (0..<7)
            .map { weekIndex -> [Int] in
                [items[weekIndex], items[weekIndex + 7], items[weekIndex + 14]]
            }
        
        self.items = reorderedItems
            // Flatten the data
            .flatMap { $0 }
        
        self.sizes = self.items
            // Compute the relative bar height
            .map { (CGFloat($0) / maxValue) * Constants.graphMaxHeight }
    }
}