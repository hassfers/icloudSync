//
//  icloudTestApp.swift
//  Shared
//
//  Created by Stefan Haßferter on 13.03.22.
//

import SwiftUI

@main
struct icloudTestApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
