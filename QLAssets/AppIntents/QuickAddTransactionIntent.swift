import AppIntents
import Foundation
import SwiftData


enum QuickAddTransactionError: LocalizedError {

    case invalidAmount
    case invalidType(String)
    case missingCategory
    case categoryNotFound(String)
    case accountNotFound(String)
    case unsupportedCurrency(String)
    case exchangeRateUnavailable(String)
    case saveFailed


    var errorDescription: String? {

        switch self {

        case .invalidAmount:
            return "金额必须大于 0。"

        case .invalidType(let type):
            return "无法判断账单类型“\(type)”，请选择收入或支出。"

        case .missingCategory:
            return "请选择一个分类。"

        case .categoryNotFound(let category):
            return "分类“\(category)”不在 QL Assets 当前分类列表中。请先从 App 获取分类列表。"

        case .accountNotFound(let account):
            return "找不到账户“\(account)”。请先从 QL Assets 获取账户列表。"

        case .unsupportedCurrency(let currency):
            return "QL Assets 暂不支持货币“\(currency)”。"

        case .exchangeRateUnavailable(let currency):
            return "暂时无法取得 \(currency) 到人民币的汇率，请联网后重试。"

        case .saveFailed:
            return "账单保存失败，账户余额未完成同步。"
        }
    }
}


enum QuickAddTransactionSupport {

    static func normalizedCurrencyCode(_ value: String) -> String {

        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let definition = CurrencyCatalog.supported.first(where: {
            $0.code.caseInsensitiveCompare(trimmed) == .orderedSame ||
            $0.name == trimmed
        }) {
            return definition.code
        }

        switch trimmed {

        case "港元":
            return "HKD"

        case "澳门币":
            return "MOP"

        default:
            return trimmed.uppercased()
        }
    }


    static func normalizedType(_ value: String?) throws -> TransactionType {

        let trimmed = value?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        switch trimmed.lowercased() {

        case "expense", "支出", "out", "debit":
            return .expense

        case "income", "收入", "in", "credit":
            return .income

        case "creditexpense", "credit_expense", "信用卡消费":
            return .creditExpense

        case "creditrepayment", "credit_repayment", "信用卡还款":
            return .creditRepayment

        case "":
            // 快捷指令没有传类型时，沿用 OCR 正负号约定：负数为支出，正数为收入。
            return .income

        default:
            throw QuickAddTransactionError.invalidType(trimmed)
        }
    }


    static func categoryNames(for type: TransactionType) -> [String] {

        let expense = CategoryStore.expenseCategories(
            from: UserDefaults.standard.string(forKey: CategoryStore.expenseKey) ?? ""
        )
        .map(\.name)

        let income = CategoryStore.incomeCategories(
            from: UserDefaults.standard.string(forKey: CategoryStore.incomeKey) ?? ""
        )
        .map(\.name)

        switch type {

        case .income:
            return income

        case .expense, .creditExpense:
            return expense

        case .creditRepayment:
            return ["信用卡还款"]

        case .transfer:
            return ["转账"]

        case .adjustment:
            return []
        }
    }


    static func allCategoryNames() -> [String] {

        var seen = Set<String>()
        return (categoryNames(for: .expense) + categoryNames(for: .income))
            .map(CategoryNormalizer.normalized)
            .filter { seen.insert($0).inserted }
    }


    static func makeContainer() throws -> ModelContainer {

        try ModelContainer(for: [
            Account.self,
            TransactionRecord.self,
            BankCard.self
        ])
    }


    @MainActor
    static func fetchAccountsAndCards(
        context: ModelContext
    ) throws -> (accounts: [Account], cards: [BankCard]) {

        let accounts = try context.fetch(
            FetchDescriptor<Account>(
                sortBy: [SortDescriptor(\Account.createdAt)]
            )
        )

        let cards = try context.fetch(
            FetchDescriptor<BankCard>(
                sortBy: [SortDescriptor(\BankCard.createdAt)]
            )
        )

        return (accounts, cards)
    }


    static func cardLabels(
        for card: BankCard
    ) -> [String] {

        let bank = card.bankName.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastFour = card.lastFourDigits.trimmingCharacters(in: .whitespacesAndNewlines)

        var labels = [
            "\(bank)\(card.cardType.rawValue)",
            "\(bank) •••• \(lastFour)"
        ]

        return labels
    }


    @MainActor
    static func accountChoices(
        context: ModelContext
    ) throws -> [String] {

        let result = try fetchAccountsAndCards(context: context)
        var seen = Set<String>()
        var values: [String] = []

        for account in result.accounts {
            let name = account.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, seen.insert(name).inserted else { continue }
            values.append(name)
        }

        for card in result.cards where card.cardType == .credit {
            let label = cardLabels(for: card).first ?? card.bankName
            guard !label.isEmpty, seen.insert(label).inserted else { continue }
            values.append(label)
        }

        return values
    }


    @MainActor
    static func save(
        amount: Double,
        currency: String,
        typeRaw: String?,
        category: String,
        accountName: String,
        note: String?,
        date: Date?
    ) async throws -> String {

        guard amount.isFinite, amount != 0 else {
            throw QuickAddTransactionError.invalidAmount
        }

        let requestedType = try normalizedType(typeRaw)
        let code = normalizedCurrencyCode(currency)

        guard CurrencyCatalog.supported.contains(where: { $0.code == code }) else {
            throw QuickAddTransactionError.unsupportedCurrency(code)
        }

        let container = try makeContainer()
        let context = ModelContext(container)
        let (accounts, cards) = try fetchAccountsAndCards(context: context)

        let requestedName = accountName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requestedName.isEmpty else {
            throw QuickAddTransactionError.accountNotFound(accountName)
        }

        let normalizedRequestedName = requestedName.lowercased()
        let selectedAccount = accounts.first {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedRequestedName
        }

        let selectedCard = cards.first { card in
            guard card.cardType == .credit else { return false }
            cardLabels(for: card).contains {
                $0.lowercased() == normalizedRequestedName
            }
        }

        var transactionType = requestedType
        var sourceAccount = selectedAccount
        var creditCard = selectedCard

        if transactionType == .creditExpense, creditCard == nil, let selectedAccount {
            creditCard = cards.first {
                $0.cardType == .credit && $0.accountID == selectedAccount.id
            }
        }

        if transactionType == .expense, selectedCard != nil, selectedAccount == nil {
            transactionType = .creditExpense
        }

        if transactionType == .creditExpense {
            guard creditCard != nil else {
                throw QuickAddTransactionError.accountNotFound(requestedName)
            }
            sourceAccount = nil
        } else {
            guard sourceAccount != nil else {
                throw QuickAddTransactionError.accountNotFound(requestedName)
            }
        }

        let categoryValue = CategoryNormalizer.normalized(category)
        guard !categoryValue.isEmpty else {
            throw QuickAddTransactionError.missingCategory
        }

        let availableCategories = categoryNames(for: transactionType)
            .map(CategoryNormalizer.normalized)
        if !availableCategories.contains(categoryValue) {
            throw QuickAddTransactionError.categoryNotFound(categoryValue)
        }

        var rates = ExchangeRateService.cachedSnapshot()
        let needsCurrencyRate = code != "CNY" && rates.rateToCNY(for: code) == nil
        let cacheExpired = Date().timeIntervalSince(rates.fetchedAt) >= 15 * 60

        if code != "CNY" && (needsCurrencyRate || cacheExpired) {
            let provider = ExchangeRateService.preferredProvider(for: sourceAccount?.name ?? creditCard?.bankName)
            if let refreshed = try? await ExchangeRateService.refresh(provider: provider) {
                rates = refreshed
            }
        }

        let inputRate = code == "CNY" ? 1 : rates.rateToCNY(for: code)
        guard let inputRate, inputRate > 0 else {
            throw QuickAddTransactionError.exchangeRateUnavailable(code)
        }

        let absoluteAmount = abs(amount)
        let cnyAmount = absoluteAmount * inputRate

        let sourceRate: Double
        if let sourceAccount {
            if sourceAccount.currencyCode == "CNY" {
                sourceRate = 1
            } else {
                sourceRate = rates.rateToCNY(for: sourceAccount.currencyCode)
                    ?? sourceAccount.lastKnownRateToCNY
                    ?? 0
            }
            guard sourceRate > 0 else {
                throw QuickAddTransactionError.exchangeRateUnavailable(sourceAccount.currencyCode)
            }
        } else {
            sourceRate = 1
        }

        let accountAmount = transactionType == .creditExpense
            ? nil
            : cnyAmount / sourceRate

        let success = TransactionService.create(
            type: transactionType,
            amount: cnyAmount,
            originalAmount: absoluteAmount,
            currencyCode: code,
            exchangeRateToCNY: inputRate,
            accountAmount: accountAmount,
            category: categoryValue,
            accountID: sourceAccount?.id,
            bankCardID: creditCard?.id,
            note: note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            date: date ?? Date(),
            accounts: accounts,
            cards: cards,
            context: context
        )

        guard success else {
            throw QuickAddTransactionError.saveFailed
        }

        let typeText = transactionType == .income ? "收入" : "支出"
        let amountText = String(format: "%.2f %@", absoluteAmount, code)
        return "已保存\(typeText) \(amountText) · \(categoryValue)"
    }
}


struct QuickAddTransactionIntent: AppIntent {

    static let title: LocalizedStringResource = "快速记账"

    static let description = IntentDescription(
        "把快捷指令识别出的金额、分类、账户和备注保存到 QL Assets。"
    )

    static let openAppWhenRun = false

    @Parameter(title: "金额")
    var amount: Double

    @Parameter(title: "货币")
    var currency: String

    @Parameter(title: "类型")
    var type: String

    @Parameter(title: "分类")
    var category: String

    @Parameter(title: "账户")
    var account: String

    @Parameter(title: "备注")
    var note: String?

    @Parameter(title: "时间")
    var date: Date?

    func perform() async throws -> some IntentResult & ReturnsValue<String> {

        let message = try await QuickAddTransactionSupport.save(
            amount: amount,
            currency: currency,
            typeRaw: type,
            category: category,
            accountName: account,
            note: note,
            date: date
        )

        return .result(value: message)
    }
}
