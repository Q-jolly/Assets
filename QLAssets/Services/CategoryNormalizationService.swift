import Foundation
import SwiftData


enum CategoryNormalizer {

    static func normalized(
        _ category:
            String
    ) -> String {

        let trimmed =
            category.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )


        switch trimmed {

        case "住房":
            return "居住"

        default:
            return trimmed
        }
    }
}


enum CategoryDataMigration {

    @MainActor
    static func run(
        context:
            ModelContext
    ) {

        normalizeTransactions(
            context:
                context
        )

        normalizeExpenseCategoryStore()

        normalizeCategoryBudgets()
    }


    @MainActor
    private static func normalizeTransactions(
        context:
            ModelContext
    ) {

        let descriptor =
            FetchDescriptor<
                TransactionRecord
            >()


        guard
            let transactions =
                try?
                    context.fetch(
                        descriptor
                    )
        else {
            return
        }


        var didChange =
            false


        for transaction in
            transactions {

            let normalized =
                CategoryNormalizer
                    .normalized(
                        transaction.category
                    )


            guard
                normalized !=
                    transaction.category
            else {
                continue
            }


            transaction.category =
                normalized

            didChange =
                true
        }


        guard didChange
        else {
            return
        }


        try?
            context.save()
    }


    private static func normalizeExpenseCategoryStore() {

        let defaults =
            UserDefaults.standard

        let stored =
            defaults.string(
                forKey:
                    CategoryStore
                        .expenseKey
            ) ??
            ""


        guard
            !stored.isEmpty
        else {
            return
        }


        let items =
            CategoryStore
                .expenseCategories(
                    from:
                        stored
                )


        var preferredByName:
            [String: CategoryItem] =
                [:]


        // 先处理真正的“居住”，若同时存在“住房”，优先保留现有“居住”的图标和 ID。
        for item in
            items
            where item.name ==
                "居住" {

            preferredByName[
                "居住"
            ] =
                item
        }


        for item in
            items {

            let normalizedName =
                CategoryNormalizer
                    .normalized(
                        item.name
                    )


            guard
                preferredByName[
                    normalizedName
                ] ==
                nil
            else {
                continue
            }


            var normalizedItem =
                item

            normalizedItem.name =
                normalizedName

            preferredByName[
                normalizedName
            ] =
                normalizedItem
        }


        var seen =
            Set<String>()

        var normalizedItems:
            [CategoryItem] = []


        for item in
            items {

            let normalizedName =
                CategoryNormalizer
                    .normalized(
                        item.name
                    )


            guard
                seen.insert(
                    normalizedName
                )
                .inserted,
                let normalizedItem =
                    preferredByName[
                        normalizedName
                    ]
            else {
                continue
            }


            normalizedItems.append(
                normalizedItem
            )
        }


        let encoded =
            CategoryStore
                .encode(
                    normalizedItems
                )


        guard
            !encoded.isEmpty,
            encoded != stored
        else {
            return
        }


        defaults.set(
            encoded,
            forKey:
                CategoryStore
                    .expenseKey
        )
    }


    private static func normalizeCategoryBudgets() {

        let defaults =
            UserDefaults.standard

        let stored =
            defaults.string(
                forKey:
                    CategoryBudgetStore
                        .storageKey
            ) ??
            ""


        guard
            !stored.isEmpty
        else {
            return
        }


        var budgets =
            CategoryBudgetStore
                .decode(
                    stored
                )


        guard
            let housingBudget =
                budgets[
                    "住房"
                ]
        else {
            return
        }


        // 如果用户已经给“居住”单独设置过预算，则保留“居住”的值；
        // 否则把旧“住房”预算迁移过去。
        if budgets[
            "居住"
        ] ==
            nil {

            budgets[
                "居住"
            ] =
                housingBudget
        }


        budgets.removeValue(
            forKey:
                "住房"
        )


        defaults.set(
            CategoryBudgetStore
                .encode(
                    budgets
                ),
            forKey:
                CategoryBudgetStore
                    .storageKey
        )
    }
}
