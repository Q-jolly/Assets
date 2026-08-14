import SwiftUI
import SwiftData

@main
struct QLAssetsApp: App {

    var body: some Scene {

        WindowGroup {
            ContentView()
        }
        .modelContainer(
            for: [
                Account.self,
                TransactionRecord.self,
                BankCard.self
            ]
        )
    }
}