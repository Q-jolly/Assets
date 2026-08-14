import Foundation
import SwiftData

enum AccountType: String, CaseIterable, Identifiable {
    case cash = "现金"
    case bank = "银行卡"
    case wechat = "微信"
    case alipay = "支付宝"
    case other = "其他"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .cash:
            return "banknote"
        case .bank:
            return "creditcard"
        case .wechat:
            return "message.fill"
        case .alipay:
            return "a.circle.fill"
        case .other:
            return "wallet.pass"
        }
    }
}

enum TransactionType: String, CaseIterable, Identifiable {
    case expense = "支出"
    case income = "收入"
    case transfer = "转账"

    var id: String { rawValue }
}

@Model
final class Account {
    var id: UUID
    var name: String
    var typeRaw: String
    var balance: Double
    var createdAt: Date

    init(
        name: String,
        type: AccountType,
        balance: Double = 0
    ) {
        self.id = UUID()
        self.name = name
        self.typeRaw = type.rawValue
        self.balance = balance
        self.createdAt = Date()
    }

    var type: AccountType {
        AccountType(rawValue: typeRaw) ?? .other
    }
}

@Model
final class TransactionRecord {
    var id: UUID
    var typeRaw: String
    var amount: Double
    var category: String
    var accountID: UUID
    var targetAccountID: UUID?
    var note: String
    var date: Date

    init(
        type: TransactionType,
        amount: Double,
        category: String,
        accountID: UUID,
        targetAccountID: UUID? = nil,
        note: String = "",
        date: Date = Date()
    ) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.amount = amount
        self.category = category
        self.accountID = accountID
        self.targetAccountID = targetAccountID
        self.note = note
        self.date = date
    }

    var type: TransactionType {
        TransactionType(rawValue: typeRaw) ?? .expense
    }
}