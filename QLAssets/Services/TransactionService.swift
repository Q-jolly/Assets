import Foundation
import SwiftData


enum TransactionService {

    // MARK: - 创建流水

    @discardableResult
    static func create(
        type: TransactionType,
        amount: Double,
        category: String,
        accountID: UUID,
        targetAccountID: UUID? = nil,
        note: String,
        date: Date,
        accounts: [Account],
        context: ModelContext
    ) -> Bool {

        let normalizedAmount: Double

        if type == .adjustment {
            normalizedAmount = amount
        } else {
            normalizedAmount = abs(amount)
        }

        let record = TransactionRecord(
            type: type,
            amount: normalizedAmount,
            category: category,
            accountID: accountID,
            targetAccountID: targetAccountID,
            note: note,
            date: date
        )

        guard apply(
            record,
            accounts: accounts
        ) else {
            return false
        }

        context.insert(record)

        do {
            try context.save()
            return true

        } catch {

            revert(
                record,
                accounts: accounts
            )

            context.delete(record)

            return false
        }
    }


    // MARK: - 删除流水

    @discardableResult
    static func delete(
        _ transaction: TransactionRecord,
        accounts: [Account],
        context: ModelContext
    ) -> Bool {

        guard revert(
            transaction,
            accounts: accounts
        ) else {
            return false
        }

        context.delete(transaction)

        do {
            try context.save()
            return true

        } catch {

            // 尽量恢复余额
            apply(
                transaction,
                accounts: accounts
            )

            return false
        }
    }


    // MARK: - 修改流水

    @discardableResult
    static func update(
        _ transaction: TransactionRecord,
        type: TransactionType,
        amount: Double,
        category: String,
        accountID: UUID,
        targetAccountID: UUID?,
        note: String,
        date: Date,
        accounts: [Account],
        context: ModelContext
    ) -> Bool {

        let snapshot = TransactionSnapshot(
            transaction: transaction
        )

        // 先撤销旧流水
        guard revert(
            transaction,
            accounts: accounts
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

        transaction.category =
            category

        transaction.accountID =
            accountID

        transaction.targetAccountID =
            type == .transfer
            ? targetAccountID
            : nil

        transaction.note =
            note

        transaction.date =
            date

        // 再应用修改后的流水
        guard apply(
            transaction,
            accounts: accounts
        ) else {

            restore(
                transaction,
                snapshot: snapshot
            )

            apply(
                transaction,
                accounts: accounts
            )

            return false
        }

        do {
            try context.save()
            return true

        } catch {

            // 撤销修改后的影响
            revert(
                transaction,
                accounts: accounts
            )

            // 恢复旧数据
            restore(
                transaction,
                snapshot: snapshot
            )

            // 重新应用旧流水
            apply(
                transaction,
                accounts: accounts
            )

            return false
        }
    }


    // MARK: - 应用流水

    @discardableResult
    static func apply(
        _ transaction: TransactionRecord,
        accounts: [Account]
    ) -> Bool {

        guard let source =
            findAccount(
                transaction.accountID,
                accounts: accounts
            )
        else {
            return false
        }

        switch transaction.type {

        case .expense:

            source.balance -=
                abs(transaction.amount)

        case .income:

            source.balance +=
                abs(transaction.amount)

        case .transfer:

            guard
                let targetID =
                    transaction.targetAccountID,

                targetID !=
                    transaction.accountID,

                let target =
                    findAccount(
                        targetID,
                        accounts: accounts
                    )
            else {
                return false
            }

            source.balance -=
                abs(transaction.amount)

            target.balance +=
                abs(transaction.amount)

        case .adjustment:

            source.balance +=
                transaction.amount
        }

        return true
    }


    // MARK: - 撤销流水

    @discardableResult
    static func revert(
        _ transaction: TransactionRecord,
        accounts: [Account]
    ) -> Bool {

        guard let source =
            findAccount(
                transaction.accountID,
                accounts: accounts
            )
        else {
            return false
        }

        switch transaction.type {

        case .expense:

            source.balance +=
                abs(transaction.amount)

        case .income:

            source.balance -=
                abs(transaction.amount)

        case .transfer:

            guard
                let targetID =
                    transaction.targetAccountID,

                let target =
                    findAccount(
                        targetID,
                        accounts: accounts
                    )
            else {
                return false
            }

            source.balance +=
                abs(transaction.amount)

            target.balance -=
                abs(transaction.amount)

        case .adjustment:

            source.balance -=
                transaction.amount
        }

        return true
    }


    // MARK: - 查询账户

    static func findAccount(
        _ id: UUID,
        accounts: [Account]
    ) -> Account? {

        accounts.first {
            $0.id == id
        }
    }


    // MARK: - 判断账户是否存在流水

    static func hasTransactions(
        accountID: UUID,
        transactions: [TransactionRecord]
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

        let category: String

        let accountID: UUID

        let targetAccountID: UUID?

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

            category =
                transaction.category

            accountID =
                transaction.accountID

            targetAccountID =
                transaction.targetAccountID

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

        transaction.category =
            snapshot.category

        transaction.accountID =
            snapshot.accountID

        transaction.targetAccountID =
            snapshot.targetAccountID

        transaction.note =
            snapshot.note

        transaction.date =
            snapshot.date
    }
}