import AppIntents
import Foundation
import SwiftData


struct GetAccountsIntent: AppIntent {

    static let title: LocalizedStringResource = "获取账户列表"

    static let description = IntentDescription(
        "读取 QL Assets 当前账户和已关联银行卡，供快捷指令动态选择。"
    )

    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {

        let values = try await MainActor.run {
            let container = try QuickAddTransactionSupport.makeContainer()
            let context = ModelContext(container)
            return try QuickAddTransactionSupport.accountChoices(context: context)
        }

        return .result(value: values)
    }
}
