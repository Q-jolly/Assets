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

    @State private var category =
        "餐饮"

    @State private var sourceAccountID:
        UUID?

    @State private var targetAccountID:
        UUID?

    @State private var note = ""

    @State private var date =
        Date()

    @State private var showSavedAlert =
        false

    @State private var showErrorAlert =
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


    var body: some View {

        Form {

            Section {

                Picker(
                    "类型",
                    selection: $type
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
                        .font(.title2)
                        .foregroundStyle(
                            .secondary
                        )

                    TextField(
                        "0.00",
                        text: $amountText
                    )
                    .keyboardType(
                        .decimalPad
                    )
                    .focused(
                        $isAmountFocused
                    )
                    .font(
                        .title2.bold()
                    )
                }
            }


            if type != .transfer {

                Section("分类") {

                    Picker(
                        "分类",
                        selection:
                            $category
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
                            "\(account.name)  ¥\(account.balance, specifier: "%.2f")"
                        )
                        .tag(
                            Optional(
                                account.id
                            )
                        )
                    }
                }
            }


            if type == .transfer {

                Section("转入账户") {

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
                            maxWidth:
                                .infinity
                        )
                        .fontWeight(
                            .semibold
                        )
                }
                .disabled(
                    !canSave
                )
            }
        }
        .scrollDismissesKeyboard(
            .interactively
        )
        .navigationTitle(
            "记一笔"
        )
        .toolbar {

            ToolbarItemGroup(
                placement: .keyboard
            ) {

                Spacer()

                Button("完成") {

                    isAmountFocused =
                        false
                }
                .fontWeight(
                    .semibold
                )
            }
        }
        .onAppear {

            if sourceAccountID ==
                nil {

                sourceAccountID =
                    accounts.first?.id
            }
        }
        .onChange(of: type) {

            if type != .transfer {

                category =
                    currentCategories
                        .first
                    ?? "其他"

                targetAccountID =
                    nil
            }
        }
        .alert(
            "记录成功",
            isPresented:
                $showSavedAlert
        ) {

            Button("好的") {}

        } message: {

            Text(
                "账户余额已同步更新"
            )
        }
        .alert(
            "保存失败",
            isPresented:
                $showErrorAlert
        ) {

            Button("好的") {}

        } message: {

            Text(
                "请检查账户和金额是否正确"
            )
        }
    }


    private var currentCategories:
        [String] {

        switch type {

        case .expense:
            return expenseCategories

        case .income:
            return incomeCategories

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
            sourceAccountID != nil
        else {
            return false
        }

        if type == .transfer {

            return
                targetAccountID != nil &&
                targetAccountID !=
                    sourceAccountID
        }

        return true
    }


    private func saveTransaction() {

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
            TransactionService.create(
                type: type,
                amount: amount,
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
                note: note,
                date: date,
                accounts: accounts,
                context:
                    modelContext
            )

        if success {

            resetForm()

            showSavedAlert =
                true

        } else {

            showErrorAlert =
                true
        }
    }


    private func resetForm() {

        amountText = ""

        note = ""

        date = Date()

        if type == .transfer {

            targetAccountID =
                nil
        }
    }
}