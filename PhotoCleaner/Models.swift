import Foundation

struct PhotoRecord: Codable, Identifiable {
    let id: String
    let signature: String
    let date: Date
    let width: Int
    let height: Int
    var digest: String?
    var bytes: Int64?
    var fingerprint: UInt64?
    var quality: Double?
    var luminance: [UInt8]?
}

struct PhotoGroup: Identifiable {
    enum Kind { case exact, similar }
    let kind: Kind
    let photos: [PhotoRecord]
    var id: String { photos.map(\.id).sorted().joined(separator: "|") }
    var bestID: String? { photos.max { ($0.quality ?? 0) < ($1.quality ?? 0) }?.id }
}

enum Decision: String, Codable { case keep, delete }
struct DecisionHistory {
    private(set) var decisions: [String: Decision] = [:]
    private var history: [(String, Decision?)] = []
    init(decisions: [String: Decision] = [:]) { self.decisions = decisions }
    var canUndo: Bool { !history.isEmpty }
    mutating func set(_ decision: Decision?, for id: String) {
        history.append((id, decisions[id]))
        decisions[id] = decision
    }
    @discardableResult mutating func undo() -> String? {
        guard let (id, old) = history.popLast() else { return nil }
        decisions[id] = old
        return id
    }
    mutating func clearQueue() {
        decisions = decisions.filter { $0.value != .delete }
        history.removeAll()
    }
    mutating func retain(_ ids: Set<String>) {
        decisions = decisions.filter { ids.contains($0.key) }
        history.removeAll()
    }
}

enum Grouping {
    static func distance(_ a: UInt64, _ b: UInt64) -> Int { (a ^ b).nonzeroBitCount }
    static func exact(_ records: [PhotoRecord]) -> [PhotoGroup] {
        Dictionary(grouping: records.filter { $0.digest != nil }, by: { $0.digest! })
            .values.filter { $0.count > 1 }
            .map { PhotoGroup(kind: .exact, photos: $0.sorted { $0.id < $1.id }) }
            .sorted { $0.id < $1.id }
    }
    // Time window limits comparisons. Every member must match the representative;
    // no transitive chain of weakly related images is allowed.
    static func similar(_ records: [PhotoRecord], threshold: Int) -> [PhotoGroup] {
        let exactGroups = exact(records)
        let redundant = Set(exactGroups.flatMap { $0.photos.dropFirst().map(\.id) })
        let sorted = records.filter { $0.fingerprint != nil && !redundant.contains($0.id) }
            .sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }
        var groups: [[PhotoRecord]] = []
        var active: [Int] = []
        for record in sorted {
            active.removeAll { record.date.timeIntervalSince(groups[$0][0].date) > 86_400 }
            let match = active.first { index in
                let first = groups[index][0]
                let ratioA = Double(first.width) / Double(max(1, first.height))
                let ratioB = Double(record.width) / Double(max(1, record.height))
                let tonalMatch: Bool
                if let a = first.luminance, let b = record.luminance, a.count == 64, b.count == 64 {
                    let meanError = zip(a, b).reduce(0.0) { $0 + abs(Double($1.0) - Double($1.1)) } / 64
                    tonalMatch = meanError <= 24
                } else { tonalMatch = true }
                return tonalMatch && abs(ratioA - ratioB) < 0.12 && distance(first.fingerprint!, record.fingerprint!) <= threshold
            }
            if let match { groups[match].append(record) }
            else { groups.append([record]); active.append(groups.count - 1) }
        }
        return groups.filter { $0.count > 1 }.map { PhotoGroup(kind: .similar, photos: $0) }
    }
}
