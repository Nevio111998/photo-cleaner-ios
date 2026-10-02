# Validierung und Abnahme

## Tatsächlich ausgeführt in der Linux-Erstellungsumgebung

- Swift-Parserprüfung aller 8 Swift-Dateien: bestanden.
- OpenStep-Parserprüfung der Xcode-Projektdatei: bestanden.
- XML-Prüfung des Shared Scheme: bestanden.
- Projektdateiverweise auf vorhandene Quelldateien: bestanden.
- `git diff --check`: bestanden.

## Vorbereitet, NICHT ausgeführt

Acht XCTest-Fälle:
1. Vormerken/Behalten/Undo stellt den früheren Entscheid wieder her.
2. Alles verwerfen entfernt Löschentscheidungen und erhält Behalten-Entscheidungen.
3. Fehlende Ressourcen werden nie als exakte Duplikate gruppiert.
4. Keine transitive Ähnlichkeitskette und Einhalten des 24h-Fensters.
5. Exakte Kopien erscheinen nicht mehrfach in ähnlichen Gruppen.
6. Codable-Roundtrip und Entfernen nicht mehr gültiger Entscheidungen.
7. Schwarze und weisse Flächen werden trotz gleicher dHash-Struktur getrennt.
8. Hamming-Distanz-Randfälle.

Diese Tests prüfen reine Logik. PhotoKit-Löschung ist nicht gemockt/integrationstested. Build, Typprüfung mit Apple SDK, XCTest und folgende manuelle Tests sind offen.

## Manuelle Tests auf iPhone/Simulator

Nur entbehrliche Testbilder verwenden.

| Fall | Erwartung |
|---|---|
| Erststart, Zugriff ablehnen | Verständliche Erklärung und Einstellungslink; keine Analyse |
| Eingeschränkten Zugriff geben | Nur freigegebene Bilder; Hinweis auf begrenzte Auswahl |
| Leere Mediathek | Abschluss ohne Fehler, keine Gruppen |
| 3 identische Dateien importieren | Eine exakte Gruppe, sofern PhotoKit Ressourcenbytes unverändert übernimmt |
| Gleiches Foto mit anderer Kompression | Nicht zwingend exakt; bei zeitlicher Nähe ähnlich |
| Live Photos mit gleichem Standbild, verschiedenen Videos | Nicht als exakt identisch einstufen |
| Schwarzes und weisses Bild | Nicht als ähnlich gruppieren |
| Ähnliche Szene/Serienaufnahmen | Gruppe bei passender Toleranz; Vergleich selbst kontrollieren |
| Links/rechts swipen | Nur interner Entscheid; Original in Apple Fotos weiterhin vorhanden |
| Mehrfach entscheiden, Undo | Vorherigen Entscheid wiederherstellen |
| Alle Fotos einer Gruppe vormerken | Warnhinweis in Review |
| Review-Einzelbild öffnen, Behalten | Grossansicht; Auswahlzahl sinkt |
| Alles verwerfen | Queue leer; nichts aus Fotos gelöscht |
| App-Bestätigung abbrechen | Keine PhotoKit-Änderung |
| Apple-Dialog abbrechen / Fehler | Queue bleibt erhalten, Fehlerhinweis |
| Bestätigt löschen | Nur geprüfte Auswahl verschwindet; Apple „Zuletzt gelöscht“ prüfen |
| Foto nach Scan extern bearbeiten | Entscheidung/Cache beim Abgleich verwerfen; Löschprüfung lehnt veraltete Auswahl ab |
| Zugriff reduzieren / Bilder extern entfernen | Beim nächsten Aktivieren aktualisieren; Löschung kann keine unzugänglichen Assets enthalten |
| App neu starten | Cache und Entscheidungen geladen; Undo-Historie leer |
| Unverändert erneut scannen | Analysemerkmale und Digests wiederverwenden |
| Original nur in iCloud | Kein Download; Zahl unvollständig geprüfter Fotos steigt |
| Während Scan stoppen / App verlassen | Stop nach laufender Anfrage; Teilstand behalten |
| Mehrere Tausend Fotos | Reaktionsfähigkeit, Zeit, Peak-RAM und Temperatur auf echtem Gerät messen |

Keine Freigabe als stabile Version, bevor Build, Unit-Tests und diese Kernabläufe bestätigt sind.
