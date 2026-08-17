import SwiftUI
import SwiftData
import Foundation


struct AccountListView: View {

    @Environment(\.modelContext)
    private var modelContext

    @Query(
        sort: \Account.createdAt
    )
    private var accounts:
        [Account]

    @Query(
        sort: \TransactionRecord.date,
        order: .reverse
    )
    private var transactions:
        [TransactionRecord]

    @State
    private var showAddAccount =
        false

    @State
    private var blockedDeleteMessage:
        String?

    var body: some View {

        List {

            if accounts.isEmpty {

                ContentUnavailableView(
                    "暂无账户",
                    systemImage:
                        "wallet.pass",
                    description:
                        Text(
                            "添加微信、支付宝、银行卡或现金账户"
                        )
                )

            } else {

                ForEach(
                    accounts
                ) { account in

                    NavigationLink {

                        AccountDetailView(
                            account:
                                account
                        )

                    } label: {

                        accountRow(
                            account
                        )
                    }
                    .swipeActions(
                        edge: .trailing
                    ) {

                        Button(
                            role: .destructive
                        ) {

                            tryDeleteAccount(
                                account
                            )

                        } label: {

                            Label(
                                "删除",
                                systemImage:
                                    "trash"
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle(
            "账户"
        )
        .toolbar {

            ToolbarItem(
                placement:
                    .topBarTrailing
            ) {

                Button {

                    showAddAccount =
                        true

                } label: {

                    Image(
                        systemName:
                            "plus"
                    )
                }
            }
        }
        .sheet(
            isPresented:
                $showAddAccount
        ) {

            AddAccountView()
        }
        .alert(
            "无法删除账户",
            isPresented:
                Binding(
                    get: {
                        blockedDeleteMessage
                            != nil
                    },
                    set: {
                        if !$0 {
                            blockedDeleteMessage =
                                nil
                        }
                    }
                )
        ) {

            Button("好的") {}

        } message: {

            Text(
                blockedDeleteMessage
                ?? ""
            )
        }
    }


    private func accountRow(
        _ account: Account
    ) -> some View {

        HStack(
            spacing: 14
        ) {

            Image(
                systemName:
                    account.type.icon
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
            .clipShape(
                Circle()
            )

            VStack(
                alignment: .leading,
                spacing: 3
            ) {

                Text(
                    account.name
                )
                .font(.headline)

                Text(
                    account.type
                        .rawValue
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()

            Text(
                account.balance,
                format:
                    .currency(
                        code: "CNY"
                    )
            )
            .fontWeight(
                .semibold
            )
        }
        .padding(
            .vertical,
            5
        )
    }


    private func tryDeleteAccount(
        _ account: Account
    ) {

        let hasTransactions =
            TransactionService
                .hasTransactions(
                    accountID:
                        account.id,
                    transactions:
                        transactions
                )

        if hasTransactions {

            blockedDeleteMessage =
                "“\(account.name)”已经存在账单记录。为了保证历史账目正确，不能直接删除这个账户。"

            return
        }

        modelContext.delete(
            account
        )

        try? modelContext.save()
    }
}



// MARK: - 账户详情

struct AccountDetailView: View {

    let account:
        Account

    @Query(
        sort: \Account.createdAt
    )
    private var accounts:
        [Account]

    @Query(
        sort: \TransactionRecord.date,
        order: .reverse
    )
    private var transactions:
        [TransactionRecord]

    @Query(
        sort: \BankCard.createdAt
    )
    private var cards:
        [BankCard]

    @State
    private var showEditAccount =
        false

    @State
    private var showAdjustment =
        false

    private var relatedTransactions:
        [TransactionRecord] {

        transactions.filter {

            $0.accountID ==
                account.id ||

            $0.targetAccountID ==
                account.id
        }
    }


    var body: some View {

        List {

            Section {

                HStack {

                    Image(
                        systemName:
                            account.type.icon
                    )
                    .font(
                        .system(
                            size: 32
                        )
                    )
                    .frame(
                        width: 56,
                        height: 56
                    )
                    .background(
                        Color(
                            .secondarySystemBackground
                        )
                    )
                    .clipShape(
                        Circle()
                    )

                    VStack(
                        alignment:
                            .leading,
                        spacing: 5
                    ) {

                        Text(
                            account.name
                        )
                        .font(
                            .title3.bold()
                        )

                        Text(
                            account.type
                                .rawValue
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    Spacer()
                }
                .padding(
                    .vertical,
                    6
                )

                LabeledContent(
                    "当前余额"
                ) {

                    Text(
                        account.balance,
                        format:
                            .currency(
                                code: "CNY"
                            )
                    )
                    .fontWeight(
                        .semibold
                    )
                }
            }


            Section("账户管理") {

                Button {

                    showEditAccount =
                        true

                } label: {

                    Label(
                        "编辑账户",
                        systemImage:
                            "pencil"
                    )
                }


                Button {

                    showAdjustment =
                        true

                } label: {

                    Label(
                        "余额校准",
                        systemImage:
                            "arrow.triangle.2.circlepath"
                    )
                }
            }


            Section("账户账单") {

                if relatedTransactions
                    .isEmpty {

                    Text(
                        "暂无账单"
                    )
                    .foregroundStyle(
                        .secondary
                    )

                } else {

                    ForEach(
                        relatedTransactions
                    ) { transaction in

                        NavigationLink {

                            TransactionDetailView(
                                transaction:
                                    transaction
                            )

                        } label: {

                            TransactionRowView(
                                transaction:
                                    transaction,
                                accountName:
                                    accountName(
                                        transaction
                                            .accountID
                                    ),
                                targetAccountName:
                                    transaction
                                        .targetAccountID
                                        .flatMap {
                                            accountName(
                                                $0
                                            )
                                        },
                                cardName:
                                    transaction
                                        .bankCardID
                                        .flatMap {
                                            cardName(
                                                $0
                                            )
                                        }
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle(
            account.name
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .sheet(
            isPresented:
                $showEditAccount
        ) {

            EditAccountView(
                account:
                    account
            )
        }
        .sheet(
            isPresented:
                $showAdjustment
        ) {

            BalanceAdjustmentView(
                account:
                    account
            )
        }
    }


    private func accountName(
        _ id: UUID
    ) -> String {

        accounts.first {

            $0.id == id

        }?.name
        ?? "未知账户"
    }


    private func cardName(
        _ id: UUID
    ) -> String? {

        cards.first {
            $0.id == id
        }
        .map {
            "\($0.bankName) •••• \($0.lastFourDigits)"
        }
    }
}



// MARK: - 添加账户

struct AddAccountView: View {

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.modelContext)
    private var modelContext

    @State
    private var name = ""

    @State
    private var accountType:
        AccountType = .wechat

    @State
    private var balanceText =
        ""

    @FocusState
    private var isBalanceFocused:
        Bool


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
                        selection:
                            $accountType
                    ) {

                        ForEach(
                            AccountType
                                .allCases
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
                            text:
                                $balanceText
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
                        cleanedName
                            .isEmpty
                    )
                }


                ToolbarItemGroup(
                    placement:
                        .keyboard
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


    private var cleanedName:
        String {

        name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }


    private func saveAccount() {

        let cleanedBalance =
            balanceText
                .replacingOccurrences(
                    of: ",",
                    with: "."
                )

        let balance =
            Double(
                cleanedBalance
            )
            ?? 0

        let account =
            Account(
                name:
                    cleanedName,
                type:
                    accountType,
                balance:
                    balance
            )

        modelContext.insert(
            account
        )

        try? modelContext.save()

        dismiss()
    }
}



// MARK: - 编辑账户

struct EditAccountView: View {

    let account:
        Account

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.modelContext)
    private var modelContext

    @State
    private var name:
        String

    @State
    private var type:
        AccountType


    init(
        account: Account
    ) {

        self.account =
            account

        _name =
            State(
                initialValue:
                    account.name
            )

        _type =
            State(
                initialValue:
                    account.type
            )
    }


    var body: some View {

        NavigationStack {

            Form {

                Section(
                    "账户信息"
                ) {

                    TextField(
                        "账户名称",
                        text: $name
                    )

                    Picker(
                        "账户类型",
                        selection:
                            $type
                    ) {

                        ForEach(
                            AccountType
                                .allCases
                        ) { item in

                            Label(
                                item.rawValue,
                                systemImage:
                                    item.icon
                            )
                            .tag(item)
                        }
                    }
                }
            }
            .navigationTitle(
                "编辑账户"
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

                        save()
                    }
                    .disabled(
                        cleanedName
                            .isEmpty
                    )
                }
            }
        }
    }


    private var cleanedName:
        String {

        name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }


    private func save() {

        account.name =
            cleanedName

        account.typeRaw =
            type.rawValue

        try? modelContext.save()

        dismiss()
    }
}



// MARK: - 余额校准

struct BalanceAdjustmentView: View {

    let account:
        Account

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.modelContext)
    private var modelContext

    @Query(
        sort: \Account.createdAt
    )
    private var accounts:
        [Account]

    @State
    private var actualBalanceText:
        String

    @State
    private var note =
        "余额校准"

    @FocusState
    private var isFocused:
        Bool

    @State
    private var showError =
        false


    init(
        account: Account
    ) {

        self.account =
            account

        _actualBalanceText =
            State(
                initialValue:
                    String(
                        format:
                            "%.2f",
                        account.balance
                    )
            )
    }


    private var actualBalance:
        Double? {

        Double(
            actualBalanceText
                .replacingOccurrences(
                    of: ",",
                    with: "."
                )
        )
    }


    private var difference:
        Double {

        guard let actualBalance
        else {
            return 0
        }

        return
            actualBalance -
            account.balance
    }


    var body: some View {

        NavigationStack {

            Form {

                Section(
                    "账面余额"
                ) {

                    Text(
                        account.balance,
                        format:
                            .currency(
                                code: "CNY"
                            )
                    )
                    .font(
                        .title2.bold()
                    )
                }


                Section(
                    "实际余额"
                ) {

                    HStack {

                        Text("¥")

                        TextField(
                            "0.00",
                            text:
                                $actualBalanceText
                        )
                        .keyboardType(
                            .decimalPad
                        )
                        .focused(
                            $isFocused
                        )
                    }
                }


                Section(
                    "差额"
                ) {

                    Text(
                        difference,
                        format:
                            .currency(
                                code: "CNY"
                            )
                    )
                    .foregroundStyle(
                        difference == 0
                        ? .secondary
                        : .primary
                    )
                }


                Section(
                    "备注"
                ) {

                    TextField(
                        "备注",
                        text: $note
                    )
                }


                Section {

                    Button {

                        saveAdjustment()

                    } label: {

                        Text(
                            "确认校准"
                        )
                        .frame(
                            maxWidth:
                                .infinity
                        )
                    }
                    .disabled(
                        actualBalance ==
                            nil ||
                        abs(difference) <
                            0.005
                    )
                }
            }
            .scrollDismissesKeyboard(
                .interactively
            )
            .navigationTitle(
                "余额校准"
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


                ToolbarItemGroup(
                    placement:
                        .keyboard
                ) {

                    Spacer()

                    Button("完成") {

                        isFocused =
                            false
                    }
                }
            }
            .alert(
                "校准失败",
                isPresented:
                    $showError
            ) {

                Button("好的") {}

            } message: {

                Text(
                    "未能保存余额调整"
                )
            }
        }
    }


    private func saveAdjustment() {

        isFocused =
            false

        guard actualBalance != nil
        else {
            return
        }

        let oldBalance =
            account.balance

        let newBalance =
            oldBalance +
            difference

        let adjustmentNote =
            note.isEmpty
            ? "余额校准：\(oldBalance) → \(newBalance)"
            : note

        let success =
            TransactionService.create(
                type:
                    .adjustment,
                amount:
                    difference,
                category:
                    "余额调整",
                accountID:
                    account.id,
                note:
                    adjustmentNote,
                date:
                    Date(),
                accounts:
                    accounts,
                context:
                    modelContext
            )

        if success {

            dismiss()

        } else {

            showError =
                true
        }
    }
}