import AppIntents
import Foundation


struct GetCategoriesIntent: AppIntent {

    static let title: LocalizedStringResource = "QL Assets 获取分类"

    static let description = IntentDescription(
        "读取 QL Assets 当前维护的收入和支出分类，供快捷指令动态选择。"
    )

    static let openAppWhenRun = false

    @Parameter(title: "类型")
    var type: QuickAddTransactionType?

    func perform() async throws -> some IntentResult & ReturnsValue<[QuickAddCategoryEntity]> {

        let all = try await QuickAddCategoryQuery().suggestedEntities()
        guard let type else {
            return .result(value: all)
        }

        // Filter by the persisted category identity/type, not by a duplicated
        // Shortcut-side name array.
        return .result(value: all.filter { $0.transactionType == type })
    }
}
