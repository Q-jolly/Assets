import SwiftUI
import SwiftData

struct TransactionListView: View {

    @Environment(\.modelContext)
    private var modelContext

    @Query(
        sort: \TransactionRecord.date,
        order: .reverse
    )
    private var transactions:
        [TransactionRecord]

    @Query
    private var accounts:
        [Account]

    var body: some View {

        List {

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

            } else {

                ForEach(
                    transactions
                ) { transaction in

                    TransactionRowView(
                        transaction:
                            transaction,
                        accountName:
                            accountName(
                                transaction
                                    .accountID
                            )
                    )
                }
                .onDelete(
                    perform:
                        deleteTransactions
                )
            }
        }
        .navigationTitle("账单")
    }

    private func accountName(
        _ id: UUID
    ) -> String {

        accounts.first {
            $0.id == id
        }?.name ?? "未知账户"
    }

    private func deleteTransactions(
        offsets: IndexSet
    ) {

        for index in offsets {

            let transaction =
                transactions[index]

            reverseBalance(
                transaction
            )

            modelContext.delete(
                transaction
            )
        }

        try? modelContext.save()
    }

    private func reverseBalance(
        _ transaction:
            TransactionRecord
    ) {

        guard
            let source =
                accounts.first(
                    where: {

                        $0.id ==
                            transaction
                                .accountID
                    }
                )
        else {

            return
        }

        switch transaction.type {

        case .expense:

            source.balance +=
                transaction.amount

        case .income:

            source.balance -=
                transaction.amount

        case .transfer:

            source.balance +=
                transaction.amount

            if
                let targetID =
                    transaction
                        .targetAccountID,

                let target =
                    accounts.first(
                        where: {

                            $0.id ==
                                targetID
                        }
                    ) {

                target.balance -=
                    transaction.amount
            }
        }
    }
}


// MARK: - 账单行

struct TransactionRowView: View {

    let transaction:
        TransactionRecord

    let accountName:
        String

    var body: some View {

        HStack(
            spacing: 12
        ) {

            ZStack {

                Circle()
                    .fill(
                        Color(
                            .secondarySystemBackground
                        )
                    )
                    .frame(
                        width: 44,
                        height: 44
                    )

                Image(
                    systemName:
                        iconName
                )
            }

            VStack(
                alignment: .leading,
                spacing: 4
            ) {

                Text(
                    transaction.category
                )
                .font(.headline)

                Text(
                    "\(accountName) · \(transaction.date.formatted(date: .abbreviated, time: .shortened))"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )

                if !transaction
                    .note
                    .isEmpty {

                    Text(
                        transaction.note
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
            }

            Spacer()

            Text(amountText)
                .fontWeight(
                    .semibold
                )
        }
        .padding(
            .vertical,
            4
        )
    }

    private var amountText:
        String {

        let formatted =
            transaction
                .amount
                .formatted(
                    .currency(
                        code: "CNY"
                    )
                )

        switch transaction.type {

        case .expense:

            return "-\(formatted)"

        case .income:

            return "+\(formatted)"

        case .transfer:

            return formatted
        }
    }

    private var iconName:
        String {

        switch transaction.type {

        case .expense:

            return "arrow.up.right"

        case .income:

            return "arrow.down.left"

        case .transfer:

            return "arrow.left.arrow.right"
        }
    }
}