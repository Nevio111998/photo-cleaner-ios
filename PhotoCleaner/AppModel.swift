import SwiftUI
import Photos

@MainActor final class AppModel: ObservableObject {
    @Published private(set) var records: [PhotoRecord] = []
    @Published private(set) var decisions = DecisionHistory()
    @Published private(set) var exact: [PhotoGroup] = []
    @Published private(set) var similar: [PhotoGroup] = []
    @Published var authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published var scanning = false
    @Published var deleting = false
    @Published var completed = 0
    @Published var total = 0
    @Published var unavailable = 0
    @Published var scanStatus = ""
    @Published var error: String?
    @Published var notice: String?
    @Published var threshold = 6.0
    private var scanTask: Task<Void, Never>?
    private var groupingTask: Task<Void, Never>?
    private let scanner = Scanner()
    var hasAccess: Bool { authorization == .authorized || authorization == .limited }
    var queue: [PhotoRecord] { records.filter { decisions.decisions[$0.id] == .delete } }
    var canUndo: Bool { decisions.canUndo }
    init() {
        do {
            let saved = try Persistence.load()
            records = saved.records
            decisions = DecisionHistory(decisions: saved.decisions)
        } catch { self.error = "Gespeicherter Stand konnte nicht geladen werden: \(error.localizedDescription)" }
    }
    func refresh() {
        guard !scanning, !deleting else { return }
        authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard hasAccess else { exact = []; similar = []; return }
        let assets = PhotoLibrary.assets()
        total = assets.count
        let signatures = Dictionary(uniqueKeysWithValues: assets.map { ($0.localIdentifier, PhotoLibrary.signature($0)) })
        // Never retain a deletion decision for an edited or no-longer-accessible image.
        records.removeAll { signatures[$0.id] != $0.signature }
        decisions.retain(Set(records.map(\.id)))
        persist(); regroup()
    }
    func requestAccess() async {
        authorization = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        refresh()
    }
    func persist() {
        do { try Persistence.save(SavedState(records: records, decisions: decisions.decisions)) }
        catch { self.error = "Stand konnte nicht gespeichert werden: \(error.localizedDescription)" }
    }
    func regroup() {
        groupingTask?.cancel()
        let input = records; let tolerance = Int(threshold)
        groupingTask = Task {
            let result = await Task.detached(priority: .userInitiated) {
                (Grouping.exact(input), Grouping.similar(input, threshold: tolerance))
            }.value
            guard !Task.isCancelled else { return }
            exact = result.0; similar = result.1
        }
    }
    func scan() {
        guard hasAccess, !scanning, !deleting else { return }
        refresh()
        scanning = true; completed = 0; unavailable = 0; scanStatus = "Analyse wird vorbereitet …"; notice = nil
        let cache = records
        scanTask = Task {
            do {
                let result = try await scanner.scan(cached: cache) { update in
                    await self.receive(update)
                }
                records = result
                if unavailable == 0 {
                    notice = "Analyse vollständig abgeschlossen. Alle \(total) Fotos wurden geprüft – inklusive Fotos aus iCloud."
                } else {
                    notice = "Analyse abgeschlossen. \(unavailable) von \(total) Fotos konnten trotz iCloud-Zugriff nicht vollständig geprüft werden. Prüfe Internetverbindung und iCloud-Fotostatus und starte die Analyse erneut."
                }
            } catch is CancellationError { notice = "Analyse gestoppt. Der bisherige Stand bleibt gespeichert." }
            catch { self.error = error.localizedDescription }
            decisions.retain(Set(records.map(\.id)))
            persist(); regroup(); scanning = false
        }
    }
    private func receive(_ update: ScanUpdate) {
        let updatedIDs = Set(update.records.map(\.id))
        records = update.records + records.filter { !updatedIDs.contains($0.id) }
        completed = update.completed; total = update.total; unavailable = update.unavailable; scanStatus = update.status
        persist()
    }
    func stop() { scanTask?.cancel() }
    func decide(_ decision: Decision?, id: String) {
        guard !deleting else { return }
        decisions.set(decision, for: id); persist()
    }
    @discardableResult func undo() -> String? {
        guard !deleting else { return nil }
        let id = decisions.undo(); persist(); return id
    }
    func discardQueue() { guard !deleting else { return }; decisions.clearQueue(); persist() }
    func deleteConfirmed(_ ids: [String]) async {
        guard !deleting, !scanning, !ids.isEmpty, Set(ids) == Set(queue.map(\.id)) else { return }
        deleting = true
        defer { deleting = false }
        do {
            guard hasAccess else { throw CocoaError(.fileReadNoPermission) }
            for record in queue {
                guard let asset = PhotoLibrary.asset(record.id), PhotoLibrary.signature(asset) == record.signature,
                      asset.canPerform(.delete) else {
                    throw NSError(domain: "PhotoCleaner", code: 1, userInfo: [NSLocalizedDescriptionKey:
                        "Die Auswahl wurde verändert oder enthält nicht löschbare Fotos. Bitte erneut analysieren und prüfen."])
                }
            }
            try await PhotoLibrary.delete(confirmedIDs: ids)
            let removed = Set(ids)
            records.removeAll { removed.contains($0.id) }
            decisions.retain(Set(records.map(\.id)))
            persist(); regroup()
            total = PhotoLibrary.assets().count
            notice = "\(ids.count) Fotos gelöscht. Sie liegen zunächst in Apples Album ‚Zuletzt gelöscht‘."
        } catch {
            self.error = "Löschung nicht abgeschlossen. Die Vormerkliste bleibt erhalten. \(error.localizedDescription)"
        }
    }
}
