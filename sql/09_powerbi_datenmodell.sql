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

-- Expected Loss je Stufe (in Anlehnung an IFRS 9, kein vollständiges IFRS-9-Modell).
-- Eine Faktentabelle statt zwei: Ausfälle (Stufe 3) haben dieselbe Körnung und dieselben
-- Dimensionen wie lebende Kredite. Mit PD = 100 % gilt EL = PD × LGD × EAD für alle Zeilen,
-- die Spalte "stufe" trennt die Teilsummen. Basis ist die Sicht v_el_basis aus sql/07.
DROP TABLE IF EXISTS fact_expected_loss;
CREATE TABLE fact_expected_loss AS
SELECT stichtag                                   AS datum,
       produkt,
       region,
       ratingklasse,
       verzugsstatus,
       stufe,
       COUNT(*)                                   AS anzahl_kredite,
       ROUND(SUM(ead), 2)                         AS ead,
       ROUND(MAX(pd_rating_roh), 5)               AS pd_rating_roh,   -- beobachtete Rating-PD
       ROUND(MAX(pd_rating), 5)                   AS pd_rating,       -- Rating-PD nach Floor
       ROUND(MAX(pd_12m), 5)                      AS pd_12m,          -- verwendete PD (Rating, Verzug oder 100 %)
       ROUND(MAX(lgd_nominal), 4)                 AS lgd_nominal,
       ROUND(MAX(lgd), 4)                         AS lgd,             -- ökonomische LGD
       ROUND(SUM(ead * pd_12m * lgd), 2)          AS expected_loss
FROM v_el_basis
GROUP BY stichtag, produkt, region, ratingklasse, verzugsstatus, stufe;

-- Risikokosten je Produkt und Ratingklasse für die Marge nach Risikokosten (identisch mit sql/08).
-- Raten- und Autokredite erhalten dieselben gepoolten Werte. Baufinanzierung ist nicht Teil der Margenanalyse.
DROP TABLE IF EXISTS fact_risikokosten;
CREATE TABLE fact_risikokosten AS
WITH lgd_konsum AS (
    SELECT 1 - SUM(erloes_netto_barwert) / SUM(ead) AS lgd
    FROM v_verwertung_bewertet
    WHERE produktgruppe = 'Konsumentenkredit'
)
SELECT pr.produkt,
       d.ratingklasse,
       ROUND(d.pd, 6)                             AS pd_12m,
       ROUND(d.pd_ohne_stress, 6)                 AS pd_12m_ohne_stress,
       ROUND(l.lgd, 6)                            AS lgd,
       (SELECT wert FROM annahme WHERE parameter = 'refinanzierung_pa') AS refinanzierung,
       ROUND(d.pd * l.lgd, 6)                     AS risikokosten,
       ROUND(d.pd_ohne_stress * l.lgd, 6)         AS risikokosten_ohne_stress
FROM v_pd_rating d
CROSS JOIN lgd_konsum l
CROSS JOIN (SELECT 'Ratenkredit' AS produkt UNION ALL SELECT 'Autokredit') pr
WHERE d.produktgruppe = 'Konsumentenkredit';
