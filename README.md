# Ploty 0.26.9

Gemeinsames RP-Werkzeug für World of Warcraft 9.2.7.

Ploty unterstützt die Organisation eines RP-Plots, ohne dessen Regeln oder Ausgänge automatisch festzulegen.

## Stabilere Plot- und Würfelsynchronisierung in 0.26.9

- Ein Plotstart erreicht neue oder neu geladene Clients jetzt in einer sicheren Reihenfolge: zuerst der Plotstatus, danach Reihenfolge und Laufzeitdaten.
- Bei mehreren Raidassistenten bleibt eine eindeutige Plotquelle zuständig; die tatsächliche Raidleitung kann sie weiterhin übernehmen.
- Die vollständige Zielauswahl einer Probe schaltet den Würfelknopf bereits zuverlässig frei. Ein zusätzlicher Whisper dient nur noch als akustischer Hinweis.
- Ploty erfasst pro Person und Probe nur den ersten Wurf mit exakt dem angeforderten Würfelbereich.
- Vorübergehend unvollständige Gruppenlisten löschen keine Anwesenheiten, Würfelergebnisse oder Auswahlstände mehr.

## Sauberer Übergang zwischen Würfelproben in 0.26.8

- Abgeschlossene Würfe bleiben sichtbar, bis die Plotleitung die nächste Probe startet.
- Vor der nächsten gültigen Würfelaufforderung werden alte Ergebnisse bei allen Ploty-Clients automatisch geleert.
- Fehleingaben oder abgebrochene Aufforderungen löschen keine noch benötigten Ergebnisse.

## Deutlichere Würfelauswahl in 0.26.7

- Ausgewählte Spieler besitzen im Würfeltab einen grünen „Gewählt“-Button.
- Nicht ausgewählte Spieler behalten den normalen violetten „Auswählen“-Button.

## Chatbox ohne sichtbare Scrollleiste in 0.26.6

- Die WoW-Standardscrollleiste und ihre Pfeilknöpfe werden nicht mehr angezeigt.
- Die Chatbox nutzt dadurch die vollständige Inhaltsbreite.
- Lange Texte lassen sich weiterhin mit dem Mausrad oder durch Bewegen des Textcursors scrollen.

## Überarbeiteter Emote-Editor in 0.26.5

- Die Chatbox nutzt die verfügbare Inhaltsbreite besser und bleibt mit ihrer Scrollleiste sauber ausgerichtet.
- „Emote senden“, „Passen“, „Text leeren“ und „Letztes wiederholen“ bilden eine klare, bündige Aktionszeile.
- Der ehemalige „Senden“-Kasten wurde entfernt; Optionen stehen kompakt unter den Aktionen.

## Ruhigerer Emote-Schreiber in 0.26.4

- Der zusätzliche äußere Abschnittsrahmen wurde entfernt.
- Das eigentliche Textfeld bleibt durch seinen violetten Rahmen klar erkennbar.

## Vollständige Sitzungsbereinigung in 0.26.3

- Wiederholte Gruppenereignisse können die verzögerte Bereinigung nach einem echten Gruppenaustritt nicht mehr aufheben.
- Neben Reihenfolge und Gruppenzuweisungen werden auch offene Würfelaufforderungen, Zielauswahl und Ergebnisse entfernt.
- Dieselbe Bereinigung greift beim laufenden Austritt und bei einem veralteten gruppengebundenen Stand nach dem nächsten Login.

## Reihenfolge beim Gruppenaustritt in 0.26.2

- Verlässt der Spieler seine WoW-Gruppe oder seinen Raid, wird die gruppengebundene Emote-Reihenfolge automatisch geleert.
- Dasselbe gilt, wenn die Gruppe vollständig aufgelöst wird.
- Aktueller Zug, Gruppenzuweisungen, Synchronisierungsinformationen und ein eventuell laufender Plot werden zurückgesetzt.
- Vorübergehend unvollständige Rosterinformationen während eines Ladebildschirms werden abgefangen und löschen die Reihenfolge nicht.

## Deutsche Zusammensetzungen in 0.26.1

- Die Rechtschreibprüfung erkennt jetzt produktive deutsche Komposita aus mehreren bekannten Wörterbuchbestandteilen.
- Dadurch gelten beispielsweise „Wochenende“, „Haustür“, „Wasserflasche“, „Sonnenlicht“, „Gruppenname“ und „Rechtschreibprüfung“ als korrekt.
- Die Großschreibung richtet sich bei Zusammensetzungen nach dem letzten Bestandteil: „das wochenende“ erhält den Vorschlag „das Wochenende“.
- Die Prüfung bleibt lokal und bewertet weiterhin weder Grammatik noch Abstände oder Zeichensetzung.

## Groß- und Kleinschreibung in 0.26.0

- Die optionale Schreibprüfung erkennt jetzt zusätzlich kleingeschriebene Satzanfänge und Nomen sowie eindeutig falsch großgeschriebene Wörter.
- Markierte Wörter erscheinen weiterhin rot; der Tooltip zeigt die korrigierte Groß- oder Kleinschreibung.
- Bei `/me` wird der vorangestellte Charaktername berücksichtigt: `/me hebt die Hand.` ist korrekt, `/me Hebt die Hand.` wird markiert.
- Gesprochener Text in Anführungszeichen beginnt als eigener Satz, beispielsweise `/me nickt. "Hallo!"`.
- Mehrdeutige Wörter werden nicht erzwungen. Teilnehmer- und Gruppennamen bleiben automatisch ausgenommen.
- Grammatik, Abstände und Zeichensetzung werden weiterhin nicht geprüft.

## Korrigierter Zeilenumbruch in 0.25.1

- Der Emote-Schreiber berechnet seine Textbreite nun direkt aus dem sichtbaren Scrollbereich.
- Rechts bleibt genügend Platz für Innenabstand, Rahmen und Scrollleiste; lange Zeilen umbrechen dadurch rechtzeitig.
- Auch nach einer Größenänderung des Ploty-Fensters wird die Breite zuverlässig neu gesetzt.

## Vollständiges deutsches Wörterbuch in 0.25.0

- Die optionale Rechtschreibprüfung verwendet das vollständige deutsche igerman98/frami-Wörterbuch und erkennt rund 928.000 Grund- und Beugungsformen.
- Wörter, die nicht im Wörterbuch stehen, werden direkt im Emote-Schreiber rot markiert.
- Für bekannte Tippfehler zeigt der Tooltip eine Korrektur an, beispielsweise „Halo“ → „Hallo“. Andere unbekannte Wörter werden nur markiert und nicht automatisch verändert.
- Grammatik, Abstände und Zeichensetzung bleiben bewusst außerhalb der Prüfung.
- Namen aus der Teilnehmerreihenfolge und Begriffe aus selbst benannten Gruppen werden automatisch akzeptiert.
- Die Prüfung bleibt standardmäßig ausgeschaltet, blockiert niemals den Versand und arbeitet vollständig lokal.
- Wörterbuchquelle, GPL-Lizenzen und Erzeugungsskript befinden sich unter `ThirdParty/GermanDictionary`.

## Direkte Rechtschreibmarkierung in 0.24.3

- Im Emote-Schreiber lässt sich eine lokale Schreibprüfung dauerhaft ein- oder ausschalten; standardmäßig ist sie deaktiviert.
- Erkannte Schreibfehler werden direkt im Text rot markiert; der Tooltip zeigt die Korrektur, beispielsweise „Halo“ → „Hallo“.
- Grammatik, Wortwiederholungen, Abstände, Satzzeichen und Anführungszeichen werden nicht bewertet.
- Die Prüfung korrigiert nichts automatisch und verhindert niemals das Absenden.
- Sie verwendet bewusst bekannte Tippfehler statt jedes unbekannte Wort zu markieren. Charakter-, Orts- und Fantasienamen bleiben dadurch unberührt.
- Ein Slash-Emote bleibt unabhängig davon nur sendbar, wenn Say ausgewählt ist.

## Korrekte Slash-Emotes in 0.24.1

- `/me`, `/e`, `/em` und `/emote` erzeugen nun dasselbe benutzerdefinierte Emote wie im normalen WoW-Chatfeld.
- Der Slashbefehl wird nicht wörtlich gesendet; Ploty übergibt nur den eigentlichen Text an WoWs Chattyp `EMOTE`.
- Im Schreiber ist die Erzählung eines Slash-Emotes orange. Gesprochener Text zwischen `"Anführungszeichen"`, `„deutschen Anführungszeichen“` oder `“typografischen Anführungszeichen”` bleibt weiß.
- Slash-Emotes bleiben auf die räumliche Say-/Emote-Reichweite beschränkt und können nicht versehentlich über Yell, Gruppe oder Raid versendet werden.

## Bewusster Plotstart in 0.24.0

- Die neue Übersicht steht vor den Markierungen und zeigt Plotstatus, Teilnehmer, Anwesenheit, Gruppen und den aktuellen Emoter.
- Die Plotleitung kann Reihenfolge und Gruppen in Ruhe lokal vorbereiten und den Ablauf anschließend über „Plot starten“ freigeben.
- Erst im laufenden Plot werden Reihenfolge, Gruppen, Zugwechsel, Emotes und Würfelaufforderungen synchronisiert beziehungsweise freigeschaltet.
- „Plot beenden“ stoppt den Ablauf, ohne die vorbereitete Reihenfolge zu löschen.
- Nach einem Reload der Plotleitung bleibt der Plot aus, bis er bewusst neu gestartet wird. Teilnehmer, die während eines laufenden Plots neu laden, erhalten den aktiven Stand wieder von der Leitung.
- Alle Textfelder besitzen nun den einheitlichen dunklen Ploty-Stil mit violetter Fokusmarkierung.
- `/me`, `/e` und `/emote` bleiben Say vorbehalten. Bei Yell, Gruppe oder Raid verhindert Ploty den Versand und erklärt die notwendige Korrektur.

## Aufgeräumt und synchronisiert in 0.23.6

- „Würfel leeren“ entfernt die Ergebnisse gleichzeitig bei allen verbundenen Ploty-Clients.
- Veraltete Löschpakete werden ignoriert, sobald bereits eine neuere Probe aktiv ist.
- Die Gruppenverwaltung heißt in der Oberfläche einheitlich nur noch „Gruppen“.
- Die Seitenköpfe zeigen ausschließlich Markierungen, Reihenfolge, Emote-Schreiber oder Würfelübersicht ohne zusätzliche Erklärungstexte.

## Automatische Reihenfolge und eigener Würfelklang in 0.23.5

- Während eines laufenden Plots wird jede strukturelle Änderung an Reihenfolge oder Gruppen unmittelbar an die verbundenen Ploty-Clients übertragen.
- Das gilt für Hinzufügen, Entfernen, Verschieben, Leeren, Gruppenimport, Gruppennamen, Farben, Gruppenpositionen und Zuweisungen.
- Auch eine vollständig geleerte Reihenfolge ersetzt bei anderen Spielern zuverlässig einen alten gespeicherten Stand.
- Der Knopf „Erneut senden“ bleibt als manuelle vollständige Neusynchronisierung verfügbar.
- Eine Würfelaufforderung verwendet einen eigenen Warnklang; der normale Bereitschaftston bleibt dem Emote-Zug vorbehalten.

## Markierreihenfolge in 0.23.4

- Ziel- und Weltmarkierungen verwenden dieselbe sichtbare Reihenfolge.
- Beide Reihen zeigen Stern, Kreis, Diamant, Dreieck, Mond, Quadrat, Kreuz und Totenkopf.
- Die für WoW 9.2.7 abweichenden Weltmarker-IDs werden intern weiterhin korrekt verwendet.

## Markierungen in 0.23.3

- Alle Ziel- und Weltmarker verwenden dieselbe Icongröße und ein gemeinsames Abstandsraster.
- Ein Linksklick setzt die gewählte Zielmarkierung; ein erneuter Linksklick auf dasselbe Symbol entfernt sie wieder.
- Mit Rechtsklick kann die Zielmarkierung weiterhin direkt entfernt werden.

## Korrigiert in 0.23.2

- Beim Löschen einer Gruppe wird der neue Gruppenstand sofort an die anderen Ploty-Clients gesendet.
- Die entfernte Gruppe und ihre bisherigen Zuweisungen verschwinden dort ohne zusätzliches manuelles Synchronisieren.
- Das gilt ebenfalls, wenn die letzte vorhandene Gruppe gelöscht wird.

## Gruppenabschnitte in 0.23.1

- Der Reihenfolge-Tab gliedert Teilnehmer sichtbar nach ihren Gruppen.
- Farbige Kopfzeilen zeigen Gruppenposition, eigenen Gruppennamen und Mitgliederzahl.
- Teilnehmer ohne Zuweisung stehen gesammelt im Abschnitt „OHNE GRUPPE“.
- Die aktive Person bleibt unabhängig von der Gruppenfarbe gold hervorgehoben.

## Gruppenreihenfolge in 0.23.0

- Gruppen bestimmen nun die tatsächliche Emote-Zugfolge.
- Innerhalb einer Gruppe gilt die dort festgelegte Teilnehmerreihenfolge.
- Nach der letzten Person einer Gruppe folgt die erste anwesende Person der nächsten Gruppe.
- Nach der letzten Gruppe beginnt der Ablauf wieder bei der ersten Gruppe.
- Gruppen lassen sich in der Gruppenverwaltung mit „Hoch“ und „Runter“ anordnen.
- Teilnehmer lassen sich mit „Hoch“ und „Runter“ nur innerhalb ihrer eigenen Gruppe verschieben.
- Personen ohne Gruppe werden als letzter Block behandelt und nicht aus der Reihenfolge ausgeschlossen.

## Farben in 0.22.1

- „Anwesend“ wird in der Reihenfolge grün, „Abwesend“ rot dargestellt.
- Die aktuell aktive Person erscheint im Reihenfolge-Tab goldfarben und hebt sich damit von der Anwesenheitsfarbe ab.
- Im Emote-Schreiber bleibt der große, grüne Name als unmittelbarer Zughinweis erhalten.

## Neu in 0.22.0

- Die Plotleitung wählt in der Würfelübersicht gezielt die Personen aus, die für eine Probe würfeln sollen.
- „Auswahl auffordern“ sendet die Aufforderung nur an diese Spieler; eine globale Runde für alle entfällt.
- Fortschritt, fehlende Würfe und Abschlussmeldung beziehen sich ausschließlich auf die aktive Auswahl.
- Nicht ausgewählte Spieler können die Probe nicht aus Ploty heraus würfeln und ihre normalen `/roll`-Nachrichten werden dafür nicht erfasst.
- Nach Abschluss können die Ergebnisse direkt verglichen oder dieselbe beziehungsweise eine neue Auswahl erneut aufgefordert werden.

## Aufgeräumt in 0.21.4

- Der Bedienhinweis `/ploty · Rechtsklick würfelt nach Aufforderung` wurde aus der Seitenleiste entfernt.
- Slashbefehl und Minimap-Rechtsklick funktionieren unverändert weiter.

## Korrigiert in 0.21.3

- Die deutlich größere aktive Person erscheint nur noch in der Namensfolge des Emote-Schreibers.
- Die Reihenfolgeliste bleibt einheitlich kompakt; dort kennzeichnet nur die grüne Farbe die aktive Person.

## Verbessert in 0.21.2

- Der Name der aktuell aktiven Person wird in der Namensfolge des Emote-Schreibers und in der Teilnehmerliste deutlich größer dargestellt.
- Vorheriger und nächster Name bleiben kleiner daneben stehen; der aktive Name bleibt grün und geklammert.
- Die aktive Zeile erhält etwas mehr Höhe, damit die Hervorhebung sauber und ohne abgeschnittenen Text bleibt.
- Beim Zugwechsel wandert die größere Schrift automatisch zur neuen aktiven Person.

## Vereinfacht in 0.21.1

- Der Teilnehmerstatus kennt nur noch „Anwesend“ und „Abwesend“.
- „Fertig“ und „Bereit“ entfallen; eine abgeschlossene Emote-Aktion verändert den Anwesenheitsstatus nicht mehr.
- Der Schreibhinweis bleibt eine getrennte, kurzlebige Anzeige und ist kein Teilnehmerstatus.
- Der gesperrte Würfelbutton heißt kompakt „Bitte warten“; die Runde zeigt „Noch nicht aufgefordert“.

## Neu in 0.21.0

- Bis zu acht frei benennbare Gruppen können in der Reihenfolge angelegt werden.
- Jede Gruppe erhält eine Farbe aus einer klar unterscheidbaren Palette: Rot, Blau, Grün, Gelb, Orange, Lila, Türkis oder Weiß.
- Teilnehmer werden direkt in ihrer Reihenfolgezeile einer Gruppe zugewiesen.
- Inaktive Teilnehmernamen übernehmen die Gruppenfarbe; der aktive Emoter bleibt zur eindeutigen Zuganzeige grün.
- Gruppennamen, Farben und Zuweisungen werden zusammen mit der offiziellen Reihenfolge synchronisiert.
- Gruppen bestimmen seit 0.23.0 die Zugfolge, verändern aber weiterhin keine Rechte oder Würfelregeln.

## Vereinfacht in 0.20.2

- Kenntnisse wurden vorerst vollständig aus Navigation und Laufzeit entfernt.
- Das daran gekoppelte Munitionskompendium wurde ebenfalls entfernt.
- Die Würfelübersicht folgt nun direkt auf den Emote-Schreiber.
- Bereits gespeicherte Kenntnisdaten werden nicht gelöscht und bleiben für eine mögliche spätere Rückkehr erhalten.

## Nachgebessert in 0.20.1

- Die aktive Person kann ihren Emote-Zug freiwillig über „Passen“ beenden.
- Emotes und das Wiederholen des letzten Emotes sind nur während des eigenen Zugs möglich.
- Die Zuganzeige verwendet direkt die Namen, beispielsweise `Mannfred [Annila] Egon`.
- Der aktive Name steht grün in Klammern; „Vorheriger“ und „Nächster“ entfallen.

## Funktionen

- Übersicht mit bewusstem Plotstart und kompaktem Laufzeitstatus
- Ziel- und Weltmarkierungen für die Plotleitung
- Synchronisierte Emote-Reihenfolge mit Teilnehmerstatus und Zughinweisen
- Frei benennbare, farbige Gruppen für Teilnehmer
- Emote-Schreiber mit Kanalwahl, Vorschau und Wiederholen-Funktion
- Gemeinsame Würfelübersicht und einfache Würfelaufforderungen

## Vereinfacht in 0.20.0

- Der Schreibstatus wird nur noch für die aktuell emote-berechtigte Person angezeigt.
- Emotes über 1020 Zeichen benötigen eine Freigabe der Plotleitung für den aktuellen Zug.
- Würfeln ist in Ploty erst nach einer Aufforderung der Plotleitung möglich.
- Der aktive Emoter wird in der Reihenfolge grün markiert; die zusätzliche „Aktiv:“-Zeile entfällt.

## Nachgebessert in 0.19.1

- Kompakteres Standardfenster für kleinere Auflösungen und hohe UI-Skalierung.
- Eigenständige Ploty-Schaltflächen statt der farblich unpassenden WoW-Standardknöpfe.
- Würfelergebnisse, Bereiche, Bewertungen und Uhrzeiten in festen, getrennten Spalten.
- Unnötige Scrollleisten werden bei leeren oder kurzen Listen ausgeblendet.
- Ruhigere Panel-Akzente und keine doppelte Ploty-Beschriftung im Fensterrand.

## Neu in 0.19.0

- Feste Seitennavigation statt einer dicht gedrängten Reiterleiste.
- Eigener Seitenkopf mit Titel und kurzer Erklärung für jeden Bereich.
- Gut sichtbare Rollenanzeige für Plotleitung und Teilnehmer.
- Aktive Seite und ungelesene Reihenfolge beziehungsweise Würfelaufforderung sind deutlicher erkennbar.
- Ruhigeres Farbsystem, einheitliche Panel-Akzente und konsistentere Abstände.
- Größerer, weiterhin skalierbarer Inhaltsbereich für Listen und Formulare.

## Wartungsstand 0.18.1

Diese Version konzentriert sich auf Stabilität und Wartbarkeit. Synchronisierung, Rollen- und Rechteerkennung, realmübergreifende Spielernamen, Emote-Zugwechsel und UI-Konsistenz wurden überarbeitet. Es wurden bewusst keine neuen großen Spielsysteme hinzugefügt.

## Installation

Den Ordner `Ploty` nach `World of Warcraft/_retail_/Interface/AddOns/` entpacken und anschließend `/reload` ausführen.

Die Datei muss danach unter `Interface/AddOns/Ploty/Ploty.toc` liegen.

## Bedienung

- `/ploty` öffnet oder schließt das Hauptfenster.
- Ein Linksklick auf den Minimap-Button öffnet Ploty.
- Ein Rechtsklick auf den Minimap-Button würfelt, sobald eine Aufforderung der Plotleitung vorliegt.
- Plotleiterfunktionen werden automatisch anhand der Gruppen- beziehungsweise Raidrechte eingeblendet.
- Die Plotleitung bereitet die Reihenfolge vor und aktiviert sie anschließend in der Übersicht mit „Plot starten“.
- „Gruppen“ im Kopf der Reihenfolge öffnet die Gruppenverwaltung für die Plotleitung.
- Die Gruppenschaltfläche in einer Teilnehmerzeile wechselt per Linksklick vorwärts und per Rechtsklick rückwärts.
