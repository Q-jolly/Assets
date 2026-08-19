import SwiftUI


enum CategoryAppearance {

    private static let fallbackPalette:
        [Color] = [

            .blue,
            .green,
            .orange,
            .purple,
            .red,
            .teal,
            .pink,
            .indigo,
            .mint,
            .cyan
        ]


    static func icon(
        for transaction:
            TransactionRecord,
        expenseStored:
            String,
        incomeStored:
            String
    ) -> String {

        switch transaction.type {

        case .expense,
             .creditExpense:

            return matchingItem(
                category:
                    transaction.category,
                items:
                    CategoryStore
                        .expenseCategories(
                            from:
                                expenseStored
                        )
            )?
            .icon ??
            transaction.type.icon


        case .income:

            return matchingItem(
                category:
                    transaction.category,
                items:
                    CategoryStore
                        .incomeCategories(
                            from:
                                incomeStored
                        )
            )?
            .icon ??
            transaction.type.icon


        case .transfer,
             .creditRepayment,
             .adjustment:

            return transaction
                .type
                .icon
        }
    }


    static func color(
        for transaction:
            TransactionRecord
    ) -> Color {

        switch transaction.type {

        case .transfer:
            return .blue

        case .creditRepayment:
            return .indigo

        case .adjustment:
            return .gray

        case .income:
            return incomeColor(
                category:
                    transaction.category
            )

        case .expense,
             .creditExpense:
            return expenseColor(
                category:
                    transaction.category
            )
        }
    }


    private static func expenseColor(
        category:
            String
    ) -> Color {

        switch category {

        case "餐饮":
            return .orange

        case "交通":
            return .blue

        case "购物":
            return .pink

        case "娱乐":
            return .purple

        case "居住",
             "住房":
            return .green

        case "医疗":
            return .red

        case "数码":
            return .indigo

        case "衣物":
            return .pink

        case "日用":
            return .teal

        case "买菜":
            return .green

        case "其他",
             "未分类":
            return .gray

        default:
            return stableColor(
                for:
                    category
            )
        }
    }


    private static func incomeColor(
        category:
            String
    ) -> Color {

        switch category {

        case "工资":
            return .green

        case "奖金":
            return .orange

        case "兼职":
            return .blue

        case "理财":
            return .indigo

        case "红包":
            return .red

        case "报销":
            return .teal

        case "其他",
             "未分类":
            return .gray

        default:
            return stableColor(
                for:
                    category
            )
        }
    }


    private static func stableColor(
        for text:
            String
    ) -> Color {

        let value =
            text.unicodeScalars
                .reduce(0) {
                    partial,
                    scalar in

                    partial +
                    Int(
                        scalar.value
                    )
                }

        return fallbackPalette[
            abs(
                value
            ) %
            fallbackPalette.count
        ]
    }


    private static func matchingItem(
        category:
            String,
        items:
            [CategoryItem]
    ) -> CategoryItem? {

        items.first {
            $0.name ==
            category
        }
    }
}
