-- =====================================================================
-- 07 – Expected Loss (EL = PD × LGD × EAD) und Verlustschätzung für Ausfälle
--
--   PD Rating   : beobachtete 12-Monats-Ausfallrate je Produktgruppe und Ratingklasse,
--                 Kohorten = nicht ausgefallene Kredite an vier Jahresstichtagen 2022–2025.
--                 pd                 = alle nicht ausgefallenen Kredite (jährliche Ausfallrate,
--                                      Basis für das Pricing in sql/08 und für die PD-Tabelle)
--                 pd_vertragsgemaess = nur Kredite ohne Rückstand am Kohortenstichtag
--                                      (Stufe-1-EL; Kredite im Rückstand erhalten die Verzugs-PD,
--                                      sonst würden ihre Ausfälle doppelt gezählt)
--                 Untergrenze pd_floor aus der Tabelle "annahme" (sql/00_annahme.sql).
--   PD Verzug   : beobachtete 12-Monats-Ausfallrate für Kredite mit 30 bzw. 60 Tagen
--                 Rückstand (alle Monatsultimos mit 12 Monaten Nachbeobachtung).
--                 Monatliche Roll Rates (sql/06) sind KEINE 12-Monats-PDs.
--   LGD         : nominal    = 1 − Erlös / EAD
--                 ökonomisch = 1 − (Erlös abgezinst über die Abwicklungsdauer − Abwicklungskosten) / EAD
--                 nur abgeschlossene Verwertungen, Parameter aus "annahme".
--   EAD         : Restschuld zum letzten Stichtag.
--
-- Einteilung in Anlehnung an IFRS 9 (KEIN vollständiges IFRS-9-Modell: keine
-- Lifetime-PD für Stufe 2, keine Zukunftsszenarien, keine Diskontierung der EL):
--   Stufe 1 = vertragsgemäß           → 12-Monats-EL mit Rating-PD
--   Stufe 2 = Rückstand 30 / 60 Tage  → 12-Monats-EL mit Verzugs-PD
--   Stufe 3 = Ausfall (90+ Tage)      → Verlustschätzung = Restschuld × LGD (PD = 100 %)
--
-- Die folgenden Sichten (v_*) werden von sql/08 und sql/09 wiederverwendet.
-- =====================================================================

DROP VIEW IF EXISTS v_el_basis;
DROP VIEW IF EXISTS v_lgd;
DROP VIEW IF EXISTS v_verwertung_bewertet;
DROP VIEW IF EXISTS v_pd_verzug;
DROP VIEW IF EXISTS v_pd_rating;

-- PD je Produktgruppe und Ratingklasse (mit Variante ohne Stressfenster für sql/08)
CREATE VIEW v_pd_rating AS
WITH kohorte AS (
    SELECT p.kredit_id,
           p.stichtag,
           p.status,
           CASE WHEN k.produkt = 'Baufinanzierung' THEN 'Immobilienkredit' ELSE 'Konsumentenkredit' END AS produktgruppe,
           k.ratingklasse,
           CASE WHEN k.auszahlungsdatum BETWEEN (SELECT datum FROM annahme WHERE parameter = 'stressfenster_von')
                                            AND (SELECT datum FROM annahme WHERE parameter = 'stressfenster_bis')
                THEN 1 ELSE 0 END AS im_stressfenster,
           CASE WHEN v.ausfalldatum >  p.stichtag
                 AND v.ausfalldatum <= date(p.stichtag, '+12 months') THEN 1 ELSE 0 END AS ausfall_12m
    FROM performance_monat p
    JOIN kredite k ON k.kredit_id = p.kredit_id
    LEFT JOIN verwertung v ON v.kredit_id = p.kredit_id
    WHERE p.stichtag IN ('2022-09-30', '2023-09-30', '2024-09-30', '2025-09-30')
      AND p.status IN ('Laufend', 'Rückstand')
),
roh AS (
    SELECT produktgruppe,
           ratingklasse,
           COUNT(*)                                                      AS beobachtungen,
           SUM(ausfall_12m)                                              AS ausfaelle_12m,
           1.0 * SUM(ausfall_12m) / COUNT(*)                             AS pd_roh,
           SUM(im_stressfenster = 0)                                     AS beobachtungen_ohne_stress,
           SUM(CASE WHEN im_stressfenster = 0 THEN ausfall_12m END)     AS ausfaelle_ohne_stress,
           1.0 * SUM(CASE WHEN im_stressfenster = 0 THEN ausfall_12m END)
               / SUM(im_stressfenster = 0)                               AS pd_ohne_stress_roh,
           SUM(status = 'Laufend')                                       AS beobachtungen_vertragsgemaess,
           SUM(CASE WHEN status = 'Laufend' THEN ausfall_12m END)       AS ausfaelle_vertragsgemaess,
           1.0 * SUM(CASE WHEN status = 'Laufend' THEN ausfall_12m END)
               / SUM(status = 'Laufend')                                 AS pd_vertragsgemaess_roh
    FROM kohorte
    GROUP BY produktgruppe, ratingklasse
)
SELECT r.*,
       MAX(r.pd_roh,                 (SELECT wert FROM annahme WHERE parameter = 'pd_floor')) AS pd,
       MAX(r.pd_ohne_stress_roh,     (SELECT wert FROM annahme WHERE parameter = 'pd_floor')) AS pd_ohne_stress,
       MAX(r.pd_vertragsgemaess_roh, (SELECT wert FROM annahme WHERE parameter = 'pd_floor')) AS pd_vertragsgemaess
FROM roh r;

-- 12-Monats-PD je Verzugsstufe, direkt aus Kohorten geschätzt (alle Produkte gepoolt)
CREATE VIEW v_pd_verzug AS
SELECT CASE WHEN p.status = 'Laufend'          THEN '1 | vertragsgemäß'
            WHEN p.tage_ueberfaellig <= 30     THEN '2 | 30 Tage'
            ELSE '3 | 60 Tage' END                                        AS verzugsstufe,
       COUNT(*)                                                           AS beobachtungen,
       SUM(CASE WHEN v.ausfalldatum >  p.stichtag
                 AND v.ausfalldatum <= date(p.stichtag, '+12 months') THEN 1 ELSE 0 END) AS ausfaelle_12m,
       1.0 * SUM(CASE WHEN v.ausfalldatum >  p.stichtag
                       AND v.ausfalldatum <= date(p.stichtag, '+12 months') THEN 1 ELSE 0 END) / COUNT(*) AS pd
FROM performance_monat p
LEFT JOIN verwertung v ON v.kredit_id = p.kredit_id
WHERE p.status IN ('Laufend', 'Rückstand')
  AND p.stichtag <= date((SELECT MAX(stichtag) FROM performance_monat), '+1 day', '-12 months', '-1 day')
GROUP BY verzugsstufe;

-- Abgeschlossene Verwertungen mit Barwert der Erlöse
CREATE VIEW v_verwertung_bewertet AS
SELECT v.kredit_id,
       k.produkt,
       CASE WHEN k.produkt = 'Baufinanzierung' THEN 'Immobilienkredit' ELSE 'Konsumentenkredit' END AS produktgruppe,
       v.ead,
       v.verwertungserloes,
       (julianday(v.abschlussdatum) - julianday(v.ausfalldatum)) / 365.25                  AS abwicklung_jahre,
       v.verwertungserloes
           / power(1 + (SELECT wert FROM annahme WHERE parameter = 'diskontsatz_pa'),
                   (julianday(v.abschlussdatum) - julianday(v.ausfalldatum)) / 365.25)
         - (SELECT wert FROM annahme WHERE parameter = 'workout_kosten') * v.ead            AS erloes_netto_barwert
FROM verwertung v
JOIN kredite k ON k.kredit_id = v.kredit_id
WHERE v.status = 'abgeschlossen';

-- LGD je Produkt: nominal und ökonomisch
CREATE VIEW v_lgd AS
SELECT produkt,
       COUNT(*)                                          AS abgeschlossene_verwertungen,
       SUM(ead)                                          AS ead,
       12 * AVG(abwicklung_jahre)                        AS abwicklung_monate,
       1 - SUM(verwertungserloes)    / SUM(ead)          AS lgd_nominal,
       1 - SUM(erloes_netto_barwert) / SUM(ead)          AS lgd_oekonomisch
FROM v_verwertung_bewertet
GROUP BY produkt;

-- Einzelkredite zum letzten Stichtag mit Stufe, PD und LGD (Basis für EL und fact_expected_loss)
CREATE VIEW v_el_basis AS
SELECT p.kredit_id,
       p.stichtag,
       k.produkt,
       CASE WHEN k.produkt = 'Baufinanzierung' THEN 'Immobilienkredit' ELSE 'Konsumentenkredit' END AS produktgruppe,
       c.region,
       k.ratingklasse,
       CASE p.status WHEN 'Ausfall' THEN 3 WHEN 'Rückstand' THEN 2 ELSE 1 END     AS stufe,
       CASE WHEN p.tage_ueberfaellig = 0               THEN '1 vertragsgemäß'
            WHEN p.tage_ueberfaellig BETWEEN 1 AND 30  THEN '2 Verzug 1–30 Tage'
            WHEN p.tage_ueberfaellig BETWEEN 31 AND 89 THEN '3 Verzug 31–89 Tage'
            ELSE '4 Ausfall 90+ Tage' END                                          AS verzugsstatus,
       p.restschuld                                                                AS ead,
       CASE WHEN p.status = 'Ausfall' THEN NULL ELSE r.pd_vertragsgemaess_roh END  AS pd_rating_roh,
       CASE WHEN p.status = 'Ausfall' THEN NULL ELSE r.pd_vertragsgemaess     END  AS pd_rating,
       CASE WHEN p.status = 'Ausfall' THEN NULL ELSE r.pd_roh                 END  AS pd_bisher,
       CASE p.status WHEN 'Ausfall'   THEN 1.0
                     WHEN 'Rückstand' THEN b.pd
                     ELSE r.pd_vertragsgemaess END                                 AS pd_12m,
       l.lgd_nominal,
       l.lgd_oekonomisch                                                           AS lgd
FROM performance_monat p
JOIN kredite k ON k.kredit_id = p.kredit_id
JOIN kunden  c ON c.kunden_id = k.kunden_id
JOIN v_lgd   l ON l.produkt   = k.produkt
LEFT JOIN v_pd_rating r ON r.ratingklasse = k.ratingklasse
                       AND r.produktgruppe = CASE WHEN k.produkt = 'Baufinanzierung' THEN 'Immobilienkredit' ELSE 'Konsumentenkredit' END
LEFT JOIN v_pd_verzug b ON b.verzugsstufe = CASE WHEN p.tage_ueberfaellig <= 30 THEN '2 | 30 Tage' ELSE '3 | 60 Tage' END
WHERE p.stichtag = (SELECT MAX(stichtag) FROM performance_monat)
  AND p.restschuld > 0;

-- @ergebnis: pd_nach_ratingklasse
-- pd_12m_roh = beobachtete Ausfallrate, pd_12m = nach PD-Floor (Annahme). Die Kurve wird nicht geglättet.
-- pd_vertragsgemaess = Kohorte ohne Kredite im Rückstand, verwendet für die Stufe-1-EL.
SELECT produktgruppe,
       ratingklasse,
       beobachtungen,
       ausfaelle_12m,
       ROUND(100 * pd_roh, 2)                                AS pd_12m_roh_prozent,
       ROUND(100 * pd, 2)                                    AS pd_12m_prozent,
       CASE WHEN pd > pd_roh THEN 'ja' ELSE 'nein' END       AS floor_greift,
       ausfaelle_vertragsgemaess,
       ROUND(100 * pd_vertragsgemaess, 2)                    AS pd_vertragsgemaess_prozent
FROM v_pd_rating
ORDER BY produktgruppe DESC, ratingklasse;

-- @ergebnis: pd_nach_verzugsstatus
-- Plausibilisierung mit verketteten Roll Rates (sql/06, 10/2025–09/2026):
--   30 Tage: P(30→60) × P(60→Ausfall) ist eine Untergrenze (Wiederausfälle nach Heilung fehlen)
--   60 Tage: P(60→Ausfall) ist eine Untergrenze
WITH uebergang AS (
    SELECT CASE WHEN tage_ueberfaellig BETWEEN 1 AND 30  AND status = 'Rückstand' THEN '30'
                WHEN tage_ueberfaellig BETWEEN 31 AND 89 AND status = 'Rückstand' THEN '60' END AS von,
           LEAD(CASE WHEN status = 'Ausfall' THEN 'A'
                     WHEN status = 'Rückstand' AND tage_ueberfaellig BETWEEN 31 AND 89 THEN '60'
                     ELSE 'X' END) OVER (PARTITION BY kredit_id ORDER BY stichtag)           AS nach,
           stichtag
    FROM performance_monat
),
roll AS (
    SELECT 1.0 * SUM(von = '30' AND nach = '60') / SUM(von = '30') AS r_30_60,
           1.0 * SUM(von = '60' AND nach = 'A')  / SUM(von = '60') AS r_60_a
    FROM uebergang
    WHERE von IS NOT NULL AND nach IS NOT NULL
      AND stichtag BETWEEN '2025-09-30' AND '2026-08-31'
)
SELECT v.verzugsstufe,
       v.beobachtungen,
       v.ausfaelle_12m,
       ROUND(100 * v.pd, 2)                                                    AS pd_12m_prozent,
       ROUND(100 * CASE v.verzugsstufe WHEN '2 | 30 Tage' THEN r.r_30_60 * r.r_60_a
                                       WHEN '3 | 60 Tage' THEN r.r_60_a END, 2) AS untergrenze_roll_rates_prozent,
       CASE v.verzugsstufe WHEN '1 | vertragsgemäß' THEN 'nur zum Vergleich, EL nutzt die Rating-PD'
                           ELSE 'PD für Kredite im Rückstand (Stufe 2)' END     AS verwendung
FROM v_pd_verzug v
CROSS JOIN roll r
ORDER BY v.verzugsstufe;

-- @ergebnis: lgd_nach_produkt
SELECT l.produkt,
       l.abgeschlossene_verwertungen,
       (SELECT COUNT(*) FROM verwertung v JOIN kredite k ON k.kredit_id = v.kredit_id
         WHERE v.status = 'laufend' AND k.produkt = l.produkt)          AS laufende_verwertungen,
       ROUND(l.ead / 1e6, 2)                                             AS ead_mio_eur,
       ROUND(l.abwicklung_monate, 0)                                     AS abwicklung_monate,
       ROUND(100 * l.lgd_nominal, 1)                                     AS lgd_nominal_prozent,
       ROUND(100 * l.lgd_oekonomisch, 1)                                 AS lgd_oekonomisch_prozent
FROM v_lgd l
ORDER BY l.lgd_nominal DESC;

-- @ergebnis: expected_loss_nach_produkt
-- "lebend" = Stufe 1 + 2 (12-Monats-EL), "Ausfall" = Stufe 3 (Verlustschätzung), alles mit ökonomischer LGD
WITH je_produkt AS (
    SELECT produkt,
           SUM(CASE WHEN stufe < 3 THEN ead END)                        AS ead_lebend,
           SUM(CASE WHEN stufe < 3 THEN ead * pd_12m END)               AS ead_x_pd,
           SUM(CASE WHEN stufe < 3 THEN ead * pd_12m * lgd END)         AS el_lebend,
           SUM(CASE WHEN stufe = 3 THEN ead END)                        AS ead_ausfall,
           SUM(CASE WHEN stufe = 3 THEN ead * lgd END)                  AS verlust_ausfall
    FROM v_el_basis
    GROUP BY produkt
    UNION ALL
    SELECT 'Gesamt',
           SUM(CASE WHEN stufe < 3 THEN ead END),
           SUM(CASE WHEN stufe < 3 THEN ead * pd_12m END),
           SUM(CASE WHEN stufe < 3 THEN ead * pd_12m * lgd END),
           SUM(CASE WHEN stufe = 3 THEN ead END),
           SUM(CASE WHEN stufe = 3 THEN ead * lgd END)
    FROM v_el_basis
)
SELECT produkt,
       ROUND(ead_lebend / 1e6, 1)                                AS ead_lebend_mio_eur,
       ROUND(100 * ead_x_pd / ead_lebend, 2)                     AS pd_gewichtet_prozent,
       ROUND(100 * el_lebend / ead_x_pd, 1)                      AS lgd_prozent,
       ROUND(el_lebend / 1e3, 0)                                 AS el_lebend_tsd_eur,
       ROUND(100 * el_lebend / ead_lebend, 3)                    AS el_quote_lebend_prozent,
       ROUND(ead_ausfall / 1e6, 2)                               AS ead_ausfall_mio_eur,
       ROUND(verlust_ausfall / 1e3, 0)                           AS verlust_ausfall_tsd_eur,
       ROUND((el_lebend + verlust_ausfall) / 1e3, 0)             AS verlust_gesamt_tsd_eur,
       ROUND((ead_lebend + ead_ausfall) / 1e6, 1)                AS bestand_mio_eur
FROM je_produkt
ORDER BY produkt = 'Gesamt', produkt;

-- @ergebnis: expected_loss_nach_stufe
SELECT CAST(stufe AS TEXT)                                                   AS stufe,
       CASE stufe WHEN 1 THEN 'vertragsgemäß (12-Monats-EL, Rating-PD)'
                  WHEN 2 THEN 'Rückstand 30/60 Tage (12-Monats-EL, Verzugs-PD)'
                  ELSE 'Ausfall 90+ (Verlustschätzung, PD = 100 %)' END    AS bezeichnung,
       COUNT(*)                                                              AS anzahl_kredite,
       ROUND(SUM(ead) / 1e6, 2)                                              AS ead_mio_eur,
       ROUND(100 * SUM(ead * pd_12m) / SUM(ead), 2)                          AS pd_gewichtet_prozent,
       ROUND(100 * SUM(ead * pd_12m * lgd) / SUM(ead * pd_12m), 1)           AS lgd_prozent,
       ROUND(SUM(ead * pd_12m * lgd) / 1e3, 0)                               AS verlust_tsd_eur
FROM v_el_basis
GROUP BY stufe
UNION ALL
SELECT 'Gesamt', 'Bestand gesamt', COUNT(*), ROUND(SUM(ead) / 1e6, 2),
       NULL,   -- keine Gesamt-PD: ein Mittel über Stufe 3 (PD = 100 %) wäre keine sinnvolle PD
       ROUND(100 * SUM(ead * pd_12m * lgd) / SUM(ead * pd_12m), 1),
       ROUND(SUM(ead * pd_12m * lgd) / 1e3, 0)
FROM v_el_basis;

-- @ergebnis: expected_loss_ueberleitung
-- Schrittweise Überleitung vom bisherigen Expected Loss zur neuen Verlustschätzung (Tsd. €).
-- Jeder Schritt ändert genau eine Annahme, die Differenz zeigt deren Effekt.
WITH w AS (
    SELECT SUM(CASE WHEN stufe < 3 THEN ead * pd_bisher     * lgd_nominal END) AS s1,
           SUM(CASE WHEN stufe < 3 THEN ead * pd_rating_roh * lgd_nominal END) AS s2,
           SUM(CASE WHEN stufe < 3 THEN ead * pd_rating     * lgd_nominal END) AS s3,
           SUM(CASE WHEN stufe < 3 THEN ead * pd_rating     * lgd         END) AS s4,
           SUM(CASE WHEN stufe < 3 THEN ead * pd_12m        * lgd         END) AS s5,
           SUM(CASE WHEN stufe = 3 THEN ead                 * lgd         END) AS s6,
           SUM(CASE WHEN stufe = 3 THEN ead                 * lgd_nominal END) AS s6_nominal
    FROM v_el_basis
)
SELECT '1 Bisher: EL lebende Kredite (alte PD, nominale LGD)'                AS schritt, ROUND(s1 / 1e3, 0) AS wert_tsd_eur, NULL AS effekt_tsd_eur FROM w
UNION ALL SELECT '2 Stufe 1: Rating-PD aus vertragsgemäßer Kohorte',          ROUND(s2 / 1e3, 0), ROUND((s2 - s1) / 1e3, 0) FROM w
UNION ALL SELECT '3 PD-Floor 0,05 % (Annahme)',                               ROUND(s3 / 1e3, 0), ROUND((s3 - s2) / 1e3, 0) FROM w
UNION ALL SELECT '4 Ökonomische LGD (Abzinsung 3 %, Kosten 0 %)',             ROUND(s4 / 1e3, 0), ROUND((s4 - s3) / 1e3, 0) FROM w
UNION ALL SELECT '5 Verzugs-PD für Kredite im Rückstand = EL lebend',         ROUND(s5 / 1e3, 0), ROUND((s5 - s4) / 1e3, 0) FROM w
UNION ALL SELECT '6 Verlustschätzung Ausfälle (Stufe 3, ökonomische LGD)',    ROUND(s6 / 1e3, 0), NULL FROM w
UNION ALL SELECT '7 Verlust gesamt = 5 + 6',                                  ROUND((s5 + s6) / 1e3, 0), NULL FROM w
UNION ALL SELECT 'Info: Verlustschätzung Ausfälle mit nominaler LGD',         ROUND(s6_nominal / 1e3, 0), NULL FROM w;
