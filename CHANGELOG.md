# Ploty 0.26.9

- Plotstatus wird vor Reihenfolge und Laufzeitdaten übertragen, sodass neue oder neu geladene Clients den ersten Plotstart vollständig übernehmen.
- In Schlachtzügen antwortet nur noch die eindeutige Plotquelle auf Synchronisierungsanfragen; konkurrierende Raidassistenten überschreiben keinen laufenden Plot mehr.
- Ausgewählte Spieler können direkt nach Empfang der Zielauswahl würfeln; der zusätzliche Whisper ist nur noch ein Hinweis und keine technische Voraussetzung.
- Pro Probe zählt nur der erste Wurf im angeforderten Würfelbereich; falsche Bereiche und Wiederholungswürfe werden ignoriert.
- Kurze Gruppenlisten-Lücken bewahren nun auch Anwesenheit, Würfelstände und Auswahlen bis der Gruppenaustritt sicher bestätigt ist.

# Ploty 0.26.8

- Ergebnisse einer Würfelprobe bleiben zunächst zur Auswertung sichtbar.
- Beim Start der nächsten gültigen Probe werden die vorherigen Würfel automatisch und synchronisiert geleert.
- Ungültige oder abgebrochene Aufforderungen verändern vorhandene Ergebnisse nicht.

# Ploty 0.26.7

- „Gewählt“-Buttons im Würfeltab werden nun deutlich grün hervorgehoben.
- Beim Abwählen kehrt der Button sofort in den normalen violetten Stil zurück.

# Ploty 0.26.6

- Sichtbare WoW-Standardscrollleiste samt Pfeilknöpfen aus der Chatbox entfernt.
- Chatbox bis zur rechten Inhaltskante erweitert; sicherer Innenabstand für den Zeilenumbruch bleibt erhalten.
- Längere Emote-Texte bleiben per Mausrad und Cursor-Navigation scrollbar.

# Ploty 0.26.5

- Chatbox bündig verbreitert und den Platz für die außenliegende Scrollleiste korrekt berücksichtigt.
- Aktionsknöpfe übersichtlicher angeordnet, knapper beschriftet und „Emote senden“ als Hauptaktion hervorgehoben.
- Überflüssigen Rahmen und Titel um den Sendebereich entfernt; Status-, Zähler- und Optionszeile sauber ausgerichtet.

# Ploty 0.26.4

- Überflüssigen äußeren Abschnittsrahmen des Emote-Schreibers entfernt; der eigene Rahmen des Textfelds bleibt erhalten.

# Ploty 0.26.3

- Mehrere schnell aufeinanderfolgende Gruppenereignisse können die verzögerte Bereinigung nach einem Gruppenaustritt nicht mehr versehentlich verhindern.
- Beim Verlassen oder Auflösen der Gruppe werden nun auch Würfelaufforderung, ausgewählte Spieler und alte Würfelergebnisse vollständig entfernt.
- Die Bereinigung gruppengebundener Sitzungsdaten ist für laufenden Gruppenaustritt und nächsten Login vereinheitlicht.

# Ploty 0.26.2

- Reihenfolge wird automatisch geleert, sobald der Spieler die WoW-Gruppe beziehungsweise den Raid verlässt oder die Gruppe aufgelöst wird.
- Aktueller Zug, Teilnehmer-Gruppenzuweisungen, Synchronisierungsquelle und laufender Plotzustand werden dabei ebenfalls sauber zurückgesetzt.
- Ein gruppengebundener Altstand wird auch beim nächsten Login entfernt, falls die Gruppe außerhalb der laufenden Sitzung beendet wurde.
- Kurze, vorübergehende Rosterlücken bei Ladebildschirmen lösen keine versehentliche Löschung aus.

# Ploty 0.26.1

- Produktive deutsche Zusammensetzungen werden nun aus bekannten Wörterbuchbestandteilen erkannt, statt fälschlich als unbekannt zu gelten.
- „Wochenende“, „Haustür“, „Wasserflasche“, „Sonnenlicht“ und vergleichbare Komposita werden korrekt akzeptiert.
- Großschreibung zusammengesetzter Hauptwörter richtet sich nach dem letzten, bedeutungsbestimmenden Bestandteil; „wochenende“ wird zu „Wochenende“ vorgeschlagen.
- Fallinformationen speichern nun beide zulässigen Schreibweisen mehrdeutiger Wörter und erzwingen nur eindeutige Fälle.
- Zusätzliche Regressionstests mit vollständigen deutschen Sätzen und gebräuchlichen RP-Komposita ergänzt.

# Ploty 0.26.0

- Deutsches Wörterbuch um Informationen zur üblichen Groß- und Kleinschreibung erweitert.
- Kleingeschriebene Satzanfänge und Nomen sowie eindeutig falsch großgeschriebene Wörter werden direkt rot markiert und mit korrigierter Schreibweise vorgeschlagen.
- `/me`-Kontext berücksichtigt: Die Erzählung darf passend zum vorangestellten Charakternamen klein beginnen; wörtliche Rede in Anführungszeichen beginnt als eigener Satz.
- Mehrdeutige Wortformen werden nicht erzwungen, um zulässige Substantivierungen und Eigennamen nicht unnötig zu beanstanden.
- Grammatik, Abstände und Zeichensetzung bleiben weiterhin außerhalb der Prüfung.

# Ploty 0.25.1

- Zeilenumbruch des Emote-Schreibers an die tatsächliche Breite des Scrollbereichs gebunden.
- Zusätzlichen rechten Innenabstand für Rahmen, Textabstand und Scrollleiste berücksichtigt.
- Veraltete Breitenberechnung beim Größenereignis des Hauptfensters entfernt, durch die Text nach dem Skalieren über den rechten Rand laufen konnte.

# Ploty 0.25.0

- Vollständiges deutsches igerman98/frami-Wörterbuch mit rund 928.000 erzeugten Wortformen lokal integriert.
- Unbekannte Wörter werden direkt im Emote-Schreiber rot markiert; bekannte Tippfehler zeigen weiterhin einen konkreten Vorschlag.
- Teilnehmernamen aus der Reihenfolge und Wörter aus selbst benannten Gruppen werden automatisch von der Markierung ausgenommen.
- Wörterbuch für kurze Ladezeit und geringen Speicherbedarf als kompakter Bloom-Filter gespeichert.
- Wörterbuchquelle, Erzeugungsskript sowie GPLv2- und GPLv3-Lizenztexte vollständig im Addon mitgeliefert.
- Rechtschreibanalyse pro Texteingabe nur einmal ausgeführt, damit der Emote-Schreiber auch bei längeren Texten flüssig bleibt.

# Ploty 0.24.3

- Schreibprüfung auf reine Rechtschreibfehler reduziert; Grammatik, Abstände und Zeichensetzung werden nicht mehr bewertet.
- Erkannte Wörter werden direkt im Emote-Schreiber rot markiert und erhalten im Tooltip einen Korrekturvorschlag, beispielsweise „Halo“ → „Hallo“.
- Namen und unbekannte RP-Begriffe werden nicht pauschal markiert; die Prüfung verwendet bewusst nur bekannte Tippfehler.

# Ploty 0.24.2

- Slash-Emotes können im Emote-Schreiber nur abgeschickt oder wiederholt werden, wenn Say ausgewählt ist; der Sendeknopf bildet diese Einschränkung nun ausdrücklich ab.
- Abschaltbare lokale Schreibprüfung für den Emote-Schreiber ergänzt und bewusst standardmäßig deaktiviert.
- Erkennt häufige deutsche Rechtschreibfehler, doppelte Wörter, mehrfache beziehungsweise falsche Leerzeichen, fehlende Abstände an Satzzeichen, unvollständige Anführungszeichen und ausgewählte Grammatikprobleme.
- Prüfstatus aktualisiert sich beim Schreiben; sämtliche Hinweise stehen im Tooltip und verändern oder blockieren den Text nicht.
- Schreibprüfung arbeitet vollständig lokal ohne externe Verbindung oder Versand des RP-Texts.

# Ploty 0.24.1

- `/me`, `/e`, `/em` und `/emote` werden nun wie im WoW-Chatfeld als echte benutzerdefinierte Emotes verschickt: Ploty entfernt den Slashbefehl und verwendet den Chattyp `EMOTE`.
- Ein Slash-Emote ohne nachfolgenden Text wird vor dem Versand abgefangen.
- Im `/me`-Modus färbt der Emote-Schreiber sämtliche Erzählung orange und wörtliche Rede zwischen geraden oder typografischen Anführungszeichen weiß.
- Wiederholen eines Slash-Emotes behält den korrekten `EMOTE`-Chattyp bei.

# Ploty 0.24.0

- Neue Übersicht vor den Markierungen mit Plotstatus, aktuellem Stand und bewusstem Starten beziehungsweise Beenden durch die Plotleitung.
- Reihenfolge und Gruppen lassen sich vorab lokal vorbereiten; Synchronisierung, Emote-Züge und Würfelaufforderungen beginnen erst mit „Plot starten“.
- Ein Reload der Plotleitung startet keinen Ablauf mehr unbeabsichtigt. Neu geladene Teilnehmer erhalten einen laufenden Plot weiterhin von der aktiven Leitung.
- Ein- und mehrzeilige Textfelder verwenden nun einen einheitlichen dunklen Ploty-Rahmen mit klarer Fokusmarkierung statt des WoW-Standarddesigns.
- `/me`, `/e` und `/emote` sind ausschließlich mit Say möglich. Ploty verhindert einen ungültigen Kanalwechsel und blockiert den Versand über Yell, Gruppe oder Raid mit einer sichtbaren Erklärung.

# Ploty 0.23.6

- „Würfel leeren“ wird nun an alle verbundenen Ploty-Clients synchronisiert.
- Würfellöschungen sind an die aktuelle Probe gebunden und können keine Ergebnisse einer neueren Probe entfernen.
- Sichtbare Bezeichnung „RP-Gruppen“ zu „Gruppen“ verkürzt.
- Erklärende Infotexte unter den vier Seitenüberschriften entfernt und Titel vertikal sauber ausgerichtet.

# Ploty 0.23.5

- Reihenfolge vollständig auf automatische Synchronisierung umgestellt.
- Hinzufügen, Entfernen, Verschieben, Leeren, Importieren sowie sämtliche Gruppenänderungen werden sofort übertragen.
- Leere Reihenfolgen werden nun verbindlich synchronisiert, damit bei anderen Spielern kein alter Stand bestehen bleibt.
- Automatische Kleinständerungen erzeugen keinen unnötigen Chat- oder Benachrichtigungston-Spam.
- Würfelaufforderungen verwenden mit dem Schlachtzugswarnklang nun einen eigenen, klar vom Emote-Zug unterscheidbaren Ton.
- Manueller Sendeknopf als „Erneut senden“ für eine bewusste vollständige Neusynchronisierung beibehalten.

# Ploty 0.23.4

- Weltmarkierungen optisch in dieselbe Reihenfolge wie die Zielmarkierungen gebracht.
- Beide Reihen zeigen nun: Stern, Kreis, Diamant, Dreieck, Mond, Quadrat, Kreuz und Totenkopf.
- Abweichende interne Weltmarker-IDs bleiben korrekt zugeordnet.

# Ploty 0.23.3

- Ziel- und Weltmarker auf eine einheitliche Symbolgröße und identische Abstände gebracht.
- Zielmarkierungen lassen sich nun mit einem erneuten Linksklick auf dasselbe Symbol wieder vom aktuellen Ziel entfernen.
- Rechtsklick bleibt als direkte Möglichkeit zum Entfernen einer Zielmarkierung erhalten.

# Ploty 0.23.2

- Das Löschen einer Gruppe wird nun sofort an alle verbundenen Ploty-Clients übertragen.
- Gelöschte Gruppen und deren alte Teilnehmerzuweisungen verschwinden bei anderen Spielern atomar aus der Reihenfolge.
- Auch das Löschen der letzten vorhandenen Gruppe wird als leerer, verbindlicher Gruppenstand synchronisiert.

# Ploty 0.23.1

- Reihenfolge-Tab um klar getrennte, farbige Gruppenabschnitte ergänzt.
- Jede Kopfzeile zeigt Gruppenposition, Gruppenname und Mitgliederzahl.
- Personen ohne Zuweisung erscheinen gesammelt im Abschnitt „OHNE GRUPPE“.
- Aktive Person bleibt innerhalb der Gruppenblöcke goldfarben hervorgehoben.

# Ploty 0.23.0

- Gruppen zu echten, aufeinanderfolgenden Zugblöcken erweitert.
- Zugfolge arbeitet nun zuerst alle anwesenden Personen einer Gruppe in ihrer internen Reihenfolge ab und springt danach zur ersten Person der nächsten Gruppe.
- Nach der letzten Person der letzten Gruppe beginnt die Folge wieder bei der ersten Gruppe.
- Personen ohne Gruppenzuweisung bilden einen eigenen letzten Block und bleiben vollständig spielberechtigt.
- Gruppenverwaltung um „Hoch“ und „Runter“ für eine frei steuerbare Gruppenreihenfolge ergänzt.
- Teilnehmerbewegung im Reihenfolge-Tab auf die interne Reihenfolge der jeweiligen Gruppe begrenzt.
- Aktive Person bleibt beim Gruppieren sowie beim Verschieben von Gruppen oder Mitgliedern erhalten.
- Gruppen- und Teilnehmerreihenfolge werden weiterhin gemeinsam und abwärtskompatibel synchronisiert.
- Datenbankschema auf 32 angehoben.

# Ploty 0.22.1

- Anwesenheitsstatus farblich eindeutig getrennt: „Anwesend“ grün, „Abwesend“ rot.
- Statusschaltflächen passend eingefärbt und auch bei eingeschränkten Rechten klar lesbar gehalten.
- Aktuelle Person im Reihenfolge-Tab von Grün auf eine goldene Hervorhebung umgestellt.
- Grüne, vergrößerte Aktivmarkierung im Emote-Schreiber unverändert beibehalten.

# Ploty 0.22.0

- Globale Würfelrunden durch gezielte Würfelaufforderungen ersetzt.
- Plotleitung kann einzelne oder mehrere Gruppenmitglieder direkt in der Würfelübersicht auswählen.
- Neue Aktion „Auswahl auffordern“ benachrichtigt ausschließlich die gewählten Spieler.
- Ergebnisfortschritt und Fehlanzeige berücksichtigen nur die aktuelle Auswahl, nicht mehr die gesamte Gruppe.
- Würfe nicht ausgewählter Gruppenmitglieder werden aus der aktuellen Ploty-Probe herausgehalten.
- Ausgewählte Spieler und Ergebnisse werden realmgenau sowie atomar synchronisiert.
- Wiederverbindung einer noch ausstehenden ausgewählten Person erneuert deren Aufforderung automatisch.
- Datenbankschema auf 31 angehoben.

# Ploty 0.21.4

- Verzichtbaren Bedienhinweis am unteren Rand der Seitenleiste entfernt.
- Linke Navigation dadurch optisch beruhigt und auf die eigentlichen Reiter konzentriert.

# Ploty 0.21.3

- Große Hervorhebung auf die Namensfolge im Emote-Schreiber beschränkt.
- Reihenfolgeliste wieder auf ein einheitliches, kompaktes Schrift- und Zeilenraster zurückgestellt.
- Aktive Person in der Reihenfolgeliste weiterhin ausschließlich grün markiert.

# Ploty 0.21.2

- Namen der aktuell aktiven Person in der Namensfolge des Emote-Schreibers und in der Teilnehmerliste deutlich vergrößert.
- Aktive Zeile für die größere Schrift erhöht; inaktive Zeilen bleiben kompakt.
- Vorheriger und nächster Name bleiben kompakt neben dem großen, grün geklammerten aktiven Namen sichtbar.
- Beide Hervorhebungen wechseln beim Fortschalten automatisch zur neuen aktiven Person.

# Ploty 0.21.1

- Teilnehmerstatus auf die beiden Zustände „Anwesend“ und „Abwesend“ reduziert.
- Veraltete Zustände „Fertig“ und „Übersprungen“ beim Laden sicher migriert.
- Schreibaktivität vom Anwesenheitsstatus getrennt; der separate Schreibhinweis bleibt erhalten.
- Deaktivierten Würfelbutton von „Warte auf Aufforderung“ zu „Bitte warten“ verkürzt.
- Datenbankschema auf 30 angehoben.

# Ploty 0.21.0

- Frei benennbare Gruppen mit acht auswählbaren Farben ergänzt.
- Kompakten Gruppenverwaltungsdialog im Kopf der Reihenfolge ergänzt.
- Direkte Gruppenzuweisung pro Teilnehmerzeile mit Vorwärts-/Rückwärtsschaltung ergänzt.
- Inaktive Teilnehmernamen und Gruppenfelder farblich markiert; aktiven Namen weiterhin eindeutig grün gehalten.
- Atomare, berechtigungsgeprüfte Synchronisierung von Gruppendefinitionen und Teilnehmerzuweisungen ergänzt.
- Gruppenübertragung auf WoWs 255-Byte-Grenze begrenzt und auf acht Gruppen sowie 80 Zuweisungen beschränkt.
- Datenbankschema auf 29 angehoben.

# Ploty 0.20.2

- Kenntnisse und Munitionskompendium vorerst vollständig aus TOC, Navigation und Laufzeit entfernt.
- Nicht mehr benötigte Moduldateien aus dem Addonpaket entfernt.
- Würfelseite wieder fest auf Navigationsposition vier gelegt und veraltete Kenntnis-Slashbefehle entfernt.
- Zielwertprüfung der Würfelrunde an Würfe ohne Kenntnisbonus angepasst.
- Vorhandene SavedVariables mit früheren Kenntnisdaten bleiben unangetastet.

# Ploty 0.20.1

- Freiwillige „Passen“-Aktion für die aktuell aktive Person ergänzt.
- Emote-Versand und Wiederholen außerhalb des eigenen Zugs in Logik und UI gesperrt.
- Kompakte Zuganzeige auf direkte Namensfolge mit grün geklammertem aktiven Namen umgestellt.
- Selbstbezeichnung „Du“ in der Zugfolge durch den tatsächlichen Charakternamen ersetzt.

# Ploty 0.20.0

- Schreibstatus an den aktiven Emote-Zug gebunden und veraltete Sitzungszustände beim Login entfernt.
- Persistenten Langtext-Schalter durch Anfrage, Freigabe oder Ablehnung der Plotleitung ersetzt.
- Langtext-Freigabe auf den aktuellen Emote-Zug begrenzt und nach Versand verbraucht.
- Ploty-Würfe vollständig an eine offene Würfelaufforderung gebunden; Direktaufrufe und Minimap-Rechtsklick respektieren dieselbe Regel.
- Kenntnisse-Seite in eine Listenansicht mit Umschaltung für eigene und geteilte Kenntnisse sowie ein bedarfsgesteuertes Formular umgebaut.
- Separate „Aktiv:“-Anzeige entfernt und aktive Person in der Reihenfolge grün hervorgehoben.
- Datenbankschema auf 28 und Addonversion auf 0.20.0 angehoben.

# Ploty 0.19.2

- Munitionskompendium aus dem Kenntnisformular in den Seitenkopf verschoben.
- Breiten Textknopf durch einen kontextbezogenen Info-Button ersetzt.
- Button und reservierter Untertitelplatz werden nur auf der Kenntnisse-Seite eingeblendet.

# Ploty 0.19.1

- Fenster nach dem ersten 0.19.1-Start einmalig auf 880 × 660 skaliert; anschließend bleiben manuelle Größen erhalten.
- Mindestgröße auf ein praxistaugliches kompaktes Raster reduziert.
- Rote WoW-Standardbuttons durch dunkle Ploty-Buttons mit einheitlichen Aktiv-, Hover- und Deaktiviertzuständen ersetzt.
- Würfelkopf in echte Spalten zerlegt und Ergebnis-/Zeitspalten verbreitert.
- Überflüssige Scrollleisten bei kurzen Listen ausgeblendet.
- Panel-Akzentlinien abgeschwächt und doppelten Fenstertitel entfernt.

# Ploty 0.19.0

- Hauptnavigation in eine feste, vertikale Seitenleiste verschoben.
- Dynamischen Seitenkopf mit Titel und Kurzbeschreibung ergänzt.
- Sichtbare Rollenanzeige für Plotleitung und Teilnehmer ergänzt.
- Aktive Navigation, Hover-Zustände und ungelesene Hinweise vereinheitlicht.
- Fensterbreite und Mindestgröße an den neuen Inhaltsbereich angepasst.
- Panel-Hintergründe, Rahmenfarben und Akzentlinien konsistent gestaltet.
- Bestehende Seiten ohne neue Spielmechanik in das neue Layout übernommen.

# Ploty 0.18.1

- Gemeinsame Hilfsfunktionen in `Util.lua` gebündelt und Versions-/Datenbankwerte zentralisiert.
- Realmübergreifende Spielernamen werden bei Rollenprüfung, Würfeln, Status und Synchronisierung eindeutig behandelt.
- Emote-Zugbenachrichtigung nach einem synchronisierten Zugwechsel wiederhergestellt.
- Doppelte Fortschaltung beim Setzen des aktiven Teilnehmers auf „Abwesend“ behoben.
- Zeilenumbrüche im Emote-Schreiber werden durch Leerzeichen ersetzt, damit Wörter nicht mehr zusammenlaufen.
- Eingehende Reihenfolgen und Addon-Nachrichten werden strenger validiert und begrenzt.
- Veraltete Textbibliotheks-Daten und nicht mehr verwendete UI-Logik entfernt.
- Sichtbarkeit von Kenntnissen respektiert: „Nur ich“ bleibt lokal, „Plotleitung“ wird nur an berechtigte Empfänger gesendet.
- Veraltete oder ungültige Kenntnis-Würfelzusätze werden nicht mehr auf spätere Würfe angewendet.
- Kenntnis- und Munitionsnachrichten bleiben sicher innerhalb der WoW-Payload-Grenze.
- Kenntnisse-UI an die gemeinsamen Bedienelemente angeglichen; Munitionskompendium passt Zeilenhöhen an den Inhalt an.
- Weltmarker-Zuordnung für WoW 9.2.7 dokumentiert und explizit beibehalten.

# Ploty 0.18.0

- Munitionskompendium hinzugefügt.
- Alle vorgegebenen Pfeile, Bolzen und Geschosse erhalten Beschreibungen.
- Typische Einsatzgebiete und Einschränkungen ergänzt.
- Kompendium über den Reiter Kenntnisse erreichbar.
- Zusätzlicher Tooltip an der Munitionsauswahl.
