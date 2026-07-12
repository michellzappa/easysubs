import SwiftUI

@main
struct EasySubsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 430, idealWidth: 470, minHeight: 430, idealHeight: 520)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 470, height: 520)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
