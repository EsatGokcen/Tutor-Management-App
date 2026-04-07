import AppKit
import SwiftUI

@MainActor
@main
struct TutorTableApp: App {
    @NSApplicationDelegateAdaptor(TutorTableApplication.self) private var appDelegate
    @StateObject private var appModel = AppModel()

    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        WindowGroup("TutorTable") {
            RootView()
                .environmentObject(appModel)
                .background(
                    WindowAccessor { window in
                        appDelegate.attach(window: window)
                        appDelegate.bind(appModel: appModel)
                    }
                )
        }
        .commands {
            CommandMenu("TutorTable") {
                Button("Show TutorTable") {
                    appDelegate.presentWindow()
                }

                Button("Add Sample Data") {
                    appModel.addSampleData()
                    appDelegate.presentWindow()
                }

                Button("Open Data Folder") {
                    appModel.openDataFolder()
                }

                Divider()

                Button("Quit TutorTable") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }
}
