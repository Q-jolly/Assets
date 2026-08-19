import Foundation
import Vision
import UIKit
import CoreImage


struct BankCardOCRResult {

    let bankName:
        String?

    let lastFourDigits:
        String?

    let cardType:
        BankCardType?

    let recognizedText:
        String

    let extractedCardImageData:
        Data?

    let usedRectangleDetection:
        Bool
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

        let extraction =
            CardImageProcessor
                .extractCardFace(
                    from:
                        imageData
                )


        guard
            let originalImage =
                UIImage(
                    data:
                        imageData
                )
        else {

            throw RecognitionError
                .invalidImage
        }


        var recognitionImages:
            [UIImage] = []


        // 竖版艺术卡 OCR 必须保留真实方向。
        // 卡包展示用的横向卡面会为了 UI 做旋转/裁切，
        // 不能再拿那个结果作为唯一 OCR 输入。
        if let recognitionData =
            CardImageProcessor
                .extractCardFaceForRecognition(
                    from:
                        imageData
                ),
           let recognitionCardImage =
            UIImage(
                data:
                    recognitionData
            ) {

            recognitionImages.append(
                recognitionCardImage
            )

            recognitionImages.append(
                contentsOf:
                    focusedOCRImages(
                        from:
                            recognitionCardImage
                    )
            )
        }


        // 卡包展示使用的自动提取卡面仍参与普通 OCR。
        if let extractedData =
            extraction?
                .imageData,
           let extractedImage =
            UIImage(
                data:
                    extractedData
            ) {

            recognitionImages.append(
                extractedImage
            )
        }


        // 原图继续作为兜底；同时针对顶部银行名称区域做放大 OCR。
        recognitionImages.append(
            originalImage
        )

        recognitionImages.append(
            contentsOf:
                focusedOCRImages(
                    from:
                        originalImage
                )
        )


        var allObservations:
            [VNRecognizedTextObservation] = []

        var allLines:
            [String] = []


        for image in recognitionImages {

            let result =
                recognizeGeneralText(
                    in:
                        image
                )

            allObservations.append(
                contentsOf:
                    result.observations
            )

            allLines.append(
                contentsOf:
                    result.lines
            )


            // 黑底白字、艺术字体卡面再跑一次高对比度版本。
            if let contrastImage =
                highContrastImage(
                    from:
                        image
                ) {

                let contrastResult =
                    recognizeGeneralText(
                        in:
                            contrastImage
                    )

                allObservations.append(
                    contentsOf:
                        contrastResult
                            .observations
                )

                allLines.append(
                    contentsOf:
                        contrastResult
                            .lines
                )
            }
        }


        let uniqueLines =
            Array(
                Set(
                    allLines
                )
            )


        let fullText =
            uniqueLines.joined(
                separator:
                    "\n"
            )


        let cardNumber =
            findBestCardNumber(
                in:
                    uniqueLines
            )


        var lastFourDigits =
            cardNumber.map {
                String(
                    $0.suffix(4)
                )
            }


        if lastFourDigits ==
            nil {

            lastFourDigits =
                findBestVisibleLastFour(
                    in:
                        allObservations
                )
        }


        // 专门对每个候选图的中下部做数字 OCR。
        if lastFourDigits ==
            nil {

            for image in
                recognitionImages {

                guard
                    let cgImage =
                        normalizedCGImage(
                            from:
                                image
                        )
                else {

                    continue
                }


                if let detected =
                    recognizeVisibleLastFourRegion(
                        in:
                            cgImage
                    ) {

                    lastFourDigits =
                        detected

                    break
                }


                if let contrastImage =
                    highContrastImage(
                        from:
                            image
                    ),
                   let contrastCGImage =
                    normalizedCGImage(
                        from:
                            contrastImage
                    ),
                   let detected =
                    recognizeVisibleLastFourRegion(
                        in:
                            contrastCGImage
                    ) {

                    lastFourDigits =
                        detected

                    break
                }
            }
        }


        let bankName =
            detectBankName(
                in:
                    fullText
            )


        let cardType =
            detectCardType(
                in:
                    fullText
            )


        // 不再因为“通用 OCR 没扫到文字”直接整次失败。
        // 只要银行卡本体成功提取，或者后四位/银行/类型任一识别成功，
        // 都把结果返回给界面。
        // 弱识别模式：
        // 艺术卡、竖版联名卡可能只有卡面，没有标准卡号和可读文字。
        // 只要成功提取出银行卡区域，就允许进入保存流程。
        let hasUsefulResult =
            extraction != nil ||
            bankName != nil ||
            cardType != nil ||
            lastFourDigits != nil ||
            !uniqueLines.isEmpty


        guard hasUsefulResult
        else {

            throw RecognitionError
                .visionFailed
        }


        return BankCardOCRResult(
            bankName:
                bankName,
            lastFourDigits:
                lastFourDigits,
            cardType:
                cardType,
            recognizedText:
                fullText,
            extractedCardImageData:
                extraction?
                    .imageData,
            usedRectangleDetection:
                extraction?
                    .usedRectangleDetection
                ?? false
        )
    }


    // MARK: - 多通道 OCR

    private struct GeneralOCRResult {

        let observations:
            [VNRecognizedTextObservation]

        let lines:
            [String]
    }


    private static func recognizeGeneralText(
        in image:
            UIImage
    ) -> GeneralOCRResult {

        guard
            let cgImage =
                normalizedCGImage(
                    from:
                        image
                )
        else {

            return GeneralOCRResult(
                observations:
                    [],
                lines:
                    []
            )
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
            0.004


        let handler =
            VNImageRequestHandler(
                cgImage:
                    cgImage,
                orientation:
                    .up,
                options:
                    [:]
            )


        do {

            try handler.perform(
                [request]
            )

        } catch {

            return GeneralOCRResult(
                observations:
                    [],
                lines:
                    []
            )
        }


        let observations =
            request.results
            ?? []


        let lines =
            observations.compactMap {
                $0.topCandidates(1)
                    .first?
                    .string
            }


        return GeneralOCRResult(
            observations:
                observations,
            lines:
                lines
        )
    }


    private static func normalizedCGImage(
        from image:
            UIImage
    ) -> CGImage? {

        if image.imageOrientation ==
            .up {

            return image.cgImage
        }


        let renderer =
            UIGraphicsImageRenderer(
                size:
                    image.size
            )


        let normalized =
            renderer.image {
                _ in

                image.draw(
                    in:
                        CGRect(
                            origin:
                                .zero,
                            size:
                                image.size
                        )
                )
            }


        return normalized.cgImage
    }


    // MARK: - 艺术卡局部 OCR

    private static func focusedOCRImages(
        from image:
            UIImage
    ) -> [UIImage] {

        let regions:
            [CGRect] = [

                // 顶部整条：银行名称 + debit / credit 常在这里。
                CGRect(
                    x: 0.00,
                    y: 0.00,
                    width: 1.00,
                    height: 0.34
                ),

                // 左上：银行 Logo / 中英文银行名称。
                CGRect(
                    x: 0.00,
                    y: 0.00,
                    width: 0.72,
                    height: 0.28
                ),

                // 右上：Gold debit / Visa / Mastercard 等小字。
                CGRect(
                    x: 0.48,
                    y: 0.00,
                    width: 0.52,
                    height: 0.32
                )
            ]


        return regions
            .compactMap {
                region in

                cropAndUpscaleForOCR(
                    image,
                    normalizedRect:
                        region
                )
            }
    }


    private static func cropAndUpscaleForOCR(
        _ image:
            UIImage,
        normalizedRect:
            CGRect
    ) -> UIImage? {

        guard
            let cgImage =
                normalizedCGImage(
                    from:
                        image
                )
        else {

            return nil
        }


        let width =
            CGFloat(
                cgImage.width
            )

        let height =
            CGFloat(
                cgImage.height
            )


        var pixelRect =
            CGRect(
                x:
                    normalizedRect.minX *
                    width,
                y:
                    normalizedRect.minY *
                    height,
                width:
                    normalizedRect.width *
                    width,
                height:
                    normalizedRect.height *
                    height
            )
            .integral


        pixelRect =
            pixelRect.intersection(
                CGRect(
                    x: 0,
                    y: 0,
                    width:
                        width,
                    height:
                        height
                )
            )


        guard
            !pixelRect.isNull,
            pixelRect.width >
                8,
            pixelRect.height >
                8,
            let cropped =
                cgImage.cropping(
                    to:
                        pixelRect
                )
        else {

            return nil
        }


        let croppedImage =
            UIImage(
                cgImage:
                    cropped,
                scale: 1,
                orientation:
                    .up
            )


        let targetWidth:
            CGFloat =
                1500

        let scale =
            max(
                1,
                min(
                    4,
                    targetWidth /
                    max(
                        croppedImage.size.width,
                        1
                    )
                )
            )


        guard scale >
            1.01
        else {

            return croppedImage
        }


        let targetSize =
            CGSize(
                width:
                    croppedImage.size.width *
                    scale,
                height:
                    croppedImage.size.height *
                    scale
            )


        let renderer =
            UIGraphicsImageRenderer(
                size:
                    targetSize
            )


        return renderer.image {
            _ in

            croppedImage.draw(
                in:
                    CGRect(
                        origin:
                            .zero,
                        size:
                            targetSize
                    )
            )
        }
    }


    private static func highContrastImage(
        from image:
            UIImage
    ) -> UIImage? {

        guard
            let cgImage =
                normalizedCGImage(
                    from:
                        image
                )
        else {

            return nil
        }


        let input =
            CIImage(
                cgImage:
                    cgImage
            )


        guard
            let filter =
                CIFilter(
                    name:
                        "CIColorControls"
                )
        else {

            return nil
        }


        filter.setValue(
            input,
            forKey:
                kCIInputImageKey
        )

        filter.setValue(
            0.0,
            forKey:
                kCIInputSaturationKey
        )

        filter.setValue(
            1.65,
            forKey:
                kCIInputContrastKey
        )

        filter.setValue(
            0.04,
            forKey:
                kCIInputBrightnessKey
        )


        guard
            let colorOutput =
                filter.outputImage
        else {

            return nil
        }


        let sharpenedOutput:
            CIImage


        if let sharpen =
            CIFilter(
                name:
                    "CISharpenLuminance"
            ) {

            sharpen.setValue(
                colorOutput,
                forKey:
                    kCIInputImageKey
            )

            sharpen.setValue(
                0.70,
                forKey:
                    kCIInputSharpnessKey
            )

            sharpenedOutput =
                sharpen.outputImage ??
                colorOutput

        } else {

            sharpenedOutput =
                colorOutput
        }


        let context =
            CIContext(
                options:
                    [
                        .useSoftwareRenderer:
                            false
                    ]
            )


        guard
            let outputCGImage =
                context.createCGImage(
                    sharpenedOutput,
                    from:
                        sharpenedOutput.extent
                )
        else {

            return nil
        }


        return UIImage(
            cgImage:
                outputCGImage,
            scale:
                1,
            orientation:
                .up
        )
    }


    // MARK: - 银行名称

    private static func detectBankName(
        in text:
            String
    ) -> String? {

        let normalized =
            text.uppercased()

        let compactNormalized =
            compactBankText(
                normalized
            )

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
                        "中國銀行",
                        "BANK OF CHINA",
                        "BANKOFCHINA",
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
                    keyword in

                    let upperKeyword =
                        keyword.uppercased()

                    return
                        normalized.contains(
                            upperKeyword
                        )
                        ||
                        compactNormalized.contains(
                            compactBankText(
                                upperKeyword
                            )
                        )
                }
            ) {

                return
                    item.name
            }
        }

        return nil
    }


    private static func compactBankText(
        _ value:
            String
    ) -> String {

        var result =
            ""


        for scalar in
            value.unicodeScalars {

            if CharacterSet.alphanumerics
                .contains(
                    scalar
                )
                ||
                (
                    scalar.value >=
                        0x4E00
                    &&
                    scalar.value <=
                        0x9FFF
                ) {

                result.unicodeScalars
                    .append(
                        scalar
                    )
            }
        }


        return result
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
                "国际信用卡",
                "全币种国际信用卡",
                "贷记卡",
                "CREDIT CARD",
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


    // MARK: - 可见后四位识别

    private struct LastFourCandidate {

        let digits:
            String

        let score:
            Int
    }


    private static func findBestVisibleLastFour(
        in observations:
            [VNRecognizedTextObservation]
    ) -> String? {

        var candidates:
            [LastFourCandidate] = []


        for observation in observations {

            guard
                let candidate =
                    observation
                        .topCandidates(1)
                        .first
            else {

                continue
            }


            let originalText =
                candidate.string

            let normalizedText =
                normalizePotentialCardNumber(
                    originalText
                )


            for digits in fourDigitGroups(
                in:
                    normalizedText
            ) {

                var score =
                    0


                let upper =
                    originalText
                        .uppercased()


                // 带掩码字符 + 4 位数字，是最可靠的银行卡后四位形式。
                if containsCardMask(
                    originalText
                ) {

                    score +=
                        120
                }


                // 单独一组 4 位数字也很常见。
                if asciiDigits(
                    in:
                        normalizedText
                ) ==
                    digits {

                    score +=
                        35
                }


                // Vision 坐标原点在左下角。
                // 银行卡号后四位大多位于卡面中下部。
                let centerY =
                    observation
                        .boundingBox
                        .midY

                if centerY <
                    0.58 {

                    score +=
                        40
                }


                let centerX =
                    observation
                        .boundingBox
                        .midX

                if centerX <
                    0.78 {

                    score +=
                        15
                }


                // 排除有效期、CVV 等容易误判的数字。
                if upper.contains(
                    "VALID"
                ) ||
                   upper.contains(
                    "THRU"
                ) ||
                   upper.contains(
                    "GOOD THRU"
                ) ||
                   upper.contains(
                    "EXP"
                ) ||
                   upper.contains(
                    "有效期"
                ) ||
                   upper.contains(
                    "CVV"
                ) ||
                   upper.contains(
                    "CVC"
                ) {

                    score -=
                        120
                }


                if originalText.contains(
                    "/"
                ) {

                    score -=
                        90
                }


                if looksLikeYear(
                    digits
                ) {

                    score -=
                        55
                }


                candidates.append(
                    LastFourCandidate(
                        digits:
                            digits,
                        score:
                            score
                    )
                )
            }
        }


        return candidates
            .sorted {
                if $0.score !=
                    $1.score {

                    return
                        $0.score >
                        $1.score
                }

                return
                    $0.digits <
                    $1.digits
            }
            .first {
                $0.score >=
                    20
            }?
            .digits
    }


    private static func recognizeVisibleLastFourRegion(
        in cgImage:
            CGImage
    ) -> String? {

        let request =
            VNRecognizeTextRequest()

        request.recognitionLevel =
            .accurate

        request.usesLanguageCorrection =
            false

        request.recognitionLanguages =
            [
                "en-US"
            ]

        request.minimumTextHeight =
            0.0025


        // 银行卡卡号通常在中下部。
        // 避开顶部银行名和右下角大部分卡组织 Logo，
        // 同时覆盖 Apple Wallet 常见的左下角后四位。
        request.regionOfInterest =
            CGRect(
                x:
                    0.02,
                y:
                    0.02,
                width:
                    0.90,
                height:
                    0.62
            )


        let handler =
            VNImageRequestHandler(
                cgImage:
                    cgImage,
                orientation:
                    .up,
                options:
                    [:]
            )


        do {

            try handler.perform(
                [request]
            )

        } catch {

            return nil
        }


        return findBestVisibleLastFour(
            in:
                request.results
                ?? []
        )
    }


    private static func fourDigitGroups(
        in text:
            String
    ) -> [String] {

        let pattern =
            #"(?<![0-9])[0-9]{4}(?![0-9])"#


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


        return regex
            .matches(
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


                return String(
                    text[
                        swiftRange
                    ]
                )
            }
    }


    private static func containsCardMask(
        _ text:
            String
    ) -> Bool {

        let maskCharacters =
            CharacterSet(
                charactersIn:
                    "•●·*＊xX×••••"
            )


        let maskCount =
            text.unicodeScalars
                .filter {
                    maskCharacters
                        .contains(
                            $0
                        )
                }
                .count


        if maskCount >=
            2 {

            return true
        }


        // 某些 OCR 会把四个圆点识别成普通句点。
        if text.contains(
            "...."
        ) ||
           text.contains(
            "····"
        ) {

            return true
        }


        return false
    }


    private static func looksLikeYear(
        _ digits:
            String
    ) -> Bool {

        guard
            let value =
                Int(
                    digits
                )
        else {

            return false
        }


        return
            value >= 1900 &&
            value <= 2099
    }


    // MARK: - 卡号识别

    private static func findBestCardNumber(
        in lines:
            [String]
    ) -> String? {

        var candidates =
            Set<String>()


        let normalizedLines =
            lines.map {
                normalizePotentialCardNumber(
                    $0
                )
            }


        // 单行完整卡号
        for line in normalizedLines {

            let digits =
                asciiDigits(
                    in:
                        line
                )


            if isCardNumberLength(
                digits.count
            ) {

                candidates.insert(
                    digits
                )
            }


            for group in digitGroups(
                in:
                    line
            ) {

                candidates.insert(
                    group
                )
            }
        }


        // OCR 可能把 16/19 位卡号拆成多行，
        // 尝试合并相邻 2~5 行。
        if !normalizedLines.isEmpty {

            for startIndex in
                normalizedLines.indices {

                var combined =
                    ""


                let lastIndex =
                    min(
                        startIndex + 4,
                        normalizedLines.count - 1
                    )


                for endIndex in
                    startIndex...lastIndex {

                    let piece =
                        asciiDigits(
                            in:
                                normalizedLines[
                                    endIndex
                                ]
                        )


                    if piece.isEmpty {

                        if !combined.isEmpty {
                            break
                        }

                        continue
                    }


                    // 单个 OCR 行太长通常不是银行卡分组
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
        }


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


        // 没通过 Luhn 时仍允许返回最合理的候选，
        // 但所有候选都已经保证只含 ASCII 数字。
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


    private static func asciiDigits(
        in text:
            String
    ) -> String {

        var result =
            ""


        for scalar in
            text.unicodeScalars {

            if scalar.value >= 48 &&
               scalar.value <= 57 {

                result.unicodeScalars
                    .append(
                        scalar
                    )
            }
        }

        return result
    }


    private static func digitGroups(
        in text:
            String
    ) -> [String] {

        let pattern =
            #"(?<![0-9])(?:[0-9][\s\-]?){13,19}(?![0-9])"#


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
                asciiDigits(
                    in:
                        String(
                            text[
                                swiftRange
                            ]
                        )
                )


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

        let asciiDigitCount =
            asciiDigits(
                in:
                    text
            )
            .count


        // 普通文本不做字母→数字纠错，避免误伤。
        // 但银行卡掩码行（•••• 581S）经常只有 3 个数字，
        // 这时也允许把 S/O/I/B 等常见 OCR 错字纠正回来。
        let mayBeMaskedCardNumber =
            containsCardMask(
                text
            ) &&
            asciiDigitCount >= 2


        guard
            asciiDigitCount >= 4 ||
            mayBeMaskedCardNumber
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



    // MARK: - 竖版银行卡辅助旋转

    private static func rotateImage(
        _ image: UIImage,
        degrees: CGFloat
    ) -> UIImage? {

        let radians = degrees * .pi / 180

        let newSize =
            image.size.applying(
                CGAffineTransform(rotationAngle: radians)
            )

        let renderer =
            UIGraphicsImageRenderer(
                size:
                    CGSize(
                        width: abs(newSize.width),
                        height: abs(newSize.height)
                    )
            )

        return renderer.image { context in
            context.cgContext.translateBy(
                x: abs(newSize.width) / 2,
                y: abs(newSize.height) / 2
            )
            context.cgContext.rotate(by: radians)
            image.draw(
                at:
                    CGPoint(
                        x: -image.size.width / 2,
                        y: -image.size.height / 2
                    )
            )
        }
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
