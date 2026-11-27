//
//  MenuBarLayout.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/24/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// What the menu bar item shows: the Fanny icon first, then the chosen readings in the user's order.
struct MenuBarLayout: Codable, Equatable {
    
    /// One thing the menu bar can show. Fan items follow the SMC fan index, starting at 0.
    enum ItemKind: Codable, Hashable {
        case icon
        case fastestFan
        case fan(id: Int)
        case cpu
        case gpu
        
        /// A stable id for analytics and drag and drop, such as `cpu` or `fan0`.
        var id: String {
            let id: String
            
            switch self {
            case .icon:
                id = "icon"
            case .fastestFan:
                id = "fastestFan"
            case .fan(let fanID):
                id = "fan\(fanID)"
            case .cpu:
                id = "cpu"
            case .gpu:
                id = "gpu"
            }
            
            return id
        }
    }
    
    struct Item: Codable, Equatable {
        var kind: ItemKind
        var isVisible: Bool
    }
    
    var items: [Item]
    
    // MARK: - Init
    /// The icon and the fastest fan shown, the temperatures listed but hidden. Fan items are added once the fans are known.
    init() {
        items = [Item(kind: ItemKind.icon, isVisible: true),
                 Item(kind: ItemKind.fastestFan, isVisible: true),
                 Item(kind: ItemKind.cpu, isVisible: false),
                 Item(kind: ItemKind.gpu, isVisible: false),]
    }
    
    init(items: [Item]) {
        self.items = items
    }
    
    // MARK: - Codable
    private enum CodingKeys: String, CodingKey {
        case items
    }
    
    /// A saved layout always comes back complete, so an item added in a later version appears hidden instead of failing to decode.
    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? container.decodeIfPresent([Item].self, forKey: .items)) ?? MenuBarLayout().items
        self = normalized(fanIDs: [])
    }
    
    // MARK: - Normalize
    /// Keeps each item once with the icon first, adds a hidden item for each fan that has none, and adds any missing item hidden.
    /// - Note: A new fan item joins the other fans, or follows the fastest fan when there are none yet.
    /// - Note: An item for a fan this Mac does not report is kept, so moving settings between Macs never loses it, but `items(fanIDs:)` leaves it out.
    func normalized(fanIDs: [Int]) -> MenuBarLayout {
        var seenKinds: Set<ItemKind> = []
        var normalizedItems: [Item] = []
        
        for item in items where seenKinds.contains(item.kind) == false {
            seenKinds.insert(item.kind)
            normalizedItems.append(item)
        }
        
        if let iconIndex: Int = normalizedItems.firstIndex(where: { $0.kind == ItemKind.icon }) {
            normalizedItems.insert(normalizedItems.remove(at: iconIndex), at: 0)
        }
        else {
            normalizedItems.insert(Item(kind: ItemKind.icon, isVisible: true), at: 0)
        }
        
        for kind in [ItemKind.fastestFan, ItemKind.cpu, ItemKind.gpu] where seenKinds.contains(kind) == false {
            seenKinds.insert(kind)
            normalizedItems.append(Item(kind: kind, isVisible: false))
        }
        
        for fanID in fanIDs where seenKinds.contains(ItemKind.fan(id: fanID)) == false {
            let kind: ItemKind = ItemKind.fan(id: fanID)
            seenKinds.insert(kind)
            let lastFanIndex: Int? = normalizedItems.lastIndex(where: { item in
                guard case ItemKind.fan = item.kind else { return item.kind == ItemKind.fastestFan }
                return true
            })
            normalizedItems.insert(Item(kind: kind, isVisible: false), at: lastFanIndex.map({ $0 + 1 }) ?? normalizedItems.count)
        }
        
        return MenuBarLayout(items: normalizedItems)
    }
    
    // MARK: - Items
    /// The items this Mac can fill, shown or not, in the saved order with the icon first.
    func items(fanIDs: [Int]) -> [Item] {
        return normalized(fanIDs: fanIDs).items.filter({ item in
            guard case ItemKind.fan(let fanID) = item.kind else { return true }
            return fanIDs.contains(fanID)
        })
    }
    
    /// The shown items, in order with the icon first.
    func visibleKinds(fanIDs: [Int]) -> [ItemKind] {
        return items(fanIDs: fanIDs).filter({ $0.isVisible }).map({ $0.kind })
    }
    
    // MARK: - Editing
    mutating func setVisible(_ isVisible: Bool, kind: ItemKind) {
        guard let index: Int = items.firstIndex(where: { $0.kind == kind }) else { return }
        items[index].isVisible = isVisible
    }
    
    /// Moves an item to sit before the item at `destinationKind`, or to the end when that is `nil`. The icon always stays first.
    mutating func moveItem(_ kind: ItemKind, before destinationKind: ItemKind?) {
        guard
            kind != ItemKind.icon,
            kind != destinationKind,
            destinationKind != ItemKind.icon,
            let sourceIndex: Int = items.firstIndex(where: { $0.kind == kind })
        else { return }
        
        let item: Item = items.remove(at: sourceIndex)
        let destinationIndex: Int = destinationKind.flatMap({ destination in items.firstIndex(where: { $0.kind == destination }) }) ?? items.count
        items.insert(item, at: destinationIndex)
    }
    
    // MARK: - Analytics
    /// The shown items in order, such as `icon,fastestFan,cpu`. Never a value.
    func analyticsValue(fanIDs: [Int]) -> String {
        let kinds: [ItemKind] = visibleKinds(fanIDs: fanIDs)
        return kinds.isEmpty ? "none" : kinds.map({ $0.id }).joined(separator: ",")
    }
}
