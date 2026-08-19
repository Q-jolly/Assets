import SwiftUI
import SwiftData


struct HomeView: View {

    @Environment(
        \.modelContext
    )
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

    @Query(
        sort: \TransactionRecord.date,
        order: .reverse
    )
    private var transactions:
        [TransactionRecord]

    @AppStorage(
        "monthlyBudgetCNY"
    )
    private var monthlyBudget:
        Double = 0

    @AppStorage(
        "privacy.homeAmountsVisible.v1"
    )
    private var homeAmountsVisible =
        true

    @State
    private var exchangeRates =
        ExchangeRateService
            .cachedSnapshot()

    @State
    private var isRefreshingRates =
        false


    // MARK: - 资产统计

    private var totalAssets:
        Double {

        accounts.reduce(0) {
            result,
            account in

            result +
            account.balance *
            valuationRate(
                for:
                    account
            )
        }
    }


    private var totalDebt:
        Double {

        creditCards.reduce(0) {
            $0 + max(
                $1.currentDebt ?? 0,
                0
            )
        }
    }


    private var netAssets:
        Double {

        totalAssets -
        totalDebt
    }


    private var creditCards:
        [BankCard] {

        cards.filter {
            $0.cardType == .credit
        }
    }


    private var monthlyExpense:
        Double {

        transactions
            .filter {

                ($0.type == .expense ||
                 $0.type == .creditExpense) &&

                AppTime.calendar.isDate(
                    $0.date,
                    equalTo: Date(),
                    toGranularity:
                        .month
                )
            }
            .reduce(0) {
                $0 + abs($1.amount)
            }
    }


    private var monthlyIncome:
        Double {

        transactions
            .filter {

                $0.type == .income &&

                AppTime.calendar.isDate(
                    $0.date,
                    equalTo: Date(),
                    toGranularity:
                        .month
                )
            }
            .reduce(0) {
                $0 + abs($1.amount)
            }
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


    private var budgetStatusText:
        String? {

        guard monthlyBudget > 0
        else {
            return nil
        }

        if rawBudgetProgress >= 1 {

            return
                "本月已超预算 \(abs(monthlyBudget - monthlyExpense).formatted(.currency(code: "CNY")))"

        } else if rawBudgetProgress >= 0.8 {

            return
                "预算已使用 \(Int(rawBudgetProgress * 100))%"
        }

        return nil
    }


    var body: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 24
            ) {

                netAssetCard

                HStack(
                    spacing: 12
                ) {

                    summaryCard(
                        title:
                            "本月支出",
                        value:
                            monthlyExpense
                    )

                    summaryCard(
                        title:
                            "本月收入",
                        value:
                            monthlyIncome
                    )
                }

                statisticsEntry

                if !creditCards.isEmpty {

                    creditCardDebtSection
                }

                recentTransactions
            }
            .padding()
        }
        .navigationTitle(
            "QL Assets"
        )
        .task {

            await refreshExchangeRates()


            while !Task.isCancelled {

                try? await Task.sleep(
                    for:
                        .seconds(15 * 60)
                )

                await refreshExchangeRates(
                    force:
                        true
                )
            }
        }
        .refreshable {

            await refreshExchangeRates(
                force:
                    true
            )
        }
    }


    private func valuationRate(
        for account:
            Account
    ) -> Double {

        if account.currencyCode ==
            "CNY" {

            return 1
        }


        return exchangeRates
            .rateToCNY(
                for:
                    account.currencyCode
            ) ??
            account.lastKnownRateToCNY ??
            0
    }


    @MainActor
    private func refreshExchangeRates(
        force:
            Bool = false
    ) async {

        guard
            !isRefreshingRates
        else {
            return
        }


        let hasForeignAccount =
            accounts.contains {
                $0.currencyCode !=
                "CNY"
            }


        guard
            hasForeignAccount ||
            force
        else {
            return
        }


        isRefreshingRates =
            true

        defer {

            isRefreshingRates =
                false
        }


        do {

            let snapshot =
                try await ExchangeRateService
                    .refresh(
                        provider:
                            .boc
                    )

            exchangeRates =
                snapshot


            for account in
                accounts
                where account.currencyCode !=
                    "CNY" {

                if let rate =
                    snapshot.rateToCNY(
                        for:
                            account.currencyCode
                    ) {

                    account.lastKnownRateToCNY =
                        rate
                }
            }


            try?
                modelContext.save()

        } catch {

            // 网络失败时继续使用缓存/账户最后一次汇率。
        }
    }


    // MARK: - 净资产卡片

    private var netAssetCard:
        some View {

        VStack(
            alignment: .leading,
            spacing: 18
        ) {

            VStack(
                alignment: .leading,
                spacing: 8
            ) {

                HStack {

                    Text(
                        "净资产"
                    )
                    .font(
                        .subheadline
                    )
                    .foregroundStyle(
                        .secondary
                    )

                    Spacer()

                    Button {

                        withAnimation(
                            .snappy(
                                duration:
                                    0.2
                            )
                        ) {

                            homeAmountsVisible
                                .toggle()
                        }

                        HapticFeedback
                            .selection()

                    } label: {

                        Image(
                            systemName:
                                homeAmountsVisible
                                ? "eye.fill"
                                : "eye.slash.fill"
                        )
                        .font(
                            .subheadline
                                .weight(
                                    .semibold
                                )
                        )
                        .foregroundStyle(
                            .secondary
                        )
                        .frame(
                            width:
                                34,
                            height:
                                34
                        )
                        .contentShape(
                            Circle()
                        )
                    }
                    .buttonStyle(
                        .plain
                    )
                    .accessibilityLabel(
                        homeAmountsVisible
                        ? "隐藏首页金额"
                        : "显示首页金额"
                    )
                }

                Text(
                    privacyAmountText(
                        netAssets
                    )
                )
                .font(
                    .system(
                        size: 36,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .contentTransition(
                    .numericText()
                )
            }


            Divider()


            HStack(
                spacing: 24
            ) {

                assetMetric(
                    title:
                        "总资产",
                    value:
                        totalAssets,
                    icon:
                        "wallet.pass.fill"
                )

                assetMetric(
                    title:
                        "总负债",
                    value:
                        totalDebt,
                    icon:
                        "creditcard.fill"
                )
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
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


    private func privacyAmountText(
        _ value:
            Double
    ) -> String {

        guard homeAmountsVisible
        else {
            return "¥••••••"
        }

        return value.formatted(
            .currency(
                code:
                    "CNY"
            )
        )
    }


    private func assetMetric(
        title: String,
        value: Double,
        icon: String
    ) -> some View {

        HStack(
            spacing: 10
        ) {

            Image(
                systemName:
                    icon
            )
            .frame(
                width: 28,
                height: 28
            )

            VStack(
                alignment: .leading,
                spacing: 2
            ) {

                Text(title)
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )

                Text(
                    privacyAmountText(
                        value
                    )
                )
                .font(
                    .subheadline.bold()
                )
            }

            Spacer(
                minLength: 0
            )
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }


    // MARK: - 月度卡片

    private func summaryCard(
        title: String,
        value: Double
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 8
        ) {

            Text(title)
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )

            Text(
                privacyAmountText(
                    value
                )
            )
            .font(
                .headline
            )
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding()
        .background(
            Color(
                .secondarySystemBackground
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
        )
    }


    // MARK: - 统计入口

    private var statisticsEntry:
        some View {

        NavigationLink {

            StatisticsView()

        } label: {

            VStack(
                alignment: .leading,
                spacing: 12
            ) {

                HStack {

                    Label(
                        "本月分析",
                        systemImage:
                            "chart.xyaxis.line"
                    )
                    .font(
                        .headline
                    )

                    Spacer()

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


                if monthlyBudget > 0 {

                    ProgressView(
                        value:
                            budgetProgress
                    )

                    HStack {

                        Text(
                            "预算使用"
                        )

                        Spacer()

                        Text(
                            homeAmountsVisible
                            ? "¥\(monthlyExpense.formatted(.number.precision(.fractionLength(0)))) / ¥\(monthlyBudget.formatted(.number.precision(.fractionLength(0))))"
                            : "••••••"
                        )
                    }
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )


                    if
                        homeAmountsVisible,
                        let budgetStatusText {

                        Label(
                            budgetStatusText,
                            systemImage:
                                rawBudgetProgress >= 1
                                ? "exclamationmark.triangle.fill"
                                : "exclamationmark.circle.fill"
                        )
                        .font(
                            .caption2
                        )
                        .foregroundStyle(
                            rawBudgetProgress >= 1
                            ? .red
                            : .orange
                        )
                    }

                } else {

                    Text(
                        "查看支出分类、每日趋势、近 6 个月收支，并设置月度预算"
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
        .buttonStyle(
            .plain
        )
    }


    // MARK: - 信用卡负债

    private var creditCardDebtSection:
        some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            HStack {

                Text("信用卡负债")
                    .font(
                        .title3.bold()
                    )

                Spacer()

                Text(
                    privacyAmountText(
                        totalDebt
                    )
                )
                .font(
                    .subheadline.bold()
                )
            }


            ForEach(
                creditCards.prefix(3)
            ) { card in

                NavigationLink {

                    CardDetailView(
                        card: card
                    )

                } label: {

                    HStack(
                        spacing: 12
                    ) {

                        Image(
                            systemName:
                                "creditcard.fill"
                        )
                        .frame(
                            width: 36,
                            height: 36
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
                            spacing: 3
                        ) {

                            Text(
                                card.bankName
                            )
                            .fontWeight(
                                .medium
                            )

                            Text(
                                "•••• \(card.lastFourDigits)"
                            )
                            .font(
                                .caption
                            )
                            .foregroundStyle(
                                .secondary
                            )


                            if CreditAccountService
                                .group(
                                    for:
                                        card,
                                    cards:
                                        cards
                                )
                                .count >
                                1 {

                                Text(
                                    "共用额度"
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

                        VStack(
                            alignment: .trailing,
                            spacing: 3
                        ) {

                            Text(
                                privacyAmountText(
                                    card.currentDebt ??
                                    0
                                )
                            )
                            .fontWeight(
                                .semibold
                            )

                            if let available =
                                CreditAccountService
                                    .availableCredit(
                                        for:
                                            card,
                                        cards:
                                            cards
                                    ) {

                                Text(
                                    homeAmountsVisible
                                    ? "可用 \(available.formatted(.currency(code: "CNY")))"
                                    : "可用 ••••••"
                                )
                                .font(
                                    .caption2
                                )
                                .foregroundStyle(
                                    .secondary
                                )
                            }
                        }
                    }
                    .padding(
                        .vertical,
                        4
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .contentShape(
                        Rectangle()
                    )
                }
                .contentShape(
                    Rectangle()
                )
                .buttonStyle(
                    .plain
                )


                if card.id !=
                    creditCards
                        .prefix(3)
                        .last?
                        .id {

                    Divider()
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
                cornerRadius: 18,
                style: .continuous
            )
        )
    }


    // MARK: - 最近账单

    private var recentTransactions:
        some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            Text("最近账单")
                .font(
                    .title3.bold()
                )


            if transactions.isEmpty {

                ContentUnavailableView(
                    "暂无账单",
                    systemImage:
                        "tray",
                    description:
                        Text(
                            "点击下方「记一笔」开始记录"
                        )
                )

            } else {

                ForEach(
                    Array(
                        transactions.prefix(5)
                    )
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
                            showsAmount:
                                homeAmountsVisible,
                            accountName:
                                accountName(
                                    transaction.accountID
                                ),
                            targetAccountName:
                                transaction
                                    .targetAccountID
                                    .flatMap {
                                        accountName($0)
                                    },
                            cardName:
                                transaction
                                    .bankCardID
                                    .flatMap {
                                        cardName($0)
                                    }
                        )
                        .contentShape(
                            Rectangle()
                        )
                    }
                    .buttonStyle(
                        .plain
                    )


                    if transaction.id !=
                        transactions
                            .prefix(5)
                            .last?
                            .id {

                        Divider()
                    }
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }


    private func accountName(
        _ id: UUID
    ) -> String? {

        accounts.first {
            $0.id == id
        }?.name
    }


    private func cardName(
        _ id: UUID
    ) -> String? {

        cards.first {
            $0.id == id
        }
        .map {
            "\($0.bankName) •••• \($0.lastFourDigits)"
        }
    }
}
