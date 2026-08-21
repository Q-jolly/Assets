import AppIntents
import Foundation


struct GetCategoriesIntent: AppIntent {

    static let title: LocalizedStringResource = "获取分类列表"

    static let description = IntentDescription(
        "读取 QL Assets 当前维护的收入和支出分类，供快捷指令动态选择。"
    )

    static let openAppWhenRun = false

    @Parameter(title: "类型")
    var type: String?

    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {

        let normalized = type?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let values: [String]

        switch normalized {

        case "income", "收入", "in":
            values = QuickAddTransactionSupport.categoryNames(for: .income)

        case "expense", "支出", "out", "debit":
            values = QuickAddTransactionSupport.categoryNames(for: .expense)

        default:
            values = QuickAddTransactionSupport.allCategoryNames()
        }

        return .result(value: values)
    }
}
