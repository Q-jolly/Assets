import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit


struct TransactionImportView:
    View {

    @Environment(
        \.dismiss
    )
    private var dismiss

    @Environment(
        \.modelContext
    )
    private var modelContext

    @Query(
        sort:
            \Account.createdAt
    )
    private var accounts:
        [Account]

    @Query(
        sort:
            \BankCard.createdAt
    )
    private var cards:
        [BankCard]

    @Query(
        sort:
            \TransactionRecord.date,
        order:
            .reverse
    )
    private var existingTransactions:
        [TransactionRecord]


    @State
    private var showFileImporter =
        false

    @State
    private var table:
        TransactionImportTable?

    @State
    private var mapping =
        TransactionImportMapping()

    @State
    private var preview:
        TransactionImportParseResult?

    @State
    private var defaultAccountID:
        UUID?

    @State
    private var useSourceAccountNames =
        true

    @State
    private var affectAccountBalance =
        false

    @State
    private var skipDuplicates =
        true

    @State
    private var fallbackYear =
        AppTime.calendar
            .component(
                .year,
                from:
                    Date()
            )

    @State
    private var sourceName =
        ""

    @State
    private var errorMessage:
        String?

    @State
    private var showImportResult =
        false

    @State
    private var importResultText =
        ""


    var body:
        some View {

        NavigationStack {

            Form {

                sourceSection


                if let table {

                    mappingSection(
                        table
                    )

                    importOptionsSection

                    previewSection
                }


                if let errorMessage {

                    Section {

                        Label(
                            errorMessage,
                            systemImage:
                                "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(
                            .orange
                        )
                    }
                }
            }
            .navigationTitle(
                "导入账单"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {

                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {

                    Button(
                        "关闭"
                    ) {

                        dismiss()
                    }
                }


                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {

                    Button(
                        "导入"
                    ) {

                        commitImport()
                    }
                    .fontWeight(
                        .semibold
                    )
                    .disabled(
                        preview?
                            .rows
                            .isEmpty
                        != false
                    )
                }
            }
            .fileImporter(
                isPresented:
                    $showFileImporter,
                allowedContentTypes:
                    [
                        .commaSeparatedText,
                        .plainText
                    ]
            ) { result in

                switch result {

                case .success(
                    let url
                ):

                    loadFile(
                        url
                    )

                case .failure(
                    let error
                ):

                    errorMessage =
                        error
                            .localizedDescription
                }
            }
            .alert(
                "导入完成",
                isPresented:
                    $showImportResult
            ) {

                Button(
                    "好的"
                ) {

                    dismiss()
                }

            } message: {

                Text(
                    importResultText
                )
            }
            .onAppear {

                if defaultAccountID ==
                    nil {

                    defaultAccountID =
                        accounts.first?
                            .id
                }
            }
        }
    }


    // MARK: - 来源

    private var sourceSection:
        some View {

        Section {

            Button {

                showFileImporter =
                    true

            } label: {

                Label(
                    "选择 CSV / TSV 文件",
                    systemImage:
                        "doc.badge.plus"
                )
            }


            Button {

                loadClipboard()

            } label: {

                Label(
                    "从 Numbers 剪贴板读取",
                    systemImage:
                        "doc.on.clipboard"
                )
            }


            if !sourceName.isEmpty {

                LabeledContent(
                    "当前来源",
                    value:
                        sourceName
                )
            }

        } header: {

            Text(
                "数据来源"
            )

        } footer: {

            Text(
                "你上传的这类 Numbers“个人预算”账单可以导入：在 Numbers 中复制明细表，回到这里点“从 Numbers 剪贴板读取”；或者在 Numbers 中导出 CSV 后选择文件。原生 .numbers 文件内部是 Apple 的 IWA 格式，本版不直接解析，以避免账单误读。"
            )
        }
    }


    // MARK: - 列映射

    private func mappingSection(
        _ table:
            TransactionImportTable
    ) -> some View {

        Section(
            "列映射"
        ) {

            columnPicker(
                "日期 *",
                selection:
                    $mapping
                        .dateColumn,
                headers:
                    table
                        .headers,
                optional:
                    false
            )


            columnPicker(
                "金额 *",
                selection:
                    $mapping
                        .amountColumn,
                headers:
                    table
                        .headers,
                optional:
                    false
            )


            columnPicker(
                "分类",
                selection:
                    $mapping
                        .categoryColumn,
                headers:
                    table
                        .headers
            )


            columnPicker(
                "描述 / 备注",
                selection:
                    $mapping
                        .descriptionColumn,
                headers:
                    table
                        .headers
            )


            columnPicker(
                "收支类型",
                selection:
                    $mapping
                        .typeColumn,
                headers:
                    table
                        .headers
            )


            columnPicker(
                "账户",
                selection:
                    $mapping
                        .accountColumn,
                headers:
                    table
                        .headers
            )


            Stepper(
                "无年份日期按 \(fallbackYear) 年处理",
                value:
                    $fallbackYear,
                in:
                    2000...2100
            )
        }
        .onChange(
            of:
                mapping
        ) { _, _ in

            refreshPreview()
        }
        .onChange(
            of:
                fallbackYear
        ) { _, _ in

            refreshPreview()
        }
    }


    private func columnPicker(
        _ title:
            String,
        selection:
            Binding<Int?>,
        headers:
            [String],
        optional:
            Bool =
                true
    ) -> some View {

        Picker(
            title,
            selection:
                selection
        ) {

            if optional {

                Text(
                    "不使用"
                )
                .tag(
                    Int?.none
                )
            }


            ForEach(
                headers.indices,
                id:
                    \.self
            ) { index in

                Text(
                    headers[
                        index
                    ]
                )
                .tag(
                    Optional(
                        index
                    )
                )
            }
        }
    }


    // MARK: - 导入选项

    private var importOptionsSection:
        some View {

        Section {

            Picker(
                "默认归属账户",
                selection:
                    $defaultAccountID
            ) {

                Text(
                    "不指定账户"
                )
                .tag(
                    UUID?.none
                )


                ForEach(
                    accounts
                ) { account in

                    Text(
                        account.name
                    )
                    .tag(
                        Optional(
                            account.id
                        )
                    )
                }
            }


            if mapping.accountColumn !=
                nil {

                Toggle(
                    "优先匹配表格中的账户名称",
                    isOn:
                        $useSourceAccountNames
                )
            }


            Toggle(
                "跳过重复账单",
                isOn:
                    $skipDuplicates
            )


            Toggle(
                "同时更新账户余额",
                isOn:
                    $affectAccountBalance
            )
            .disabled(
                defaultAccountID ==
                    nil &&
                !useSourceAccountNames
            )

        } header: {

            Text(
                "导入方式"
            )

        } footer: {

            Text(
                affectAccountBalance
                ? "导入时会按收入/支出同步修改账户余额。适合从零开始建立账本。"
                : "默认只补充历史账单，不修改当前账户余额，避免把已经设置好的余额重复加减。"
            )
        }
    }


    // MARK: - 预览

    private var previewSection:
        some View {

        Section {

            if let preview {

                HStack {

                    Label(
                        "可导入",
                        systemImage:
                            "checkmark.circle.fill"
                    )

                    Spacer()

                    Text(
                        "\(preview.rows.count) 笔"
                    )
                    .fontWeight(
                        .semibold
                    )
                }


                if preview.skippedRows >
                    0 {

                    LabeledContent(
                        "无法识别",
                        value:
                            "\(preview.skippedRows) 行"
                    )
                    .foregroundStyle(
                        .orange
                    )
                }


                ForEach(
                    preview.rows
                        .prefix(
                            10
                        )
                ) { row in

                    VStack(
                        alignment:
                            .leading,
                        spacing: 5
                    ) {

                        HStack {

                            Text(
                                row.category
                            )
                            .fontWeight(
                                .medium
                            )


                            Spacer()


                            Text(
                                amountText(
                                    row
                                )
                            )
                            .fontWeight(
                                .semibold
                            )
                            .foregroundStyle(
                                row.type ==
                                    .income
                                ? .green
                                : .primary
                            )
                        }


                        HStack {

                            Text(
                                AppTime.listDateTime(
                                    row.date
                                )
                            )


                            if !row.note.isEmpty {

                                Text(
                                    "· \(row.note)"
                                )
                                .lineLimit(
                                    1
                                )
                            }
                        }
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                    .padding(
                        .vertical,
                        3
                    )
                }


                if preview.rows.count >
                    10 {

                    Text(
                        "仅预览前 10 笔，实际将处理 \(preview.rows.count) 笔。"
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }

            } else {

                ContentUnavailableView(
                    "等待解析",
                    systemImage:
                        "tablecells",
                    description:
                        Text(
                            "选择数据源并确认日期、金额列后，会在这里预览。"
                        )
                )
            }

        } header: {

            Text(
                "导入预览"
            )
        }
    }


    // MARK: - 读取

    private func loadFile(
        _ url:
            URL
    ) {

        errorMessage =
            nil


        let accessed =
            url
                .startAccessingSecurityScopedResource()


        defer {

            if accessed {

                url
                    .stopAccessingSecurityScopedResource()
            }
        }


        do {

            let data =
                try Data(
                    contentsOf:
                        url
                )


            let text =
                try TransactionImportService
                    .decodeText(
                        data:
                            data
                    )


            try loadText(
                text,
                source:
                    url
                        .lastPathComponent
            )

        } catch {

            errorMessage =
                error
                    .localizedDescription
        }
    }


    private func loadClipboard() {

        errorMessage =
            nil


        guard
            let text =
                UIPasteboard
                    .general
                    .string,
            !text
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .isEmpty
        else {

            errorMessage =
                TransactionImportError
                    .cannotReadClipboard
                    .localizedDescription

            return
        }


        do {

            try loadText(
                text,
                source:
                    "Numbers 剪贴板"
            )

        } catch {

            errorMessage =
                error
                    .localizedDescription
        }
    }


    private func loadText(
        _ text:
            String,
        source:
            String
    ) throws {

        let parsedTable =
            try TransactionImportService
                .parseTable(
                    text:
                        text
                )


        table =
            parsedTable

        mapping =
            TransactionImportService
                .autoMapping(
                    headers:
                        parsedTable
                            .headers
                )

        sourceName =
            source

        refreshPreview()
    }


    private func refreshPreview() {

        guard
            let table
        else {

            preview =
                nil

            return
        }


        do {

            preview =
                try TransactionImportService
                    .makePreview(
                        table:
                            table,
                        mapping:
                            mapping,
                        fallbackYear:
                            fallbackYear
                    )

            errorMessage =
                nil

        } catch {

            preview =
                nil

            errorMessage =
                error
                    .localizedDescription
        }
    }


    // MARK: - 提交

    private func commitImport() {

        guard
            let preview
        else {

            return
        }


        let result =
            TransactionImportService
                .commit(
                    previewRows:
                        preview.rows,
                    defaultAccountID:
                        defaultAccountID,
                    useSourceAccountNames:
                        useSourceAccountNames,
                    affectAccountBalance:
                        affectAccountBalance,
                    skipDuplicates:
                        skipDuplicates,
                    accounts:
                        accounts,
                    cards:
                        cards,
                    existingTransactions:
                        existingTransactions,
                    context:
                        modelContext
                )


        var parts =
            [
                "成功导入 \(result.importedCount) 笔"
            ]


        if result.duplicateCount >
            0 {

            parts.append(
                "跳过重复 \(result.duplicateCount) 笔"
            )
        }


        if result.failedCount >
            0 {

            parts.append(
                "失败 \(result.failedCount) 笔"
            )
        }


        let newCategoryCount =
            result
                .createdExpenseCategories
                .count +
            result
                .createdIncomeCategories
                .count


        if newCategoryCount >
            0 {

            parts.append(
                "新增分类 \(newCategoryCount) 个"
            )
        }


        importResultText =
            parts.joined(
                separator:
                    "；"
            ) +
            "。"

        showImportResult =
            true
    }


    private func amountText(
        _ row:
            TransactionImportPreviewRow
    ) -> String {

        let amount =
            row.amount.formatted(
                .currency(
                    code:
                        "CNY"
                )
            )


        return row.type ==
            .income
        ? "+\(amount)"
        : "-\(amount)"
    }
}
