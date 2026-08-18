import Foundation


struct CategoryItem:
    Codable,
    Identifiable,
    Hashable {

    var id:
        UUID

    var name:
        String

    var icon:
        String


    init(
        id:
            UUID = UUID(),
        name:
            String,
        icon:
            String
    ) {

        self.id =
            id

        self.name =
            name

        self.icon =
            icon
    }
}


enum CategoryStore {

    static let expenseKey =
        "categories.expense.v1"

    static let incomeKey =
        "categories.income.v1"


    static let defaultExpense:
        [CategoryItem] = [

            CategoryItem(
                name:
                    "餐饮",
                icon:
                    "fork.knife"
            ),

            CategoryItem(
                name:
                    "交通",
                icon:
                    "car.fill"
            ),

            CategoryItem(
                name:
                    "购物",
                icon:
                    "bag.fill"
            ),

            CategoryItem(
                name:
                    "娱乐",
                icon:
                    "gamecontroller.fill"
            ),

            CategoryItem(
                name:
                    "居住",
                icon:
                    "house.fill"
            ),

            CategoryItem(
                name:
                    "医疗",
                icon:
                    "cross.case.fill"
            ),

            CategoryItem(
                name:
                    "数码",
                icon:
                    "laptopcomputer"
            ),

            CategoryItem(
                name:
                    "衣物",
                icon:
                    "tshirt.fill"
            ),

            CategoryItem(
                name:
                    "日用",
                icon:
                    "cart.fill"
            ),

            CategoryItem(
                name:
                    "其他",
                icon:
                    "ellipsis.circle.fill"
            )
        ]


    static let defaultIncome:
        [CategoryItem] = [

            CategoryItem(
                name:
                    "工资",
                icon:
                    "yensign.circle.fill"
            ),

            CategoryItem(
                name:
                    "奖金",
                icon:
                    "gift.fill"
            ),

            CategoryItem(
                name:
                    "兼职",
                icon:
                    "briefcase.fill"
            ),

            CategoryItem(
                name:
                    "理财",
                icon:
                    "chart.line.uptrend.xyaxis"
            ),

            CategoryItem(
                name:
                    "红包",
                icon:
                    "envelope.open.fill"
            ),

            CategoryItem(
                name:
                    "报销",
                icon:
                    "receipt.fill"
            ),

            CategoryItem(
                name:
                    "其他",
                icon:
                    "ellipsis.circle.fill"
            )
        ]


    static let availableIcons:
        [String] = [

            "fork.knife",
            "cup.and.saucer.fill",
            "takeoutbag.and.cup.and.straw.fill",
            "car.fill",
            "bus.fill",
            "airplane",
            "bag.fill",
            "cart.fill",
            "gift.fill",
            "gamecontroller.fill",
            "film.fill",
            "music.note",
            "house.fill",
            "bed.double.fill",
            "cross.case.fill",
            "pills.fill",
            "figure.run",
            "laptopcomputer",
            "iphone",
            "tshirt.fill",
            "pawprint.fill",
            "book.fill",
            "graduationcap.fill",
            "briefcase.fill",
            "yensign.circle.fill",
            "chart.line.uptrend.xyaxis",
            "envelope.open.fill",
            "receipt.fill",
            "ellipsis.circle.fill"
        ]


    static func expenseCategories(
        from stored:
            String
    ) -> [CategoryItem] {

        decode(
            stored,
            fallback:
                defaultExpense
        )
    }


    static func incomeCategories(
        from stored:
            String
    ) -> [CategoryItem] {

        decode(
            stored,
            fallback:
                defaultIncome
        )
    }


    static func decode(
        _ stored:
            String,
        fallback:
            [CategoryItem]
    ) -> [CategoryItem] {

        guard
            !stored.isEmpty,
            let data =
                stored.data(
                    using:
                        .utf8
                ),
            let decoded =
                try?
                    JSONDecoder()
                        .decode(
                            [CategoryItem]
                                .self,
                            from:
                                data
                        ),
            !decoded.isEmpty
        else {

            return fallback
        }

        return decoded
    }


    static func encode(
        _ items:
            [CategoryItem]
    ) -> String {

        guard
            let data =
                try?
                    JSONEncoder()
                        .encode(
                            items
                        ),
            let string =
                String(
                    data:
                        data,
                    encoding:
                        .utf8
                )
        else {

            return ""
        }

        return string
    }


    static func icon(
        for category:
            String,
        expenseStored:
            String = UserDefaults.standard
                .string(
                    forKey:
                        expenseKey
                )
                ?? "",
        incomeStored:
            String = UserDefaults.standard
                .string(
                    forKey:
                        incomeKey
                )
                ?? ""
    ) -> String {

        let all =
            expenseCategories(
                from:
                    expenseStored
            ) +
            incomeCategories(
                from:
                    incomeStored
            )


        return all.first {
            $0.name ==
                category
        }?
        .icon
        ?? "tag.fill"
    }
}
