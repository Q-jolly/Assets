import SwiftUI
import SwiftData

struct HomeView: View {

    @Query(
        sort: \Account.createdAt
    )
    private var accounts: [Account]

    @Query(
        sort: \TransactionRecord.date,
        order: .reverse
    )
    private var transactions: [TransactionRecord]


    // MARK: - 统计

    private var totalAssets: Double {

        accounts.reduce(0) {
            $0 + $1.balance
        }
    }


    private var monthlyExpense: Double {

        transactions
            .filter {

                $0.type == .expense &&

                Calendar.current.isDate(
                    $0.date,
                    equalTo: Date(),
                    toGranularity: .month
                )
            }
            .reduce(0) {
                $0 + abs($1.amount)
            }
    }


    private var monthlyIncome: Double {

        transactions
            .filter {

                $0.type == .income &&

                Calendar.current.isDate(
                    $0.date,
                    equalTo: Date(),
                    toGranularity: .month
                )
            }
            .reduce(0) {
                $0 + abs($1.amount)
            }
    }


    var body: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 24
            ) {

                netAssetCard

                HStack(spacing: 12) {

                    summaryCard(
                        title: "本月支出",
                        value: monthlyExpense
                    )

                    summaryCard(
                        title: "本月收入",
                        value: monthlyIncome
                    )
                }

                recentTransactions
            }
            .padding()
        }
        .navigationTitle("QL Assets")
    }


    // MARK: - 净资产卡片

    private var netAssetCard: some View {

        VStack(
            alignment: .leading,
            spacing: 10
        ) {

            Text("净资产")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(
                totalAssets,
                format: .currency(code: "CNY")
            )
            .font(
                .system(
                    size: 36,
                    weight: .bold,
                    design: .rounded
                )
            )
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding()
        .background(
            Color(.secondarySystemBackground)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20
            )
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
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(
                value,
                format: .currency(code: "CNY")
            )
            .font(.headline)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding()
        .background(
            Color(.secondarySystemBackground)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16
            )
        )
    }


    // MARK: - 最近账单

    private var recentTransactions: some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            Text("最近账单")
                .font(.title3.bold())


            if transactions.isEmpty {

                ContentUnavailableView(
                    "暂无账单",
                    systemImage: "tray",
                    description: Text(
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
                            transaction: transaction
                        )

                    } label: {

                        TransactionRowView(
                            transaction: transaction,

                            accountName:
                                accountName(
                                    transaction.accountID
                                ),

                            targetAccountName:
                                transaction
                                    .targetAccountID
                                    .flatMap {
                                        accountName($0)
                                    }
                        )
                        .contentShape(
                            Rectangle()
                        )
                    }
                    .buttonStyle(.plain)


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


    // MARK: - 账户名称

    private func accountName(
        _ id: UUID
    ) -> String {

        accounts.first {

            $0.id == id

        }?.name
        ?? "未知账户"
    }
}