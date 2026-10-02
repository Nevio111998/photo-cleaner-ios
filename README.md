# Photo Cleaner · iPhone

Native SwiftUI-App (iOS 16+) für **Duplikate → ähnliche Fotos → Swipe → Review → bestätigtes Löschen**. Keine externen Swift-Pakete, Werbung, Konten, Abos oder kostenpflichtigen APIs. Fehlende Fotodaten dürfen ausschließlich über Apple PhotoKit aus der eigenen iCloud-Fotomediathek nachgeladen werden; es gibt keinen Upload an eigene oder fremde Server.

**Stand: v1.0.0-alpha.1 – implementierter Prototyp, noch nicht auf einem Apple-Gerät validiert.**
Swift-Syntax und Xcode-Projektstruktur wurden statisch geprüft. In der Erstellungsumgebung waren weder Swift noch Xcode installiert. Ein erfolgreicher iOS-Build oder bestandene XCTest-/Gerätetests wird deshalb ausdrücklich nicht behauptet. Vor Einsatz mit wichtigen Fotos zuerst die Checkliste in `docs/TESTING.md` durchführen.

## Enthalten

- PhotoKit-Zugriff inklusive verweigerter und eingeschränkter Berechtigung.
- Fortschritt, Scan-Abbruch und Wiederverwendung unveränderter Ergebnisse.
- Speicheroptimierter Zwei-Stufen-Scan: Jedes Foto wird zuerst nur mit einer kleinen 256px-Darstellung geprüft. Nur Fotos mit identischen Abmessungen und identischem normalisiertem 64×64-Vorschau-Digest werden als Kandidaten für exakte Duplikate weiter geprüft. Für diese Kandidaten werden die Originalressourcen per PhotoKit gestreamt und mit SHA-256 verifiziert. Byte-identische Duplikate können den Vorfilter nicht umgehen; unnötige Original-Downloads werden vermieden.
- Ähnliche Fotos anhand lokalem 64-Bit-dHash, zusätzlichem 8×8-Helligkeitsvergleich und Seitenverhältnis. Konfigurierbare Hamming-Distanz 2–10, Standard 6.
- Gruppen, grosse Einzelansicht, Vergleich über anklickbare Thumbnails und heuristische Empfehlung aus Schärfe, Pixelanzahl und Belichtung.
- Links: vormerken. Rechts: behalten. Buttons als Alternative. Undo des letzten Entscheids während der laufenden Sitzung.
- Persistente Entscheidungen, Löschübersicht, Einzelbilder prüfen, Auswahl entfernen und alles verwerfen.
- App-Bestätigung vor dem einzigen PhotoKit-Löschaufruf; Apple kann zusätzlich eine Systembestätigung anzeigen. Fehler und Abbruch erhalten die Auswahl.
- Vor Löschung: identische Queue, unveränderte Asset-Signaturen und Löschbarkeit prüfen. Keine automatische Auswahl oder Löschung.

## Kostenlos auf deinem iPhone installieren

**Du brauchst einen Mac mit einer zu deinem iPhone-iOS passenden Xcode-Version, dein iPhone und einen kostenlosen Apple Account.** Ein GitHub-Repository allein kann eine native iOS-App nicht auf dein iPhone installieren.

1. Xcode aus dem Mac App Store installieren und einmal starten; angebotene iOS-Komponenten installieren.
2. ZIP entpacken oder Repository klonen. `PhotoCleaner.xcodeproj` doppelklicken. Kein Projektgenerator nötig.
3. Xcode → Settings → Accounts: Apple Account hinzufügen.
4. Blaues Projekt auswählen → Target **PhotoCleaner** → **Signing & Capabilities** → **Automatically manage signing** aktivieren → deine **Personal Team** wählen.
5. Unter **Bundle Identifier** einen eindeutigen Wert setzen, z. B. `ch.nevio.photocleaner.personal`. Falls Tests signiert ausgeführt werden, auch beim Test-Target deine Team wählen und dessen Identifier anpassen.
6. iPhone per Kabel verbinden, dem Mac vertrauen und in Xcode oben als Run Destination auswählen.
7. Falls verlangt: am iPhone unter Einstellungen → Datenschutz & Sicherheit → **Entwicklermodus** aktivieren; den erforderlichen Neustart bestätigen. Falls iOS eine Vertrauensfreigabe verlangt, unter Allgemein → VPN & Geräteverwaltung prüfen.
8. In Xcode **⌘R** drücken. Auf dem iPhone zuerst nur einige Testbilder freigeben.
9. Identische Kopien und ähnliche Aufnahmen scannen, Swipes/Undo/Review testen und nur entbehrliche Testbilder löschen.

Apple erlaubt Personal-Team-Tests kostenlos. Die Provisioning-Profile laufen nach **7 Tagen** ab; danach kann ein erneutes Bauen/Installieren mit Xcode notwendig sein. Ein bezahltes Developer-Abo oder TestFlight ist für diesen persönlichen Test nicht erforderlich.

Apple-Quellen: [Kostenlose Entwicklung und Personal Team](https://developer.apple.com/support/compare-memberships/), [App auf Gerät starten](https://help.apple.com/xcode/mac/current/en.lproj/dev5a825a1ca.html).

## Apple-konforme Grenzen

- **iCloud:** PhotoKit darf fehlende Bilddaten aus der eigenen iCloud-Fotomediathek nachladen (`isNetworkAccessAllowed = true`). Für die normale Analyse wird nur eine kleine 256px-Darstellung benötigt. Vollständige Originalressourcen werden nur für mögliche exakte Duplikate gestreamt. Die App speichert keine zusätzlichen Fotokopien; iOS/PhotoKit kann heruntergeladene Inhalte jedoch systemseitig zwischenspeichern. Bei fehlender Internetverbindung, iCloud-Fehlern oder nicht erreichbaren Assets werden betroffene Fotos gezählt und können später erneut geprüft werden.
- **Exakt** bedeutet identische Ressourcenbytes, nicht bloss gleicher Bildinhalt. Abweichende Metadaten, Formate oder Bearbeitungshistorien können die exakte Gruppierung verhindern. Solche Bilder können in ähnlichen Gruppen auftauchen.
- **Ähnlichkeit:** V1 vergleicht zeitlich nahe Fotos innerhalb von 24 Stunden zum Gruppenvertreter. Keine globale semantische Suche, keine Gesichts-/Augenerkennung. Jede Aufnahme muss direkt zum Vertreter passen; Ähnlichkeitsketten werden vermieden. Exakte Mehrfachkopien sind in der Ähnlichkeitsansicht auf einen Vertreter reduziert.
- **Empfohlen** ist eine einfache Heuristik, keine Garantie für das schönste Foto. Motive, Gesichtsausdruck und Bildkomposition bewertet V1 nicht.
- **Speicher:** Der Scanner hält nur kleine Analysemerkmale, Hashes und Metadaten dauerhaft vor. Er legt keine Foto-Duplikate in seinem eigenen Speicher ab. Originalressourcen werden nur für exakte Kandidaten gestreamt. Die bekannte Dateigrösse ist deshalb nur für vollständig verifizierte Kandidaten verfügbar. iOS kann iCloud-Inhalte unabhängig von der App cachen. Gelöschte Bilder liegen zunächst in Apples „Zuletzt gelöscht“; iCloud synchronisiert bestätigte Löschungen auf andere Geräte.
- **Hintergrund:** Analyse läuft ausserhalb des Main Actors, während die App geöffnet ist. Beim Wechsel in den Hintergrund wird ein Stop angefordert. Ein bereits laufender Ressourcenabruf kann noch fertiglaufen. Keine garantierte Ausführung bei gesperrtem iPhone; iOS entscheidet über Suspendierung.
- **Cache:** Geschützte JSON-Datei in Application Support; von Backups ausgenommen. Nur Kennungen, Metadaten, Hashes, Helligkeitsmerkmale und Entscheidungen, keine Bildkopien. Bearbeitete/nicht mehr zugängliche Fotos verlieren beim Abgleich ihre bisherigen Ergebnisse und Entscheidungen. Undo-Historie wird nicht über Neustarts erhalten.
- **Performance:** Ein Ressourcenstrom und kleine Analysebilder gleichzeitig. Typischer Vergleichsaufwand durch Zeitfenster reduziert; bei sehr vielen unterschiedlichen Fotos am selben Tag bleibt der Worst Case quadratisch. V1 enthält noch keinen Gerätebenchmark.

## Architektur

| Datei | Verantwortung |
|---|---|
| `PhotoCleanerApp.swift` | Einstieg und App-Lebenszyklus |
| `AppModel.swift` | Main-Actor-Zustand, Entscheidungen, Löschbestätigung |
| `Scanner.swift` | Serieller Analyse-Actor, Fortschritt und Cache-Wiederverwendung |
| `PhotoLibrary.swift` | PhotoKit lesen, streamen, Thumbnails, einziger Löschaufruf; Bildanalyse |
| `Models.swift` | Datenmodelle, Undo und pure Gruppierung |
| `Persistence.swift` | Atomare Speicherung mit Dateischutz |
| `Views.swift` | Start, Gruppen, Swipe und Review |
| `PhotoCleanerTests/` | XCTest für Gruppierung, Undo und Datenzustand |

Spätere Kategorien (Screenshots, Unschärfe, Videos, grosse Dateien, Serien) können weitere Scanner/Ansichten und dieselbe Entscheidungs-/Review-Strecke verwenden. Sie sind in V1 absichtlich nicht als funktionslose Menüpunkte enthalten.

## Testen und Entwicklung

In Xcode **⌘U** für die Unit-Tests. Für den Simulator zunächst die verfügbare Destination ermitteln:

```sh
xcodebuild -list -project PhotoCleaner.xcodeproj
xcrun simctl list devices available
xcodebuild test -project PhotoCleaner.xcodeproj -scheme PhotoCleaner \
  -destination 'platform=iOS Simulator,id=DEINE-SIMULATOR-UUID' \
  CODE_SIGNING_ALLOWED=NO
```

`.github/workflows/ios.yml` baut und testet auf einem macOS-Runner. Die Workflow-Datei ist vorbereitet, wurde aber noch nicht ausgeführt. GitHub Actions ist für lokale Nutzung nicht erforderlich; private Repositories können ein Minutenbudget haben.

Statische Linux-Prüfung (kein Ersatz für Xcode):

```sh
python3 -m pip install -r scripts/requirements-validation.txt
python3 scripts/validate_source.py
```

Projektdatei bei Bedarf deterministisch neu erstellen: `python3 scripts/generate_project.py`. Das überschreibt manuelle Xcode-Projekteinstellungen; vorher eigene Signing-Einstellungen sichern.

## GitHub

Der lokale Stand ist mit Git versioniert. Es wurde noch kein Remote-Repository erstellt oder hochgeladen, weil die verfügbare GitHub-Anbindung keine Repository-Erstellung anbietet.

Mit auf dem Mac eingerichteter GitHub CLI kann das neue private Repository erstellt werden:

```sh
# Im Projektordner, nach Wiederherstellung des Git-Verlaufs aus dem Lieferpaket:
gh auth login
gh repo create photo-cleaner-ios --private --source=. --remote=origin --push
git push origin --tags
```

Alternativ ein **leeres privates** Repository in GitHub anlegen (ohne README/.gitignore), dann:

```sh
git remote add origin https://github.com/DEIN-NAME/photo-cleaner-ios.git
git push -u origin main
git push origin --tags
```

Das Lieferpaket enthält den Projektordner und `PhotoCleaner-history.bundle`. Mit `git clone PhotoCleaner-history.bundle PhotoCleaner-versioniert` wird der vollständige vorbereitete Git-Verlauf als eigenes Arbeitsverzeichnis wiederhergestellt. Für Xcode genügt auch der bereits entpackte Projektordner.
