import Foundation


enum CategoryBudgetStore {

    static let storageKey =
        "budget.categories.v1"


    static func decode(
        _ stored:
            String
    ) -> [String: Double] {

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
                            [String: Double]
                                .self,
                            from:
                                data
                        )
        else {

            return [:]
        }

        return decoded.filter {
            $0.value >
            0
        }
    }


    static func encode(
        _ budgets:
            [String: Double]
    ) -> String {

        let cleaned =
            budgets.filter {
                $0.value >
                0
            }

        guard
            let data =
                try?
                    JSONEncoder()
                        .encode(
                            cleaned
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
}
