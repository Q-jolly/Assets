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
    case creditExpense = "信用卡消费"
    case creditRepayment = "信用卡还款"

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
            .transfer,
            .creditExpense,
            .creditRepayment
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

        case .creditExpense:
            return "creditcard.fill"

        case .creditRepayment:
            return "arrow.down.to.line.compact"

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

    // 账户余额始终以账户本身币种记录。
    // 旧账户 currencyCodeRaw 为 nil 时按 CNY 处理。
    var balance: Double

    var currencyCodeRaw: String?

    // 最近一次成功联网获取到的人民币估值汇率。
    // 仅用于离线兜底，不参与历史交易汇率回写。
    var lastKnownRateToCNY: Double?

    var createdAt: Date

    init(
        name: String,
        type: AccountType,
        balance: Double = 0,
        currencyCode: String = "CNY",
        lastKnownRateToCNY: Double? = nil
    ) {

        self.id = UUID()

        self.name = name

        self.typeRaw =
            type.rawValue

        self.balance =
            balance

        self.currencyCodeRaw =
            currencyCode.uppercased()

        self.lastKnownRateToCNY =
            currencyCode.uppercased() == "CNY"
            ? 1
            : lastKnownRateToCNY

        self.createdAt =
            Date()
    }

    var currencyCode: String {

        let value =
            currencyCodeRaw?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .uppercased()

        return
            value?.isEmpty == false
            ? value!
            : "CNY"
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
    // 人民币等值金额，用于统计、负债和净资产口径。
    var amount: Double

    // 外币原始金额/币种/记账时汇率。旧数据保持 nil，等价于 CNY。
    var originalAmount: Double?

    var currencyCodeRaw: String?

    var exchangeRateToCNY: Double?

    // 实际作用到账户余额的本币金额。
    // 例如 USD 10 记入美元账户时 accountAmount = 10；
    // 同一笔记入人民币账户时 accountAmount = 人民币等值。
    var accountAmount: Double?

    var targetAccountAmount: Double?

    var category: String

    var accountID: UUID

    var targetAccountID: UUID?

    /*
     信用卡消费 / 还款关联的 BankCard。
     普通账单保持 nil。
     */
    var bankCardID: UUID?

    var note: String

    var date: Date

    init(
        type: TransactionType,
        amount: Double,
        originalAmount: Double? = nil,
        currencyCode: String? = nil,
        exchangeRateToCNY: Double? = nil,
        accountAmount: Double? = nil,
        targetAccountAmount: Double? = nil,
        category: String,
        accountID: UUID,
        targetAccountID: UUID? = nil,
        bankCardID: UUID? = nil,
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

        self.originalAmount =
            originalAmount

        self.currencyCodeRaw =
            currencyCode?.uppercased()

        self.exchangeRateToCNY =
            exchangeRateToCNY

        self.accountAmount =
            accountAmount

        self.targetAccountAmount =
            targetAccountAmount

        self.category =
            CategoryNormalizer
                .normalized(
                    category
                )

        self.accountID =
            accountID

        self.targetAccountID =
            targetAccountID

        self.bankCardID =
            bankCardID

        self.note =
            note

        self.date =
            date
    }

    var currencyCode: String {

        let code =
            currencyCodeRaw?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .uppercased()

        return
            code?.isEmpty == false
            ? code!
            : "CNY"
    }


    var displayOriginalAmount: Double {

        originalAmount ??
        abs(amount)
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

    // 当前欠款的人民币等值，用于总负债、可用额度和统计口径。
    var currentDebt: Double?

    // 手动编辑欠款时保留用户输入的原币金额与记账汇率。
    // 自动产生新的信用卡消费/还款后，会重新归一为 CNY，
    // 避免多币种交易聚合后仍显示一份已经过期的原币金额。
    var currentDebtOriginalAmount: Double?

    var currentDebtCurrencyCodeRaw: String?

    var currentDebtExchangeRateToCNY: Double?

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
        currentDebtOriginalAmount: Double? = nil,
        currentDebtCurrencyCode: String? = nil,
        currentDebtExchangeRateToCNY: Double? = nil,
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

            let debtCode =
                currentDebtCurrencyCode?
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .uppercased()

            self.currentDebtCurrencyCodeRaw =
                debtCode?.isEmpty == false
                ? debtCode
                : (currentDebt == nil ? nil : "CNY")

            self.currentDebtOriginalAmount =
                currentDebtOriginalAmount ?? currentDebt

            self.currentDebtExchangeRateToCNY =
                self.currentDebtCurrencyCodeRaw == nil
                ? nil
                : (
                    self.currentDebtCurrencyCodeRaw == "CNY"
                    ? 1
                    : currentDebtExchangeRateToCNY
                )

            self.billingDay =
                billingDay

            self.repaymentDay =
                repaymentDay

        } else {

            self.creditLimit =
                nil

            self.currentDebt =
                nil

            self.currentDebtOriginalAmount =
                nil

            self.currentDebtCurrencyCodeRaw =
                nil

            self.currentDebtExchangeRateToCNY =
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


    var currentDebtCurrencyCode: String {

        let code =
            currentDebtCurrencyCodeRaw?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .uppercased()

        return
            code?.isEmpty == false
            ? code!
            : "CNY"
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
