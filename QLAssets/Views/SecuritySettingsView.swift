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

    @AppStorage(
        AppLockManager
            .automaticLockDelayMinutesKey
    )
    private var automaticLockDelayMinutes =
        AppLockManager
            .defaultAutomaticLockDelayMinutes

    @AppStorage(
        AppPreferenceKeys
            .appearanceMode
    )
    private var appearanceModeRaw =
        AppAppearanceMode
            .system
            .rawValue

    @AppStorage(
        AppPreferenceKeys
            .hapticsEnabled
    )
    private var hapticsEnabled =
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

                Picker(
                    "外观",
                    selection:
                        $appearanceModeRaw
                ) {

                    ForEach(
                        AppAppearanceMode
                            .allCases
                    ) { mode in

                        Label(
                            mode.rawValue,
                            systemImage:
                                mode.icon
                        )
                        .tag(
                            mode.rawValue
                        )
                    }
                }


                Toggle(
                    "触感反馈",
                    isOn:
                        $hapticsEnabled
                )
                .onChange(
                    of:
                        hapticsEnabled
                ) { _, isEnabled in

                    if isEnabled {

                        HapticFeedback
                            .selection()
                    }
                }

            } header: {

                Text(
                    "外观与交互"
                )

            } footer: {

                Text(
                    "外观可跟随系统，也可以固定为浅色或深色。关闭触感反馈后，标签切换和记账保存不会震动。"
                )
            }


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

                    Picker(
                        "自动锁定",
                        selection:
                            $automaticLockDelayMinutes
                    ) {

                        Text(
                            "1 分钟"
                        )
                        .tag(1)

                        Text(
                            "2 分钟"
                        )
                        .tag(2)

                        Text(
                            "5 分钟"
                        )
                        .tag(5)

                        Text(
                            "10 分钟"
                        )
                        .tag(10)

                        Text(
                            "30 分钟"
                        )
                        .tag(30)

                        Text(
                            "永不"
                        )
                        .tag(0)
                    }



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
                    "自动锁定时间可选择 1、2、5、10、30 分钟或永不。“永不”仅关闭后台超时自动锁定；冷启动和“立即锁定”仍会验证身份。"
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

                NavigationLink {

                    BackupRestoreView()

                } label: {

                    Label(
                        "备份与恢复",
                        systemImage:
                            "externaldrive.fill"
                    )
                }

            } header: {

                Text(
                    "数据"
                )

            } footer: {

                Text(
                    "可将账户、账单、银行卡、预算和自定义卡面导出为一个本地备份文件。"
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
            "设置"
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


    private var automaticLockText:
        String {

        if automaticLockDelayMinutes ==
            0 {

            return
                "永不"
        }

        return
            "\(automaticLockDelayMinutes) 分钟"
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
