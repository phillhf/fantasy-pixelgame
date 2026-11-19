# FantasyPixelgame (Arbeitstitel)

Ein klassisches Rollenspiel im Pixelstil: Karte von oben, rundenbasierte Kämpfe in Seitenansicht.
Das Spiel erscheint in Kapiteln für Windows, Linux und Android.

**Stand:** Prototyp 0.1 mit Platzhaltergrafik.

## Was der Prototyp kann

- Titelbild, Namenseingabe für den Helden
- Weltkarte (Holtmark) und ein Dorf (Erlenfurt) mit Gesprächen
- Zufallskämpfe in Seitenansicht: Angreifen, Fähigkeiten, Gegenstände, Verteidigen, Fliehen
- Fluchtregel: Ist die Gruppe 10 oder mehr Stufen über den Gegnern, fliehen diese
- Magie als Ausdauer: Kraft (KP) kommt durch Essen und Rasten zurück, Überanstrengung kostet Lebenspunkte
- Gasthaus, Händler, Schreine zum Speichern
- Steuerung mit Tastatur, Controller und Touch

## Steuerung

| Aktion | Tastatur | Controller |
|---|---|---|
| Laufen / Auswahl | Pfeiltasten oder WASD | Steuerkreuz / linker Stick |
| Bestätigen, Reden | Enter, Leertaste oder Z | A |
| Zurück, Menü | Esc, Rücktaste oder X | B |

Auf dem Handy erscheinen Steuerkreuz und Knöpfe auf dem Bildschirm. Menüeinträge kann man direkt antippen.

## Inhalte ändern

Alle Spielinhalte liegen als Textdateien in `data/`:

- `config.json` – Grundeinstellungen (Startgold, Fluchtregel, Tempo)
- `dialogs.json` – alle Texte
- `enemies.json`, `items.json`, `skills.json`, `heroes.json` – Werte
- `maps/*.json` – Karten, ein Zeichen pro Feld (Bedeutung in `tiles.json`)

## Herunterladen

Fertige Versionen stehen unter [Releases](../../releases). Jeder Build auf `main` liegt außerdem als Artefakt unter [Actions](../../actions).

## Technik

Godot 4.7, Builds über GitHub Actions. Vor jedem Export läuft ein automatischer Spieltest (`tools/autotest.gd`).
