import SwiftUI
import SwiftData

struct AddTransactionView: View {

    @Environment(\.modelContext)
    private var modelContext

    @Query(
        sort: \Account.createdAt
    )
    private var accounts: [Account]

    @State private var type:
        TransactionType = .expense

    @State private var amountText = ""

    @State private var category = "餐饮"

    @State private var sourceAccountID:
        UUID?

    @State private var targetAccountID:
        UUID?

    @State private var note = ""

    @State private var date = Date()

    @State private var showSavedAlert = false

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

    var body: some View {

        Form {

            Section {

                Picker(
                    "类型",
                    selection: $type
                ) {

                    ForEach(
                        TransactionType.allCases
                    ) { item in

                        Text(item.rawValue)
                            .tag(item)
                    }
                }
                .pickerStyle(.segmented)

            }

            Section("金额") {

                HStack {

                    Text("¥")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    TextField(
                        "0.00",
                        text: $amountText
                    )
                    .keyboardType(.decimalPad)
                    .font(.title2.bold())
                }
            }

            if type != .transfer {

                Section("分类") {

                    Picker(
                        "分类",
                        selection: $category
                    ) {

                        ForEach(
                            currentCategories,
                            id: \.self
                        ) { item in

                            Text(item)
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
                    selection: $sourceAccountID
                ) {

                    Text("请选择")
                        .tag(UUID?.none)

                    ForEach(accounts) { account in

                        Text(
                            "\(account.name)  ¥\(account.balance, specifier: "%.2f")"
                        )
                        .tag(
                            Optional(account.id)
                        )
                    }
                }
            }

            if type == .transfer {

                Section("转入账户") {

                    Picker(
                        "选择账户",
                        selection: $targetAccountID
                    ) {

                        Text("请选择")
                            .tag(UUID?.none)

                        ForEach(accounts) { account in

                            Text(account.name)
                                .tag(
                                    Optional(account.id)
                                )
                        }
                    }
                }
            }

            Section("其他") {

                DatePicker(
                    "日期",
                    selection: $date
                )

                TextField(
                    "备注（可选）",
                    text: $note
                )
            }

            Section {

                Button {

                    saveTransaction()

                } label: {

                    Text("保存")
                        .frame(
                            maxWidth: .infinity
                        )
                        .fontWeight(.semibold)
                }
                .disabled(!canSave)
            }
        }
        .navigationTitle("记一笔")
        .onAppear {

            if sourceAccountID == nil {
                sourceAccountID =
                    accounts.first?.id
            }
        }
        .onChange(of: type) {

            category =
                currentCategories.first
                ?? "其他"
        }
        .alert(
            "记录成功",
            isPresented: $showSavedAlert
        ) {

            Button("好的") {}

        } message: {

            Text("账户余额已同步更新")
        }
    }

    private var currentCategories:
        [String] {

        switch type {
        case .expense:
            return expenseCategories

        case .income:
            return incomeCategories

        case .transfer:
            return []
        }
    }

    private var amount: Double? {

        Double(
            amountText
                .replacingOccurrences(
                    of: ",",
                    with: "."
                )
        )
    }

    private var canSave: Bool {

        guard
            let amount,
            amount > 0,
            sourceAccountID != nil
        else {
            return false
        }

        if type == .transfer {

            return targetAccountID != nil &&
                targetAccountID !=
                sourceAccountID
        }

        return true
    }

    private func saveTransaction() {

        guard
            let amount,
            let sourceID = sourceAccountID,
            let source =
                accounts.first(
                    where: {
                        $0.id == sourceID
                    }
                )
        else {
            return
        }

        switch type {

        case .expense:

            source.balance -= amount

        case .income:

            source.balance += amount

        case .transfer:

            guard
                let targetID =
                    targetAccountID,
                let target =
                    accounts.first(
                        where: {
                            $0.id == targetID
                        }
                    )
            else {
                return
            }

            source.balance -= amount
            target.balance += amount
        }

        let record =
            TransactionRecord(
                type: type,
                amount: amount,
                category:
                    type == .transfer
                    ? "转账"
                    : category,
                accountID: sourceID,
                targetAccountID:
                    targetAccountID,
                note: note,
                date: date
            )

        modelContext.insert(record)

        try? modelContext.save()

        amountText = ""
        note = ""
        date = Date()

        showSavedAlert = true
    }
}