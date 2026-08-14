import Foundation
import SwiftData

enum AccountType: String, CaseIterable, Identifiable {
    case cash = "现金"
    case bank = "银行卡"
    case wechat = "微信"
    case alipay = "支付宝"
    case other = "其他"

    var id: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .cash:
            return "banknote.fill"

        case .bank:
            return "creditcard.fill"

        case .wechat:
            return "message.fill"

        case .alipay:
            return "a.circle.fill"

        case .other:
            return "wallet.pass.fill"
        }
    }
}


enum TransactionType: String, CaseIterable, Identifiable {
    case expense = "支出"
    case income = "收入"
    case transfer = "转账"

    // 系统内部使用
    case adjustment = "余额调整"

    var id: String {
        rawValue
    }

    static var userSelectableCases: [TransactionType] {
        [
            .expense,
            .income,
            .transfer
        ]
    }

    var icon: String {
        switch self {
        case .expense:
            return "arrow.up.right"

        case .income:
            return "arrow.down.left"

        case .transfer:
            return "arrow.left.arrow.right"

        case .adjustment:
            return "arrow.triangle.2.circlepath"
        }
    }
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
        AccountType(
            rawValue: typeRaw
        ) ?? .other
    }
}


@Model
final class TransactionRecord {

    var id: UUID

    var typeRaw: String

    /*
     普通支出 / 收入 / 转账：
     amount 永远为正数

     余额调整：
     amount 可以为正或负
     */
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

        if type == .adjustment {
            self.amount = amount
        } else {
            self.amount = abs(amount)
        }

        self.category = category
        self.accountID = accountID
        self.targetAccountID = targetAccountID
        self.note = note
        self.date = date
    }

    var type: TransactionType {
        TransactionType(
            rawValue: typeRaw
        ) ?? .expense
    }
}