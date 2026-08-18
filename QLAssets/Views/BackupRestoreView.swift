import SwiftUI
import SwiftData
import UniformTypeIdentifiers


struct BackupRestoreView:
    View {

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
            \TransactionRecord.date,
        order:
            .reverse
    )
    private var transactions:
        [TransactionRecord]

    @Query(
        sort: [
            SortDescriptor(
                \BankCard.sortOrder
            ),
            SortDescriptor(
                \BankCard.createdAt
            )
        ]
    )
    private var cards:
        [BankCard]


    @State
    private var exportDocument =
        QLAssetsBackupDocument()

    @State
    private var showExporter =
        false

    @State
    private var showImporter =
        false

    @State
    private var pendingRestore:
        QLAssetsBackup?

    @State
    private var showRestoreConfirmation =
        false

    @State
    private var messageTitle =
        ""

    @State
    private var messageText =
        ""

    @State
    private var showMessage =
        false


    var body:
        some View {

        List {

            Section {

                backupSummaryRow(
                    title:
                        "账户",
                    value:
                        "\(accounts.count) 个"
                )

                backupSummaryRow(
                    title:
                        "账单",
                    value:
                        "\(transactions.count) 笔"
                )

                backupSummaryRow(
                    title:
                        "银行卡",
                    value:
                        "\(cards.count) 张"
                )

                backupSummaryRow(
                    title:
                        "自定义卡面",
                    value:
                        "\(customFaceCount) 张"
                )

            } header: {

                Text(
                    "当前数据"
                )
            }


            Section {

                Button {

                    exportBackup()

                } label: {

                    Label(
                        "导出完整备份",
                        systemImage:
                            "square.and.arrow.up"
                    )
                }


                Button {

                    showImporter =
                        true

                } label: {

                    Label(
                        "从备份恢复",
                        systemImage:
                            "square.and.arrow.down"
                    )
                }

            } header: {

                Text(
                    "本地备份"
                )

            } footer: {

                Text(
                    "备份包含账户、账单、银行卡、月度预算和自定义银行卡卡面。完整银行卡号从未保存在 App 中，因此备份也不会包含完整卡号。"
                )
            }


            Section {

                Label(
                    "备份文件由你手动保存到“文件”App、iCloud Drive 或其他位置。",
                    systemImage:
                        "lock.doc"
                )

                Label(
                    "恢复会覆盖当前 QL Assets 数据。",
                    systemImage:
                        "exclamationmark.triangle"
                )

            } header: {

                Text(
                    "说明"
                )
            }
        }
        .navigationTitle(
            "备份与恢复"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .fileExporter(
            isPresented:
                $showExporter,
            document:
                exportDocument,
            contentType:
                QLAssetsBackupDocument
                    .readableContentTypes
                    .first
                ?? .json,
            defaultFilename:
                backupFilename
        ) { result in

            switch result {

            case .success:

                showMessage(
                    title:
                        "备份完成",
                    text:
                        "备份文件已导出。"
                )

            case .failure(
                let error
            ):

                showMessage(
                    title:
                        "导出失败",
                    text:
                        error
                            .localizedDescription
                )
            }
        }
        .fileImporter(
            isPresented:
                $showImporter,
            allowedContentTypes:
                QLAssetsBackupDocument
                    .readableContentTypes,
            allowsMultipleSelection:
                false
        ) { result in

            importBackup(
                result
            )
        }
        .confirmationDialog(
            "恢复备份？",
            isPresented:
                $showRestoreConfirmation,
            titleVisibility:
                .visible
        ) {

            Button(
                "覆盖当前数据并恢复",
                role:
                    .destructive
            ) {

                performRestore()
            }


            Button(
                "取消",
                role:
                    .cancel
            ) {}

        } message: {

            if let backup =
                pendingRestore {

                Text(
                    "备份包含 \(backup.accounts.count) 个账户、\(backup.transactions.count) 笔账单和 \(backup.cards.count) 张银行卡。当前数据会被替换。"
                )
            }
        }
        .alert(
            messageTitle,
            isPresented:
                $showMessage
        ) {

            Button(
                "好的"
            ) {}

        } message: {

            Text(
                messageText
            )
        }
    }


    private var customFaceCount:
        Int {

        cards.filter {
            CardFaceImageStore
                .exists(
                    for:
                        $0.id
                )
        }
        .count
    }


    private var backupFilename:
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
            "yyyyMMdd_HHmm"

        return
            "QLAssets_备份_" +
            formatter.string(
                from:
                    Date()
            )
    }


    private func backupSummaryRow(
        title:
            String,
        value:
            String
    ) -> some View {

        LabeledContent(
            title,
            value:
                value
        )
    }


    private func exportBackup() {

        do {

            let data =
                try BackupService
                    .makeBackup(
                        accounts:
                            accounts,
                        transactions:
                            transactions,
                        cards:
                            cards
                    )

            exportDocument =
                QLAssetsBackupDocument(
                    data:
                        data
                )

            showExporter =
                true

        } catch {

            showMessage(
                title:
                    "生成备份失败",
                text:
                    error
                        .localizedDescription
            )
        }
    }


    private func importBackup(
        _ result:
            Result<[URL], Error>
    ) {

        do {

            let urls =
                try result
                    .get()


            guard
                let url =
                    urls.first
            else {

                return
            }


            let accessing =
                url.startAccessingSecurityScopedResource()


            defer {

                if accessing {

                    url.stopAccessingSecurityScopedResource()
                }
            }


            let data =
                try Data(
                    contentsOf:
                        url
                )


            let backup =
                try BackupService
                    .decodeBackup(
                        data
                    )


            pendingRestore =
                backup

            showRestoreConfirmation =
                true

        } catch {

            showMessage(
                title:
                    "读取备份失败",
                text:
                    error
                        .localizedDescription
            )
        }
    }


    private func performRestore() {

        guard
            let pendingRestore
        else {

            return
        }


        do {

            try BackupService
                .restore(
                    pendingRestore,
                    existingAccounts:
                        accounts,
                    existingTransactions:
                        transactions,
                    existingCards:
                        cards,
                    context:
                        modelContext
                )


            self.pendingRestore =
                nil


            showMessage(
                title:
                    "恢复完成",
                text:
                    "账户、账单、银行卡、预算和卡面已恢复。"
            )

        } catch {

            showMessage(
                title:
                    "恢复失败",
                text:
                    error
                        .localizedDescription
            )
        }
    }


    private func showMessage(
        title:
            String,
        text:
            String
    ) {

        messageTitle =
            title

        messageText =
            text

        showMessage =
            true
    }
}
