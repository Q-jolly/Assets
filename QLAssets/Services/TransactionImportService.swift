import Foundation
import SwiftData
import Compression


struct TransactionImportTable {

    let headers:
        [String]

    let rows:
        [[String]]

    let delimiter:
        Character
}


struct NumbersZIPImportSelection {

    let text:
        String

    let entryName:
        String

    let ignoredCSVCount:
        Int
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

    case invalidZIP

    case noTransactionCSVInZIP


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

        case .invalidZIP:

            return
                "这个 ZIP 文件无法解析，请确认它是 Numbers 导出的 CSV 压缩包。"

        case .noTransactionCSVInZIP:

            return
                "ZIP 中没有找到可识别的交易明细 CSV。"
        }
    }
}


enum TransactionImportService {

    // MARK: - 多表合并

    static func mergeTables(
        _ tables:
            [TransactionImportTable]
    ) throws
        -> TransactionImportTable {

        guard
            let first =
                tables.first
        else {

            throw TransactionImportError
                .emptyFile
        }


        var mergedHeaders:
            [String] = []

        var seenHeaders =
            Set<String>()


        for table in
            tables {

            for header in
                table.headers {

                let normalized =
                    header.trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )


                guard
                    seenHeaders
                        .insert(
                            normalized
                        )
                        .inserted
                else {
                    continue
                }


                mergedHeaders.append(
                    normalized
                )
            }
        }


        var mergedRows:
            [[String]] = []


        for table in
            tables {

            let sourceIndexByHeader =
                Dictionary(
                    uniqueKeysWithValues:
                        table.headers
                            .enumerated()
                            .map {
                                index,
                                header in

                                (
                                    header.trimmingCharacters(
                                        in:
                                            .whitespacesAndNewlines
                                    ),
                                    index
                                )
                            }
                )


            for row in
                table.rows {

                var mergedRow =
                    Array(
                        repeating:
                            "",
                        count:
                            mergedHeaders.count
                    )


                for (
                    targetIndex,
                    header
                ) in
                    mergedHeaders
                        .enumerated() {

                    guard
                        let sourceIndex =
                            sourceIndexByHeader[
                                header
                            ],
                        sourceIndex <
                            row.count
                    else {
                        continue
                    }


                    mergedRow[
                        targetIndex
                    ] =
                        row[
                            sourceIndex
                        ]
                }


                mergedRows.append(
                    mergedRow
                )
            }
        }


        guard
            !mergedRows.isEmpty
        else {

            throw TransactionImportError
                .emptyFile
        }


        return TransactionImportTable(
            headers:
                mergedHeaders,
            rows:
                mergedRows,
            delimiter:
                first.delimiter
        )
    }


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


    static func extractNumbersZIP(
        data:
            Data
    ) throws
        -> NumbersZIPImportSelection {

        let entries =
            try readZIPEntries(
                data:
                    data
            )
            .filter {
                $0.name
                    .lowercased()
                    .hasSuffix(
                        ".csv"
                    )
            }


        guard !entries.isEmpty
        else {

            throw TransactionImportError
                .noTransactionCSVInZIP
        }


        var candidates:
            [(
                score:
                    Int,
                rowCount:
                    Int,
                name:
                    String,
                text:
                    String
            )] = []


        for entry in entries {

            guard
                let entryData =
                    extractZIPEntry(
                        entry,
                        archiveData:
                            data
                    ),
                let csvText =
                    try? decodeText(
                        data:
                            entryData
                    ),
                let table =
                    try? parseTable(
                        text:
                            csvText
                    )
            else {

                continue
            }


            let mapping =
                autoMapping(
                    headers:
                        table.headers
                )


            var score =
                0


            if mapping.dateColumn !=
                nil {

                score +=
                    100
            }


            if mapping.amountColumn !=
                nil {

                score +=
                    80
            }


            if mapping.typeColumn !=
                nil {

                score +=
                    50
            }


            if mapping.categoryColumn !=
                nil {

                score +=
                    30
            }


            if mapping.descriptionColumn !=
                nil {

                score +=
                    15
            }


            let normalizedName =
                entry.name
                    .lowercased()


            if normalizedName.contains(
                "交易"
            ) ||
               normalizedName.contains(
                "transaction"
            ) {

                score +=
                    40
            }


            // 明细表通常远多于“月支出 / 月收入”概览行。
            score +=
                min(
                    table.rows.count,
                    50
                )


            candidates.append(
                (
                    score:
                        score,
                    rowCount:
                        table.rows.count,
                    name:
                        entry.name,
                    text:
                        csvText
                )
            )
        }


        let sortedCandidates =
            candidates.sorted {
                lhs,
                rhs in

                if lhs.score !=
                    rhs.score {

                    return
                        lhs.score >
                        rhs.score
                }

                return
                    lhs.rowCount >
                    rhs.rowCount
            }


        guard
            let best =
                sortedCandidates.first,
            best.score >=
                180
        else {

            throw TransactionImportError
                .noTransactionCSVInZIP
        }


        return NumbersZIPImportSelection(
            text:
                best.text,
            entryName:
                best.name,
            ignoredCSVCount:
                max(
                    0,
                    entries.count -
                    1
                )
        )
    }


    // MARK: - ZIP 读取

    private struct ZIPEntry {

        let name:
            String

        let compressionMethod:
            UInt16

        let compressedSize:
            Int

        let uncompressedSize:
            Int

        let localHeaderOffset:
            Int
    }


    private static func readZIPEntries(
        data:
            Data
    ) throws
        -> [ZIPEntry] {

        // End of central directory 至少 22 字节，
        // ZIP comment 最长 65535 字节。
        guard data.count >=
                22
        else {

            throw TransactionImportError
                .invalidZIP
        }


        let signature:
            UInt32 =
                0x06054B50


        let lowerBound =
            max(
                0,
                data.count -
                65_557
            )


        var index =
            data.count -
            22

        var endOffset:
            Int?


        while index >=
                lowerBound {

            if readUInt32(
                data,
                at:
                    index
            ) ==
                signature {

                endOffset =
                    index

                break
            }


            index -=
                1
        }


        guard
            let endOffset,
            let entryCount =
                readUInt16(
                    data,
                    at:
                        endOffset +
                        10
                ),
            let centralDirectoryOffset =
                readUInt32(
                    data,
                    at:
                        endOffset +
                        16
                )
        else {

            throw TransactionImportError
                .invalidZIP
        }


        var entries:
            [ZIPEntry] = []

        var cursor =
            Int(
                centralDirectoryOffset
            )


        for _ in
            0..<Int(
                entryCount
            ) {

            guard
                readUInt32(
                    data,
                    at:
                        cursor
                ) ==
                    0x02014B50,
                let flags =
                    readUInt16(
                        data,
                        at:
                            cursor +
                            8
                    ),
                let method =
                    readUInt16(
                        data,
                        at:
                            cursor +
                            10
                    ),
                let compressedSize =
                    readUInt32(
                        data,
                        at:
                            cursor +
                            20
                    ),
                let uncompressedSize =
                    readUInt32(
                        data,
                        at:
                            cursor +
                            24
                    ),
                let nameLength =
                    readUInt16(
                        data,
                        at:
                            cursor +
                            28
                    ),
                let extraLength =
                    readUInt16(
                        data,
                        at:
                            cursor +
                            30
                    ),
                let commentLength =
                    readUInt16(
                        data,
                        at:
                            cursor +
                            32
                    ),
                let localOffset =
                    readUInt32(
                        data,
                        at:
                            cursor +
                            42
                    )
            else {

                throw TransactionImportError
                    .invalidZIP
            }


            // encrypted ZIP 不处理
            guard
                flags &
                    0x0001 ==
                    0
            else {

                throw TransactionImportError
                    .invalidZIP
            }


            let nameStart =
                cursor +
                46

            let nameEnd =
                nameStart +
                Int(
                    nameLength
                )


            guard
                nameStart >=
                    0,
                nameEnd <=
                    data.count
            else {

                throw TransactionImportError
                    .invalidZIP
            }


            let nameData =
                data.subdata(
                    in:
                        nameStart..<nameEnd
                )


            // Numbers 导出的 ZIP 可能没有设置 UTF-8 flag，
            // 但文件名字节本身仍然是 UTF-8；优先按 UTF-8 解码。
            let name =
                String(
                    data:
                        nameData,
                    encoding:
                        .utf8
                )
                ?? "CSV-\(entries.count + 1).csv"


            entries.append(
                ZIPEntry(
                    name:
                        name,
                    compressionMethod:
                        method,
                    compressedSize:
                        Int(
                            compressedSize
                        ),
                    uncompressedSize:
                        Int(
                            uncompressedSize
                        ),
                    localHeaderOffset:
                        Int(
                            localOffset
                        )
                )
            )


            cursor +=
                46 +
                Int(
                    nameLength
                ) +
                Int(
                    extraLength
                ) +
                Int(
                    commentLength
                )
        }


        return entries
    }


    private static func extractZIPEntry(
        _ entry:
            ZIPEntry,
        archiveData:
            Data
    ) -> Data? {

        let offset =
            entry.localHeaderOffset


        guard
            readUInt32(
                archiveData,
                at:
                    offset
            ) ==
                0x04034B50,
            let nameLength =
                readUInt16(
                    archiveData,
                    at:
                        offset +
                        26
                ),
            let extraLength =
                readUInt16(
                    archiveData,
                    at:
                        offset +
                        28
                )
        else {

            return nil
        }


        let dataStart =
            offset +
            30 +
            Int(
                nameLength
            ) +
            Int(
                extraLength
            )

        let dataEnd =
            dataStart +
            entry.compressedSize


        guard
            dataStart >=
                0,
            dataEnd <=
                archiveData.count
        else {

            return nil
        }


        let compressed =
            archiveData.subdata(
                in:
                    dataStart..<dataEnd
            )


        switch entry
            .compressionMethod {

        case 0:

            return compressed

        case 8:

            return inflateRawDeflate(
                compressed,
                expectedSize:
                    entry
                        .uncompressedSize
            )

        default:

            return nil
        }
    }


    private static func inflateRawDeflate(
        _ compressed:
            Data,
        expectedSize:
            Int
    ) -> Data? {

        guard
            expectedSize >=
                0
        else {

            return nil
        }


        if expectedSize ==
            0 {

            return Data()
        }


        var output =
            Data(
                count:
                    max(
                        expectedSize,
                        1
                    )
            )


        let outputCapacity =
            output.count


        let decodedSize:
            Int =
                output
                    .withUnsafeMutableBytes {
                        destinationBuffer in

                        compressed
                            .withUnsafeBytes {
                                sourceBuffer in

                                guard
                                    let destination =
                                        destinationBuffer
                                            .bindMemory(
                                                to:
                                                    UInt8.self
                                            )
                                            .baseAddress,
                                    let source =
                                        sourceBuffer
                                            .bindMemory(
                                                to:
                                                    UInt8.self
                                            )
                                            .baseAddress
                                else {

                                    return 0
                                }


                                return compression_decode_buffer(
                                    destination,
                                    outputCapacity,
                                    source,
                                    compressed.count,
                                    nil,
                                    COMPRESSION_ZLIB
                                )
                            }
                    }


        guard decodedSize >
                0
        else {

            return nil
        }


        output.count =
            decodedSize

        return output
    }


    private static func readUInt16(
        _ data:
            Data,
        at offset:
            Int
    ) -> UInt16? {

        guard
            offset >=
                0,
            offset +
                2 <=
                data.count
        else {

            return nil
        }


        return
            UInt16(
                data[
                    offset
                ]
            ) |
            (
                UInt16(
                    data[
                        offset +
                        1
                    ]
                )
                << 8
            )
    }


    private static func readUInt32(
        _ data:
            Data,
        at offset:
            Int
    ) -> UInt32? {

        guard
            offset >=
                0,
            offset +
                4 <=
                data.count
        else {

            return nil
        }


        return
            UInt32(
                data[
                    offset
                ]
            ) |
            (
                UInt32(
                    data[
                        offset +
                        1
                    ]
                )
                << 8
            ) |
            (
                UInt32(
                    data[
                        offset +
                        2
                    ]
                )
                << 16
            ) |
            (
                UInt32(
                    data[
                        offset +
                        3
                    ]
                )
                << 24
            )
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
                    "账目明细",
                    "明细",
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


            let importedCategory =
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
                        cleanImportedCategory
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


            let category =
                CategoryNormalizer
                    .normalized(
                        importedCategory
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
                    CategoryNormalizer
                        .normalized(
                            $0.name
                        )
                }
            )


        let newNames =
            Set(
                names.map {
                    CategoryNormalizer
                        .normalized(
                            $0
                        )
                }
            )
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


    private static func cleanImportedCategory(
        _ value:
            String
    ) -> String {

        let cleaned =
            cleanCell(
                value
            )


        guard !cleaned.isEmpty
        else {

            return cleaned
        }


        let allowedStart =
            CharacterSet
                .letters
                .union(
                    .decimalDigits
                )


        if let scalarIndex =
            cleaned
                .unicodeScalars
                .firstIndex(
                    where: {
                        allowedStart
                            .contains(
                                $0
                            )
                    }
                ) {

            return String(
                cleaned
                    .unicodeScalars[
                        scalarIndex...
                    ]
            )
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
        }


        return cleaned
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
