-- =====================================================================
-- 04 – Rückstände und NPL-Quote im Zeitverlauf
-- NPL (Non-Performing Loans) = Kredite mit 90+ Tagen Zahlungsverzug (Ausfall)
-- =====================================================================

-- @ergebnis: npl_entwicklung_monatlich
WITH monat AS (
    SELECT stichtag,
           SUM(restschuld)                                                       AS bestand,
           SUM(CASE WHEN tage_ueberfaellig BETWEEN 1 AND 89 THEN restschuld ELSE 0 END) AS rueckstand_1_89,
           SUM(CASE WHEN status = 'Ausfall' THEN restschuld ELSE 0 END)          AS npl
    FROM performance_monat
    WHERE restschuld > 0
    GROUP BY stichtag
)
SELECT stichtag,
       ROUND(bestand / 1e6, 1)                                AS bestand_mio_eur,
       ROUND(npl / 1e6, 2)                                    AS npl_mio_eur,
       ROUND(100.0 * npl / bestand, 2)                        AS npl_quote_prozent,
       ROUND(100.0 * (rueckstand_1_89 + npl) / bestand, 2)    AS quote_30_plus_prozent,
       -- Veränderung der NPL-Quote ggü. Vorjahresmonat (Prozentpunkte)
       ROUND(100.0 * npl / bestand
             - LAG(100.0 * npl / bestand, 12) OVER (ORDER BY stichtag), 2) AS npl_veraenderung_vj_pp
FROM monat
WHERE stichtag >= '2021-06-30'          -- Anlaufphase des Portfolios ausblenden
ORDER BY stichtag;

-- @ergebnis: dpd_buckets_nach_produkt
WITH letzter AS (SELECT MAX(stichtag) AS stichtag FROM performance_monat)
SELECT k.produkt,
       ROUND(100.0 * SUM(CASE WHEN p.tage_ueberfaellig = 0               THEN p.restschuld ELSE 0 END) / SUM(p.restschuld), 2) AS vertragsgemaess_prozent,
       ROUND(100.0 * SUM(CASE WHEN p.tage_ueberfaellig BETWEEN 1 AND 30 THEN p.restschuld ELSE 0 END) / SUM(p.restschuld), 2) AS dpd_1_30_prozent,
       ROUND(100.0 * SUM(CASE WHEN p.tage_ueberfaellig BETWEEN 31 AND 89 THEN p.restschuld ELSE 0 END) / SUM(p.restschuld), 2) AS dpd_31_89_prozent,
       ROUND(100.0 * SUM(CASE WHEN p.tage_ueberfaellig >= 90              THEN p.restschuld ELSE 0 END) / SUM(p.restschuld), 2) AS npl_90_plus_prozent
FROM performance_monat p
JOIN kredite k ON k.kredit_id = p.kredit_id
WHERE p.stichtag = (SELECT stichtag FROM letzter) AND p.restschuld > 0
GROUP BY k.produkt
ORDER BY npl_90_plus_prozent DESC;
