import SwiftUI
import SwiftData
import Foundation
import UniformTypeIdentifiers


struct TransactionListView:
    View {

    private enum DateFilter:
        String,
        CaseIterable,
        Identifiable {

        case all =
            "全部时间"

        case thisMonth =
            "本月"

        case lastMonth =
            "上月"

        case recentThreeMonths =
            "近3个月"

        case thisYear =
            "今年"


        var id:
            String {

            rawValue
        }
    }


    private struct MonthGroup:
        Identifiable {

        let month:
            Date

        let transactions:
            [TransactionRecord]


        var id:
            Date {

            month
        }
    }


    @Environment(
        \.modelContext
    )
    private var modelContext

    @Query(
        sort:
            \TransactionRecord.date,
        order:
            .reverse
    )
    private var transactions:
        [TransactionRecord]

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


    @State
    private var searchText =
        ""

    @State
    private var showFilters =
        false

    @State
    private var showImporter =
        false

    @State
    private var selectedType =
        "全部类型"

    @State
    private var selectedCategory =
        "全部分类"

    @State
    private var selectedAccountID:
        UUID?

    @State
    private var selectedCardID:
        UUID?

    @State
    private var dateFilter:
        DateFilter =
            .all

    @State
    private var exportDocument =
        TransactionCSVDocument()

    @State
    private var showExporter =
        false

    @State
    private var exportFilename =
        "QLAssets_账单"

    @State
    private var exportMessageTitle =
        ""

    @State
    private var exportMessageText =
        ""

    @State
    private var showExportMessage =
        false


    private var availableCategories:
        [String] {

        Array(
            Set(
                transactions
                    .map(
                        \.category
                    )
                    .filter {
                        !$0.isEmpty
                    }
            )
        )
        .sorted()
    }


    private var filteredTransactions:
        [TransactionRecord] {

        transactions.filter {
            transaction in

            matchesSearch(
                transaction
            ) &&
            matchesType(
                transaction
            ) &&
            matchesCategory(
                transaction
            ) &&
            matchesAccount(
                transaction
            ) &&
            matchesCard(
                transaction
            ) &&
            matchesDate(
                transaction.date
            )
        }
    }


    private var monthGroups:
        [MonthGroup] {

        let grouped =
            Dictionary(
                grouping:
                    filteredTransactions
            ) {
                transaction in

                AppTime.calendar
                    .dateInterval(
                        of:
                            .month,
                        for:
                            transaction.date
                    )?
                    .start
                ?? transaction.date
            }


        return grouped
            .map {
                month,
                records in

                MonthGroup(
                    month:
                        month,
                    transactions:
                        records.sorted {
                            $0.date >
                            $1.date
                        }
                )
            }
            .sorted {
                $0.month >
                $1.month
            }
    }


    private var filteredExpense:
        Double {

        filteredTransactions
            .filter {
                $0.type ==
                    .expense ||
                $0.type ==
                    .creditExpense
            }
            .reduce(
                0
            ) {
                $0 +
                abs(
                    $1.amount
                )
            }
    }


    private var filteredIncome:
        Double {

        filteredTransactions
            .filter {
                $0.type ==
                    .income
            }
            .reduce(
                0
            ) {
                $0 +
                abs(
                    $1.amount
                )
            }
    }


    private var activeFilterCount:
        Int {

        var count =
            0

        if selectedType !=
            "全部类型" {

            count +=
                1
        }

        if selectedCategory !=
            "全部分类" {

            count +=
                1
        }

        if selectedAccountID !=
            nil {

            count +=
                1
        }

        if selectedCardID !=
            nil {

            count +=
                1
        }

        if dateFilter !=
            .all {

            count +=
                1
        }

        return count
    }


    var body:
        some View {

        List {

            if !transactions.isEmpty {

                Section {

                    HStack(
                        spacing: 12
                    ) {

                        summaryValue(
                            title:
                                "筛选支出",
                            value:
                                filteredExpense
                        )

                        summaryValue(
                            title:
                                "筛选收入",
                            value:
                                filteredIncome
                        )
                    }

                } footer: {

                    Text(
                        "当前共 \(filteredTransactions.count) 笔账单"
                    )
                }
            }


            if transactions.isEmpty {

                ContentUnavailableView(
                    "暂无账单",
                    systemImage:
                        "list.bullet.rectangle",
                    description:
                        Text(
                            "记录第一笔消费吧"
                        )
                )

            } else if filteredTransactions
                .isEmpty {

                ContentUnavailableView(
                    "没有匹配的账单",
                    systemImage:
                        "magnifyingglass",
                    description:
                        Text(
                            "尝试修改搜索词或筛选条件"
                        )
                )

            } else {

                ForEach(
                    monthGroups
                ) { group in

                    Section {

                        ForEach(
                            group
                                .transactions
                        ) { transaction in

                            NavigationLink {

                                TransactionDetailView(
                                    transaction:
                                        transaction
                                )

                            } label: {

                                TransactionRowView(
                                    transaction:
                                        transaction,
                                    accountName:
                                        accountName(
                                            transaction
                                                .accountID
                                        ),
                                    targetAccountName:
                                        transaction
                                            .targetAccountID
                                            .flatMap {
                                                accountName(
                                                    $0
                                                )
                                            },
                                    cardName:
                                        transaction
                                            .bankCardID
                                            .flatMap {
                                                cardName(
                                                    $0
                                                )
                                            }
                                )
                            }
                            .swipeActions(
                                edge:
                                    .trailing
                            ) {

                                Button(
                                    role:
                                        .destructive
                                ) {

                                    deleteTransaction(
                                        transaction
                                    )

                                } label: {

                                    Label(
                                        "删除",
                                        systemImage:
                                            "trash"
                                    )
                                }
                            }
                        }

                    } header: {

                        HStack {

                            Text(
                                monthText(
                                    group.month
                                )
                            )

                            Spacer()

                            Text(
                                "\(group.transactions.count) 笔"
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle(
            "账单"
        )
        .searchable(
            text:
                $searchText,
            placement:
                .navigationBarDrawer(
                    displayMode:
                        .automatic
                ),
            prompt:
                "搜索分类、备注、账户或银行卡"
        )
        .toolbar {

            ToolbarItemGroup(
                placement:
                    .topBarTrailing
            ) {

                Menu {

                    Button {

                        showImporter =
                            true

                    } label: {

                        Label(
                            "导入账单",
                            systemImage:
                                "square.and.arrow.down"
                        )
                    }


                    Divider()


                    Button {

                        prepareCSVExport(
                            transactions:
                                filteredTransactions,
                            filtered:
                                true
                        )

                    } label: {

                        Label(
                            "导出当前结果",
                            systemImage:
                                "line.3.horizontal.decrease"
                        )
                    }
                    .disabled(
                        filteredTransactions
                            .isEmpty
                    )


                    Button {

                        prepareCSVExport(
                            transactions:
                                transactions,
                            filtered:
                                false
                        )

                    } label: {

                        Label(
                            "导出全部账单",
                            systemImage:
                                "tray.full"
                        )
                    }
                    .disabled(
                        transactions
                            .isEmpty
                    )

                } label: {

                    Image(
                        systemName:
                            "arrow.up.arrow.down.square"
                    )
                }


                NavigationLink {

                    CategoryManagerView()

                } label: {

                    Image(
                        systemName:
                            "square.grid.2x2"
                    )
                }


                Button {

                    showFilters =
                        true

                } label: {

                    Image(
                        systemName:
                            "line.3.horizontal.decrease.circle"
                    )
                    .frame(
                        width:
                            30,
                        height:
                            30
                    )
                    // 自绘筛选数量角标。
                    // 不使用外层 Capsule 内部 overlay，避免被 clipShape 裁剪。
                    .padding(
                        4
                    )
                    .background {
                        if activeFilterCount > 0 {
                            Text("\(activeFilterCount)")
                                .font(
                                    .system(
                                        size: 9,
                                        weight: .bold
                                    )
                                )
                                .foregroundStyle(.white)
                                .frame(
                                    width: 18,
                                    height: 18
                                )
                                .background(
                                    Circle()
                                        .fill(Color.red)
                                )
                                .offset(
                                    x: 18,
                                    y: -12
                                )
                                .allowsHitTesting(false)
                                .zIndex(20)
                        }
                    }
                }
            }
        }
        .sheet(
            isPresented:
                $showFilters
        ) {

            NavigationStack {

                Form {

                    Section(
                        "类型"
                    ) {

                        Picker(
                            "账单类型",
                            selection:
                                $selectedType
                        ) {

                            Text(
                                "全部类型"
                            )
                            .tag(
                                "全部类型"
                            )


                            ForEach(
                                TransactionType
                                    .userSelectableCases
                            ) { type in

                                Text(
                                    type.rawValue
                                )
                                .tag(
                                    type.rawValue
                                )
                            }


                            Text(
                                TransactionType
                                    .adjustment
                                    .rawValue
                            )
                            .tag(
                                TransactionType
                                    .adjustment
                                    .rawValue
                            )
                        }
                    }


                    Section(
                        "分类"
                    ) {

                        Picker(
                            "分类",
                            selection:
                                $selectedCategory
                        ) {

                            Text(
                                "全部分类"
                            )
                            .tag(
                                "全部分类"
                            )


                            ForEach(
                                availableCategories,
                                id:
                                    \.self
                            ) { category in

                                Text(
                                    category
                                )
                                .tag(
                                    category
                                )
                            }
                        }
                    }


                    Section(
                        "账户 / 信用卡"
                    ) {

                        Picker(
                            "资产账户",
                            selection:
                                $selectedAccountID
                        ) {

                            Text(
                                "全部账户"
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


                        Picker(
                            "信用卡",
                            selection:
                                $selectedCardID
                        ) {

                            Text(
                                "全部信用卡"
                            )
                            .tag(
                                UUID?.none
                            )


                            ForEach(
                                cards.filter {
                                    $0.cardType ==
                                        .credit
                                }
                            ) { card in

                                Text(
                                    "\(card.bankName) •••• \(card.lastFourDigits)"
                                )
                                .tag(
                                    Optional(
                                        card.id
                                    )
                                )
                            }
                        }
                    }


                    Section(
                        "时间"
                    ) {

                        Picker(
                            "范围",
                            selection:
                                $dateFilter
                        ) {

                            ForEach(
                                DateFilter
                                    .allCases
                            ) { item in

                                Text(
                                    item.rawValue
                                )
                                .tag(
                                    item
                                )
                            }
                        }
                    }


                    Section {

                        Button(
                            "清除全部筛选"
                        ) {

                            resetFilters()
                        }
                        .disabled(
                            activeFilterCount ==
                                0
                        )
                    }
                }
                .navigationTitle(
                    "筛选账单"
                )
                .navigationBarTitleDisplayMode(
                    .inline
                )
                .toolbar {

                    ToolbarItem(
                        placement:
                            .confirmationAction
                    ) {

                        Button(
                            "完成"
                        ) {

                            showFilters =
                                false
                        }
                    }
                }
            }
        }
        .sheet(
            isPresented:
                $showImporter
        ) {

            TransactionImportView()
        }
        .fileExporter(
            isPresented:
                $showExporter,
            document:
                exportDocument,
            contentType:
                TransactionCSVDocument
                    .readableContentTypes
                    .first
                ?? .plainText,
            defaultFilename:
                exportFilename
        ) { result in

            switch result {

            case .success:

                exportMessageTitle =
                    "导出完成"

                exportMessageText =
                    "CSV 文件已导出，可用 Excel、Numbers 等应用打开。"

            case .failure(
                let error
            ):

                exportMessageTitle =
                    "导出失败"

                exportMessageText =
                    error
                        .localizedDescription
            }


            showExportMessage =
                true
        }
        .alert(
            exportMessageTitle,
            isPresented:
                $showExportMessage
        ) {

            Button(
                "好的"
            ) {}

        } message: {

            Text(
                exportMessageText
            )
        }
    }


    private func prepareCSVExport(
        transactions records:
            [TransactionRecord],
        filtered:
            Bool
    ) {

        let data =
            TransactionCSVExportService
                .makeCSV(
                    transactions:
                        records,
                    accounts:
                        accounts,
                    cards:
                        cards
                )


        exportDocument =
            TransactionCSVDocument(
                data:
                    data
            )


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
            "yyyyMMdd_HHmm"


        exportFilename =
            filtered
            ? "QLAssets_筛选账单_\(formatter.string(from: Date()))"
            : "QLAssets_全部账单_\(formatter.string(from: Date()))"


        showExporter =
            true
    }


    private func summaryValue(
        title:
            String,
        value:
            Double
    ) -> some View {

        VStack(
            alignment:
                .leading,
            spacing:
                4
        ) {

            Text(
                title
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )


            Text(
                value,
                format:
                    .currency(
                        code:
                            "CNY"
                    )
            )
            .font(
                .headline
            )
            .lineLimit(1)
            .minimumScaleFactor(
                0.75
            )
        }
        .frame(
            maxWidth:
                .infinity,
            alignment:
                .leading
        )
    }


    private func matchesSearch(
        _ transaction:
            TransactionRecord
    ) -> Bool {

        let query =
            searchText
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        guard !query.isEmpty
        else {

            return true
        }


        var fields =
            [
                transaction.category,
                transaction.note,
                transaction.type.rawValue,
                AppTime.listDateTime(
                    transaction.date
                )
            ]


        if let account =
            accountName(
                transaction.accountID
            ) {

            fields.append(
                account
            )
        }


        if let targetID =
            transaction.targetAccountID,
           let target =
            accountName(
                targetID
            ) {

            fields.append(
                target
            )
        }


        if let cardID =
            transaction.bankCardID,
           let card =
            cardName(
                cardID
            ) {

            fields.append(
                card
            )
        }


        return fields.contains {
            $0.localizedCaseInsensitiveContains(
                query
            )
        }
    }


    private func matchesType(
        _ transaction:
            TransactionRecord
    ) -> Bool {

        selectedType ==
            "全部类型" ||
        transaction.type.rawValue ==
            selectedType
    }


    private func matchesCategory(
        _ transaction:
            TransactionRecord
    ) -> Bool {

        selectedCategory ==
            "全部分类" ||
        transaction.category ==
            selectedCategory
    }


    private func matchesAccount(
        _ transaction:
            TransactionRecord
    ) -> Bool {

        guard
            let selectedAccountID
        else {

            return true
        }


        return
            transaction.accountID ==
                selectedAccountID ||
            transaction.targetAccountID ==
                selectedAccountID
    }


    private func matchesCard(
        _ transaction:
            TransactionRecord
    ) -> Bool {

        guard
            let selectedCardID
        else {

            return true
        }


        return
            transaction.bankCardID ==
            selectedCardID
    }


    private func matchesDate(
        _ date:
            Date
    ) -> Bool {

        let calendar =
            AppTime.calendar

        let now =
            Date()


        switch dateFilter {

        case .all:

            return true


        case .thisMonth:

            return calendar.isDate(
                date,
                equalTo:
                    now,
                toGranularity:
                    .month
            )


        case .lastMonth:

            guard
                let lastMonth =
                    calendar.date(
                        byAdding:
                            .month,
                        value:
                            -1,
                        to:
                            now
                    )
            else {

                return false
            }


            return calendar.isDate(
                date,
                equalTo:
                    lastMonth,
                toGranularity:
                    .month
            )


        case .recentThreeMonths:

            guard
                let start =
                    calendar.date(
                        byAdding:
                            .month,
                        value:
                            -3,
                        to:
                            now
                    )
            else {

                return true
            }


            return
                date >=
                start


        case .thisYear:

            return calendar.isDate(
                date,
                equalTo:
                    now,
                toGranularity:
                    .year
            )
        }
    }


    private func monthText(
        _ date:
            Date
    ) -> String {

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
            "yyyy年M月"

        return formatter.string(
            from:
                date
        )
    }


    private func accountName(
        _ id:
            UUID
    ) -> String? {

        accounts.first {
            $0.id ==
                id
        }?
        .name
    }


    private func cardName(
        _ id:
            UUID
    ) -> String? {

        cards.first {
            $0.id ==
                id
        }
        .map {
            "\($0.bankName) •••• \($0.lastFourDigits)"
        }
    }


    private func deleteTransaction(
        _ transaction:
            TransactionRecord
    ) {

        _ =
            TransactionService
                .delete(
                    transaction,
                    accounts:
                        accounts,
                    cards:
                        cards,
                    context:
                        modelContext
                )
    }


    private func resetFilters() {

        selectedType =
            "全部类型"

        selectedCategory =
            "全部分类"

        selectedAccountID =
            nil

        selectedCardID =
            nil

        dateFilter =
            .all
    }
}


// MARK: - 流水行

struct TransactionRowView: View {

    @AppStorage(
        CategoryStore
            .expenseKey
    )
    private var expenseCategoriesStored =
        ""

    @AppStorage(
        CategoryStore
            .incomeKey
    )
    private var incomeCategoriesStored =
        ""

    let transaction:
        TransactionRecord

    var showsAmount:
        Bool = true

    var accountName:
        String? = nil

    var targetAccountName:
        String? = nil

    var cardName:
        String? = nil


    private var categoryIcon:
        String {

        CategoryAppearance
            .icon(
                for:
                    transaction,
                expenseStored:
                    expenseCategoriesStored,
                incomeStored:
                    incomeCategoriesStored
            )
    }


    private var categoryColor:
        Color {

        CategoryAppearance
            .color(
                for:
                    transaction
            )
    }


    var body: some View {

        HStack(
            spacing: 12
        ) {

            ZStack {

                Circle()
                    .fill(
                        categoryColor
                    )
                    .frame(
                        width: 44,
                        height: 44
                    )

                Image(
                    systemName:
                        categoryIcon
                )
                .symbolRenderingMode(
                    .monochrome
                )
                .font(
                    .system(
                        size:
                            18,
                        weight:
                            .semibold
                    )
                )
                .foregroundStyle(
                    .white
                )
            }


            VStack(
                alignment: .leading,
                spacing: 4
            ) {

                Text(
                    transaction.category
                )
                .font(
                    .headline
                )

                Text(
                    subtitle
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )

                if !transaction
                    .note
                    .isEmpty {

                    Text(
                        transaction.note
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .lineLimit(1)
                }
            }


            Spacer()


            Text(
                showsAmount
                ? amountText
                : "¥••••"
            )
            .fontWeight(
                .semibold
            )
        }
        .padding(
            .vertical,
            4
        )
    }


    private var subtitle:
        String {

        let sourceText:
            String

        switch transaction.type {

        case .transfer:

            sourceText =
                "\(accountName ?? "未知账户") → \(targetAccountName ?? "未知账户")"

        case .creditExpense:

            sourceText =
                cardName ??
                "未知信用卡"

        case .creditRepayment:

            sourceText =
                "\(accountName ?? "未知账户") → \(cardName ?? "未知信用卡")"

        case .expense,
             .income,
             .adjustment:

            sourceText =
                accountName ??
                "未知账户"
        }

        let foreignText:
            String


        if transaction.currencyCode !=
            "CNY",
           let originalAmount =
            transaction.originalAmount {

            foreignText =
                " · \(originalAmount.formatted(.number.precision(.fractionLength(0...2)))) \(transaction.currencyCode)"

        } else {

            foreignText =
                ""
        }


        return
            "\(sourceText)\(foreignText) · \(AppTime.listDateTime(transaction.date))"
    }


    private var amountText:
        String {

        switch transaction.type {

        case .expense,
             .creditExpense:

            return
                "-\(abs(transaction.amount).formatted(.currency(code: "CNY")))"

        case .income:

            return
                "+\(abs(transaction.amount).formatted(.currency(code: "CNY")))"

        case .transfer,
             .creditRepayment:

            return
                abs(transaction.amount)
                    .formatted(
                        .currency(
                            code: "CNY"
                        )
                    )

        case .adjustment:

            if transaction.amount > 0 {

                return
                    "+\(transaction.amount.formatted(.currency(code: "CNY")))"

            } else {

                return
                    transaction.amount
                        .formatted(
                            .currency(
                                code: "CNY"
                            )
                        )
            }
        }
    }
}


// MARK: - 流水详情

struct TransactionDetailView: View {

    let transaction:
        TransactionRecord

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.modelContext)
    private var modelContext

    @Query(
        sort: \Account.createdAt
    )
    private var accounts:
        [Account]

    @Query(
        sort: \BankCard.createdAt
    )
    private var cards:
        [BankCard]

    @State
    private var showEdit =
        false

    @State
    private var showDeleteConfirmation =
        false

    @State
    private var showDeleteError =
        false


    var body: some View {

        List {

            Section {

                LabeledContent(
                    "类型",
                    value:
                        transaction
                            .type
                            .rawValue
                )

                LabeledContent(
                    "金额"
                ) {

                    Text(
                        displayAmount
                    )
                    .fontWeight(
                        .semibold
                    )
                }

                if transaction.currencyCode !=
                    "CNY",
                   let originalAmount =
                    transaction.originalAmount {

                    LabeledContent(
                        "原币金额"
                    ) {

                        Text(
                            originalAmount,
                            format:
                                .currency(
                                    code:
                                        transaction.currencyCode
                                )
                        )
                    }


                    if let rate =
                        transaction.exchangeRateToCNY {

                        LabeledContent(
                            "记账汇率",
                            value:
                                "1 \(transaction.currencyCode) ≈ ¥\(rate.formatted(.number.precision(.fractionLength(4))))"
                        )
                    }
                }


                LabeledContent(
                    "分类",
                    value:
                        transaction.category
                )
            }


            transactionSourceSection


            Section("时间") {

                LabeledContent(
                    "日期"
                ) {

                    Text(
                        AppTime.detailDateTime(
                            transaction.date
                        )
                    )
                }
            }


            if !transaction
                .note
                .isEmpty {

                Section("备注") {

                    Text(
                        transaction.note
                    )
                }
            }


            Section {

                if canEdit {

                    Button {

                        showEdit =
                            true

                    } label: {

                        Label(
                            "编辑账单",
                            systemImage:
                                "pencil"
                        )
                    }
                }

                Button(
                    role:
                        .destructive
                ) {

                    showDeleteConfirmation =
                        true

                } label: {

                    Label(
                        "删除账单",
                        systemImage:
                            "trash"
                    )
                }
            }
        }
        .navigationTitle(
            "账单详情"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .sheet(
            isPresented:
                $showEdit
        ) {

            EditTransactionView(
                transaction:
                    transaction
            )
        }
        .confirmationDialog(
            "删除这笔账单？",
            isPresented:
                $showDeleteConfirmation,
            titleVisibility:
                .visible
        ) {

            Button(
                "删除",
                role:
                    .destructive
            ) {

                deleteTransaction()
            }

            Button(
                "取消",
                role:
                    .cancel
            ) {}

        } message: {

            Text(
                "删除后会同步恢复账户余额或信用卡欠款。"
            )
        }
        .alert(
            "删除失败",
            isPresented:
                $showDeleteError
        ) {

            Button("好的") {}

        } message: {

            Text(
                "当前账户或信用卡状态无法安全撤销这笔记录。"
            )
        }
    }


    @ViewBuilder
    private var transactionSourceSection:
        some View {

        switch transaction.type {

        case .creditExpense:

            Section("信用卡") {

                LabeledContent(
                    "信用卡",
                    value:
                        cardName(
                            transaction.bankCardID
                        )
                )
            }

        case .creditRepayment:

            Section("还款") {

                LabeledContent(
                    "还款账户",
                    value:
                        accountName(
                            transaction.accountID
                        )
                )

                LabeledContent(
                    "信用卡",
                    value:
                        cardName(
                            transaction.bankCardID
                        )
                )
            }

        case .transfer:

            Section("账户") {

                LabeledContent(
                    "转出账户",
                    value:
                        accountName(
                            transaction.accountID
                        )
                )

                if let targetID =
                    transaction.targetAccountID {

                    LabeledContent(
                        "转入账户",
                        value:
                            accountName(
                                targetID
                            )
                    )
                }
            }

        case .expense,
             .income,
             .adjustment:

            Section("账户") {

                LabeledContent(
                    "账户",
                    value:
                        accountName(
                            transaction.accountID
                        )
                )
            }
        }
    }


    private var canEdit:
        Bool {

        transaction.type ==
            .expense ||
        transaction.type ==
            .income ||
        transaction.type ==
            .transfer
    }


    private var displayAmount:
        String {

        switch transaction.type {

        case .expense,
             .creditExpense:

            return
                "-\(abs(transaction.amount).formatted(.currency(code: "CNY")))"

        case .income:

            return
                "+\(abs(transaction.amount).formatted(.currency(code: "CNY")))"

        case .transfer,
             .creditRepayment:

            return
                abs(transaction.amount)
                    .formatted(
                        .currency(
                            code: "CNY"
                        )
                    )

        case .adjustment:

            return
                transaction.amount
                    .formatted(
                        .currency(
                            code: "CNY"
                        )
                    )
        }
    }


    private func accountName(
        _ id: UUID
    ) -> String {

        accounts.first {
            $0.id == id
        }?.name ??
        "未知账户"
    }


    private func cardName(
        _ id: UUID?
    ) -> String {

        guard let id
        else {
            return "未知信用卡"
        }

        guard let card =
            cards.first(
                where: {
                    $0.id == id
                }
            )
        else {
            return "未知信用卡"
        }

        return
            "\(card.bankName) •••• \(card.lastFourDigits)"
    }


    private func deleteTransaction() {

        let success =
            TransactionService.delete(
                transaction,
                accounts:
                    accounts,
                cards:
                    cards,
                context:
                    modelContext
            )

        if success {

            dismiss()

        } else {

            showDeleteError =
                true
        }
    }
}


// MARK: - 编辑普通流水

struct EditTransactionView: View {

    let transaction:
        TransactionRecord

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.modelContext)
    private var modelContext

    @Query(
        sort: \Account.createdAt
    )
    private var accounts:
        [Account]

    @State
    private var type:
        TransactionType

    @State
    private var amountText:
        String

    @State
    private var category:
        String

    @State
    private var sourceAccountID:
        UUID?

    @State
    private var targetAccountID:
        UUID?

    @State
    private var note:
        String

    @State
    private var date:
        Date

    @State
    private var showError =
        false

    @FocusState
    private var isAmountFocused:
        Bool


    private let expenseCategories = [
        "餐饮",
        "交通",
        "购物",
        "娱乐",
        "居住",
        "医疗",
        "数码",
        "衣物",
        "日用",
        "其他"
    ]

    private let incomeCategories = [
        "工资",
        "奖金",
        "兼职",
        "理财",
        "红包",
        "报销",
        "其他"
    ]


    init(
        transaction:
            TransactionRecord
    ) {

        self.transaction =
            transaction

        _type =
            State(
                initialValue:
                    transaction.type
            )

        _amountText =
            State(
                initialValue:
                    String(
                        format:
                            "%.2f",
                        abs(
                            transaction.amount
                        )
                    )
            )

        _category =
            State(
                initialValue:
                    transaction.category
            )

        _sourceAccountID =
            State(
                initialValue:
                    transaction.accountID
            )

        _targetAccountID =
            State(
                initialValue:
                    transaction.targetAccountID
            )

        _note =
            State(
                initialValue:
                    transaction.note
            )

        _date =
            State(
                initialValue:
                    transaction.date
            )
    }


    var body: some View {

        NavigationStack {

            Form {

                Section {

                    Picker(
                        "类型",
                        selection:
                            $type
                    ) {

                        Text("支出")
                            .tag(
                                TransactionType.expense
                            )

                        Text("收入")
                            .tag(
                                TransactionType.income
                            )

                        Text("转账")
                            .tag(
                                TransactionType.transfer
                            )
                    }
                    .pickerStyle(
                        .segmented
                    )
                }


                Section("金额") {

                    HStack {

                        Text("¥")
                            .foregroundStyle(
                                .secondary
                            )

                        TextField(
                            "0.00",
                            text:
                                $amountText
                        )
                        .keyboardType(
                            .decimalPad
                        )
                        .focused(
                            $isAmountFocused
                        )
                    }
                }


                if type !=
                    .transfer {

                    Section("分类") {

                        Picker(
                            "分类",
                            selection:
                                $category
                        ) {

                            ForEach(
                                currentCategories,
                                id: \.self
                            ) { item in

                                Text(item)
                                    .tag(item)
                            }
                        }
                    }
                }


                Section(
                    type == .transfer
                    ? "转出账户"
                    : "账户"
                ) {

                    Picker(
                        "选择账户",
                        selection:
                            $sourceAccountID
                    ) {

                        Text("请选择")
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
                }


                if type ==
                    .transfer {

                    Section("转入账户") {

                        Picker(
                            "选择账户",
                            selection:
                                $targetAccountID
                        ) {

                            Text("请选择")
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
                    }
                }


                Section("其他") {

                    DatePicker(
                        "日期",
                        selection:
                            $date
                    )

                    TextField(
                        "备注",
                        text:
                            $note
                    )
                }
            }
            .scrollDismissesKeyboard(
                .interactively
            )
            .navigationTitle(
                "编辑账单"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {

                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {

                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {

                    Button("保存") {
                        save()
                    }
                    .disabled(
                        !canSave
                    )
                }

                ToolbarItemGroup(
                    placement:
                        .keyboard
                ) {

                    Spacer()

                    Button("完成") {

                        isAmountFocused =
                            false
                    }
                }
            }
            .onChange(
                of: type
            ) { _ in

                if type == .transfer {

                    category =
                        "转账"

                } else {

                    targetAccountID =
                        nil

                    category =
                        currentCategories.first ??
                        "其他"
                }
            }
            .alert(
                "修改失败",
                isPresented:
                    $showError
            ) {

                Button("好的") {}

            } message: {

                Text(
                    "请检查金额和账户是否正确"
                )
            }
        }
    }


    private var currentCategories:
        [String] {

        switch type {

        case .expense:
            return expenseCategories

        case .income:
            return incomeCategories

        default:
            return []
        }
    }


    private var amount:
        Double? {

        Double(
            amountText
                .replacingOccurrences(
                    of: ",",
                    with: "."
                )
        )
    }


    private var canSave:
        Bool {

        guard
            let amount,
            amount > 0,
            sourceAccountID != nil
        else {
            return false
        }

        if type == .transfer {

            return
                targetAccountID != nil &&
                targetAccountID !=
                    sourceAccountID
        }

        return
            type == .expense ||
            type == .income
    }


    private func save() {

        isAmountFocused =
            false

        guard
            let amount,
            let sourceID =
                sourceAccountID
        else {
            return
        }

        let success =
            TransactionService.update(
                transaction,
                type:
                    type,
                amount:
                    amount,
                category:
                    type == .transfer
                    ? "转账"
                    : category,
                accountID:
                    sourceID,
                targetAccountID:
                    type == .transfer
                    ? targetAccountID
                    : nil,
                note:
                    note,
                date:
                    date,
                accounts:
                    accounts,
                context:
                    modelContext
            )

        if success {

            dismiss()

        } else {

            showError =
                true
        }
    }
}
