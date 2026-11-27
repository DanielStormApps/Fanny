//
//  FloatingWindowLayout.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/23/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// What the floating window shows: its cards in order, and each card's stats in order.
struct FloatingWindowLayout: Codable, Equatable {
    
    enum Orientation: String, Codable, CaseIterable {
        case horizontal
        case vertical
    }
    
    /// A card's reading source. Fan cards follow the SMC fan index, starting at 0.
    enum CardKind: Codable, Hashable {
        case cpu
        case gpu
        case fan(id: Int)
        
        /// A stable id for analytics and drag and drop, such as `cpu` or `fan0`.
        var id: String {
            let id: String
            
            switch self {
            case .cpu:
                id = "cpu"
            case .gpu:
                id = "gpu"
            case .fan(let fanID):
                id = "fan\(fanID)"
            }
            
            return id
        }
        
        /// Every stat the card can show, in its default order.
        var availableStats: [Stat] {
            let stats: [Stat]
            
            switch self {
            case .cpu:
                stats = [Stat.cpuTemperature,
                         Stat.cpuAverage,
                         Stat.cpuHottest,
                         Stat.cpuDie,]
            case .gpu:
                stats = [Stat.gpuTemperature,
                         Stat.gpuAverage,
                         Stat.gpuHottest,]
            case .fan:
                stats = [Stat.fanSpeed,
                         Stat.fanSpeedBar,
                         Stat.fanTarget,
                         Stat.fanMinimum,
                         Stat.fanMaximum,]
            }
            
            return stats
        }
        
        /// The stat a new card shows.
        var defaultStat: Stat {
            return availableStats[0]
        }
    }
    
    /// One value a card can show. The CPU and GPU Temperature stats follow the mode chosen in the Sensors pane.
    enum Stat: String, Codable, CaseIterable {
        case cpuTemperature
        case cpuAverage
        case cpuHottest
        case cpuDie
        case gpuTemperature
        case gpuAverage
        case gpuHottest
        case fanSpeed
        case fanSpeedBar
        case fanTarget
        case fanMinimum
        case fanMaximum
        
        /// The CPU mode this stat reads, with Temperature following the Sensors pane. `nil` for any other stat.
        func cpuSensorMode(selectedMode: FannySettings.CPUSensorMode) -> FannySettings.CPUSensorMode? {
            let mode: FannySettings.CPUSensorMode?
            
            switch self {
            case .cpuTemperature: mode = selectedMode
            case .cpuDie: mode = FannySettings.CPUSensorMode.die
            case .cpuHottest: mode = FannySettings.CPUSensorMode.hottest
            case .cpuAverage: mode = FannySettings.CPUSensorMode.average
            default: mode = nil
            }
            
            return mode
        }
        
        /// The GPU mode this stat reads, with Temperature following the Sensors pane. `nil` for any other stat.
        func gpuSensorMode(selectedMode: FannySettings.GPUSensorMode) -> FannySettings.GPUSensorMode? {
            let mode: FannySettings.GPUSensorMode?
            
            switch self {
            case .gpuTemperature: mode = selectedMode
            case .gpuHottest: mode = FannySettings.GPUSensorMode.hottest
            case .gpuAverage: mode = FannySettings.GPUSensorMode.average
            default: mode = nil
            }
            
            return mode
        }
        
        /// Short, so every card fits in Firebase's 100 character parameter limit.
        var analyticsValue: String {
            let value: String
            
            switch self {
            case .cpuTemperature, .gpuTemperature: value = "temp"
            case .cpuDie: value = "die"
            case .cpuHottest, .gpuHottest: value = "hot"
            case .cpuAverage, .gpuAverage: value = "avg"
            case .fanSpeed: value = "speed"
            case .fanSpeedBar: value = "bar"
            case .fanTarget: value = "target"
            case .fanMinimum: value = "min"
            case .fanMaximum: value = "max"
            }
            
            return value
        }
    }
    
    struct StatItem: Codable, Equatable {
        var stat: Stat
        var isVisible: Bool
    }
    
    struct Card: Codable, Equatable {
        var kind: CardKind
        var isVisible: Bool
        var stats: [StatItem]
        
        var visibleStats: [Stat] {
            return stats.filter({ $0.isVisible }).map({ $0.stat })
        }
        
        /// A shown card with only its default stat shown.
        init(kind: CardKind) {
            self.kind = kind
            isVisible = true
            stats = kind.availableStats.map({ StatItem(stat: $0, isVisible: $0 == kind.defaultStat) })
        }
        
        init(kind: CardKind, isVisible: Bool, stats: [StatItem]) {
            self.kind = kind
            self.isVisible = isVisible
            self.stats = stats
        }
    }
    
    var orientation: Orientation
    var cards: [Card]
    
    private static let defaultOrientation: Orientation = Orientation.vertical
    
    // MARK: - Init
    /// The CPU and GPU cards, each showing its temperature. Fan cards are added once the fans are known.
    init() {
        orientation = FloatingWindowLayout.defaultOrientation
        cards = [Card(kind: CardKind.cpu),
                 Card(kind: CardKind.gpu),]
    }
    
    init(orientation: Orientation, cards: [Card]) {
        self.orientation = orientation
        self.cards = cards
    }
    
    // MARK: - Codable
    private enum CodingKeys: String, CodingKey {
        case orientation
        case cards
    }
    
    /// A saved layout always comes back complete, so a stat or card added in a later version appears hidden instead of failing to decode.
    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        orientation = (try? container.decodeIfPresent(Orientation.self, forKey: .orientation)) ?? FloatingWindowLayout.defaultOrientation
        cards = (try? container.decodeIfPresent([Card].self, forKey: .cards)) ?? FloatingWindowLayout().cards
        self = normalized(fanIDs: [])
    }
    
    // MARK: - Normalize
    /// Keeps one CPU and one GPU card, adds a shown card for each fan that has none, and gives every card each of its stats once.
    /// - Note: A new fan card joins the other fans, or leads the window when there are none yet, so fans come first by default.
    /// - Note: A card for a fan this Mac does not report is kept, so moving settings between Macs never loses it, but `cards(fanIDs:)` leaves it out.
    func normalized(fanIDs: [Int]) -> FloatingWindowLayout {
        var seenKinds: Set<CardKind> = []
        var normalizedCards: [Card] = []
        
        for card in cards where seenKinds.contains(card.kind) == false {
            seenKinds.insert(card.kind)
            normalizedCards.append(FloatingWindowLayout.normalizedCard(card))
        }
        
        for fanID in fanIDs where seenKinds.contains(CardKind.fan(id: fanID)) == false {
            let kind: CardKind = CardKind.fan(id: fanID)
            seenKinds.insert(kind)
            let lastFanIndex: Int? = normalizedCards.lastIndex(where: { card in
                guard case CardKind.fan = card.kind else { return false }
                return true
            })
            normalizedCards.insert(Card(kind: kind), at: lastFanIndex.map({ $0 + 1 }) ?? 0)
        }
        
        for kind in [CardKind.cpu, CardKind.gpu] where seenKinds.contains(kind) == false {
            seenKinds.insert(kind)
            normalizedCards.append(Card(kind: kind))
        }
        
        return FloatingWindowLayout(orientation: orientation, cards: normalizedCards)
    }
    
    /// Drops stats the card cannot show and duplicates, then adds missing stats hidden, in their default order.
    private static func normalizedCard(_ card: Card) -> Card {
        let availableStats: [Stat] = card.kind.availableStats
        var seenStats: Set<Stat> = []
        var stats: [StatItem] = []
        
        for item in card.stats where availableStats.contains(item.stat) && seenStats.contains(item.stat) == false {
            seenStats.insert(item.stat)
            stats.append(item)
        }
        
        for stat in availableStats where seenStats.contains(stat) == false {
            stats.append(StatItem(stat: stat, isVisible: false))
        }
        
        return Card(kind: card.kind, isVisible: card.isVisible, stats: stats)
    }
    
    // MARK: - Cards
    /// The cards this Mac can fill, shown or not, in the saved order.
    func cards(fanIDs: [Int]) -> [Card] {
        return normalized(fanIDs: fanIDs).cards.filter({ card in
            guard case CardKind.fan(let fanID) = card.kind else { return true }
            return fanIDs.contains(fanID)
        })
    }
    
    /// The shown cards with at least one shown stat, which is what the window draws.
    func visibleCards(fanIDs: [Int]) -> [Card] {
        return cards(fanIDs: fanIDs).filter({ $0.isVisible && $0.visibleStats.isEmpty == false })
    }
    
    /// Every stat the window shows on any card, used to decide which sensors to read.
    func visibleStats(fanIDs: [Int]) -> Set<Stat> {
        return Set(visibleCards(fanIDs: fanIDs).flatMap({ $0.visibleStats }))
    }
    
    // MARK: - Editing
    mutating func setCardVisible(_ isVisible: Bool, kind: CardKind) {
        guard let index: Int = cards.firstIndex(where: { $0.kind == kind }) else { return }
        cards[index].isVisible = isVisible
    }
    
    mutating func setStatVisible(_ isVisible: Bool, stat: Stat, kind: CardKind) {
        guard
            let cardIndex: Int = cards.firstIndex(where: { $0.kind == kind }),
            let statIndex: Int = cards[cardIndex].stats.firstIndex(where: { $0.stat == stat })
        else { return }
        
        cards[cardIndex].stats[statIndex].isVisible = isVisible
    }
    
    /// Moves a card to sit before the card at `destinationKind`, or to the end when that is `nil`.
    mutating func moveCard(_ kind: CardKind, before destinationKind: CardKind?) {
        guard
            kind != destinationKind,
            let sourceIndex: Int = cards.firstIndex(where: { $0.kind == kind })
        else { return }
        
        let card: Card = cards.remove(at: sourceIndex)
        let destinationIndex: Int = destinationKind.flatMap({ destination in cards.firstIndex(where: { $0.kind == destination }) }) ?? cards.count
        cards.insert(card, at: destinationIndex)
    }
    
    /// Moves a stat to sit before `destinationStat` on the same card, or to the end when that is `nil`.
    mutating func moveStat(_ stat: Stat, before destinationStat: Stat?, kind: CardKind) {
        guard
            stat != destinationStat,
            let cardIndex: Int = cards.firstIndex(where: { $0.kind == kind }),
            let sourceIndex: Int = cards[cardIndex].stats.firstIndex(where: { $0.stat == stat })
        else { return }
        
        let item: StatItem = cards[cardIndex].stats.remove(at: sourceIndex)
        let destinationIndex: Int = destinationStat.flatMap({ destination in cards[cardIndex].stats.firstIndex(where: { $0.stat == destination }) }) ?? cards[cardIndex].stats.count
        cards[cardIndex].stats.insert(item, at: destinationIndex)
    }
    
    // MARK: - Analytics
    /// The shown cards and their shown stats in order, such as `cpu:temp|fan0:speed,bar`. Never a value.
    func analyticsValue(fanIDs: [Int]) -> String {
        let cardValues: [String] = visibleCards(fanIDs: fanIDs).map({ card in
            return "\(card.kind.id):\(card.visibleStats.map({ $0.analyticsValue }).joined(separator: ","))"
        })
        
        return cardValues.isEmpty ? "none" : cardValues.joined(separator: "|")
    }
}
