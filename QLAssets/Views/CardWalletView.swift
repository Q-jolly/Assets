import SwiftUI
import SwiftData
import Foundation
import PhotosUI
import UIKit
import Combine


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

    @State
    private var selectedCardIndex =
        0

    @GestureState
    private var dragOffset:
        CGFloat = 0

    @GestureState
    private var isCardDragging =
        false




    private let cardReveal:
        CGFloat = 68

    private let bottomTailReveal:
        CGFloat = 38

    private let maxRenderedCards =
        5


    var body: some View {

        ScrollView(
            .vertical
        ) {

            VStack(
                alignment: .leading,
                spacing: 20
            ) {

                if cards.isEmpty {

                    emptyState

                } else {

                    interactiveCardStack

                    stackHint

                    selectedCardDetailLink

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
        .scrollDisabled(
            isCardDragging
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
        .onChange(
            of: cards.count
        ) { _ in

            clampSelectedIndex()
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


    // MARK: 当前银行卡

    private var selectedCard:
        BankCard? {

        guard
            !cards.isEmpty,
            cards.indices.contains(
                selectedCardIndex
            )
        else {
            return nil
        }

        return cards[
            selectedCardIndex
        ]
    }


    // MARK: 卡片尺寸

    private var cardWidth:
        CGFloat {

        min(
            max(
                UIScreen.main.bounds.width -
                40,
                280
            ),
            520
        )
    }


    private var cardHeight:
        CGFloat {

        cardWidth /
        BankCardLayout.aspectRatio
    }


    private var stackedCards:
        [BankCard] {

        guard
            !cards.isEmpty,
            cards.indices.contains(
                selectedCardIndex
            )
        else {
            return cards
        }

        let front =
            Array(
                cards[
                    selectedCardIndex...
                ]
            )

        let wrapped =
            Array(
                cards.prefix(
                    selectedCardIndex
                )
            )

        return
            front +
            wrapped
    }


    private var visibleStackedCards:
        [BankCard] {

        guard stackedCards.count >
                maxRenderedCards
        else {
            return stackedCards
        }

        let frontCards =
            Array(
                stackedCards.prefix(
                    maxRenderedCards - 1
                )
            )

        guard
            let tailCard =
                stackedCards.last
        else {
            return frontCards
        }

        return
            frontCards +
            [tailCard]
    }


    private var cardStackHeight:
        CGFloat {

        guard visibleStackedCards.count > 1
        else {
            return cardHeight
        }

        return
            cardHeight +
            CGFloat(
                max(
                    visibleStackedCards.count - 2,
                    0
                )
            ) * cardReveal +
            bottomTailReveal
    }


    // MARK: 真正的纵向堆叠 + 纵向切卡

    private var interactiveCardStack:
        some View {

        ZStack(
            alignment: .top
        ) {

            ForEach(
                Array(
                    visibleStackedCards.enumerated()
                ),
                id: \.element.id
            ) { relativeIndex, card in

                    FlippableBankCardView(
                        card:
                            card,
                        account:
                            linkedAccount(
                                card
                            ),
                        allCards:
                            cards,
                        allowsFlip:
                            relativeIndex == 0,
                        onTap: {

                            if relativeIndex >
                                0 {

                                selectCard(
                                    cardID:
                                        card.id
                                )
                            }
                        }
                    )
                    .frame(
                        width:
                            cardWidth,
                        height:
                            cardHeight
                    )
                    // 卡包中的所有卡片统一使用银行卡横向画布。
                    // 额外裁剪，避免竖版艺术卡原图撑开堆叠布局。
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius:
                                BankCardLayout
                                    .cornerRadius,
                            style:
                                .continuous
                        )
                    )
                    .clipped()
                    .scaleEffect(
                        1 -
                        CGFloat(
                            relativeIndex
                        ) * 0.015,
                        anchor:
                            .top
                    )
                    .offset(
                        y:
                            cardOffset(
                                relativeIndex:
                                    relativeIndex
                            )
                    )
                    .zIndex(
                        Double(
                            visibleStackedCards.count -
                            relativeIndex
                        )
                    )
            }
        }
        .frame(
            maxWidth:
                .infinity
        )
        .frame(
            height:
                cardStackHeight,
            alignment:
                .top
        )
        .contentShape(
            Rectangle()
        )
        .highPriorityGesture(
            cardSwitchGesture
        )
        .animation(
            .interactiveSpring(
                response: 0.28,
                dampingFraction: 0.92,
                blendDuration: 0.06
            ),
            value:
                selectedCardIndex
        )
    }


    private func baseCardOffset(
        relativeIndex:
            Int
    ) -> CGFloat {

        guard relativeIndex > 0
        else {
            return 0
        }

        if relativeIndex ==
            visibleStackedCards.count - 1 {

            return
                CGFloat(
                    max(
                        relativeIndex - 1,
                        0
                    )
                ) * cardReveal +
                bottomTailReveal
        }

        return
            CGFloat(
                relativeIndex
            ) * cardReveal
    }


    private func cardOffset(
        relativeIndex:
            Int
    ) -> CGFloat {

        let base =
            baseCardOffset(
                relativeIndex:
                    relativeIndex
            )


        if relativeIndex == 0 {

            if dragOffset < 0 {

                return
                    max(
                        dragOffset,
                        -cardReveal
                    ) * 0.55
            }

            return
                min(
                    dragOffset,
                    cardReveal * 1.35
                ) * 0.72
        }


        guard dragOffset != 0
        else {
            return base
        }


        if dragOffset < 0 {

            return
                base +
                max(
                    dragOffset,
                    -cardReveal
                ) * 0.26
        }


        return
            base +
            min(
                dragOffset,
                cardReveal
            ) * 0.04
    }


    private var cardSwitchGesture:
        some Gesture {

        DragGesture(
            minimumDistance: 8
        )
        .updating(
            $dragOffset
        ) { value, state, _ in

            state =
                value.translation.height
        }
        .updating(
            $isCardDragging
        ) { _, state, _ in

            state =
                true
        }
        .onEnded { value in

            guard cards.count > 1
            else {
                return
            }

            let predicted =
                value
                    .predictedEndTranslation
                    .height

            let actual =
                value
                    .translation
                    .height

            let decisionValue =
                abs(predicted) >
                abs(actual)
                ? predicted
                : actual

            if decisionValue <
                -48 {

                withAnimation(
                    .interactiveSpring(
                        response: 0.28,
                        dampingFraction: 0.92,
                        blendDuration: 0.06
                    )
                ) {

                    goToNextCard()
                }

            } else if decisionValue >
                        48 {

                withAnimation(
                    .interactiveSpring(
                        response: 0.28,
                        dampingFraction: 0.92,
                        blendDuration: 0.06
                    )
                ) {

                    goToPreviousCard()
                }
            }
        }
    }


    private func goToNextCard() {

        guard cards.count > 1
        else {
            return
        }

        selectedCardIndex =
            (
                selectedCardIndex +
                1
            ) %
            cards.count
    }


    private func goToPreviousCard() {

        guard cards.count > 1
        else {
            return
        }

        selectedCardIndex =
            (
                selectedCardIndex -
                1 +
                cards.count
            ) %
            cards.count
    }


    private func selectCard(
        cardID:
            UUID
    ) {

        guard
            let index =
                cards.firstIndex(
                    where: {
                        $0.id ==
                            cardID
                    }
                )
        else {
            return
        }

        withAnimation(
            .spring(
                response: 0.38,
                dampingFraction: 0.86
            )
        ) {

            selectedCardIndex =
                index
        }
    }


    private func clampSelectedIndex() {

        if cards.isEmpty {

            selectedCardIndex =
                0

            return
        }

        selectedCardIndex =
            min(
                max(
                    selectedCardIndex,
                    0
                ),
                cards.count - 1
            )
    }


    private var stackHint:
        some View {

        HStack(
            spacing: 6
        ) {

            Spacer()

            Image(
                systemName:
                    "hand.draw"
            )

            Text(
                cards.count > 1
                ? "上下均可循环切卡 · 底部始终保留尾卡"
                : "点击银行卡翻转正反面"
            )

            if cards.count >
                1 {

                Text(
                    "\(selectedCardIndex + 1)/\(cards.count)"
                )
                .fontWeight(
                    .semibold
                )
            }

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


    @ViewBuilder
    private var selectedCardDetailLink:
        some View {

        if let selectedCard {

            NavigationLink {

                CardDetailView(
                    card:
                        selectedCard
                )

            } label: {

                HStack {

                    Image(
                        systemName:
                            selectedCard
                                .cardType
                                .icon
                    )

                    VStack(
                        alignment:
                            .leading,
                        spacing: 2
                    ) {

                        Text(
                            selectedCard
                                .bankName
                        )
                        .fontWeight(
                            .medium
                        )

                        Text(
                            "•••• \(selectedCard.lastFourDigits)"
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    Spacer()

                    Text(
                        "查看详情"
                    )
                    .font(
                        .subheadline
                    )

                    Image(
                        systemName:
                            "chevron.right"
                    )
                    .font(
                        .caption.bold()
                    )
                }
                .padding(
                    .horizontal,
                    16
                )
                .padding(
                    .vertical,
                    12
                )
                .background(
                    Color(
                        .secondarySystemBackground
                    )
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 16,
                        style:
                            .continuous
                    )
                )
            }
            .buttonStyle(
                .plain
            )
            .padding(
                .horizontal,
                20
            )
        }
    }


    // MARK: 卡片概览

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

            Text(
                title
            )
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


private func cardNumberText(
    faceType:
        CardFaceType,
    lastFour:
        String
) -> String {

    let clean =
        lastFour.filter {
            $0.isNumber
        }

    switch faceType {

    case .standard:
        return clean.isEmpty
            ? "未提供卡号"
            : "••••  ••••  ••••  \(String(clean.suffix(4)))"

    case .art:
        return clean.isEmpty
            ? "艺术卡 · 未提供卡号"
            : "艺术卡 · •••• \(String(clean.suffix(4)))"

    case .virtual:
        return clean.isEmpty
            ? "虚拟卡 · 未提供尾号"
            : "虚拟卡 · •••• \(String(clean.suffix(4)))"

    case .noNumber:
        return "无卡号"
    }
}


private struct CardFaceTypeBadge: View {

    let faceType:
        CardFaceType

    @ViewBuilder
    var body:
        some View {

        if faceType != .standard {

            Text(
                faceType.rawValue
            )
            .font(
                .caption2.weight(
                    .semibold
                )
            )
            .lineLimit(1)
            .padding(
                .horizontal,
                7
            )
            .padding(
                .vertical,
                4
            )
            .background(
                Color.black.opacity(
                    0.34
                ),
                in:
                    Capsule()
            )
        }
    }
}


// MARK: - 可翻转银行卡

struct FlippableBankCardView: View {

    let card:
        BankCard

    let account:
        Account?

    let allCards:
        [BankCard]

    let allowsFlip:
        Bool

    let onTap:
        (() -> Void)?

    @State
    private var flipped =
        false

    @State
    private var customFaceImage:
        UIImage?

    @State
    private var customBackFaceImage:
        UIImage?


    init(
        card: BankCard,
        account: Account?,
        allCards: [BankCard] = [],
        allowsFlip: Bool = true,
        onTap: (() -> Void)? = nil
    ) {

        self.card =
            card

        self.account =
            account

        self.allCards =
            allCards

        self.allowsFlip =
            allowsFlip

        self.onTap =
            onTap
    }


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

            if allowsFlip {

                withAnimation(
                    .easeInOut(
                        duration:
                            0.48
                    )
                ) {

                    flipped.toggle()
                }

            } else {

                onTap?()
            }
        }
        .onChange(
            of: allowsFlip
        ) { newValue in

            if !newValue {

                flipped =
                    false
            }
        }
        .onAppear {

            reloadCustomFace()
        }
        .onReceive(
            NotificationCenter.default
                .publisher(
                    for:
                        CardFaceImageStore
                            .didChangeNotification
                )
        ) { notification in

            guard
                let changedID =
                    notification.object
                    as? String,
                changedID ==
                    card.id.uuidString
            else {
                return
            }

            reloadCustomFace()
        }
    }


    // MARK: 正面

    private var cardFront:
        some View {

        ZStack {

            cardFrontBackground


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

                        CardFaceTypeBadge(
                            faceType:
                                card.faceType
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
                    cardNumberText(
                        faceType:
                            card.faceType,
                        lastFour:
                            card.lastFourDigits
                    )
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
                                CreditAccountService
                                    .availableCredit(
                                        for:
                                            card,
                                        cards:
                                            allCards.isEmpty
                                            ? [card]
                                            : allCards
                                    ) {

                                Text(
                                    available,
                                    format:
                                        .currency(
                                            code:
                                                account?.currencyCode ??
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


    @ViewBuilder
    private var cardFrontBackground:
        some View {

        if let customFaceImage {

            Image(
                uiImage:
                    customFaceImage
            )
            .resizable()
            .scaledToFill()
            .frame(
                maxWidth:
                    .infinity,
                maxHeight:
                    .infinity
            )
            .clipped()
            .overlay {

                LinearGradient(
                    colors:
                        [
                            .black.opacity(
                                0.28
                            ),
                            .black.opacity(
                                0.08
                            ),
                            .black.opacity(
                                0.30
                            )
                        ],
                    startPoint:
                        .topLeading,
                    endPoint:
                        .bottomTrailing
                )
            }

        } else {

            CardThemeBackground(
                theme:
                    card.theme
            )
        }
    }


    private func reloadCustomFace() {

        customFaceImage =
            CardFaceImageStore
                .image(
                    for:
                        card.id,
                    side:
                        .front
                )

        customBackFaceImage =
            CardFaceImageStore
                .image(
                    for:
                        card.id,
                    side:
                        .back
                )
    }


    // MARK: 背面

    @ViewBuilder
    private var cardBack:
        some View {

        if let customBackFaceImage {

            Image(
                uiImage:
                    customBackFaceImage
            )
            .resizable()
            .scaledToFill()
            .frame(
                maxWidth:
                    .infinity,
                maxHeight:
                    .infinity
            )
            .clipped()
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
                radius:
                    14,
                y:
                    8
            )

        } else {

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
                                        CreditAccountService
                                    .sharedCreditLimit(
                                        for:
                                            card,
                                        cards:
                                            allCards.isEmpty
                                            ? [card]
                                            : allCards
                                    )
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
                                    cardNumberText(
                                        faceType:
                                            card.faceType,
                                        lastFour:
                                            card.lastFourDigits
                                    )
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
    private var faceType:
        CardFaceType =
            .standard

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

    @State
    private var selectedCardImage:
        PhotosPickerItem?

    @State
    private var isRecognizingCard =
        false

    @State
    private var recognitionMessage:
        String?

    @State
    private var recognizedImageData:
        Data?

    @State
    private var selectedFaceImage:
        PhotosPickerItem?

    @State
    private var customFaceImageData:
        Data?

    @State
    private var selectedBackFaceImage:
        PhotosPickerItem?

    @State
    private var customBackFaceImageData:
        Data?

    @State
    private var faceMessage:
        String?

    @State
    private var backFaceMessage:
        String?

    @FocusState
    private var focusedField:
        CardNumberField?


    private enum CardNumberField:
        Hashable {

        case bankName
        case holderName
        case lastFour
        case creditLimit
        case currentDebt
    }


    var body: some View {

        NavigationStack {

            Form {

                previewSection

                cardRecognitionSection

                basicInfoSection

                if cardType ==
                    .credit {

                    creditCardSection
                }

                linkedAccountSection

                cardFaceSection

                cardBackFaceSection
            }
            .scrollDismissesKeyboard(
                .interactively
            )
            .onChange(
                of: selectedCardImage
            ) { _, newItem in

                guard let newItem
                else {
                    return
                }

                Task {

                    await recognizeCardImage(
                        newItem
                    )
                }
            }
            .onChange(
                of: selectedFaceImage
            ) { _, newItem in

                guard let newItem
                else {
                    return
                }

                Task {

                    await loadCustomFace(
                        newItem
                    )
                }
            }
            .onChange(
                of: selectedBackFaceImage
            ) { _, newItem in

                guard let newItem
                else {
                    return
                }

                Task {

                    await recognizeBackFaceImage(
                        newItem
                    )
                }
            }
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


    private var basicInfoSection:
        some View {

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
                    .tag(
                        type
                    )
                }
            }


            Picker(
                "卡面类型",
                selection:
                    $faceType
            ) {

                ForEach(
                    CardFaceType
                        .allCases,
                    id: \.self
                ) { item in

                    Text(
                        item.rawValue
                    )
                    .tag(
                        item
                    )
                }
            }


            TextField(
                faceType.requiresLastFour
                ? "卡号后四位"
                : "卡号后四位（可选）",
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
            .focused(
                $focusedField,
                equals:
                    .holderName
            )
            .submitLabel(
                .done
            )
            .onSubmit {

                focusedField =
                    nil
            }
        }
    }


    private var linkedAccountSection:
        some View {

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
                        accountPickerTitle(
                            account
                        )
                    )
                    .tag(
                        Optional(
                            account.id
                        )
                    )
                }
            }
        }
    }


    private func accountPickerTitle(
        _ account:
            Account
    ) -> String {

        let balanceText =
            account.balance.formatted(
                .currency(
                    code:
                        "CNY"
                )
            )

        return
            account.name +
            "  " +
            balanceText
    }


    private var cardFaceSection:
        some View {

        Section {

            Picker(
                "卡面主题",
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
                    .tag(
                        item
                    )
                }
            }


            PhotosPicker(
                selection:
                    $selectedFaceImage,
                matching:
                    .images
            ) {

                Label(
                    customFaceImageData == nil
                    ? "选择自定义卡面"
                    : "更换自定义卡面",
                    systemImage:
                        "photo"
                )
            }


            if recognizedImageData != nil {

                Button {

                    customFaceImageData =
                        recognizedImageData

                    faceMessage =
                        "已将本次识别图片设为卡面预览。"

                } label: {

                    Label(
                        "使用识别图片作为卡面",
                        systemImage:
                            "rectangle.on.rectangle"
                    )
                }
            }


            if customFaceImageData != nil {

                Button(
                    "恢复主题卡面",
                    role:
                        .destructive
                ) {

                    customFaceImageData =
                        nil

                    faceMessage =
                        "已恢复主题卡面。"
                }
            }


            if let faceMessage {

                Text(
                    faceMessage
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }

        } header: {

            Text(
                "正面卡面"
            )

        } footer: {

            Text(
                "正面自定义卡面只保存在本机，不会上传。银行卡号仍只保存后四位。"
            )
        }
    }


    private var cardBackFaceSection:
        some View {

        Section {

            if let data =
                customBackFaceImageData,
               let image =
                UIImage(
                    data:
                        data
                ) {

                Image(
                    uiImage:
                        image
                )
                .resizable()
                .scaledToFill()
                .frame(
                    height:
                        120
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius:
                            14,
                        style:
                            .continuous
                    )
                )
            }


            PhotosPicker(
                selection:
                    $selectedBackFaceImage,
                matching:
                    .images
            ) {

                Label(
                    customBackFaceImageData ==
                        nil
                    ? "识别银行卡背面图片"
                    : "重新识别银行卡背面",
                    systemImage:
                        "creditcard.and.123"
                )
            }


            if customBackFaceImageData !=
                nil {

                Button(
                    "移除银行卡背面图片",
                    role:
                        .destructive
                ) {

                    customBackFaceImageData =
                        nil

                    backFaceMessage =
                        "保存后将恢复默认银行卡背面。"
                }
            }


            if let backFaceMessage {

                Text(
                    backFaceMessage
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }

        } header: {

            Text(
                "背面卡面"
            )

        } footer: {

            Text(
                "选择银行卡背面照片后，会自动识别卡片边框并透视矫正。背面只用于卡包翻转显示，不会读取或保存完整银行卡号。"
            )
        }
    }


    private var cardRecognitionSection:
        some View {

        Section {

            PhotosPicker(
                selection:
                    $selectedCardImage,
                matching:
                    .images
            ) {

                HStack {

                    Label(
                        isRecognizingCard
                        ? "正在识别银行卡..."
                        : "从银行卡图片识别",
                        systemImage:
                            isRecognizingCard
                            ? "hourglass"
                            : "viewfinder"
                    )

                    Spacer()

                    if isRecognizingCard {

                        ProgressView()
                            .controlSize(
                                .small
                            )
                    }
                }
            }
            .disabled(
                isRecognizingCard
            )


            if let recognitionMessage {

                Text(
                    recognitionMessage
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }

        } header: {

            Text(
                "智能识别"
            )

        } footer: {

            Text(
                "选择银行卡照片或截图后，会在本机识别银行名称、卡号后四位和卡片类型。不会上传图片。"
            )
        }
    }


    @MainActor
    private func recognizeCardImage(
        _ item:
            PhotosPickerItem
    ) async {

        focusedField =
            nil

        isRecognizingCard =
            true

        recognitionMessage =
            "正在读取图片..."

        defer {

            isRecognizingCard =
                false

            selectedCardImage =
                nil
        }

        do {

            guard
                let data =
                    try await item.loadTransferable(
                        type:
                            Data.self
                    )
            else {

                recognitionMessage =
                    "无法读取这张图片，请换一张再试。"

                return
            }


            let result =
                try await CardImageOCRService
                    .recognize(
                        imageData:
                            data
                    )


            if let extractedCardImageData =
                result.extractedCardImageData {

                recognizedImageData =
                    extractedCardImageData

                customFaceImageData =
                    extractedCardImageData

                faceMessage =
                    result.usedRectangleDetection
                    ? "已自动检测银行卡边框、透视矫正并提取为卡面。"
                    : "未检测到完整银行卡边框，已按卡片原始方向自动裁切为卡面。"

            } else {

                recognizedImageData =
                    nil

                faceMessage =
                    "银行卡信息已尝试识别，但没有成功提取卡面图片。"
            }


            if let detectedBankName =
                result.bankName {

                bankName =
                    detectedBankName
            }


            if let detectedLastFour =
                result.lastFourDigits {

                lastFourDigits =
                    sanitizeLastFour(
                        detectedLastFour
                    )
            }


            if let detectedCardType =
                result.cardType {

                cardType =
                    detectedCardType
            }


            // “无号码卡”不应同时拥有可识别的后四位；
            // 这种结果按艺术/联名卡处理，避免预览和识别消息不一致。
            let resolvedFaceType =
                result.faceType ==
                    .noNumber &&
                result.lastFourDigits != nil
                ? CardFaceType.art
                : result.faceType

            faceType =
                resolvedFaceType


            if result.bankName != nil ||
               result.lastFourDigits != nil ||
               result.cardType != nil ||
               result.extractedCardImageData != nil {

                var parts:
                    [String] = []

                if let name =
                    result.bankName {

                    parts.append(
                        name
                    )
                }

                if let lastFour =
                    result.lastFourDigits {

                    parts.append(
                        "•••• \(lastFour)"
                    )
                }

                if let detectedType =
                    result.cardType {

                    parts.append(
                        detectedType.rawValue
                    )
                }

                parts.append(
                    resolvedFaceType.rawValue
                )

                let cardFaceText =
                    result.extractedCardImageData != nil
                    ? " · 已自动提取卡面"
                    : ""

                if result.lastFourDigits ==
                    nil,
                   resolvedFaceType.requiresLastFour {

                    recognitionMessage =
                        "识别成功：\(parts.joined(separator: " · "))\(cardFaceText)。这类卡面可能没有印卡号，后四位请手动填写后保存。"

                } else {

                    recognitionMessage =
                        "识别成功：\(parts.joined(separator: " · "))\(cardFaceText)。请核对后保存。"
                }

            } else {

                recognitionMessage =
                    "已提取卡面，但未识别到足够银行信息。该类艺术卡可能没有标准卡号，请手动补充后保存。"
            }

        } catch {

            recognitionMessage =
                "识别失败：\(error.localizedDescription)"
        }
    }


    private var previewCustomFaceImage:
        UIImage? {

        guard
            let customFaceImageData
        else {

            return nil
        }

        return UIImage(
            data:
                customFaceImageData
        )
    }


    @MainActor
    private func loadCustomFace(
        _ item:
            PhotosPickerItem
    ) async {

        faceMessage =
            "正在读取卡面图片..."


        defer {

            selectedFaceImage =
                nil
        }


        do {

            guard
                let data =
                    try await item.loadTransferable(
                        type:
                            Data.self
                    ),
                UIImage(
                    data:
                        data
                ) != nil
            else {

                faceMessage =
                    "无法读取这张图片，请换一张再试。"

                return
            }


            customFaceImageData =
                data

            faceMessage =
                "自定义卡面已加载，保存银行卡后会写入本机。"

        } catch {

            faceMessage =
                "读取卡面失败：\(error.localizedDescription)"
        }
    }


    @MainActor
    private func recognizeBackFaceImage(
        _ item:
            PhotosPickerItem
    ) async {

        backFaceMessage =
            "正在识别银行卡背面..."


        defer {

            selectedBackFaceImage =
                nil
        }


        do {

            guard
                let data =
                    try await item.loadTransferable(
                        type:
                            Data.self
                    )
            else {

                backFaceMessage =
                    "无法读取这张图片，请换一张再试。"

                return
            }


            guard
                let extraction =
                    CardImageProcessor
                        .extractCardFace(
                            from:
                                data
                        )
            else {

                backFaceMessage =
                    "没有识别出银行卡卡面，请尽量使用完整、清晰、正对镜头的银行卡背面照片。"

                return
            }


            customBackFaceImageData =
                extraction.imageData

            backFaceMessage =
                extraction.usedRectangleDetection
                ? "已识别银行卡背面边框并完成透视矫正。"
                : "未检测到完整边框，已按银行卡比例自动裁切背面卡面。"


            HapticFeedback
                .success()

        } catch {

            backFaceMessage =
                "读取银行卡背面失败：\(error.localizedDescription)"
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
                "信用卡消费和还款会自动联动欠款，并同步计入总负债和净资产。"
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
                    sanitizeLastFour(
                        lastFourDigits
                    ),
                holderName:
                    holderName.isEmpty
                    ? "CARD HOLDER"
                    : holderName,
                theme:
                    theme,
                customFaceImage:
                    previewCustomFaceImage,
                faceType:
                    faceType
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
            (
                !faceType.requiresLastFour ||
                sanitizeLastFour(
                    lastFourDigits
                )
                .count ==
                    4
            )

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
                    nextOrder,
                faceType:
                    faceType
            )


        modelContext.insert(
            card
        )


        if card.cardType ==
            .credit {

            CreditAccountService
                .synchronizeCreditLimit(
                    card.creditLimit,
                    for:
                        card,
                    cards:
                        cards +
                        [card]
                )
        }


        try?
            modelContext.save()


        if let customFaceImageData {

            try?
                CardFaceImageStore
                    .save(
                        imageData:
                            customFaceImageData,
                        for:
                            card.id,
                        side:
                            .front
                    )
        }


        if let customBackFaceImageData {

            try?
                CardFaceImageStore
                    .save(
                        imageData:
                            customBackFaceImageData,
                        for:
                            card.id,
                        side:
                            .back
                    )
        }

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
        _ value:
            String
    ) -> String {

        var digits =
            ""


        for scalar in
            value.unicodeScalars {

            guard
                scalar.value >= 48,
                scalar.value <= 57
            else {

                continue
            }


            digits.unicodeScalars
                .append(
                    scalar
                )


            if digits.count ==
                4 {

                break
            }
        }


        return digits
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

    let customFaceImage:
        UIImage?

    let faceType:
        CardFaceType

    var body: some View {

        ZStack {

            previewBackground


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

                        CardFaceTypeBadge(
                            faceType:
                                faceType
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
                    cardNumberText(
                        faceType:
                            faceType,
                        lastFour:
                            lastFourDigits
                    )
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
            // 新增/编辑预览也与卡包及其他银行卡保持统一横向比例。
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


    @ViewBuilder
    private var previewBackground:
        some View {

        if let customFaceImage {

            Image(
                uiImage:
                    customFaceImage
            )
            .resizable()
            .scaledToFill()
            .frame(
                maxWidth:
                    .infinity,
                maxHeight:
                    .infinity
            )
            .clipped()
            .overlay {

                LinearGradient(
                    colors:
                        [
                            .black.opacity(
                                0.28
                            ),
                            .black.opacity(
                                0.08
                            ),
                            .black.opacity(
                                0.30
                            )
                        ],
                    startPoint:
                        .topLeading,
                    endPoint:
                        .bottomTrailing
                )
            }

        } else {

            CardThemeBackground(
                theme:
                    theme
            )
        }
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

    @Query(
        sort: \TransactionRecord.date,
        order: .reverse
    )
    private var transactions:
        [TransactionRecord]

    @Query(
        sort: \BankCard.createdAt
    )
    private var cards:
        [BankCard]

    @State
    private var showEdit =
        false

    @State
    private var showDelete =
        false

    @State
    private var showDeleteBlocked =
        false


    var body: some View {

        List {

            Section {

                FlippableBankCardView(
                    card:
                        card,
                    account:
                        linkedAccount,
                    allCards:
                        cards
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
                    "卡面类型",
                    value:
                        card.faceType
                            .rawValue
                )


                LabeledContent(
                    "卡号",
                    value:
                        cardNumberText(
                            faceType:
                                card.faceType,
                            lastFour:
                                card.lastFourDigits
                        )
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
                                CreditAccountService
                                    .sharedCreditLimit(
                                        for:
                                            card,
                                        cards:
                                            cards
                                    )
                            )
                        )
                    }


                    LabeledContent(
                        CreditAccountService
                            .group(
                                for:
                                    card,
                                cards:
                                    cards
                            )
                            .count >
                            1
                        ? "本卡欠款"
                        : "当前欠款"
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


                    if CreditAccountService
                        .group(
                            for:
                                card,
                            cards:
                                cards
                        )
                        .count >
                        1 {

                        LabeledContent(
                            "共用账户欠款"
                        ) {

                            Text(
                                formattedCurrency(
                                    CreditAccountService
                                        .sharedDebt(
                                            for:
                                                card,
                                            cards:
                                                cards
                                        )
                                )
                            )
                            .fontWeight(
                                .semibold
                            )
                        }
                    }


                    LabeledContent(
                        "可用额度"
                    ) {

                        Text(
                            formattedCurrency(
                                CreditAccountService
                                    .availableCredit(
                                        for:
                                            card,
                                        cards:
                                            cards
                                    )
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

                    if hasTransactions {

                        showDeleteBlocked =
                            true

                    } else {

                        showDelete =
                            true
                    }

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

                CardFaceImageStore
                    .deleteAll(
                        for:
                            card.id
                    )

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
                "只会删除卡包里的卡片，不会删除关联的资产账户。"
            )
        }
        .alert(
            "暂时不能删除",
            isPresented:
                $showDeleteBlocked
        ) {

            Button("好的") {}

        } message: {

            Text(
                "这张信用卡已经存在消费或还款记录。请先保留卡片，以免历史账单失去关联。"
            )
        }
    }


    private var hasTransactions:
        Bool {

        transactions.contains {
            $0.bankCardID ==
                card.id
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

    @Query(
        sort: \BankCard.createdAt
    )
    private var cards:
        [BankCard]


    @State
    private var bankName:
        String

    @State
    private var cardType:
        BankCardType

    @State
    private var faceType:
        CardFaceType

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
    private var currentDebtCurrencyCode:
        String

    @State
    private var debtExchangeRates =
        ExchangeRateService
            .cachedSnapshot()

    @State
    private var isRefreshingDebtRate =
        false

    @State
    private var debtRateMessage:
        String?

    @State
    private var billingDay:
        Int

    @State
    private var repaymentDay:
        Int

    @State
    private var selectedCardImage:
        PhotosPickerItem?

    @State
    private var isRecognizingCard =
        false

    @State
    private var recognitionMessage:
        String?

    @State
    private var recognizedImageData:
        Data?

    @State
    private var selectedFaceImage:
        PhotosPickerItem?

    @State
    private var customFaceImageData:
        Data?

    @State
    private var selectedBackFaceImage:
        PhotosPickerItem?

    @State
    private var customBackFaceImageData:
        Data?

    @State
    private var faceMessage:
        String?

    @State
    private var backFaceMessage:
        String?

    @FocusState
    private var focusedField:
        EditCardNumberField?


    private enum EditCardNumberField:
        Hashable {

        case bankName
        case holderName
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

        _faceType =
            State(
                initialValue:
                    card.faceType
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
                    (
                        card.currentDebtOriginalAmount ??
                        card.currentDebt
                    )
                    .map {
                        String(
                            format:
                                "%.2f",
                            $0
                        )
                    }
                    ?? ""
            )

        _currentDebtCurrencyCode =
            State(
                initialValue:
                    card.currentDebtCurrencyCode
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

        _customFaceImageData =
            State(
                initialValue:
                    CardFaceImageStore
                        .imageData(
                            for:
                                card.id,
                            side:
                                .front
                        )
            )

        _customBackFaceImageData =
            State(
                initialValue:
                    CardFaceImageStore
                        .imageData(
                            for:
                                card.id,
                            side:
                                .back
                        )
            )
    }


    var body: some View {

        NavigationStack {

            Form {

                previewSection

                cardRecognitionSection

                basicInfoSection

                if cardType ==
                    .credit {

                    creditCardSection
                }

                linkedAccountSection

                cardFaceSection

                cardBackFaceSection
            }
            .scrollDismissesKeyboard(
                .interactively
            )
            .task(
                id:
                    debtRateRefreshKey
            ) {

                await refreshDebtExchangeRateIfNeeded()
            }
            .onChange(
                of:
                    currentDebtCurrencyCode
            ) { _, _ in

                debtRateMessage =
                    nil
            }
            .onChange(
                of: selectedCardImage
            ) { _, newItem in

                guard let newItem
                else {
                    return
                }

                Task {

                    await recognizeCardImage(
                        newItem
                    )
                }
            }
            .onChange(
                of: selectedFaceImage
            ) { _, newItem in

                guard let newItem
                else {
                    return
                }

                Task {

                    await loadCustomFace(
                        newItem
                    )
                }
            }
            .onChange(
                of: selectedBackFaceImage
            ) { _, newItem in

                guard let newItem
                else {
                    return
                }

                Task {

                    await recognizeBackFaceImage(
                        newItem
                    )
                }
            }
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


    private var previewSection:
        some View {

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
                    theme,
                customFaceImage:
                    previewCustomFaceImage,
                faceType:
                    faceType
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


    private var basicInfoSection:
        some View {

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
                    .tag(
                        item
                    )
                }
            }


            Picker(
                "卡面类型",
                selection:
                    $faceType
            ) {

                ForEach(
                    CardFaceType
                        .allCases,
                    id: \.self
                ) { item in

                    Text(
                        item.rawValue
                    )
                    .tag(
                        item
                    )
                }
            }


            TextField(
                faceType.requiresLastFour
                ? "卡号后四位"
                : "卡号后四位（可选）",
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
                "持卡人",
                text:
                    $holderName
            )
            .focused(
                $focusedField,
                equals:
                    .holderName
            )
            .submitLabel(
                .done
            )
            .onSubmit {

                focusedField =
                    nil
            }
        }
    }


    private var linkedAccountSection:
        some View {

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
    }


    private var cardFaceSection:
        some View {

        Section {

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
                    .tag(
                        item
                    )
                }
            }


            PhotosPicker(
                selection:
                    $selectedFaceImage,
                matching:
                    .images
            ) {

                Label(
                    customFaceImageData == nil
                    ? "选择自定义卡面"
                    : "更换自定义卡面",
                    systemImage:
                        "photo"
                )
            }


            if recognizedImageData != nil {

                Button {

                    customFaceImageData =
                        recognizedImageData

                    faceMessage =
                        "已将本次识别图片设为卡面预览。"

                } label: {

                    Label(
                        "使用识别图片作为卡面",
                        systemImage:
                            "rectangle.on.rectangle"
                    )
                }
            }


            if customFaceImageData != nil {

                Button(
                    "恢复主题卡面",
                    role:
                        .destructive
                ) {

                    customFaceImageData =
                        nil

                    faceMessage =
                        "保存后将移除自定义卡面。"
                }
            }


            if let faceMessage {

                Text(
                    faceMessage
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }

        } header: {

            Text(
                "正面卡面"
            )

        } footer: {

            Text(
                "正面自定义卡面只保存在本机，不写入 SwiftData，也不会上传。"
            )
        }
    }


    private var cardBackFaceSection:
        some View {

        Section {

            if let data =
                customBackFaceImageData,
               let image =
                UIImage(
                    data:
                        data
                ) {

                Image(
                    uiImage:
                        image
                )
                .resizable()
                .scaledToFill()
                .frame(
                    height:
                        120
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius:
                            14,
                        style:
                            .continuous
                    )
                )
            }


            PhotosPicker(
                selection:
                    $selectedBackFaceImage,
                matching:
                    .images
            ) {

                Label(
                    customBackFaceImageData ==
                        nil
                    ? "识别银行卡背面图片"
                    : "重新识别银行卡背面",
                    systemImage:
                        "creditcard.and.123"
                )
            }


            if customBackFaceImageData !=
                nil {

                Button(
                    "移除银行卡背面图片",
                    role:
                        .destructive
                ) {

                    customBackFaceImageData =
                        nil

                    backFaceMessage =
                        "保存后将恢复默认银行卡背面。"
                }
            }


            if let backFaceMessage {

                Text(
                    backFaceMessage
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }

        } header: {

            Text(
                "背面卡面"
            )

        } footer: {

            Text(
                "选择银行卡背面照片后，会自动识别卡片边框并透视矫正。背面只用于卡包翻转显示，不会读取或保存完整银行卡号。"
            )
        }
    }


    private var cardRecognitionSection:
        some View {

        Section {

            PhotosPicker(
                selection:
                    $selectedCardImage,
                matching:
                    .images
            ) {

                HStack {

                    Label(
                        isRecognizingCard
                        ? "正在重新识别..."
                        : "从图片重新识别",
                        systemImage:
                            isRecognizingCard
                            ? "hourglass"
                            : "viewfinder"
                    )

                    Spacer()

                    if isRecognizingCard {

                        ProgressView()
                            .controlSize(
                                .small
                            )
                    }
                }
            }
            .disabled(
                isRecognizingCard
            )


            if let recognitionMessage {

                Text(
                    recognitionMessage
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }

        } header: {

            Text(
                "智能识别"
            )

        } footer: {

            Text(
                "重新选择银行卡照片或截图后，只会覆盖识别到的字段；信用额度、欠款、账单日和还款日不会被图片识别修改。"
            )
        }
    }


    @MainActor
    private func recognizeCardImage(
        _ item:
            PhotosPickerItem
    ) async {

        focusedField =
            nil

        isRecognizingCard =
            true

        recognitionMessage =
            "正在读取图片..."

        defer {

            isRecognizingCard =
                false

            selectedCardImage =
                nil
        }

        do {

            guard
                let data =
                    try await item.loadTransferable(
                        type:
                            Data.self
                    )
            else {

                recognitionMessage =
                    "无法读取这张图片，请换一张再试。"

                return
            }


            let result =
                try await CardImageOCRService
                    .recognize(
                        imageData:
                            data
                    )


            if let extractedCardImageData =
                result.extractedCardImageData {

                recognizedImageData =
                    extractedCardImageData

                customFaceImageData =
                    extractedCardImageData

                faceMessage =
                    result.usedRectangleDetection
                    ? "已自动检测银行卡边框、透视矫正并更新卡面预览。"
                    : "未检测到完整边框，已按卡片原始方向自动裁切并更新卡面预览。"
            }


            if let detectedBankName =
                result.bankName {

                bankName =
                    detectedBankName
            }


            if let detectedLastFour =
                result.lastFourDigits {

                lastFourDigits =
                    sanitizeLastFour(
                        detectedLastFour
                    )
            }


            if let detectedCardType =
                result.cardType {

                cardType =
                    detectedCardType
            }


            let resolvedFaceType =
                result.faceType ==
                    .noNumber &&
                result.lastFourDigits != nil
                ? CardFaceType.art
                : result.faceType

            faceType =
                resolvedFaceType


            if result.bankName != nil ||
               result.lastFourDigits != nil ||
               result.cardType != nil ||
               result.extractedCardImageData != nil {

                recognitionMessage =
                    "已更新识别到的银行卡信息，请核对后保存。"

            } else {

                recognitionMessage =
                    "没有可靠提取出新的银行卡信息，原有内容未修改。"
            }

        } catch {

            recognitionMessage =
                "识别失败：\(error.localizedDescription)"
        }
    }


    private var previewCustomFaceImage:
        UIImage? {

        guard
            let customFaceImageData
        else {

            return nil
        }

        return UIImage(
            data:
                customFaceImageData
        )
    }


    @MainActor
    private func loadCustomFace(
        _ item:
            PhotosPickerItem
    ) async {

        faceMessage =
            "正在读取卡面图片..."


        defer {

            selectedFaceImage =
                nil
        }


        do {

            guard
                let data =
                    try await item.loadTransferable(
                        type:
                            Data.self
                    ),
                UIImage(
                    data:
                        data
                ) != nil
            else {

                faceMessage =
                    "无法读取这张图片，请换一张再试。"

                return
            }


            customFaceImageData =
                data

            faceMessage =
                "自定义卡面已加载，保存银行卡后会写入本机。"

        } catch {

            faceMessage =
                "读取卡面失败：\(error.localizedDescription)"
        }
    }


    @MainActor
    private func recognizeBackFaceImage(
        _ item:
            PhotosPickerItem
    ) async {

        backFaceMessage =
            "正在识别银行卡背面..."


        defer {

            selectedBackFaceImage =
                nil
        }


        do {

            guard
                let data =
                    try await item.loadTransferable(
                        type:
                            Data.self
                    )
            else {

                backFaceMessage =
                    "无法读取这张图片，请换一张再试。"

                return
            }


            guard
                let extraction =
                    CardImageProcessor
                        .extractCardFace(
                            from:
                                data
                        )
            else {

                backFaceMessage =
                    "没有识别出银行卡卡面，请尽量使用完整、清晰、正对镜头的银行卡背面照片。"

                return
            }


            customBackFaceImageData =
                extraction.imageData

            backFaceMessage =
                extraction.usedRectangleDetection
                ? "已识别银行卡背面边框并完成透视矫正。"
                : "未检测到完整边框，已按银行卡比例自动裁切背面卡面。"


            HapticFeedback
                .success()

        } catch {

            backFaceMessage =
                "读取银行卡背面失败：\(error.localizedDescription)"
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


            HStack(
                spacing: 8
            ) {

                Text(
                    "当前欠款"
                )

                Spacer()

                Text(
                    CurrencyCatalog
                        .symbol(
                            for:
                                currentDebtCurrencyCode
                        )
                )
                .foregroundStyle(
                    .secondary
                )

                ReliableDecimalTextField(
                    text:
                        $currentDebtText,
                    placeholder:
                        "0.00",
                    font:
                        .systemFont(
                            ofSize: 17
                        ),
                    alignment:
                        .right
                )
                .frame(
                    width: 105,
                    height: 34
                )

                Picker(
                    "欠款币种",
                    selection:
                        $currentDebtCurrencyCode
                ) {

                    ForEach(
                        CurrencyCatalog.supported
                    ) { currency in

                        Text(
                            currency.code
                        )
                        .tag(
                            currency.code
                        )
                    }
                }
                .labelsHidden()
                .frame(
                    maxWidth: 78
                )
            }


            if currentDebtCurrencyCode !=
                "CNY" {

                if let estimate =
                    currentDebtCNYEstimate {

                    LabeledContent(
                        "人民币估值"
                    ) {

                        Text(
                            formattedCNY(
                                estimate
                            )
                        )
                        .fontWeight(
                            .semibold
                        )
                    }
                }


                if let rate =
                    selectedDebtRateToCNY {

                    Text(
                        debtRateSummaryText(
                            rate: rate
                        )
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )

                } else if isRefreshingDebtRate {

                    Label(
                        "正在查询银行实时汇率…",
                        systemImage:
                            "arrow.triangle.2.circlepath"
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }


                if let debtRateMessage {

                    Text(
                        debtRateMessage
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
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

        let basicValid =
            !bankName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .isEmpty
            &&
            (
                !faceType.requiresLastFour ||
                sanitizeLastFour(
                    lastFourDigits
                )
                .count ==
                    4
            )


        guard basicValid
        else {
            return false
        }


        guard
            cardType ==
                .credit,
            parsedAmount(
                currentDebtText
            ) != nil,
            currentDebtCurrencyCode !=
                "CNY"
        else {
            return true
        }


        return selectedDebtRateToCNY !=
            nil
    }


    private var debtRateRefreshKey:
        String {

        currentDebtCurrencyCode +
            "|" +
            bankName
    }


    private var selectedDebtRateToCNY:
        Double? {

        if currentDebtCurrencyCode ==
            "CNY" {

            return 1
        }


        if let fresh =
            debtExchangeRates
                .rateToCNY(
                    for:
                        currentDebtCurrencyCode
                ) {

            return fresh
        }


        if currentDebtCurrencyCode ==
            card.currentDebtCurrencyCode {

            return card
                .currentDebtExchangeRateToCNY
        }


        return nil
    }


    private var currentDebtCNYEstimate:
        Double? {

        guard
            let amount =
                parsedAmount(
                    currentDebtText
                ),
            let rate =
                selectedDebtRateToCNY
        else {
            return nil
        }


        return amount *
            rate
    }


    private func formattedCNY(
        _ amount:
            Double
    ) -> String {

        String(
            format:
                "¥%.2f",
            amount
        )
    }


    private func debtRateSummaryText(
        rate:
            Double
    ) -> String {

        let rateText =
            String(
                format:
                    "%.4f",
                rate
            )

        return "1 " +
            currentDebtCurrencyCode +
            " ≈ ¥" +
            rateText +
            " · " +
            debtExchangeRates.sourceName
    }


    private func refreshDebtExchangeRateIfNeeded() async {

        guard currentDebtCurrencyCode !=
            "CNY"
        else {

            debtRateMessage =
                nil

            return
        }


        if debtExchangeRates
            .rateToCNY(
                for:
                    currentDebtCurrencyCode
            ) != nil,
           Date()
            .timeIntervalSince(
                debtExchangeRates.fetchedAt
            ) <
            15 * 60 {

            return
        }


        isRefreshingDebtRate =
            true

        defer {
            isRefreshingDebtRate =
                false
        }


        do {

            let provider =
                ExchangeRateService
                    .preferredProvider(
                        for:
                            bankName
                    )

            debtExchangeRates =
                try await ExchangeRateService
                    .refresh(
                        provider:
                            provider
                    )


            if debtExchangeRates
                .rateToCNY(
                    for:
                        currentDebtCurrencyCode
                ) == nil {

                debtRateMessage =
                    "暂未获取到该币种汇率，请稍后重试。"

            } else {

                debtRateMessage =
                    nil
            }

        } catch {

            if selectedDebtRateToCNY ==
                nil {

                debtRateMessage =
                    ExchangeRateService
                        .userFacingErrorMessage(
                            error
                        )
            }
        }
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

        card.faceTypeRaw =
            faceType.rawValue

        card.lastFourDigits =
            sanitizeLastFour(
                lastFourDigits
            )

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

            let originalDebt =
                parsedAmount(
                    currentDebtText
                )

            let debtRate =
                selectedDebtRateToCNY ??
                1

            card.currentDebt =
                originalDebt.map {
                    $0 * debtRate
                }

            card.currentDebtOriginalAmount =
                originalDebt

            card.currentDebtCurrencyCodeRaw =
                originalDebt == nil
                ? nil
                : currentDebtCurrencyCode

            card.currentDebtExchangeRateToCNY =
                originalDebt == nil
                ? nil
                : debtRate

            card.billingDay =
                billingDay

            card.repaymentDay =
                repaymentDay

        } else {

            card.creditLimit =
                nil

            card.currentDebt =
                nil

            card.currentDebtOriginalAmount =
                nil

            card.currentDebtCurrencyCodeRaw =
                nil

            card.currentDebtExchangeRateToCNY =
                nil

            card.billingDay =
                nil

            card.repaymentDay =
                nil
        }

        if cardType ==
            .credit {

            CreditAccountService
                .synchronizeCreditLimit(
                    card.creditLimit,
                    for:
                        card,
                    cards:
                        cards
                )
        }


        try?
            modelContext.save()


        if let customFaceImageData {

            try?
                CardFaceImageStore
                    .save(
                        imageData:
                            customFaceImageData,
                        for:
                            card.id,
                        side:
                            .front
                    )

        } else {

            CardFaceImageStore
                .delete(
                    for:
                        card.id,
                    side:
                        .front
                )
        }


        if let customBackFaceImageData {

            try?
                CardFaceImageStore
                    .save(
                        imageData:
                            customBackFaceImageData,
                        for:
                            card.id,
                        side:
                            .back
                    )

        } else {

            CardFaceImageStore
                .delete(
                    for:
                        card.id,
                    side:
                        .back
                )
        }

        dismiss()
    }


    private func sanitizeLastFour(
        _ value:
            String
    ) -> String {

        var digits =
            ""


        for scalar in
            value.unicodeScalars {

            guard
                scalar.value >= 48,
                scalar.value <= 57
            else {

                continue
            }


            digits.unicodeScalars
                .append(
                    scalar
                )


            if digits.count ==
                4 {

                break
            }
        }


        return digits
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

                                CardFaceTypeBadge(
                                    faceType:
                                        card.faceType
                                )

                                Text(
                                    cardNumberText(
                                        faceType:
                                            card.faceType,
                                        lastFour:
                                            card.lastFourDigits
                                    )
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
