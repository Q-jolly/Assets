import Foundation
import SwiftData


enum TransactionService {

    // 信用卡消费本身不对应资产账户，但 TransactionRecord 为兼容旧数据
    // 仍保留非可选 accountID，因此使用一个固定占位 UUID。
    static let noAccountID =
        UUID(
            uuidString:
                "00000000-0000-0000-0000-000000000001"
        )!


    // MARK: - 创建流水

    @discardableResult
    static func create(
        type: TransactionType,
        amount: Double,
        originalAmount: Double? = nil,
        currencyCode: String? = nil,
        exchangeRateToCNY: Double? = nil,
        accountAmount: Double? = nil,
        targetAccountAmount: Double? = nil,
        category: String,
        accountID: UUID?,
        targetAccountID: UUID? = nil,
        bankCardID: UUID? = nil,
        note: String,
        date: Date,
        accounts: [Account],
        cards: [BankCard] = [],
        context: ModelContext
    ) -> Bool {

        let normalizedAmount:
            Double

        if type == .adjustment {

            normalizedAmount =
                amount

        } else {

            normalizedAmount =
                abs(amount)
        }

        let storedAccountID =
            accountID ??
            noAccountID

        let record =
            TransactionRecord(
                type: type,
                amount:
                    normalizedAmount,
                originalAmount:
                    originalAmount,
                currencyCode:
                    currencyCode,
                exchangeRateToCNY:
                    exchangeRateToCNY,
                accountAmount:
                    accountAmount,
                targetAccountAmount:
                    targetAccountAmount,
                category:
                    category,
                accountID:
                    storedAccountID,
                targetAccountID:
                    targetAccountID,
                bankCardID:
                    bankCardID,
                note:
                    note,
                date:
                    date
            )

        guard apply(
            record,
            accounts:
                accounts,
            cards:
                cards
        ) else {
            return false
        }

        context.insert(
            record
        )

        do {

            try context.save()

            return true

        } catch {

            revert(
                record,
                accounts:
                    accounts,
                cards:
                    cards
            )

            context.delete(
                record
            )

            return false
        }
    }


    // MARK: - 删除流水

    @discardableResult
    static func delete(
        _ transaction:
            TransactionRecord,
        accounts: [Account],
        cards: [BankCard] = [],
        context: ModelContext
    ) -> Bool {

        guard revert(
            transaction,
            accounts:
                accounts,
            cards:
                cards
        ) else {
            return false
        }

        context.delete(
            transaction
        )

        do {

            try context.save()

            return true

        } catch {

            apply(
                transaction,
                accounts:
                    accounts,
                cards:
                    cards
            )

            return false
        }
    }


    // MARK: - 修改流水

    @discardableResult
    static func update(
        _ transaction:
            TransactionRecord,
        type: TransactionType,
        amount: Double,
        originalAmount: Double? = nil,
        currencyCode: String? = nil,
        exchangeRateToCNY: Double? = nil,
        accountAmount: Double? = nil,
        targetAccountAmount: Double? = nil,
        category: String,
        accountID: UUID?,
        targetAccountID: UUID?,
        bankCardID: UUID? = nil,
        note: String,
        date: Date,
        accounts: [Account],
        cards: [BankCard] = [],
        context: ModelContext
    ) -> Bool {

        let snapshot =
            TransactionSnapshot(
                transaction:
                    transaction
            )

        guard revert(
            transaction,
            accounts:
                accounts,
            cards:
                cards
        ) else {
            return false
        }

        transaction.typeRaw =
            type.rawValue

        if type == .adjustment {

            transaction.amount =
                amount

        } else {

            transaction.amount =
                abs(amount)
        }

        let oldAbsoluteAmount =
            abs(
                snapshot.amount
            )

        let newAbsoluteAmount =
            abs(
                amount
            )

        let amountScale =
            oldAbsoluteAmount >
                0.000_001
            ? newAbsoluteAmount /
                oldAbsoluteAmount
            : 1


        transaction.originalAmount =
            originalAmount ??
            snapshot.originalAmount
                .map {
                    $0 *
                    amountScale
                }

        transaction.currencyCodeRaw =
            currencyCode?.uppercased() ??
            snapshot.currencyCodeRaw

        transaction.exchangeRateToCNY =
            exchangeRateToCNY ??
            snapshot.exchangeRateToCNY

        transaction.accountAmount =
            accountAmount ??
            snapshot.accountAmount
                .map {
                    $0 *
                    amountScale
                }

        transaction.targetAccountAmount =
            targetAccountAmount ??
            snapshot.targetAccountAmount
                .map {
                    $0 *
                    amountScale
                }

        transaction.category =
            CategoryNormalizer
                .normalized(
                    category
                )

        transaction.accountID =
            accountID ??
            noAccountID

        transaction.targetAccountID =
            type == .transfer
            ? targetAccountID
            : nil

        transaction.bankCardID =
            type == .creditExpense ||
            type == .creditRepayment
            ? bankCardID
            : nil

        transaction.note =
            note

        transaction.date =
            date

        guard apply(
            transaction,
            accounts:
                accounts,
            cards:
                cards
        ) else {

            restore(
                transaction,
                snapshot:
                    snapshot
            )

            apply(
                transaction,
                accounts:
                    accounts,
                cards:
                    cards
            )

            return false
        }

        do {

            try context.save()

            return true

        } catch {

            revert(
                transaction,
                accounts:
                    accounts,
                cards:
                    cards
            )

            restore(
                transaction,
                snapshot:
                    snapshot
            )

            apply(
                transaction,
                accounts:
                    accounts,
                cards:
                    cards
            )

            return false
        }
    }


    // MARK: - 应用流水

    @discardableResult
    static func apply(
        _ transaction:
            TransactionRecord,
        accounts: [Account],
        cards: [BankCard] = []
    ) -> Bool {

        let amount =
            abs(
                transaction.amount
            )

        let sourceAccountAmount =
            abs(
                transaction.accountAmount ??
                amount
            )

        let targetAccountAmount =
            abs(
                transaction.targetAccountAmount ??
                amount
            )

        switch transaction.type {

        case .creditExpense:

            guard
                let cardID =
                    transaction.bankCardID,
                let card =
                    findCard(
                        cardID,
                        cards:
                            cards
                    ),
                card.cardType ==
                    .credit
            else {
                return false
            }

            card.currentDebt =
                max(
                    card.currentDebt ?? 0,
                    0
                ) +
                amount

            markDebtAsCNY(
                card
            )

            return true


        case .creditRepayment:

            guard
                let cardID =
                    transaction.bankCardID,
                let card =
                    findCard(
                        cardID,
                        cards:
                            cards
                    ),
                card.cardType ==
                    .credit,
                let source =
                    findAccount(
                        transaction.accountID,
                        accounts:
                            accounts
                    )
            else {
                return false
            }

            let currentDebt =
                max(
                    card.currentDebt ?? 0,
                    0
                )

            guard amount <=
                    currentDebt + 0.0001
            else {
                return false
            }

            source.balance -=
                sourceAccountAmount

            card.currentDebt =
                max(
                    currentDebt - amount,
                    0
                )

            markDebtAsCNY(
                card
            )

            return true


        case .expense,
             .income,
             .transfer,
             .adjustment:

            guard let source =
                findAccount(
                    transaction.accountID,
                    accounts:
                        accounts
                )
            else {
                return false
            }

            switch transaction.type {

            case .expense:

                source.balance -=
                    sourceAccountAmount

            case .income:

                source.balance +=
                    sourceAccountAmount

            case .transfer:

                guard
                    let targetID =
                        transaction.targetAccountID,
                    targetID !=
                        transaction.accountID,
                    let target =
                        findAccount(
                            targetID,
                            accounts:
                                accounts
                        )
                else {
                    return false
                }

                source.balance -=
                    sourceAccountAmount

                target.balance +=
                    targetAccountAmount

            case .adjustment:

                source.balance +=
                    transaction.amount

            case .creditExpense,
                 .creditRepayment:

                break
            }

            return true
        }
    }


    // MARK: - 撤销流水

    @discardableResult
    static func revert(
        _ transaction:
            TransactionRecord,
        accounts: [Account],
        cards: [BankCard] = []
    ) -> Bool {

        let amount =
            abs(
                transaction.amount
            )

        let sourceAccountAmount =
            abs(
                transaction.accountAmount ??
                amount
            )

        let targetAccountAmount =
            abs(
                transaction.targetAccountAmount ??
                amount
            )

        switch transaction.type {

        case .creditExpense:

            guard
                let cardID =
                    transaction.bankCardID,
                let card =
                    findCard(
                        cardID,
                        cards:
                            cards
                    ),
                card.cardType ==
                    .credit
            else {
                return false
            }

            let currentDebt =
                max(
                    card.currentDebt ?? 0,
                    0
                )

            guard currentDebt + 0.0001 >=
                    amount
            else {
                return false
            }

            card.currentDebt =
                max(
                    currentDebt - amount,
                    0
                )

            markDebtAsCNY(
                card
            )

            return true


        case .creditRepayment:

            guard
                let cardID =
                    transaction.bankCardID,
                let card =
                    findCard(
                        cardID,
                        cards:
                            cards
                    ),
                card.cardType ==
                    .credit,
                let source =
                    findAccount(
                        transaction.accountID,
                        accounts:
                            accounts
                    )
            else {
                return false
            }

            source.balance +=
                sourceAccountAmount

            card.currentDebt =
                max(
                    card.currentDebt ?? 0,
                    0
                ) +
                amount

            markDebtAsCNY(
                card
            )

            return true


        case .expense,
             .income,
             .transfer,
             .adjustment:

            guard let source =
                findAccount(
                    transaction.accountID,
                    accounts:
                        accounts
                )
            else {
                return false
            }

            switch transaction.type {

            case .expense:

                source.balance +=
                    sourceAccountAmount

            case .income:

                source.balance -=
                    sourceAccountAmount

            case .transfer:

                guard
                    let targetID =
                        transaction.targetAccountID,
                    let target =
                        findAccount(
                            targetID,
                            accounts:
                                accounts
                        )
                else {
                    return false
                }

                source.balance +=
                    sourceAccountAmount

                target.balance -=
                    targetAccountAmount

            case .adjustment:

                source.balance -=
                    transaction.amount

            case .creditExpense,
                 .creditRepayment:

                break
            }

            return true
        }
    }


    // MARK: - 查询

    static func findAccount(
        _ id: UUID,
        accounts: [Account]
    ) -> Account? {

        accounts.first {
            $0.id == id
        }
    }


    static func findCard(
        _ id: UUID,
        cards: [BankCard]
    ) -> BankCard? {

        cards.first {
            $0.id == id
        }
    }


    static func hasTransactions(
        accountID: UUID,
        transactions:
            [TransactionRecord]
    ) -> Bool {

        transactions.contains {

            $0.accountID ==
                accountID ||

            $0.targetAccountID ==
                accountID
        }
    }


    // MARK: - Snapshot

    private struct TransactionSnapshot {

        let typeRaw: String

        let amount: Double

        let originalAmount: Double?

        let currencyCodeRaw: String?

        let exchangeRateToCNY: Double?

        let accountAmount: Double?

        let targetAccountAmount: Double?

        let category: String

        let accountID: UUID

        let targetAccountID:
            UUID?

        let bankCardID:
            UUID?

        let note: String

        let date: Date


        init(
            transaction:
                TransactionRecord
        ) {

            typeRaw =
                transaction.typeRaw

            amount =
                transaction.amount

            originalAmount =
                transaction.originalAmount

            currencyCodeRaw =
                transaction.currencyCodeRaw

            exchangeRateToCNY =
                transaction.exchangeRateToCNY

            accountAmount =
                transaction.accountAmount

            targetAccountAmount =
                transaction.targetAccountAmount

            category =
                transaction.category

            accountID =
                transaction.accountID

            targetAccountID =
                transaction.targetAccountID

            bankCardID =
                transaction.bankCardID

            note =
                transaction.note

            date =
                transaction.date
        }
    }


    private static func restore(
        _ transaction:
            TransactionRecord,
        snapshot:
            TransactionSnapshot
    ) {

        transaction.typeRaw =
            snapshot.typeRaw

        transaction.amount =
            snapshot.amount

        transaction.originalAmount =
            snapshot.originalAmount

        transaction.currencyCodeRaw =
            snapshot.currencyCodeRaw

        transaction.exchangeRateToCNY =
            snapshot.exchangeRateToCNY

        transaction.accountAmount =
            snapshot.accountAmount

        transaction.targetAccountAmount =
            snapshot.targetAccountAmount

        transaction.category =
            snapshot.category

        transaction.accountID =
            snapshot.accountID

        transaction.targetAccountID =
            snapshot.targetAccountID

        transaction.bankCardID =
            snapshot.bankCardID

        transaction.note =
            snapshot.note

        transaction.date =
            snapshot.date
    }

    private static func markDebtAsCNY(
        _ card:
            BankCard
    ) {

        guard
            let debt =
                card.currentDebt
        else {

            card.currentDebtOriginalAmount =
                nil

            card.currentDebtCurrencyCodeRaw =
                nil

            card.currentDebtExchangeRateToCNY =
                nil

            return
        }


        card.currentDebtOriginalAmount =
            debt

        card.currentDebtCurrencyCodeRaw =
            "CNY"

        card.currentDebtExchangeRateToCNY =
            1
    }

}
