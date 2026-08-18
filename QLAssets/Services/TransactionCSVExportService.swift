import Foundation
import SwiftUI
import UniformTypeIdentifiers


struct TransactionCSVDocument:
    FileDocument {

    static var readableContentTypes:
        [UTType] {

        [
            UTType(
                filenameExtension:
                    "csv"
            )
            ?? .plainText
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

        self.data =
            configuration
                .file
                .regularFileContents
            ?? Data()
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


enum TransactionCSVExportService {

    static func makeCSV(
        transactions:
            [TransactionRecord],
        accounts:
            [Account],
        cards:
            [BankCard]
    ) -> Data {

        let accountNames =
            Dictionary(
                uniqueKeysWithValues:
                    accounts.map {
                        (
                            $0.id,
                            $0.name
                        )
                    }
            )


        let cardNames =
            Dictionary(
                uniqueKeysWithValues:
                    cards.map {
                        (
                            $0.id,
                            "\($0.bankName) •••• \($0.lastFourDigits)"
                        )
                    }
            )


        var rows:
            [String] = [

                [
                    "日期",
                    "类型",
                    "分类",
                    "金额",
                    "账户",
                    "目标账户",
                    "信用卡",
                    "备注"
                ]
                .map(
                    csvEscaped
                )
                .joined(
                    separator:
                        ","
                )
            ]


        let formatter =
            DateFormatter()

        formatter.calendar =
            AppTime.calendar

        formatter.timeZone =
            AppTime.timeZone

        formatter.locale =
            Locale(
                identifier:
                    "zh_CN"
            )

        formatter.dateFormat =
            "yyyy-MM-dd HH:mm:ss"


        for transaction in
            transactions.sorted(
                by: {
                    $0.date >
                    $1.date
                }
            ) {

            let account =
                accountNames[
                    transaction.accountID
                ]
                ?? "未知账户"


            let targetAccount =
                transaction
                    .targetAccountID
                    .flatMap {
                        accountNames[
                            $0
                        ]
                    }
                ?? ""


            let card =
                transaction
                    .bankCardID
                    .flatMap {
                        cardNames[
                            $0
                        ]
                    }
                ?? ""


            let row =
                [
                    formatter.string(
                        from:
                            transaction.date
                    ),
                    transaction
                        .type
                        .rawValue,
                    transaction.category,
                    amountText(
                        transaction
                    ),
                    account,
                    targetAccount,
                    card,
                    transaction.note
                ]
                .map(
                    csvEscaped
                )
                .joined(
                    separator:
                        ","
                )


            rows.append(
                row
            )
        }


        // Excel 在 Windows 上打开 UTF-8 CSV 时，
        // 加 BOM 可以避免中文乱码。
        let csv =
            "\u{FEFF}" +
            rows.joined(
                separator:
                    "\r\n"
            )


        return csv.data(
            using:
                .utf8
        )
        ?? Data()
    }


    private static func amountText(
        _ transaction:
            TransactionRecord
    ) -> String {

        let amount =
            abs(
                transaction.amount
            )


        let signedAmount:
            Double


        switch transaction.type {

        case .income:

            signedAmount =
                amount

        case .expense,
             .creditExpense:

            signedAmount =
                -amount

        case .adjustment:

            signedAmount =
                transaction.amount

        case .transfer,
             .creditRepayment:

            // 转账和信用卡还款不是收入/支出；
            // CSV 保留正金额并用“类型”字段区分。
            signedAmount =
                amount
        }


        return String(
            format:
                "%.2f",
            signedAmount
        )
    }


    private static func csvEscaped(
        _ value:
            String
    ) -> String {

        let escaped =
            value.replacingOccurrences(
                of:
                    "\"",
                with:
                    "\"\""
            )


        if escaped.contains(
            ","
        ) ||
           escaped.contains(
            "\""
        ) ||
           escaped.contains(
            "\n"
        ) ||
           escaped.contains(
            "\r"
        ) {

            return
                "\"\(escaped)\""
        }


        return escaped
    }
}
