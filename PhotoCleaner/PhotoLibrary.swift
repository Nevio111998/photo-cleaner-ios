import Photos
import UIKit
import CryptoKit

// PhotoKit streams one resource at a time. The lock protects callback-owned state.
private final class DigestAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var hasher = SHA256()
    private var count: Int64 = 0
    func append(_ data: Data) { lock.lock(); defer { lock.unlock() }; hasher.update(data: data); count += Int64(data.count) }
    func result() -> (String, Int64) {
        lock.lock(); defer { lock.unlock() }
        return (hasher.finalize().map { String(format: "%02x", $0) }.joined(), count)
    }
}

enum PhotoLibrary {
    static func assets() -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }
    static func asset(_ id: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
    }
    static func signature(_ asset: PHAsset) -> String {
        "\(asset.modificationDate?.timeIntervalSince1970 ?? 0):\(asset.pixelWidth):\(asset.pixelHeight):\(asset.mediaSubtypes.rawValue)"
    }
    static func image(_ asset: PHAsset, size: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            PHImageManager.default().requestImage(for: asset, targetSize: size,
                contentMode: .aspectFit, options: options) { image, info in
                if (info?[PHImageResultIsDegradedKey] as? Bool) == true { return }
                continuation.resume(returning: image)
            }
        }
    }
    static func digest(_ asset: PHAsset) async throws -> (String, Int64) {
        let resources = PHAssetResource.assetResources(for: asset)
        guard !resources.isEmpty else { throw CocoaError(.fileReadUnknown) }
        var components: [String] = []
        var total: Int64 = 0
        for resource in resources {
            try Task.checkCancellation()
            let accumulator = DigestAccumulator()
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let options = PHAssetResourceRequestOptions()
                options.isNetworkAccessAllowed = true
                PHAssetResourceManager.default().requestData(for: resource, options: options,
                    dataReceivedHandler: { accumulator.append($0) }, completionHandler: { error in
                        if let error { continuation.resume(throwing: error) }
                        else { continuation.resume() }
                    })
            }
            let (hash, bytes) = accumulator.result()
            components.append("\(resource.type.rawValue):\(bytes):\(hash)")
            total += bytes
        }
        let data = Data(components.sorted().joined(separator: "|").utf8)
        return (SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), total)
    }
    // This is the sole library mutation entry point, called only by the review confirmation.
    static func delete(confirmedIDs: [String]) async throws {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: confirmedIDs, options: nil)
        guard assets.count == confirmedIDs.count else { throw CocoaError(.fileNoSuchFile) }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets)
        }
    }
}

enum ImageAnalysis {
    private static func gray(_ image: CGImage, width: Int, height: Int) -> [UInt8]? {
        var pixels = [UInt8](repeating: 0, count: width * height)
        let succeeded = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
            return true
        }
        return succeeded ? pixels : nil
    }
    static func analyze(_ image: UIImage, pixels: Int) -> (UInt64, Double, [UInt8], String)? {
        // Render UIKit orientation before deriving the fingerprint.
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let normalized = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256), format: format)
            .image { _ in image.draw(in: CGRect(x: 0, y: 0, width: 256, height: 256)) }
        guard let cg = normalized.cgImage,
              let small = gray(cg, width: 9, height: 8),
              let tones = gray(cg, width: 8, height: 8),
              let detail = gray(cg, width: 64, height: 64) else { return nil }
        var hash: UInt64 = 0
        for y in 0..<8 { for x in 0..<8 {
            if small[y * 9 + x] > small[y * 9 + x + 1] { hash |= UInt64(1) << (y * 8 + x) }
        } }
        var sharpness = 0.0
        var clipped = 0.0
        for y in 1..<63 { for x in 1..<63 {
            let index = y * 64 + x
            let laplacian = 4 * Double(detail[index]) - Double(detail[index-1]) - Double(detail[index+1])
                - Double(detail[index-64]) - Double(detail[index+64])
            sharpness += laplacian * laplacian
            if detail[index] < 8 || detail[index] > 247 { clipped += 1 }
        } }
        let quality = log1p(sharpness / 3844) + 0.2 * log1p(Double(pixels) / 1_000_000) - clipped / 3844
        let previewDigest = SHA256.hash(data: Data(detail)).map { String(format: "%02x", $0) }.joined()
        return (hash, quality, tones, previewDigest)
    }
}
