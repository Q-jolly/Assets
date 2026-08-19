import Foundation


struct ExchangeRateSnapshot:
    Codable,
    Equatable {

    let ratesToCNY:
        [String: Double]

    let fetchedAt:
        Date

    let sourceName:
        String


    static let cnyOnly =
        ExchangeRateSnapshot(
            ratesToCNY:
                [
                    "CNY": 1
                ],
            fetchedAt:
                .distantPast,
            sourceName:
                "本地"
        )


    func rateToCNY(
        for code:
            String
    ) -> Double? {

        if code.uppercased() ==
            "CNY" {

            return 1
        }


        return ratesToCNY[
            code.uppercased()
        ]
    }
}


enum ExchangeRateProvider:
    String,
    Codable {

    case cmb
    case boc


    var displayName:
        String {

        switch self {

        case .cmb:
            return "招商银行外汇实时汇率"

        case .boc:
            return "中国银行外汇牌价"
        }
    }
}


enum ExchangeRateService {

    private static let cacheKey =
        "exchange.rate.snapshot.v1"

    private static let cmbURL =
        URL(
            string:
                "https://fx.cmbchina.cn/hq/"
        )!

    private static let bocURL =
        URL(
            string:
                "https://www.bankofchina.com/english/bocinfo/"
        )!


    static func cachedSnapshot()
        -> ExchangeRateSnapshot {

        guard
            let data =
                UserDefaults.standard
                    .data(
                        forKey:
                            cacheKey
                    ),
            let decoded =
                try?
                    JSONDecoder()
                        .decode(
                            ExchangeRateSnapshot.self,
                            from:
                                data
                        )
        else {

            return .cnyOnly
        }


        return decoded
    }


    static func preferredProvider(
        for bankName:
            String?
    ) -> ExchangeRateProvider {

        let name =
            bankName ??
            ""


        if name.contains(
            "招商"
        ) ||
            name.uppercased()
                .contains(
                    "CMB"
                ) {

            return .cmb
        }


        return .boc
    }


    static func refresh(
        provider:
            ExchangeRateProvider
    ) async throws
        -> ExchangeRateSnapshot {

        let primary:
            ExchangeRateSnapshot


        do {

            switch provider {

            case .cmb:

                primary =
                    try await fetchCMB()

            case .boc:

                primary =
                    try await fetchBOC()
            }

        } catch {

            // 银行页面偶发维护时自动使用另一家官方银行页面兜底。
            switch provider {

            case .cmb:
                primary =
                    try await fetchBOC()

            case .boc:
                primary =
                    try await fetchCMB()
            }
        }


        saveCache(
            primary
        )

        return primary
    }


    private static func fetchCMB() async throws
        -> ExchangeRateSnapshot {

        let html =
            try await fetchHTML(
                cmbURL
            )

        let rows =
            tableRows(
                html
            )

        let nameToCode:
            [String: String] = [

                "美元": "USD",
                "欧元": "EUR",
                "英镑": "GBP",
                "日元": "JPY",
                "港币": "HKD",
                "澳大利亚元": "AUD",
                "澳元": "AUD",
                "加拿大元": "CAD",
                "新加坡元": "SGD",
                "瑞士法郎": "CHF",
                "新西兰元": "NZD"
            ]


        var rates:
            [String: Double] = [

                "CNY": 1
            ]


        for cells in rows {

            guard
                cells.count >=
                    7,
                let code =
                    nameToCode[
                        cells[0]
                    ]
            else {
                continue
            }


            let sell =
                number(
                    cells[3]
                )

            let buy =
                number(
                    cells[5]
                )

            let selected:
                Double?


            if let sell,
               let buy {

                // 用结汇/售汇中点作为资产估值参考。
                selected =
                    (
                        sell +
                        buy
                    ) /
                    2

            } else {

                selected =
                    sell ??
                    buy
            }


            if let selected,
               selected >
                0 {

                rates[
                    code
                ] =
                    selected /
                    100
            }
        }


        guard rates.count >
            1
        else {

            throw URLError(
                .cannotParseResponse
            )
        }


        return ExchangeRateSnapshot(
            ratesToCNY:
                rates,
            fetchedAt:
                Date(),
            sourceName:
                ExchangeRateProvider
                    .cmb
                    .displayName
        )
    }


    private static func fetchBOC() async throws
        -> ExchangeRateSnapshot {

        let html =
            try await fetchHTML(
                bocURL
            )

        let rows =
            tableRows(
                html
            )

        var rates:
            [String: Double] = [

                "CNY": 1
            ]


        for cells in rows {

            guard
                cells.count >=
                    6
            else {
                continue
            }


            let code =
                cells[0]
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                    .uppercased()


            guard
                code.count ==
                    3,
                CurrencyCatalog.supported
                    .contains(
                        where: {
                            $0.code ==
                            code
                        }
                    )
            else {
                continue
            }


            let middle =
                number(
                    cells[5]
                )

            let buying =
                cells.count >
                    1
                ? number(
                    cells[1]
                )
                : nil

            let selling =
                cells.count >
                    3
                ? number(
                    cells[3]
                )
                : nil


            let selected =
                middle ??
                (
                    buying != nil &&
                    selling != nil
                    ? (
                        buying! +
                        selling!
                    ) /
                    2
                    : buying ??
                      selling
                )


            if let selected,
               selected >
                0 {

                rates[
                    code
                ] =
                    selected /
                    100
            }
        }


        guard rates.count >
            1
        else {

            throw URLError(
                .cannotParseResponse
            )
        }


        return ExchangeRateSnapshot(
            ratesToCNY:
                rates,
            fetchedAt:
                Date(),
            sourceName:
                ExchangeRateProvider
                    .boc
                    .displayName
        )
    }


    private static func fetchHTML(
        _ url:
            URL
    ) async throws
        -> String {

        var request =
            URLRequest(
                url:
                    url
            )

        request.timeoutInterval =
            12

        request.setValue(
            "Mozilla/5.0 QLAssets/1.0",
            forHTTPHeaderField:
                "User-Agent"
        )


        let (
            data,
            response
        ) =
            try await URLSession.shared
                .data(
                    for:
                        request
                )


        guard
            let http =
                response as?
                    HTTPURLResponse,
            200..<300 ~=
                http.statusCode
        else {

            throw URLError(
                .badServerResponse
            )
        }


        if let utf8 =
            String(
                data:
                    data,
                encoding:
                    .utf8
            ) {

            return utf8
        }


        if let unicode =
            String(
                data:
                    data,
                encoding:
                    .unicode
            ) {

            return unicode
        }


        throw URLError(
            .cannotDecodeContentData
        )
    }


    private static func tableRows(
        _ html:
            String
    ) -> [[String]] {

        let rowPattern =
            "(?is)<tr[^>]*>(.*?)</tr>"

        let cellPattern =
            "(?is)<t[dh][^>]*>(.*?)</t[dh]>"


        guard
            let rowRegex =
                try? NSRegularExpression(
                    pattern:
                        rowPattern
                ),
            let cellRegex =
                try? NSRegularExpression(
                    pattern:
                        cellPattern
                )
        else {

            return []
        }


        let ns =
            html as NSString

        let fullRange =
            NSRange(
                location:
                    0,
                length:
                    ns.length
            )


        return rowRegex
            .matches(
                in:
                    html,
                range:
                    fullRange
            )
            .compactMap {
                rowMatch -> [String]? in

                guard rowMatch.numberOfRanges >
                    1
                else {
                    return nil
                }


                let rowHTML =
                    ns.substring(
                        with:
                            rowMatch.range(
                                at:
                                    1
                            )
                    )

                let rowNS =
                    rowHTML as NSString

                let rowRange =
                    NSRange(
                        location:
                            0,
                        length:
                            rowNS.length
                    )


                let cells =
                    cellRegex
                        .matches(
                            in:
                                rowHTML,
                            range:
                                rowRange
                        )
                        .compactMap {
                            cellMatch -> String? in

                            guard cellMatch.numberOfRanges >
                                1
                            else {
                                return nil
                            }


                            let raw =
                                rowNS.substring(
                                    with:
                                        cellMatch.range(
                                            at:
                                                1
                                        )
                                )


                            return cleanHTML(
                                raw
                            )
                        }


                return cells.isEmpty
                ? nil
                : cells
            }
    }


    private static func cleanHTML(
        _ raw:
            String
    ) -> String {

        let withoutTags =
            raw.replacingOccurrences(
                of:
                    "<[^>]+>",
                with:
                    "",
                options:
                    .regularExpression
            )


        return withoutTags
            .replacingOccurrences(
                of:
                    "&nbsp;",
                with:
                    " "
            )
            .replacingOccurrences(
                of:
                    "&amp;",
                with:
                    "&"
            )
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
    }


    private static func number(
        _ text:
            String
    ) -> Double? {

        Double(
            text
                .replacingOccurrences(
                    of:
                        ",",
                    with:
                        ""
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
        )
    }


    private static func saveCache(
        _ snapshot:
            ExchangeRateSnapshot
    ) {

        guard let data =
            try?
                JSONEncoder()
                    .encode(
                        snapshot
                    )
        else {
            return
        }


        UserDefaults.standard
            .set(
                data,
                forKey:
                    cacheKey
            )
    }
}
