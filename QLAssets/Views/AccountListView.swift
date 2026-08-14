import SwiftUI
import SwiftData

struct AccountListView: View {

    @Environment(\.modelContext)
    private var modelContext

    @Query(
        sort: \Account.createdAt
    )
    private var accounts: [Account]

    @State private var showAddAccount = false

    var body: some View {

        List {

            if accounts.isEmpty {

                ContentUnavailableView(
                    "暂无账户",
                    systemImage: "wallet.pass",
                    description: Text(
                        "添加微信、支付宝、银行卡或现金账户"
                    )
                )

            } else {

                ForEach(accounts) { account in

                    HStack(spacing: 14) {

                        Image(
                            systemName: account.type.icon
                        )
                        .font(.title2)
                        .frame(
                            width: 42,
                            height: 42
                        )
                        .background(
                            Color(
                                .secondarySystemBackground
                            )
                        )
                        .clipShape(Circle())

                        VStack(
                            alignment: .leading,
                            spacing: 3
                        ) {

                            Text(account.name)
                                .font(.headline)

                            Text(
                                account.type.rawValue
                            )
                            .font(.caption)
                            .foregroundStyle(
                                .secondary
                            )
                        }

                        Spacer()

                        Text(
                            account.balance,
                            format: .currency(
                                code: "CNY"
                            )
                        )
                        .fontWeight(.semibold)
                    }
                    .padding(
                        .vertical,
                        5
                    )
                }
                .onDelete(
                    perform: deleteAccounts
                )
            }
        }
        .navigationTitle("账户")
        .toolbar {

            ToolbarItem(
                placement: .topBarTrailing
            ) {

                Button {
                    showAddAccount = true
                } label: {
                    Image(
                        systemName: "plus"
                    )
                }
            }
        }
        .sheet(
            isPresented: $showAddAccount
        ) {

            AddAccountView()
        }
    }

    private func deleteAccounts(
        offsets: IndexSet
    ) {

        for index in offsets {

            modelContext.delete(
                accounts[index]
            )
        }

        try? modelContext.save()
    }
}


// MARK: - 添加账户

struct AddAccountView: View {

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.modelContext)
    private var modelContext

    @State private var name = ""

    @State private var accountType:
        AccountType = .wechat

    @State private var balanceText = ""

    @FocusState
    private var isBalanceFocused: Bool

    var body: some View {

        NavigationStack {

            Form {

                Section("账户信息") {

                    TextField(
                        "例如：微信零钱",
                        text: $name
                    )

                    Picker(
                        "账户类型",
                        selection: $accountType
                    ) {

                        ForEach(
                            AccountType.allCases
                        ) { type in

                            Label(
                                type.rawValue,
                                systemImage:
                                    type.icon
                            )
                            .tag(type)
                        }
                    }
                }

                Section("当前余额") {

                    HStack {

                        Text("¥")
                            .foregroundStyle(
                                .secondary
                            )

                        TextField(
                            "0.00",
                            text: $balanceText
                        )
                        .keyboardType(
                            .decimalPad
                        )
                        .focused(
                            $isBalanceFocused
                        )
                    }
                }
            }
            .scrollDismissesKeyboard(
                .interactively
            )
            .navigationTitle(
                "添加账户"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {

                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {

                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {

                    Button("保存") {

                        isBalanceFocused =
                            false

                        saveAccount()
                    }
                    .disabled(
                        name
                            .trimmingCharacters(
                                in: .whitespaces
                            )
                            .isEmpty
                    )
                }

                ToolbarItemGroup(
                    placement: .keyboard
                ) {

                    Spacer()

                    Button("完成") {

                        isBalanceFocused =
                            false
                    }
                    .fontWeight(
                        .semibold
                    )
                }
            }
        }
    }

    private func saveAccount() {

        let cleanedBalance =
            balanceText
                .replacingOccurrences(
                    of: ",",
                    with: "."
                )

        let balance =
            Double(cleanedBalance)
            ?? 0

        let account = Account(
            name:
                name.trimmingCharacters(
                    in: .whitespaces
                ),
            type: accountType,
            balance: balance
        )

        modelContext.insert(
            account
        )

        try? modelContext.save()

        dismiss()
    }
}