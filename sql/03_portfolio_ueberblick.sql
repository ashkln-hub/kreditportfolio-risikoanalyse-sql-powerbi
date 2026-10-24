-- =====================================================================
-- 03 – Portfolioüberblick
-- Bestand zum letzten Stichtag, Neugeschäft je Jahr, Struktur nach Region und Rating
-- =====================================================================

-- @ergebnis: bestand_nach_produkt
WITH letzter AS (SELECT MAX(stichtag) AS stichtag FROM performance_monat),
bestand AS (
    SELECT k.produkt, k.zinssatz_pa, k.ratingklasse, p.restschuld
    FROM performance_monat p
    JOIN kredite k ON k.kredit_id = p.kredit_id
    WHERE p.stichtag = (SELECT stichtag FROM letzter)
      AND p.restschuld > 0
)
SELECT produkt,
       COUNT(*)                                                    AS anzahl_kredite,
       ROUND(SUM(restschuld) / 1e6, 1)                             AS bestand_mio_eur,
       ROUND(100.0 * SUM(restschuld) / SUM(SUM(restschuld)) OVER (), 1) AS anteil_prozent,
       ROUND(SUM(restschuld) / COUNT(*), 0)                        AS durchschn_restschuld_eur,
       ROUND(SUM(restschuld * zinssatz_pa) / SUM(restschuld), 2)   AS zins_volumengewichtet,
       ROUND(SUM(restschuld * ratingklasse) / SUM(restschuld), 1)  AS rating_volumengewichtet
FROM bestand
GROUP BY produkt
ORDER BY bestand_mio_eur DESC;

-- @ergebnis: neugeschaeft_nach_jahr
SELECT strftime('%Y', auszahlungsdatum)                          AS jahr,
       produkt,
       COUNT(*)                                                  AS anzahl_kredite,
       ROUND(SUM(kreditbetrag) / 1e6, 1)                         AS volumen_mio_eur,
       ROUND(SUM(kreditbetrag * zinssatz_pa) / SUM(kreditbetrag), 2) AS zins_volumengewichtet
FROM kredite
GROUP BY jahr, produkt
ORDER BY jahr, produkt;

-- @ergebnis: bestand_nach_region
WITH letzter AS (SELECT MAX(stichtag) AS stichtag FROM performance_monat)
SELECT c.region,
       COUNT(*)                                                    AS anzahl_kredite,
       ROUND(SUM(p.restschuld) / 1e6, 1)                           AS bestand_mio_eur,
       ROUND(100.0 * SUM(CASE WHEN p.status = 'Ausfall' THEN p.restschuld ELSE 0 END)
             / SUM(p.restschuld), 2)                               AS npl_quote_prozent
FROM performance_monat p
JOIN kredite k ON k.kredit_id = p.kredit_id
JOIN kunden  c ON c.kunden_id = k.kunden_id
WHERE p.stichtag = (SELECT stichtag FROM letzter) AND p.restschuld > 0
GROUP BY c.region
ORDER BY bestand_mio_eur DESC;

-- @ergebnis: ratingverteilung_neugeschaeft
SELECT ratingklasse,
       CASE WHEN ratingklasse <= 2 THEN 'Sehr gut (1–2)'
            WHEN ratingklasse <= 4 THEN 'Gut (3–4)'
            WHEN ratingklasse <= 6 THEN 'Mittel (5–6)'
            WHEN ratingklasse <= 8 THEN 'Erhöht (7–8)'
            ELSE 'Hoch (9–10)' END                               AS risikoband,
       COUNT(*)                                                  AS anzahl_kredite,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)        AS anteil_prozent,
       ROUND(AVG(zinssatz_pa), 2)                                AS durchschn_zins,
       ROUND(AVG(kapitaldienstquote) * 100, 1)                   AS durchschn_kapitaldienstquote_prozent
FROM kredite
GROUP BY ratingklasse
ORDER BY ratingklasse;
