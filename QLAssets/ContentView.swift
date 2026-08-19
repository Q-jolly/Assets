import SwiftUI


struct ContentView: View {

    private enum AppTab:
        Int,
        Hashable {

        case home
        case transactions
        case add
        case cards
        case accounts
    }


    @State
    private var selectedTab:
        AppTab =
            .home


    var body: some View {

        TabView(
            selection:
                $selectedTab
        ) {

            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label(
                    "首页",
                    systemImage:
                        "house.fill"
                )
            }
            .tag(
                AppTab.home
            )


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
            .tag(
                AppTab.transactions
            )


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
            .tag(
                AppTab.add
            )


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
            .tag(
                AppTab.cards
            )


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
            .tag(
                AppTab.accounts
            )
        }
        .onChange(
            of:
                selectedTab
        ) { _, _ in

            HapticFeedback
                .selection()
        }
    }
}
