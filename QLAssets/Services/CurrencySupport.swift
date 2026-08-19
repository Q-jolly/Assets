import Foundation


struct CurrencyDefinition:
    Identifiable,
    Hashable {

    let code:
        String

    let name:
        String

    let symbol:
        String


    var id:
        String {

        code
    }


    var title:
        String {

        "\(code) · \(name)"
    }
}


enum CurrencyCatalog {

    static let cny =
        CurrencyDefinition(
            code:
                "CNY",
            name:
                "人民币",
            symbol:
                "¥"
        )


    static let supported:
        [CurrencyDefinition] = [

            cny,

            CurrencyDefinition(
                code:
                    "USD",
                name:
                    "美元",
                symbol:
                    "$"
            ),

            CurrencyDefinition(
                code:
                    "EUR",
                name:
                    "欧元",
                symbol:
                    "€"
            ),

            CurrencyDefinition(
                code:
                    "GBP",
                name:
                    "英镑",
                symbol:
                    "£"
            ),

            CurrencyDefinition(
                code:
                    "JPY",
                name:
                    "日元",
                symbol:
                    "¥"
            ),

            CurrencyDefinition(
                code:
                    "HKD",
                name:
                    "港币",
                symbol:
                    "HK$"
            ),

            CurrencyDefinition(
                code:
                    "AUD",
                name:
                    "澳元",
                symbol:
                    "A$"
            ),

            CurrencyDefinition(
                code:
                    "CAD",
                name:
                    "加元",
                symbol:
                    "C$"
            ),

            CurrencyDefinition(
                code:
                    "SGD",
                name:
                    "新加坡元",
                symbol:
                    "S$"
            ),

            CurrencyDefinition(
                code:
                    "CHF",
                name:
                    "瑞士法郎",
                symbol:
                    "CHF"
            ),

            CurrencyDefinition(
                code:
                    "NZD",
                name:
                    "新西兰元",
                symbol:
                    "NZ$"
            ),

            CurrencyDefinition(
                code:
                    "KRW",
                name:
                    "韩元",
                symbol:
                    "₩"
            ),

            CurrencyDefinition(
                code:
                    "THB",
                name:
                    "泰铢",
                symbol:
                    "฿"
            ),

            CurrencyDefinition(
                code:
                    "AED",
                name:
                    "阿联酋迪拉姆",
                symbol:
                    "AED"
            ),

            CurrencyDefinition(
                code:
                    "MOP",
                name:
                    "澳门元",
                symbol:
                    "MOP$"
            ),

            CurrencyDefinition(
                code:
                    "DKK",
                name:
                    "丹麦克朗",
                symbol:
                    "kr"
            ),

            CurrencyDefinition(
                code:
                    "SEK",
                name:
                    "瑞典克朗",
                symbol:
                    "kr"
            ),

            CurrencyDefinition(
                code:
                    "NOK",
                name:
                    "挪威克朗",
                symbol:
                    "kr"
            )
        ]


    static func definition(
        for code:
            String
    ) -> CurrencyDefinition {

        supported.first {
            $0.code ==
            code.uppercased()
        } ??
        CurrencyDefinition(
            code:
                code.uppercased(),
            name:
                code.uppercased(),
            symbol:
                code.uppercased()
        )
    }


    static func symbol(
        for code:
            String
    ) -> String {

        definition(
            for:
                code
        )
        .symbol
    }
}
