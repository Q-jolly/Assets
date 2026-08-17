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
                    normalizedImage
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


    // MARK: - 银行卡矩形检测

    private static func detectAndCorrectCard(
        from image:
            UIImage
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
            6

        request.minimumConfidence =
            0.45

        request.minimumSize =
            0.16

        request.minimumAspectRatio =
            0.45

        request.maximumAspectRatio =
            1.0

        request.quadratureTolerance =
            35


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
                best
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
            VNRectangleObservation
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


        // 如果透视矫正结果是竖向的，
        // 自动旋转成银行卡常见的横向卡面。
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


        var cropRect:
            CGRect


        if currentRatio >
            bankCardAspectRatio {

            let targetWidth =
                height *
                bankCardAspectRatio

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
                bankCardAspectRatio

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
