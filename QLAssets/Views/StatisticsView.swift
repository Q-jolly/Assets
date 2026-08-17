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


    private var now:
        Date {

        Date()
    }


    private var monthStart:
        Date {

        AppTime.calendar.dateInterval(
            of: .month,
            for: now
        )?.start ?? now
    }


    private var monthEnd:
        Date {

        AppTime.calendar.date(
            byAdding: .month,
            value: 1,
            to: monthStart
        ) ?? now
    }


    private var currentMonthTransactions:
        [TransactionRecord] {

        transactions.filter {
            $0.date >= monthStart &&
            $0.date < monthEnd
        }
    }


    private var monthlyExpense:
        Double {

        currentMonthTransactions
            .filter {
                $0.type == .expense ||
                $0.type == .creditExpense
            }
            .reduce(0) {
                $0 + abs($1.amount)
            }
    }


    private var monthlyIncome:
        Double {

        currentMonthTransactions
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


    private var budgetRemaining:
        Double {

        monthlyBudget -
        monthlyExpense
    }


    private var currentMonthTitle:
        String {

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
            from: now
        )
    }


    private var dailyExpensePoints:
        [DailyExpensePoint] {

        let expenseTransactions =
            currentMonthTransactions.filter {
                $0.type == .expense ||
                $0.type == .creditExpense
            }

        let grouped =
            Dictionary(
                grouping:
                    expenseTransactions
            ) { transaction in

                AppTime.calendar.startOfDay(
                    for: transaction.date
                )
            }

        return grouped
            .map { date, records in

                DailyExpensePoint(
                    date: date,
                    amount:
                        records.reduce(0) {
                            $0 + abs($1.amount)
                        }
                )
            }
            .sorted {
                $0.date < $1.date
            }
    }


    private var categoryExpensePoints:
        [CategoryExpensePoint] {

        let expenseTransactions =
            currentMonthTransactions.filter {
                $0.type == .expense ||
                $0.type == .creditExpense
            }

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
                $0.amount > $1.amount
            }
    }


    private var sixMonthFlowPoints:
        [MonthlyFlowPoint] {

        guard let firstMonth =
                AppTime.calendar.date(
                    byAdding: .month,
                    value: -5,
                    to: monthStart
                )
        else {
            return []
        }

        return (0..<6).flatMap { offset -> [MonthlyFlowPoint] in

            guard
                let start =
                    AppTime.calendar.date(
                        byAdding: .month,
                        value: offset,
                        to: firstMonth
                    ),
                let end =
                    AppTime.calendar.date(
                        byAdding: .month,
                        value: 1,
                        to: start
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
                    month: start,
                    type: "支出",
                    amount: expense
                ),
                MonthlyFlowPoint(
                    month: start,
                    type: "收入",
                    amount: income
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

                monthSummaryCard

                budgetCard

                dailyExpenseSection

                categorySection

                sixMonthSection
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


    private var monthSummaryCard:
        some View {

        VStack(
            alignment: .leading,
            spacing: 16
        ) {

            Text(
                currentMonthTitle
            )
            .font(
                .headline
            )


            HStack(
                spacing: 12
            ) {

                metricCard(
                    title: "支出",
                    value: monthlyExpense,
                    icon:
                        "arrow.up.right"
                )

                metricCard(
                    title: "收入",
                    value: monthlyIncome,
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
                            code: "CNY"
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
                style: .continuous
            )
        )
    }


    private func metricCard(
        title: String,
        value: Double,
        icon: String
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 8
        ) {

            Label(
                title,
                systemImage: icon
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
                        code: "CNY"
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
            maxWidth: .infinity,
            alignment: .leading
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
                style: .continuous
            )
        )
    }


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
                                    code: "CNY"
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
                                    code: "CNY"
                                )
                        )
                        .fontWeight(
                            .semibold
                        )
                    }
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
                    "设置一个月度支出预算后，可以在首页和统计页随时查看使用进度。"
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
                style: .continuous
            )
        )
    }


    private var dailyExpenseSection:
        some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            Text(
                "本月每日支出"
            )
            .font(
                .title3.bold()
            )


            if dailyExpensePoints.isEmpty {

                emptyChart(
                    text:
                        "本月还没有支出记录"
                )

            } else {

                Chart(
                    dailyExpensePoints
                ) { point in

                    BarMark(
                        x:
                            .value(
                                "日期",
                                point.date,
                                unit: .day
                            ),
                        y:
                            .value(
                                "支出",
                                point.amount
                            )
                    )
                    .cornerRadius(4)
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
                    ) { value in

                        AxisGridLine()

                        AxisTick()

                        AxisValueLabel(
                            format:
                                .dateTime.day()
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
                style: .continuous
            )
        )
    }


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

                Chart(
                    categoryExpensePoints
                ) { point in

                    SectorMark(
                        angle:
                            .value(
                                "金额",
                                point.amount
                            ),
                        innerRadius:
                            .ratio(0.60),
                        angularInset: 2
                    )
                    .foregroundStyle(
                        by:
                            .value(
                                "分类",
                                point.category
                            )
                    )
                }
                .frame(
                    height: 220
                )
                .chartLegend(
                    position: .bottom,
                    alignment: .leading,
                    spacing: 8
                )


                VStack(
                    spacing: 10
                ) {

                    ForEach(
                        Array(
                            categoryExpensePoints
                                .prefix(5)
                        )
                    ) { point in

                        HStack {

                            Text(
                                point.category
                            )

                            Spacer()

                            Text(
                                point.amount,
                                format:
                                    .currency(
                                        code: "CNY"
                                    )
                            )
                            .fontWeight(
                                .medium
                            )
                        }
                        .font(
                            .subheadline
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
                style: .continuous
            )
        )
    }


    private var sixMonthSection:
        some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            Text(
                "近 6 个月收支"
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
                            unit: .month
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
                ) { value in

                    AxisGridLine()

                    AxisTick()

                    AxisValueLabel(
                        format:
                            .dateTime.month()
                    )
                }
            }
            .chartLegend(
                position: .bottom,
                alignment: .leading
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
                style: .continuous
            )
        )
    }


    private func emptyChart(
        text: String
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

            Text(text)
                .font(
                    .subheadline
                )
        }
        .foregroundStyle(
            .secondary
        )
        .frame(
            maxWidth: .infinity,
            minHeight: 150
        )
    }
}


private struct DailyExpensePoint:
    Identifiable {

    let date: Date
    let amount: Double

    var id: Date {
        date
    }
}


private struct CategoryExpensePoint:
    Identifiable {

    let category: String
    let amount: Double

    var id: String {
        category
    }
}


private struct MonthlyFlowPoint:
    Identifiable {

    let month: Date
    let type: String
    let amount: Double

    var id: String {
        "\(month.timeIntervalSince1970)-\(type)"
    }
}


private struct BudgetEditorView: View {

    @Environment(\.dismiss)
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
                        format: "%.2f",
                        monthlyBudget.wrappedValue
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

                        Text("¥")
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
                            role: .destructive
                        ) {

                            monthlyBudget = 0

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
                        parsedAmount == nil ||
                        (parsedAmount ?? 0) <= 0
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
                    of: ",",
                    with: "."
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
