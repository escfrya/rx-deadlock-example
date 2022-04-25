//
//  ContentView.swift
//  Shared
//
//  Created by Igor Skovorodkin on 03.09.2021.
//

import SwiftUI
import ReactiveKit

struct ContentView: View {
    var body: some View {
        VStack {
            VStack {
                Text("ReactiveKit")
                Button("Reproduce deadlock 1") {
                    ReactiveKitTest.shared.reproduceDeadlock1()
                }
                Button("Reproduce deadlock 2") {
                    ReactiveKitTest.shared.reproduceDeadlock2()
                }
            }
            VStack {
                Text("Combine")
                Button("Reproduce deadlock 1") {
                    CombineTest.shared.reproduceDeadlock1()
                }
                Button("Reproduce deadlock 2") {
                    CombineTest.shared.reproduceDeadlock2()
                }
            }
            VStack {
                Text("RxSwift")
                Button("Reproduce deadlock 1") {
                    RxSwiftTest.shared.reproduceDeadlock1()
                }
                Button("Reproduce deadlock 2") {
                    RxSwiftTest.shared.reproduceDeadlock2()
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
