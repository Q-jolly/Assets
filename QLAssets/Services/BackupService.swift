import Foundation
import SwiftData
import UniformTypeIdentifiers
import SwiftUI


struct QLAssetsBackup:
    Codable {

    let version:
        Int

    let exportedAt:
        Date

    let monthlyBudget:
        Double

    let expenseCategoriesStored:
        String?

    let incomeCategoriesStored:
        String?

    let accounts:
        [BackupAccount]

    let transactions:
        [BackupTransaction]

    let cards:
        [BackupBankCard]
}


struct BackupAccount:
    Codable {

    let id:
        UUID

    let name:
        String

    let typeRaw:
        String

    let balance:
        Double

    let createdAt:
        Date
}


struct BackupTransaction:
    Codable {

    let id:
        UUID

    let typeRaw:
        String

    let amount:
        Double

    let category:
        String

    let accountID:
        UUID

    let targetAccountID:
        UUID?

    let bankCardID:
        UUID?

    let note:
        String

    let date:
        Date
}


struct BackupBankCard:
    Codable {

    let id:
        UUID

    let bankName:
        String

    let cardTypeRaw:
        String

    let lastFourDigits:
        String

    let holderName:
        String

    let accountID:
        UUID?

    let themeRaw:
        String

    let creditLimit:
        Double?

    let currentDebt:
        Double?

    let billingDay:
        Int?

    let repaymentDay:
        Int?

    let sortOrder:
        Int

    let createdAt:
        Date

    let faceImageData:
        Data?
}


enum BackupRestoreError:
    LocalizedError {

    case unsupportedVersion

    case invalidAccountType

    case invalidCardType

    case invalidTheme

    case invalidTransactionType


    var errorDescription:
        String? {

        switch self {

        case .unsupportedVersion:

            return
                "备份文件版本暂不支持"

        case .invalidAccountType:

            return
                "备份中存在无法识别的账户类型"

        case .invalidCardType:

            return
                "备份中存在无法识别的银行卡类型"

        case .invalidTheme:

            return
                "备份中存在无法识别的卡面主题"

        case .invalidTransactionType:

            return
                "备份中存在无法识别的账单类型"
        }
    }
}


enum BackupService {

    static let currentVersion =
        2


    static func makeBackup(
        accounts:
            [Account],
        transactions:
            [TransactionRecord],
        cards:
            [BankCard]
    ) throws -> Data {

        let backup =
            QLAssetsBackup(
                version:
                    currentVersion,
                exportedAt:
                    Date(),
                monthlyBudget:
                    UserDefaults.standard
                        .double(
                            forKey:
                                "monthlyBudgetCNY"
                        ),
                expenseCategoriesStored:
                    UserDefaults.standard
                        .string(
                            forKey:
                                CategoryStore
                                    .expenseKey
                        ),
                incomeCategoriesStored:
                    UserDefaults.standard
                        .string(
                            forKey:
                                CategoryStore
                                    .incomeKey
                        ),
                accounts:
                    accounts.map {
                        BackupAccount(
                            id:
                                $0.id,
                            name:
                                $0.name,
                            typeRaw:
                                $0.typeRaw,
                            balance:
                                $0.balance,
                            createdAt:
                                $0.createdAt
                        )
                    },
                transactions:
                    transactions.map {
                        BackupTransaction(
                            id:
                                $0.id,
                            typeRaw:
                                $0.typeRaw,
                            amount:
                                $0.amount,
                            category:
                                $0.category,
                            accountID:
                                $0.accountID,
                            targetAccountID:
                                $0.targetAccountID,
                            bankCardID:
                                $0.bankCardID,
                            note:
                                $0.note,
                            date:
                                $0.date
                        )
                    },
                cards:
                    cards.map {
                        BackupBankCard(
                            id:
                                $0.id,
                            bankName:
                                $0.bankName,
                            cardTypeRaw:
                                $0.cardTypeRaw,
                            lastFourDigits:
                                $0.lastFourDigits,
                            holderName:
                                $0.holderName,
                            accountID:
                                $0.accountID,
                            themeRaw:
                                $0.themeRaw,
                            creditLimit:
                                $0.creditLimit,
                            currentDebt:
                                $0.currentDebt,
                            billingDay:
                                $0.billingDay,
                            repaymentDay:
                                $0.repaymentDay,
                            sortOrder:
                                $0.sortOrder,
                            createdAt:
                                $0.createdAt,
                            faceImageData:
                                CardFaceImageStore
                                    .imageData(
                                        for:
                                            $0.id
                                    )
                        )
                    }
            )


        let encoder =
            JSONEncoder()

        encoder.outputFormatting =
            [
                .prettyPrinted,
                .sortedKeys
            ]

        encoder.dateEncodingStrategy =
            .iso8601


        return try encoder
            .encode(
                backup
            )
    }


    static func decodeBackup(
        _ data:
            Data
    ) throws -> QLAssetsBackup {

        let decoder =
            JSONDecoder()

        decoder.dateDecodingStrategy =
            .iso8601


        let backup =
            try decoder
                .decode(
                    QLAssetsBackup.self,
                    from:
                        data
                )


        guard backup.version <=
                currentVersion
        else {

            throw BackupRestoreError
                .unsupportedVersion
        }


        return backup
    }


    static func restore(
        _ backup:
            QLAssetsBackup,
        existingAccounts:
            [Account],
        existingTransactions:
            [TransactionRecord],
        existingCards:
            [BankCard],
        context:
            ModelContext
    ) throws {

        // 先校验所有枚举，确保不会删掉现有数据后才发现备份无效。
        for account in
            backup.accounts {

            guard AccountType(
                rawValue:
                    account.typeRaw
            ) != nil
            else {

                throw BackupRestoreError
                    .invalidAccountType
            }
        }


        for transaction in
            backup.transactions {

            guard TransactionType(
                rawValue:
                    transaction.typeRaw
            ) != nil
            else {

                throw BackupRestoreError
                    .invalidTransactionType
            }
        }


        for card in
            backup.cards {

            guard BankCardType(
                rawValue:
                    card.cardTypeRaw
            ) != nil
            else {

                throw BackupRestoreError
                    .invalidCardType
            }


            guard CardTheme(
                rawValue:
                    card.themeRaw
            ) != nil
            else {

                throw BackupRestoreError
                    .invalidTheme
            }
        }


        // 先清理现有本地卡面。
        for card in
            existingCards {

            CardFaceImageStore
                .delete(
                    for:
                        card.id
                )
        }


        // SwiftData 中先删流水，再删银行卡和账户。
        for transaction in
            existingTransactions {

            context.delete(
                transaction
            )
        }


        for card in
            existingCards {

            context.delete(
                card
            )
        }


        for account in
            existingAccounts {

            context.delete(
                account
            )
        }


        try context.save()


        // 恢复账户。
        for item in
            backup.accounts {

            guard
                let type =
                    AccountType(
                        rawValue:
                            item.typeRaw
                    )
            else {

                continue
            }


            let account =
                Account(
                    name:
                        item.name,
                    type:
                        type,
                    balance:
                        item.balance
                )

            account.id =
                item.id

            account.createdAt =
                item.createdAt

            context.insert(
                account
            )
        }


        // 恢复银行卡。
        for item in
            backup.cards {

            guard
                let cardType =
                    BankCardType(
                        rawValue:
                            item.cardTypeRaw
                    ),
                let theme =
                    CardTheme(
                        rawValue:
                            item.themeRaw
                    )
            else {

                continue
            }


            let card =
                BankCard(
                    bankName:
                        item.bankName,
                    cardType:
                        cardType,
                    lastFourDigits:
                        item.lastFourDigits,
                    holderName:
                        item.holderName,
                    accountID:
                        item.accountID,
                    theme:
                        theme,
                    creditLimit:
                        item.creditLimit,
                    currentDebt:
                        item.currentDebt,
                    billingDay:
                        item.billingDay,
                    repaymentDay:
                        item.repaymentDay,
                    sortOrder:
                        item.sortOrder
                )

            card.id =
                item.id

            card.createdAt =
                item.createdAt

            context.insert(
                card
            )
        }


        // 恢复流水。这里直接恢复已保存的账户余额/信用卡欠款，
        // 不再执行 TransactionService.apply，避免重复计算。
        for item in
            backup.transactions {

            guard
                let type =
                    TransactionType(
                        rawValue:
                            item.typeRaw
                    )
            else {

                continue
            }


            let transaction =
                TransactionRecord(
                    type:
                        type,
                    amount:
                        item.amount,
                    category:
                        item.category,
                    accountID:
                        item.accountID,
                    targetAccountID:
                        item.targetAccountID,
                    bankCardID:
                        item.bankCardID,
                    note:
                        item.note,
                    date:
                        item.date
                )

            transaction.id =
                item.id

            context.insert(
                transaction
            )
        }


        try context.save()


        // 卡面文件最后恢复。
        for item in
            backup.cards {

            guard
                let data =
                    item.faceImageData
            else {

                continue
            }


            try CardFaceImageStore
                .save(
                    imageData:
                        data,
                    for:
                        item.id
                )
        }


        UserDefaults.standard
            .set(
                backup.monthlyBudget,
                forKey:
                    "monthlyBudgetCNY"
            )


        if let expense =
            backup
                .expenseCategoriesStored {

            UserDefaults.standard
                .set(
                    expense,
                    forKey:
                        CategoryStore
                            .expenseKey
                )
        }


        if let income =
            backup
                .incomeCategoriesStored {

            UserDefaults.standard
                .set(
                    income,
                    forKey:
                        CategoryStore
                            .incomeKey
                )
        }
    }
}


// MARK: - FileDocument

struct QLAssetsBackupDocument:
    FileDocument {

    static var readableContentTypes:
        [UTType] {

        [
            UTType(
                exportedAs:
                    "com.qiaolei.qlassets.backup",
                conformingTo:
                    .json
            ),
            .json
        ]
    }


    var data:
        Data


    init(
        data:
            Data = Data()
    ) {

        self.data =
            data
    }


    init(
        configuration:
            ReadConfiguration
    ) throws {

        guard
            let data =
                configuration
                    .file
                    .regularFileContents
        else {

            throw CocoaError(
                .fileReadCorruptFile
            )
        }

        self.data =
            data
    }


    func fileWrapper(
        configuration:
            WriteConfiguration
    ) throws -> FileWrapper {

        FileWrapper(
            regularFileWithContents:
                data
        )
    }
}
