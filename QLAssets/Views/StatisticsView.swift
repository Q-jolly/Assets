import SwiftUI
import SwiftData
import Charts


struct StatisticsView: View {

    @Query(
        sort: \TransactionRecord.date
    )
    private var transactions:
        [TransactionRecord]

    @AppStorage(
        "monthlyBudgetCNY"
    )
    private var monthlyBudget:
        Double = 0

    @AppStorage(
        CategoryStore
            .expenseKey
    )
    private var expenseCategoriesStored =
        ""

    @AppStorage(
        CategoryBudgetStore
            .storageKey
    )
    private var categoryBudgetsStored =
        ""

    @State
    private var showBudgetEditor =
        false

    @State
    private var showCategoryBudgetEditor =
        false

    @State
    private var selectedMonth:
        Date =
            AppTime.calendar.dateInterval(
                of: .month,
                for: Date()
            )?.start
            ?? Date()

    @State
    private var selectedDay:
        Date?

    @State
    private var selectedTrendMonth:
        Date?

    @State
    private var selectedCategoryID:
        String?


    // MARK: - 月份

    private var currentMonthStart:
        Date {

        AppTime.calendar.dateInterval(
            of: .month,
            for: Date()
        )?.start
        ?? Date()
    }


    private var monthStart:
        Date {

        AppTime.calendar.dateInterval(
            of: .month,
            for: selectedMonth
        )?.start
        ?? selectedMonth
    }


    private var monthEnd:
        Date {

        AppTime.calendar.date(
            byAdding: .month,
            value: 1,
            to: monthStart
        )
        ?? monthStart
    }


    private var previousMonthStart:
        Date {

        AppTime.calendar.date(
            byAdding: .month,
            value: -1,
            to: monthStart
        )
        ?? monthStart
    }


    private var previousMonthEnd:
        Date {

        monthStart
    }


    private var lastYearMonthStart:
        Date {

        AppTime.calendar.date(
            byAdding: .year,
            value: -1,
            to: monthStart
        )
        ?? monthStart
    }


    private var lastYearMonthEnd:
        Date {

        AppTime.calendar.date(
            byAdding: .month,
            value: 1,
            to: lastYearMonthStart
        )
        ?? lastYearMonthStart
    }


    private var isCurrentMonth:
        Bool {

        AppTime.calendar.isDate(
            monthStart,
            equalTo:
                currentMonthStart,
            toGranularity:
                .month
        )
    }


    private var canGoNextMonth:
        Bool {

        monthStart <
        currentMonthStart
    }


    private var monthTitle:
        String {

        monthFormatter.string(
            from: monthStart
        )
    }


    private var monthFormatter:
        DateFormatter {

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

        return formatter
    }


    private func moveMonth(
        by value:
            Int
    ) {

        guard
            let newMonth =
                AppTime.calendar.date(
                    byAdding:
                        .month,
                    value:
                        value,
                    to:
                        monthStart
                )
        else {
            return
        }

        if newMonth >
            currentMonthStart {

            selectedMonth =
                currentMonthStart

        } else {

            selectedMonth =
                newMonth
        }

        selectedDay =
            nil

        selectedTrendMonth =
            nil

        selectedCategoryID =
            nil
    }


    // MARK: - 当前月份数据

    private var monthTransactions:
        [TransactionRecord] {

        transactions.filter {
            $0.date >= monthStart &&
            $0.date < monthEnd
        }
    }


    private var expenseTransactions:
        [TransactionRecord] {

        monthTransactions.filter {
            $0.type == .expense ||
            $0.type == .creditExpense
        }
    }


    private var monthlyExpense:
        Double {

        expenseTransactions
            .reduce(0) {
                $0 + abs($1.amount)
            }
    }


    private var monthlyIncome:
        Double {

        monthTransactions
            .filter {
                $0.type == .income
            }
            .reduce(0) {
                $0 + abs($1.amount)
            }
    }


    private var monthlyBalance:
        Double {

        monthlyIncome -
        monthlyExpense
    }


    // MARK: - 环比 / 同比

    private var previousMonthExpense:
        Double {

        amount(
            type:
                .expense,
            secondaryType:
                .creditExpense,
            from:
                previousMonthStart,
            to:
                previousMonthEnd
        )
    }


    private var previousMonthIncome:
        Double {

        amount(
            type:
                .income,
            secondaryType:
                nil,
            from:
                previousMonthStart,
            to:
                previousMonthEnd
        )
    }


    private var lastYearExpense:
        Double {

        amount(
            type:
                .expense,
            secondaryType:
                .creditExpense,
            from:
                lastYearMonthStart,
            to:
                lastYearMonthEnd
        )
    }


    private var lastYearIncome:
        Double {

        amount(
            type:
                .income,
            secondaryType:
                nil,
            from:
                lastYearMonthStart,
            to:
                lastYearMonthEnd
        )
    }


    private func amount(
        type:
            TransactionType,
        secondaryType:
            TransactionType?,
        from start:
            Date,
        to end:
            Date
    ) -> Double {

        transactions
            .filter { transaction in

                guard
                    transaction.date >= start &&
                    transaction.date < end
                else {
                    return false
                }

                if transaction.type ==
                    type {

                    return true
                }

                if let secondaryType {

                    return
                        transaction.type ==
                        secondaryType
                }

                return false
            }
            .reduce(0) {
                $0 + abs($1.amount)
            }
    }


    private func comparisonText(
        current:
            Double,
        previous:
            Double,
        prefix:
            String
    ) -> String {

        guard previous > 0
        else {

            return
                current > 0
                ? "\(prefix)暂无基数"
                : "\(prefix)暂无数据"
        }

        let percent =
            (
                current -
                previous
            ) /
            previous *
            100

        let direction =
            percent >= 0
            ? "增加"
            : "减少"

        return
            "\(prefix)\(direction) \(abs(percent).formatted(.number.precision(.fractionLength(1))))%"
    }


    // MARK: - 预算

    private var budgetProgress:
        Double {

        guard monthlyBudget > 0
        else {
            return 0
        }

        return min(
            monthlyExpense /
            monthlyBudget,
            1
        )
    }


    private var rawBudgetProgress:
        Double {

        guard monthlyBudget > 0
        else {
            return 0
        }

        return
            monthlyExpense /
            monthlyBudget
    }


    private var budgetRemaining:
        Double {

        monthlyBudget -
        monthlyExpense
    }


    private var budgetStatusText:
        String? {

        guard monthlyBudget > 0
        else {
            return nil
        }

        if rawBudgetProgress >= 1 {

            return
                "已超出预算 \(abs(budgetRemaining).formatted(.currency(code: "CNY")))"

        } else if rawBudgetProgress >= 0.8 {

            return
                "预算已使用 \(Int(rawBudgetProgress * 100))%，建议控制本月后续支出"
        }

        return nil
    }


    // MARK: - 分类预算

    private var expenseCategoryItems:
        [CategoryItem] {

        CategoryStore
            .expenseCategories(
                from:
                    expenseCategoriesStored
            )
    }


    private var categoryBudgets:
        [String: Double] {

        CategoryBudgetStore
            .decode(
                categoryBudgetsStored
            )
    }


    private var configuredCategoryBudgetItems:
        [CategoryItem] {

        expenseCategoryItems
            .filter {
                (
                    categoryBudgets[
                        $0.name
                    ] ??
                    0
                ) >
                0
            }
    }


    private func categoryExpense(
        _ category:
            String
    ) -> Double {

        expenseTransactions
            .filter {
                $0.category ==
                category
            }
            .reduce(0) {
                $0 +
                abs(
                    $1.amount
                )
            }
    }


    // MARK: - 每日支出

    private var dailyExpensePoints:
        [DailyExpensePoint] {

        let grouped =
            Dictionary(
                grouping:
                    expenseTransactions
            ) { transaction in

                AppTime.calendar.startOfDay(
                    for:
                        transaction.date
                )
            }

        return grouped
            .map { date, records in

                DailyExpensePoint(
                    date:
                        date,
                    amount:
                        records.reduce(0) {
                            $0 + abs($1.amount)
                        }
                )
            }
            .sorted {
                $0.date <
                $1.date
            }
    }


    private var selectedDailyExpensePoint:
        DailyExpensePoint? {

        guard let selectedDay
        else {
            return nil
        }

        return dailyExpensePoints
            .first {

                AppTime.calendar
                    .isDate(
                        $0.date,
                        inSameDayAs:
                            selectedDay
                    )
            }
    }


    private func nearestDailyExpenseDate(
        to date:
            Date
    ) -> Date? {

        dailyExpensePoints
            .min {
                lhs,
                rhs in

                abs(
                    lhs.date
                        .timeIntervalSince(
                            date
                        )
                ) <
                abs(
                    rhs.date
                        .timeIntervalSince(
                            date
                        )
                )
            }?
            .date
    }


    private func nearestTrendMonth(
        to date:
            Date
    ) -> Date? {

        let months =
            Dictionary(
                grouping:
                    sixMonthFlowPoints,
                by: {
                    AppTime.calendar
                        .date(
                            from:
                                AppTime.calendar
                                    .dateComponents(
                                        [
                                            .year,
                                            .month
                                        ],
                                        from:
                                            $0.month
                                    )
                        ) ??
                    $0.month
                }
            )
            .keys


        return months.min {
            lhs,
                rhs in

            abs(
                lhs.timeIntervalSince(
                    date
                )
            ) <
            abs(
                rhs.timeIntervalSince(
                    date
                )
            )
        }
    }


    private var selectedDayTransactions:
        [TransactionRecord] {

        guard let selectedDay
        else {
            return []
        }

        return expenseTransactions
            .filter {

                AppTime.calendar.isDate(
                    $0.date,
                    inSameDayAs:
                        selectedDay
                )
            }
            .sorted {
                $0.date >
                $1.date
            }
    }


    private var selectedDayAmount:
        Double {

        selectedDayTransactions
            .reduce(0) {
                $0 + abs($1.amount)
            }
    }


    private var selectedDayTitle:
        String {

        guard let selectedDay
        else {
            return ""
        }

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
            "M月d日"

        return formatter.string(
            from:
                selectedDay
        )
    }


    // MARK: - 分类

    private var categoryExpensePoints:
        [CategoryExpensePoint] {

        let grouped =
            Dictionary(
                grouping:
                    expenseTransactions
            ) {

                $0.category.isEmpty
                ? "未分类"
                : $0.category
            }

        return grouped
            .map { category, records in

                CategoryExpensePoint(
                    category:
                        category,
                    amount:
                        records.reduce(0) {
                            $0 + abs($1.amount)
                        }
                )
            }
            .sorted {
                $0.amount >
                $1.amount
            }
    }


    private var categoryChartSlices:
        [CategoryChartSlice] {

        let colors:
            [Color] = [
                .blue,
                .green,
                .orange,
                .purple,
                .red,
                .teal,
                .yellow,
                .pink,
                .indigo,
                .mint
            ]

        guard monthlyExpense > 0
        else {
            return []
        }

        var startAngle =
            -90.0

        return categoryExpensePoints
            .enumerated()
            .map { index, point in

                let percentage =
                    point.amount /
                    monthlyExpense

                let endAngle =
                    startAngle +
                    percentage *
                    360

                defer {
                    startAngle =
                        endAngle
                }

                return CategoryChartSlice(
                    category:
                        point.category,
                    amount:
                        point.amount,
                    percentage:
                        percentage,
                    startAngle:
                        .degrees(
                            startAngle
                        ),
                    endAngle:
                        .degrees(
                            endAngle
                        ),
                    color:
                        colors[
                            index %
                            colors.count
                        ]
                )
            }
    }


    private var selectedCategorySlice:
        CategoryChartSlice? {

        guard
            let selectedCategoryID
        else {

            return nil
        }

        return categoryChartSlices
            .first {
                $0.id ==
                selectedCategoryID
            }
    }


    private var displayedCategorySlices:
        [CategoryChartSlice] {

        if let selectedCategorySlice {

            return [
                selectedCategorySlice
            ]
        }

        return categoryChartSlices
    }


    private var categoryLegend:
        some View {

        LazyVGrid(
            columns:
                [
                    GridItem(
                        .adaptive(
                            minimum: 86
                        ),
                        spacing: 8,
                        alignment:
                            .leading
                    )
                ],
            alignment:
                .leading,
            spacing:
                8
        ) {

            ForEach(
                categoryChartSlices
            ) { point in

                Button {

                    toggleCategorySelection(
                        point.id
                    )

                } label: {

                    HStack(
                        spacing: 6
                    ) {

                        Circle()
                            .fill(
                                point.color
                            )
                            .frame(
                                width: 10,
                                height: 10
                            )

                        Text(
                            point.category
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            selectedCategoryID ==
                                nil ||
                            selectedCategoryID ==
                                point.id
                            ? .primary
                            : .secondary
                        )
                    }
                    .padding(
                        .horizontal,
                        8
                    )
                    .padding(
                        .vertical,
                        5
                    )
                    .background {

                        if selectedCategoryID ==
                            point.id {

                            Capsule()
                                .fill(
                                    point.color
                                        .opacity(
                                            0.12
                                        )
                                )
                        }
                    }
                }
                .buttonStyle(
                    .plain
                )
            }
        }
    }


    private func toggleCategorySelection(
        _ categoryID:
            String
    ) {

        withAnimation(
            .snappy(
                duration:
                    0.24
            )
        ) {

            if selectedCategoryID ==
                categoryID {

                selectedCategoryID =
                    nil

            } else {

                selectedCategoryID =
                    categoryID
            }
        }
    }


    // MARK: - 趋势

    private var sixMonthFlowPoints:
        [MonthlyFlowPoint] {

        guard
            let firstMonth =
                AppTime.calendar.date(
                    byAdding:
                        .month,
                    value:
                        -5,
                    to:
                        monthStart
                )
        else {
            return []
        }

        return (0..<6)
            .flatMap { offset -> [MonthlyFlowPoint] in

                guard
                    let start =
                        AppTime.calendar.date(
                            byAdding:
                                .month,
                            value:
                                offset,
                            to:
                                firstMonth
                        ),
                    let end =
                        AppTime.calendar.date(
                            byAdding:
                                .month,
                            value:
                                1,
                            to:
                                start
                        )
                else {
                    return []
                }

                let records =
                    transactions.filter {
                        $0.date >= start &&
                        $0.date < end
                    }

                let expense =
                    records
                        .filter {
                            $0.type == .expense ||
                            $0.type == .creditExpense
                        }
                        .reduce(0) {
                            $0 + abs($1.amount)
                        }

                let income =
                    records
                        .filter {
                            $0.type == .income
                        }
                        .reduce(0) {
                            $0 + abs($1.amount)
                        }

                return [
                    MonthlyFlowPoint(
                        month:
                            start,
                        type:
                            "支出",
                        amount:
                            expense
                    ),
                    MonthlyFlowPoint(
                        month:
                            start,
                        type:
                            "收入",
                        amount:
                            income
                    )
                ]
            }
    }


    private var selectedTrendPoints:
        [MonthlyFlowPoint] {

        guard let selectedTrendMonth
        else {
            return []
        }

        let selectedComponents =
            AppTime.calendar
                .dateComponents(
                    [
                        .year,
                        .month
                    ],
                    from:
                        selectedTrendMonth
                )

        return sixMonthFlowPoints
            .filter {

                let components =
                    AppTime.calendar
                        .dateComponents(
                            [
                                .year,
                                .month
                            ],
                            from:
                                $0.month
                        )

                return
                    components.year ==
                    selectedComponents.year &&
                    components.month ==
                    selectedComponents.month
            }
    }


    private var selectedTrendExpense:
        Double {

        selectedTrendPoints
            .first {
                $0.type ==
                "支出"
            }?
            .amount ??
            0
    }


    private var selectedTrendIncome:
        Double {

        selectedTrendPoints
            .first {
                $0.type ==
                "收入"
            }?
            .amount ??
            0
    }


    private var selectedTrendTitle:
        String {

        guard let selectedTrendMonth
        else {
            return ""
        }

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
                selectedTrendMonth
        )
    }


    var body: some View {

        // 统计页交互回归保护：
        // - 饼图：扇区/图例可点选，选中后突出并过滤明细，再点一次取消。
        // - 每日柱状图：chartXSelection 选日期并显示具体金额。
        // - 六个月柱状图：chartXSelection 选月份并显示收入/支出具体金额。
        // 后续改统计页布局时不要替换成静态 Chart。
        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 22
            ) {

                monthSelector

                monthSummaryCard

                comparisonSection

                budgetCard

                categoryBudgetCard

                dailyExpenseSection

                categorySection

                sixMonthSection

                monthBillEntry
            }
            .padding()
        }
        .navigationTitle(
            "收支统计"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .sheet(
            isPresented:
                $showBudgetEditor
        ) {

            BudgetEditorView(
                monthlyBudget:
                    $monthlyBudget
            )
        }
        .sheet(
            isPresented:
                $showCategoryBudgetEditor
        ) {

            CategoryBudgetEditorView(
                stored:
                    $categoryBudgetsStored,
                categories:
                    expenseCategoryItems
            )
        }
    }


    // MARK: - 月份切换

    private var monthSelector:
        some View {

        HStack(
            spacing: 14
        ) {

            Button {

                moveMonth(
                    by: -1
                )

            } label: {

                Image(
                    systemName:
                        "chevron.left"
                )
                .frame(
                    width: 34,
                    height: 34
                )
            }
            .buttonStyle(
                .bordered
            )


            Spacer()


            VStack(
                spacing: 3
            ) {

                Text(
                    monthTitle
                )
                .font(
                    .headline
                )

                if !isCurrentMonth {

                    Button(
                        "回到本月"
                    ) {

                        selectedMonth =
                            currentMonthStart

                        selectedDay =
                            nil

                        selectedCategoryID =
                            nil
                    }
                    .font(
                        .caption
                    )
                }
            }


            Spacer()


            Button {

                moveMonth(
                    by: 1
                )

            } label: {

                Image(
                    systemName:
                        "chevron.right"
                )
                .frame(
                    width: 34,
                    height: 34
                )
            }
            .buttonStyle(
                .bordered
            )
            .disabled(
                !canGoNextMonth
            )
        }
    }


    // MARK: - 月度摘要

    private var monthSummaryCard:
        some View {

        VStack(
            alignment: .leading,
            spacing: 16
        ) {

            HStack {

                Text(
                    monthTitle
                )
                .font(
                    .headline
                )

                Spacer()

                Text(
                    "\(monthTransactions.count) 笔"
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }


            HStack(
                spacing: 12
            ) {

                metricCard(
                    title:
                        "支出",
                    value:
                        monthlyExpense,
                    icon:
                        "arrow.up.right"
                )

                metricCard(
                    title:
                        "收入",
                    value:
                        monthlyIncome,
                    icon:
                        "arrow.down.left"
                )
            }


            HStack {

                Text(
                    "本月结余"
                )
                .foregroundStyle(
                    .secondary
                )

                Spacer()

                Text(
                    monthlyBalance,
                    format:
                        .currency(
                            code:
                                "CNY"
                        )
                )
                .fontWeight(
                    .semibold
                )
            }
        }
        .padding()
        .background(
            Color(
                .secondarySystemBackground
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style:
                    .continuous
            )
        )
    }


    private func metricCard(
        title:
            String,
        value:
            Double,
        icon:
            String
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 8
        ) {

            Label(
                title,
                systemImage:
                    icon
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
                0.72
            )
        }
        .frame(
            maxWidth:
                .infinity,
            alignment:
                .leading
        )
        .padding(14)
        .background(
            Color(
                .tertiarySystemBackground
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16,
                style:
                    .continuous
            )
        )
    }


    // MARK: - 环比同比

    private var comparisonSection:
        some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            Text(
                "收支对比"
            )
            .font(
                .title3.bold()
            )


            comparisonRow(
                title:
                    "支出",
                current:
                    monthlyExpense,
                previous:
                    previousMonthExpense,
                lastYear:
                    lastYearExpense
            )

            Divider()

            comparisonRow(
                title:
                    "收入",
                current:
                    monthlyIncome,
                previous:
                    previousMonthIncome,
                lastYear:
                    lastYearIncome
            )
        }
        .padding()
        .background(
            Color(
                .secondarySystemBackground
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style:
                    .continuous
            )
        )
    }


    private func comparisonRow(
        title:
            String,
        current:
            Double,
        previous:
            Double,
        lastYear:
            Double
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 7
        ) {

            HStack {

                Text(
                    title
                )
                .fontWeight(
                    .medium
                )

                Spacer()

                Text(
                    current,
                    format:
                        .currency(
                            code:
                                "CNY"
                        )
                )
                .fontWeight(
                    .semibold
                )
            }


            Text(
                comparisonText(
                    current:
                        current,
                    previous:
                        previous,
                    prefix:
                        "环比"
                )
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )


            Text(
                comparisonText(
                    current:
                        current,
                    previous:
                        lastYear,
                    prefix:
                        "同比"
                )
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )
        }
    }


    // MARK: - 预算

    private var budgetCard:
        some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            HStack {

                Text(
                    "月度预算"
                )
                .font(
                    .title3.bold()
                )

                Spacer()

                Button(
                    monthlyBudget > 0
                    ? "调整"
                    : "设置"
                ) {

                    showBudgetEditor =
                        true
                }
                .font(
                    .subheadline
                )
            }


            if monthlyBudget > 0 {

                ProgressView(
                    value:
                        budgetProgress
                )


                HStack {

                    VStack(
                        alignment: .leading,
                        spacing: 3
                    ) {

                        Text(
                            "已使用"
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )

                        Text(
                            monthlyExpense,
                            format:
                                .currency(
                                    code:
                                        "CNY"
                                )
                        )
                        .fontWeight(
                            .semibold
                        )
                    }


                    Spacer()


                    VStack(
                        alignment: .trailing,
                        spacing: 3
                    ) {

                        Text(
                            budgetRemaining >= 0
                            ? "剩余"
                            : "超出"
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )

                        Text(
                            abs(
                                budgetRemaining
                            ),
                            format:
                                .currency(
                                    code:
                                        "CNY"
                                )
                        )
                        .fontWeight(
                            .semibold
                        )
                    }
                }


                if let budgetStatusText {

                    Label(
                        budgetStatusText,
                        systemImage:
                            rawBudgetProgress >= 1
                            ? "exclamationmark.triangle.fill"
                            : "exclamationmark.circle.fill"
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        rawBudgetProgress >= 1
                        ? .red
                        : .orange
                    )
                }


                Text(
                    "预算 ¥\(monthlyBudget.formatted(.number.precision(.fractionLength(2))))"
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )

            } else {

                Text(
                    "设置月度支出预算后，可以查看预算使用进度和超支提醒。"
                )
                .font(
                    .subheadline
                )
                .foregroundStyle(
                    .secondary
                )
            }
        }
        .padding()
        .background(
            Color(
                .secondarySystemBackground
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style:
                    .continuous
            )
        )
    }


    // MARK: - 分类预算

    private var categoryBudgetCard:
        some View {

        VStack(
            alignment:
                .leading,
            spacing:
                14
        ) {

            HStack {

                VStack(
                    alignment:
                        .leading,
                    spacing:
                        3
                ) {

                    Text(
                        "分类预算"
                    )
                    .font(
                        .title3
                            .bold()
                    )

                    Text(
                        "给餐饮、购物等分类单独设置预算"
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }


                Spacer()


                Button(
                    configuredCategoryBudgetItems
                        .isEmpty
                    ? "设置"
                    : "管理"
                ) {

                    showCategoryBudgetEditor =
                        true
                }
                .font(
                    .subheadline
                )
            }


            if configuredCategoryBudgetItems
                .isEmpty {

                Text(
                    "还没有设置分类预算。设置后，可以直接看到每个分类的使用进度、剩余额度和超支状态。"
                )
                .font(
                    .subheadline
                )
                .foregroundStyle(
                    .secondary
                )

            } else {

                VStack(
                    spacing:
                        16
                ) {

                    ForEach(
                        configuredCategoryBudgetItems
                    ) { item in

                        let budget =
                            categoryBudgets[
                                item.name
                            ] ??
                            0

                        let spent =
                            categoryExpense(
                                item.name
                            )

                        let rawProgress =
                            budget >
                            0
                            ? spent /
                                budget
                            : 0

                        let remaining =
                            budget -
                            spent


                        VStack(
                            alignment:
                                .leading,
                            spacing:
                                7
                        ) {

                            HStack(
                                spacing:
                                    10
                            ) {

                                Image(
                                    systemName:
                                        item.icon
                                )
                                .frame(
                                    width:
                                        24
                                )

                                Text(
                                    item.name
                                )
                                .fontWeight(
                                    .medium
                                )


                                Spacer()


                                Text(
                                    "\(spent.formatted(.currency(code: "CNY"))) / \(budget.formatted(.currency(code: "CNY")))"
                                )
                                .font(
                                    .caption
                                )
                                .foregroundStyle(
                                    rawProgress >=
                                        1
                                    ? .red
                                    : .secondary
                                )
                            }


                            ProgressView(
                                value:
                                    min(
                                        rawProgress,
                                        1
                                    )
                            )
                            .tint(
                                rawProgress >=
                                    1
                                ? .red
                                : rawProgress >=
                                    0.8
                                    ? .orange
                                    : .accentColor
                            )


                            HStack {

                                Text(
                                    "\(Int(rawProgress * 100))%"
                                )
                                .font(
                                    .caption2
                                )
                                .foregroundStyle(
                                    .secondary
                                )


                                Spacer()


                                Text(
                                    remaining >=
                                        0
                                    ? "剩余 \(remaining.formatted(.currency(code: "CNY")))"
                                    : "超出 \(abs(remaining).formatted(.currency(code: "CNY")))"
                                )
                                .font(
                                    .caption2
                                )
                                .foregroundStyle(
                                    remaining <
                                        0
                                    ? .red
                                    : .secondary
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            Color(
                .secondarySystemBackground
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    20,
                style:
                    .continuous
            )
        )
    }


    // MARK: - 每日支出

    private var dailyExpenseSection:
        some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            HStack {

                Text(
                    "每日支出"
                )
                .font(
                    .title3.bold()
                )

                Spacer()

                if selectedDay != nil {

                    Button(
                        "取消选择"
                    ) {

                        selectedDay =
                            nil
                    }
                    .font(
                        .caption
                    )
                }
            }


            if dailyExpensePoints.isEmpty {

                emptyChart(
                    text:
                        "这个月还没有支出记录"
                )

            } else {

                Chart {

                    ForEach(
                        dailyExpensePoints
                    ) { point in

                        let isSelected =
                            selectedDay !=
                            nil &&
                            AppTime.calendar
                                .isDate(
                                    point.date,
                                    inSameDayAs:
                                        selectedDay ??
                                        point.date
                                )

                        BarMark(
                            x:
                                .value(
                                    "日期",
                                    point.date,
                                    unit:
                                        .day
                                ),
                            y:
                                .value(
                                    "支出",
                                    point.amount
                                )
                        )
                        .cornerRadius(
                            4
                        )
                        .foregroundStyle(
                            isSelected
                            ? Color.accentColor
                            : selectedDay ==
                                nil
                                ? Color.accentColor
                                    .opacity(
                                        0.82
                                    )
                                : Color.accentColor
                                    .opacity(
                                        0.28
                                    )
                        )
                    }


                    if let point =
                        selectedDailyExpensePoint {

                        RuleMark(
                            x:
                                .value(
                                    "选择日期",
                                    point.date,
                                    unit:
                                        .day
                                )
                        )
                        .foregroundStyle(
                            .secondary
                        )
                        .annotation(
                            position:
                                .top,
                            spacing:
                                8
                        ) {

                            VStack(
                                spacing:
                                    2
                            ) {

                                Text(
                                    selectedDayTitle
                                )
                                .font(
                                    .caption2
                                )
                                .foregroundStyle(
                                    .secondary
                                )

                                Text(
                                    point.amount,
                                    format:
                                        .currency(
                                            code:
                                                "CNY"
                                        )
                                )
                                .font(
                                    .caption
                                        .bold()
                                )
                            }
                            .padding(
                                .horizontal,
                                9
                            )
                            .padding(
                                .vertical,
                                6
                            )
                            .background(
                                .regularMaterial
                            )
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius:
                                        9,
                                    style:
                                        .continuous
                                )
                            )
                        }
                    }
                }
                .frame(
                    height: 210
                )
                .chartXAxis {

                    AxisMarks(
                        values:
                            .stride(
                                by: .day,
                                count: 5
                            )
                    ) { _ in

                        AxisGridLine()

                        AxisTick()

                        AxisValueLabel(
                            format:
                                .dateTime.day()
                        )
                    }
                }
                .chartOverlay {
                    proxy in

                    GeometryReader {
                        geometry in

                        Rectangle()
                            .fill(
                                Color.clear
                            )
                            .contentShape(
                                Rectangle()
                            )
                            .gesture(
                                DragGesture(
                                    minimumDistance:
                                        0
                                )
                                .onEnded {
                                    value in

                                    guard
                                        let plotFrame =
                                            proxy.plotFrame
                                    else {
                                        return
                                    }


                                    let frame =
                                        geometry[
                                            plotFrame
                                        ]


                                    guard
                                        frame.contains(
                                            value.location
                                        )
                                    else {
                                        return
                                    }


                                    let x =
                                        value.location.x -
                                        frame.minX


                                    guard
                                        let rawDate:
                                            Date =
                                                proxy.value(
                                                    atX:
                                                        x
                                                ),
                                        let nearest =
                                            nearestDailyExpenseDate(
                                                to:
                                                    rawDate
                                            )
                                    else {
                                        return
                                    }


                                    if let selectedDay,
                                       AppTime.calendar
                                        .isDate(
                                            selectedDay,
                                            inSameDayAs:
                                                nearest
                                        ) {

                                        self.selectedDay =
                                            nil

                                    } else {

                                        self.selectedDay =
                                            nearest

                                        HapticFeedback
                                            .selection()
                                    }
                                }
                            )
                    }
                }


                if selectedDay != nil {

                    selectedDayDetail
                }
            }
        }
        .padding()
        .background(
            Color(
                .secondarySystemBackground
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style:
                    .continuous
            )
        )
    }


    private var selectedDayDetail:
        some View {

        VStack(
            alignment: .leading,
            spacing: 10
        ) {

            Divider()


            HStack {

                Text(
                    selectedDayTitle
                )
                .fontWeight(
                    .medium
                )

                Spacer()

                Text(
                    selectedDayAmount,
                    format:
                        .currency(
                            code:
                                "CNY"
                        )
                )
                .fontWeight(
                    .semibold
                )
            }


            if selectedDayTransactions.isEmpty {

                Text(
                    "这一天没有支出账单"
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )

            } else {

                ForEach(
                    selectedDayTransactions
                        .prefix(5)
                ) { transaction in

                    NavigationLink {

                        TransactionDetailView(
                            transaction:
                                transaction
                        )

                    } label: {

                        compactTransactionRow(
                            transaction
                        )
                    }
                    .buttonStyle(
                        .plain
                    )
                }
            }
        }
    }


    // MARK: - 分类

    private var categorySection:
        some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            Text(
                "支出分类"
            )
            .font(
                .title3.bold()
            )


            if categoryExpensePoints.isEmpty {

                emptyChart(
                    text:
                        "记录支出后会显示分类占比"
                )

            } else {

                CategoryDonutBreakdownView(
                    points:
                        categoryChartSlices,
                    selectedCategoryID:
                        $selectedCategoryID
                )
                .frame(
                    height: 390
                )


                categoryLegend


                VStack(
                    spacing: 2
                ) {

                    ForEach(
                        displayedCategorySlices
                    ) { point in

                        NavigationLink {

                            CategoryTransactionsView(
                                category:
                                    point.category,
                                monthStart:
                                    monthStart,
                                monthEnd:
                                    monthEnd
                            )

                        } label: {

                            HStack(
                                spacing: 12
                            ) {

                                Circle()
                                    .fill(
                                        point.color
                                    )
                                    .frame(
                                        width: 11,
                                        height: 11
                                    )


                                VStack(
                                    alignment:
                                        .leading,
                                    spacing: 2
                                ) {

                                    Text(
                                        point.category
                                    )

                                    if monthlyExpense >
                                        0 {

                                        Text(
                                            "\(point.amount / monthlyExpense * 100, format: .number.precision(.fractionLength(1)))%"
                                        )
                                        .font(
                                            .caption2
                                        )
                                        .foregroundStyle(
                                            .secondary
                                        )
                                    }
                                }


                                Spacer()


                                Text(
                                    point.amount,
                                    format:
                                        .currency(
                                            code:
                                                "CNY"
                                        )
                                )
                                .fontWeight(
                                    .medium
                                )


                                Image(
                                    systemName:
                                        "chevron.right"
                                )
                                .font(
                                    .caption2.bold()
                                )
                                .foregroundStyle(
                                    .secondary
                                )
                            }
                            .padding(
                                .vertical,
                                7
                            )
                        }
                        .buttonStyle(
                            .plain
                        )
                    }
                }
            }
        }
        .padding()
        .background(
            Color(
                .secondarySystemBackground
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style:
                    .continuous
            )
        )
        .onDisappear {

            selectedCategoryID =
                nil
        }
    }


    // MARK: - 六个月趋势

    private var sixMonthSection:
        some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            Text(
                "截至所选月份近 6 个月收支"
            )
            .font(
                .title3.bold()
            )


            Chart {

                ForEach(
                    sixMonthFlowPoints
                ) { point in

                    BarMark(
                        x:
                            .value(
                                "月份",
                                point.month,
                                unit:
                                    .month
                            ),
                        y:
                            .value(
                                "金额",
                                point.amount
                            )
                    )
                    .position(
                        by:
                            .value(
                                "类型",
                                point.type
                            )
                    )
                    .foregroundStyle(
                        by:
                            .value(
                                "类型",
                                point.type
                            )
                    )
                    .opacity(
                        selectedTrendMonth ==
                            nil
                        ? 1
                        : selectedTrendPoints
                            .contains {
                                $0.id ==
                                point.id
                            }
                            ? 1
                            : 0.32
                    )
                }


                if let selectedTrendMonth {

                    RuleMark(
                        x:
                            .value(
                                "选择月份",
                                selectedTrendMonth,
                                unit:
                                    .month
                            )
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .annotation(
                        position:
                            .top,
                        spacing:
                            8
                    ) {

                        VStack(
                            alignment:
                                .leading,
                            spacing:
                                3
                        ) {

                            Text(
                                selectedTrendTitle
                            )
                            .font(
                                .caption2
                            )
                            .foregroundStyle(
                                .secondary
                            )

                            Text(
                                "收入 \(selectedTrendIncome.formatted(.currency(code: "CNY")))"
                            )
                            .font(
                                .caption
                                    .bold()
                            )

                            Text(
                                "支出 \(selectedTrendExpense.formatted(.currency(code: "CNY")))"
                            )
                            .font(
                                .caption
                                    .bold()
                            )
                        }
                        .padding(
                            .horizontal,
                            9
                        )
                        .padding(
                            .vertical,
                            6
                        )
                        .background(
                            .regularMaterial
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius:
                                    9,
                                style:
                                    .continuous
                            )
                        )
                    }
                }
            }
            .frame(
                height: 230
            )
            .chartXAxis {

                AxisMarks(
                    values:
                        .stride(
                            by: .month,
                            count: 1
                        )
                ) { _ in

                    AxisGridLine()

                    AxisTick()

                    AxisValueLabel(
                        format:
                            .dateTime.month()
                    )
                }
            }
            .chartLegend(
                position:
                    .bottom,
                alignment:
                    .leading
            )
            .chartOverlay {
                proxy in

                GeometryReader {
                    geometry in

                    Rectangle()
                        .fill(
                            Color.clear
                        )
                        .contentShape(
                            Rectangle()
                        )
                        .gesture(
                            DragGesture(
                                minimumDistance:
                                    0
                            )
                            .onEnded {
                                value in

                                guard
                                    let plotFrame =
                                        proxy.plotFrame
                                else {
                                    return
                                }


                                let frame =
                                    geometry[
                                        plotFrame
                                    ]


                                guard
                                    frame.contains(
                                        value.location
                                    )
                                else {
                                    return
                                }


                                let x =
                                    value.location.x -
                                    frame.minX


                                guard
                                    let rawDate:
                                        Date =
                                            proxy.value(
                                                atX:
                                                    x
                                            ),
                                    let nearest =
                                        nearestTrendMonth(
                                            to:
                                                rawDate
                                        )
                                else {
                                    return
                                }


                                if let selectedTrendMonth,
                                   AppTime.calendar
                                    .isDate(
                                        selectedTrendMonth,
                                        equalTo:
                                            nearest,
                                        toGranularity:
                                            .month
                                    ) {

                                    self.selectedTrendMonth =
                                        nil

                                } else {

                                    self.selectedTrendMonth =
                                        nearest

                                    HapticFeedback
                                        .selection()
                                }
                            }
                        )
                }
            }
        }
        .padding()
        .background(
            Color(
                .secondarySystemBackground
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style:
                    .continuous
            )
        )
    }


    // MARK: - 月度账单入口

    private var monthBillEntry:
        some View {

        NavigationLink {

            MonthTransactionsView(
                monthStart:
                    monthStart,
                monthEnd:
                    monthEnd,
                title:
                    monthTitle
            )

        } label: {

            HStack {

                Label(
                    "查看 \(monthTitle) 全部账单",
                    systemImage:
                        "list.bullet.rectangle"
                )

                Spacer()

                Text(
                    "\(monthTransactions.count) 笔"
                )
                .foregroundStyle(
                    .secondary
                )

                Image(
                    systemName:
                        "chevron.right"
                )
                .font(
                    .caption.bold()
                )
                .foregroundStyle(
                    .secondary
                )
            }
            .padding()
            .background(
                Color(
                    .secondarySystemBackground
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 18,
                    style:
                        .continuous
                )
            )
        }
        .buttonStyle(
            .plain
        )
    }


    private func compactTransactionRow(
        _ transaction:
            TransactionRecord
    ) -> some View {

        HStack(
            spacing: 10
        ) {

            Image(
                systemName:
                    transaction.type.icon
            )
            .frame(
                width: 28,
                height: 28
            )
            .background(
                Color(
                    .tertiarySystemBackground
                )
            )
            .clipShape(
                Circle()
            )


            VStack(
                alignment: .leading,
                spacing: 2
            ) {

                Text(
                    transaction.category.isEmpty
                    ? transaction.type.rawValue
                    : transaction.category
                )
                .font(
                    .subheadline
                )

                Text(
                    AppTime.listDateTime(
                        transaction.date
                    )
                )
                .font(
                    .caption2
                )
                .foregroundStyle(
                    .secondary
                )
            }


            Spacer()


            Text(
                abs(
                    transaction.amount
                ),
                format:
                    .currency(
                        code:
                            "CNY"
                    )
            )
            .font(
                .subheadline.weight(
                    .medium
                )
            )
        }
        .contentShape(
            Rectangle()
        )
    }


    private func emptyChart(
        text:
            String
    ) -> some View {

        VStack(
            spacing: 8
        ) {

            Image(
                systemName:
                    "chart.bar.xaxis"
            )
            .font(
                .title2
            )

            Text(
                text
            )
            .font(
                .subheadline
            )
        }
        .foregroundStyle(
            .secondary
        )
        .frame(
            maxWidth:
                .infinity,
            minHeight:
                150
        )
    }
}


// MARK: - 分类账单

private struct CategoryTransactionsView: View {

    let category:
        String

    let monthStart:
        Date

    let monthEnd:
        Date

    @Query(
        sort:
            \TransactionRecord.date,
        order:
            .reverse
    )
    private var transactions:
        [TransactionRecord]


    private var filteredTransactions:
        [TransactionRecord] {

        transactions.filter {

            let transactionCategory =
                $0.category.isEmpty
                ? "未分类"
                : $0.category

            return
                $0.date >= monthStart &&
                $0.date < monthEnd &&
                (
                    $0.type == .expense ||
                    $0.type == .creditExpense
                ) &&
                transactionCategory ==
                category
        }
    }


    private var total:
        Double {

        filteredTransactions
            .reduce(0) {
                $0 + abs($1.amount)
            }
    }


    var body: some View {

        List {

            Section {

                LabeledContent(
                    "分类合计"
                ) {

                    Text(
                        total,
                        format:
                            .currency(
                                code:
                                    "CNY"
                            )
                    )
                    .fontWeight(
                        .semibold
                    )
                }

                LabeledContent(
                    "账单数量",
                    value:
                        "\(filteredTransactions.count) 笔"
                )
            }


            Section(
                "账单"
            ) {

                if filteredTransactions.isEmpty {

                    Text(
                        "暂无账单"
                    )
                    .foregroundStyle(
                        .secondary
                    )

                } else {

                    ForEach(
                        filteredTransactions
                    ) { transaction in

                        NavigationLink {

                            TransactionDetailView(
                                transaction:
                                    transaction
                            )

                        } label: {

                            StatisticsTransactionRow(
                                transaction:
                                    transaction
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle(
            category
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
    }
}


// MARK: - 月度全部账单

private struct MonthTransactionsView: View {

    let monthStart:
        Date

    let monthEnd:
        Date

    let title:
        String

    @Query(
        sort:
            \TransactionRecord.date,
        order:
            .reverse
    )
    private var transactions:
        [TransactionRecord]


    private var filteredTransactions:
        [TransactionRecord] {

        transactions.filter {
            $0.date >= monthStart &&
            $0.date < monthEnd
        }
    }


    var body: some View {

        List {

            if filteredTransactions.isEmpty {

                Text(
                    "这个月还没有账单"
                )
                .foregroundStyle(
                    .secondary
                )

            } else {

                ForEach(
                    filteredTransactions
                ) { transaction in

                    NavigationLink {

                        TransactionDetailView(
                            transaction:
                                transaction
                        )

                    } label: {

                        StatisticsTransactionRow(
                            transaction:
                                transaction
                        )
                    }
                }
            }
        }
        .navigationTitle(
            title
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
    }
}


// MARK: - 统计页账单行

private struct StatisticsTransactionRow: View {

    let transaction:
        TransactionRecord


    var body: some View {

        HStack(
            spacing: 12
        ) {

            Image(
                systemName:
                    transaction.type.icon
            )
            .frame(
                width: 32,
                height: 32
            )
            .background(
                Color(
                    .secondarySystemBackground
                )
            )
            .clipShape(
                Circle()
            )


            VStack(
                alignment: .leading,
                spacing: 3
            ) {

                Text(
                    transaction.category.isEmpty
                    ? transaction.type.rawValue
                    : transaction.category
                )

                Text(
                    AppTime.listDateTime(
                        transaction.date
                    )
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }


            Spacer()


            Text(
                signedAmountText
            )
            .fontWeight(
                .medium
            )
        }
    }


    private var signedAmountText:
        String {

        let amount =
            abs(
                transaction.amount
            )
            .formatted(
                .currency(
                    code:
                        "CNY"
                )
            )

        switch transaction.type {

        case .income:

            return "+\(amount)"

        case .expense,
             .creditExpense:

            return "-\(amount)"

        case .transfer,
             .creditRepayment,
             .adjustment:

            return amount
        }
    }
}


// MARK: - 图表数据

private struct DailyExpensePoint:
    Identifiable {

    let date:
        Date

    let amount:
        Double

    var id:
        Date {

        date
    }
}


private struct CategoryExpensePoint:
    Identifiable {

    let category:
        String

    let amount:
        Double

    var id:
        String {

        category
    }
}


private struct MonthlyFlowPoint:
    Identifiable {

    let month:
        Date

    let type:
        String

    let amount:
        Double

    var id:
        String {

        "\(month.timeIntervalSince1970)-\(type)"
    }
}


private struct CategoryChartSlice:
    Identifiable {

    let category:
        String

    let amount:
        Double

    let percentage:
        Double

    let startAngle:
        Angle

    let endAngle:
        Angle

    let color:
        Color

    var id:
        String {

        category
    }

    var midAngle:
        Angle {

        .degrees(
            (
                startAngle.degrees +
                endAngle.degrees
            ) /
            2
        )
    }

    var percentageText:
        String {

        percentage.formatted(
            .percent
                .precision(
                    .fractionLength(
                        1
                    )
                )
        )
    }

    var accessibilityText:
        String {

        "\(category) \(percentageText)"
    }
}


private struct CategoryDonutBreakdownView: View {

    let points:
        [CategoryChartSlice]

    @Binding
    var selectedCategoryID:
        String?


    var body: some View {

        GeometryReader { proxy in

            let width =
                proxy.size.width

            let height =
                proxy.size.height

            let centerYOffset =
                min(
                    max(
                        height *
                        0.06,
                        18
                    ),
                    26
                )

            let center =
                CGPoint(
                    x:
                        width /
                        2,
                    y:
                        height /
                        2 +
                        centerYOffset
                )

            // 名称 + 百分比标签比原来更宽，因此主动缩小圆环，
            // 给左右折线和文字留下空间。
            let maxCalloutLabelWidth =
                points
                    .map {
                        estimatedCalloutLabelWidth(
                            text:
                                "\($0.category) \($0.percentageText)"
                        )
                    }
                    .max() ??
                    88

            let sidePaddingForCallout:
                CGFloat = 12

            let labelGapForCallout:
                CGFloat = 7

            let safeCircleExtra:
                CGFloat = 18

            let minimumHorizontalForCallout:
                CGFloat = 52

            let requiredSideSpace =
                maxCalloutLabelWidth +
                sidePaddingForCallout +
                labelGapForCallout +
                safeCircleExtra +
                minimumHorizontalForCallout

            let widthLimitedRadius =
                max(
                    128,
                    width /
                    2 -
                    requiredSideSpace
                )

            let outerRadius =
                min(
                    widthLimitedRadius,
                    height *
                    0.31
                )

            let innerRadius =
                outerRadius *
                0.56

            let calloutRadius =
                outerRadius +
                14

            let horizontalExtension:
                CGFloat = 16

            let labelLayouts =
                resolvedLabelLayouts(
                    center:
                        center,
                    outerRadius:
                        outerRadius,
                    calloutRadius:
                        calloutRadius,
                    horizontalExtension:
                        horizontalExtension,
                    bounds:
                        proxy.size
                )


            ZStack {

                // 扇区、中心白圆、中心文字和 callout 计算必须共享同一个 center。
                // 不依赖 UIScreen / 固定机型尺寸，GeometryReader 尺寸变化时同步适配。
                // 点击圆环之外的空白区域，视为失去焦点。
                Color.clear
                    .contentShape(
                        Rectangle()
                    )
                    .onTapGesture {

                        clearSelection()
                    }


                ForEach(
                    points
                ) { point in

                    let isSelected =
                        selectedCategoryID ==
                        point.id

                    let hasSelection =
                        selectedCategoryID !=
                        nil

                    let radians =
                        point.midAngle
                            .radians

                    let selectionOffset:
                        CGFloat =
                            isSelected
                            ? 9
                            : 0


                    DonutSliceShape(
                        startAngle:
                            point.startAngle,
                        endAngle:
                            point.endAngle,
                        innerRadiusRatio:
                            innerRadius /
                            outerRadius
                    )
                    .fill(
                        point.color
                    )
                    .frame(
                        width:
                            outerRadius *
                            2,
                        height:
                            outerRadius *
                            2
                    )
                    .position(
                        center
                    )
                    .opacity(
                        hasSelection &&
                        !isSelected
                        ? 0.28
                        : 1
                    )
                    .scaleEffect(
                        isSelected
                        ? 1.035
                        : 1
                    )
                    .offset(
                        x:
                            cos(
                                radians
                            ) *
                            selectionOffset,
                        y:
                            sin(
                                radians
                            ) *
                            selectionOffset
                    )
                    .shadow(
                        color:
                            isSelected
                            ? point.color
                                .opacity(
                                    0.24
                                )
                            : .clear,
                        radius:
                            isSelected
                            ? 8
                            : 0
                    )
                    .contentShape(
                        DonutSliceShape(
                            startAngle:
                                point.startAngle,
                            endAngle:
                                point.endAngle,
                            innerRadiusRatio:
                                innerRadius /
                                outerRadius
                        )
                    )
                    .allowsHitTesting(
                        false
                    )
                    .accessibilityLabel(
                        point.accessibilityText
                    )
                    .accessibilityAddTraits(
                        isSelected
                        ? .isSelected
                        : []
                    )
                    .zIndex(
                        isSelected
                        ? 3
                        : 1
                    )
                }


                Circle()
                    .fill(
                        Color(
                            .systemBackground
                        )
                    )
                    .frame(
                        width:
                            innerRadius *
                            2,
                        height:
                            innerRadius *
                            2
                    )
                    .position(
                        center
                    )
                    .contentShape(
                        Circle()
                    )
                    .allowsHitTesting(
                        false
                    )
                    .zIndex(4)


                centerContent
                    .position(
                        center
                    )
                    .zIndex(5)
                    .allowsHitTesting(
                        false
                    )


                // Callout 必须位于扇区之上。
                // 扇区自身 zIndex 为 1/3，中心层为 4/5；
                // 引线/圆点/标签使用 7~11，避免初始状态被不透明扇区遮住。
                ForEach(
                    points
                ) { point in

                    if let layout =
                        labelLayouts[
                            point.id
                        ] {

                        let isSelected =
                            selectedCategoryID ==
                            point.id

                        let hasSelection =
                            selectedCategoryID !=
                            nil

                        let radians =
                            point.midAngle
                                .radians

                        let selectedStartOffset:
                            CGFloat =
                                isSelected
                                ? (
                                    9 +
                                    outerRadius *
                                    0.035
                                )
                                : 0

                        let renderedStart =
                            CGPoint(
                                x:
                                    layout.start.x +
                                    cos(
                                        radians
                                    ) *
                                    selectedStartOffset,
                                y:
                                    layout.start.y +
                                    sin(
                                        radians
                                    ) *
                                    selectedStartOffset
                            )


                        Path { path in

                            path.move(
                                to:
                                    renderedStart
                            )

                            path.addLine(
                                to:
                                    layout.bend
                            )

                            path.addLine(
                                to:
                                    layout.end
                            )
                        }
                        .stroke(
                            point.color.opacity(
                                hasSelection &&
                                !isSelected
                                ? 0.24
                                : 0.82
                            ),
                            style:
                                StrokeStyle(
                                    lineWidth:
                                        isSelected
                                        ? 2
                                        : 1.4,
                                    lineCap:
                                        .round,
                                    lineJoin:
                                        .round
                                )
                        )
                        .zIndex(
                            isSelected
                            ? 9
                            : 7
                        )


                        Circle()
                            .fill(
                                point.color
                            )
                            .frame(
                                width:
                                    isSelected
                                    ? 7
                                    : 5,
                                height:
                                    isSelected
                                    ? 7
                                    : 5
                            )
                            .position(
                                renderedStart
                            )
                            .zIndex(
                                isSelected
                                ? 10
                                : 8
                            )


                        Text(
                            "\(point.category) \(point.percentageText)"
                        )
                        .lineLimit(
                            1
                        )
                        .minimumScaleFactor(
                            0.78
                        )
                        .font(
                            .caption2
                                .weight(
                                    isSelected
                                    ? .bold
                                    : .semibold
                                )
                        )
                        .foregroundStyle(
                            hasSelection &&
                            !isSelected
                            ? .secondary
                            : .primary
                        )
                        .padding(
                            .vertical,
                            3
                        )
                        .frame(
                            width:
                                layout.labelFrameWidth,
                            alignment:
                                .center
                        )
                        .multilineTextAlignment(
                            .center
                        )
                        .background(
                            Color(
                                .systemBackground
                            )
                            .opacity(
                                0.96
                            )
                        )
                        .overlay {

                            if isSelected {

                                Capsule()
                                    .stroke(
                                        point.color
                                            .opacity(
                                                0.55
                                            ),
                                        lineWidth:
                                            1
                                    )
                            }
                        }
                        .clipShape(
                            Capsule()
                        )
                        .position(
                            x:
                                layout.textAnchorX,
                            y:
                                layout.end.y -
                                16
                        )
                        .allowsHitTesting(
                            false
                        )
                        .zIndex(
                            isSelected
                            ? 11
                            : 9
                        )
                    }
                }


                // 交互命中层始终放在视觉内容最上方。
                // 使用几乎透明的扇区填充，而不是依赖下层视觉 Shape 的 hit testing，
                // 避免 ScrollView、callout 高 zIndex、选中缩放等因素吞掉点击。
                ForEach(
                    points
                ) { point in

                    DonutSliceShape(
                        startAngle:
                            point.startAngle,
                        endAngle:
                            point.endAngle,
                        innerRadiusRatio:
                            innerRadius /
                            outerRadius
                    )
                    .fill(
                        Color.white
                            .opacity(
                                0.001
                            )
                    )
                    .frame(
                        width:
                            outerRadius *
                            2,
                        height:
                            outerRadius *
                            2
                    )
                    .position(
                        center
                    )
                    .contentShape(
                        DonutSliceShape(
                            startAngle:
                                point.startAngle,
                            endAngle:
                                point.endAngle,
                            innerRadiusRatio:
                                innerRadius /
                                outerRadius
                        )
                    )
                    .onTapGesture {

                        toggleSelection(
                            point.id
                        )

                        HapticFeedback
                            .selection()
                    }
                    .zIndex(
                        20
                    )
                }


                // 中心白圆单独覆盖在命中层之上，点击中心取消选择。
                Circle()
                    .fill(
                        Color.white
                            .opacity(
                                0.001
                            )
                    )
                    .frame(
                        width:
                            innerRadius *
                            2,
                        height:
                            innerRadius *
                            2
                    )
                    .position(
                        center
                    )
                    .contentShape(
                        Circle()
                    )
                    .onTapGesture {

                        clearSelection()
                    }
                    .zIndex(
                        21
                    )
            }
            .frame(
                maxWidth:
                    .infinity,
                maxHeight:
                    .infinity
            )
            .animation(
                .snappy(
                    duration:
                        0.24
                ),
                value:
                    selectedCategoryID
            )
        }
    }


    @ViewBuilder
    private var centerContent:
        some View {

        if let selected =
            points.first(
                where: {
                    $0.id ==
                    selectedCategoryID
                }
            ) {

            VStack(
                spacing: 3
            ) {

                Text(
                    selected.category
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    selected.color
                )

                Text(
                    selected.amount,
                    format:
                        .currency(
                            code:
                                "CNY"
                        )
                )
                .font(
                    .headline
                )

                Text(
                    selected.percentageText
                )
                .font(
                    .caption2
                )
                .foregroundStyle(
                    .secondary
                )
            }

        } else {

            VStack(
                spacing: 4
            ) {

                Text(
                    "支出占比"
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )

                Text(
                    points
                        .reduce(0) {
                            $0 + $1.amount
                        },
                    format:
                        .currency(
                            code:
                                "CNY"
                        )
                )
                .font(
                    .headline
                )
            }
        }
    }


    private func toggleSelection(
        _ categoryID:
            String
    ) {

        withAnimation(
            .snappy(
                duration:
                    0.24
            )
        ) {

            if selectedCategoryID ==
                categoryID {

                selectedCategoryID =
                    nil

            } else {

                selectedCategoryID =
                    categoryID
            }
        }
    }


    private func clearSelection() {

        guard selectedCategoryID !=
                nil
        else {

            return
        }


        withAnimation(
            .snappy(
                duration:
                    0.24
            )
        ) {

            selectedCategoryID =
                nil
        }
    }


    private func resolvedLabelLayouts(
        center:
            CGPoint,
        outerRadius:
            CGFloat,
        calloutRadius:
            CGFloat,
        horizontalExtension:
            CGFloat,
        bounds:
            CGSize
    ) -> [String: CategoryCalloutLayout] {

        struct RawLayoutSeed {

            let id:
                String

            let start:
                CGPoint

            let proposedY:
                CGFloat

            let labelWidth:
                CGFloat

            let isRightSide:
                Bool
        }


        var topClusterIndex =
            0

        let rawSeeds =
            points.map { point in

                let radians =
                    point.midAngle
                        .radians

                let cosine =
                    cos(
                        radians
                    )

                let sine =
                    sin(
                        radians
                    )

                let isTopCluster =
                    sine <
                    -0.90

                let isRightSide:
                    Bool

                if isTopCluster {

                    // 接近 12 点方向时左右没有强几何偏好。
                    // 交替分流可避免“买菜 / 其他 / 娱乐”
                    // 全部叠在同一侧同一高度。
                    isRightSide =
                        topClusterIndex %
                        2 ==
                        1

                    topClusterIndex +=
                        1

                } else {

                    isRightSide =
                        cosine >=
                        0
                }

                let start =
                    CGPoint(
                        x:
                            center.x +
                            cos(
                                radians
                            ) *
                            (outerRadius + 2),
                        y:
                            center.y +
                            sin(
                                radians
                            ) *
                            (outerRadius + 2)
                    )

                let proposedY =
                    center.y +
                    sin(
                        radians
                    ) *
                    calloutRadius

                let labelWidth =
                    estimatedCalloutLabelWidth(
                        text:
                            "\(point.category) \(point.percentageText)"
                    )

                return RawLayoutSeed(
                    id:
                        point.id,
                    start:
                        start,
                    proposedY:
                        proposedY,
                    labelWidth:
                        labelWidth,
                    isRightSide:
                        isRightSide
                )
            }


        let sidePadding:
            CGFloat = 12

        let labelInsetFromLineEnd:
            CGFloat = 6

        let horizontalSegmentLength:
            CGFloat = 68

        let outerElbowGap:
            CGFloat = 22

        let rawLayouts =
            rawSeeds.map { seed in

                let labelFrameWidth =
                    seed.labelWidth

                let textAnchorX =
                    seed.isRightSide
                    ? bounds.width - sidePadding - labelFrameWidth / 2
                    : sidePadding + labelFrameWidth / 2

                let labelGap:
                    CGFloat = 7

                let endX =
                    seed.isRightSide
                    ? (
                        textAnchorX -
                        labelFrameWidth / 2 -
                        labelGap
                    )
                    : (
                        textAnchorX +
                        labelFrameWidth / 2 +
                        labelGap
                    )

                let bendX: CGFloat

                if seed.isRightSide {

                    bendX =
                        max(
                            seed.start.x +
                            outerElbowGap,
                            endX -
                            horizontalSegmentLength
                        )

                } else {

                    bendX =
                        min(
                            seed.start.x -
                            outerElbowGap,
                            endX +
                            horizontalSegmentLength
                        )
                }

                return CategoryCalloutLayout(
                    id:
                        seed.id,
                    start:
                        seed.start,
                    bend:
                        CGPoint(
                            x:
                                bendX,
                            y:
                                seed.proposedY
                        ),
                    end:
                        CGPoint(
                            x:
                                endX,
                            y:
                                seed.proposedY
                        ),
                    textAnchorX:
                        textAnchorX,
                    labelFrameWidth:
                        labelFrameWidth,
                    isRightSide:
                        seed.isRightSide
                )
            }

        let topLimit =
            max(
                30,
                center.y -
                outerRadius -
                70
            )

        let bottomLimit =
            min(
                bounds.height -
                22,
                center.y +
                outerRadius +
                34
            )

        let minimumGap:
            CGFloat = 28


        let leftAdjusted =
            adjustSideLayouts(
                rawLayouts
                    .filter {
                        !$0.isRightSide
                    },
                topLimit:
                    topLimit,
                bottomLimit:
                    bottomLimit,
                minimumGap:
                    minimumGap,
                center:
                    center,
                outerRadius:
                    outerRadius
            )


        let rightAdjusted =
            adjustSideLayouts(
                rawLayouts
                    .filter {
                        $0.isRightSide
                    },
                topLimit:
                    topLimit,
                bottomLimit:
                    bottomLimit,
                minimumGap:
                    minimumGap,
                center:
                    center,
                outerRadius:
                    outerRadius
            )


        return Dictionary(
            uniqueKeysWithValues:
                (
                    leftAdjusted +
                    rightAdjusted
                )
                .map {
                    (
                        $0.id,
                        $0
                    )
                }
        )
    }


    private func estimatedCalloutLabelWidth(
        text:
            String
    ) -> CGFloat {

        let baseWidth =
            text.reduce(0) {
                partial, character in

                if character.isASCII {
                    return partial + 6.4
                } else {
                    return partial + 11.5
                }
            }

        return min(
            max(
                baseWidth + 10,
                58
            ),
            104
        )
    }


    private func adjustSideLayouts(
        _ layouts:
            [CategoryCalloutLayout],
        topLimit:
            CGFloat,
        bottomLimit:
            CGFloat,
        minimumGap:
            CGFloat,
        center:
            CGPoint,
        outerRadius:
            CGFloat
    ) -> [CategoryCalloutLayout] {

        guard !layouts.isEmpty
        else {
            return []
        }


        // 关键原则：
        // 不再为了避让标签直接修改 bend.y。
        //
        // start -> bend 必须永远沿着该扇区的半径方向向外，
        // 因此第一段只允许改变“半径长度”，不能任意改 x/y。
        //
        // 这样整条第一段除了起点之外，都位于饼图外部白色区域。
        let verticalEpsilon:
            CGFloat = 0.04


        let upperLayouts =
            layouts.filter {
                radialUnitY(
                    for:
                        $0,
                    center:
                        center
                ) <
                    -verticalEpsilon
            }


        let lowerLayouts =
            layouts.filter {
                radialUnitY(
                    for:
                        $0,
                    center:
                        center
                ) >
                    verticalEpsilon
            }


        let middleLayouts =
            layouts.filter {

                abs(
                    radialUnitY(
                        for:
                            $0,
                        center:
                            center
                    )
                ) <=
                    verticalEpsilon
            }


        let adjustedUpper =
            adjustRadialGroup(
                upperLayouts,
                isUpper:
                    true,
                topLimit:
                    topLimit,
                bottomLimit:
                    bottomLimit,
                minimumGap:
                    minimumGap,
                center:
                    center,
                outerRadius:
                    outerRadius
            )


        let adjustedLower =
            adjustRadialGroup(
                lowerLayouts,
                isUpper:
                    false,
                topLimit:
                    topLimit,
                bottomLimit:
                    bottomLimit,
                minimumGap:
                    minimumGap,
                center:
                    center,
                outerRadius:
                    outerRadius
            )


        let adjustedMiddle =
            middleLayouts.map {
                makeRadialCallout(
                    $0,
                    radius:
                        outerRadius +
                        30,
                    center:
                        center,
                    outerRadius:
                        outerRadius,
                    topLimit:
                        topLimit,
                    bottomLimit:
                        bottomLimit
                )
            }


        return
            adjustedUpper +
            adjustedMiddle +
            adjustedLower
    }


    private func adjustRadialGroup(
        _ layouts:
            [CategoryCalloutLayout],
        isUpper:
            Bool,
        topLimit:
            CGFloat,
        bottomLimit:
            CGFloat,
        minimumGap:
            CGFloat,
        center:
            CGPoint,
        outerRadius:
            CGFloat
    ) -> [CategoryCalloutLayout] {

        guard !layouts.isEmpty
        else {
            return []
        }


        let baseRadius =
            outerRadius +
            30


        // 上半区从“靠近水平轴”向上处理；
        // 下半区从“靠近水平轴”向下处理。
        //
        // 避让时只增加 radial radius，
        // 所以斜线始终沿原扇区半径继续向外。
        let sorted =
            layouts.sorted {

                let lhsY =
                    radialY(
                        for:
                            $0,
                        radius:
                            baseRadius,
                        center:
                            center
                    )

                let rhsY =
                    radialY(
                        for:
                            $1,
                        radius:
                            baseRadius,
                        center:
                            center
                    )

                if isUpper {
                    return lhsY >
                        rhsY
                }

                return lhsY <
                    rhsY
            }


        var result:
            [CategoryCalloutLayout] = []

        var previousLineY:
            CGFloat?


        for layout in
            sorted {

            let unitY =
                radialUnitY(
                    for:
                        layout,
                    center:
                        center
                )


            let naturalLineY =
                radialY(
                    for:
                        layout,
                    radius:
                        baseRadius,
                    center:
                        center
                )


            var targetLineY =
                naturalLineY


            if let previousLineY {

                if isUpper {

                    targetLineY =
                        min(
                            targetLineY,
                            previousLineY -
                            minimumGap
                        )

                } else {

                    targetLineY =
                        max(
                            targetLineY,
                            previousLineY +
                            minimumGap
                        )
                }
            }


            targetLineY =
                min(
                    max(
                        targetLineY,
                        topLimit
                    ),
                    bottomLimit
                )


            let requiredRadius:
                CGFloat

            if abs(
                unitY
            ) >
                0.001 {

                requiredRadius =
                    (
                        targetLineY -
                        center.y
                    ) /
                    unitY

            } else {

                requiredRadius =
                    baseRadius
            }


            let requestedRadius =
                max(
                    baseRadius,
                    requiredRadius
                )


            let adjusted =
                makeRadialCallout(
                    layout,
                    radius:
                        requestedRadius,
                    center:
                        center,
                    outerRadius:
                        outerRadius,
                    topLimit:
                        topLimit,
                    bottomLimit:
                        bottomLimit
                )


            result.append(
                adjusted
            )

            // 使用真正绘制后的 lineY 作为下一条的基准，
            // 避免多个顶部小分类因为半径上限被压到同一行。
            previousLineY =
                adjusted.end.y
        }


        return result
    }


    private func makeRadialCallout(
        _ layout:
            CategoryCalloutLayout,
        radius:
            CGFloat,
        center:
            CGPoint,
        outerRadius:
            CGFloat,
        topLimit:
            CGFloat,
        bottomLimit:
            CGFloat
    ) -> CategoryCalloutLayout {

        var result =
            layout


        let vectorX =
            result.start.x -
            center.x

        let vectorY =
            result.start.y -
            center.y

        let vectorLength =
            max(
                sqrt(
                    vectorX *
                    vectorX +
                    vectorY *
                    vectorY
                ),
                0.001
            )

        let unitX =
            vectorX /
            vectorLength

        let unitY =
            vectorY /
            vectorLength


        let minimumRadius =
            outerRadius +
            26


        var maximumRadius =
            CGFloat.greatestFiniteMagnitude


        // 约束 1：标签/水平线不能跑出上下显示区域。
        if unitY <
            -0.001 {

            maximumRadius =
                min(
                    maximumRadius,
                    (
                        center.y -
                        topLimit
                    ) /
                    -unitY
                )

        } else if unitY >
                    0.001 {

            maximumRadius =
                min(
                    maximumRadius,
                    (
                        bottomLimit -
                        center.y
                    ) /
                    unitY
                )
        }


        // 约束 2：bend 后面必须还留得下一个明显的水平段。
        let minimumHorizontalLength:
            CGFloat = 38

        if result.isRightSide,
           unitX >
            0.001 {

            maximumRadius =
                min(
                    maximumRadius,
                    (
                        result.end.x -
                        minimumHorizontalLength -
                        center.x
                    ) /
                    unitX
                )

        } else if !result.isRightSide,
                  unitX <
                    -0.001 {

            maximumRadius =
                min(
                    maximumRadius,
                    (
                        center.x -
                        (
                            result.end.x +
                            minimumHorizontalLength
                        )
                    ) /
                    -unitX
                )
        }


        let effectiveRadius:
            CGFloat

        if maximumRadius >=
            minimumRadius {

            effectiveRadius =
                min(
                    max(
                        radius,
                        minimumRadius
                    ),
                    maximumRadius
                )

        } else {

            // 极端窄空间时仍优先保证第一段不进入饼图。
            effectiveRadius =
                minimumRadius
        }


        let bend =
            CGPoint(
                x:
                    center.x +
                    unitX *
                    effectiveRadius,
                y:
                    center.y +
                    unitY *
                    effectiveRadius
            )


        result.bend =
            bend

        // 第二段只做水平延伸。
        result.end.y =
            bend.y


        // 标签依旧锁在显示区域内，
        // 水平线终点贴近标签内侧。
        let labelSafeMargin:
            CGFloat = 12

        let labelGap:
            CGFloat = 7

        let halfLabelWidth =
            result.labelFrameWidth /
            2

        result.textAnchorX =
            min(
                max(
                    result.textAnchorX,
                    labelSafeMargin +
                    halfLabelWidth
                ),
                center.x *
                2 -
                labelSafeMargin -
                halfLabelWidth
            )


        if result.isRightSide {

            let labelLeftEdge =
                result.textAnchorX -
                halfLabelWidth

            result.end.x =
                max(
                    bend.x +
                    12,
                    labelLeftEdge -
                    labelGap
                )

        } else {

            let labelRightEdge =
                result.textAnchorX +
                halfLabelWidth

            result.end.x =
                min(
                    bend.x -
                    12,
                    labelRightEdge +
                    labelGap
                )
        }


        return result
    }


    private func radialUnitY(
        for layout:
            CategoryCalloutLayout,
        center:
            CGPoint
    ) -> CGFloat {

        let dx =
            layout.start.x -
            center.x

        let dy =
            layout.start.y -
            center.y

        let length =
            max(
                sqrt(
                    dx *
                    dx +
                    dy *
                    dy
                ),
                0.001
            )

        return dy /
            length
    }


    private func radialY(
        for layout:
            CategoryCalloutLayout,
        radius:
            CGFloat,
        center:
            CGPoint
    ) -> CGFloat {

        center.y +
        radialUnitY(
            for:
                layout,
            center:
                center
        ) *
        radius
    }

}


private extension Character {

    var isASCII:
        Bool {

        unicodeScalars.allSatisfy {
            $0.isASCII
        }
    }
}


private struct CategoryCalloutLayout {

    let id:
        String

    let start:
        CGPoint

    var bend:
        CGPoint

    var end:
        CGPoint

    var textAnchorX:
        CGFloat

    // 用于估算标签定位；显示时不强制撑到这个宽度。
    let labelFrameWidth:
        CGFloat

    let isRightSide:
        Bool
}


private struct DonutSliceShape:
    Shape {

    let startAngle:
        Angle

    let endAngle:
        Angle

    let innerRadiusRatio:
        CGFloat

    func path(
        in rect:
            CGRect
    ) -> Path {

        let center =
            CGPoint(
                x:
                    rect.midX,
                y:
                    rect.midY
            )

        let outerRadius =
            min(
                rect.width,
                rect.height
            ) / 2

        let innerRadius =
            outerRadius *
            innerRadiusRatio

        var path =
            Path()

        path.addArc(
            center:
                center,
            radius:
                outerRadius,
            startAngle:
                startAngle,
            endAngle:
                endAngle,
            clockwise:
                false
        )

        path.addArc(
            center:
                center,
            radius:
                innerRadius,
            startAngle:
                endAngle,
            endAngle:
                startAngle,
            clockwise:
                true
        )

        path.closeSubpath()

        return path
    }
}


// MARK: - 预算编辑

private struct BudgetEditorView: View {

    @Environment(
        \.dismiss
    )
    private var dismiss

    @Binding
    var monthlyBudget:
        Double

    @State
    private var amountText:
        String

    @FocusState
    private var amountFocused:
        Bool


    init(
        monthlyBudget:
            Binding<Double>
    ) {

        self._monthlyBudget =
            monthlyBudget

        self._amountText =
            State(
                initialValue:
                    monthlyBudget.wrappedValue > 0
                    ? String(
                        format:
                            "%.2f",
                        monthlyBudget
                            .wrappedValue
                    )
                    : ""
            )
    }


    var body: some View {

        NavigationStack {

            Form {

                Section(
                    "月度支出预算"
                ) {

                    HStack {

                        Text(
                            "¥"
                        )
                        .foregroundStyle(
                            .secondary
                        )

                        TextField(
                            "例如 5000",
                            text:
                                $amountText
                        )
                        .keyboardType(
                            .decimalPad
                        )
                        .focused(
                            $amountFocused
                        )
                    }
                }


                if monthlyBudget > 0 {

                    Section {

                        Button(
                            "清除预算",
                            role:
                                .destructive
                        ) {

                            monthlyBudget =
                                0

                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(
                "设置预算"
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
                        "取消"
                    ) {

                        dismiss()
                    }
                }


                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {

                    Button(
                        "保存"
                    ) {

                        save()
                    }
                    .disabled(
                        parsedAmount ==
                            nil ||
                        (
                            parsedAmount
                            ?? 0
                        ) <= 0
                    )
                }


                ToolbarItemGroup(
                    placement:
                        .keyboard
                ) {

                    Spacer()

                    Button(
                        "完成"
                    ) {

                        amountFocused =
                            false
                    }
                    .fontWeight(
                        .semibold
                    )
                }
            }
            .onAppear {

                amountFocused =
                    true
            }
        }
    }


    private var parsedAmount:
        Double? {

        let cleaned =
            amountText
                .replacingOccurrences(
                    of:
                        ",",
                    with:
                        "."
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        return Double(
            cleaned
        )
    }


    private func save() {

        guard
            let amount =
                parsedAmount,
            amount > 0
        else {
            return
        }

        monthlyBudget =
            amount

        dismiss()
    }
}



// MARK: - 分类预算编辑

private struct CategoryBudgetEditorView:
    View {

    @Environment(
        \.dismiss
    )
    private var dismiss

    @Binding
    private var stored:
        String

    let categories:
        [CategoryItem]

    @State
    private var drafts:
        [String: String]


    init(
        stored:
            Binding<String>,
        categories:
            [CategoryItem]
    ) {

        self._stored =
            stored

        self.categories =
            categories


        let existing =
            CategoryBudgetStore
                .decode(
                    stored
                        .wrappedValue
                )


        self._drafts =
            State(
                initialValue:
                    Dictionary(
                        uniqueKeysWithValues:
                            categories.map {
                                item in

                                let value =
                                    existing[
                                        item.name
                                    ] ??
                                    0

                                return (
                                    item.name,
                                    value >
                                    0
                                    ? value.formatted(
                                        .number
                                            .precision(
                                                .fractionLength(
                                                    0...2
                                                )
                                            )
                                    )
                                    : ""
                                )
                            }
                    )
            )
    }


    var body:
        some View {

        NavigationStack {

            List {

                Section {

                    ForEach(
                        categories
                    ) { item in

                        HStack(
                            spacing:
                                12
                        ) {

                            Image(
                                systemName:
                                    item.icon
                            )
                            .frame(
                                width:
                                    28
                            )


                            Text(
                                item.name
                            )


                            Spacer()


                            HStack(
                                spacing:
                                    4
                            ) {

                                Text(
                                    "¥"
                                )
                                .foregroundStyle(
                                    .secondary
                                )

                                TextField(
                                    "不设置",
                                    text:
                                        draftBinding(
                                            for:
                                                item.name
                                        )
                                )
                                .keyboardType(
                                    .decimalPad
                                )
                                .multilineTextAlignment(
                                    .trailing
                                )
                                .frame(
                                    width:
                                        90
                                )
                            }
                        }
                    }

                } header: {

                    Text(
                        "支出分类"
                    )

                } footer: {

                    Text(
                        "留空表示该分类不单独设置预算。分类预算只用于提醒和统计，不会改变总资产或账单金额。"
                    )
                }


                if !CategoryBudgetStore
                    .decode(
                        stored
                    )
                    .isEmpty {

                    Section {

                        Button(
                            "清除全部分类预算",
                            role:
                                .destructive
                        ) {

                            stored =
                                ""

                            drafts =
                                Dictionary(
                                    uniqueKeysWithValues:
                                        categories.map {
                                            (
                                                $0.name,
                                                ""
                                            )
                                        }
                                )

                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(
                "分类预算"
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
                        "取消"
                    ) {

                        dismiss()
                    }
                }


                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {

                    Button(
                        "保存"
                    ) {

                        save()
                    }
                    .fontWeight(
                        .semibold
                    )
                }


                ToolbarItemGroup(
                    placement:
                        .keyboard
                ) {

                    Spacer()

                    Button(
                        "完成"
                    ) {

                        UIApplication
                            .shared
                            .sendAction(
                                #selector(
                                    UIResponder
                                        .resignFirstResponder
                                ),
                                to:
                                    nil,
                                from:
                                    nil,
                                for:
                                    nil
                            )
                    }
                }
            }
        }
    }


    private func draftBinding(
        for category:
            String
    ) -> Binding<String> {

        Binding(
            get: {

                drafts[
                    category
                ] ??
                ""
            },
            set: {

                drafts[
                    category
                ] =
                    normalizedAmountText(
                        $0
                    )
            }
        )
    }


    private func normalizedAmountText(
        _ value:
            String
    ) -> String {

        let normalized =
            value.replacingOccurrences(
                of:
                    "，",
                with:
                    "."
            )


        var result =
            ""

        var hasDecimalPoint =
            false


        for character in
            normalized {

            if character
                .isNumber {

                result.append(
                    character
                )

            } else if character ==
                        ".",
                      !hasDecimalPoint {

                if result
                    .isEmpty {

                    result =
                        "0"
                }

                result.append(
                    "."
                )

                hasDecimalPoint =
                    true
            }
        }


        return result
    }


    private func save() {

        var budgets:
            [String: Double] = [:]


        for item in
            categories {

            let raw =
                drafts[
                    item.name
                ] ??
                ""

            guard
                let amount =
                    Double(
                        raw
                    ),
                amount >
                    0
            else {

                continue
            }


            budgets[
                item.name
            ] =
                amount
        }


        stored =
            CategoryBudgetStore
                .encode(
                    budgets
                )


        dismiss()
    }
}
