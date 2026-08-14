import SwiftUI

struct ContentView: View {

    var body: some View {

        TabView {

            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label(
                    "首页",
                    systemImage: "house.fill"
                )
            }


            NavigationStack {
                TransactionListView()
            }
            .tabItem {
                Label(
                    "账单",
                    systemImage:
                        "list.bullet.rectangle"
                )
            }


            NavigationStack {
                AddTransactionView()
            }
            .tabItem {
                Label(
                    "记一笔",
                    systemImage:
                        "plus.circle.fill"
                )
            }


            NavigationStack {
                CardWalletView()
            }
            .tabItem {
                Label(
                    "卡包",
                    systemImage:
                        "creditcard.fill"
                )
            }


            NavigationStack {
                AccountListView()
            }
            .tabItem {
                Label(
                    "账户",
                    systemImage:
                        "wallet.pass.fill"
                )
            }
        }
    }
}