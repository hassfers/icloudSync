//
//  SubItem+CoreDataProperties.swift
//  icloudTest
//
//  Created by Stefan Haßferter on 30.04.22.
//
//

import Foundation
import CoreData


extension SubItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SubItem> {
        return NSFetchRequest<SubItem>(entityName: "SubItem")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var timestamp: Date?
    @NSManaged public var version: String?
    @NSManaged public var item: Item?

}

extension SubItem : Identifiable {

}
