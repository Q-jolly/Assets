import SwiftUI
import SwiftData


struct AddTransactionView: View {

    private enum EntryMode:
        String,
        CaseIterable,
        Identifiable {

        case expense = "支出"
        case income = "收入"
        case transfer = "转账"
        case creditCard = "信用卡"

        var id: String {
            rawValue
        }
    }


    private enum CreditAction:
        String,
        CaseIterable,
        Identifiable {

        case purchase = "消费"
        case repayment = "还款"

        var id: String {
            rawValue
        }
    }


    @Environment(\.modelContext)
    private var modelContext

    @Query(
        sort: \Account.createdAt
    )
    private var accounts:
        [Account]

    @Query(
        sort: [
            SortDescriptor(
                \BankCard.sortOrder
            ),
            SortDescriptor(
                \BankCard.createdAt
            )
        ]
    )
    private var cards:
        [BankCard]

    @State
    private var mode:
        EntryMode = .expense

    @State
    private var creditAction:
        CreditAction = .purchase

    @State
    private var amountText =
        ""

    @State
    private var category =
        "餐饮"

    @State
    private var sourceAccountID:
        UUID?

    @State
    private var targetAccountID:
        UUID?

    @State
    private var selectedCreditCardID:
        UUID?

    @State
    private var note =
        ""

    @State
    private var date =
        Date()

    @State
    private var showSavedAlert =
        false

    @State
    private var showErrorAlert =
        false

    @FocusState
    private var isAmountFocused:
        Bool


    @AppStorage(
        CategoryStore
            .expenseKey
    )
    private var expenseCategoriesStored =
        ""

    @AppStorage(
        CategoryStore
            .incomeKey
    )
    private var incomeCategoriesStored =
        ""


    private var expenseCategoryItems:
        [CategoryItem] {

        CategoryStore
            .expenseCategories(
                from:
                    expenseCategoriesStored
            )
    }


    private var incomeCategoryItems:
        [CategoryItem] {

        CategoryStore
            .incomeCategories(
                from:
                    incomeCategoriesStored
            )
    }


    private var expenseCategories:
        [String] {

        expenseCategoryItems
            .map(
                \.name
            )
    }


    private var incomeCategories:
        [String] {

        incomeCategoryItems
            .map(
                \.name
            )
    }


    private var creditCards:
        [BankCard] {

        cards.filter {
            $0.cardType == .credit
        }
    }


    private var transactionType:
        TransactionType {

        switch mode {

        case .expense:
            return .expense

        case .income:
            return .income

        case .transfer:
            return .transfer

        case .creditCard:

            switch creditAction {

            case .purchase:
                return .creditExpense

            case .repayment:
                return .creditRepayment
            }
        }
    }


    var body: some View {

        Form {

            Section {

                Picker(
                    "类型",
                    selection:
                        $mode
                ) {

                    ForEach(
                        EntryMode.allCases
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


                if mode ==
                    .creditCard {

                    Picker(
                        "信用卡操作",
                        selection:
                            $creditAction
                    ) {

                        ForEach(
                            CreditAction.allCases
                        ) { action in

                            Text(
                                action.rawValue
                            )
                            .tag(action)
                        }
                    }
                    .pickerStyle(
                        .segmented
                    )
                }
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
                        text:
                            $amountText
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


            if showsCategory {

                Section {

                    Picker(
                        "分类",
                        selection:
                            $category
                    ) {

                        ForEach(
                            currentCategoryItems
                        ) { item in

                            Label(
                                item.name,
                                systemImage:
                                    item.icon
                            )
                            .tag(
                                item.name
                            )
                        }
                    }


                    NavigationLink {

                        CategoryManagerView()

                    } label: {

                        Label(
                            "管理分类",
                            systemImage:
                                "square.grid.2x2"
                        )
                    }

                } header: {

                    Text(
                        "分类"
                    )
                }
            }


            if mode ==
                .creditCard {

                Section("信用卡") {

                    if creditCards.isEmpty {

                        Label(
                            "还没有信用卡，请先到卡包添加",
                            systemImage:
                                "creditcard"
                        )
                        .foregroundStyle(
                            .secondary
                        )

                    } else {

                        Picker(
                            "选择信用卡",
                            selection:
                                $selectedCreditCardID
                        ) {

                            Text("请选择")
                                .tag(
                                    UUID?.none
                                )

                            ForEach(
                                creditCards
                            ) { card in

                                Text(
                                    "\(card.bankName) •••• \(card.lastFourDigits)"
                                )
                                .tag(
                                    Optional(
                                        card.id
                                    )
                                )
                            }
                        }


                        if let card =
                            selectedCreditCard {

                            LabeledContent(
                                "当前欠款"
                            ) {

                                Text(
                                    card.currentDebt ?? 0,
                                    format:
                                        .currency(
                                            code:
                                                "CNY"
                                        )
                                )
                                .fontWeight(
                                    .semibold
                                )
                            }


                            if let available =
                                card.availableCredit {

                                LabeledContent(
                                    "可用额度"
                                ) {

                                    Text(
                                        available,
                                        format:
                                            .currency(
                                                code:
                                                    "CNY"
                                            )
                                    )
                                }
                            }
                        }
                    }
                }
            }


            if showsSourceAccount {

                Section(
                    sourceSectionTitle
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
                                "\(account.name)  \(account.balance.formatted(.currency(code: "CNY")))"
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


            if mode ==
                .transfer {

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
                    selection:
                        $date
                )

                TextField(
                    "备注（可选）",
                    text:
                        $note
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
                placement:
                    .keyboard
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

            ensureDefaults()
        }
        .onChange(
            of: mode
        ) { _ in

            updateForModeChange()
        }
        .onChange(
            of: creditAction
        ) { _ in

            updateForCreditActionChange()
        }
        .onChange(
            of: creditCards.map(\.id)
        ) { _ in

            if selectedCreditCardID ==
                nil ||
               !creditCards.contains(
                    where: {
                        $0.id ==
                            selectedCreditCardID
                    }
               ) {

                selectedCreditCardID =
                    creditCards.first?.id
            }
        }
        .onChange(
            of:
                expenseCategoriesStored
        ) { _ in

            ensureValidCategory()
        }
        .onChange(
            of:
                incomeCategoriesStored
        ) { _ in

            ensureValidCategory()
        }
        .alert(
            "记录成功",
            isPresented:
                $showSavedAlert
        ) {

            Button("好的") {}

        } message: {

            Text(
                successMessage
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
                "请检查金额、账户和信用卡信息是否正确"
            )
        }
    }


    private var showsCategory:
        Bool {

        switch transactionType {

        case .expense,
             .income,
             .creditExpense:
            return true

        case .transfer,
             .creditRepayment,
             .adjustment:
            return false
        }
    }


    private var showsSourceAccount:
        Bool {

        transactionType !=
            .creditExpense
    }


    private var sourceSectionTitle:
        String {

        switch transactionType {

        case .transfer:
            return "转出账户"

        case .creditRepayment:
            return "还款账户"

        default:
            return "账户"
        }
    }


    private var currentCategoryItems:
        [CategoryItem] {

        switch transactionType {

        case .expense,
             .creditExpense:

            return
                expenseCategoryItems

        case .income:

            return
                incomeCategoryItems

        case .transfer,
             .creditRepayment,
             .adjustment:

            return []
        }
    }


    private var currentCategories:
        [String] {

        switch transactionType {

        case .expense,
             .creditExpense:
            return expenseCategories

        case .income:
            return incomeCategories

        case .transfer,
             .creditRepayment,
             .adjustment:
            return []
        }
    }


    private var selectedCreditCard:
        BankCard? {

        guard let id =
            selectedCreditCardID
        else {
            return nil
        }

        return creditCards.first {
            $0.id == id
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
            amount > 0
        else {
            return false
        }

        switch transactionType {

        case .expense,
             .income:

            return
                sourceAccountID !=
                nil

        case .transfer:

            return
                sourceAccountID !=
                    nil &&
                targetAccountID !=
                    nil &&
                targetAccountID !=
                    sourceAccountID

        case .creditExpense:

            return
                selectedCreditCard !=
                nil

        case .creditRepayment:

            guard
                sourceAccountID != nil,
                let card =
                    selectedCreditCard
            else {
                return false
            }

            return amount <=
                max(
                    card.currentDebt ?? 0,
                    0
                ) +
                0.0001

        case .adjustment:
            return false
        }
    }


    private var successMessage:
        String {

        switch transactionType {

        case .creditExpense:
            return "信用卡欠款已增加，并计入总负债"

        case .creditRepayment:
            return "还款账户余额和信用卡欠款已同步更新"

        default:
            return "账户余额已同步更新"
        }
    }


    private func ensureValidCategory() {

        guard showsCategory
        else {

            return
        }


        if !currentCategories
            .contains(
                category
            ) {

            category =
                currentCategories
                    .first
                ?? "其他"
        }
    }


    private func ensureDefaults() {

        if sourceAccountID ==
            nil {

            sourceAccountID =
                accounts.first?.id
        }

        if selectedCreditCardID ==
            nil {

            selectedCreditCardID =
                creditCards.first?.id
        }
    }


    private func updateForModeChange() {

        targetAccountID =
            nil

        switch mode {

        case .expense:
            category =
                expenseCategories.first ??
                "其他"

        case .income:
            category =
                incomeCategories.first ??
                "其他"

        case .transfer:
            category =
                "转账"

        case .creditCard:
            updateForCreditActionChange()
        }
    }


    private func updateForCreditActionChange() {

        switch creditAction {

        case .purchase:
            category =
                expenseCategories.first ??
                "其他"

        case .repayment:
            category =
                "信用卡还款"
        }

        if selectedCreditCardID ==
            nil {

            selectedCreditCardID =
                creditCards.first?.id
        }
    }


    private func saveTransaction() {

        isAmountFocused =
            false

        guard let amount
        else {
            return
        }

        let success =
            TransactionService.create(
                type:
                    transactionType,
                amount:
                    amount,
                category:
                    transactionType ==
                        .transfer
                    ? "转账"
                    : transactionType ==
                        .creditRepayment
                    ? "信用卡还款"
                    : category,
                accountID:
                    transactionType ==
                        .creditExpense
                    ? nil
                    : sourceAccountID,
                targetAccountID:
                    transactionType ==
                        .transfer
                    ? targetAccountID
                    : nil,
                bankCardID:
                    transactionType ==
                        .creditExpense ||
                    transactionType ==
                        .creditRepayment
                    ? selectedCreditCardID
                    : nil,
                note:
                    note,
                date:
                    date,
                accounts:
                    accounts,
                cards:
                    cards,
                context:
                    modelContext
            )

        if success {

            HapticFeedback
                .success()

            resetForm()

            showSavedAlert =
                true

        } else {

            HapticFeedback
                .error()

            showErrorAlert =
                true
        }
    }


    private func resetForm() {

        amountText =
            ""

        note =
            ""

        date =
            Date()

        targetAccountID =
            nil
    }
}
