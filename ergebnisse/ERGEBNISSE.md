# Ergebnisse der SQL-Analysen

Automatisch erzeugt von `src/02_sql_pipeline.py`. Alle Werte basieren auf synthetischen Daten.

## 00_annahme · parameter

| parameter         |     wert | datum      | einheit        | beschreibung                                                                                        |
|:------------------|---------:|:-----------|:---------------|:----------------------------------------------------------------------------------------------------|
| refinanzierung_pa |   0.03   | nan        | Anteil p. a.   | Refinanzierungskosten Konsumentenkredite, fest und vereinfacht (Marge nach Risikokosten)            |
| pd_floor          |   0.0005 | nan        | Anteil         | PD-Untergrenze 0,05 % je Ratingklasse, angelehnt an den Retail-PD-Floor nach Basel III final (CRR3) |
| diskontsatz_pa    |   0.03   | nan        | Anteil p. a.   | Diskontsatz für Verwertungserlöse über die Abwicklungsdauer (ökonomische LGD)                       |
| workout_kosten    |   0      | nan        | Anteil der EAD | Interne Abwicklungskosten je Verwertung, Standard 0 % (ökonomische LGD)                             |
| stressfenster_von | nan      | 2022-07-01 | Datum          | Beginn des im Generator eingebauten Stressaufschlags (PD × 1,25 für Auszahlungen ab diesem Datum)   |
| stressfenster_bis | nan      | 2023-12-31 | Datum          | Ende des Stressaufschlags (Auszahlungen bis einschließlich diesem Datum), Variante der Pricing-PD   |

## 02_datenqualitaet · pruefungen

| pruefung                                   |   fehler |
|:-------------------------------------------|---------:|
| Kredite ohne gültigen Kunden               |        0 |
| Doppelte Kredit-IDs                        |        0 |
| Zinssatz außerhalb 0–20 %                  |        0 |
| Baufinanzierung ohne Beleihungsauslauf     |        0 |
| Kapitaldienstquote über 100 %              |        0 |
| Performance-Sätze ohne Kredit              |        0 |
| Stichtag vor Auszahlung                    |        0 |
| Negative Restschuld                        |        0 |
| Status und Tage überfällig widersprüchlich |        0 |
| Ausfall ohne Verwertungsdatensatz          |        0 |
| Verwertungserlös größer als EAD            |        0 |
| Lücken in der Monatshistorie               |        0 |

## 02_datenqualitaet · tabellenumfang

| tabelle           |   datensaetze |
|:------------------|--------------:|
| kunden            |         20000 |
| kredite           |         20000 |
| performance_monat |        517679 |
| verwertung        |           669 |

## 03_portfolio_ueberblick · bestand_nach_produkt

| produkt         |   anzahl_kredite |   bestand_mio_eur |   anteil_prozent |   durchschn_restschuld_eur |   zins_volumengewichtet |   rating_volumengewichtet |
|:----------------|-----------------:|------------------:|-----------------:|---------------------------:|------------------------:|--------------------------:|
| Baufinanzierung |             2242 |             606.2 |             84.8 |                     270386 |                    2.97 |                       4.1 |
| Ratenkredit     |             6638 |              56.3 |              7.9 |                       8482 |                    7.35 |                       4.7 |
| Autokredit      |             3530 |              52.3 |              7.3 |                      14802 |                    6.28 |                       4.6 |

## 03_portfolio_ueberblick · neugeschaeft_nach_jahr

|   jahr | produkt         |   anzahl_kredite |   volumen_mio_eur |   zins_volumengewichtet |
|-------:|:----------------|-----------------:|------------------:|------------------------:|
|   2021 | Autokredit      |              937 |              24.3 |                    3.84 |
|   2021 | Baufinanzierung |              469 |             144.8 |                    1.3  |
|   2021 | Ratenkredit     |             1692 |              23.5 |                    4.48 |
|   2022 | Autokredit      |             1059 |              27.5 |                    4.38 |
|   2022 | Baufinanzierung |              372 |             112.4 |                    1.67 |
|   2022 | Ratenkredit     |             1895 |              26   |                    5.11 |
|   2023 | Autokredit      |             1093 |              27.3 |                    6.29 |
|   2023 | Baufinanzierung |              311 |              88.3 |                    3.58 |
|   2023 | Ratenkredit     |             1993 |              27.6 |                    7.35 |
|   2024 | Autokredit      |             1113 |              28   |                    6.82 |
|   2024 | Baufinanzierung |              443 |             119.2 |                    4.14 |
|   2024 | Ratenkredit     |             2051 |              27.9 |                    8.02 |
|   2025 | Autokredit      |             1220 |              31   |                    6.4  |
|   2025 | Baufinanzierung |              465 |             130.6 |                    3.7  |
|   2025 | Ratenkredit     |             2148 |              29.9 |                    7.5  |
|   2026 | Autokredit      |              830 |              20.9 |                    6.14 |
|   2026 | Baufinanzierung |              354 |              99.2 |                    3.46 |
|   2026 | Ratenkredit     |             1555 |              21.8 |                    7.2  |

## 03_portfolio_ueberblick · bestand_nach_region

| region          |   anzahl_kredite |   bestand_mio_eur |   npl_quote_prozent |
|:----------------|-----------------:|------------------:|--------------------:|
| Region Hannover |             3720 |             215.5 |                1.33 |
| Braunschweig    |             1917 |             110   |                1.23 |
| Lüneburg        |             1823 |             107.2 |                1.1  |
| Osnabrück       |             1837 |             105.9 |                0.27 |
| Oldenburg       |             1878 |             101.8 |                1.39 |
| Göttingen       |             1235 |              74.5 |                0.25 |

## 03_portfolio_ueberblick · ratingverteilung_neugeschaeft

|   ratingklasse | risikoband     |   anzahl_kredite |   anteil_prozent |   durchschn_zins |   durchschn_kapitaldienstquote_prozent |
|---------------:|:---------------|-----------------:|-----------------:|-----------------:|---------------------------------------:|
|              1 | Sehr gut (1–2) |              998 |              5   |             4.82 |                                   15   |
|              2 | Sehr gut (1–2) |             1615 |              8.1 |             5.13 |                                   16.4 |
|              3 | Gut (3–4)      |             3076 |             15.4 |             5.43 |                                   16.6 |
|              4 | Gut (3–4)      |             4023 |             20.1 |             5.7  |                                   17.3 |
|              5 | Mittel (5–6)   |             4212 |             21.1 |             6.06 |                                   18.1 |
|              6 | Mittel (5–6)   |             3222 |             16.1 |             6.35 |                                   18.6 |
|              7 | Erhöht (7–8)   |             1827 |              9.1 |             6.66 |                                   19.4 |
|              8 | Erhöht (7–8)   |              705 |              3.5 |             7.42 |                                   18.4 |
|              9 | Hoch (9–10)    |              246 |              1.2 |             7.62 |                                   19.7 |
|             10 | Hoch (9–10)    |               76 |              0.4 |             7.95 |                                   20.5 |

## 04_rueckstaende_npl · npl_entwicklung_monatlich

| stichtag   |   bestand_mio_eur |   npl_mio_eur |   npl_veraenderung_vj_mio_eur |   npl_quote_prozent |   quote_30_plus_prozent |   npl_veraenderung_vj_pp |
|:-----------|------------------:|--------------:|------------------------------:|--------------------:|------------------------:|-------------------------:|
| 2021-06-30 |              89   |          0    |                        nan    |                0    |                    0.13 |                   nan    |
| 2021-07-31 |             102.2 |          0.01 |                        nan    |                0.01 |                    0.13 |                   nan    |
| 2021-08-31 |             121.3 |          0.05 |                        nan    |                0.04 |                    0.26 |                   nan    |
| 2021-09-30 |             139.5 |          0.1  |                        nan    |                0.07 |                    0.38 |                   nan    |
| 2021-10-31 |             154.9 |          0.14 |                        nan    |                0.09 |                    0.23 |                   nan    |
| 2021-11-30 |             166.1 |          0.16 |                        nan    |                0.1  |                    0.78 |                   nan    |
| 2021-12-31 |             181.5 |          0.2  |                        nan    |                0.11 |                    0.72 |                   nan    |
| 2022-01-31 |             195.5 |          0.2  |                        nan    |                0.1  |                    0.29 |                   nan    |
| 2022-02-28 |             210.6 |          0.22 |                        nan    |                0.1  |                    0.39 |                   nan    |
| 2022-03-31 |             224.3 |          0.24 |                        nan    |                0.11 |                    0.9  |                   nan    |
| 2022-04-30 |             238.8 |          0.59 |                        nan    |                0.25 |                    0.96 |                   nan    |
| 2022-05-31 |             249.5 |          1.12 |                        nan    |                0.45 |                    0.68 |                   nan    |
| 2022-06-30 |             264.5 |          1.31 |                          1.31 |                0.5  |                    0.9  |                     0.5  |
| 2022-07-31 |             273.9 |          1.42 |                          1.41 |                0.52 |                    1.02 |                     0.5  |
| 2022-08-31 |             280.7 |          1.5  |                          1.44 |                0.53 |                    0.97 |                     0.49 |
| 2022-09-30 |             287.3 |          1.57 |                          1.47 |                0.55 |                    0.93 |                     0.48 |
| 2022-10-31 |             298.6 |          1.91 |                          1.77 |                0.64 |                    0.84 |                     0.55 |
| 2022-11-30 |             305.5 |          1.96 |                          1.8  |                0.64 |                    0.95 |                     0.55 |
| 2022-12-31 |             314.4 |          1.98 |                          1.79 |                0.63 |                    1.11 |                     0.52 |
| 2023-01-31 |             321.7 |          2.05 |                          1.85 |                0.64 |                    0.97 |                     0.54 |
| 2023-02-28 |             330.6 |          2.1  |                          1.89 |                0.64 |                    0.86 |                     0.53 |
| 2023-03-31 |             337.3 |          2.13 |                          1.88 |                0.63 |                    1.12 |                     0.52 |
| 2023-04-30 |             346.3 |          2.2  |                          1.61 |                0.64 |                    1.17 |                     0.39 |
| 2023-05-31 |             353.1 |          2.52 |                          1.4  |                0.71 |                    1.38 |                     0.27 |
| 2023-06-30 |             362.5 |          2.59 |                          1.27 |                0.71 |                    1.03 |                     0.22 |

*… 39 weitere Zeilen in `04_rueckstaende_npl__npl_entwicklung_monatlich.csv`*

## 04_rueckstaende_npl · dpd_buckets_nach_produkt

| produkt         |   vertragsgemaess_prozent |   dpd_1_30_prozent |   dpd_31_89_prozent |   npl_90_plus_prozent |
|:----------------|--------------------------:|-------------------:|--------------------:|----------------------:|
| Ratenkredit     |                     96.2  |               0.66 |                0.41 |                  2.73 |
| Baufinanzierung |                     98.86 |               0.23 |                0.02 |                  0.88 |
| Autokredit      |                     98.33 |               0.36 |                0.51 |                  0.8  |

## 04_rueckstaende_npl · npl_quote_zerlegung

| stichtag   |   bestand_mio_eur |   npl_mio_eur |   npl_quote_prozent |   npl_quote_bei_bestand_07_2024_prozent |   anteil_bestand_unter_12_monate_prozent |   abgeschlossene_verwertungen_12m |   abgang_aus_npl_12m_mio_eur |
|:-----------|------------------:|--------------:|--------------------:|----------------------------------------:|-----------------------------------------:|----------------------------------:|-----------------------------:|
| 2024-07-31 |             473.8 |          6.75 |                1.43 |                                    1.43 |                                     28.9 |                                76 |                         2.06 |
| 2025-09-30 |             610.9 |          7.69 |                1.26 |                                    1.62 |                                     26.5 |                               151 |                         2.66 |
| 2026-09-30 |             714.8 |          7.28 |                1.02 |                                    1.54 |                                     22.8 |                               175 |                         6.14 |

## 05_vintage_analyse · vintage_kurven

| jahrgang   |   monate_seit_auszahlung |   kredite_beobachtbar |   ausfaelle_kumuliert |   ausfallrate_kumuliert_prozent |
|:-----------|-------------------------:|----------------------:|----------------------:|--------------------------------:|
| 2021-H1    |                        3 |                  1274 |                     0 |                            0    |
| 2021-H1    |                        6 |                  1274 |                     5 |                            0.39 |
| 2021-H1    |                        9 |                  1274 |                    10 |                            0.78 |
| 2021-H1    |                       12 |                  1274 |                    16 |                            1.26 |
| 2021-H1    |                       18 |                  1274 |                    29 |                            2.28 |
| 2021-H1    |                       24 |                  1274 |                    42 |                            3.3  |
| 2021-H1    |                       30 |                  1274 |                    50 |                            3.92 |
| 2021-H1    |                       36 |                  1274 |                    53 |                            4.16 |
| 2021-H1    |                       42 |                  1274 |                    54 |                            4.24 |
| 2021-H1    |                       48 |                  1274 |                    57 |                            4.47 |
| 2021-H2    |                        3 |                  1355 |                     1 |                            0.07 |
| 2021-H2    |                        6 |                  1355 |                     2 |                            0.15 |
| 2021-H2    |                        9 |                  1355 |                     8 |                            0.59 |
| 2021-H2    |                       12 |                  1355 |                    14 |                            1.03 |
| 2021-H2    |                       18 |                  1355 |                    27 |                            1.99 |
| 2021-H2    |                       24 |                  1355 |                    39 |                            2.88 |
| 2021-H2    |                       30 |                  1355 |                    47 |                            3.47 |
| 2021-H2    |                       36 |                  1355 |                    54 |                            3.99 |
| 2021-H2    |                       42 |                  1355 |                    57 |                            4.21 |
| 2021-H2    |                       48 |                  1355 |                    59 |                            4.35 |
| 2022-H1    |                        3 |                  1421 |                     0 |                            0    |
| 2022-H1    |                        6 |                  1421 |                     6 |                            0.42 |
| 2022-H1    |                        9 |                  1421 |                    10 |                            0.7  |
| 2022-H1    |                       12 |                  1421 |                    15 |                            1.06 |
| 2022-H1    |                       18 |                  1421 |                    24 |                            1.69 |

*… 48 weitere Zeilen in `05_vintage_analyse__vintage_kurven.csv`*

## 05_vintage_analyse · vintage_vergleich_12_24_mob

|   jahrgang |   ausfallrate_12_mob_prozent |   ausfallrate_24_mob_prozent |
|-----------:|-----------------------------:|-----------------------------:|
|       2021 |                         1.14 |                         3.08 |
|       2022 |                         1.35 |                         3.49 |
|       2023 |                         2.04 |                         4.08 |
|       2024 |                         1.71 |                         2.88 |
|       2025 |                         1.18 |                       nan    |

## 06_roll_rates · uebergangsmatrix

| von_status        | nach_status       |   uebergaenge |   anteil_prozent |
|:------------------|:------------------|--------------:|-----------------:|
| 1 | vertragsgemäß | 1 | vertragsgemäß |        136614 |            97.83 |
| 1 | vertragsgemäß | 2 | 30 Tage       |           707 |             0.51 |
| 1 | vertragsgemäß | 5 | getilgt       |          2327 |             1.67 |
| 2 | 30 Tage       | 1 | vertragsgemäß |           251 |            35.25 |
| 2 | 30 Tage       | 2 | 30 Tage       |             4 |             0.56 |
| 2 | 30 Tage       | 3 | 60 Tage       |           450 |            63.2  |
| 2 | 30 Tage       | 5 | getilgt       |             7 |             0.98 |
| 3 | 60 Tage       | 1 | vertragsgemäß |           251 |            56.03 |
| 3 | 60 Tage       | 2 | 30 Tage       |             3 |             0.67 |
| 3 | 60 Tage       | 4 | Ausfall (90+) |           182 |            40.63 |
| 3 | 60 Tage       | 5 | getilgt       |            12 |             2.68 |

## 07_expected_loss · pd_nach_ratingklasse

| produktgruppe     |   ratingklasse |   beobachtungen |   ausfaelle_12m |   pd_12m_roh_prozent |   pd_12m_prozent | floor_greift   |   ausfaelle_vertragsgemaess |   pd_vertragsgemaess_prozent |
|:------------------|---------------:|----------------:|----------------:|---------------------:|-----------------:|:---------------|----------------------------:|-----------------------------:|
| Konsumentenkredit |              1 |            1393 |               3 |                 0.22 |             0.22 | nein           |                           2 |                         0.14 |
| Konsumentenkredit |              2 |            2200 |               2 |                 0.09 |             0.09 | nein           |                           2 |                         0.09 |
| Konsumentenkredit |              3 |            4314 |              17 |                 0.39 |             0.39 | nein           |                          15 |                         0.35 |
| Konsumentenkredit |              4 |            5593 |              60 |                 1.07 |             1.07 | nein           |                          49 |                         0.88 |
| Konsumentenkredit |              5 |            5906 |              89 |                 1.51 |             1.51 | nein           |                          73 |                         1.25 |
| Konsumentenkredit |              6 |            4652 |             108 |                 2.32 |             2.32 | nein           |                          84 |                         1.83 |
| Konsumentenkredit |              7 |            2519 |             107 |                 4.25 |             4.25 | nein           |                          90 |                         3.67 |
| Konsumentenkredit |              8 |            1065 |              82 |                 7.7  |             7.7  | nein           |                          67 |                         6.56 |
| Konsumentenkredit |              9 |             337 |              36 |                10.68 |            10.68 | nein           |                          31 |                         9.75 |
| Konsumentenkredit |             10 |              84 |              17 |                20.24 |            20.24 | nein           |                          13 |                        17.11 |
| Immobilienkredit  |              1 |             330 |               0 |                 0    |             0.05 | ja             |                           0 |                         0.05 |
| Immobilienkredit  |              2 |             519 |               0 |                 0    |             0.05 | ja             |                           0 |                         0.05 |
| Immobilienkredit  |              3 |             917 |               2 |                 0.22 |             0.22 | nein           |                           1 |                         0.11 |
| Immobilienkredit  |              4 |            1152 |               4 |                 0.35 |             0.35 | nein           |                           3 |                         0.26 |
| Immobilienkredit  |              5 |            1001 |               8 |                 0.8  |             0.8  | nein           |                           7 |                         0.7  |
| Immobilienkredit  |              6 |             684 |              10 |                 1.46 |             1.46 | nein           |                           9 |                         1.32 |
| Immobilienkredit  |              7 |             384 |               6 |                 1.56 |             1.56 | nein           |                           6 |                         1.57 |

## 07_expected_loss · pd_nach_verzugsstatus

| verzugsstufe      |   beobachtungen |   ausfaelle_12m |   pd_12m_prozent |   untergrenze_roll_rates_prozent | verwendung                                |
|:------------------|----------------:|----------------:|-----------------:|---------------------------------:|:------------------------------------------|
| 1 | vertragsgemäß |          357311 |            4937 |             1.38 |                           nan    | nur zum Vergleich, EL nutzt die Rating-PD |
| 2 | 30 Tage       |            1959 |             570 |            29.1  |                            25.68 | PD für Kredite im Rückstand (Stufe 2)     |
| 3 | 60 Tage       |            1235 |             535 |            43.32 |                            40.63 | PD für Kredite im Rückstand (Stufe 2)     |

## 07_expected_loss · lgd_nach_produkt

| produkt         |   abgeschlossene_verwertungen |   laufende_verwertungen |   ead_mio_eur |   abwicklung_monate |   lgd_nominal_prozent |   lgd_oekonomisch_prozent |
|:----------------|------------------------------:|------------------------:|--------------:|--------------------:|----------------------:|--------------------------:|
| Ratenkredit     |                           267 |                     170 |          2.77 |                  18 |                  63.7 |                      65.3 |
| Autokredit      |                           169 |                      26 |          3.1  |                   6 |                  38.4 |                      39.3 |
| Baufinanzierung |                            18 |                      19 |          5.95 |                  24 |                  14.9 |                      19.8 |

## 07_expected_loss · expected_loss_nach_produkt

| produkt         |   ead_lebend_mio_eur |   pd_gewichtet_prozent |   lgd_prozent |   el_lebend_tsd_eur |   el_quote_lebend_prozent |   ead_ausfall_mio_eur |   verlust_ausfall_tsd_eur |   verlust_gesamt_tsd_eur |   bestand_mio_eur |
|:----------------|---------------------:|-----------------------:|--------------:|--------------------:|--------------------------:|----------------------:|--------------------------:|-------------------------:|------------------:|
| Autokredit      |                 51.8 |                   1.84 |          39.3 |                 374 |                     0.721 |                  0.42 |                       164 |                      538 |              52.3 |
| Baufinanzierung |                600.9 |                   0.59 |          19.8 |                 697 |                     0.116 |                  5.33 |                      1052 |                     1749 |             606.2 |
| Ratenkredit     |                 54.8 |                   1.92 |          65.3 |                 686 |                     1.253 |                  1.54 |                      1003 |                     1689 |              56.3 |
| Gesamt          |                707.5 |                   0.78 |          31.8 |                1757 |                     0.248 |                  7.28 |                      2220 |                     3977 |             714.8 |

## 07_expected_loss · expected_loss_nach_stufe

| stufe   | bezeichnung                                     |   anzahl_kredite |   ead_mio_eur |   pd_gewichtet_prozent |   lgd_prozent |   verlust_tsd_eur |
|:--------|:------------------------------------------------|-----------------:|--------------:|-----------------------:|--------------:|------------------:|
| 1       | vertragsgemäß (12-Monats-EL, Rating-PD)         |            12104 |        704.87 |                   0.66 |          31.2 |              1461 |
| 2       | Rückstand 30/60 Tage (12-Monats-EL, Verzugs-PD) |               91 |          2.61 |                  32.58 |          34.8 |               296 |
| 3       | Ausfall 90+ (Verlustschätzung, PD = 100 %)      |              215 |          7.28 |                 100    |          30.5 |              2220 |
| Gesamt  | Bestand gesamt                                  |            12410 |        714.76 |                   1.79 |          31   |              3977 |

## 07_expected_loss · expected_loss_ueberleitung

| schritt                                                |   wert_tsd_eur |   effekt_tsd_eur |
|:-------------------------------------------------------|---------------:|-----------------:|
| 1 Bisher: EL lebende Kredite (alte PD, nominale LGD)   |           1541 |              nan |
| 2 Stufe 1: Rating-PD aus vertragsgemäßer Kohorte       |           1307 |             -234 |
| 3 PD-Floor 0,05 % (Annahme)                            |           1315 |                8 |
| 4 Ökonomische LGD (Abzinsung 3 %, Kosten 0 %)          |           1486 |              171 |
| 5 Verzugs-PD für Kredite im Rückstand = EL lebend      |           1757 |              271 |
| 6 Verlustschätzung Ausfälle (Stufe 3, ökonomische LGD) |           2220 |              nan |
| 7 Verlust gesamt = 5 + 6                               |           3977 |              nan |
| Info: Verlustschätzung Ausfälle mit nominaler LGD      |           1931 |              nan |

## 08_marge_nach_risikokosten · stressfenster_test

| produktgruppe     | fenster                       |   beobachtungen |   ausfaelle_12m |   pd_12m_prozent |   durchschn_ratingklasse |
|:------------------|:------------------------------|----------------:|----------------:|-----------------:|-------------------------:|
| Konsumentenkredit | 1 Auszahlung außerhalb        |           17427 |             280 |             1.61 |                     4.56 |
| Konsumentenkredit | 2 Auszahlung im Stressfenster |           10636 |             241 |             2.27 |                     4.62 |
| Immobilienkredit  | 1 Auszahlung außerhalb        |            3754 |              16 |             0.43 |                     4.1  |
| Immobilienkredit  | 2 Auszahlung im Stressfenster |            1233 |              14 |             1.14 |                     4.16 |

## 08_marge_nach_risikokosten · marge_nach_rating_konsumentenkredite

|   ratingklasse |   kredite_neugeschaeft_ab_2024 |   sollzins_prozent |   refinanzierung_prozent |   pd_12m_prozent |   pd_12m_ohne_stress_prozent |   lgd_oekonomisch_prozent |   risikokosten_prozent |   marge_nach_risikokosten_prozent |   marge_ohne_stressfenster_prozent |
|---------------:|-------------------------------:|-------------------:|-------------------------:|-----------------:|-----------------------------:|--------------------------:|-----------------------:|----------------------------------:|-----------------------------------:|
|              1 |                            409 |               5.97 |                        3 |             0.22 |                         0.23 |                      51.6 |                   0.11 |                              2.85 |                               2.85 |
|              2 |                            677 |               6.27 |                        3 |             0.09 |                         0.07 |                      51.6 |                   0.05 |                              3.22 |                               3.23 |
|              3 |                           1353 |               6.54 |                        3 |             0.39 |                         0.36 |                      51.6 |                   0.2  |                              3.34 |                               3.35 |
|              4 |                           1770 |               6.84 |                        3 |             1.07 |                         0.9  |                      51.6 |                   0.55 |                              3.29 |                               3.38 |
|              5 |                           1883 |               7.15 |                        3 |             1.51 |                         1.51 |                      51.6 |                   0.78 |                              3.37 |                               3.37 |
|              6 |                           1483 |               7.47 |                        3 |             2.32 |                         1.95 |                      51.6 |                   1.2  |                              3.28 |                               3.46 |
|              7 |                            818 |               7.78 |                        3 |             4.25 |                         3.51 |                      51.6 |                   2.19 |                              2.59 |                               2.97 |
|              8 |                            366 |               8.07 |                        3 |             7.7  |                         6.38 |                      51.6 |                   3.97 |                              1.1  |                               1.78 |
|              9 |                            117 |               8.32 |                        3 |            10.68 |                        10.17 |                      51.6 |                   5.51 |                             -0.19 |                               0.08 |
|             10 |                             41 |               8.88 |                        3 |            20.24 |                        21.31 |                      51.6 |                  10.44 |                             -4.56 |                              -5.12 |
