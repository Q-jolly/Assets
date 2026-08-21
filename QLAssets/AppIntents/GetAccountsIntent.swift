import AppIntents
import Foundation
import SwiftData


struct GetAccountsIntent: AppIntent {

    static let title: LocalizedStringResource = "QL Assets 获取账户"

    static let description = IntentDescription(
        "读取 QL Assets 当前账户和已关联银行卡，供快捷指令动态选择。"
    )

    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<[QuickAddAccountEntity]> {

        let values = try await QuickAddAccountQuery().suggestedEntities()

        return .result(value: values)
    }
}
