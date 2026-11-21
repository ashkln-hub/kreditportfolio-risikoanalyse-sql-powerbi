# Anleitung: Power-BI-Dashboard aufbauen

Der fertige Bericht liegt als `powerbi/Kreditportfolio_Dashboard.pbix` bei. Diese Anleitung beschreibt,
wie er aufgebaut ist – zum Nachvollziehen oder zum Nachbauen von Grund auf (ca. 3 Stunden).
Menüpfade stehen auf Deutsch, die englische Bezeichnung in Klammern.

> Die aktuelle Fassung aller Measures steht in `powerbi/measures.dax` (36 Measures, identisch mit dem Modell),
> u. a. *Expected Loss* (lebende Kredite), *Verlust Ausfall* (Stufe 3), *Verlust gesamt*, *Effekt Verzugs-PD*
> und *Marge nach Risikokosten* mit Variante *ohne Stressfenster*.

Alle Daten liegen fertig in `powerbi/daten/` (erzeugt von `src/02_sql_pipeline.py`). Alle Annahmen
(Refinanzierung, PD-Floor, Diskontsatz, Stressfenster) stehen in `sql/00_annahme.sql` und kommen über die
CSV-Dateien ins Modell. In DAX ist keine Annahme fest eingetragen.

---

## Schritt 0 – Vorbereitung

1. **Power BI Desktop** kostenlos aus dem Microsoft Store installieren.
2. Power BI öffnen → **Datei → Optionen und Einstellungen → Optionen → Aktuelle Datei → Regionale Einstellungen**
   (*File → Options and settings → Options → Current file → Regional settings*)
   → *Gebietsschema für Import* (*Locale for import*) auf **Englisch (USA)** stellen.
   *Grund:* Die CSV-Dateien verwenden den Punkt als Dezimaltrennzeichen. Mit deutschem Gebietsschema würde
   Power BI `24628.29` als 2.462.829 lesen.
3. **Ansicht → Designs → Nach Designs suchen** (*View → Themes → Browse for themes*) →
   `powerbi/theme_kreditportfolio.json` laden.

## Schritt 1 – Daten laden

**Start → Daten abrufen → Text/CSV** (*Home → Get data → Text/CSV*) und nacheinander alle neun Dateien aus
`powerbi/daten/` laden (jeweils **Laden** / *Load*, nicht *Daten transformieren*):

| Datei | Typ | Inhalt |
|---|---|---|
| `dim_datum.csv` | Dimension | Monatsultimos 01/2021 – 09/2026 |
| `dim_produkt.csv` | Dimension | Ratenkredit, Autokredit, Baufinanzierung |
| `dim_region.csv` | Dimension | Sechs Regionen in Niedersachsen |
| `dim_rating.csv` | Dimension | Ratingklasse 1–10 mit Risikoband |
| `fact_bestand_monat.csv` | Fakten | Restschuld je Monat × Produkt × Region × Rating × Verzugsstatus |
| `fact_neugeschaeft.csv` | Fakten | Neugeschäft je Auszahlungsmonat |
| `fact_vintage.csv` | Fakten | Kumulierte Ausfälle je Jahrgang und Laufzeitmonat |
| `fact_expected_loss.csv` | Fakten | EAD, PD, LGD, EL zum 30.09.2026 je Stufe (1 vertragsgemäß, 2 Rückstand, 3 Ausfall) |
| `fact_risikokosten.csv` | Fakten | PD, LGD, Refinanzierung und Risikokosten je Produkt und Ratingklasse (Marge nach Risikokosten) |

**Datentypen prüfen** (Tabellenansicht, Spalte markieren → *Spaltentools* / *Column tools*):
- alle Spalten `datum` → **Datum** (*Date*)
- `restschuld`, `volumen`, `ead`, `expected_loss` → **Dezimalzahl** (*Decimal number*)
- `pd_12m`, `pd_rating`, `pd_rating_roh`, `lgd`, `lgd_nominal`, `risikokosten`, `refinanzierung` → **Dezimalzahl**
- `ratingklasse`, `jahrgang`, `monate_seit_auszahlung`, `stufe` → **Ganze Zahl** (*Whole number*)

**Sortierung:** In `dim_datum` die Spalte `monat_jahr` markieren → *Nach Spalte sortieren* (*Sort by column*) →
`monat_sort`. In `dim_rating` die Spalte `risikoband` → *Nach Spalte sortieren* → `risikoband_sortierung`.

## Schritt 2 – Datenmodell (Sternschema)

In der **Modellansicht** (*Model view*) folgende Beziehungen anlegen (Spalte von der Dimension auf die
Faktentabelle ziehen; Kardinalität **1:n**, Filterrichtung **einfach** / *Single*):

| Dimension | Faktentabelle(n) | Schlüssel |
|---|---|---|
| `dim_datum` | `fact_bestand_monat`, `fact_neugeschaeft`, `fact_expected_loss` | `datum` |
| `dim_produkt` | alle fünf Faktentabellen | `produkt` |
| `dim_region` | `fact_bestand_monat`, `fact_neugeschaeft`, `fact_expected_loss` | `region` |
| `dim_rating` | `fact_bestand_monat`, `fact_neugeschaeft`, `fact_expected_loss`, `fact_risikokosten` | `ratingklasse` |

```
               dim_datum        dim_produkt
                   │  ╲            │
                   │   ╲           │
 dim_region ── fact_bestand_monat ─┤── fact_vintage
       │           │               │
       ├──── fact_neugeschaeft ────┤
       │                           │
       └──── fact_expected_loss ───┤
                   │               │
               dim_rating ── fact_risikokosten
```

`fact_risikokosten` hat keine Beziehung zu `dim_datum` und `dim_region`: Die Risikokosten gelten je Produkt und
Ratingklasse, unabhängig von Monat und Region.

Danach alle Schlüsselspalten in den Faktentabellen **ausblenden** (Rechtsklick → *In Berichtsansicht
ausblenden* / *Hide in report view*), damit im Bericht nur die Dimensionen als Filter verwendet werden.
Die Spalte `fact_expected_loss[stufe]` sichtbar lassen, sie eignet sich als Zeile in einer Matrix.

## Schritt 3 – Measures anlegen

1. **Start → Daten eingeben** (*Home → Enter data*) → leere Tabelle mit dem Namen `_Measures` laden.
2. Jedes Measure aus `powerbi/measures.dax` einzeln anlegen: Tabelle `_Measures` markieren →
   **Neues Measure** (*New measure*) → Code einfügen → Format wie im Kommentar angegeben einstellen
   (*Measuretools → Format* / *Measure tools → Format*).
3. Die Hilfsspalte `Spalte1` in `_Measures` löschen – die Tabelle wandert dann als Measure-Tabelle nach oben.

Wichtig für das Verständnis:
- `EAD`, `Expected Loss`, `PD gewichtet`, `LGD gewichtet` und `EL-Quote` zählen nur **lebende Kredite**
  (Stufe 1 + 2, Filter `stufe < 3`). Ausgefallene Kredite stehen in `EAD Ausfall` und `Verlust Ausfall`.
- `Risikokosten` liest PD × LGD je Ratingklasse aus `fact_risikokosten` (identisch mit `sql/08`). Über mehrere
  Ratingklassen wird mit dem Neugeschäftsvolumen gewichtet.

## Schritt 4 – Berichtsseiten

Auf jeder Seite oben eine **Filterleiste** mit drei Datenschnitten (*Slicer*): `dim_datum[datum]` (Typ *Zwischen*
/ *Between*), `dim_produkt[produkt]` und `dim_region[region]` (Typ *Dropdown*). Tipp: Datenschnitte über
**Ansicht → Datenschnitte synchronisieren** (*View → Sync slicers*) auf alle Seiten übertragen.

**Seitengröße:** Seite *Risikoentwicklung* 1280 × 840, Seite *Expected Loss & Pricing* 1280 × 900, die anderen
1280 × 720. Einstellen über **Visualisierungen → Seite formatieren (Pinsel) → Canvaseinstellungen → Typ:
Benutzerdefiniert, Höhe** (*Visualizations → Format page → Canvas settings → Type: Custom, Height*).

### Seite 1 – Portfolioübersicht

```
┌──────────────────────────── Filter: Zeitraum | Produkt | Region ────────────────────────────┐
│ [Bestand Stichtag] [Anzahl Kredite] [Zins volumengew.] [NPL-Quote Stichtag] [Expected Loss] │
├──────────────────────────────────────────────┬───────────────────────────────────────────────┤
│ Bestand nach Produkt im Zeitverlauf          │ Bestand nach Region (Stichtag)                │
│ (gestapeltes Flächendiagramm)                │ (gruppiertes Balkendiagramm)                  │
├──────────────────────────────────────────────┼───────────────────────────────────────────────┤
│ Neugeschäft nach Jahr und Produkt            │ Bestand nach Risikoband (Stichtag)            │
│ (gestapeltes Säulendiagramm)                 │ (Säulendiagramm)                              │
└──────────────────────────────────────────────┴───────────────────────────────────────────────┘
```

| Visual | Felder |
|---|---|
| 5 × **Karte** (*Card*) | `Bestand Stichtag`, `Anzahl Kredite Stichtag`, `Zins volumengewichtet Stichtag`, `NPL-Quote Stichtag`, `Expected Loss` (Anzeigename „Expected Loss (lebend, 12 M)“) |
| **Gestapeltes Flächendiagramm** (*Stacked area chart*) | X: `dim_datum[datum]` · Y: `Bestand` · Legende: `dim_produkt[produkt]` |
| **Gruppiertes Balkendiagramm** (*Clustered bar chart*) | Y: `dim_region[region]` · X: `Bestand Stichtag` |
| **Gestapeltes Säulendiagramm** (*Stacked column chart*) | X: `dim_datum[jahr]` · Y: `Neugeschäft Volumen` · Legende: `dim_produkt[produkt]` |
| **Säulendiagramm** (*Clustered column chart*) | X: `dim_rating[risikoband]` · Y: `Bestand Stichtag` |

Anzeigename eines Felds ändern: im Bereich *Visualisierungen* beim Feld auf den Pfeil → **Für dieses Visual
umbenennen** (*Rename for this visual*).

### Seite 2 – Risikoentwicklung

```
┌───────────────────── Filter ─────────────────────┐
│ [NPL-Quote] [NPL-Quote VJ] [Veränderung] [NPL-Volumen] │
├──────────────────────────────┬───────────────────┤
│ NPL-Quote und Verzugsquote   │ NPL-Volumen       │
│ (Liniendiagramm)             │ (Liniendiagramm)  │
├──────────────────────────────┼───────────────────┤
│ Verzugsstatus nach Produkt   │ NPL-Quote nach    │
│ (Matrix)                     │ Region (Balken)   │
├──────────────────────────────┴───────────────────┤
│ Textfeld „Einordnung“                             │
└──────────────────────────────────────────────────┘
```

| Visual | Felder |
|---|---|
| **Liniendiagramm** (*Line chart*), links | X: `dim_datum[datum]` · Y: `NPL-Quote` und `Verzugsquote 30+` |
| **Liniendiagramm** (*Line chart*), rechts, **neu** | X: `dim_datum[datum]` · Y: `NPL Volumen` (Anzeigename „NPL-Volumen“) · Titel „NPL-Volumen im Zeitverlauf (seit 2025 seitwärts)“ |
| 4 × **Karte** | `NPL-Quote Stichtag`, `NPL-Quote Vorjahr`, `NPL-Quote Veränderung VJ (pp)`, `NPL Volumen Stichtag` |
| **Matrix** | Zeilen: `dim_produkt[produkt]` · Spalten: `fact_bestand_monat[verzugsstatus]` · Werte: `Anteil am Bestand` |
| **Balkendiagramm** | Y: `dim_region[region]` · X: `NPL-Quote Stichtag` (absteigend sortiert) |
| **Textfeld** (*Text box*), **neu** | Einordnung der NPL-Quote, siehe unten |

Klickpfad für das neue Liniendiagramm: leere Stelle im Bericht anklicken → **Visualisierungen → Liniendiagramm**
(*Visualizations → Line chart*) → `dim_datum[datum]` auf **X-Achse** (*X-axis*), Measure `NPL Volumen` auf
**Y-Achse** (*Y-axis*) ziehen → **Visual formatieren → Allgemein → Titel** (*Format visual → General → Title*)
Text eintragen. Das bestehende linke Liniendiagramm dafür auf 760 px Breite verkleinern
(**Visual formatieren → Allgemein → Eigenschaften → Größe** / *Format visual → General → Properties → Size*).

Klickpfad für das Textfeld: **Einfügen → Textfeld** (*Insert → Text box*), Inhalt:

> **Einordnung: Die NPL-Quote sinkt seit 07/2024, das NPL-Volumen ist seit 2025 seitwärts bei 7 bis 8 Mio. €**
> Das NPL-Volumen stieg ab 07/2024 und bewegt sich seit 2025 zwischen rund 7 und 8 Mio. € (09/2025: 7,69,
> 09/2026: 7,28 Mio. €). Die Quote fällt vor allem, weil der Bestand wächst.
> • Nennereffekt: Der Bestand wuchs von 474 auf 715 Mio. €, das NPL-Volumen von 6,75 auf 7,28 Mio. €. Bei
> konstantem Bestand von 07/2024 läge die Quote heute bei 1,54 % statt 1,02 %.
> • Seasoning: Neue Kredite fallen erst nach einigen Monaten aus. Ein schnell wachsender Bestand enthält viele
> junge Kredite, die die Quote vorübergehend drücken.
> • Abgang: Ausgefallene Kredite verlassen den Bestand nach Ende der Verwertung (Raten 18, Auto 6, Bau 24 Monate).
> In den letzten 12 Monaten gingen 6,1 Mio. € NPL ab.
> Wachstumsneutrale Sicht: Vintage-Kurven (Seite 3) vergleichen Jahrgänge bei gleichem Kreditalter.

**Bedingte Formatierung:** In der Karte `NPL-Quote Veränderung VJ (pp)` → *Datenbeschriftung → Farbe → fx*
(*Callout value → Color → fx*): Regel `> 0` = Rot (`#e34948`), `<= 0` = Grün (`#1baf7a`).

### Seite 3 – Vintage-Analyse

| Visual | Felder |
|---|---|
| **Liniendiagramm** | X: `fact_vintage[monate_seit_auszahlung]` (Typ *kontinuierlich* / *Continuous*) · Y: `Ausfallrate kumuliert` · Legende: `fact_vintage[jahrgang]` |
| **Matrix** | Zeilen: `fact_vintage[jahrgang]` · Spalten: `fact_vintage[monate_seit_auszahlung]` (Filter: 12, 24, 36) · Werte: `Ausfallrate kumuliert` |
| **Textfeld** | Kernaussagen, darunter: „Die Analyse findet den im Generator eingebauten Stressaufschlag (×1,25 für Auszahlungen 07/2022–12/2023) korrekt wieder. Die Daten sind synthetisch, das ist kein Befund über reale Zinsen oder Inflation.“ |

Für diese Seite den Datenschnitt *Produkt* durch einen Seitenfilter **Ratenkredit + Autokredit** ersetzen
(Baufinanzierung hat zu wenige Ausfälle für stabile Kurven).

### Seite 4 – Expected Loss & Pricing

```
┌─────────────────────────────── Filter ───────────────────────────────┐
│ [EAD lebend] [PD gewichtet] [LGD ökonomisch] [EL lebend] [EL-Quote]  │
│ [Ausfallvolumen] [Verlust Ausfälle] [Verlust gesamt] [Effekt Verzugs-PD] [LGD nominal] │
├──────────────────────────────────────┬───────────────────────────────┤
│ Matrix Expected Loss lebender Kredite│ Marge nach Risikokosten       │
│ nach Produkt und Risikoband          ├───────────────────────────────┤
│                                      │ Expected Loss nach Produkt    │
├──────────────────────────────────────┴───────────────────────────────┤
│ Textfeld: Definition der Marge, Stufen, Annahmen                     │
└──────────────────────────────────────────────────────────────────────┘
```

| Visual | Felder |
|---|---|
| 5 × **Karte**, Zeile 1 | `EAD` („EAD lebend (Stufe 1+2)“), `PD gewichtet` („PD gewichtet (inkl. Verzugs-PD)“), `LGD gewichtet` („LGD ökonomisch“), `Expected Loss` („EL lebend (12 Monate)“), `EL-Quote` |
| 5 × **Karte**, Zeile 2, **neu** | `EAD Ausfall` („Ausfallvolumen (Stufe 3)“), `Verlust Ausfall` („Verlust Ausfälle (Stufe 3)“), `Verlust gesamt` („Verlust gesamt (Stufe 1–3)“), `Effekt Verzugs-PD` („davon Effekt Verzugs-PD“), `LGD nominal gewichtet` („LGD nominal (Vergleich)“) |
| **Matrix** | Zeilen: `dim_produkt[produkt]`, darunter `dim_rating[risikoband]` · Werte: `EAD`, `PD gewichtet (roh)` („Rating-PD vor Floor“, **neu**), `PD gewichtet`, `LGD gewichtet`, `Expected Loss`, `EL-Quote` |
| **Gruppiertes Säulendiagramm** | X: `dim_rating[ratingklasse]` · Y: `Marge nach Risikokosten` und `Marge nach Risikokosten ohne Stressfenster` (**neu**) · Filter: `dim_datum[jahr]` = 2024, 2025, 2026 und `dim_produkt[produktgruppe]` = Konsumentenkredit |
| **Gruppiertes Balkendiagramm** | Y: `dim_produkt[produkt]` · X: `Expected Loss` |
| **Textfeld**, **neu** | Definition der Marge nach Risikokosten (ohne Betriebs- und Eigenkapitalkosten), Hinweis, dass das Vorzeichen in Klasse 9 nicht bestimmbar ist, Hinweis zu Stufe 2 und 3 |

Klickpfad für die neuen Karten: **Visualisierungen → Karte** (*Visualizations → Card*) → Measure auf **Felder**
(*Fields*) ziehen → **Visual formatieren → Visual → Beschriftungswert → Anzeigeeinheiten: Millionen,
Dezimalstellen: 2** (*Format visual → Visual → Callout value → Display units: Millions, Value decimal places: 2*).
Für `LGD nominal gewichtet` die Anzeigeeinheit auf *Keine* (*None*) lassen.

Klickpfad für die zweite Reihe im Margendiagramm: Diagramm markieren → Measure
`Marge nach Risikokosten ohne Stressfenster` zusätzlich auf **Y-Achse** (*Y-axis*) ziehen. Beide Measures
erscheinen dann als gruppierte Säulen nebeneinander.

Klickpfad für die rohe PD in der Matrix: Matrix markieren → `PD gewichtet (roh)` auf **Werte** (*Values*) vor
`PD gewichtet` ziehen.

## Schritt 5 – Prüfen

Mit Filter **Stichtag 30.09.2026, alle Produkte, alle Regionen** müssen diese Werte erscheinen
(sie stammen aus den SQL-Ergebnissen in `ergebnisse/ERGEBNISSE.md`):

| Kennzahl | Sollwert |
|---|---|
| Bestand Stichtag | ≈ 714,8 Mio. € |
| EAD lebend + Ausfallvolumen | 707,5 + 7,28 = 714,8 Mio. € |
| NPL-Quote Stichtag | ≈ 1,02 % |
| NPL-Volumen Stichtag | ≈ 7,28 Mio. € |
| Expected Loss (lebend) | ≈ 1,76 Mio. € |
| EL-Quote | ≈ 0,248 % |
| Verlust Ausfälle | ≈ 2,22 Mio. € |
| Verlust gesamt | ≈ 3,98 Mio. € (= 1,76 + 2,22) |
| Marge nach Risikokosten Klasse 9 / 10 | −0,19 % / −4,56 % (ohne Stressfenster +0,08 % / −5,12 %) |

Weicht ein Wert stark ab, zuerst Schritt 0 (Gebietsschema) und die Beziehungen in Schritt 2 prüfen.

## Schritt 6 – Speichern und auf GitHub veröffentlichen

1. **Datei → Speichern unter** (*File → Save as*) → `powerbi/Kreditportfolio_Dashboard.pbix`
2. **Datei → Exportieren → In PDF exportieren** (*File → Export → Export to PDF*) → als
   `powerbi/Kreditportfolio_Dashboard.pdf` speichern.
3. Von jeder Seite einen Screenshot der ganzen Seite mit Datenschnitten im Standardzustand als PNG speichern
   (oder die Seiten der PDF als PNG exportieren):
   `powerbi/screenshots/01_portfolioubersicht.png`, `02_risikoentwicklung.png`, `03_vintage_analyse.png`,
   `04_expected_loss_pricing.png`
4. In PowerShell im Projektordner:

```powershell
git add powerbi/
git commit -m "Power-BI-Dashboard aktualisiert"
git push
```
