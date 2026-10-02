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
                    }
                    if let notice = model.notice { Text(notice).font(.callout).foregroundStyle(.secondary) }
                }
                if model.hasAccess {
                    Section("Gefunden") {
                        NavigationLink { GroupList(title: "Exakte Duplikate", exact: true) } label: {
                            category("Exakte Duplikate", icon: "square.on.square", count: model.exact.reduce(0) { $0 + $1.photos.count })
                        }
                        NavigationLink { GroupList(title: "Ähnliche Fotos", exact: false) } label: {
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

struct GroupList: View {
    @EnvironmentObject var model: AppModel
    let title: String
    let exact: Bool
    var groups: [PhotoGroup] { exact ? model.exact : model.similar }
    var body: some View {
        List {
            if groups.isEmpty { Text("Keine Gruppen gefunden. Starte eine Analyse auf der Startseite.") }
            ForEach(groups) { group in
                NavigationLink { SwipeView(group: group) } label: {
                    HStack {
                        AssetImage(id: group.photos[0].id).frame(width: 68, height: 68)
                        VStack(alignment: .leading) {
                            Text("\(group.photos.count) \(exact ? "identische" : "ähnliche") Fotos").font(.headline)
                            Text("\(group.photos.filter { model.decisions.decisions[$0.id] != nil }.count) entschieden")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }.navigationTitle(title)
    }
}

struct SwipeView: View {
    @EnvironmentObject var model: AppModel
    let group: PhotoGroup
    @State private var index = 0
    @State private var offset: CGFloat = 0
    var body: some View {
        VStack(spacing: 12) {
            if index < group.photos.count {
                let photo = group.photos[index]
                HStack {
                    Text("Foto \(index + 1) von \(group.photos.count)")
                    Spacer()
                    if photo.id == group.bestID { Label("Empfohlen", systemImage: "star.fill").foregroundStyle(.orange) }
                }.font(.caption)
                ZStack(alignment: .top) {
                    AssetImage(id: photo.id, large: true)
                        .offset(x: offset).rotationEffect(.degrees(Double(offset / 30)))
                    if abs(offset) > 30 {
                        Text(offset > 0 ? "BEHALTEN" : "VORMERKEN")
                            .font(.headline).padding().background(offset > 0 ? Color.green : Color.red)
                            .foregroundStyle(.white).clipShape(Capsule())
                    }
                }.frame(maxHeight: .infinity)
                    .gesture(DragGesture().onChanged { offset = $0.translation.width }
                        .onEnded { value in
                            if value.translation.width > 90 { decide(.keep) }
                            else if value.translation.width < -90 { decide(.delete) }
                            offset = 0
                        })
                if let decision = model.decisions.decisions[photo.id] {
                    Text(decision == .keep ? "Behalten" : "Zum Löschen vorgemerkt").font(.caption)
                }
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(Array(group.photos.enumerated()), id: \.element.id) { position, item in
                            Button { index = position } label: {
                                AssetImage(id: item.id).frame(width: 58, height: 58)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(position == index ? Color.teal : Color.clear, lineWidth: 3))
                            }.accessibilityLabel("Foto \(position + 1) anzeigen")
                        }
                    }.padding(4)
                }
                HStack {
                    Button { decide(.delete) } label: { Label("Vormerken", systemImage: "trash") }.tint(.red)
                    Spacer()
                    Button { decide(.keep) } label: { Label("Behalten", systemImage: "heart") }
                }.buttonStyle(.borderedProminent)
            } else {
                Spacer()
                Image(systemName: "checkmark.circle").font(.system(size: 60)).foregroundStyle(.teal)
                Text("Gruppe geprüft").font(.title.bold())
                Text("Es wurde noch nichts gelöscht.")
                Button("Gruppe erneut ansehen") { index = 0 }
                NavigationLink("Löschübersicht öffnen") { ReviewView() }.buttonStyle(.borderedProminent)
                Spacer()
            }
            Button { if let id = model.undo(), let position = group.photos.firstIndex(where: { $0.id == id }) { index = position } } label: { Label("Letzten Swipe rückgängig", systemImage: "arrow.uturn.backward") }
                .disabled(!model.canUndo)
            Text("Links vormerken · Rechts behalten").font(.caption).foregroundStyle(.secondary)
        }.padding().navigationTitle("Fotos prüfen").navigationBarTitleDisplayMode(.inline)
            .toolbar { NavigationLink { ReviewView() } label: { Image(systemName: "trash") } }
    }
    private func decide(_ decision: Decision) {
        model.decide(decision, id: group.photos[index].id)
        index += 1; offset = 0
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
