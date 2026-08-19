import SwiftUI
import SwiftData
import Foundation


enum AppTime {

    static let timeZone =
        TimeZone(
            identifier:
                "Asia/Shanghai"
        )!


    static var calendar:
        Calendar {

        var calendar =
            Calendar(
                identifier:
                    .gregorian
            )

        calendar.timeZone =
            timeZone

        calendar.locale =
            Locale(
                identifier:
                    "zh_CN"
            )

        return calendar
    }


    static func listDateTime(
        _ date: Date
    ) -> String {

        let formatter =
            DateFormatter()

        formatter.calendar =
            calendar

        formatter.timeZone =
            timeZone

        formatter.locale =
            Locale(
                identifier:
                    "zh_CN"
            )

        formatter.dateFormat =
            "M月d日 HH:mm"

        return formatter.string(
            from: date
        )
    }


    static func detailDateTime(
        _ date: Date
    ) -> String {

        let formatter =
            DateFormatter()

        formatter.calendar =
            calendar

        formatter.timeZone =
            timeZone

        formatter.locale =
            Locale(
                identifier:
                    "zh_CN"
            )

        formatter.dateFormat =
            "yyyy年M月d日 HH:mm"

        return formatter.string(
            from: date
        )
    }
}


@main
struct QLAssetsApp: App {

    @StateObject
    private var appLock =
        AppLockManager()

    @AppStorage(
        AppPreferenceKeys
            .appearanceMode
    )
    private var appearanceModeRaw =
        AppAppearanceMode
            .system
            .rawValue


    private var appearanceMode:
        AppAppearanceMode {

        AppAppearanceMode(
            rawValue:
                appearanceModeRaw
        ) ??
        .system
    }


    var body: some Scene {

        WindowGroup {

            AppLockContainerView()
                .environmentObject(
                    appLock
                )
                .environment(
                    \.timeZone,
                    AppTime.timeZone
                )
                .environment(
                    \.calendar,
                    AppTime.calendar
                )
                .preferredColorScheme(
                    appearanceMode
                        .colorScheme
                )
        }
        .modelContainer(
            for: [
                Account.self,
                TransactionRecord.self,
                BankCard.self
            ]
        )
    }
}
