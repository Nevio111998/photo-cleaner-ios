import Foundation
import Photos

struct ScanUpdate {
    let records: [PhotoRecord]
    let completed: Int
    let total: Int
    let unavailable: Int
}

actor Scanner {
    func scan(cached: [PhotoRecord], progress: @escaping @Sendable (ScanUpdate) async -> Void) async throws -> [PhotoRecord] {
        let assets = PhotoLibrary.assets()
        let cache = Dictionary(uniqueKeysWithValues: cached.map { ($0.id, $0) })
        var records: [PhotoRecord] = []
        var unavailable = 0
        for (index, asset) in assets.enumerated() {
            try Task.checkCancellation()
            let signature = PhotoLibrary.signature(asset)
            var record = PhotoRecord(id: asset.localIdentifier, signature: signature,
                date: asset.creationDate ?? .distantPast, width: asset.pixelWidth, height: asset.pixelHeight)
            if let old = cache[record.id], old.signature == signature { record = old }
            if record.digest == nil {
                do {
                    let (hash, bytes) = try await PhotoLibrary.digest(asset)
                    record.digest = hash; record.bytes = bytes
                } catch is CancellationError { throw CancellationError() }
                catch { /* Local resource unavailable: retry on next scan. */ }
            }
            try Task.checkCancellation()
            if (record.fingerprint == nil || record.luminance == nil),
               let image = await PhotoLibrary.image(asset, size: CGSize(width: 256, height: 256)),
               let (hash, quality, tones) = ImageAnalysis.analyze(image, pixels: asset.pixelWidth * asset.pixelHeight) {
                record.fingerprint = hash; record.quality = quality; record.luminance = tones
            }
            if record.digest == nil || record.fingerprint == nil { unavailable += 1 }
            records.append(record)
            if index % 25 == 0 || index == assets.count - 1 {
                await progress(ScanUpdate(records: records, completed: index + 1, total: assets.count, unavailable: unavailable))
            }
        }
        return records
    }
}
