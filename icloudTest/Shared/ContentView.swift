//
//  ContentView.swift
//  Shared
//
//  Created by Stefan Haßferter on 13.03.22.
//

import SwiftUI
import CoreData

let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()


struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default)
    private var items: FetchedResults<Item>

    var body: some View {
        NavigationView {
            VStack{
                Text("\(items.count) Items")
                List {
                ForEach(items) { item in
                    NavigationLink {
                        
                         ItemContentView(item: item)
                        
                    } label: {
                        ItemRow(item: item)
                    }
                }
                .onDelete(perform: deleteItems)
            }}
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                    
                }
#endif
                
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            Text("Select an item")
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()
            newItem.id = UUID()
            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { items[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct ItemRow: View {
    @ObservedObject var item: Item   // !! @ObserveObject is the key!!!
    @State var version: String = ""
    @Environment(\.managedObjectContext) private var viewContext
    
    init(item: Item){
        _version = State(initialValue: item.version ?? "")
        self.item = item
    }


    var body: some View {
        HStack {
            VStack{
                Text("Item at \(item.timestamp ?? Date(), formatter: itemFormatter)")
                Text(item.id?.uuidString ?? "")
                Text(item.version ?? "no version available")
                TextField("Enter your text", text: $version)
                    .onChange(of: version) { newValue in
                    item.version = newValue
                        item.timestamp = Date()
                    try? viewContext.save()
                }
            }
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
