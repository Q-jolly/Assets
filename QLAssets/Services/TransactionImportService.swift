import Foundation
import SwiftData


struct TransactionImportTable {

    let headers:
        [String]

    let rows:
        [[String]]

    let delimiter:
        Character
}


struct TransactionImportMapping:
    Equatable {

    var dateColumn:
        Int?

    var descriptionColumn:
        Int?

    var categoryColumn:
        Int?

    var amountColumn:
        Int?

    var typeColumn:
        Int?

    var accountColumn:
        Int?
}


struct TransactionImportPreviewRow:
    Identifiable {

    let id =
        UUID()

    let sourceRow:
        Int

    let date:
        Date

    let type:
        TransactionType

    let amount:
        Double

    let category:
        String

    let note:
        String

    let sourceAccountName:
        String?
}


struct TransactionImportParseResult {

    let rows:
        [TransactionImportPreviewRow]

    let skippedRows:
        Int

    let warnings:
        [String]
}


struct TransactionImportCommitResult {

    let importedCount:
        Int

    let duplicateCount:
        Int

    let failedCount:
        Int

    let createdExpenseCategories:
        [String]

    let createdIncomeCategories:
        [String]
}


enum TransactionImportError:
    LocalizedError {

    case cannotDecode

    case emptyFile

    case missingDateColumn

    case missingAmountColumn

    case noValidRows

    case cannotReadClipboard


    var errorDescription:
        String? {

        switch self {

        case .cannotDecode:

            return
                "无法读取文件文字编码，请确认是 CSV、TSV 或从 Numbers 复制的表格。"

        case .emptyFile:

            return
                "文件中没有可导入的数据。"

        case .missingDateColumn:

            return
                "请选择日期列。"

        case .missingAmountColumn:

            return
                "请选择金额列。"

        case .noValidRows:

            return
                "没有解析出可导入的账单，请检查列映射和日期、金额格式。"

        case .cannotReadClipboard:

            return
                "剪贴板中没有可识别的表格文字。"
        }
    }
}


enum TransactionImportService {

    // MARK: - 读取表格

    static func decodeText(
        data:
            Data
    ) throws -> String {

        let encodings:
            [String.Encoding] = [

                .utf8,
                .utf16,
                .utf16LittleEndian,
                .utf16BigEndian,
                .unicode
            ]


        for encoding in
            encodings {

            if let text =
                String(
                    data:
                        data,
                    encoding:
                        encoding
                ),
               !text
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .isEmpty {

                return text
            }
        }


        throw TransactionImportError
            .cannotDecode
    }


    static func parseTable(
        text:
            String
    ) throws
        -> TransactionImportTable {

        let normalized =
            text
                .replacingOccurrences(
                    of:
                        "\r\n",
                    with:
                        "\n"
                )
                .replacingOccurrences(
                    of:
                        "\r",
                    with:
                        "\n"
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        guard !normalized.isEmpty
        else {

            throw TransactionImportError
                .emptyFile
        }


        let delimiter =
            detectDelimiter(
                in:
                    normalized
            )


        let matrix =
            parseDelimitedText(
                normalized,
            delimiter:
                delimiter
            )
            .filter {
                row in

                row.contains {
                    !$0
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                        .isEmpty
                }
            }


        guard
            let first =
                matrix.first,
            !first.isEmpty
        else {

            throw TransactionImportError
                .emptyFile
        }


        let headers =
            first.enumerated()
                .map {
                    index,
                    value in

                    let cleaned =
                        cleanCell(
                            value
                        )

                    return
                        cleaned.isEmpty
                        ? "第 \(index + 1) 列"
                        : cleaned
                }


        let rows =
            Array(
                matrix.dropFirst()
            )
            .map {
                normalizeRow(
                    $0,
                    count:
                        headers.count
                )
            }


        return TransactionImportTable(
            headers:
                headers,
            rows:
                rows,
            delimiter:
                delimiter
        )
    }


    static func autoMapping(
        headers:
            [String]
    ) -> TransactionImportMapping {

        var mapping =
            TransactionImportMapping()


        for (
            index,
            header
        ) in headers
            .enumerated() {

            let key =
                normalizedHeader(
                    header
                )


            if mapping.dateColumn ==
                nil,
               matches(
                key,
                [
                    "日期",
                    "时间",
                    "交易日期",
                    "交易时间",
                    "记账日期",
                    "date",
                    "datetime",
                    "transactiondate"
                ]
               ) {

                mapping.dateColumn =
                    index

                continue
            }


            if mapping.descriptionColumn ==
                nil,
               matches(
                key,
                [
                    "描述",
                    "备注",
                    "摘要",
                    "项目",
                    "商户",
                    "说明",
                    "description",
                    "note",
                    "memo",
                    "merchant"
                ]
               ) {

                mapping.descriptionColumn =
                    index

                continue
            }


            if mapping.categoryColumn ==
                nil,
               matches(
                key,
                [
                    "分类",
                    "类别",
                    "收支分类",
                    "category",
                    "categories"
                ]
               ) {

                mapping.categoryColumn =
                    index

                continue
            }


            if mapping.amountColumn ==
                nil,
               matches(
                key,
                [
                    "实际金额",
                    "金额",
                    "收支金额",
                    "实际支出",
                    "支出金额",
                    "收入金额",
                    "actualamount",
                    "amount",
                    "actual"
                ]
               ) {

                mapping.amountColumn =
                    index

                continue
            }


            if mapping.typeColumn ==
                nil,
               matches(
                key,
                [
                    "类型",
                    "收支类型",
                    "交易类型",
                    "type",
                    "transactiontype"
                ]
               ) {

                mapping.typeColumn =
                    index

                continue
            }


            if mapping.accountColumn ==
                nil,
               matches(
                key,
                [
                    "账户",
                    "支付账户",
                    "付款账户",
                    "account",
                    "paymentaccount"
                ]
               ) {

                mapping.accountColumn =
                    index
            }
        }


        return mapping
    }


    // MARK: - 解析账单

    static func makePreview(
        table:
            TransactionImportTable,
        mapping:
            TransactionImportMapping,
        fallbackYear:
            Int
    ) throws
        -> TransactionImportParseResult {

        guard
            let dateColumn =
                mapping.dateColumn
        else {

            throw TransactionImportError
                .missingDateColumn
        }


        guard
            let amountColumn =
                mapping.amountColumn
        else {

            throw TransactionImportError
                .missingAmountColumn
        }


        var previewRows:
            [TransactionImportPreviewRow] = []

        var skipped =
            0

        var warnings:
            [String] = []


        for (
            rowIndex,
            row
        ) in table.rows
            .enumerated() {

            let sourceRow =
                rowIndex +
                2


            guard
                let dateText =
                    value(
                        row,
                        at:
                            dateColumn
                    ),
                let date =
                    parseDate(
                        dateText,
                        fallbackYear:
                            fallbackYear
                    )
            else {

                skipped +=
                    1

                continue
            }


            guard
                let amountText =
                    value(
                        row,
                        at:
                            amountColumn
                    ),
                let signedAmount =
                    parseAmount(
                        amountText
                    ),
                abs(
                    signedAmount
                ) >
                    0.000_001
            else {

                skipped +=
                    1

                continue
            }


            let typeText =
                mapping
                    .typeColumn
                    .flatMap {
                        value(
                            row,
                            at:
                                $0
                        )
                    }
                ?? ""


            let inferredType =
                inferType(
                    typeText:
                        typeText,
                    amountHeader:
                        table.headers[
                            amountColumn
                        ],
                    signedAmount:
                        signedAmount
                )


            let category =
                mapping
                    .categoryColumn
                    .flatMap {
                        value(
                            row,
                            at:
                                $0
                        )
                    }
                    .map(
                        cleanCell
                    )
                    .flatMap {
                        $0.isEmpty
                        ? nil
                        : $0
                    }
                ?? defaultCategory(
                    for:
                        inferredType
                )


            let note =
                mapping
                    .descriptionColumn
                    .flatMap {
                        value(
                            row,
                            at:
                                $0
                        )
                    }
                    .map(
                        cleanCell
                    )
                ?? ""


            let sourceAccountName =
                mapping
                    .accountColumn
                    .flatMap {
                        value(
                            row,
                            at:
                                $0
                        )
                    }
                    .map(
                        cleanCell
                    )
                    .flatMap {
                        $0.isEmpty
                        ? nil
                        : $0
                    }


            previewRows.append(
                TransactionImportPreviewRow(
                    sourceRow:
                        sourceRow,
                    date:
                        date,
                    type:
                        inferredType,
                    amount:
                        abs(
                            signedAmount
                        ),
                    category:
                        category,
                    note:
                        note,
                    sourceAccountName:
                        sourceAccountName
                )
            )
        }


        if skipped >
            0 {

            warnings.append(
                "有 \(skipped) 行因日期或金额无法识别而跳过。"
            )
        }


        guard !previewRows.isEmpty
        else {

            throw TransactionImportError
                .noValidRows
        }


        return TransactionImportParseResult(
            rows:
                previewRows,
            skippedRows:
                skipped,
            warnings:
                warnings
        )
    }


    // MARK: - 提交导入

    @MainActor
    static func commit(
        previewRows:
            [TransactionImportPreviewRow],
        defaultAccountID:
            UUID?,
        useSourceAccountNames:
            Bool,
        affectAccountBalance:
            Bool,
        skipDuplicates:
            Bool,
        accounts:
            [Account],
        cards:
            [BankCard],
        existingTransactions:
            [TransactionRecord],
        context:
            ModelContext
    ) -> TransactionImportCommitResult {

        var imported =
            0

        var duplicates =
            0

        var failed =
            0


        var fingerprints =
            Set(
                existingTransactions.map {
                    fingerprint(
                        type:
                            $0.type,
                        amount:
                            abs(
                                $0.amount
                            ),
                        category:
                            $0.category,
                        note:
                            $0.note,
                        date:
                            $0.date,
                        accountID:
                            $0.accountID
                    )
                }
            )


        let accountByName =
            Dictionary(
                uniqueKeysWithValues:
                    accounts.map {
                        (
                            normalizedAccountName(
                                $0.name
                            ),
                            $0.id
                        )
                    }
            )


        var importedExpenseCategories =
            Set<String>()

        var importedIncomeCategories =
            Set<String>()


        for row in
            previewRows {

            var resolvedAccountID =
                defaultAccountID


            if useSourceAccountNames,
               let sourceAccount =
                row.sourceAccountName {

                resolvedAccountID =
                    accountByName[
                        normalizedAccountName(
                            sourceAccount
                        )
                    ]
                    ?? defaultAccountID
            }


            let storedAccountID =
                resolvedAccountID
                ?? TransactionService
                    .noAccountID


            let fingerprintValue =
                fingerprint(
                    type:
                        row.type,
                    amount:
                        row.amount,
                    category:
                        row.category,
                    note:
                        row.note,
                    date:
                        row.date,
                    accountID:
                        storedAccountID
                )


            if skipDuplicates,
               fingerprints.contains(
                    fingerprintValue
               ) {

                duplicates +=
                    1

                continue
            }


            let success:
                Bool


            if affectAccountBalance {

                guard
                    resolvedAccountID !=
                        nil
                else {

                    failed +=
                        1

                    continue
                }


                success =
                    TransactionService
                        .create(
                            type:
                                row.type,
                            amount:
                                row.amount,
                            category:
                                row.category,
                            accountID:
                                resolvedAccountID,
                            note:
                                row.note,
                            date:
                                row.date,
                            accounts:
                                accounts,
                            cards:
                                cards,
                            context:
                                context
                        )

            } else {

                let record =
                    TransactionRecord(
                        type:
                            row.type,
                        amount:
                            row.amount,
                        category:
                            row.category,
                        accountID:
                            storedAccountID,
                        note:
                            row.note,
                        date:
                            row.date
                    )


                context.insert(
                    record
                )


                do {

                    try context.save()

                    success =
                        true

                } catch {

                    context.delete(
                        record
                    )

                    success =
                        false
                }
            }


            if success {

                imported +=
                    1

                fingerprints.insert(
                    fingerprintValue
                )


                switch row.type {

                case .expense:

                    importedExpenseCategories.insert(
                        row.category
                    )

                case .income:

                    importedIncomeCategories.insert(
                        row.category
                    )

                default:

                    break
                }

            } else {

                failed +=
                    1
            }
        }


        let createdExpense =
            mergeCategories(
                importedExpenseCategories,
            key:
                CategoryStore
                    .expenseKey,
            fallback:
                CategoryStore
                    .defaultExpense
            )


        let createdIncome =
            mergeCategories(
                importedIncomeCategories,
            key:
                CategoryStore
                    .incomeKey,
            fallback:
                CategoryStore
                    .defaultIncome
            )


        return TransactionImportCommitResult(
            importedCount:
                imported,
            duplicateCount:
                duplicates,
            failedCount:
                failed,
            createdExpenseCategories:
                createdExpense,
            createdIncomeCategories:
                createdIncome
        )
    }


    // MARK: - CSV / TSV

    private static func detectDelimiter(
        in text:
            String
    ) -> Character {

        let sample =
            String(
                text.prefix(
                    8_000
                )
            )


        let delimiters:
            [Character] = [

                "\t",
                ",",
                ";"
            ]


        let scores =
            delimiters.map {
                delimiter in

                (
                    delimiter,
                    delimiterScore(
                        sample,
                        delimiter:
                            delimiter
                    )
                )
            }


        return scores
            .max {
                $0.1 <
                $1.1
            }?
            .0
        ?? ","
    }


    private static func delimiterScore(
        _ text:
            String,
        delimiter:
            Character
    ) -> Int {

        var score =
            0

        var inQuotes =
            false


        for character in
            text {

            if character ==
                "\"" {

                inQuotes.toggle()

            } else if !inQuotes,
                      character ==
                        delimiter {

                score +=
                    1

            } else if !inQuotes,
                      character ==
                        "\n",
                      score >
                        0 {

                // 前几行已经足够判断。
                if score >=
                    3 {

                    break
                }
            }
        }


        return score
    }


    private static func parseDelimitedText(
        _ text:
            String,
        delimiter:
            Character
    ) -> [[String]] {

        var rows:
            [[String]] = []

        var row:
            [String] = []

        var field =
            ""

        var inQuotes =
            false

        let characters =
            Array(
                text
            )

        var index =
            0


        while index <
                characters.count {

            let character =
                characters[
                    index
                ]


            if character ==
                "\"" {

                if inQuotes,
                   index +
                    1 <
                    characters.count,
                   characters[
                    index +
                    1
                   ] ==
                    "\"" {

                    field.append(
                        "\""
                    )

                    index +=
                        1

                } else {

                    inQuotes.toggle()
                }

            } else if !inQuotes,
                      character ==
                        delimiter {

                row.append(
                    field
                )

                field =
                    ""

            } else if !inQuotes,
                      character ==
                        "\n" {

                row.append(
                    field
                )

                rows.append(
                    row
                )

                row =
                    []

                field =
                    ""

            } else {

                field.append(
                    character
                )
            }


            index +=
                1
        }


        row.append(
            field
        )


        if row.contains(
            where: {
                !$0.isEmpty
            }
        ) {

            rows.append(
                row
            )
        }


        return rows
    }


    private static func normalizeRow(
        _ row:
            [String],
        count:
            Int
    ) -> [String] {

        if row.count ==
            count {

            return row
        }


        if row.count >
            count {

            return Array(
                row.prefix(
                    count
                )
            )
        }


        return row +
            Array(
                repeating:
                    "",
                count:
                    count -
                    row.count
            )
    }


    // MARK: - 解析字段

    private static func parseDate(
        _ raw:
            String,
        fallbackYear:
            Int
    ) -> Date? {

        let value =
            cleanCell(
                raw
            )


        guard !value.isEmpty
        else {

            return nil
        }


        let formats =
            [
                "yyyy-MM-dd HH:mm:ss",
                "yyyy-MM-dd HH:mm",
                "yyyy/M/d HH:mm:ss",
                "yyyy/M/d HH:mm",
                "yyyy年M月d日 HH:mm",
                "yyyy-MM-dd",
                "yyyy/M/d",
                "yyyy年M月d日",
                "M/d HH:mm",
                "M-d HH:mm",
                "M月d日 HH:mm"
            ]


        for format in
            formats {

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
                format

            formatter.isLenient =
                false


            if let date =
                formatter.date(
                    from:
                        value
                ) {

                return date
            }
        }


        let noYearFormats =
            [
                "M/d",
                "M-d",
                "M月d日"
            ]


        for format in
            noYearFormats {

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
                format

            formatter.defaultDate =
                AppTime.calendar.date(
                    from:
                        DateComponents(
                            year:
                                fallbackYear,
                            month:
                                1,
                            day:
                                1
                        )
                )


            if let date =
                formatter.date(
                    from:
                        value
                ) {

                var components =
                    AppTime.calendar
                        .dateComponents(
                            [
                                .month,
                                .day
                            ],
                            from:
                                date
                        )

                components.year =
                    fallbackYear

                return AppTime.calendar
                    .date(
                        from:
                            components
                    )
            }
        }


        return nil
    }


    private static func parseAmount(
        _ raw:
            String
    ) -> Double? {

        var value =
            cleanCell(
                raw
            )


        guard !value.isEmpty
        else {

            return nil
        }


        var negative =
            false


        if value.hasPrefix(
            "("
        ),
           value.hasSuffix(
            ")"
        ) {

            negative =
                true

            value.removeFirst()

            value.removeLast()
        }


        value =
            value
                .replacingOccurrences(
                    of:
                        "¥",
                    with:
                        ""
                )
                .replacingOccurrences(
                    of:
                        "￥",
                    with:
                        ""
                )
                .replacingOccurrences(
                    of:
                        "$",
                    with:
                        ""
                )
                .replacingOccurrences(
                    of:
                        "CNY",
                    with:
                        "",
                    options:
                        .caseInsensitive
                )
                .replacingOccurrences(
                    of:
                        ",",
                    with:
                        ""
                )
                .replacingOccurrences(
                    of:
                        " ",
                    with:
                        ""
                )


        guard
            let number =
                Double(
                    value
                )
        else {

            return nil
        }


        return negative
            ? -abs(
                number
            )
            : number
    }


    private static func inferType(
        typeText:
            String,
        amountHeader:
            String,
        signedAmount:
            Double
    ) -> TransactionType {

        let normalizedType =
            normalizedHeader(
                typeText
            )


        if normalizedType.contains(
            "收入"
        ) ||
           normalizedType.contains(
            "income"
        ) {

            return .income
        }


        if normalizedType.contains(
            "支出"
        ) ||
           normalizedType.contains(
            "expense"
        ) {

            return .expense
        }


        let normalizedAmountHeader =
            normalizedHeader(
                amountHeader
            )


        if normalizedAmountHeader.contains(
            "收入"
        ) {

            return .income
        }


        if normalizedAmountHeader.contains(
            "支出"
        ) {

            return .expense
        }


        // Apple Numbers “个人预算 / Personal Budget” 模板的
        // Actual Amount：支出为负，收入为正。
        return signedAmount <
            0
            ? .expense
            : .income
    }


    private static func defaultCategory(
        for type:
            TransactionType
    ) -> String {

        type ==
            .income
        ? "其他"
        : "其他"
    }


    // MARK: - 去重 / 分类

    private static func fingerprint(
        type:
            TransactionType,
        amount:
            Double,
        category:
            String,
        note:
            String,
        date:
            Date,
        accountID:
            UUID
    ) -> String {

        let seconds =
            Int(
                date
                    .timeIntervalSince1970
            )


        return [
            type.rawValue,
            String(
                format:
                    "%.2f",
                amount
            ),
            cleanCell(
                category
            ),
            cleanCell(
                note
            ),
            "\(seconds)",
            accountID
                .uuidString
        ]
        .joined(
            separator:
                "|"
        )
    }


    private static func mergeCategories(
        _ names:
            Set<String>,
        key:
            String,
        fallback:
            [CategoryItem]
    ) -> [String] {

        guard !names.isEmpty
        else {

            return []
        }


        let stored =
            UserDefaults.standard
                .string(
                    forKey:
                        key
                )
            ?? ""


        var categories =
            CategoryStore.decode(
                stored,
                fallback:
                    fallback
            )


        let existing =
            Set(
                categories.map {
                    $0.name
                }
            )


        let newNames =
            names
                .filter {
                    !existing.contains(
                        $0
                    )
                }
                .sorted()


        guard !newNames.isEmpty
        else {

            return []
        }


        categories.append(
            contentsOf:
                newNames.map {
                    CategoryItem(
                        name:
                            $0,
                        icon:
                            "tag.fill"
                    )
                }
        )


        UserDefaults.standard
            .set(
                CategoryStore.encode(
                    categories
                ),
                forKey:
                    key
            )


        return newNames
    }


    // MARK: - 辅助

    private static func value(
        _ row:
            [String],
        at index:
            Int
    ) -> String? {

        guard
            index >=
                0,
            index <
                row.count
        else {

            return nil
        }


        return row[
            index
        ]
    }


    private static func cleanCell(
        _ value:
            String
    ) -> String {

        value
            .replacingOccurrences(
                of:
                    "\u{FEFF}",
                with:
                    ""
            )
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
    }


    private static func normalizedHeader(
        _ value:
            String
    ) -> String {

        cleanCell(
            value
        )
        .lowercased()
        .replacingOccurrences(
            of:
                " ",
            with:
                ""
        )
        .replacingOccurrences(
            of:
                "_",
            with:
                ""
        )
        .replacingOccurrences(
            of:
                "-",
            with:
                ""
        )
    }


    private static func matches(
        _ value:
            String,
        _ candidates:
            [String]
    ) -> Bool {

        candidates.contains {
            value ==
                normalizedHeader(
                    $0
                )
        }
    }


    private static func normalizedAccountName(
        _ value:
            String
    ) -> String {

        cleanCell(
            value
        )
        .lowercased()
        .replacingOccurrences(
            of:
                " ",
            with:
                ""
        )
    }
}
