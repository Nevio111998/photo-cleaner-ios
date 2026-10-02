import SwiftUI
import Photos

struct HomeView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Nur auf deinem iPhone", systemImage: "lock.shield")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("Fotomediathek").font(.title2.bold())
                        Text("\(model.total.formatted()) Fotos").font(.largeTitle.bold())
                        if model.hasAccess {
                            Button(model.scanning ? "Analyse stoppen" : "Fotos analysieren") {
                                model.scanning ? model.stop() : model.scan()
                            }.buttonStyle(.borderedProminent).disabled(model.deleting)
                        } else if model.authorization == .notDetermined {
                            Button("Fotozugriff erlauben") { Task { await model.requestAccess() } }
                                .buttonStyle(.borderedProminent)
                        } else {
                            Text("Bitte erlaube den Fotozugriff in den Einstellungen.")
                            Link("Einstellungen öffnen", destination: URL(string: UIApplication.openSettingsURLString)!)
                        }
                    }.padding(.vertical, 12)
                    if model.authorization == .limited {
                        Text("Eingeschränkter Zugriff: Nur freigegebene Fotos werden analysiert.").font(.caption)
                        Link("Fotoauswahl in Einstellungen ändern", destination: URL(string: UIApplication.openSettingsURLString)!)
                    }
                    if model.scanning {
                        ProgressView(value: Double(model.completed), total: Double(max(1, model.total)))
                        Text("\(model.completed) von \(model.total) Fotos analysiert").font(.caption)
                        Text(model.scanStatus).font(.caption).foregroundStyle(.secondary)
                        Text("Die App lädt zuerst nur kleine iCloud-Vorschauen. Vollständige Originaldaten werden nur für mögliche exakte Duplikate gestreamt und nicht als Kopie in der App gespeichert.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let notice = model.notice { Text(notice).font(.callout).foregroundStyle(.secondary) }
                }
                if model.hasAccess {
                    Section("Gefunden") {
                        NavigationLink { ContinuousSwipeView(title: "Exakte Duplikate", exact: true) } label: {
                            category("Exakte Duplikate", icon: "square.on.square", count: model.exact.reduce(0) { $0 + $1.photos.count })
                        }
                        NavigationLink { ContinuousSwipeView(title: "Ähnliche Fotos", exact: false) } label: {
                            category("Ähnliche Fotos", icon: "photo.stack", count: model.similar.reduce(0) { $0 + $1.photos.count })
                        }
                        NavigationLink { ReviewView() } label: {
                            category("Zum Löschen vorgemerkt", icon: "trash", count: model.queue.count)
                        }
                    }.disabled(model.scanning || model.deleting)
                    Section("Ähnlichkeit") {
                        Slider(value: $model.threshold, in: 2...10, step: 1) { Text("Toleranz") }
                            .onChange(of: model.threshold) { _ in model.regroup() }
                        Text("Toleranz \(Int(model.threshold)): niedrig = strenger. Verglichen werden Aufnahmen innerhalb von 24 Stunden. Ähnliche Fotos bitte selbst prüfen.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.disabled(model.scanning)
                }
                Section {
                    Text("Kein Upload. Keine Anmeldung. Swipes merken Fotos nur vor. Gelöscht wird erst nach deiner Bestätigung.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }.navigationTitle("Photo Cleaner")
        }.tint(.teal)
    }
    private func category(_ title: String, icon: String, count: Int) -> some View {
        HStack { Label(title, systemImage: icon); Spacer(); Text("\(count)").foregroundStyle(.secondary) }
    }
}

struct AssetImage: View {
    let id: String
    var large = false
    @State private var image: UIImage?
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(.quaternary)
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            else { Image(systemName: "photo").foregroundStyle(.secondary) }
        }.clipped().task(id: id) {
            image = nil
            guard let asset = PhotoLibrary.asset(id) else { return }
            let loaded = await PhotoLibrary.image(asset, size: CGSize(width: large ? 1400 : 220, height: large ? 1400 : 220))
            guard !Task.isCancelled else { return }
            image = loaded
        }
    }
}

struct SwipeItem: Identifiable {
    let photo: PhotoRecord
    let groupNumber: Int
    let groupCount: Int
    let positionInGroup: Int
    let photosInGroup: Int
    let bestID: String?
    var id: String { photo.id }
}

struct ContinuousSwipeView: View {
    @EnvironmentObject var model: AppModel
    let title: String
    let exact: Bool
    @State private var index = 0
    @State private var offset: CGFloat = 0

    private var groups: [PhotoGroup] { exact ? model.exact : model.similar }

    private var items: [SwipeItem] {
        let totalGroups = groups.count
        return groups.enumerated().flatMap { groupIndex, group in
            group.photos.enumerated().map { photoIndex, photo in
                SwipeItem(
                    photo: photo,
                    groupNumber: groupIndex + 1,
                    groupCount: totalGroups,
                    positionInGroup: photoIndex + 1,
                    photosInGroup: group.photos.count,
                    bestID: group.bestID
                )
            }
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            if index < items.count {
                let item = items[index]

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gruppe \(item.groupNumber) von \(item.groupCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(exact ? "Identische Fotos" : "Ähnliche Fotos")
                            .font(.headline)
                    }
                    Spacer()
                    if item.photo.id == item.bestID {
                        Label("Empfohlen", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                ZStack(alignment: .top) {
                    AssetImage(id: item.photo.id, large: true)
                        .offset(x: offset)
                        .rotationEffect(.degrees(Double(offset / 30)))

                    if abs(offset) > 30 {
                        Text(offset > 0 ? "BEHALTEN" : "VORMERKEN")
                            .font(.headline)
                            .padding()
                            .background(offset > 0 ? Color.green : Color.red)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { offset = $0.translation.width }
                        .onEnded { value in
                            if value.translation.width > 90 {
                                decide(.keep)
                            } else if value.translation.width < -90 {
                                decide(.delete)
                            } else {
                                withAnimation(.spring(response: 0.25)) { offset = 0 }
                            }
                        }
                )

                VStack(spacing: 4) {
                    Text("Nr. \(item.positionInGroup) von \(item.photosInGroup)")
                        .font(.title3.bold())
                    Text("Insgesamt \(index + 1) von \(items.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let decision = model.decisions.decisions[item.photo.id] {
                    Text(decision == .keep ? "Behalten" : "Zum Löschen vorgemerkt")
                        .font(.caption)
                }
            } else if items.isEmpty {
                Spacer()
                Image(systemName: "photo.stack")
                    .font(.system(size: 54))
                    .foregroundStyle(.secondary)
                Text("Keine Fotos gefunden")
                    .font(.title2.bold())
                Text("Starte zuerst eine Analyse auf der Startseite.")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                Spacer()
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 60))
                    .foregroundStyle(.teal)
                Text("Alles geprüft")
                    .font(.title.bold())
                Text(exact ? "Alle exakten Duplikate wurden durchgesehen." : "Alle ähnlichen Fotos wurden durchgesehen.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Text("Gelöscht wurde noch nichts.")
                    .font(.callout)
                Button("Alle erneut ansehen") {
                    index = 0
                    offset = 0
                }
                NavigationLink("Löschübersicht öffnen") {
                    ReviewView()
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }

            if !items.isEmpty {
                HStack {
                    Button {
                        undo()
                    } label: {
                        Label("Rückgängig", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(!model.canUndo)

                    Spacer()

                    NavigationLink {
                        ReviewView()
                    } label: {
                        Label("\(model.queue.count)", systemImage: "trash")
                    }
                }

                Text("Links vormerken · Rechts behalten")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { resumeAtFirstUndecided() }
    }

    private func decide(_ decision: Decision) {
        guard index < items.count else { return }
        model.decide(decision, id: items[index].photo.id)
        index += 1
        offset = 0
        skipPreviouslyDecided()
    }

    private func undo() {
        guard let id = model.undo(),
              let position = items.firstIndex(where: { $0.photo.id == id }) else { return }
        index = position
        offset = 0
    }

    private func resumeAtFirstUndecided() {
        if let next = items.firstIndex(where: { model.decisions.decisions[$0.photo.id] == nil }) {
            index = next
        } else {
            index = items.count
        }
    }

    private func skipPreviouslyDecided() {
        while index < items.count,
              model.decisions.decisions[items[index].photo.id] != nil {
            index += 1
        }
    }
}

struct ReviewView: View {
    @EnvironmentObject var model: AppModel
    @State private var confirmedIDs: [String] = []
    @State private var confirmation = false
    @State private var selected: PhotoRecord?
    var body: some View {
        List {
            Section {
                Text("\(model.queue.count) Fotos zum Löschen").font(.title2.bold())
                let bytes = model.queue.compactMap(\.bytes).reduce(0, +)
                Text("Bekannte Dateigrösse: \(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))")
                if model.queue.contains(where: { $0.bytes == nil }) { Text("Für einige Fotos ist die Dateigrösse unbekannt.").font(.caption) }
                Text("Schätzung, keine garantierte Freigabe. Apple bewahrt gelöschte Fotos zunächst in ‚Zuletzt gelöscht‘ auf. Bei iCloud-Fotos wird die Löschung auf deine Geräte synchronisiert.")
                    .font(.caption).foregroundStyle(.secondary)
                if removesWholeGroup { Label("Du hast alle Fotos mindestens einer Gruppe vorgemerkt. Prüfe, ob du ein Exemplar behalten möchtest.", systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
            }
            Section("Auswahl kontrollieren") {
                ForEach(model.queue) { photo in
                    HStack {
                        Button { selected = photo } label: {
                            HStack {
                                AssetImage(id: photo.id).frame(width: 65, height: 65)
                                Text(photo.date, style: .date).font(.caption)
                            }
                        }.buttonStyle(.plain)
                        Spacer()
                        Button("Behalten") { model.decide(.keep, id: photo.id) }.buttonStyle(.bordered)
                    }
                }
            }
            Section {
                Button("Alles verwerfen") { model.discardQueue() }.disabled(model.queue.isEmpty)
                Button("Ausgewählte Fotos löschen …", role: .destructive) {
                    confirmedIDs = model.queue.map(\.id); confirmation = true
                }.disabled(model.queue.isEmpty || model.scanning)
                if model.deleting { ProgressView("Löschung wird ausgeführt …") }
            }
        }.navigationTitle("Löschübersicht").disabled(model.deleting)
            .confirmationDialog("\(confirmedIDs.count) Fotos wirklich aus der Fotomediathek löschen?", isPresented: $confirmation, titleVisibility: .visible) {
                Button("\(confirmedIDs.count) Fotos löschen", role: .destructive) { Task { await model.deleteConfirmed(confirmedIDs) } }
                Button("Abbrechen", role: .cancel) {}
            } message: { Text("Erst jetzt wird die Löschung bei Apple angefordert. Ein Swipe allein löscht niemals Fotos.") }
            .sheet(item: $selected) { photo in
                NavigationStack {
                    AssetImage(id: photo.id, large: true).padding()
                        .toolbar { Button("Fertig") { selected = nil } }
                }
            }
    }
    private var removesWholeGroup: Bool {
        let ids = Set(model.queue.map(\.id))
        return (model.exact + model.similar).contains { $0.photos.allSatisfy { ids.contains($0.id) } }
    }
}
