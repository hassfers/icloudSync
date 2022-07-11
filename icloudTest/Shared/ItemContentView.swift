//
//  ItemContentView.swift
//  icloudTest
//
//  Created by Stefan Haßferter on 10.04.22.
//

import SwiftUI

struct ItemContentView: View {
    @ObservedObject var item: Item   // !! @ObserveObject is the key!!
    @State var version: String = ""
    @State var selection: SubItem? = nil
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
            List(selection: $selection){
                ForEach(Array(item.subItem), id: \.self){ subitem in
                    VStack{
                        Text(subitem.id?.uuidString ?? "no id")
                        Text("\(subitem.timestamp ?? Date(), formatter: itemFormatter)")
                    }
                }
                .onDelete { indecies in
                    //                            viewContext.delete(item.subItem[index])
                    //                            item.subItem.remove(at: index)
//                    let items = indecies.map{ index in
//                        Array(item.subItem)[index]
//                    }.forEach { subitem in
//                        item.subItem.remove(subitem)
//                        viewContext.delete(subitem)
//                        try? viewContext.save()
//                    }


                    if let sel = self.selection {
                        self.item.subItem.filter { subitem in
                            subitem.id == sel.id
                        }.forEach { subitem in
                            item.subItem.remove(subitem)
                            viewContext.delete(subitem)
                            try? viewContext.save()
                        }
                    }
                }
#if os(macOS)
                .onDeleteCommand {
                    if let sel = self.selection {
                        print("delete item: \(sel)")
                        self.item.subItem.filter { subitem in
                            subitem.id == sel.id
                        }.forEach { subitem in
                            item.subItem.remove(subitem)
                            viewContext.delete(subitem)
                        }
                    }
                }
#endif
            }
        }
    }
}

struct ItemContentView_Previews: PreviewProvider {
    static var previews: some View {
        ItemContentView(item: Item())
    }
}
