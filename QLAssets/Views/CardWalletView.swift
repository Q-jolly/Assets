import SwiftUI
import SwiftData
import Foundation


// MARK: - 卡包首页

struct CardWalletView: View {

    @Query(
        sort: [
            SortDescriptor(
                \BankCard.sortOrder
            ),
            SortDescriptor(
                \BankCard.createdAt
            )
        ]
    )
    private var cards:
        [BankCard]

    @Query(
        sort: \Account.createdAt
    )
    private var accounts:
        [Account]

    @State
    private var showAddCard =
        false

    @State
    private var showManageCards =
        false


    var body: some View {

        ScrollView(
            .vertical
        ) {

            VStack(
                alignment: .leading,
                spacing: 22
            ) {

                if cards.isEmpty {

                    emptyState

                } else {

                    verticalCardStack

                    stackHint

                    cardInformation
                }
            }
            .padding(
                .vertical
            )
        }
        .scrollIndicators(
            .hidden
        )
        .navigationTitle(
            "卡包"
        )
        .toolbar {

            ToolbarItemGroup(
                placement:
                    .topBarTrailing
            ) {

                if !cards.isEmpty {

                    Button {

                        showManageCards =
                            true

                    } label: {

                        Image(
                            systemName:
                                "slider.horizontal.3"
                        )
                    }
                }


                Button {

                    showAddCard =
                        true

                } label: {

                    Image(
                        systemName:
                            "plus"
                    )
                }
            }
        }
        .sheet(
            isPresented:
                $showAddCard
        ) {

            AddCardView()
        }
        .sheet(
            isPresented:
                $showManageCards
        ) {

            CardManagerView()
        }
    }


    // MARK: 空状态

    private var emptyState:
        some View {

        ContentUnavailableView {

            Label(
                "还没有银行卡",
                systemImage:
                    "creditcard"
            )

        } description: {

            Text(
                "添加你的第一张储蓄卡或信用卡"
            )

        } actions: {

            Button(
                "添加银行卡"
            ) {

                showAddCard =
                    true
            }
            .buttonStyle(
                .borderedProminent
            )
        }
        .frame(
            minHeight: 500
        )
    }


    // MARK: 纵向卡片堆叠

    private var verticalCardStack:
        some View {

        LazyVStack(
            spacing: -145
        ) {

            ForEach(
                Array(
                    cards.enumerated()
                ),
                id: \.element.id
            ) { index, card in

                FlippableBankCardView(
                    card:
                        card,
                    account:
                        linkedAccount(
                            card
                        )
                )
                .padding(
                    .horizontal,
                    20
                )
                .zIndex(
                    Double(index)
                )
            }
        }
        .padding(
            .top,
            4
        )
        .padding(
            .bottom,
            8
        )
    }


    private var stackHint:
        some View {

        HStack {

            Spacer()

            Image(
                systemName:
                    "hand.draw"
            )

            Text(
                cards.count > 1
                ? "上下滑动浏览银行卡 · 点击卡片翻转"
                : "点击银行卡翻转正反面"
            )

            Spacer()
        }
        .font(
            .caption
        )
        .foregroundStyle(
            .secondary
        )
        .padding(
            .horizontal
        )
    }


    // MARK: 简单统计

    private var cardInformation:
        some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            Text(
                "卡片概览"
            )
            .font(
                .title3.bold()
            )


            HStack(
                spacing: 12
            ) {

                infoCard(
                    title:
                        "全部",
                    value:
                        cards.count
                )


                infoCard(
                    title:
                        "储蓄卡",
                    value:
                        cards.filter {
                            $0.cardType ==
                                .debit
                        }.count
                )


                infoCard(
                    title:
                        "信用卡",
                    value:
                        cards.filter {
                            $0.cardType ==
                                .credit
                        }.count
                )
            }
        }
        .padding(
            .horizontal
        )
    }


    private func infoCard(
        title: String,
        value: Int
    ) -> some View {

        VStack(
            spacing: 5
        ) {

            Text(
                "\(value)"
            )
            .font(
                .title2.bold()
            )

            Text(title)
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
        }
        .frame(
            maxWidth:
                .infinity
        )
        .padding(
            .vertical,
            16
        )
        .background(
            Color(
                .secondarySystemBackground
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16
            )
        )
    }


    private func linkedAccount(
        _ card:
            BankCard
    ) -> Account? {

        guard
            let accountID =
                card.accountID
        else {
            return nil
        }

        return accounts.first {

            $0.id ==
                accountID
        }
    }
}


// MARK: - 银行卡统一尺寸

private enum BankCardLayout {

    // ISO/IEC 7810 ID-1：85.60 × 53.98 mm
    static let aspectRatio:
        CGFloat = 85.60 / 53.98

    static let cornerRadius:
        CGFloat = 24
}


// MARK: - 可翻转银行卡

struct FlippableBankCardView: View {

    let card:
        BankCard

    let account:
        Account?

    @State
    private var flipped =
        false


    var body: some View {

        ZStack {

            cardFront
                .rotation3DEffect(
                    .degrees(
                        flipped
                        ? 180
                        : 0
                    ),
                    axis:
                        (
                            x: 0,
                            y: 1,
                            z: 0
                        ),
                    perspective:
                        0.65
                )
                .opacity(
                    flipped
                    ? 0
                    : 1
                )


            cardBack
                .rotation3DEffect(
                    .degrees(
                        flipped
                        ? 0
                        : -180
                    ),
                    axis:
                        (
                            x: 0,
                            y: 1,
                            z: 0
                        ),
                    perspective:
                        0.65
                )
                .opacity(
                    flipped
                    ? 1
                    : 0
                )
        }
        .aspectRatio(
            BankCardLayout
                .aspectRatio,
            contentMode:
                .fit
        )
        .compositingGroup()
        .contentShape(
            RoundedRectangle(
                cornerRadius:
                    BankCardLayout
                        .cornerRadius,
                style:
                    .continuous
            )
        )
        .onTapGesture {

            withAnimation(
                .easeInOut(
                    duration: 0.48
                )
            ) {

                flipped.toggle()
            }
        }
    }


    // MARK: 正面

    private var cardFront:
        some View {

        ZStack {

            CardThemeBackground(
                theme:
                    card.theme
            )


            VStack(
                alignment: .leading,
                spacing: 0
            ) {

                HStack {

                    VStack(
                        alignment:
                            .leading,
                        spacing: 3
                    ) {

                        Text(
                            card.bankName
                        )
                        .font(
                            .headline
                        )

                        Text(
                            card.cardType
                                .rawValue
                        )
                        .font(
                            .caption
                        )
                        .opacity(
                            0.8
                        )
                    }


                    Spacer()


                    Image(
                        systemName:
                            "wave.3.right"
                    )
                    .font(
                        .title2
                    )
                }


                Spacer()


                HStack {

                    RoundedRectangle(
                        cornerRadius: 5
                    )
                    .fill(
                        Color.white
                            .opacity(
                                0.8
                            )
                    )
                    .frame(
                        width: 42,
                        height: 32
                    )

                    Spacer()
                }


                Spacer()


                Text(
                    "••••  ••••  ••••  \(formattedLastFour)"
                )
                .font(
                    .system(
                        size: 21,
                        weight:
                            .medium,
                        design:
                            .monospaced
                    )
                )
                .tracking(1)
                .minimumScaleFactor(
                    0.78
                )
                .lineLimit(1)


                Spacer()


                HStack(
                    alignment:
                        .bottom
                ) {

                    VStack(
                        alignment:
                            .leading,
                        spacing: 2
                    ) {

                        Text(
                            "CARD HOLDER"
                        )
                        .font(
                            .system(
                                size: 8
                            )
                        )
                        .opacity(
                            0.6
                        )

                        Text(
                            card
                                .holderName
                                .uppercased()
                        )
                        .font(
                            .caption.bold()
                        )
                        .lineLimit(1)
                    }


                    Spacer()


                    if card.cardType ==
                        .credit {

                        VStack(
                            alignment:
                                .trailing,
                            spacing: 2
                        ) {

                            Text(
                                "AVAILABLE"
                            )
                            .font(
                                .system(
                                    size: 8
                                )
                            )
                            .opacity(
                                0.6
                            )

                            if let available =
                                card.availableCredit {

                                Text(
                                    available,
                                    format:
                                        .currency(
                                            code:
                                                "CNY"
                                        )
                                )
                                .font(
                                    .caption.bold()
                                )
                            }
                        }

                    } else {

                        Image(
                            systemName:
                                "creditcard.fill"
                        )
                        .font(
                            .title2
                        )
                    }
                }
            }
            .foregroundStyle(
                .white
            )
            .padding(22)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    BankCardLayout
                        .cornerRadius,
                style: .continuous
            )
        )
        .shadow(
            color:
                .black.opacity(
                    0.15
                ),
            radius: 14,
            y: 8
        )
    }


    // MARK: 背面

    private var cardBack:
        some View {

        GeometryReader {
            geometry in

            ZStack {

                CardThemeBackground(
                    theme:
                        card.theme
                )


                VStack(
                    spacing: 0
                ) {

                    Spacer()
                        .frame(
                            height:
                                geometry
                                    .size
                                    .height * 0.09
                        )


                    Rectangle()
                        .fill(
                            Color.black
                                .opacity(
                                    0.72
                                )
                        )
                        .frame(
                            height:
                                geometry
                                    .size
                                    .height * 0.21
                        )


                    VStack(
                        alignment:
                            .leading,
                        spacing: 10
                    ) {

                        HStack {

                            VStack(
                                alignment:
                                    .leading,
                                spacing: 2
                            ) {

                                Text(
                                    "卡片信息"
                                )
                                .font(
                                    .headline
                                )

                                Text(
                                    card.cardType
                                        .rawValue
                                )
                                .font(
                                    .caption2
                                )
                                .opacity(
                                    0.65
                                )
                            }


                            Spacer()


                            Image(
                                systemName:
                                    "lock.shield.fill"
                            )
                        }


                        Divider()
                            .overlay(
                                Color.white
                                    .opacity(
                                        0.28
                                    )
                            )


                        infoRow(
                            title:
                                "关联账户",
                            value:
                                account?
                                    .name
                                ?? "未关联"
                        )


                        if card.cardType ==
                            .credit {

                            infoRow(
                                title:
                                    "信用额度",
                                value:
                                    formattedCurrency(
                                        card.creditLimit
                                    )
                            )


                            infoRow(
                                title:
                                    "账单 / 还款",
                                value:
                                    creditDateText
                            )

                        } else {

                            infoRow(
                                title:
                                    "账户余额",
                                value:
                                    account
                                        .map {
                                            $0.balance
                                                .formatted(
                                                    .currency(
                                                        code:
                                                            "CNY"
                                                    )
                                                )
                                        }
                                    ?? "--"
                            )


                            infoRow(
                                title:
                                    "卡号",
                                value:
                                    "•••• \(formattedLastFour)"
                            )
                        }
                    }
                    .padding(
                        .horizontal,
                        22
                    )
                    .padding(
                        .top,
                        12
                    )
                    .padding(
                        .bottom,
                        14
                    )


                    Spacer(
                        minLength: 0
                    )
                }
            }
            .foregroundStyle(
                .white
            )
            .frame(
                width:
                    geometry
                        .size
                        .width,
                height:
                    geometry
                        .size
                        .height
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius:
                        BankCardLayout
                            .cornerRadius,
                    style:
                        .continuous
                )
            )
            .shadow(
                color:
                    .black.opacity(
                        0.15
                    ),
                radius: 14,
                y: 8
            )
        }
    }


    private func infoRow(
        title: String,
        value: String
    ) -> some View {

        HStack(
            alignment: .firstTextBaseline,
            spacing: 12
        ) {

            Text(title)
                .font(
                    .subheadline
                )
                .opacity(
                    0.68
                )


            Spacer(
                minLength: 8
            )


            Text(value)
                .font(
                    .subheadline
                        .weight(
                            .medium
                        )
                )
                .multilineTextAlignment(
                    .trailing
                )
                .lineLimit(1)
                .minimumScaleFactor(
                    0.78
                )
        }
    }


    private func formattedCurrency(
        _ value: Double?
    ) -> String {

        guard let value
        else {
            return "未设置"
        }

        return value.formatted(
            .currency(
                code: "CNY"
            )
        )
    }


    private var creditDateText:
        String {

        let billing =
            card.billingDay
                .map {
                    "\($0)日"
                }
            ?? "--"

        let repayment =
            card.repaymentDay
                .map {
                    "\($0)日"
                }
            ?? "--"

        return
            "\(billing) / \(repayment)"
    }


    private var formattedLastFour:
        String {

        let clean =
            card
                .lastFourDigits
                .filter {
                    $0.isNumber
                }

        if clean.isEmpty {

            return "----"
        }

        return String(
            clean.suffix(4)
        )
    }
}


// MARK: - 卡面背景

struct CardThemeBackground: View {

    let theme:
        CardTheme


    var body: some View {

        LinearGradient(
            colors:
                gradientColors,
            startPoint:
                .topLeading,
            endPoint:
                .bottomTrailing
        )
        .overlay {

            Circle()
                .fill(
                    Color.white
                        .opacity(
                            0.08
                        )
                )
                .frame(
                    width: 220
                )
                .offset(
                    x: 130,
                    y: -90
                )
        }
        .overlay {

            Circle()
                .fill(
                    Color.white
                        .opacity(
                            0.04
                        )
                )
                .frame(
                    width: 180
                )
                .offset(
                    x: -120,
                    y: 110
                )
        }
    }


    private var gradientColors:
        [Color] {

        switch theme {

        case .midnight:

            return [
                Color(
                    red: 0.05,
                    green: 0.05,
                    blue: 0.07
                ),
                Color(
                    red: 0.18,
                    green: 0.19,
                    blue: 0.24
                )
            ]


        case .ocean:

            return [
                Color(
                    red: 0.02,
                    green: 0.18,
                    blue: 0.36
                ),
                Color(
                    red: 0.04,
                    green: 0.43,
                    blue: 0.72
                )
            ]


        case .forest:

            return [
                Color(
                    red: 0.04,
                    green: 0.25,
                    blue: 0.19
                ),
                Color(
                    red: 0.08,
                    green: 0.48,
                    blue: 0.35
                )
            ]


        case .violet:

            return [
                Color(
                    red: 0.20,
                    green: 0.10,
                    blue: 0.38
                ),
                Color(
                    red: 0.46,
                    green: 0.20,
                    blue: 0.68
                )
            ]


        case .graphite:

            return [
                Color(
                    red: 0.18,
                    green: 0.19,
                    blue: 0.21
                ),
                Color(
                    red: 0.40,
                    green: 0.41,
                    blue: 0.44
                )
            ]


        case .sunrise:

            return [
                Color(
                    red: 0.55,
                    green: 0.17,
                    blue: 0.06
                ),
                Color(
                    red: 0.91,
                    green: 0.46,
                    blue: 0.12
                )
            ]
        }
    }
}



// MARK: - 添加银行卡

struct AddCardView: View {

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.modelContext)
    private var modelContext

    @Query(
        sort: \Account.createdAt
    )
    private var accounts:
        [Account]

    @Query
    private var cards:
        [BankCard]


    @State
    private var bankName =
        ""

    @State
    private var cardType:
        BankCardType =
            .debit

    @State
    private var lastFourDigits =
        ""

    @State
    private var holderName =
        ""

    @State
    private var linkedAccountID:
        UUID?

    @State
    private var theme:
        CardTheme =
            .midnight

    @State
    private var creditLimitText =
        ""

    @State
    private var currentDebtText =
        ""

    @State
    private var billingDay =
        1

    @State
    private var repaymentDay =
        20

    @FocusState
    private var focusedField:
        CardNumberField?


    private enum CardNumberField:
        Hashable {

        case lastFour
        case creditLimit
        case currentDebt
    }


    var body: some View {

        NavigationStack {

            Form {

                previewSection


                Section(
                    "基本信息"
                ) {

                    TextField(
                        "银行名称",
                        text:
                            $bankName
                    )
                    .focused(
                        $focusedField,
                        equals:
                            .bankName
                    )
                    .submitLabel(
                        .done
                    )
                    .onSubmit {
                        focusedField =
                            nil
                    }


                    Picker(
                        "卡片类型",
                        selection:
                            $cardType
                    ) {

                        ForEach(
                            BankCardType
                                .allCases
                        ) { type in

                            Text(
                                type.rawValue
                            )
                            .tag(type)
                        }
                    }


                    TextField(
                        "卡号后四位",
                        text:
                            $lastFourDigits
                    )
                    .keyboardType(
                        .numberPad
                    )
                    .focused(
                        $focusedField,
                        equals:
                            .lastFour
                    )
                    .onChange(
                        of:
                            lastFourDigits
                    ) {

                        lastFourDigits =
                            sanitizeLastFour(
                                lastFourDigits
                            )
                    }


                    TextField(
                        "持卡人姓名",
                        text:
                            $holderName
                    )
                }


                if cardType ==
                    .credit {

                    creditCardSection
                }


                Section(
                    "关联账户"
                ) {

                    Picker(
                        "资产账户",
                        selection:
                            $linkedAccountID
                    ) {

                        Text(
                            "不关联"
                        )
                        .tag(
                            UUID?.none
                        )

                        ForEach(
                            accounts
                        ) { account in

                            Text(
                                "\(account.name)  \(account.balance.formatted(.currency(code: "CNY")))"
                            )
                            .tag(
                                Optional(
                                    account.id
                                )
                            )
                        }
                    }
                }


                Section(
                    "卡面"
                ) {

                    Picker(
                        "卡面主题",
                        selection:
                            $theme
                    ) {

                        ForEach(
                            CardTheme
                                .allCases
                        ) { theme in

                            Text(
                                theme.rawValue
                            )
                            .tag(theme)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(
                .interactively
            )
            .navigationTitle(
                "添加银行卡"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {

                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {

                    Button(
                        "取消"
                    ) {

                        dismiss()
                    }
                }


                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {

                    Button(
                        "保存"
                    ) {

                        focusedField =
                            nil

                        saveCard()
                    }
                    .disabled(
                        !canSave
                    )
                }


                ToolbarItemGroup(
                    placement:
                        .keyboard
                ) {

                    Spacer()

                    Button(
                        "完成"
                    ) {

                        focusedField =
                            nil
                    }
                    .fontWeight(
                        .semibold
                    )
                }
            }
            .onChange(
                of: cardType
            ) {

                if cardType ==
                    .debit {

                    creditLimitText =
                        ""

                    currentDebtText =
                        ""
                }
            }
        }
    }


    private var creditCardSection:
        some View {

        Section {

            HStack {

                Text(
                    "信用额度"
                )

                Spacer()

                Text("¥")
                    .foregroundStyle(
                        .secondary
                    )

                TextField(
                    "0.00",
                    text:
                        $creditLimitText
                )
                .keyboardType(
                    .decimalPad
                )
                .multilineTextAlignment(
                    .trailing
                )
                .focused(
                    $focusedField,
                    equals:
                        .creditLimit
                )
                .frame(
                    maxWidth: 130
                )
            }


            HStack {

                Text(
                    "当前欠款"
                )

                Spacer()

                Text("¥")
                    .foregroundStyle(
                        .secondary
                    )

                TextField(
                    "0.00",
                    text:
                        $currentDebtText
                )
                .keyboardType(
                    .decimalPad
                )
                .multilineTextAlignment(
                    .trailing
                )
                .focused(
                    $focusedField,
                    equals:
                        .currentDebt
                )
                .frame(
                    maxWidth: 130
                )
            }


            Picker(
                "账单日",
                selection:
                    $billingDay
            ) {

                ForEach(
                    1...31,
                    id: \.self
                ) { day in

                    Text(
                        "每月 \(day) 日"
                    )
                    .tag(day)
                }
            }


            Picker(
                "还款日",
                selection:
                    $repaymentDay
            ) {

                ForEach(
                    1...31,
                    id: \.self
                ) { day in

                    Text(
                        "每月 \(day) 日"
                    )
                    .tag(day)
                }
            }
        } header: {

            Text(
                "信用卡信息"
            )

        } footer: {

            Text(
                "当前版本先记录额度、欠款与日期；V0.3 会把信用卡欠款正式纳入总负债和净资产计算。"
            )
        }
    }


    private var previewSection:
        some View {

        Section {

            BankCardPreview(
                bankName:
                    bankName.isEmpty
                    ? "银行名称"
                    : bankName,
                cardType:
                    cardType,
                lastFourDigits:
                    lastFourDigits,
                holderName:
                    holderName.isEmpty
                    ? "CARD HOLDER"
                    : holderName,
                theme:
                    theme
            )
            .listRowInsets(
                EdgeInsets()
            )
            .listRowBackground(
                Color.clear
            )
            .padding(
                .vertical,
                8
            )
        }
    }


    private var canSave:
        Bool {

        let basicValid =
            !bankName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .isEmpty
            &&
            lastFourDigits.count ==
                4

        if cardType ==
            .credit {

            guard basicValid
            else {
                return false
            }

            if let limit =
                parsedAmount(
                    creditLimitText
                ),
               limit < 0 {

                return false
            }

            if let debt =
                parsedAmount(
                    currentDebtText
                ),
               debt < 0 {

                return false
            }
        }

        return basicValid
    }


    private func saveCard() {

        let nextOrder =
            (
                cards
                    .map {
                        $0.sortOrder
                    }
                    .max()
                ?? -1
            ) + 1


        let card =
            BankCard(
                bankName:
                    bankName
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        ),
                cardType:
                    cardType,
                lastFourDigits:
                    lastFourDigits,
                holderName:
                    holderName
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        ),
                accountID:
                    linkedAccountID,
                theme:
                    theme,
                creditLimit:
                    cardType == .credit
                    ? parsedAmount(
                        creditLimitText
                    )
                    : nil,
                currentDebt:
                    cardType == .credit
                    ? parsedAmount(
                        currentDebtText
                    )
                    : nil,
                billingDay:
                    cardType == .credit
                    ? billingDay
                    : nil,
                repaymentDay:
                    cardType == .credit
                    ? repaymentDay
                    : nil,
                sortOrder:
                    nextOrder
            )


        modelContext.insert(
            card
        )

        try?
            modelContext.save()

        dismiss()
    }


    private func parsedAmount(
        _ value: String
    ) -> Double? {

        let cleaned =
            value
                .replacingOccurrences(
                    of: ",",
                    with: "."
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        if cleaned.isEmpty {
            return nil
        }

        return Double(
            cleaned
        )
    }


    private func sanitizeLastFour(
        _ value: String
    ) -> String {

        String(
            value
                .filter {
                    $0.isNumber
                }
                .prefix(4)
        )
    }
}


// MARK: - 新增页面卡片预览

struct BankCardPreview: View {

    let bankName:
        String

    let cardType:
        BankCardType

    let lastFourDigits:
        String

    let holderName:
        String

    let theme:
        CardTheme


    var body: some View {

        ZStack {

            CardThemeBackground(
                theme: theme
            )


            VStack(
                alignment:
                    .leading
            ) {

                HStack {

                    VStack(
                        alignment:
                            .leading
                    ) {

                        Text(
                            bankName
                        )
                        .font(
                            .headline
                        )

                        Text(
                            cardType
                                .rawValue
                        )
                        .font(
                            .caption
                        )
                        .opacity(
                            0.8
                        )
                    }


                    Spacer()


                    Image(
                        systemName:
                            "wave.3.right"
                    )
                }


                Spacer()


                Text(
                    "••••  ••••  ••••  \(displayLastFour)"
                )
                .font(
                    .system(
                        size: 18,
                        weight:
                            .medium,
                        design:
                            .monospaced
                    )
                )


                Spacer()


                HStack {

                    Text(
                        holderName
                            .uppercased()
                    )
                    .font(
                        .caption.bold()
                    )


                    Spacer()


                    Image(
                        systemName:
                            "creditcard.fill"
                    )
                }
            }
            .foregroundStyle(
                .white
            )
            .padding(22)
        }
        .aspectRatio(
            BankCardLayout
                .aspectRatio,
            contentMode: .fit
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    BankCardLayout
                        .cornerRadius,
                style: .continuous
            )
        )
        .padding(
            .horizontal
        )
    }


    private var displayLastFour:
        String {

        if lastFourDigits.isEmpty {

            return "----"
        }

        return
            lastFourDigits
    }
}



// MARK: - 卡片详情

struct CardDetailView: View {

    let card:
        BankCard

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.modelContext)
    private var modelContext

    @Query(
        sort: \Account.createdAt
    )
    private var accounts:
        [Account]

    @State
    private var showEdit =
        false

    @State
    private var showDelete =
        false


    var body: some View {

        List {

            Section {

                FlippableBankCardView(
                    card:
                        card,
                    account:
                        linkedAccount
                )
                .listRowInsets(
                    EdgeInsets()
                )
                .listRowBackground(
                    Color.clear
                )
                .padding(
                    .vertical,
                    12
                )
            }


            Section(
                "卡片信息"
            ) {

                LabeledContent(
                    "银行",
                    value:
                        card.bankName
                )


                LabeledContent(
                    "类型",
                    value:
                        card.cardType
                            .rawValue
                )


                LabeledContent(
                    "卡号",
                    value:
                        "•••• \(card.lastFourDigits)"
                )


                if !card
                    .holderName
                    .isEmpty {

                    LabeledContent(
                        "持卡人",
                        value:
                            card
                                .holderName
                    )
                }


                LabeledContent(
                    "卡面",
                    value:
                        card.theme
                            .rawValue
                )
            }


            if card.cardType ==
                .credit {

                Section(
                    "信用卡"
                ) {

                    LabeledContent(
                        "信用额度"
                    ) {

                        Text(
                            formattedCurrency(
                                card.creditLimit
                            )
                        )
                    }


                    LabeledContent(
                        "当前欠款"
                    ) {

                        Text(
                            formattedCurrency(
                                card.currentDebt
                            )
                        )
                        .fontWeight(
                            .semibold
                        )
                    }


                    LabeledContent(
                        "可用额度"
                    ) {

                        Text(
                            formattedCurrency(
                                card.availableCredit
                            )
                        )
                    }


                    LabeledContent(
                        "账单日",
                        value:
                            dayText(
                                card.billingDay
                            )
                    )


                    LabeledContent(
                        "还款日",
                        value:
                            dayText(
                                card.repaymentDay
                            )
                    )
                }
            }


            Section(
                "关联资产"
            ) {

                if let linkedAccount {

                    LabeledContent(
                        "账户",
                        value:
                            linkedAccount
                                .name
                    )


                    LabeledContent(
                        "余额"
                    ) {

                        Text(
                            linkedAccount.balance,
                            format:
                                .currency(
                                    code:
                                        "CNY"
                                )
                        )
                        .fontWeight(
                            .semibold
                        )
                    }

                } else {

                    Text(
                        "这张银行卡尚未关联资产账户"
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }


            Section {

                Button {

                    showEdit =
                        true

                } label: {

                    Label(
                        "编辑银行卡",
                        systemImage:
                            "pencil"
                    )
                }


                Button(
                    role:
                        .destructive
                ) {

                    showDelete =
                        true

                } label: {

                    Label(
                        "删除银行卡",
                        systemImage:
                            "trash"
                    )
                }
            }
        }
        .navigationTitle(
            card.bankName
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .sheet(
            isPresented:
                $showEdit
        ) {

            EditCardView(
                card: card
            )
        }
        .confirmationDialog(
            "删除这张银行卡？",
            isPresented:
                $showDelete,
            titleVisibility:
                .visible
        ) {

            Button(
                "删除",
                role:
                    .destructive
            ) {

                modelContext.delete(
                    card
                )

                try?
                    modelContext.save()

                dismiss()
            }


            Button(
                "取消",
                role:
                    .cancel
            ) {}
        } message: {

            Text(
                "只会删除卡包里的卡片，不会删除关联的资产账户和历史账单。"
            )
        }
    }


    private var linkedAccount:
        Account? {

        guard
            let accountID =
                card.accountID
        else {
            return nil
        }

        return accounts.first {

            $0.id ==
                accountID
        }
    }


    private func formattedCurrency(
        _ value: Double?
    ) -> String {

        guard let value
        else {
            return "未设置"
        }

        return value.formatted(
            .currency(
                code: "CNY"
            )
        )
    }


    private func dayText(
        _ day: Int?
    ) -> String {

        guard let day
        else {
            return "未设置"
        }

        return "每月 \(day) 日"
    }
}


// MARK: - 编辑银行卡

struct EditCardView: View {

    let card:
        BankCard

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.modelContext)
    private var modelContext

    @Query(
        sort: \Account.createdAt
    )
    private var accounts:
        [Account]


    @State
    private var bankName:
        String

    @State
    private var cardType:
        BankCardType

    @State
    private var lastFourDigits:
        String

    @State
    private var holderName:
        String

    @State
    private var accountID:
        UUID?

    @State
    private var theme:
        CardTheme

    @State
    private var creditLimitText:
        String

    @State
    private var currentDebtText:
        String

    @State
    private var billingDay:
        Int

    @State
    private var repaymentDay:
        Int

    @FocusState
    private var focusedField:
        EditCardNumberField?


    private enum EditCardNumberField:
        Hashable {

        case lastFour
        case creditLimit
        case currentDebt
    }


    init(
        card: BankCard
    ) {

        self.card =
            card

        _bankName =
            State(
                initialValue:
                    card.bankName
            )

        _cardType =
            State(
                initialValue:
                    card.cardType
            )

        _lastFourDigits =
            State(
                initialValue:
                    card.lastFourDigits
            )

        _holderName =
            State(
                initialValue:
                    card.holderName
            )

        _accountID =
            State(
                initialValue:
                    card.accountID
            )

        _theme =
            State(
                initialValue:
                    card.theme
            )

        _creditLimitText =
            State(
                initialValue:
                    card.creditLimit
                        .map {
                            String(
                                format:
                                    "%.2f",
                                $0
                            )
                        }
                    ?? ""
            )

        _currentDebtText =
            State(
                initialValue:
                    card.currentDebt
                        .map {
                            String(
                                format:
                                    "%.2f",
                                $0
                            )
                        }
                    ?? ""
            )

        _billingDay =
            State(
                initialValue:
                    card.billingDay
                    ?? 1
            )

        _repaymentDay =
            State(
                initialValue:
                    card.repaymentDay
                    ?? 20
            )
    }


    var body: some View {

        NavigationStack {

            Form {

                Section {

                    BankCardPreview(
                        bankName:
                            bankName,
                        cardType:
                            cardType,
                        lastFourDigits:
                            lastFourDigits,
                        holderName:
                            holderName,
                        theme:
                            theme
                    )
                    .listRowInsets(
                        EdgeInsets()
                    )
                    .listRowBackground(
                        Color.clear
                    )
                    .padding(
                        .vertical,
                        8
                    )
                }


                Section(
                    "基本信息"
                ) {

                    TextField(
                        "银行名称",
                        text:
                            $bankName
                    )
                    .focused(
                        $focusedField,
                        equals:
                            .bankName
                    )
                    .submitLabel(
                        .done
                    )
                    .onSubmit {
                        focusedField =
                            nil
                    }


                    Picker(
                        "卡片类型",
                        selection:
                            $cardType
                    ) {

                        ForEach(
                            BankCardType
                                .allCases
                        ) { item in

                            Text(
                                item.rawValue
                            )
                            .tag(item)
                        }
                    }


                    TextField(
                        "卡号后四位",
                        text:
                            $lastFourDigits
                    )
                    .keyboardType(
                        .numberPad
                    )
                    .focused(
                        $focusedField,
                        equals:
                            .lastFour
                    )
                    .onChange(
                        of:
                            lastFourDigits
                    ) {

                        lastFourDigits =
                            String(
                                lastFourDigits
                                    .filter {
                                        $0.isNumber
                                    }
                                    .prefix(4)
                            )
                    }


                    TextField(
                        "持卡人",
                        text:
                            $holderName
                    )
                }


                if cardType ==
                    .credit {

                    creditCardSection
                }


                Section(
                    "关联账户"
                ) {

                    Picker(
                        "资产账户",
                        selection:
                            $accountID
                    ) {

                        Text(
                            "不关联"
                        )
                        .tag(
                            UUID?.none
                        )

                        ForEach(
                            accounts
                        ) { account in

                            Text(
                                account.name
                            )
                            .tag(
                                Optional(
                                    account.id
                                )
                            )
                        }
                    }
                }


                Section(
                    "卡面"
                ) {

                    Picker(
                        "主题",
                        selection:
                            $theme
                    ) {

                        ForEach(
                            CardTheme
                                .allCases
                        ) { item in

                            Text(
                                item.rawValue
                            )
                            .tag(item)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(
                .interactively
            )
            .navigationTitle(
                "编辑银行卡"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {

                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {

                    Button(
                        "取消"
                    ) {

                        dismiss()
                    }
                }


                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {

                    Button(
                        "保存"
                    ) {

                        focusedField =
                            nil

                        save()
                    }
                    .disabled(
                        !canSave
                    )
                }


                ToolbarItemGroup(
                    placement:
                        .keyboard
                ) {

                    Spacer()

                    Button(
                        "完成"
                    ) {

                        focusedField =
                            nil
                    }
                    .fontWeight(
                        .semibold
                    )
                }
            }
            .onChange(
                of: cardType
            ) {

                if cardType ==
                    .debit {

                    creditLimitText =
                        ""

                    currentDebtText =
                        ""
                }
            }
        }
    }


    private var creditCardSection:
        some View {

        Section(
            "信用卡信息"
        ) {

            HStack {

                Text(
                    "信用额度"
                )

                Spacer()

                Text("¥")
                    .foregroundStyle(
                        .secondary
                    )

                TextField(
                    "0.00",
                    text:
                        $creditLimitText
                )
                .keyboardType(
                    .decimalPad
                )
                .multilineTextAlignment(
                    .trailing
                )
                .focused(
                    $focusedField,
                    equals:
                        .creditLimit
                )
                .frame(
                    maxWidth: 130
                )
            }


            HStack {

                Text(
                    "当前欠款"
                )

                Spacer()

                Text("¥")
                    .foregroundStyle(
                        .secondary
                    )

                TextField(
                    "0.00",
                    text:
                        $currentDebtText
                )
                .keyboardType(
                    .decimalPad
                )
                .multilineTextAlignment(
                    .trailing
                )
                .focused(
                    $focusedField,
                    equals:
                        .currentDebt
                )
                .frame(
                    maxWidth: 130
                )
            }


            Picker(
                "账单日",
                selection:
                    $billingDay
            ) {

                ForEach(
                    1...31,
                    id: \.self
                ) { day in

                    Text(
                        "每月 \(day) 日"
                    )
                    .tag(day)
                }
            }


            Picker(
                "还款日",
                selection:
                    $repaymentDay
            ) {

                ForEach(
                    1...31,
                    id: \.self
                ) { day in

                    Text(
                        "每月 \(day) 日"
                    )
                    .tag(day)
                }
            }
        }
    }


    private var canSave:
        Bool {

        !bankName
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .isEmpty
        &&
        lastFourDigits.count ==
            4
    }


    private func save() {

        card.bankName =
            bankName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        card.cardTypeRaw =
            cardType.rawValue

        card.lastFourDigits =
            lastFourDigits

        card.holderName =
            holderName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        card.accountID =
            accountID

        card.themeRaw =
            theme.rawValue


        if cardType ==
            .credit {

            card.creditLimit =
                parsedAmount(
                    creditLimitText
                )

            card.currentDebt =
                parsedAmount(
                    currentDebtText
                )

            card.billingDay =
                billingDay

            card.repaymentDay =
                repaymentDay

        } else {

            card.creditLimit =
                nil

            card.currentDebt =
                nil

            card.billingDay =
                nil

            card.repaymentDay =
                nil
        }

        try?
            modelContext.save()

        dismiss()
    }


    private func parsedAmount(
        _ value: String
    ) -> Double? {

        let cleaned =
            value
                .replacingOccurrences(
                    of: ",",
                    with: "."
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        if cleaned.isEmpty {
            return nil
        }

        return Double(
            cleaned
        )
    }
}


// MARK: - 卡片管理 / 排序

struct CardManagerView: View {

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.modelContext)
    private var modelContext

    @Query(
        sort: [
            SortDescriptor(
                \BankCard.sortOrder
            ),
            SortDescriptor(
                \BankCard.createdAt
            )
        ]
    )
    private var cards:
        [BankCard]


    var body: some View {

        NavigationStack {

            List {

                Section {

                    ForEach(
                        cards
                    ) { card in

                        HStack(
                            spacing: 12
                        ) {

                            Image(
                                systemName:
                                    card.cardType
                                        .icon
                            )
                            .frame(
                                width: 32
                            )


                            VStack(
                                alignment:
                                    .leading
                            ) {

                                Text(
                                    card.bankName
                                )

                                Text(
                                    "•••• \(card.lastFourDigits)"
                                )
                                .font(
                                    .caption
                                )
                                .foregroundStyle(
                                    .secondary
                                )
                            }
                        }
                    }
                    .onMove(
                        perform:
                            moveCards
                    )
                } header: {

                    Text(
                        "长按右侧拖动可以调整卡片顺序"
                    )
                }
            }
            .environment(
                \.editMode,
                .constant(
                    .active
                )
            )
            .navigationTitle(
                "管理卡片"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {

                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {

                    Button(
                        "完成"
                    ) {

                        dismiss()
                    }
                }
            }
        }
    }


    private func moveCards(
        from source:
            IndexSet,
        to destination:
            Int
    ) {

        var reordered =
            cards

        reordered.move(
            fromOffsets:
                source,
            toOffset:
                destination
        )


        for (
            index,
            card
        ) in reordered
            .enumerated() {

            card.sortOrder =
                index
        }

        try?
            modelContext.save()
    }
}