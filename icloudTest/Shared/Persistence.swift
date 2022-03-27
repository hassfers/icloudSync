//
//  Persistence.swift
//  Shared
//
//  Created by Stefan Haßferter on 13.03.22.
//

import CoreData
import CloudKit
import SwiftUI


class PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentCloudKitContainer
    static let appTransactionAuthorName = "ProjectFettFreiApp"
    
    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "icloudTest")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        //        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        
        
        // Enable remote notifications
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("###\(#function): Failed to retrieve a persistent store description.")
        }
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        
        
        // Observe Core Data remote change notifications.
        NotificationCenter.default.addObserver(
            self, selector: #selector(self.mergeICloudChanges),
            name: .NSPersistentStoreRemoteChange, object: nil)
        
        container.viewContext.transactionAuthor = PersistenceController.appTransactionAuthorName
        do {
            try container.viewContext.setQueryGenerationFrom(.current)
        } catch {
            fatalError("###\(#function): Failed to pin viewContext to the current generation:\(error)")
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
    }
    
    @objc func mergeICloudChanges(){
        print("⚡️🎊 incoming icloud changes")
        
        let backgroundContext = container.backgroundContext()
        backgroundContext.performAndWait {
            
            // Fetch history received from outside the app since the last token
            let historyFetchRequest = NSPersistentHistoryTransaction.fetchRequest!
            historyFetchRequest.predicate = NSPredicate(format: "author != %@", PersistenceController.appTransactionAuthorName)
            let request = NSPersistentHistoryChangeRequest.fetchHistory(after: lastHistoryToken)
            request.fetchRequest = historyFetchRequest
            
            let result = (try? backgroundContext.execute(request)) as? NSPersistentHistoryResult
            guard let transactions = result?.result as? [NSPersistentHistoryTransaction],
                  !transactions.isEmpty
            else { return }
            
            print("⚡️transactions = \(transactions)")
            
            
            self.mergeChanges(from: transactions)
            
            // Update the history token using the last transaction.
            lastHistoryToken = transactions.last!.token
        }
    }
    
    private func mergeChanges(from transactions: [NSPersistentHistoryTransaction]) {
        
        let tagEntityName = Item.entity().name
        var newTagObjectIDs = [NSManagedObjectID]()
        
        for transaction in transactions where transaction.changes != nil {
            for change in transaction.changes!
            where change.changedObjectID.entity.name == tagEntityName
            //            && change.changeType == .insert
            {
                print("⚡️change = \(change)")
                newTagObjectIDs.append(change.changedObjectID)
            }
        }
        
        if !newTagObjectIDs.isEmpty {
            deduplicateAndWait(tagObjectIDs: newTagObjectIDs)
        }
        
        container.viewContext.perform {
            transactions.forEach { [weak self] transaction in
                guard let self = self, let userInfo = transaction.objectIDNotification().userInfo else { return }
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: userInfo, into: [self.container.viewContext])
            }
        }
//        DispatchQueue.main.async {
//            self.container.viewContext.refreshAllObjects()
//            var object = newTagObjectIDs.map{ self.container.viewContext.object(with: $0)}
//        }
    }
    
    
    /**
     Track the last history token processed for a store, and write its value to file.
     
     The historyQueue reads the token when executing operations, and updates it after processing is complete.
     */
    private var lastHistoryToken: NSPersistentHistoryToken? = nil {
        didSet {
            guard let token = lastHistoryToken,
                  let data = try? NSKeyedArchiver.archivedData( withRootObject: token, requiringSecureCoding: true) else { return }
            
            do {
                try data.write(to: tokenFile)
            } catch {
                print("###\(#function): Failed to write token data. Error = \(error)")
            }
        }
    }
    
    /**
     The file URL for persisting the persistent history token.
     */
    private lazy var tokenFile: URL = {
        let url = NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("CoreDataCloudKitDemo", isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("###\(#function): Failed to create persistent container URL. Error = \(error)")
            }
        }
        return url.appendingPathComponent("token.data", isDirectory: false)
    }()
    
    /**
     An operation queue for handling history processing tasks: watching changes, deduplicating tags, and triggering UI updates if needed.
     */
    private lazy var historyQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
}

extension NSPersistentContainer {
    func backgroundContext() -> NSManagedObjectContext {
        let context = newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        context.transactionAuthor = PersistenceController.appTransactionAuthorName
        return context
    }
}

// MARK: - Deduplicate tags

extension PersistenceController {
    /**
     Deduplicate tags with the same name by processing the persistent history, one tag at a time, on the historyQueue.
     
     All peers should eventually reach the same result with no coordination or communication.
     */
    private func deduplicateAndWait(tagObjectIDs: [NSManagedObjectID]) {
        // Make any store changes on a background context
        let taskContext = container.backgroundContext()
        
        // Use performAndWait because each step relies on the sequence. Since historyQueue runs in the background, waiting won’t block the main queue.
        taskContext.performAndWait {
         var objects = tagObjectIDs.map { tagObjectID in
               (tagObjectID, deduplicate(tagObjectID: tagObjectID, performingContext: taskContext))
         }
            
            
            objects.filter{$0.1 != nil}.forEach{ (objectId, object) in
                var new = taskContext.object(with: objectId) as? Item
                new?.version = object?.version
                new?.id = object?.id
                new?.timestamp = object?.timestamp
            }
            // Save the background context to trigger a notification and merge the result into the viewContext.
            try? taskContext.save()
        }
    }
    
    /**
     Deduplicate a single tag.
     */
    private func deduplicate(tagObjectID: NSManagedObjectID, performingContext: NSManagedObjectContext) -> Item? {
        // das was reinkommt?
        guard let tag = performingContext.object(with: tagObjectID) as? Item,
              let tagName = tag.id?.uuidString else { return nil
                  //            fatalError("###\(#function): Failed to retrieve a valid tag with ID: \(tagObjectID)")
              }
        
        // alter eintrag
        //        container.viewContext.object(with: tagObjectID)
        
        // neuer eintrag
        //        performingContext.fetch(fetchRequest)
        
        // Fetch all tags with the same name, sorted by uuid
        let fetchRequest: NSFetchRequest<Item> = Item.fetchRequest()
        //        fetchRequest.sortDescriptors = [NSSortDescriptor(key: Item., ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "id == %@", tagName)
        
        // Return if there are no duplicates.
        guard let newEntry = try? performingContext.fetch(fetchRequest).first else {
            return nil
        }
        
        let oldEntry = container.viewContext.object(with: tagObjectID) as? Item
        
        var array = [newEntry, oldEntry].compactMap { $0}
        
        
        print("⚡️ \(array)")
        //        // Pick the first tag as the winnerarray
  
        if let oldTimeStamp = oldEntry?.timestamp,
           let newTimestamp = newEntry.timestamp,
           (newTimestamp < oldTimeStamp) {
            return oldEntry
        }
        
        return nil
        //        duplicatedTags.removeFirst()
//        array.removeFirst()
        
//        let winningObject = container.viewContext.object(with: winner.objectID)
//        container.viewContext.insert(winningObject)
//        DispatchQueue.main.async {
//            try? performingContext.save()
//        }
        
        //        remove(duplicatedTags: array, winner: winner, performingContext: performingContext)
    }
    
    /**
     Remove duplicate tags from their respective posts, replacing them with the winner.
     */
    private func remove(duplicatedTags: [Item], winner: Item, performingContext: NSManagedObjectContext) {
        duplicatedTags.forEach { tag in
            //            defer {
            performingContext.delete(tag)
            //            }
            //            guard let posts = tag.posts else { return }
            //
            //            for case let post as Post in posts {
            //                if let mutableTags: NSMutableSet = post.tags?.mutableCopy() as? NSMutableSet {
            //                    if mutableTags.contains(tag) {
            //                        mutableTags.remove(tag)
            //                        mutableTags.add(winner)
            //                    }
            //                }
            //            }
        }
    }
}



extension PersistenceController{
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for _ in 0..<10 {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()
        }
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()
}
