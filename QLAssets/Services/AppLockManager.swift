import Foundation
import LocalAuthentication


@MainActor
final class AppLockManager:
    ObservableObject {

    static let appLockEnabledKey =
        "security.appLockEnabled"

    static let hideInSwitcherKey =
        "security.hideInAppSwitcher"


    static let automaticLockDelayMinutesKey =
        "security.automaticLockDelayMinutes"


    static let defaultAutomaticLockDelayMinutes =
        5


    private var backgroundEnteredAt:
        Date?


    @Published
    private(set)
    var isLocked =
        false

    @Published
    private(set)
    var isAuthenticating =
        false

    @Published
    var lastErrorMessage:
        String?


    var isAppLockEnabled:
        Bool {

        get {

            UserDefaults.standard
                .bool(
                    forKey:
                        Self
                            .appLockEnabledKey
                )
        }

        set {

            UserDefaults.standard
                .set(
                    newValue,
                    forKey:
                        Self
                            .appLockEnabledKey
                )

            if !newValue {

                backgroundEnteredAt =
                    nil

                isLocked =
                    false
            }
        }
    }


    var hideInAppSwitcher:
        Bool {

        get {

            if UserDefaults.standard
                .object(
                    forKey:
                        Self
                            .hideInSwitcherKey
                ) ==
                nil {

                return true
            }

            return UserDefaults.standard
                .bool(
                    forKey:
                        Self
                            .hideInSwitcherKey
                )
        }

        set {

            UserDefaults.standard
                .set(
                    newValue,
                    forKey:
                        Self
                            .hideInSwitcherKey
                )
        }
    }


    var automaticLockDelayMinutes:
        Int {

        get {

            let stored =
                UserDefaults.standard
                    .integer(
                        forKey:
                            Self
                                .automaticLockDelayMinutesKey
                    )


            // 0 代表“永不自动锁定”。
            // 首次安装没有值时默认 5 分钟。
            if UserDefaults.standard
                .object(
                    forKey:
                        Self
                            .automaticLockDelayMinutesKey
                ) ==
                nil {

                return
                    Self
                        .defaultAutomaticLockDelayMinutes
            }

            return stored
        }

        set {

            UserDefaults.standard
                .set(
                    newValue,
                    forKey:
                        Self
                            .automaticLockDelayMinutesKey
                )
        }
    }


    var automaticLockDelay:
        TimeInterval? {

        guard automaticLockDelayMinutes >
                0
        else {

            return nil
        }

        return
            TimeInterval(
                automaticLockDelayMinutes *
                60
            )
    }


    var authenticationTitle:
        String {

        let context =
            LAContext()

        var error:
            NSError?

        _ =
            context
                .canEvaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    error:
                        &error
                )


        switch context.biometryType {

        case .faceID:

            return
                "Face ID"

        case .touchID:

            return
                "Touch ID"

        case .opticID:

            return
                "Optic ID"

        case .none:

            return
                "设备验证"

        @unknown default:

            return
                "设备验证"
        }
    }


    func prepareForLaunch() {

        backgroundEnteredAt =
            nil


        guard isAppLockEnabled
        else {

            isLocked =
                false

            return
        }


        // 冷启动仍然需要验证。
        isLocked =
            true
    }


    func didEnterBackground(
        at date:
            Date =
                Date()
    ) {

        guard isAppLockEnabled
        else {

            backgroundEnteredAt =
                nil

            isLocked =
                false

            return
        }


        // 这里只记录离开时间，不立刻锁定。
        backgroundEnteredAt =
            date
    }


    func shouldUnlockAfterBecomingActive(
        at date:
            Date =
                Date()
    ) -> Bool {

        guard isAppLockEnabled
        else {

            backgroundEnteredAt =
                nil

            isLocked =
                false

            return false
        }


        // 手动“立即锁定”或冷启动产生的锁定，
        // 回到前台时仍然需要解锁。
        if isLocked {

            backgroundEnteredAt =
                nil

            return true
        }


        guard
            let backgroundEnteredAt
        else {

            return false
        }


        self.backgroundEnteredAt =
            nil


        guard
            let automaticLockDelay
        else {

            // “永不”只影响自动锁定；
            // 冷启动和手动“立即锁定”仍然有效。
            return false
        }


        let elapsed =
            max(
                0,
                date.timeIntervalSince(
                    backgroundEnteredAt
                )
            )


        guard elapsed >=
                automaticLockDelay
        else {

            return false
        }


        isLocked =
            true

        return true
    }


    func lockNow() {

        guard isAppLockEnabled
        else {
            return
        }


        backgroundEnteredAt =
            nil

        isLocked =
            true
    }


    func authenticateForEnabling()
        async -> Bool {

        await authenticate(
            reason:
                "验证身份后开启 QL Assets 应用锁"
        )
    }


    func unlock()
        async -> Bool {

        guard isAppLockEnabled
        else {

            isLocked =
                false

            return true
        }


        let success =
            await authenticate(
                reason:
                    "解锁 QL Assets，查看你的资产信息"
            )


        if success {

            isLocked =
                false
        }

        return success
    }


    private func authenticate(
        reason:
            String
    ) async -> Bool {

        guard !isAuthenticating
        else {

            return false
        }


        isAuthenticating =
            true

        lastErrorMessage =
            nil


        defer {

            isAuthenticating =
                false
        }


        let context =
            LAContext()

        context.localizedCancelTitle =
            "取消"

        context.localizedFallbackTitle =
            "使用设备密码"


        var error:
            NSError?


        guard
            context.canEvaluatePolicy(
                .deviceOwnerAuthentication,
                error:
                    &error
            )
        else {

            lastErrorMessage =
                error?
                    .localizedDescription
                ?? "当前设备无法进行身份验证"

            return false
        }


        do {

            let success =
                try await context
                    .evaluatePolicy(
                        .deviceOwnerAuthentication,
                        localizedReason:
                            reason
                    )

            if !success {

                lastErrorMessage =
                    "身份验证未通过"
            }

            return success

        } catch {

            let nsError =
                error as NSError


            if nsError.code !=
                LAError
                    .userCancel
                    .rawValue &&
               nsError.code !=
                LAError
                    .systemCancel
                    .rawValue {

                lastErrorMessage =
                    error
                        .localizedDescription
            }

            return false
        }
    }
}
