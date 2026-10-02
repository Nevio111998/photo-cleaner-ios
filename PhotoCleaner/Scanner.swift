import Foundation
import Photos

struct ScanUpdate {
    let records: [PhotoRecord]
    let completed: Int
    let total: Int
    let unavailable: Int
    let status: String
}

actor Scanner {
    func scan(cached: [PhotoRecord], progress: @escaping @Sendable (ScanUpdate) async -> Void) async throws -> [PhotoRecord] {
        let assets = PhotoLibrary.assets()
        let cache = Dictionary(uniqueKeysWithValues: cached.map { ($0.id, $0) })

        var records: [PhotoRecord] = []
        records.reserveCapacity(assets.count)

        var unavailableIDs = Set<String>()

        // Phase 1: Every photo gets a small 256px representation. This is enough for
        // similarity analysis and for a mathematically safe prefilter for byte-identical
        // duplicates. iCloud only needs to deliver a small rendition here.
        for (index, asset) in assets.enumerated() {
            try Task.checkCancellation()

            let signature = PhotoLibrary.signature(asset)
            var record = PhotoRecord(
                id: asset.localIdentifier,
                signature: signature,
                date: asset.creationDate ?? .distantPast,
                width: asset.pixelWidth,
                height: asset.pixelHeight
            )

            if let old = cache[record.id], old.signature == signature {
                record = old
            }

            if record.fingerprint == nil || record.luminance == nil || record.previewDigest == nil {
                if let image = await PhotoLibrary.image(asset, size: CGSize(width: 256, height: 256)),
                   let (hash, quality, tones, previewDigest) = ImageAnalysis.analyze(
                    image,
                    pixels: asset.pixelWidth * asset.pixelHeight
                   ) {
                    record.fingerprint = hash
                    record.quality = quality
                    record.luminance = tones
                    record.previewDigest = previewDigest
                } else {
                    unavailableIDs.insert(record.id)
                }
            }

            records.append(record)

            if index % 25 == 0 || index == assets.count - 1 {
                await progress(ScanUpdate(
                    records: records,
                    completed: index + 1,
                    total: assets.count,
                    unavailable: unavailableIDs.count,
                    status: "Alle Fotos werden mit kleinen Vorschauen geprüft …"
                ))
            }
        }

        try Task.checkCancellation()

        // Only photos that can still be exact byte duplicates after the cheap preview
        // gate require the expensive original-resource stream from iCloud.
        let candidateIDs = Grouping.exactCandidateIDs(records)
        let indexByID = Dictionary(uniqueKeysWithValues: records.enumerated().map { ($0.element.id, $0.offset) })
        let candidatesNeedingDigest = candidateIDs.filter { id in
            guard let index = indexByID[id] else { return false }
            return records[index].digest == nil
        }

        if !candidatesNeedingDigest.isEmpty {
            let assetsByID = Dictionary(uniqueKeysWithValues: assets.map { ($0.localIdentifier, $0) })
            let orderedCandidates = candidatesNeedingDigest.sorted()

            for (candidateIndex, id) in orderedCandidates.enumerated() {
                try Task.checkCancellation()

                guard let asset = assetsByID[id], let recordIndex = indexByID[id] else {
                    unavailableIDs.insert(id)
                    continue
                }

                do {
                    let (hash, bytes) = try await PhotoLibrary.digest(asset)
                    records[recordIndex].digest = hash
                    records[recordIndex].bytes = bytes
                    unavailableIDs.remove(id)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    unavailableIDs.insert(id)
                }

                if candidateIndex % 5 == 0 || candidateIndex == orderedCandidates.count - 1 {
                    await progress(ScanUpdate(
                        records: records,
                        completed: assets.count,
                        total: assets.count,
                        unavailable: unavailableIDs.count,
                        status: "Exakte Duplikat-Kandidaten werden verifiziert: \(candidateIndex + 1) von \(orderedCandidates.count)"
                    ))
                }
            }
        }

        // A photo is fully checked when its small representation was available and,
        // if it was an exact-duplicate candidate, its original-resource digest succeeded.
        for record in records {
            if record.previewDigest == nil || record.fingerprint == nil {
                unavailableIDs.insert(record.id)
            } else if candidateIDs.contains(record.id) && record.digest == nil {
                unavailableIDs.insert(record.id)
            }
        }

        await progress(ScanUpdate(
            records: records,
            completed: assets.count,
            total: assets.count,
            unavailable: unavailableIDs.count,
            status: "Analyse wird abgeschlossen …"
        ))

        return records
    }
}
