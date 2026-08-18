import SwiftUI


struct SecuritySettingsView:
    View {

    @EnvironmentObject
    private var appLock:
        AppLockManager

    @AppStorage(
        AppLockManager
            .appLockEnabledKey
    )
    private var appLockEnabled =
        false

    @AppStorage(
        AppLockManager
            .hideInSwitcherKey
    )
    private var hideInAppSwitcher =
        true

    @State
    private var pendingLockToggle =
        false

    @State
    private var showError =
        false

    @State
    private var errorMessage =
        ""


    var body:
        some View {

        List {

            Section {

                Toggle(
                    isOn:
                        Binding(
                            get: {
                                appLockEnabled
                            },
                            set: {
                                newValue in

                                handleLockToggle(
                                    newValue
                                )
                            }
                        )
                ) {

                    Label(
                        "应用锁",
                        systemImage:
                            "lock.fill"
                    )
                }
                .disabled(
                    pendingLockToggle
                )


                if appLockEnabled {

                    Button {

                        appLock
                            .lockNow()

                    } label: {

                        Label(
                            "立即锁定",
                            systemImage:
                                "lock"
                        )
                    }
                }

            } header: {

                Text(
                    "应用锁"
                )

            } footer: {

                Text(
                    "开启后，QL Assets 每次离开前台都会重新锁定，可使用 Face ID、Touch ID 或设备密码解锁。"
                )
            }


            Section {

                Toggle(
                    "隐藏 App 切换器内容",
                    isOn:
                        $hideInAppSwitcher
                )

            } header: {

                Text(
                    "隐私保护"
                )

            } footer: {

                Text(
                    "开启后，切换到其他 App 或进入后台时，会用隐私页遮住资产余额、账单和银行卡内容。"
                )
            }


            Section {

                LabeledContent(
                    "验证方式",
                    value:
                        appLock
                            .authenticationTitle
                )

                LabeledContent(
                    "数据位置",
                    value:
                        "仅本机"
                )
            } header: {

                Text(
                    "安全状态"
                )
            }
        }
        .navigationTitle(
            "隐私与安全"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .alert(
            "无法开启应用锁",
            isPresented:
                $showError
        ) {

            Button(
                "好的"
            ) {}

        } message: {

            Text(
                errorMessage
            )
        }
    }


    private func handleLockToggle(
        _ newValue:
            Bool
    ) {

        if !newValue {

            appLockEnabled =
                false

            appLock
                .isAppLockEnabled =
                false

            return
        }


        pendingLockToggle =
            true


        Task {

            let success =
                await appLock
                    .authenticateForEnabling()


            await MainActor.run {

                pendingLockToggle =
                    false


                if success {

                    appLockEnabled =
                        true

                    appLock
                        .isAppLockEnabled =
                        true

                } else {

                    appLockEnabled =
                        false

                    appLock
                        .isAppLockEnabled =
                        false

                    errorMessage =
                        appLock
                            .lastErrorMessage
                        ?? "身份验证未通过"

                    showError =
                        true
                }
            }
        }
    }
}
