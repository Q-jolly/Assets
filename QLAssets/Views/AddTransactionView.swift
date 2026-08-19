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


    private var creditCardIDs:
        [UUID] {

        creditCards.map(
            \.id
        )
    }


    private var exchangeRateRefreshKey:
        String {

        [
            currencyCode,
            selectedSourceAccount?.currencyCode ?? "",
            selectedTargetAccount?.currencyCode ?? "",
            selectedCreditCard?.bankName ?? ""
        ]
        .joined(
            separator:
                "|"
        )
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

            entryTypeSection

            amountSection

            categorySection

            creditCardSection

            sourceAccountSection

            targetAccountSection

            otherSection

            saveSection
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

            handleAppear()
        }
        .task {

            await runClockRefreshLoop()
        }
        .task(
            id:
                exchangeRateRefreshKey
        ) {

            await refreshExchangeRatesIfNeeded()
        }
        .onChange(
            of:
                mode
        ) { _, _ in

            updateForModeChange()
        }
        .onChange(
            of:
                creditAction
        ) { _, _ in

            updateForCreditActionChange()
        }
        .onChange(
            of:
                sourceAccountID
        ) { _, _ in

            handleSourceAccountChange()
        }
        .onChange(
            of:
                currencyCode
        ) { _, _ in

            handleCurrencyCodeChange()
        }
        .onChange(
            of:
                creditCardIDs
        ) { _, _ in

            handleCreditCardsChange()
        }
        .onChange(
            of:
                expenseCategoriesStored
        ) { _, _ in

            ensureValidCategory()
        }
        .onChange(
            of:
                incomeCategoriesStored
        ) { _, _ in

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


    // MARK: - 记账表单分区
    //
    // 这些 Section 原来全部堆在 body 的同一个 Form ViewBuilder 中。
    // Xcode Release + Whole Module Optimization 会在复杂 Picker / 条件视图处
    // 出现 “unable to type-check in reasonable time”。
    // 拆开后每个分区单独推导类型，功能和界面保持不变。

    @ViewBuilder
    private var entryTypeSection:
        some View {

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
                    .tag(
                        item
                    )
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
                        .tag(
                            action
                        )
                    }
                }
                .pickerStyle(
                    .segmented
                )
            }
        }
    }


    @ViewBuilder
    private var amountSection:
        some View {

        Section(
            "金额"
        ) {

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

                foreignCurrencyInfo
            }
        }
    }


    @ViewBuilder
    private var foreignCurrencyInfo:
        some View {

        if let converted =
            cnyAmount {

            LabeledContent(
                "人民币估值"
            ) {

                Text(
                    cnyEstimateText(
                        converted
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
                exchangeRateSummaryText(
                    rate:
                        rate
                )
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


    @ViewBuilder
    private var categorySection:
        some View {

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
    }


    @ViewBuilder
    private var creditCardSection:
        some View {

        if mode ==
            .creditCard {

            Section(
                "信用卡"
            ) {

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

                        Text(
                            "请选择"
                        )
                        .tag(
                            UUID?.none
                        )


                        ForEach(
                            creditCards
                        ) { card in

                            Text(
                                creditCardPickerLabel(
                                    card
                                )
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
                                sharedDebtText(
                                    for:
                                        card
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
                                    cnyEstimateText(
                                        available
                                    )
                                )
                            }
                        }
                    }
                }
            }
        }
    }


    @ViewBuilder
    private var sourceAccountSection:
        some View {

        if showsSourceAccount {

            Section(
                sourceSectionTitle
            ) {

                Picker(
                    "选择账户",
                    selection:
                        $sourceAccountID
                ) {

                    Text(
                        "请选择"
                    )
                    .tag(
                        UUID?.none
                    )


                    ForEach(
                        accounts
                    ) { account in

                        Text(
                            accountPickerLabel(
                                account
                            )
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
    }


    @ViewBuilder
    private var targetAccountSection:
        some View {

        if mode ==
            .transfer {

            Section(
                "转入账户"
            ) {

                Picker(
                    "选择账户",
                    selection:
                        $targetAccountID
                ) {

                    Text(
                        "请选择"
                    )
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
    }


    private var otherSection:
        some View {

        Section(
            "其他"
        ) {

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
    }


    private var saveSection:
        some View {

        Section {

            Button {

                saveTransaction()

            } label: {

                Text(
                    "保存"
                )
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


    private func creditCardPickerLabel(
        _ card:
            BankCard
    ) -> String {

        card.bankName +
            " •••• " +
            card.lastFourDigits
    }


    private func sharedDebtText(
        for card:
            BankCard
    ) -> String {

        let debt =
            CreditAccountService
                .sharedDebt(
                    for:
                        card,
                    cards:
                        cards
                )

        return cnyEstimateText(
            debt
        )
    }


    private func cnyEstimateText(
        _ value:
            Double
    ) -> String {

        String(
            format:
                "¥%.2f",
            value
        )
    }


    private func exchangeRateSummaryText(
        rate:
            Double
    ) -> String {

        let rateText =
            String(
                format:
                    "%.4f",
                rate
            )

        return "1 " +
            currencyCode +
            " ≈ ¥" +
            rateText +
            " · " +
            exchangeRates.sourceName
    }


    private func accountPickerLabel(
        _ account:
            Account
    ) -> String {

        let balanceText =
            account.balance
                .formatted(
                    .currency(
                        code:
                            account.currencyCode
                    )
                )

        return account.name +
            "  " +
            balanceText
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


    private func handleAppear() {

        ensureDefaults()


        if !dateWasManuallyEdited {

            date =
                Date()
        }


        synchronizeCurrencyWithCurrentContext()
    }


    @MainActor
    private func runClockRefreshLoop() async {

        while !Task.isCancelled {

            if !dateWasManuallyEdited {

                date =
                    Date()
            }


            try? await Task.sleep(
                for:
                    .seconds(15)
            )
        }
    }


    private func handleSourceAccountChange() {

        guard mode ==
            .transfer
        else {
            return
        }


        synchronizeCurrencyWithCurrentContext()
    }


    private func handleCurrencyCodeChange() {

        exchangeRateMessage =
            nil
    }


    private func handleCreditCardsChange() {

        guard
            !creditCards.isEmpty
        else {

            selectedCreditCardID =
                nil

            return
        }


        guard
            let currentID =
                selectedCreditCardID
        else {

            selectedCreditCardID =
                creditCards.first?.id

            return
        }


        let stillExists =
            creditCards.contains {
                card in

                card.id ==
                    currentID
            }


        if !stillExists {

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
            15 *
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
