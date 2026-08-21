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
    case transferRequiresTargetAccount
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

        case .transferRequiresTargetAccount:
            return "转账需要转出账户和转入账户；当前快捷记账流程只接收一个账户。"

        case .saveFailed:
            return "账单保存失败，账户余额未完成同步。"
        }
    }
}


enum QuickAddTransactionType: String, AppEnum, CaseIterable, Sendable {

    case expense
    case income
    case transfer


    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "收支类型")
    }


    static var caseDisplayRepresentations: [Self: DisplayRepresentation] {
        [
            .expense: DisplayRepresentation(title: "🔴 支出"),
            .income: DisplayRepresentation(title: "🟢 收入"),
            .transfer: DisplayRepresentation(title: "🔵 转账")
        ]
    }


    var transactionType: TransactionType {
        switch self {
        case .expense:
            return .expense
        case .income:
            return .income
        case .transfer:
            return .transfer
        }
    }
}


enum QuickAddCurrency: String, AppEnum, CaseIterable, Sendable {

    case cny = "CNY"
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case jpy = "JPY"
    case hkd = "HKD"
    case aud = "AUD"
    case cad = "CAD"
    case sgd = "SGD"
    case chf = "CHF"
    case nzd = "NZD"
    case krw = "KRW"
    case thb = "THB"
    case aed = "AED"
    case mop = "MOP"
    case dkk = "DKK"
    case sek = "SEK"
    case nok = "NOK"


    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "货币")
    }


    static var caseDisplayRepresentations: [Self: DisplayRepresentation] {
        [
            .cny: DisplayRepresentation(title: "人民币 · CNY"),
            .usd: DisplayRepresentation(title: "美元 · USD"),
            .eur: DisplayRepresentation(title: "欧元 · EUR"),
            .gbp: DisplayRepresentation(title: "英镑 · GBP"),
            .jpy: DisplayRepresentation(title: "日元 · JPY"),
            .hkd: DisplayRepresentation(title: "港币 · HKD"),
            .aud: DisplayRepresentation(title: "澳元 · AUD"),
            .cad: DisplayRepresentation(title: "加元 · CAD"),
            .sgd: DisplayRepresentation(title: "新加坡元 · SGD"),
            .chf: DisplayRepresentation(title: "瑞士法郎 · CHF"),
            .nzd: DisplayRepresentation(title: "新西兰元 · NZD"),
            .krw: DisplayRepresentation(title: "韩元 · KRW"),
            .thb: DisplayRepresentation(title: "泰铢 · THB"),
            .aed: DisplayRepresentation(title: "阿联酋迪拉姆 · AED"),
            .mop: DisplayRepresentation(title: "澳门元 · MOP"),
            .dkk: DisplayRepresentation(title: "丹麦克朗 · DKK"),
            .sek: DisplayRepresentation(title: "瑞典克朗 · SEK"),
            .nok: DisplayRepresentation(title: "挪威克朗 · NOK")
        ]
    }


    var code: String {
        rawValue
    }
}


struct QuickAddCategoryRecord: Hashable, Sendable {

    let id: String
    let name: String
    let icon: String
    let transactionType: QuickAddTransactionType
}


struct QuickAddCategoryEntity: AppEntity, Hashable, Sendable {

    let id: String
    let name: String
    let icon: String
    let transactionType: QuickAddTransactionType


    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "分类")
    }


    static var defaultQuery = QuickAddCategoryQuery()


    var displayRepresentation: DisplayRepresentation {
        // 名称和图标均来自 App 当前分类记录，不在快捷指令中维护副本。
        DisplayRepresentation(title: "\(name)")
    }
}


struct QuickAddCategoryQuery: EntityQuery, EntityStringQuery, Sendable {

    func entities(for identifiers: [QuickAddCategoryEntity.ID]) async throws -> [QuickAddCategoryEntity] {
        allEntities().filter { identifiers.contains($0.id) }
    }


    func suggestedEntities() async throws -> [QuickAddCategoryEntity] {
        allEntities()
    }


    func entities(matching string: String) async throws -> [QuickAddCategoryEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return allEntities() }
        return allEntities().filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }


    private func allEntities() -> [QuickAddCategoryEntity] {
        QuickAddTransactionSupport.categoryRecords().map {
            QuickAddCategoryEntity(
                id: $0.id,
                name: $0.name,
                icon: $0.icon,
                transactionType: $0.transactionType
            )
        }
    }
}


struct QuickAddAccountEntity: AppEntity, Hashable, Sendable {

    let id: String
    let name: String
    let currencyCode: String
    let isCreditCard: Bool


    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "账户")
    }


    static var defaultQuery = QuickAddAccountQuery()


    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}


struct QuickAddAccountQuery: EntityQuery, EntityStringQuery, Sendable {

    func entities(for identifiers: [QuickAddAccountEntity.ID]) async throws -> [QuickAddAccountEntity] {
        try await suggestedEntities().filter { identifiers.contains($0.id) }
    }


    func suggestedEntities() async throws -> [QuickAddAccountEntity] {
        try await MainActor.run {
            let container = try QuickAddTransactionSupport.makeContainer()
            let context = ModelContext(container)
            let result = try QuickAddTransactionSupport.fetchAccountsAndCards(context: context)
            var entities: [QuickAddAccountEntity] = []
            var seen = Set<String>()

            for account in result.accounts {
                let name = account.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, seen.insert(name).inserted else { continue }
                entities.append(
                    QuickAddAccountEntity(
                        id: account.id.uuidString,
                        name: name,
                        currencyCode: account.currencyCode,
                        isCreditCard: false
                    )
                )
            }

            for card in result.cards where card.cardType == .credit {
                let name = QuickAddTransactionSupport.cardLabels(for: card).first ?? card.bankName
                guard !name.isEmpty, seen.insert(name).inserted else { continue }
                let currency = result.accounts.first {
                    $0.id == card.accountID
                }?.currencyCode ?? "CNY"
                entities.append(
                    QuickAddAccountEntity(
                        id: "card:\(card.id.uuidString)",
                        name: name,
                        currencyCode: currency,
                        isCreditCard: true
                    )
                )
            }

            return entities
        }
    }


    func entities(matching string: String) async throws -> [QuickAddAccountEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return try await suggestedEntities() }
        return try await suggestedEntities().filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.currencyCode.localizedCaseInsensitiveContains(query)
        }
    }
}


enum QuickAddTransactionSupport {

    static func normalizedCurrencyCode(_ value: QuickAddCurrency) -> String {

        value.code
    }


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


    static func normalizedType(
        _ value: QuickAddTransactionType?,
        amount: Double
    ) throws -> TransactionType {

        if let value {
            return value.transactionType
        }

        // 快捷指令没有传类型时，沿用 OCR 正负号约定：负数为支出，正数为收入。
        if amount < 0 {
            return .expense
        }
        if amount > 0 {
            return .income
        }
        throw QuickAddTransactionError.invalidType("")
    }


    static func categoryNames(for type: TransactionType) -> [String] {
        categoryRecords(for: quickAddType(for: type)).map(\.name)
    }


    static func allCategoryNames() -> [String] {

        var seen = Set<String>()
        return categoryRecords()
            .map { CategoryNormalizer.normalized($0.name) }
            .filter { seen.insert($0).inserted }
    }


    /// Returns the same category records that the App's category manager uses.
    /// IDs are preserved so a Shortcut passes the selected category identity
    /// instead of maintaining a second hard-coded name list.
    static func categoryRecords(
        for type: QuickAddTransactionType? = nil
    ) -> [QuickAddCategoryRecord] {

        let requestedTypes: [QuickAddTransactionType] =
            type.map { [$0] } ?? [.expense, .income]

        let defaults = UserDefaults.standard
        let expense = CategoryStore.expenseCategories(
            from: defaults.string(forKey: CategoryStore.expenseKey) ?? ""
        )
        let income = CategoryStore.incomeCategories(
            from: defaults.string(forKey: CategoryStore.incomeKey) ?? ""
        )

        var records: [QuickAddCategoryRecord] = []
        var seen = Set<String>()

        for requestedType in requestedTypes {
            let items: [CategoryItem]
            switch requestedType {
            case .expense:
                items = expense
            case .income:
                items = income
            case .transfer:
                items = [CategoryItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "转账", icon: "arrow.left.arrow.right")]
            }

            for item in items {
                let normalizedName = CategoryNormalizer.normalized(item.name)
                guard !normalizedName.isEmpty else { continue }
                let id = item.id.uuidString
                guard seen.insert("\(requestedType.rawValue):\(id)").inserted else { continue }
                records.append(
                    QuickAddCategoryRecord(
                        id: id,
                        name: normalizedName,
                        icon: item.icon,
                        transactionType: requestedType
                    )
                )
            }
        }

        return records
    }


    static func categoryRecord(
        for entity: QuickAddCategoryEntity,
        type: TransactionType
    ) -> QuickAddCategoryRecord? {

        let requestedType = quickAddType(for: type)
        let records = categoryRecords(for: requestedType)

        // Preferred path: the AppEntity ID is the CategoryItem UUID.
        if let match = records.first(where: { $0.id == entity.id }) {
            return match
        }

        // Compatibility path for entities created by the previous build,
        // whose ID was the category name rather than the stored UUID.
        let normalizedName = CategoryNormalizer.normalized(entity.name)
        return records.first {
            CategoryNormalizer.normalized($0.name) == normalizedName
        }
    }


    private static func quickAddType(
        for type: TransactionType
    ) -> QuickAddTransactionType? {

        switch type {
        case .income:
            return .income
        case .expense, .creditExpense, .creditRepayment:
            return .expense
        case .transfer:
            return .transfer
        case .adjustment:
            return nil
        }
    }


    static func makeContainer() throws -> ModelContainer {

        try ModelContainer(
            for: Account.self,
            TransactionRecord.self,
            BankCard.self
        )
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
        currency: QuickAddCurrency,
        type: QuickAddTransactionType?,
        category: QuickAddCategoryEntity,
        account: QuickAddAccountEntity,
        note: String?,
        date: Date?
    ) async throws -> String {

        guard amount.isFinite, amount != 0 else {
            throw QuickAddTransactionError.invalidAmount
        }

        let requestedType = try normalizedType(type, amount: amount)
        let code = normalizedCurrencyCode(currency)

        let container = try makeContainer()
        let context = ModelContext(container)
        let (accounts, cards) = try fetchAccountsAndCards(context: context)

        let requestedName = account.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requestedName.isEmpty else {
            throw QuickAddTransactionError.accountNotFound(account.name)
        }

        let normalizedRequestedName = requestedName.lowercased()
        let selectedAccount: Account?
        let selectedCard: BankCard?

        if let accountID = UUID(uuidString: account.id) {
            selectedAccount = accounts.first { $0.id == accountID }
            selectedCard = nil
        } else if account.id.hasPrefix("card:"),
                  let cardID = UUID(uuidString: String(account.id.dropFirst("card:".count))) {
            selectedAccount = nil
            selectedCard = cards.first { $0.id == cardID && $0.cardType == .credit }
        } else {
            selectedAccount = accounts.first {
                $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedRequestedName
            }
            selectedCard = cards.first { card in
                guard card.cardType == .credit else { return false }
                return cardLabels(for: card).contains {
                    $0.lowercased() == normalizedRequestedName
                }
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

        if transactionType == .transfer {
            throw QuickAddTransactionError.transferRequiresTargetAccount
        }

        guard let categoryRecord = categoryRecord(
            for: category,
            type: transactionType
        ) else {
            let categoryValue = CategoryNormalizer.normalized(category.name)
            if categoryValue.isEmpty {
                throw QuickAddTransactionError.missingCategory
            }
            throw QuickAddTransactionError.categoryNotFound(categoryValue)
        }

        let categoryValue = CategoryNormalizer.normalized(categoryRecord.name)

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

    static let title: LocalizedStringResource = "QL Assets 快速记账"

    static let description = IntentDescription(
        "把快捷指令识别出的金额、分类、账户和备注保存到 QL Assets。"
    )

    static let openAppWhenRun = false

    @Parameter(title: "金额")
    var amount: Double

    @Parameter(title: "货币")
    var currency: QuickAddCurrency

    @Parameter(title: "类型")
    var type: QuickAddTransactionType?

    @Parameter(title: "分类")
    var category: QuickAddCategoryEntity

    @Parameter(title: "账户")
    var account: QuickAddAccountEntity

    @Parameter(title: "备注")
    var note: String?

    @Parameter(title: "时间")
    var date: Date?

    func perform() async throws -> some IntentResult & ReturnsValue<String> {

        let message = try await QuickAddTransactionSupport.save(
            amount: amount,
            currency: currency,
            type: type,
            category: category,
            account: account,
            note: note,
            date: date
        )

        return .result(value: message)
    }
}
