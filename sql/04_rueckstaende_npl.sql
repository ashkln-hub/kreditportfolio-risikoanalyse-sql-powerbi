-- =====================================================================
-- 04 – Rückstände und NPL-Quote im Zeitverlauf
-- NPL (Non-Performing Loans) = Kredite mit 90+ Tagen Zahlungsverzug (Ausfall)
-- Die NPL-Quote ist ein Bruch (NPL-Volumen / Bestand). Sie wird immer zusammen
-- mit dem NPL-Volumen ausgewiesen: Wächst der Bestand schnell, sinkt die Quote
-- auch dann, wenn das NPL-Volumen steigt (Nennereffekt).
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
       ROUND((npl - LAG(npl, 12) OVER (ORDER BY stichtag)) / 1e6, 2) AS npl_veraenderung_vj_mio_eur,
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

-- @ergebnis: npl_quote_zerlegung
-- Warum sinkt die Quote, obwohl das NPL-Volumen steigt? Vergleich Höchststand 07/2024 mit dem letzten Stichtag:
--   * Nennereffekt: Quote, wenn der Bestand auf dem Stand 07/2024 geblieben wäre
--   * Seasoning: Anteil junger Kredite (< 12 Monate seit Auszahlung), die noch kaum ausfallen können
--   * Abgang: Ausfälle bleiben nur bis zum Ende der Verwertung im Bestand (Raten 18, Auto 6, Bau 24 Monate)
WITH monat AS (
    SELECT stichtag,
           SUM(restschuld)                                                         AS bestand,
           SUM(CASE WHEN status = 'Ausfall' THEN restschuld ELSE 0 END)            AS npl,
           SUM(CASE WHEN monate_seit_auszahlung < 12 THEN restschuld ELSE 0 END)   AS bestand_unter_12_mob
    FROM performance_monat
    WHERE restschuld > 0
      AND stichtag IN ('2024-07-31', '2025-09-30', '2026-09-30')
    GROUP BY stichtag
),
abgang AS (   -- Ausfälle, deren Verwertung in den 12 Monaten bis zum Stichtag abgeschlossen wurde (Abgang aus dem Bestand)
    SELECT m.stichtag,
           COUNT(v.kredit_id)        AS abgaenge_12m,
           SUM(v.ead)                AS abgang_ead_12m
    FROM monat m
    LEFT JOIN verwertung v ON v.abschlussdatum >  date(m.stichtag, '+1 day', '-12 months', '-1 day')
                          AND v.abschlussdatum <= m.stichtag
    GROUP BY m.stichtag
)
SELECT m.stichtag,
       ROUND(m.bestand / 1e6, 1)                                                AS bestand_mio_eur,
       ROUND(m.npl / 1e6, 2)                                                    AS npl_mio_eur,
       ROUND(100.0 * m.npl / m.bestand, 2)                                      AS npl_quote_prozent,
       ROUND(100.0 * m.npl / (SELECT bestand FROM monat WHERE stichtag = '2024-07-31'), 2)
                                                                                AS npl_quote_bei_bestand_07_2024_prozent,
       ROUND(100.0 * m.bestand_unter_12_mob / m.bestand, 1)                     AS anteil_bestand_unter_12_monate_prozent,
       a.abgaenge_12m                                                           AS abgeschlossene_verwertungen_12m,
       ROUND(COALESCE(a.abgang_ead_12m, 0) / 1e6, 2)                            AS abgang_aus_npl_12m_mio_eur
FROM monat m
JOIN abgang a ON a.stichtag = m.stichtag
ORDER BY m.stichtag;
