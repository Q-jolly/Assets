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

        let allowed = Set(
            QuickAddTransactionSupport
                .categoryNames(for: type.transactionType)
                .map(CategoryNormalizer.normalized)
        )

        return .result(value: all.filter { allowed.contains($0.name) })
    }
}
