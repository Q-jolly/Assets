import Foundation
import UIKit


enum CardFaceSide:
    String {

    case front
    case back
}


enum CardFaceImageStore {

    static let didChangeNotification =
        Notification.Name(
            "QLAssets.CardFaceImageDidChange"
        )


    private static var directoryURL:
        URL {

        let base =
            FileManager.default.urls(
                for:
                    .applicationSupportDirectory,
                in:
                    .userDomainMask
            )
            .first
            ?? FileManager.default
                .temporaryDirectory

        return base
            .appendingPathComponent(
                "QLAssets",
                isDirectory:
                    true
            )
            .appendingPathComponent(
                "CardFaces",
                isDirectory:
                    true
            )
    }


    private static func fileURL(
        for cardID:
            UUID,
        side:
            CardFaceSide
    ) -> URL {

        let filename =
            side ==
                .front
            ? cardID.uuidString
            : cardID.uuidString +
                "-back"


        return directoryURL
            .appendingPathComponent(
                filename
            )
            .appendingPathExtension(
                "jpg"
            )
    }


    static func save(
        imageData:
            Data,
        for cardID:
            UUID,
        side:
            CardFaceSide = .front
    ) throws {

        guard
            let image =
                UIImage(
                    data:
                        imageData
                )
        else {

            throw CocoaError(
                .fileReadCorruptFile
            )
        }


        let processed =
            resizedImage(
                image,
                maxDimension:
                    1600
            )


        guard
            let jpegData =
                processed.jpegData(
                    compressionQuality:
                        0.86
                )
        else {

            throw CocoaError(
                .fileWriteUnknown
            )
        }


        try FileManager.default
            .createDirectory(
                at:
                    directoryURL,
                withIntermediateDirectories:
                    true
            )


        try jpegData.write(
            to:
                fileURL(
                    for:
                        cardID,
                    side:
                        side
                ),
            options:
                .atomic
        )


        postChange(
            cardID:
                cardID
        )
    }


    static func image(
        for cardID:
            UUID,
        side:
            CardFaceSide = .front
    ) -> UIImage? {

        guard
            let data =
                try? Data(
                    contentsOf:
                        fileURL(
                            for:
                                cardID,
                            side:
                                side
                        )
                )
        else {

            return nil
        }


        return UIImage(
            data:
                data
        )
    }


    static func imageData(
        for cardID:
            UUID,
        side:
            CardFaceSide = .front
    ) -> Data? {

        try? Data(
            contentsOf:
                fileURL(
                    for:
                        cardID,
                    side:
                        side
                )
        )
    }


    static func exists(
        for cardID:
            UUID,
        side:
            CardFaceSide = .front
    ) -> Bool {

        FileManager.default
            .fileExists(
                atPath:
                    fileURL(
                        for:
                            cardID,
                        side:
                            side
                    )
                    .path
            )
    }


    static func delete(
        for cardID:
            UUID,
        side:
            CardFaceSide = .front
    ) {

        let url =
            fileURL(
                for:
                    cardID,
                side:
                    side
            )


        if FileManager.default
            .fileExists(
                atPath:
                    url.path
            ) {

            try?
                FileManager.default
                    .removeItem(
                        at:
                            url
                    )
        }


        postChange(
            cardID:
                cardID
        )
    }


    static func deleteAll(
        for cardID:
            UUID
    ) {

        for side in
            [
                CardFaceSide.front,
                CardFaceSide.back
            ] {

            let url =
                fileURL(
                    for:
                        cardID,
                    side:
                        side
                )


            if FileManager.default
                .fileExists(
                    atPath:
                        url.path
                ) {

                try?
                    FileManager.default
                        .removeItem(
                            at:
                                url
                        )
            }
        }


        postChange(
            cardID:
                cardID
        )
    }


    private static func postChange(
        cardID:
            UUID
    ) {

        NotificationCenter.default
            .post(
                name:
                    didChangeNotification,
                object:
                    cardID.uuidString
            )
    }


    private static func resizedImage(
        _ image:
            UIImage,
        maxDimension:
            CGFloat
    ) -> UIImage {

        let size =
            image.size

        let longest =
            max(
                size.width,
                size.height
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
                    size.width *
                    scale,
                height:
                    size.height *
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
