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

    @State
    private var showBudgetEditor =
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


    var body: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 22
            ) {

                monthSelector

                monthSummaryCard

                comparisonSection

                budgetCard

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
                        .cornerRadius(4)
                    }


                    if let selectedDay {

                        RuleMark(
                            x:
                                .value(
                                    "选择日期",
                                    selectedDay,
                                    unit:
                                        .day
                                )
                        )
                        .foregroundStyle(
                            .secondary
                        )
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
                .chartXSelection(
                    value:
                        $selectedDay
                )


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
                    height: 320
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


            Chart(
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

            let center =
                CGPoint(
                    x:
                        width /
                        2,
                    y:
                        height /
                        2
                )

            // 名称 + 百分比标签比原来更宽，因此主动缩小圆环，
            // 给左右折线和文字留下空间。
            let outerRadius =
                min(
                    width *
                    0.285,
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
                    .onTapGesture {

                        toggleSelection(
                            point.id
                        )
                    }
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
                    .contentShape(
                        Circle()
                    )
                    .onTapGesture {

                        clearSelection()
                    }
                    .zIndex(4)


                centerContent
                    .zIndex(5)
                    .allowsHitTesting(
                        false
                    )


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


                        Path { path in

                            path.move(
                                to:
                                    layout.start
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
                                layout.start
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
                            .horizontal,
                            7
                        )
                        .padding(
                            .vertical,
                            4
                        )
                        .frame(
                            width:
                                layout.labelFrameWidth,
                            alignment:
                                layout.isRightSide
                                ? .leading
                                : .trailing
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
                                18
                        )
                        .allowsHitTesting(
                            false
                        )
                    }
                }
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


        let rawSeeds =
            points.map { point in

                let radians =
                    point.midAngle
                        .radians

                let isRightSide =
                    cos(
                        radians
                    ) >= 0

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
            CGFloat = 18

        let labelInsetFromLineEnd:
            CGFloat = 6

        let maxLeftWidth =
            rawSeeds
                .filter {
                    !$0.isRightSide
                }
                .map {
                    $0.labelWidth
                }
                .max() ?? 0

        let maxRightWidth =
            rawSeeds
                .filter {
                    $0.isRightSide
                }
                .map {
                    $0.labelWidth
                }
                .max() ?? 0

        let leftColumnWidth =
            maxLeftWidth

        let rightColumnWidth =
            maxRightWidth

        let leftTextAnchorX =
            sidePadding +
            leftColumnWidth / 2

        let rightTextAnchorX =
            bounds.width -
            sidePadding -
            rightColumnWidth / 2

        let leftLineEndX =
            leftTextAnchorX +
            leftColumnWidth / 2 +
            labelInsetFromLineEnd

        let rightLineEndX =
            rightTextAnchorX -
            rightColumnWidth / 2 -
            labelInsetFromLineEnd

        let rawLayouts =
            rawSeeds.map { seed in

                let endX =
                    seed.isRightSide
                    ? rightLineEndX
                    : leftLineEndX

                let textAnchorX =
                    seed.isRightSide
                    ? rightTextAnchorX
                    : leftTextAnchorX

                let labelFrameWidth =
                    seed.isRightSide
                    ? rightColumnWidth
                    : leftColumnWidth

                let bendX: CGFloat

                if seed.isRightSide {

                    let available =
                        max(
                            endX -
                            seed.start.x,
                            18
                        )

                    let diagonalLength =
                        min(
                            24,
                            max(
                                10,
                                available *
                                0.42
                            )
                        )

                    bendX =
                        min(
                            seed.start.x +
                            diagonalLength,
                            endX - 8
                        )

                } else {

                    let available =
                        max(
                            seed.start.x -
                            endX,
                            18
                        )

                    let diagonalLength =
                        min(
                            24,
                            max(
                                10,
                                available *
                                0.42
                            )
                        )

                    bendX =
                        max(
                            seed.start.x -
                            diagonalLength,
                            endX + 8
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
                22,
                center.y -
                outerRadius -
                34
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
            CGFloat = 30


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
                    minimumGap
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
                    minimumGap
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
                    return partial + 7.5
                } else {
                    return partial + 13.5
                }
            }

        return min(
            max(
                baseWidth + 18,
                76
            ),
            144
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
            CGFloat
    ) -> [CategoryCalloutLayout] {

        guard !layouts.isEmpty
        else {
            return []
        }


        var adjusted =
            layouts.sorted {
                $0.end.y <
                $1.end.y
            }


        var previousY =
            topLimit -
            minimumGap


        for index in
            adjusted.indices {

            var layout =
                adjusted[
                    index
                ]

            let newY =
                max(
                    layout.end.y,
                    previousY +
                    minimumGap
                )

            layout.bend.y =
                newY

            layout.end.y =
                newY

            adjusted[
                index
            ] =
                layout

            previousY =
                newY
        }


        if let last =
            adjusted.last,
           last.end.y >
                bottomLimit {

            let overflow =
                last.end.y -
                bottomLimit


            for index in
                adjusted.indices
                    .reversed() {

                var layout =
                    adjusted[
                        index
                    ]

                let shiftedY =
                    layout.end.y -
                    overflow


                if index <
                    adjusted.count -
                    1 {

                    let nextY =
                        adjusted[
                            index +
                            1
                        ]
                        .end.y -
                        minimumGap

                    layout.end.y =
                        min(
                            shiftedY,
                            nextY
                        )

                } else {

                    layout.end.y =
                        shiftedY
                }


                layout.end.y =
                    max(
                        layout.end.y,
                        topLimit
                    )

                layout.bend.y =
                    layout.end.y

                adjusted[
                    index
                ] =
                    layout
            }
        }


        return adjusted
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

    let textAnchorX:
        CGFloat

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
