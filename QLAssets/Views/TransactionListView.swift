import SwiftUI
import SwiftData
import Foundation


struct TransactionListView: View {

    @Environment(\.modelContext)
    private var modelContext

    @Query(
        sort: \TransactionRecord.date,
        order: .reverse
    )
    private var transactions:
        [TransactionRecord]

    @Query(
        sort: \Account.createdAt
    )
    private var accounts:
        [Account]


    var body: some View {

        List {

            if transactions.isEmpty {

                ContentUnavailableView(
                    "暂无账单",
                    systemImage:
                        "list.bullet.rectangle",
                    description:
                        Text(
                            "记录第一笔消费吧"
                        )
                )

            } else {

                ForEach(
                    transactions
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
                                    }
                        )
                    }
                }
                .onDelete(
                    perform:
                        deleteTransactions
                )
            }
        }
        .navigationTitle(
            "账单"
        )
    }


    private func accountName(
        _ id: UUID
    ) -> String {

        accounts.first {

            $0.id == id

        }?.name
        ?? "未知账户"
    }


    private func deleteTransactions(
        offsets: IndexSet
    ) {

        for index in offsets {

            let transaction =
                transactions[index]

            _ =
                TransactionService
                    .delete(
                        transaction,
                        accounts:
                            accounts,
                        context:
                            modelContext
                    )
        }
    }
}



// MARK: - 流水行

struct TransactionRowView: View {

    let transaction:
        TransactionRecord

    let accountName:
        String

    var targetAccountName:
        String? = nil


    var body: some View {

        HStack(
            spacing: 12
        ) {

            ZStack {

                Circle()
                    .fill(
                        Color(
                            .secondarySystemBackground
                        )
                    )
                    .frame(
                        width: 44,
                        height: 44
                    )

                Image(
                    systemName:
                        transaction
                            .type
                            .icon
                )
            }


            VStack(
                alignment:
                    .leading,
                spacing: 4
            ) {

                Text(
                    transaction
                        .category
                )
                .font(
                    .headline
                )


                Text(
                    subtitle
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )


                if !transaction
                    .note
                    .isEmpty {

                    Text(
                        transaction.note
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .lineLimit(1)
                }
            }


            Spacer()


            Text(
                amountText
            )
            .fontWeight(
                .semibold
            )
        }
        .padding(
            .vertical,
            4
        )
    }


    private var subtitle:
        String {

        let accountText:
            String

        if transaction.type ==
            .transfer {

            accountText =
                "\(accountName) → \(targetAccountName ?? "未知账户")"

        } else {

            accountText =
                accountName
        }

        return
            "\(accountText) · \(AppTime.listDateTime(transaction.date))"
    }


    private var amountText:
        String {

        switch transaction.type {

        case .expense:

            return
                "-\(abs(transaction.amount).formatted(.currency(code: "CNY")))"


        case .income:

            return
                "+\(abs(transaction.amount).formatted(.currency(code: "CNY")))"


        case .transfer:

            return
                abs(transaction.amount)
                    .formatted(
                        .currency(
                            code: "CNY"
                        )
                    )


        case .adjustment:

            if transaction.amount >
                0 {

                return
                    "+\(transaction.amount.formatted(.currency(code: "CNY")))"

            } else {

                return
                    transaction.amount
                        .formatted(
                            .currency(
                                code: "CNY"
                            )
                        )
            }
        }
    }
}



// MARK: - 流水详情

struct TransactionDetailView: View {

    let transaction:
        TransactionRecord

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
    private var showEdit =
        false

    @State
    private var showDeleteConfirmation =
        false


    var body: some View {

        List {

            Section {

                LabeledContent(
                    "类型",
                    value:
                        transaction
                            .type
                            .rawValue
                )


                LabeledContent(
                    "金额"
                ) {

                    Text(
                        displayAmount
                    )
                    .fontWeight(
                        .semibold
                    )
                }


                LabeledContent(
                    "分类",
                    value:
                        transaction
                            .category
                )
            }


            Section(
                "账户"
            ) {

                LabeledContent(
                    transaction.type ==
                        .transfer
                    ? "转出账户"
                    : "账户",
                    value:
                        accountName(
                            transaction
                                .accountID
                        )
                )


                if
                    transaction.type ==
                        .transfer,
                    let targetID =
                        transaction
                            .targetAccountID {

                    LabeledContent(
                        "转入账户",
                        value:
                            accountName(
                                targetID
                            )
                    )
                }
            }


            Section(
                "时间"
            ) {

                LabeledContent(
                    "日期"
                ) {

                    Text(
                        AppTime.detailDateTime(
                            transaction.date
                        )
                    )
                }
            }


            if !transaction
                .note
                .isEmpty {

                Section(
                    "备注"
                ) {

                    Text(
                        transaction.note
                    )
                }
            }


            Section {

                if transaction.type !=
                    .adjustment {

                    Button {

                        showEdit =
                            true

                    } label: {

                        Label(
                            "编辑账单",
                            systemImage:
                                "pencil"
                        )
                    }
                }


                Button(
                    role:
                        .destructive
                ) {

                    showDeleteConfirmation =
                        true

                } label: {

                    Label(
                        "删除账单",
                        systemImage:
                            "trash"
                    )
                }
            }
        }
        .navigationTitle(
            "账单详情"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .sheet(
            isPresented:
                $showEdit
        ) {

            EditTransactionView(
                transaction:
                    transaction
            )
        }
        .confirmationDialog(
            "确定删除这笔账单？",
            isPresented:
                $showDeleteConfirmation,
            titleVisibility:
                .visible
        ) {

            Button(
                "删除",
                role: .destructive
            ) {

                deleteTransaction()
            }


            Button(
                "取消",
                role: .cancel
            ) {}
        } message: {

            Text(
                "删除后，关联账户余额会自动恢复。"
            )
        }
    }


    private var displayAmount:
        String {

        switch transaction.type {

        case .expense:

            return
                "-\(abs(transaction.amount).formatted(.currency(code: "CNY")))"


        case .income:

            return
                "+\(abs(transaction.amount).formatted(.currency(code: "CNY")))"


        case .transfer:

            return
                abs(transaction.amount)
                    .formatted(
                        .currency(
                            code: "CNY"
                        )
                    )


        case .adjustment:

            if transaction.amount >=
                0 {

                return
                    "+\(transaction.amount.formatted(.currency(code: "CNY")))"

            } else {

                return
                    transaction.amount
                        .formatted(
                            .currency(
                                code: "CNY"
                            )
                        )
            }
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


    private func deleteTransaction() {

        let success =
            TransactionService.delete(
                transaction,
                accounts:
                    accounts,
                context:
                    modelContext
            )

        if success {

            dismiss()
        }
    }
}



// MARK: - 编辑流水

struct EditTransactionView: View {

    let transaction:
        TransactionRecord


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
    private var type:
        TransactionType


    @State
    private var amountText:
        String


    @State
    private var category:
        String


    @State
    private var sourceAccountID:
        UUID?


    @State
    private var targetAccountID:
        UUID?


    @State
    private var note:
        String


    @State
    private var date:
        Date


    @State
    private var showError =
        false


    @FocusState
    private var isAmountFocused:
        Bool


    private let expenseCategories = [
        "餐饮",
        "交通",
        "购物",
        "娱乐",
        "居住",
        "医疗",
        "数码",
        "衣物",
        "日用",
        "其他"
    ]


    private let incomeCategories = [
        "工资",
        "奖金",
        "兼职",
        "理财",
        "红包",
        "报销",
        "其他"
    ]


    init(
        transaction:
            TransactionRecord
    ) {

        self.transaction =
            transaction

        _type =
            State(
                initialValue:
                    transaction.type
            )

        _amountText =
            State(
                initialValue:
                    String(
                        format:
                            "%.2f",
                        abs(
                            transaction
                                .amount
                        )
                    )
            )

        _category =
            State(
                initialValue:
                    transaction
                        .category
            )

        _sourceAccountID =
            State(
                initialValue:
                    transaction
                        .accountID
            )

        _targetAccountID =
            State(
                initialValue:
                    transaction
                        .targetAccountID
            )

        _note =
            State(
                initialValue:
                    transaction.note
            )

        _date =
            State(
                initialValue:
                    transaction.date
            )
    }


    var body: some View {

        NavigationStack {

            Form {

                Section {

                    Picker(
                        "类型",
                        selection:
                            $type
                    ) {

                        ForEach(
                            TransactionType
                                .userSelectableCases
                        ) { item in

                            Text(
                                item.rawValue
                            )
                            .tag(item)
                        }
                    }
                    .pickerStyle(
                        .segmented
                    )
                }


                Section("金额") {

                    HStack {

                        Text("¥")
                            .foregroundStyle(
                                .secondary
                            )

                        TextField(
                            "0.00",
                            text:
                                $amountText
                        )
                        .keyboardType(
                            .decimalPad
                        )
                        .focused(
                            $isAmountFocused
                        )
                    }
                }


                if type !=
                    .transfer {

                    Section(
                        "分类"
                    ) {

                        Picker(
                            "分类",
                            selection:
                                $category
                        ) {

                            ForEach(
                                currentCategories,
                                id: \.self
                            ) { item in

                                Text(
                                    item
                                )
                                .tag(item)
                            }
                        }
                    }
                }


                Section(
                    type == .transfer
                    ? "转出账户"
                    : "账户"
                ) {

                    Picker(
                        "选择账户",
                        selection:
                            $sourceAccountID
                    ) {

                        Text("请选择")
                            .tag(
                                UUID?.none
                            )

                        ForEach(
                            accounts
                        ) { account in

                            Text(
                                account.name
                            )
                            .tag(
                                Optional(
                                    account.id
                                )
                            )
                        }
                    }
                }


                if type ==
                    .transfer {

                    Section(
                        "转入账户"
                    ) {

                        Picker(
                            "选择账户",
                            selection:
                                $targetAccountID
                        ) {

                            Text("请选择")
                                .tag(
                                    UUID?.none
                                )

                            ForEach(
                                accounts
                            ) { account in

                                Text(
                                    account.name
                                )
                                .tag(
                                    Optional(
                                        account.id
                                    )
                                )
                            }
                        }
                    }
                }


                Section(
                    "其他"
                ) {

                    DatePicker(
                        "日期",
                        selection:
                            $date
                    )

                    TextField(
                        "备注",
                        text:
                            $note
                    )
                }
            }
            .scrollDismissesKeyboard(
                .interactively
            )
            .navigationTitle(
                "编辑账单"
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
                        !canSave
                    )
                }


                ToolbarItemGroup(
                    placement:
                        .keyboard
                ) {

                    Spacer()

                    Button("完成") {

                        isAmountFocused =
                            false
                    }
                }
            }
            .onChange(
                of: type
            ) {

                if type ==
                    .transfer {

                    category =
                        "转账"

                } else {

                    targetAccountID =
                        nil

                    category =
                        currentCategories
                            .first
                        ?? "其他"
                }
            }
            .alert(
                "修改失败",
                isPresented:
                    $showError
            ) {

                Button("好的") {}

            } message: {

                Text(
                    "请检查金额和账户是否正确"
                )
            }
        }
    }


    private var currentCategories:
        [String] {

        switch type {

        case .expense:
            return
                expenseCategories

        case .income:
            return
                incomeCategories

        case .transfer,
             .adjustment:
            return []
        }
    }


    private var amount:
        Double? {

        Double(
            amountText
                .replacingOccurrences(
                    of: ",",
                    with: "."
                )
        )
    }


    private var canSave:
        Bool {

        guard
            let amount,
            amount > 0,
            sourceAccountID !=
                nil
        else {

            return false
        }

        if type ==
            .transfer {

            return
                targetAccountID !=
                    nil &&

                targetAccountID !=
                    sourceAccountID
        }

        return true
    }


    private func save() {

        isAmountFocused =
            false

        guard
            let amount,
            let sourceID =
                sourceAccountID
        else {
            return
        }

        let success =
            TransactionService.update(
                transaction,
                type:
                    type,
                amount:
                    amount,
                category:
                    type == .transfer
                    ? "转账"
                    : category,
                accountID:
                    sourceID,
                targetAccountID:
                    type == .transfer
                    ? targetAccountID
                    : nil,
                note:
                    note,
                date:
                    date,
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