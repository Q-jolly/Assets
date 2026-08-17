import Foundation
import Vision
import UIKit


struct BankCardOCRResult {

    let bankName:
        String?

    let lastFourDigits:
        String?

    let cardType:
        BankCardType?

    let recognizedText:
        String
}


enum CardImageOCRService {

    enum RecognitionError:
        LocalizedError {

        case invalidImage

        case visionFailed


        var errorDescription:
            String? {

            switch self {

            case .invalidImage:

                return
                    "图片格式无法识别"

            case .visionFailed:

                return
                    "没有识别到可用文字"
            }
        }
    }


    static func recognize(
        imageData:
            Data
    ) async throws
        -> BankCardOCRResult {

        guard
            let image =
                UIImage(
                    data:
                        imageData
                ),
            let cgImage =
                image.cgImage
        else {

            throw RecognitionError
                .invalidImage
        }


        let request =
            VNRecognizeTextRequest()

        request.recognitionLevel =
            .accurate

        request.usesLanguageCorrection =
            true

        request.recognitionLanguages =
            [
                "zh-Hans",
                "en-US"
            ]

        request.minimumTextHeight =
            0.012


        let handler =
            VNImageRequestHandler(
                cgImage:
                    cgImage,
                orientation:
                    cgImageOrientation(
                        for:
                            image.imageOrientation
                    ),
                options:
                    [:]
            )


        try handler.perform(
            [request]
        )


        let observations =
            request.results
            ?? []


        let lines =
            observations.compactMap {
                $0.topCandidates(1)
                    .first?
                    .string
            }


        guard !lines.isEmpty
        else {

            throw RecognitionError
                .visionFailed
        }


        let fullText =
            lines.joined(
                separator:
                    "\n"
            )


        let cardNumber =
            findBestCardNumber(
                in:
                    lines
            )


        return BankCardOCRResult(
            bankName:
                detectBankName(
                    in:
                        fullText
                ),
            lastFourDigits:
                cardNumber.map {
                    String(
                        $0.suffix(4)
                    )
                },
            cardType:
                detectCardType(
                    in:
                        fullText
                ),
            recognizedText:
                fullText
        )
    }


    // MARK: - 银行名称

    private static func detectBankName(
        in text:
            String
    ) -> String? {

        let normalized =
            text.uppercased()

        let bankAliases:
            [(
                keywords:
                    [String],
                name:
                    String
            )] = [

                (
                    [
                        "中国工商银行",
                        "工商银行",
                        "ICBC"
                    ],
                    "中国工商银行"
                ),

                (
                    [
                        "中国农业银行",
                        "农业银行",
                        "ABC"
                    ],
                    "中国农业银行"
                ),

                (
                    [
                        "中国银行",
                        "BANK OF CHINA",
                        "BOC"
                    ],
                    "中国银行"
                ),

                (
                    [
                        "中国建设银行",
                        "建设银行",
                        "CCB"
                    ],
                    "中国建设银行"
                ),

                (
                    [
                        "交通银行",
                        "BANK OF COMMUNICATIONS",
                        "BOCOM"
                    ],
                    "交通银行"
                ),

                (
                    [
                        "招商银行",
                        "CHINA MERCHANTS BANK",
                        "CMB"
                    ],
                    "招商银行"
                ),

                (
                    [
                        "中信银行",
                        "CHINA CITIC BANK",
                        "CITIC"
                    ],
                    "中信银行"
                ),

                (
                    [
                        "中国光大银行",
                        "光大银行",
                        "CEB"
                    ],
                    "中国光大银行"
                ),

                (
                    [
                        "华夏银行",
                        "HUA XIA BANK",
                        "HXB"
                    ],
                    "华夏银行"
                ),

                (
                    [
                        "中国民生银行",
                        "民生银行",
                        "CMBC"
                    ],
                    "中国民生银行"
                ),

                (
                    [
                        "广发银行",
                        "CHINA GUANGFA BANK",
                        "CGB"
                    ],
                    "广发银行"
                ),

                (
                    [
                        "平安银行",
                        "PING AN BANK",
                        "PAB"
                    ],
                    "平安银行"
                ),

                (
                    [
                        "兴业银行",
                        "INDUSTRIAL BANK",
                        "CIB"
                    ],
                    "兴业银行"
                ),

                (
                    [
                        "上海浦东发展银行",
                        "浦发银行",
                        "SPDB"
                    ],
                    "浦发银行"
                ),

                (
                    [
                        "中国邮政储蓄银行",
                        "邮储银行",
                        "PSBC"
                    ],
                    "中国邮政储蓄银行"
                ),

                (
                    [
                        "江苏银行",
                        "BANK OF JIANGSU",
                        "JSBC"
                    ],
                    "江苏银行"
                ),

                (
                    [
                        "南京银行",
                        "BANK OF NANJING",
                        "NJCB"
                    ],
                    "南京银行"
                ),

                (
                    [
                        "宁波银行",
                        "BANK OF NINGBO",
                        "NBCB"
                    ],
                    "宁波银行"
                ),

                (
                    [
                        "北京银行",
                        "BANK OF BEIJING",
                        "BOB"
                    ],
                    "北京银行"
                )
            ]


        for item in bankAliases {

            if item.keywords.contains(
                where: {
                    normalized.contains(
                        $0.uppercased()
                    )
                }
            ) {

                return
                    item.name
            }
        }

        return nil
    }


    // MARK: - 卡片类型

    private static func detectCardType(
        in text:
            String
    ) -> BankCardType? {

        let upper =
            text.uppercased()


        let creditKeywords =
            [
                "信用卡",
                "贷记卡",
                "CREDIT"
            ]


        if creditKeywords.contains(
            where: {
                upper.contains(
                    $0
                )
            }
        ) {

            return
                .credit
        }


        let debitKeywords =
            [
                "储蓄卡",
                "借记卡",
                "DEBIT"
            ]


        if debitKeywords.contains(
            where: {
                upper.contains(
                    $0
                )
            }
        ) {

            return
                .debit
        }

        return nil
    }


    // MARK: - 卡号识别

    private static func findBestCardNumber(
        in lines:
            [String]
    ) -> String? {

        var candidates =
            Set<String>()


        // 1. 单行候选：
        //    6217 0000 1234 5678
        //    6217-0000-1234-5678
        for line in lines {

            let normalized =
                normalizePotentialCardNumber(
                    line
                )


            let digits =
                normalized.filter {
                    $0.isNumber
                }


            if isCardNumberLength(
                digits.count
            ) {

                candidates.insert(
                    digits
                )
            }


            for group in digitGroups(
                in:
                    normalized
            ) {

                if isCardNumberLength(
                    group.count
                ) {

                    candidates.insert(
                        group
                    )
                }
            }
        }


        // 2. OCR 经常把银行卡号拆成多行，
        //    例如：
        //    6217
        //    0000
        //    1234
        //    5678
        //
        //    这里尝试把相邻 2~5 行拼接。
        guard !lines.isEmpty
        else {
            return nil
        }


        let normalizedLines =
            lines.map {
                normalizePotentialCardNumber(
                    $0
                )
            }


        for startIndex in normalizedLines.indices {

            var combined =
                ""


            for endIndex in startIndex...min(
                startIndex + 4,
                normalizedLines.count - 1
            ) {

                let piece =
                    normalizedLines[
                        endIndex
                    ]
                    .filter {
                        $0.isNumber
                    }


                // 一行完全没有数字时，
                // 不继续跨越文本区域拼接。
                if piece.isEmpty {

                    if !combined.isEmpty {
                        break
                    }

                    continue
                }


                // 银行卡号常见分组为 3~6 位。
                // 太长的单行大概率是日期/编号等其他信息。
                if piece.count > 8 &&
                   combined.isEmpty {

                    break
                }


                combined +=
                    piece


                if isCardNumberLength(
                    combined.count
                ) {

                    candidates.insert(
                        combined
                    )
                }


                if combined.count >=
                    19 {

                    break
                }
            }
        }


        // 3. 优先选择通过 Luhn 校验的候选。
        let luhnCandidates =
            candidates.filter {
                passesLuhn(
                    $0
                )
            }


        if let best =
            luhnCandidates
                .sorted(
                    by:
                        preferredCardNumber
                )
                .first {

            return best
        }


        // 4. 如果图片质量导致某一位识别错误，
        //    仍然返回最像银行卡号的候选，
        //    但最终只保存后四位，并由用户确认。
        return candidates
            .sorted(
                by:
                    preferredCardNumber
            )
            .first
    }


    private static func isCardNumberLength(
        _ count:
            Int
    ) -> Bool {

        count >= 13 &&
        count <= 19
    }


    private static func digitGroups(
        in text:
            String
    ) -> [String] {

        let pattern =
            #"(?<!\d)(?:\d[\s\-]?){13,19}(?!\d)"#


        guard
            let regex =
                try? NSRegularExpression(
                    pattern:
                        pattern
                )
        else {

            return []
        }


        let range =
            NSRange(
                text.startIndex...,
                in:
                    text
            )


        return regex.matches(
            in:
                text,
            range:
                range
        )
        .compactMap { match in

            guard
                let swiftRange =
                    Range(
                        match.range,
                        in:
                            text
                    )
            else {

                return nil
            }


            let digits =
                text[
                    swiftRange
                ]
                .filter {
                    $0.isNumber
                }


            guard isCardNumberLength(
                digits.count
            )
            else {

                return nil
            }

            return digits
        }
    }


    private static func normalizePotentialCardNumber(
        _ text:
            String
    ) -> String {

        // 只在“数字感很强”的文本中做字符纠错，
        // 避免把普通英文单词误当成卡号。
        let digitCount =
            text.filter {
                $0.isNumber
            }
            .count


        guard digitCount >= 6
        else {

            return text
        }


        var result =
            ""


        for character in text {

            switch character {

            case "O",
                 "o",
                 "Q":

                result.append(
                    "0"
                )

            case "I",
                 "l",
                 "|":

                result.append(
                    "1"
                )

            case "S":

                result.append(
                    "5"
                )

            case "B":

                result.append(
                    "8"
                )

            default:

                result.append(
                    character
                )
            }
        }

        return result
    }


    private static func preferredCardNumber(
        _ lhs:
            String,
        over rhs:
            String
    ) -> Bool {

        let preferredLengths =
            [
                19,
                18,
                16,
                17,
                15,
                14,
                13
            ]


        let leftRank =
            preferredLengths.firstIndex(
                of:
                    lhs.count
            )
            ?? preferredLengths.count


        let rightRank =
            preferredLengths.firstIndex(
                of:
                    rhs.count
            )
            ?? preferredLengths.count


        if leftRank !=
            rightRank {

            return
                leftRank <
                rightRank
        }

        return
            lhs.count >
            rhs.count
    }


    private static func passesLuhn(
        _ number:
            String
    ) -> Bool {

        guard
            number.count >= 13,
            number.count <= 19
        else {
            return false
        }


        var sum =
            0

        var shouldDouble =
            false


        for character in number.reversed() {

            guard
                let digit =
                    character.wholeNumberValue
            else {
                return false
            }


            var value =
                digit


            if shouldDouble {

                value *=
                    2

                if value >
                    9 {

                    value -=
                        9
                }
            }


            sum +=
                value

            shouldDouble.toggle()
        }


        return
            sum % 10 ==
            0
    }


    // MARK: - 图片方向

    private static func cgImageOrientation(
        for orientation:
            UIImage.Orientation
    ) -> CGImagePropertyOrientation {

        switch orientation {

        case .up:

            return .up

        case .upMirrored:

            return .upMirrored

        case .down:

            return .down

        case .downMirrored:

            return .downMirrored

        case .left:

            return .left

        case .leftMirrored:

            return .leftMirrored

        case .right:

            return .right

        case .rightMirrored:

            return .rightMirrored

        @unknown default:

            return .up
        }
    }
}
