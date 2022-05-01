//
//  ItemContentView.swift
//  icloudTest
//
//  Created by Stefan Haßferter on 10.04.22.
//

import SwiftUI

struct ItemContentView: View {
    @ObservedObject var item: Item   // !! @ObserveObject is the key!!!
    @State var version: String = ""
    @Environment(\.managedObjectContext) private var viewContext
    
    init(item: Item){
        _version = State(initialValue: item.version ?? "")
        self.item = item
    }


    var body: some View {
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
                Button("add subitem"){
                    let subitem = SubItem(context: viewContext)
                    subitem.timestamp = Date()
                    subitem.id = UUID()
                    item.addToSubItem(subitem)
                    try? viewContext.save()
                }
                List(Array(item.subItem), id: \.self){ subitem in
                    VStack{
                        Text(subitem.id?.uuidString ?? "no id")
                        Text("\(subitem.timestamp ?? Date(), formatter: itemFormatter)")
                    }
                }
            }
    }
}

struct ItemContentView_Previews: PreviewProvider {
    static var previews: some View {
        ItemContentView(item: Item())
    }
}
