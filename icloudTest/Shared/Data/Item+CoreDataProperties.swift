//
//  Item+CoreDataProperties.swift
//  icloudTest
//
//  Created by Stefan Haßferter on 30.04.22.
//
//

import Foundation
import CoreData


extension Item {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Item> {
        return NSFetchRequest<Item>(entityName: "Item")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var timestamp: Date?
    @NSManaged public var version: String?
    @NSManaged public var subItem: NSSet(SubItem)

}

// MARK: Generated accessors for subItem
extension Item {

    @objc(addSubItemObject:)
    @NSManaged public func addToSubItem(_ value: SubItem)

    @objc(removeSubItemObject:)
    @NSManaged public func removeFromSubItem(_ value: SubItem)

    @objc(addSubItem:)
    @NSManaged public func addToSubItem(_ values: NSSet)

    @objc(removeSubItem:)
    @NSManaged public func removeFromSubItem(_ values: NSSet)

}

extension Item : Identifiable {

}
