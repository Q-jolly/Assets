import Foundation
import SwiftData


// MARK: - 账户类型

enum AccountType:
    String,
    CaseIterable,
    Identifiable {

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


// MARK: - 流水类型

enum TransactionType:
    String,
    CaseIterable,
    Identifiable {

    case expense = "支出"
    case income = "收入"
    case transfer = "转账"

    // 系统内部使用
    case adjustment = "余额调整"

    var id: String {
        rawValue
    }

    static var userSelectableCases:
        [TransactionType] {

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


// MARK: - 卡片类型

enum BankCardType:
    String,
    CaseIterable,
    Identifiable {

    case debit = "储蓄卡"
    case credit = "信用卡"

    var id: String {
        rawValue
    }

    var icon: String {

        switch self {

        case .debit:
            return "creditcard"

        case .credit:
            return "creditcard.fill"
        }
    }
}


// MARK: - 卡面主题

enum CardTheme:
    String,
    CaseIterable,
    Identifiable {

    case midnight = "曜石黑"
    case ocean = "深海蓝"
    case forest = "森林绿"
    case violet = "星云紫"
    case graphite = "石墨灰"
    case sunrise = "晨曦橙"

    var id: String {
        rawValue
    }
}


// MARK: - Account

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

        self.typeRaw =
            type.rawValue

        self.balance =
            balance

        self.createdAt =
            Date()
    }

    var type: AccountType {

        AccountType(
            rawValue:
                typeRaw
        ) ?? .other
    }
}


// MARK: - Transaction

@Model
final class TransactionRecord {

    var id: UUID

    var typeRaw: String

    /*
     普通支出 / 收入 / 转账：
     amount 永远为正数

     余额调整：
     amount 可以为正数或负数
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

        self.typeRaw =
            type.rawValue

        if type == .adjustment {

            self.amount =
                amount

        } else {

            self.amount =
                abs(amount)
        }

        self.category =
            category

        self.accountID =
            accountID

        self.targetAccountID =
            targetAccountID

        self.note =
            note

        self.date =
            date
    }

    var type: TransactionType {

        TransactionType(
            rawValue:
                typeRaw
        ) ?? .expense
    }
}


// MARK: - BankCard

@Model
final class BankCard {

    var id: UUID

    var bankName: String

    var cardTypeRaw: String

    /*
     当前阶段不保存完整银行卡号，
     只保存后四位。
     */
    var lastFourDigits: String

    var holderName: String

    /*
     可选关联 Account。
     例如：

     工商银行卡卡片
          ↓
     工商银行资产账户
     */
    var accountID: UUID?

    var themeRaw: String

    /*
     信用卡扩展信息。
     储蓄卡保持 nil。

     目前先作为卡片管理数据使用，
     V0.3 再与“负债 / 净资产”正式联动。
     */
    var creditLimit: Double?

    var currentDebt: Double?

    var billingDay: Int?

    var repaymentDay: Int?

    /*
     排序用。
     */
    var sortOrder: Int

    var createdAt: Date

    init(
        bankName: String,
        cardType: BankCardType,
        lastFourDigits: String,
        holderName: String,
        accountID: UUID? = nil,
        theme: CardTheme = .midnight,
        creditLimit: Double? = nil,
        currentDebt: Double? = nil,
        billingDay: Int? = nil,
        repaymentDay: Int? = nil,
        sortOrder: Int = 0
    ) {

        self.id =
            UUID()

        self.bankName =
            bankName

        self.cardTypeRaw =
            cardType.rawValue

        self.lastFourDigits =
            lastFourDigits

        self.holderName =
            holderName

        self.accountID =
            accountID

        self.themeRaw =
            theme.rawValue

        if cardType == .credit {

            self.creditLimit =
                creditLimit

            self.currentDebt =
                currentDebt

            self.billingDay =
                billingDay

            self.repaymentDay =
                repaymentDay

        } else {

            self.creditLimit =
                nil

            self.currentDebt =
                nil

            self.billingDay =
                nil

            self.repaymentDay =
                nil
        }

        self.sortOrder =
            sortOrder

        self.createdAt =
            Date()
    }


    var cardType: BankCardType {

        BankCardType(
            rawValue:
                cardTypeRaw
        ) ?? .debit
    }


    var theme: CardTheme {

        CardTheme(
            rawValue:
                themeRaw
        ) ?? .midnight
    }


    var availableCredit: Double? {

        guard
            cardType == .credit,
            let creditLimit
        else {
            return nil
        }

        return max(
            creditLimit - (currentDebt ?? 0),
            0
        )
    }
}
