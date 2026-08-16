Deutsches Wörterbuch in Ploty
=============================

Ploty verwendet das deutsche igerman98/frami-Hunspell-Wörterbuch
(Version 20161207+frami20170109) als Grundlage der lokalen Rechtschreibprüfung.

Quelle:
https://github.com/LibreOffice/dictionaries/tree/master/de

Urheber:
- Björn Jacke <bjoern@j3e.de> (Grundwörterbuch)
- Franz Michael Baumann <fm.baumann@uni-muenster.de> (frami-Erweiterung)

Lizenz:
GNU General Public License, Version 2 oder Version 3. Die vollständigen
Lizenztexte liegen als COPYING_GPLv2 und COPYING_GPLv3 in diesem Ordner.

Die Datei GermanDictionary.lua im Ploty-Hauptordner ist eine für WoW erzeugte,
speichersparende Bloom-Filter-Darstellung der Wörter, ihrer üblichen Groß- und
Kleinschreibung und der aus den Hunspell-Affixregeln erzeugten Wortformen.
Produktive deutsche Zusammensetzungen werden zur Laufzeit aus bekannten
Wortbestandteilen geprüft. Die unveränderten Quelldateien
de_DE_frami.dic und de_DE_frami.aff sowie das verwendete Erzeugungsskript
generate-german-dictionary.js liegen ebenfalls in diesem Ordner.

Der Bloom-Filter kann theoretisch ein unbekanntes Wort irrtümlich akzeptieren,
markiert aber niemals ein enthaltenes Wörterbuchwort als unbekannt.
