# Methodik-Überarbeitung (Branch `fix/methodik-review`, 11/2026)

Alle Daten bleiben synthetisch und unverändert: `src/01_daten_generieren.py` und `data/raw/` sind nicht
angefasst (Seed 42, Prüfsummen der Rohdaten vor und nach der Überarbeitung identisch). Alle Änderungen liegen
in SQL, Pipeline, Grafiken, Power BI und Dokumentation. Neue Annahmen stehen an **einer** Stelle:
Tabelle `annahme` in `sql/00_annahme.sql` (siehe README, Abschnitt *Annahme*).

## Kennzahlen vorher / nachher (Stichtag 30.09.2026)

| Kennzahl | Vorher | Nachher | Grund |
|---|---|---|---|
| Kreditbestand | 714,8 Mio. € | 714,8 Mio. € | unverändert |
| NPL-Quote | 1,02 % | 1,02 % | unverändert, jetzt immer mit NPL-Volumen 7,28 Mio. € |
| NPL-Quote bei konstantem Bestand 07/2024 | – | 1,54 % | neu (Nennereffekt) |
| EAD im Expected Loss | 707,5 Mio. € (nur lebend) | 707,5 lebend + 7,28 Ausfall = 714,8 Mio. € | Fix 2 |
| Expected Loss lebender Kredite | 1.541 Tsd. € | 1.757 Tsd. € | Fix 3, 4, 5 und Kohortendefinition |
| EL-Quote lebend | 0,218 % | 0,248 % | wie oben |
| EL Ratenkredit / Auto / Bau | 656 / 368 / 517 Tsd. € | 686 / 374 / 697 Tsd. € | wie oben |
| Verlustschätzung Ausfälle (Stufe 3) | fehlte | 2.220 Tsd. € (nominale LGD: 1.931) | Fix 2 |
| Verlust gesamt | fehlte | 3.977 Tsd. € | Fix 2 |
| PD gewichtet (lebend) | 0,77 % | 0,78 % | Verzugs-PD, Kohorte |
| LGD gewichtet (EL) | 28,2 % | 31,8 % | Fix 5 |
| LGD Raten / Auto / Bau | 63,7 / 38,4 / 14,9 % | nominal unverändert, ökonomisch 65,3 / 39,3 / 19,8 % | Fix 5 |
| PD Baufinanzierung Klasse 1 / 2 | 0,00 / 0,00 % | 0,05 / 0,05 % (roh weiter 0,00 %) | Fix 4 |
| 12-Monats-PD 30 Tage Rückstand | nicht geschätzt (nur Roll Rate 63,2 %/Monat) | 29,1 % (Untergrenze 25,7 %) | Fix 3 |
| 12-Monats-PD 60 Tage Rückstand | nicht geschätzt (nur Roll Rate 40,63 %/Monat) | 43,3 % (Untergrenze 40,6 %) | Fix 3 |
| Effekt Verzugs-PD auf den EL | – | +271 Tsd. € | Fix 3 |
| Marge Klasse 7 / 8 / 9 / 10 (SQL) | 2,64 / 1,19 / −0,06 / −4,31 pp | 2,59 / 1,10 / −0,19 / −4,56 pp | Fix 5 (ökonomische LGD) |
| Marge Klasse 7 / 8 / 9 / 10 (Dashboard) | 2,57 / 1,10 / −0,07 / −4,55 pp | 2,59 / 1,10 / −0,19 / −4,56 pp (= SQL) | Fix 6 |
| Marge ohne Stressfenster Klasse 9 / 10 | – | +0,08 / −5,12 pp | Fix 6 |
| Risikokosten Klasse 10 | 10,19 % | 10,44 % | Fix 5 |
| DAX-Measures | 25 | 36 | neue Kennzahlen |
| Faktentabellen | 4 | 5 (`fact_risikokosten`) | Fix 6 |

**Überleitung des Expected Loss** (`ergebnisse/07_expected_loss__expected_loss_ueberleitung.csv`):

| Schritt | Tsd. € | Effekt |
|---|---|---|
| 1 Bisher: EL lebende Kredite (alte PD, nominale LGD) | 1.541 | |
| 2 Stufe 1: Rating-PD aus vertragsgemäßer Kohorte | 1.307 | −234 |
| 3 PD-Floor 0,05 % | 1.315 | +8 |
| 4 Ökonomische LGD | 1.486 | +171 |
| 5 Verzugs-PD für Kredite im Rückstand = EL lebend | 1.757 | +271 |
| 6 Verlustschätzung Ausfälle (Stufe 3) | 2.220 | |
| 7 Verlust gesamt | 3.977 | |

## Die Änderungen im Einzelnen

### Vorab: eine Stelle für alle Annahmen

- **Was:** neue Datei `sql/00_annahme.sql` mit der Tabelle `annahme` (Refinanzierung 3 %, PD-Floor 0,05 %,
  Diskontsatz 3 %, Abwicklungskosten 0 %, Stressfenster 07/2022 bis 12/2023). Die Pipeline führt jetzt auch
  SQL vor dem ersten `-- @ergebnis:`-Marker aus (Tabellen und Sichten).
- **Warum:** Vorher stand die Refinanzierung doppelt fest im Code (`sql/08` und DAX). Eine Annahme an zwei Stellen
  kann auseinanderlaufen.
- **Dateien:** `sql/00_annahme.sql`, `src/02_sql_pipeline.py`, `ergebnisse/00_annahme__parameter.csv`

### Fix 1 – NPL-Quote gegen Wachstum

- **Was:** SQL 04 weist zusätzlich die Vorjahresveränderung des NPL-Volumens und eine Zerlegung aus
  (`npl_quote_zerlegung`: Quote bei konstantem Bestand, Anteil junger Kredite, Abgang aus NPL). Grafik 01 zeigt
  NPL-Volumen und Bestand unter der Quote. In Power BI gibt es auf *Risikoentwicklung* eine NPL-Volumen-Linie
  und ein Textfeld mit der Einordnung. „Rückläufig“-Formulierungen wurden ersetzt.
- **Warum:** Die Quote fiel von 1,43 % auf 1,02 %, das NPL-Volumen stieg aber von 6,75 auf 7,28 Mio. €. Ohne
  Volumen sieht das nach Verbesserung aus, obwohl vor allem der Bestand (Nenner) wächst.
- **Dateien:** `sql/04_rueckstaende_npl.sql`, `src/03_grafiken.py`, Power-BI-Seite *Risikoentwicklung*, README

### Fix 2 – Verlustschätzung für ausgefallene Kredite (Stufe 3)

- **Was:** `fact_expected_loss` hat jetzt eine Spalte `stufe` (1 vertragsgemäß, 2 Rückstand, 3 Ausfall) und
  enthält auch die 215 ausgefallenen Kredite. Für sie gilt PD = 100 %, Verlust = Restschuld × LGD. Neue Measures
  `EAD Ausfall`, `Verlust Ausfall`, `Verlust gesamt`, `EAD gesamt` und Karten auf *Expected Loss & Pricing*.
  Vorab geprüft mit nominaler LGD: 1,93 Mio. € Ausfälle und 3,47 Mio. € gesamt (erwartet ≈ 1,9 und ≈ 3,5).
  Mit ökonomischer LGD (Fix 5) sind es 2,22 und 3,98 Mio. €.
- **Warum eine Tabelle statt zwei:** gleiche Körnung (Stichtag × Produkt × Region × Rating), gleiche Dimensionen,
  gleiche Formel EL = PD × LGD × EAD. Eine zweite Faktentabelle hätte vier Beziehungen und alle Measures verdoppelt.
- **IFRS-9-Bezug:** Einteilung in Anlehnung an die drei Stufen. Kein vollständiges IFRS-9-Modell (keine
  Lifetime-PD für Stufe 2, keine Szenarien, keine Abzinsung des EL).
- **Dateien:** `sql/07_expected_loss.sql` (Sicht `v_el_basis`), `sql/09_powerbi_datenmodell.sql`,
  `powerbi/daten/fact_expected_loss.csv`, TMDL, `measures.dax`, Power-BI-Seite 4

### Fix 3 – 12-Monats-PD bei Zahlungsrückstand

- **Was:** neue Sicht `v_pd_verzug`: Kredite mit 30 bzw. 60 Tagen Rückstand an allen Monatsultimos bis 09/2025,
  Ausfall in den folgenden 12 Monaten. Ergebnis 29,1 % bzw. 43,3 %. Plausibilisiert mit verketteten Roll Rates
  (Untergrenzen 63,2 % × 40,63 % = 25,7 % und 40,63 %). Kredite im Rückstand bekommen diese PD im EL.
  Effekt: +271 Tsd. € (Measure `Effekt Verzugs-PD`).
- **Folgeänderung:** Die Rating-PD für Stufe 1 wird jetzt nur aus Krediten ohne Rückstand geschätzt. Sonst wären
  die Ausfälle aus dem Rückstand doppelt gezählt (einmal in der Rating-PD, einmal in der Verzugs-PD). Effekt: −234 Tsd. €.
  Für das Pricing bleibt die PD aller nicht ausgefallenen Kredite, weil jeder Ausfall über 30 und 60 Tage Rückstand läuft.
- **Warum:** Eine monatliche Roll Rate ist keine 12-Monats-PD. Kredite im Rückstand mit der Rating-PD (z. B. 1 %)
  zu bewerten, unterschätzt ihr Risiko stark.
- **Dateien:** `sql/07_expected_loss.sql`, `ergebnisse/07_expected_loss__pd_nach_verzugsstatus.csv`

### Fix 4 – PD-Floor, keine Glättung

- **Was:** PD-Untergrenze 0,05 % (Annahme, angelehnt an den Retail-Floor nach Basel III final). Ausgewiesen werden
  rohe PD und PD nach Floor. Der Floor greift nur bei Baufinanzierung Klasse 1 und 2. Grafik 03 zeigt die rohe PD
  und markiert den Floor. In Power BI zeigt die Matrix „PD roh“ neben „PD“.
- **Dokumentiert:** Konsum Klasse 1 (0,22 %) > Klasse 2 (0,09 %) ist Rauschen (3 gegenüber 2 Ausfällen). Die
  Baufinanzierung endet bei Klasse 7 wegen der Kreditrichtlinie.
- **Warum:** Eine PD von 0 % heißt „kann nicht ausfallen“, das ist bei kleinen Stichproben falsch. Glätten würde
  Werte erfinden, die nicht beobachtet wurden.
- **Dateien:** `sql/00_annahme.sql`, `sql/07_expected_loss.sql`, `src/03_grafiken.py`, README

### Fix 5 – Ökonomische LGD

- **Was:** neben der nominalen LGD eine ökonomische LGD: Erlöse über die tatsächliche Abwicklungsdauer
  (18/6/24 Monate) mit 3 % abgezinst, Abwicklungskosten als Parameter (Standard 0 %). Der Haupt-EL nutzt die
  ökonomische LGD, beide werden gezeigt (Karte „LGD nominal (Vergleich)“).
- **Dokumentiert:** 454 von 669 Verwertungen abgeschlossen. Baufinanzierung basiert auf 18 Fällen.
  Verwertungs-EAD (Restschuld + 3 Raten) ist nicht gleich der EAD im EL (Restschuld).
- **Warum:** Ein Euro, der erst nach 24 Monaten zurückkommt, ist heute weniger wert. Die nominale LGD
  unterschätzt den Verlust, am stärksten bei der langen Abwicklung der Baufinanzierung (14,9 → 19,8 %).
- **Dateien:** `sql/07_expected_loss.sql` (Sichten `v_verwertung_bewertet`, `v_lgd`)

### Fix 6 – Marge nach Risikokosten

- **Test vorab:** Kredite aus dem Stressfenster haben eine höhere 12-Monats-PD (Konsum 2,27 % gegenüber 1,61 %,
  Bau 1,14 % gegenüber 0,43 %). Der Jahrgang 2024 liegt nach 12 Monaten mit 1,71 % über 2021 (1,14 %) und
  2022 (1,35 %), aber unter 2023 (2,04 %).
- **Was:** Variante der Pricing-PD ohne Stressfenster, beide Varianten in SQL, Grafik und Dashboard.
  **Klasse 9 wechselt das Vorzeichen** (−0,19 → +0,08 pp), Klasse 10 bleibt negativ (−4,56 → −5,12 pp).
  Umbenennung „Risikoadjustierte Marge“ → „Marge nach Risikokosten“ überall (SQL-Datei, CSV, Grafik, Measure,
  Visual, Doku). Betriebs- und Eigenkapitalkosten sind ausdrücklich nicht enthalten.
- **SQL/DAX-Abgleich:** Das Dashboard rechnete die LGD als Mix der Produkt-LGDs im aktuellen Bestand (≈ 51–52 %),
  SQL nutzte die gepoolte LGD der Verwertungen (50,35 %). Jetzt kommen PD und LGD je Ratingklasse aus der neuen
  Tabelle `fact_risikokosten` (von `sql/09` aus denselben Sichten wie `sql/08` erzeugt). Per DAX-Abfrage über
  den Power BI Modeling MCP geprüft: alle 10 Klassen, beide Varianten, auf zwei Stellen identisch.
- **Dateien:** `sql/08_marge_nach_risikokosten.sql` (umbenannt), `sql/09_powerbi_datenmodell.sql`,
  `src/03_grafiken.py`, `ergebnisse/grafiken/04_marge_nach_risikokosten.png`, TMDL, `measures.dax`, Power-BI-Seite 4

### Fix 7 – Zirkelschluss

- **Was:** Erklärungen wie „Effekt von Zinswende und Inflation“ ersetzt durch: „Die Analyse findet den im
  Generator eingebauten Stressaufschlag (×1,25 für Auszahlungen 07/2022–12/2023) korrekt wieder.“ Ebenso
  dokumentiert: Die gemessenen LGDs treffen die Generator-Mittelwerte 65/40/15 %.
- **Warum:** Die Daten sind synthetisch. Was der Generator einbaut, kann die Analyse nur wiederfinden, nicht als
  Befund über die reale Welt ausgeben.
- **Dateien:** README, Textfeld auf *Vintage-Analyse*, Grafik 02, ANLEITUNG

### Fix 8 – nur dokumentiert

- Raten- und Autokredite sind in der PD gepoolt, obwohl der Generator PD-Faktoren 1,30 und 1,00 setzt.
- Die PD-Kohorten überlappen (ein Kredit erscheint in mehreren Jahreskohorten, bei der Verzugs-PD in vielen Monaten).
- Die Refinanzierung von 3 % ist fest und vereinfacht. Sie steht jetzt in `annahme` statt doppelt im Code.

### Power BI und Ausgaben

- Modelländerungen über den Power BI Modeling MCP (Spalten, Tabelle, Beziehungen, Measures, Aktualisierung,
  DAX-Prüfabfragen). Visuals und Textfelder direkt in den PBIR-Dateien bei geschlossenem Power BI Desktop,
  jeweils kopiert von bestehenden Visuals desselben Typs.
- `Kreditportfolio_Dashboard.pbix` und `.pdf` neu gespeichert bzw. exportiert, die vier Screenshots aus dem PDF
  erzeugt (ganze Seite, Datenschnitte im Standardzustand). Seiten *Risikoentwicklung* und *Expected Loss & Pricing*
  sind jetzt höher (840 bzw. 900 px), damit die neuen Elemente Platz haben.
- Der Parameter `Datenordner` steht in der PBIP-Fassung wieder auf dem Platzhalter `C:\PFAD\ZUM\ORDNER\...`.
- Backup des alten Ordners `powerbi/` vor der ersten Änderung: außerhalb des Repos unter `C:\kredit\backup_powerbi_20261120_212228`.

## Verbleibende Grenzen (Verteidigungspunkte fürs Interview)

1. **Synthetische Daten:** Jedes Ergebnis kann nur zeigen, dass die Methode die eingebauten Muster findet. Für
   echte Aussagen braucht es echte Daten.
2. **Kein vollständiges IFRS 9:** keine Lifetime-PD für Stufe 2, keine makroökonomischen Szenarien, keine
   Abzinsung des EL mit dem Effektivzins, kein formales SICR-Kriterium.
3. **Kleine Fallzahlen:** Baufinanzierungs-LGD aus 18 Fällen, Klasse 10 mit 41 Krediten im Neugeschäft,
   Klassen 1 und 2 mit 2 bis 3 Ausfällen. Konfidenzintervalle wären der nächste Schritt.
4. **Gepoolte PD:** Raten- und Autokredite teilen eine PD, obwohl ihr Risiko verschieden ist. Eigene PDs je
   Produkt wären genauer, aber noch instabiler.
5. **Überlappende Kohorten:** Beobachtungen sind nicht unabhängig, Standardfehler wären unterschätzt.
6. **LGD-Basis:** LGD auf Verwertungs-EAD (mit 3 Raten Rückstand) gemessen, aber auf die Restschuld angewendet.
   Ein CCF bzw. eine EAD-Hochrechnung für lebende Kredite fehlt.
7. **Stufe-3-Verlust vereinfacht:** Die volle Abzinsung über die gesamte Abwicklungsdauer wird auch auf Kredite
   angewendet, deren Verwertung schon läuft. Bereits eingegangene Teilerlöse sind im Datensatz nicht abgebildet.
8. **Marge unvollständig:** Betriebs- und Eigenkapitalkosten fehlen, die Refinanzierung ist ein fester Satz ohne
   Laufzeitbezug.
9. **Point-in-time vs. through-the-cycle:** Die PD mittelt über 2022 bis 2025 inklusive Stressphase. Eine
   Kalibrierung auf einen Zyklus ist nicht erfolgt.

## Die Änderungen einfach erklärt

- **NPL-Quote und Nenner:** Eine Quote ist ein Bruch. Wenn der Nenner (Bestand) schneller wächst als der Zähler
  (notleidende Kredite), sinkt die Quote, obwohl es mehr Problemkredite gibt. Deshalb steht das Volumen jetzt immer daneben.
- **Stufe 3:** Bisher zählte der Expected Loss nur Kredite, die noch nicht ausgefallen sind. Für schon ausgefallene
  Kredite ist der Verlust aber sehr wahrscheinlich: Man schätzt ihn als Restschuld mal Verlustquote. So sieht man
  das ganze Verlustrisiko des Bestands.
- **Verzugs-PD:** Wer schon 60 Tage im Rückstand ist, fällt viel öfter aus als ein Kunde mit gleichem Rating, der
  pünktlich zahlt. Man zählt einfach nach: Von allen Krediten, die irgendwann 60 Tage im Rückstand waren, wie viele
  waren 12 Monate später ausgefallen? Das sind 43 %.
- **Roll Rate vs. PD:** Die Roll Rate sagt, was im nächsten Monat passiert. Die PD sagt, was in 12 Monaten passiert.
  Ein Kredit kann geheilt werden und später doch ausfallen, deshalb ist das Produkt der Monatsraten nur eine Untergrenze.
- **PD-Floor:** 0 Ausfälle in 330 Krediten heißt nicht, dass nie jemand ausfällt. Die Untergrenze verhindert eine
  PD von 0 %.
- **Ökonomische LGD:** Geld, das erst in zwei Jahren aus dem Verkauf einer Immobilie kommt, ist heute weniger wert.
  Abzinsen macht das sichtbar.
- **Marge nach Risikokosten:** Zins minus Refinanzierung minus erwarteter Verlust. Was übrig bleibt, muss noch
  Personal, IT und Eigenkapital bezahlen. Der neue Name sagt genau das, „risikoadjustiert“ klang vollständiger, als es ist.
- **SQL = DAX:** Zwei Werkzeuge sollen dieselbe Zahl liefern. Vorher rechnete Power BI die Verlustquote anders als
  SQL. Jetzt rechnet SQL die Risikokosten einmal aus, Power BI liest sie nur noch ein.
- **Annahme-Tabelle:** Alle gesetzten Werte stehen in einer Tabelle. Wer eine Annahme ändern will, ändert eine Zeile.
