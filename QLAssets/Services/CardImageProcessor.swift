import Foundation
import Vision
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins


struct CardImageExtractionResult {

    let imageData:
        Data

    let usedRectangleDetection:
        Bool
}


enum CardImageProcessor {

    private static let bankCardAspectRatio:
        CGFloat =
            85.60 /
            53.98


    static func extractCardFace(
        from imageData:
            Data
    ) -> CardImageExtractionResult? {

        guard
            let sourceImage =
                UIImage(
                    data:
                        imageData
                )
        else {

            return nil
        }


        let normalizedImage =
            normalizeOrientation(
                sourceImage
            )


        if let detectedImage =
            detectAndCorrectCard(
                from:
                    normalizedImage,
                // 保存识别结果时保留卡片原始横竖方向。
                // 竖版艺术卡不能为了卡包横版布局而提前旋转、裁切，
                // 否则人物和卡面主体会在保存前就丢失。
                normalizeToLandscape:
                    false
            ),
           let data =
            jpegData(
                from:
                    detectedImage
            ) {

            return CardImageExtractionResult(
                imageData:
                    data,
                usedRectangleDetection:
                    true
            )
        }


        // Apple Wallet / 银行 App 截图中的银行卡通常是
        // 一个位于屏幕上半部的大型横向卡片。
        //
        // Vision 对圆角卡片偶尔无法返回矩形，此时不要再直接
        // 对整张竖屏截图做中心裁切，否则很容易裁到大片灰色背景。
        if let screenshotCard =
            detectCardInPortraitScreenshot(
                normalizedImage
            ),
           let data =
            jpegData(
                from:
                    screenshotCard
            ) {

            return CardImageExtractionResult(
                imageData:
                    data,
                usedRectangleDetection:
                    false
            )
        }


        guard
            let fallbackImage =
                centerCropToCardRatio(
                    normalizedImage
                ),
            let data =
                jpegData(
                    from:
                        fallbackImage
                )
        else {

            return nil
        }


        return CardImageExtractionResult(
            imageData:
                data,
            usedRectangleDetection:
                false
        )
    }


    // OCR 专用：保留银行卡在照片中的真实横竖方向。
    // 竖版艺术卡如果先强制旋转并裁成横卡，会把银行名称和
    // “debit / credit”等小字切掉，导致识别失败。
    static func extractCardFaceForRecognition(
        from imageData:
            Data
    ) -> Data? {

        guard
            let sourceImage =
                UIImage(
                    data:
                        imageData
                )
        else {

            return nil
        }


        let normalizedImage =
            normalizeOrientation(
                sourceImage
            )


        guard
            let detectedImage =
                detectAndCorrectCard(
                    from:
                        normalizedImage,
                    normalizeToLandscape:
                        false
                )
        else {

            return nil
        }


        return jpegData(
            from:
                detectedImage
        )
    }


    // MARK: - 银行卡矩形检测

    private static func detectAndCorrectCard(
        from image:
            UIImage,
        normalizeToLandscape:
            Bool
    ) -> UIImage? {

        guard
            let cgImage =
                image.cgImage
        else {

            return nil
        }


        let request =
            VNDetectRectanglesRequest()

        request.maximumObservations =
            12

        request.minimumConfidence =
            0.20

        request.minimumSize =
            0.14

        // Vision 的 aspectRatio 定义为“短边 / 长边”。
        // 银行卡 85.60:53.98 的对应值约为 0.63。
        request.minimumAspectRatio =
            0.52

        request.maximumAspectRatio =
            0.76

        request.quadratureTolerance =
            45


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


        guard
            let observations =
                request.results,
            !observations.isEmpty
        else {

            return nil
        }


        guard
            let best =
                observations.min(
                    by: {
                        rectangleScore(
                            $0
                        ) <
                        rectangleScore(
                            $1
                        )
                    }
                )
        else {

            return nil
        }


        return perspectiveCorrect(
            cgImage:
                cgImage,
            observation:
                best,
            normalizeToLandscape:
                normalizeToLandscape
        )
    }


    private static func rectangleScore(
        _ observation:
            VNRectangleObservation
    ) -> CGFloat {

        let width =
            observation.boundingBox
                .width

        let height =
            observation.boundingBox
                .height


        guard
            width > 0,
            height > 0
        else {

            return
                .greatestFiniteMagnitude
        }


        let ratio =
            max(
                width,
                height
            ) /
            min(
                width,
                height
            )


        let ratioPenalty =
            abs(
                ratio -
                bankCardAspectRatio
            )


        let area =
            width *
            height


        // 更像银行卡比例、面积更大的矩形优先
        return
            ratioPenalty +
            (
                1 -
                area
            ) *
            0.30
    }


    private static func perspectiveCorrect(
        cgImage:
            CGImage,
        observation:
            VNRectangleObservation,
        normalizeToLandscape:
            Bool
    ) -> UIImage? {

        let ciImage =
            CIImage(
                cgImage:
                    cgImage
            )


        let width =
            ciImage.extent
                .width

        let height =
            ciImage.extent
                .height


        func point(
            _ normalized:
                CGPoint
        ) -> CGPoint {

            CGPoint(
                x:
                    normalized.x *
                    width,
                y:
                    normalized.y *
                    height
            )
        }


        let filter =
            CIFilter
                .perspectiveCorrection()

        filter.inputImage =
            ciImage

        filter.topLeft =
            point(
                observation.topLeft
            )

        filter.topRight =
            point(
                observation.topRight
            )

        filter.bottomLeft =
            point(
                observation.bottomLeft
            )

        filter.bottomRight =
            point(
                observation.bottomRight
            )


        guard
            let output =
                filter.outputImage
        else {

            return nil
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
            let correctedCGImage =
                context.createCGImage(
                    output,
                    from:
                        output.extent
                )
        else {

            return nil
        }


        var result =
            UIImage(
                cgImage:
                    correctedCGImage,
                scale:
                    1,
                orientation:
                    .up
            )


        guard normalizeToLandscape
        else {

            // OCR 要看到完整的竖版卡面，不做横向旋转和二次裁切。
            return result
        }


        // 卡包 UI 仍沿用横向银行卡卡面，因此原有展示逻辑不变。
        if result.size.height >
            result.size.width {

            result =
                rotate90Degrees(
                    result
                )
        }


        return centerCropToCardRatio(
            result
        )
    }


    // MARK: - 竖屏截图银行卡检测

    private struct ScreenshotCardCandidate {

        let rect:
            CGRect

        let score:
            Double
    }


    private static func detectCardInPortraitScreenshot(
        _ image:
            UIImage
    ) -> UIImage? {

        guard
            let cgImage =
                image.cgImage
        else {

            return nil
        }


        let sourceWidth =
            cgImage.width

        let sourceHeight =
            cgImage.height


        guard
            sourceWidth > 0,
            sourceHeight > 0
        else {

            return nil
        }


        let sourceRatio =
            Double(
                sourceHeight
            ) /
            Double(
                sourceWidth
            )


        // 只对明显的竖屏图使用这个启发式。
        // 普通银行卡近景照片仍然优先交给 Vision 矩形检测。
        guard sourceRatio >=
                1.25
        else {

            return nil
        }


        let sampleWidth =
            180

        let sampleHeight =
            max(
                180,
                Int(
                    Double(
                        sourceHeight
                    ) /
                    Double(
                        sourceWidth
                    ) *
                    Double(
                        sampleWidth
                    )
                )
            )


        guard
            let grayscale =
                makeGrayscaleSample(
                    from:
                        cgImage,
                    width:
                        sampleWidth,
                    height:
                        sampleHeight
                )
        else {

            return nil
        }


        // 同时尝试横版和竖版比例。银行 App/钱包截图里的艺术卡
        // 经常是竖版，不能只按普通银行卡横版比例搜索。
        let cardRatios =
            [
                Double(
                    bankCardAspectRatio
                ),
                1 /
                Double(
                    bankCardAspectRatio
                )
            ]


        var bestCandidate:
            ScreenshotCardCandidate?


        // Wallet / 银行 App 的横版卡片通常宽度占屏幕 72%~96%；
        // 竖版艺术卡宽度通常更窄，扩大到 45%~84%。
        for cardRatio in cardRatios {

            let minimumWidthPercent =
                cardRatio < 1
                ? 45
                : 72

            let maximumWidthPercent =
                cardRatio < 1
                ? 84
                : 96

            for widthPercent in
                stride(
                    from:
                        minimumWidthPercent,
                    through:
                        maximumWidthPercent,
                    by:
                        2
                ) {

            let candidateWidth =
                max(
                    40,
                    Int(
                        Double(
                            sampleWidth
                        ) *
                        Double(
                            widthPercent
                        ) /
                        100.0
                    )
                )


            let candidateHeight =
                max(
                    24,
                    Int(
                        Double(
                            candidateWidth
                        ) /
                        cardRatio
                    )
                )


            guard
                candidateHeight <
                    sampleHeight
            else {

                continue
            }


            // 卡片通常基本居中，但允许轻微左右偏移。
            for centerPercent in
                stride(
                    from:
                        46,
                    through:
                        54,
                    by:
                        2
                ) {

                let centerX =
                    Int(
                        Double(
                            sampleWidth
                        ) *
                        Double(
                            centerPercent
                        ) /
                        100.0
                    )


                let x =
                    centerX -
                    candidateWidth /
                    2


                guard
                    x >= 3,
                    x +
                    candidateWidth +
                    3 <
                    sampleWidth
                else {

                    continue
                }


                for topPercent in
                    stride(
                        from:
                            6,
                        through:
                            45,
                        by:
                            1
                    ) {

                    let y =
                        Int(
                            Double(
                                sampleHeight
                            ) *
                            Double(
                                topPercent
                            ) /
                            100.0
                        )


                    guard
                        y >= 3,
                        y +
                        candidateHeight +
                        3 <
                        sampleHeight
                    else {

                        continue
                    }


                    let rect =
                        CGRect(
                            x:
                                x,
                            y:
                                y,
                            width:
                                candidateWidth,
                            height:
                                candidateHeight
                        )


                    let score =
                        screenshotCardEdgeScore(
                            pixels:
                                grayscale,
                            width:
                                sampleWidth,
                            height:
                                sampleHeight,
                            rect:
                                rect
                        )


                    guard
                        score >
                            0
                    else {

                        continue
                    }


                    if bestCandidate ==
                        nil ||
                       score >
                        (
                            bestCandidate?
                                .score
                            ?? 0
                        ) {

                        bestCandidate =
                            ScreenshotCardCandidate(
                                rect:
                                    rect,
                                score:
                                    score
                            )
                    }
                }
            }
        }
        }


        guard
            let bestCandidate,
            // 防止在普通竖图里把随机 UI 元素当成卡片。
            bestCandidate.score >=
                14.0
        else {

            return nil
        }


        let scaleX =
            Double(
                sourceWidth
            ) /
            Double(
                sampleWidth
            )

        let scaleY =
            Double(
                sourceHeight
            ) /
            Double(
                sampleHeight
            )


        let sourceRect =
            CGRect(
                x:
                    bestCandidate
                        .rect
                        .origin
                        .x *
                    scaleX,
                y:
                    bestCandidate
                        .rect
                        .origin
                        .y *
                    scaleY,
                width:
                    bestCandidate
                        .rect
                        .width *
                    scaleX,
                height:
                    bestCandidate
                        .rect
                        .height *
                    scaleY
            )
            .integral
            .intersection(
                CGRect(
                    x:
                        0,
                    y:
                        0,
                    width:
                        sourceWidth,
                    height:
                        sourceHeight
                )
            )


        guard
            sourceRect.width >
                10,
            sourceRect.height >
                10,
            let cropped =
                cgImage.cropping(
                    to:
                        sourceRect
                )
        else {

            return nil
        }


        return UIImage(
            cgImage:
                cropped,
            scale:
                image.scale,
            orientation:
                .up
        )
    }


    private static func screenshotCardEdgeScore(
        pixels:
            [UInt8],
        width:
            Int,
        height:
            Int,
        rect:
            CGRect
    ) -> Double {

        let x =
            Int(
                rect.origin.x
            )

        let y =
            Int(
                rect.origin.y
            )

        let w =
            Int(
                rect.width
            )

        let h =
            Int(
                rect.height
            )


        guard
            w > 20,
            h > 12
        else {

            return 0
        }


        let insetX =
            max(
                4,
                Int(
                    Double(
                        w
                    ) *
                    0.10
                )
            )

        let insetY =
            max(
                3,
                Int(
                    Double(
                        h
                    ) *
                    0.10
                )
            )


        let edgeGap =
            2


        var edgeTotal =
            0.0

        var edgeCount =
            0


        func value(
            _ px:
                Int,
            _ py:
                Int
        ) -> Int {

            guard
                px >= 0,
                px < width,
                py >= 0,
                py < height
            else {

                return 0
            }

            return Int(
                pixels[
                    py *
                    width +
                    px
                ]
            )
        }


        // 上、下边缘
        if y -
            edgeGap >= 0,
           y +
            edgeGap < height,
           y +
            h -
            edgeGap >= 0,
           y +
            h +
            edgeGap < height {

            for px in stride(
                from:
                    x +
                    insetX,
                to:
                    x +
                    w -
                    insetX,
                by:
                    2
            ) {

                edgeTotal +=
                    Double(
                        abs(
                            value(
                                px,
                                y +
                                edgeGap
                            ) -
                            value(
                                px,
                                y -
                                edgeGap
                            )
                        )
                    )

                edgeCount +=
                    1


                edgeTotal +=
                    Double(
                        abs(
                            value(
                                px,
                                y +
                                h -
                                edgeGap
                            ) -
                            value(
                                px,
                                y +
                                h +
                                edgeGap
                            )
                        )
                    )

                edgeCount +=
                    1
            }
        }


        // 左、右边缘
        if x -
            edgeGap >= 0,
           x +
            edgeGap < width,
           x +
            w -
            edgeGap >= 0,
           x +
            w +
            edgeGap < width {

            for py in stride(
                from:
                    y +
                    insetY,
                to:
                    y +
                    h -
                    insetY,
                by:
                    2
            ) {

                edgeTotal +=
                    Double(
                        abs(
                            value(
                                x +
                                edgeGap,
                                py
                            ) -
                            value(
                                x -
                                edgeGap,
                                py
                            )
                        )
                    )

                edgeCount +=
                    1


                edgeTotal +=
                    Double(
                        abs(
                            value(
                                x +
                                w -
                                edgeGap,
                                py
                            ) -
                            value(
                                x +
                                w +
                                edgeGap,
                                py
                            )
                        )
                    )

                edgeCount +=
                    1
            }
        }


        guard edgeCount >
                0
        else {

            return 0
        }


        let edgeScore =
            edgeTotal /
            Double(
                edgeCount
            )


        // 少量奖励卡片内部有纹理/图案。
        // 权重很低，纯色银行卡也不会因此被排除。
        var sampleValues:
            [Double] = []


        for py in stride(
            from:
                y +
                insetY,
            to:
                y +
                h -
                insetY,
            by:
                max(
                    3,
                    h /
                    12
                )
        ) {

            for px in stride(
                from:
                    x +
                    insetX,
                to:
                    x +
                    w -
                    insetX,
                by:
                    max(
                        3,
                        w /
                        18
                    )
            ) {

                sampleValues.append(
                    Double(
                        value(
                            px,
                            py
                        )
                    )
                )
            }
        }


        var textureBonus =
            0.0


        if sampleValues.count >
            1 {

            let mean =
                sampleValues.reduce(
                    0,
                    +
                ) /
                Double(
                    sampleValues.count
                )


            let variance =
                sampleValues.reduce(
                    0
                ) {
                    partial,
                    current in

                    let difference =
                        current -
                        mean

                    return
                        partial +
                        difference *
                        difference
                } /
                Double(
                    sampleValues.count
                )


            textureBonus =
                sqrt(
                    variance
                ) *
                0.08
        }


        return
            edgeScore +
            textureBonus
    }


    private static func makeGrayscaleSample(
        from cgImage:
            CGImage,
        width:
            Int,
        height:
            Int
    ) -> [UInt8]? {

        guard
            width > 0,
            height > 0
        else {

            return nil
        }


        var pixels =
            [UInt8](
                repeating:
                    0,
                count:
                    width *
                    height
            )


        guard
            let context =
                CGContext(
                    data:
                        &pixels,
                    width:
                        width,
                    height:
                        height,
                    bitsPerComponent:
                        8,
                    bytesPerRow:
                        width,
                    space:
                        CGColorSpaceCreateDeviceGray(),
                    bitmapInfo:
                        CGImageAlphaInfo
                            .none
                            .rawValue
                )
        else {

            return nil
        }


        // CGContext 默认坐标原点在左下角。
        // 翻转后让像素数组和 UIImage / 截图一样从左上角开始。
        context.translateBy(
            x:
                0,
            y:
                CGFloat(
                    height
                )
        )

        context.scaleBy(
            x:
                1,
            y:
                -1
        )


        context.interpolationQuality =
            .medium


        context.draw(
            cgImage,
            in:
                CGRect(
                    x:
                        0,
                    y:
                        0,
                    width:
                        width,
                    height:
                        height
                )
        )


        return pixels
    }


    // MARK: - 兜底裁切

    private static func centerCropToCardRatio(
        _ image:
            UIImage
    ) -> UIImage? {

        guard
            let cgImage =
                image.cgImage
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


        guard
            width > 0,
            height > 0
        else {

            return nil
        }


        let currentRatio =
            width /
            height

        // 根据原图方向选择目标比例：横版银行卡保持 85.60:53.98，
        // 竖版艺术卡使用反向比例，避免兜底裁切把卡面上下截掉。
        let targetRatio =
            width >= height
            ? bankCardAspectRatio
            : 1 / bankCardAspectRatio


        var cropRect:
            CGRect


        if currentRatio >
            targetRatio {

            let targetWidth =
                height *
                targetRatio

            cropRect =
                CGRect(
                    x:
                        (
                            width -
                            targetWidth
                        ) /
                        2,
                    y:
                        0,
                    width:
                        targetWidth,
                    height:
                        height
                )

        } else {

            let targetHeight =
                width /
                targetRatio

            cropRect =
                CGRect(
                    x:
                        0,
                    y:
                        (
                            height -
                            targetHeight
                        ) /
                        2,
                    width:
                        width,
                    height:
                        targetHeight
                )
        }


        let integralRect =
            cropRect.integral
                .intersection(
                    CGRect(
                        x:
                            0,
                        y:
                            0,
                        width:
                            width,
                        height:
                            height
                    )
                )


        guard
            integralRect.width > 1,
            integralRect.height > 1,
            let cropped =
                cgImage.cropping(
                    to:
                        integralRect
                )
        else {

            return nil
        }


        return UIImage(
            cgImage:
                cropped,
            scale:
                image.scale,
            orientation:
                .up
        )
    }


    // MARK: - 图片标准化

    private static func normalizeOrientation(
        _ image:
            UIImage
    ) -> UIImage {

        guard
            image.imageOrientation !=
                .up
        else {

            return image
        }


        let renderer =
            UIGraphicsImageRenderer(
                size:
                    image.size
            )


        return renderer.image {
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
    }


    private static func rotate90Degrees(
        _ image:
            UIImage
    ) -> UIImage {

        let targetSize =
            CGSize(
                width:
                    image.size.height,
                height:
                    image.size.width
            )


        let renderer =
            UIGraphicsImageRenderer(
                size:
                    targetSize
            )


        return renderer.image {
            context in

            let cg =
                context.cgContext

            cg.translateBy(
                x:
                    targetSize.width /
                    2,
                y:
                    targetSize.height /
                    2
            )

            cg.rotate(
                by:
                    .pi /
                    2
            )

            image.draw(
                in:
                    CGRect(
                        x:
                            -image.size.width /
                            2,
                        y:
                            -image.size.height /
                            2,
                        width:
                            image.size.width,
                        height:
                            image.size.height
                    )
            )
        }
    }


    private static func jpegData(
        from image:
            UIImage
    ) -> Data? {

        let resized =
            resizedImage(
                image,
                maxDimension:
                    1800
            )


        return resized.jpegData(
            compressionQuality:
                0.90
        )
    }


    private static func resizedImage(
        _ image:
            UIImage,
        maxDimension:
            CGFloat
    ) -> UIImage {

        let longest =
            max(
                image.size.width,
                image.size.height
            )


        guard
            longest >
            maxDimension,
            longest >
            0
        else {

            return image
        }


        let scale =
            maxDimension /
            longest


        let targetSize =
            CGSize(
                width:
                    image.size.width *
                    scale,
                height:
                    image.size.height *
                    scale
            )


        let renderer =
            UIGraphicsImageRenderer(
                size:
                    targetSize
            )


        return renderer.image {
            _ in

            image.draw(
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
}
