-- =====================================================================
-- 09 – Datenmodell für Power BI (Sternschema)
-- Dimensionen (dim_*) und Faktentabellen (fact_*) werden als CSV nach
-- powerbi/daten/ exportiert und dort in Power BI geladen.
-- =====================================================================

-- ---------- Dimensionen ----------------------------------------------

DROP TABLE IF EXISTS dim_datum;
CREATE TABLE dim_datum AS
WITH RECURSIVE monate (datum) AS (
    SELECT '2021-01-31'
    UNION ALL
    SELECT date(datum, '+1 day', '+1 month', '-1 day') FROM monate WHERE datum < '2026-09-30'
)
SELECT datum,
       CAST(strftime('%Y', datum) AS INTEGER)                              AS jahr,
       'Q' || ((CAST(strftime('%m', datum) AS INTEGER) + 2) / 3)          AS quartal,
       CAST(strftime('%m', datum) AS INTEGER)                              AS monat_nr,
       CASE strftime('%m', datum)
            WHEN '01' THEN 'Jan' WHEN '02' THEN 'Feb' WHEN '03' THEN 'Mär' WHEN '04' THEN 'Apr'
            WHEN '05' THEN 'Mai' WHEN '06' THEN 'Jun' WHEN '07' THEN 'Jul' WHEN '08' THEN 'Aug'
            WHEN '09' THEN 'Sep' WHEN '10' THEN 'Okt' WHEN '11' THEN 'Nov' ELSE 'Dez' END
         || ' ' || strftime('%Y', datum)                                   AS monat_jahr,
       CAST(strftime('%Y', datum) AS INTEGER) * 100 + CAST(strftime('%m', datum) AS INTEGER) AS monat_sort
FROM monate;

DROP TABLE IF EXISTS dim_produkt;
CREATE TABLE dim_produkt AS
SELECT DISTINCT produkt,
       CASE WHEN produkt = 'Baufinanzierung' THEN 'Immobilienkredit' ELSE 'Konsumentenkredit' END AS produktgruppe,
       sicherheit,
       CASE produkt WHEN 'Ratenkredit' THEN 1 WHEN 'Autokredit' THEN 2 ELSE 3 END              AS sortierung
FROM kredite;

DROP TABLE IF EXISTS dim_region;
CREATE TABLE dim_region AS
SELECT DISTINCT region FROM kunden;

DROP TABLE IF EXISTS dim_rating;
CREATE TABLE dim_rating AS
SELECT ratingklasse,
       CASE WHEN ratingklasse <= 2 THEN 'Sehr gut (1–2)'
            WHEN ratingklasse <= 4 THEN 'Gut (3–4)'
            WHEN ratingklasse <= 6 THEN 'Mittel (5–6)'
            WHEN ratingklasse <= 8 THEN 'Erhöht (7–8)'
            ELSE 'Hoch (9–10)' END                AS risikoband,
       (ratingklasse + 1) / 2                     AS risikoband_sortierung
FROM (SELECT DISTINCT ratingklasse FROM kredite);

-- ---------- Fakten ---------------------------------------------------

DROP TABLE IF EXISTS fact_bestand_monat;
CREATE TABLE fact_bestand_monat AS
SELECT p.stichtag                                     AS datum,
       k.produkt,
       c.region,
       k.ratingklasse,
       CASE WHEN p.tage_ueberfaellig = 0               THEN '1 vertragsgemäß'
            WHEN p.tage_ueberfaellig BETWEEN 1 AND 30  THEN '2 Verzug 1–30 Tage'
            WHEN p.tage_ueberfaellig BETWEEN 31 AND 89 THEN '3 Verzug 31–89 Tage'
            ELSE '4 Ausfall 90+ Tage' END             AS verzugsstatus,
       COUNT(*)                                       AS anzahl_kredite,
       ROUND(SUM(p.restschuld), 2)                    AS restschuld,
       ROUND(SUM(p.restschuld * k.zinssatz_pa), 2)    AS restschuld_x_zins
FROM performance_monat p
JOIN kredite k ON k.kredit_id = p.kredit_id
JOIN kunden  c ON c.kunden_id = k.kunden_id
WHERE p.restschuld > 0
GROUP BY p.stichtag, k.produkt, c.region, k.ratingklasse, verzugsstatus;

DROP TABLE IF EXISTS fact_neugeschaeft;
CREATE TABLE fact_neugeschaeft AS
SELECT date(k.auszahlungsdatum, 'start of month', '+1 month', '-1 day') AS datum,
       k.produkt,
       c.region,
       k.ratingklasse,
       COUNT(*)                                     AS anzahl_kredite,
       ROUND(SUM(k.kreditbetrag), 2)                AS volumen,
       ROUND(SUM(k.kreditbetrag * k.zinssatz_pa), 2) AS volumen_x_zins
FROM kredite k
JOIN kunden c ON c.kunden_id = k.kunden_id
GROUP BY 1, 2, 3, 4;

DROP TABLE IF EXISTS fact_vintage;
CREATE TABLE fact_vintage AS
WITH basis AS (
    SELECT k.produkt,
           strftime('%Y', k.auszahlungsdatum)              AS jahrgang,
           (2026 * 12 + 9)
         - (CAST(strftime('%Y', k.auszahlungsdatum) AS INTEGER) * 12 + CAST(strftime('%m', k.auszahlungsdatum) AS INTEGER)) AS mob_beobachtbar,
           (CAST(strftime('%Y', v.ausfalldatum) AS INTEGER) * 12 + CAST(strftime('%m', v.ausfalldatum) AS INTEGER))
         - (CAST(strftime('%Y', k.auszahlungsdatum) AS INTEGER) * 12 + CAST(strftime('%m', k.auszahlungsdatum) AS INTEGER)) AS mob_ausfall
    FROM kredite k
    LEFT JOIN verwertung v ON v.kredit_id = k.kredit_id
),
mob (m) AS (
    SELECT 3 UNION ALL SELECT m + 3 FROM mob WHERE m < 60
),
groesse AS (
    SELECT jahrgang, produkt, COUNT(*) AS kredite_gesamt FROM basis GROUP BY jahrgang, produkt
)
SELECT b.jahrgang,
       b.produkt,
       mob.m                                               AS monate_seit_auszahlung,
       COUNT(*)                                            AS kredite_beobachtbar,
       SUM(CASE WHEN b.mob_ausfall <= mob.m THEN 1 ELSE 0 END) AS ausfaelle_kumuliert,
       -- 1 = mind. 90 % des Jahrgangs haben diesen MOB erreicht (für Diagramme verwenden)
       CASE WHEN COUNT(*) >= 0.9 * MAX(g.kredite_gesamt) THEN 1 ELSE 0 END AS repraesentativ
FROM basis b
JOIN mob ON b.mob_beobachtbar >= mob.m
JOIN groesse g ON g.jahrgang = b.jahrgang AND g.produkt = b.produkt
GROUP BY b.jahrgang, b.produkt, mob.m;

DROP TABLE IF EXISTS fact_expected_loss;
CREATE TABLE fact_expected_loss AS
WITH pd_tab AS (
    SELECT CASE WHEN k.produkt = 'Baufinanzierung' THEN 'Immobilienkredit' ELSE 'Konsumentenkredit' END AS produktgruppe,
           k.ratingklasse,
           1.0 * SUM(CASE WHEN v.ausfalldatum > p.stichtag
                           AND v.ausfalldatum <= date(p.stichtag, '+12 months') THEN 1 ELSE 0 END) / COUNT(*) AS pd
    FROM performance_monat p
    JOIN kredite k ON k.kredit_id = p.kredit_id
    LEFT JOIN verwertung v ON v.kredit_id = p.kredit_id
    WHERE p.stichtag IN ('2022-09-30', '2023-09-30', '2024-09-30', '2025-09-30')
      AND p.status IN ('Laufend', 'Rückstand')
    GROUP BY produktgruppe, k.ratingklasse
),
lgd_tab AS (
    SELECT k.produkt, 1 - SUM(v.verwertungserloes) / SUM(v.ead) AS lgd
    FROM verwertung v JOIN kredite k ON k.kredit_id = v.kredit_id
    WHERE v.status = 'abgeschlossen'
    GROUP BY k.produkt
)
SELECT p.stichtag                                AS datum,
       k.produkt,
       c.region,
       k.ratingklasse,
       COUNT(*)                                  AS anzahl_kredite,
       ROUND(SUM(p.restschuld), 2)               AS ead,
       ROUND(MAX(d.pd), 5)                       AS pd_12m,
       ROUND(MAX(l.lgd), 4)                      AS lgd,
       ROUND(SUM(p.restschuld) * MAX(d.pd) * MAX(l.lgd), 2) AS expected_loss
FROM performance_monat p
JOIN kredite k ON k.kredit_id = p.kredit_id
JOIN kunden  c ON c.kunden_id = k.kunden_id
JOIN pd_tab  d ON d.ratingklasse = k.ratingklasse AND d.produktgruppe = CASE WHEN k.produkt = 'Baufinanzierung' THEN 'Immobilienkredit' ELSE 'Konsumentenkredit' END
JOIN lgd_tab l ON l.produkt = k.produkt
WHERE p.stichtag = (SELECT MAX(stichtag) FROM performance_monat)
  AND p.status IN ('Laufend', 'Rückstand')
  AND p.restschuld > 0
GROUP BY p.stichtag, k.produkt, c.region, k.ratingklasse;
