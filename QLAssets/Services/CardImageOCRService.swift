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

        try await Task.detached(
            priority:
                .userInitiated
        ) {

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
        .value
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

        var candidates:
            [String] = []


        for line in lines {

            let digits =
                line.filter {
                    $0.isNumber
                }


            if digits.count >= 13 &&
               digits.count <= 19 {

                candidates.append(
                    digits
                )
            }


            let pattern =
                #"(?<!\d)(?:\d[\s\-]?){13,19}(?!\d)"#


            guard
                let regex =
                    try? NSRegularExpression(
                        pattern:
                            pattern
                    )
            else {
                continue
            }


            let nsRange =
                NSRange(
                    line.startIndex...,
                    in:
                        line
                )


            for match in regex.matches(
                in:
                    line,
                range:
                    nsRange
            ) {

                guard
                    let range =
                        Range(
                            match.range,
                            in:
                                line
                        )
                else {
                    continue
                }


                let candidate =
                    line[range]
                        .filter {
                            $0.isNumber
                        }


                if candidate.count >= 13 &&
                   candidate.count <= 19 {

                    candidates.append(
                        String(
                            candidate
                        )
                    )
                }
            }
        }


        let uniqueCandidates =
            Array(
                Set(
                    candidates
                )
            )


        if let luhnCandidate =
            uniqueCandidates
                .filter({
                    passesLuhn(
                        $0
                    )
                })
                .sorted(
                    by: {
                        preferredCardNumber(
                            $0,
                            over:
                                $1
                        )
                    }
                )
                .first {

            return
                luhnCandidate
        }


        return uniqueCandidates
            .sorted(
                by: {
                    preferredCardNumber(
                        $0,
                        over:
                            $1
                    )
                }
            )
            .first
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
