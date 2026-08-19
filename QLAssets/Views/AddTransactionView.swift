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
    private var currencyCode =
        "CNY"

    @State
    private var exchangeRates =
        ExchangeRateService
            .cachedSnapshot()

    @State
    private var isRefreshingRate =
        false

    @State
    private var exchangeRateMessage:
        String?

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
    private var dateWasManuallyEdited =
        false

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

                    Text(
                        CurrencyCatalog
                            .symbol(
                                for:
                                    currencyCode
                            )
                    )
                    .font(
                        .title2
                    )
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


                    Picker(
                        "币种",
                        selection:
                            $currencyCode
                    ) {

                        ForEach(
                            CurrencyCatalog
                                .supported
                        ) { currency in

                            Text(
                                currency.code
                            )
                            .tag(
                                currency.code
                            )
                        }
                    }
                    .labelsHidden()
                    .disabled(
                        transactionType ==
                            .creditRepayment ||
                        transactionType ==
                            .adjustment
                    )
                }


                if currencyCode !=
                    "CNY" {

                    if let converted =
                        cnyAmount {

                        LabeledContent(
                            "人民币估值"
                        ) {

                            Text(
                                converted,
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
                    }


                    if let rate =
                        selectedCurrencyRate {

                        Text(
                            "1 \(currencyCode) ≈ ¥\(rate.formatted(.number.precision(.fractionLength(4)))) · \(exchangeRates.sourceName)"
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )

                    } else if isRefreshingRate {

                        Label(
                            "正在查询银行实时汇率…",
                            systemImage:
                                "arrow.triangle.2.circlepath"
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }


                    if let exchangeRateMessage {

                        Text(
                            exchangeRateMessage
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
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
                                    CreditAccountService
                                        .sharedDebt(
                                            for:
                                                card,
                                            cards:
                                                cards
                                        ),
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
                                CreditAccountService
                                    .availableCredit(
                                        for:
                                            card,
                                        cards:
                                            cards
                                    ) {

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
                                "\(account.name)  \(account.balance.formatted(.currency(code: account.currencyCode)))"
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
                        Binding(
                            get: {
                                date
                            },
                            set: {
                                newValue in

                                date =
                                    newValue

                                dateWasManuallyEdited =
                                    true
                            }
                        )
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

            if !dateWasManuallyEdited {

                date =
                    Date()
            }

            synchronizeCurrencyWithCurrentContext()
        }
        .task {

            while !Task.isCancelled {

                if !dateWasManuallyEdited {

                    await MainActor.run {

                        date =
                            Date()
                    }
                }


                try? await Task.sleep(
                    for:
                        .seconds(15)
                )
            }
        }
        .task(
            id:
                currencyCode +
                (selectedSourceAccount?.currencyCode ?? "") +
                (selectedTargetAccount?.currencyCode ?? "") +
                (selectedCreditCard?.bankName ?? "")
        ) {

            await refreshExchangeRatesIfNeeded()
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
            of:
                sourceAccountID
        ) { _, _ in

            if mode ==
                .transfer {

                synchronizeCurrencyWithCurrentContext()
            }
        }
        .onChange(
            of:
                currencyCode
        ) { _, _ in

            exchangeRateMessage =
                nil
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


    private var selectedSourceAccount:
        Account? {

        guard let sourceAccountID
        else {
            return nil
        }


        return accounts.first {
            $0.id ==
            sourceAccountID
        }
    }


    private var selectedTargetAccount:
        Account? {

        guard let targetAccountID
        else {
            return nil
        }


        return accounts.first {
            $0.id ==
            targetAccountID
        }
    }


    private var selectedCurrencyRate:
        Double? {

        exchangeRates
            .rateToCNY(
                for:
                    currencyCode
            )
    }


    private var cnyAmount:
        Double? {

        guard let amount
        else {
            return nil
        }


        guard let rate =
            selectedCurrencyRate
        else {
            return nil
        }


        return amount *
            rate
    }


    private func rateToCNY(
        for account:
            Account?
    ) -> Double? {

        guard let account
        else {
            return nil
        }


        if account.currencyCode ==
            "CNY" {

            return 1
        }


        return exchangeRates
            .rateToCNY(
                for:
                    account.currencyCode
            ) ??
            account.lastKnownRateToCNY
    }


    private var sourceNativeAmount:
        Double? {

        guard let cnyAmount
        else {
            return nil
        }


        guard let source =
            selectedSourceAccount
        else {
            return nil
        }


        guard let rate =
            rateToCNY(
                for:
                    source
            ),
            rate >
                0
        else {
            return nil
        }


        return cnyAmount /
            rate
    }


    private var targetNativeAmount:
        Double? {

        guard let cnyAmount
        else {
            return nil
        }


        guard let target =
            selectedTargetAccount
        else {
            return nil
        }


        guard let rate =
            rateToCNY(
                for:
                    target
            ),
            rate >
                0
        else {
            return nil
        }


        return cnyAmount /
            rate
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
            cnyAmount !=
                nil
        else {
            return false
        }

        switch transactionType {

        case .expense,
             .income:

            return
                sourceAccountID !=
                    nil &&
                sourceNativeAmount !=
                    nil

        case .transfer:

            return
                sourceAccountID !=
                    nil &&
                targetAccountID !=
                    nil &&
                targetAccountID !=
                    sourceAccountID &&
                sourceNativeAmount !=
                    nil &&
                targetNativeAmount !=
                    nil

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

            return
                sourceNativeAmount !=
                    nil &&
                (cnyAmount ?? 0) <=
                    max(
                        card.currentDebt ??
                        0,
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

        synchronizeCurrencyWithCurrentContext()
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

        synchronizeCurrencyWithCurrentContext()
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

        guard
            let amount,
            let cnyAmount
        else {
            return
        }

        let success =
            TransactionService.create(
                type:
                    transactionType,
                amount:
                    cnyAmount,
                originalAmount:
                    amount,
                currencyCode:
                    currencyCode,
                exchangeRateToCNY:
                    selectedCurrencyRate,
                accountAmount:
                    transactionType ==
                        .creditExpense
                    ? nil
                    : sourceNativeAmount,
                targetAccountAmount:
                    transactionType ==
                        .transfer
                    ? targetNativeAmount
                    : nil,
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

        dateWasManuallyEdited =
            false

        targetAccountID =
            nil

        synchronizeCurrencyWithCurrentContext()
    }


    private func synchronizeCurrencyWithCurrentContext() {

        switch transactionType {

        case .transfer:

            currencyCode =
                selectedSourceAccount?
                    .currencyCode ??
                "CNY"

        case .creditRepayment:

            currencyCode =
                "CNY"

        case .expense,
             .income:

            if currencyCode ==
                "CNY",
               let accountCurrency =
                selectedSourceAccount?
                    .currencyCode,
               accountCurrency !=
                "CNY" {

                currencyCode =
                    accountCurrency
            }

        case .creditExpense:
            break

        case .adjustment:
            currencyCode =
                "CNY"
        }
    }


    @MainActor
    private func refreshExchangeRatesIfNeeded() async {

        let requiredCodes =
            Set(
                [
                    currencyCode,
                    selectedSourceAccount?
                        .currencyCode,
                    selectedTargetAccount?
                        .currencyCode
                ]
                .compactMap {
                    $0
                }
                .filter {
                    $0 !=
                    "CNY"
                }
            )


        guard !requiredCodes.isEmpty
        else {

            exchangeRateMessage =
                nil

            return
        }


        let hasAllRates =
            requiredCodes.allSatisfy {
                exchangeRates
                    .rateToCNY(
                        for:
                            $0
                    ) !=
                    nil
            }


        if hasAllRates,
           Date()
            .timeIntervalSince(
                exchangeRates.fetchedAt
            ) <
            5 *
            60 {

            return
        }


        isRefreshingRate =
            true

        defer {

            isRefreshingRate =
                false
        }


        do {

            let provider =
                ExchangeRateService
                    .preferredProvider(
                        for:
                            selectedCreditCard?
                                .bankName
                    )

            var refreshed =
                try await ExchangeRateService
                    .refresh(
                        provider:
                            provider
                    )


            let stillMissing =
                requiredCodes.contains {
                    refreshed.rateToCNY(
                        for:
                            $0
                    ) ==
                    nil
                }


            if stillMissing,
               provider !=
                .boc {

                refreshed =
                    try await ExchangeRateService
                        .refresh(
                            provider:
                                .boc
                        )
            }


            exchangeRates =
                refreshed

            exchangeRateMessage =
                "汇率仅用于记账估值，实际信用卡入账汇率以发卡行清算结果为准。"

        } catch {

            let cached =
                ExchangeRateService
                    .cachedSnapshot()

            if requiredCodes.allSatisfy(
                {
                    cached.rateToCNY(
                        for:
                            $0
                    ) !=
                        nil
                }
            ) {

                exchangeRates =
                    cached

                exchangeRateMessage =
                    "实时查询失败，当前使用上次缓存的银行汇率。"

            } else {

                exchangeRateMessage =
                    "暂时无法取得 \(currencyCode) 汇率，请联网后重试。"
            }
        }
    }
}
