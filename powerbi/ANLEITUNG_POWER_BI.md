# Anleitung: Power-BI-Dashboard aufbauen

Zeitaufwand: ca. 2–3 Stunden. Ergebnis: ein Bericht mit vier Seiten, gespeichert als
`powerbi/Kreditportfolio_Dashboard.pbix`, plus Screenshots für das README.

Alle Daten liegen fertig in `powerbi/daten/` (erzeugt von `src/02_sql_pipeline.py`).

---

## Schritt 0 – Vorbereitung

1. **Power BI Desktop** kostenlos aus dem Microsoft Store installieren.
2. Power BI öffnen → **Datei → Optionen und Einstellungen → Optionen → Aktuelle Datei → Regionale Einstellungen**
   → *Gebietsschema für Import* auf **Englisch (USA)** stellen.
   *Grund:* Die CSV-Dateien verwenden den Punkt als Dezimaltrennzeichen. Mit deutschem Gebietsschema würde
   Power BI `24628.29` als 2.462.829 lesen.
3. **Ansicht → Designs → Nach Designs suchen** → `powerbi/theme_kreditportfolio.json` laden.

## Schritt 1 – Daten laden

**Start → Daten abrufen → Text/CSV** und nacheinander alle acht Dateien aus `powerbi/daten/` laden
(jeweils **Laden**, nicht *Daten transformieren*):

| Datei | Typ | Inhalt |
|---|---|---|
| `dim_datum.csv` | Dimension | Monatsultimos 01/2021 – 09/2026 |
| `dim_produkt.csv` | Dimension | Ratenkredit, Autokredit, Baufinanzierung |
| `dim_region.csv` | Dimension | Sechs Regionen in Niedersachsen |
| `dim_rating.csv` | Dimension | Ratingklasse 1–10 mit Risikoband |
| `fact_bestand_monat.csv` | Fakten | Restschuld je Monat × Produkt × Region × Rating × Verzugsstatus |
| `fact_neugeschaeft.csv` | Fakten | Neugeschäft je Auszahlungsmonat |
| `fact_vintage.csv` | Fakten | Kumulierte Ausfälle je Jahrgang und Laufzeitmonat |
| `fact_expected_loss.csv` | Fakten | EAD, PD, LGD, EL zum 30.09.2026 |

**Datentypen prüfen** (Tabellenansicht, Spalte markieren → *Spaltentools*):
- alle Spalten `datum` → **Datum**
- `restschuld`, `volumen`, `ead`, `expected_loss` → **Dezimalzahl**
- `pd_12m`, `lgd` → **Dezimalzahl**
- `ratingklasse`, `jahrgang`, `monate_seit_auszahlung` → **Ganze Zahl**

**Sortierung:** In `dim_datum` die Spalte `monat_jahr` markieren → *Nach Spalte sortieren* → `monat_sort`.
In `dim_rating` die Spalte `risikoband` → *Nach Spalte sortieren* → `risikoband_sortierung`.

## Schritt 2 – Datenmodell (Sternschema)

In der **Modellansicht** folgende Beziehungen anlegen (Spalte von der Dimension auf die Faktentabelle ziehen;
Kardinalität **1:n**, Filterrichtung **einfach**):

| Dimension | Faktentabelle(n) | Schlüssel |
|---|---|---|
| `dim_datum` | `fact_bestand_monat`, `fact_neugeschaeft`, `fact_expected_loss` | `datum` |
| `dim_produkt` | alle vier Faktentabellen | `produkt` |
| `dim_region` | `fact_bestand_monat`, `fact_neugeschaeft`, `fact_expected_loss` | `region` |
| `dim_rating` | `fact_bestand_monat`, `fact_neugeschaeft`, `fact_expected_loss` | `ratingklasse` |

```
               dim_datum        dim_produkt
                   │  ╲            │
                   │   ╲           │
 dim_region ── fact_bestand_monat ─┤── fact_vintage
       │           │               │
       ├──── fact_neugeschaeft ────┤
       │                           │
       └──── fact_expected_loss ───┘
                   │
               dim_rating
```

Danach alle Schlüsselspalten in den Faktentabellen **ausblenden** (Rechtsklick → *In Berichtsansicht
ausblenden*), damit im Bericht nur die Dimensionen als Filter verwendet werden.

## Schritt 3 – Measures anlegen

1. **Start → Daten eingeben** → leere Tabelle mit dem Namen `_Measures` laden.
2. Jedes Measure aus `powerbi/measures.dax` einzeln anlegen: Tabelle `_Measures` markieren →
   **Neues Measure** → Code einfügen → Format wie im Kommentar angegeben einstellen.
3. Die Hilfsspalte `Spalte1` in `_Measures` löschen – die Tabelle wandert dann als Measure-Tabelle nach oben.

## Schritt 4 – Berichtsseiten

Auf jeder Seite oben eine **Filterleiste** mit drei Datenschnitten: `dim_datum[datum]` (Typ *Zwischen*),
`dim_produkt[produkt]` und `dim_region[region]` (Typ *Dropdown*). Tipp: Datenschnitte über
**Ansicht → Datenschnitte synchronisieren** auf alle Seiten übertragen.

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
| 5 × **Karte** | `Bestand Stichtag`, `Anzahl Kredite Stichtag`, `Zins volumengewichtet`, `NPL-Quote Stichtag`, `Expected Loss` |
| **Gestapeltes Flächendiagramm** | X: `dim_datum[datum]` · Y: `Bestand` · Legende: `dim_produkt[produkt]` |
| **Gruppiertes Balkendiagramm** | Y: `dim_region[region]` · X: `Bestand Stichtag` |
| **Gestapeltes Säulendiagramm** | X: `dim_datum[jahr]` · Y: `Neugeschäft Volumen` · Legende: `dim_produkt[produkt]` |
| **Säulendiagramm** | X: `dim_rating[risikoband]` · Y: `Bestand Stichtag` |

### Seite 2 – Risikoentwicklung

| Visual | Felder |
|---|---|
| **Liniendiagramm** (breit, oben) | X: `dim_datum[datum]` · Y: `NPL-Quote` und `Verzugsquote 30+` |
| 3 × **Karte** | `NPL-Quote Stichtag`, `NPL-Quote Vorjahr`, `NPL-Quote Veränderung VJ (pp)` |
| **Matrix** | Zeilen: `dim_produkt[produkt]` · Spalten: `fact_bestand_monat[verzugsstatus]` · Werte: `Bestand Stichtag` → *Wert anzeigen als: Prozent der Zeilensumme* |
| **Balkendiagramm** | Y: `dim_region[region]` · X: `NPL-Quote Stichtag` (absteigend sortiert) |

**Bedingte Formatierung:** In der Karte `NPL-Quote Veränderung VJ (pp)` → *Datenbeschriftung → Farbe → fx*:
Regel `> 0` = Rot (`#e34948`), `<= 0` = Grün (`#1baf7a`).

### Seite 3 – Vintage-Analyse

| Visual | Felder |
|---|---|
| **Liniendiagramm** | X: `fact_vintage[monate_seit_auszahlung]` (Typ *kontinuierlich*) · Y: `Ausfallrate kumuliert` · Legende: `fact_vintage[jahrgang]` |
| **Matrix** | Zeilen: `fact_vintage[jahrgang]` · Spalten: `fact_vintage[monate_seit_auszahlung]` (Filter: 12, 24, 36) · Werte: `Ausfallrate kumuliert` → Hintergrundfarbe als Farbskala |
| **Textfeld** | Kernaussage, z. B.: „Jahrgang 2023 liegt nach 24 Monaten rund 1 Prozentpunkt über 2021 – Effekt der Zinswende und Inflation.“ |

Für diese Seite den Datenschnitt *Produkt* auf **Ratenkredit + Autokredit** voreinstellen
(Baufinanzierung hat zu wenige Ausfälle für stabile Kurven).

### Seite 4 – Expected Loss & Pricing

| Visual | Felder |
|---|---|
| 4 × **Karte** | `EAD`, `PD gewichtet`, `LGD gewichtet`, `EL-Quote` |
| **Matrix** | Zeilen: `dim_produkt[produkt]`, darunter `dim_rating[risikoband]` · Werte: `EAD`, `PD gewichtet`, `LGD gewichtet`, `Expected Loss`, `EL-Quote` |
| **Gruppiertes Säulendiagramm** | X: `dim_rating[ratingklasse]` · Y: `Neugeschäft Zins` · Filter: Neugeschäft ab 2024, Produkt ≠ Baufinanzierung |
| **Ringdiagramm** | Legende: `dim_produkt[produkt]` · Werte: `Expected Loss` |

## Schritt 5 – Prüfen

Mit Filter **Stichtag 30.09.2026, alle Produkte, alle Regionen** müssen diese Werte erscheinen
(sie stammen aus den SQL-Ergebnissen in `ergebnisse/ERGEBNISSE.md`):

| Kennzahl | Sollwert |
|---|---|
| Bestand Stichtag | ≈ 714,8 Mio. € |
| NPL-Quote Stichtag | ≈ 1,02 % |
| Expected Loss | ≈ 1,54 Mio. € |
| EL-Quote | ≈ 0,22 % |

Weicht ein Wert stark ab, zuerst Schritt 0 (Gebietsschema) und die Beziehungen in Schritt 2 prüfen.

## Schritt 6 – Speichern und auf GitHub veröffentlichen

1. **Datei → Speichern unter** → `powerbi/Kreditportfolio_Dashboard.pbix`
2. Von jeder Seite einen Screenshot (**Win + Umschalt + S**) als PNG speichern:
   `powerbi/screenshots/01_portfolio.png`, `02_risiko.png`, `03_vintage.png`, `04_expected_loss.png`
3. Im README den Abschnitt *Power-BI-Dashboard* um die Screenshots ergänzen.
4. In PowerShell im Projektordner:

```powershell
git add powerbi/
git commit -m "Power-BI-Dashboard und Screenshots ergänzt"
git push
```
