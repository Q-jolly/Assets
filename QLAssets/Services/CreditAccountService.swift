import Foundation


enum CreditAccountService {

    static func group(
        for card:
            BankCard,
        cards:
            [BankCard]
    ) -> [BankCard] {

        guard
            card.cardType ==
                .credit,
            let accountID =
                card.accountID
        else {

            return [
                card
            ]
        }


        let linked =
            cards.filter {
                $0.cardType ==
                    .credit &&
                $0.accountID ==
                    accountID
            }


        return linked.isEmpty
        ? [card]
        : linked
    }


    static func sharedCreditLimit(
        for card:
            BankCard,
        cards:
            [BankCard]
    ) -> Double? {

        group(
            for:
                card,
            cards:
                cards
        )
        .compactMap {
            $0.creditLimit
        }
        .max()
    }


    static func sharedDebt(
        for card:
            BankCard,
        cards:
            [BankCard]
    ) -> Double {

        group(
            for:
                card,
            cards:
                cards
        )
        .reduce(
            0
        ) {
            result,
            item in

            result +
            max(
                item.currentDebt ??
                0,
                0
            )
        }
    }


    static func availableCredit(
        for card:
            BankCard,
        cards:
            [BankCard]
    ) -> Double? {

        guard let limit =
            sharedCreditLimit(
                for:
                    card,
                cards:
                    cards
            )
        else {
            return nil
        }


        return max(
            limit -
            sharedDebt(
                for:
                    card,
                cards:
                    cards
            ),
            0
        )
    }


    static func synchronizeCreditLimit(
        _ limit:
            Double?,
        for card:
            BankCard,
        cards:
            [BankCard]
    ) {

        guard
            card.cardType ==
                .credit,
            let accountID =
                card.accountID
        else {
            return
        }


        let linkedCards =
            cards.filter {
                $0.cardType ==
                    .credit &&
                $0.accountID ==
                    accountID
            }


        let effectiveLimit =
            limit ??
            linkedCards
                .compactMap {
                    $0.creditLimit
                }
                .max()


        for item in
            linkedCards {

            item.creditLimit =
                effectiveLimit
        }
    }
}
