-- =====================================================================
-- 08 – Risikoadjustierte Marge (Risk-based Pricing)
-- Deckt der Zinsaufschlag je Ratingklasse die erwarteten Verluste?
--   Risikokosten p. a. = PD (12 Monate) × LGD
--   Risikoadjustierte Marge = Sollzins − Refinanzierung − Risikokosten
-- Annahme Refinanzierungskosten: Konsumentenkredite 3,0 % p. a.
-- =====================================================================

-- @ergebnis: marge_nach_rating_konsumentenkredite
WITH pd_tab AS (
    SELECT k.ratingklasse,
           1.0 * SUM(CASE WHEN v.ausfalldatum > p.stichtag
                           AND v.ausfalldatum <= date(p.stichtag, '+12 months') THEN 1 ELSE 0 END) / COUNT(*) AS pd
    FROM performance_monat p
    JOIN kredite k ON k.kredit_id = p.kredit_id
    LEFT JOIN verwertung v ON v.kredit_id = p.kredit_id
    WHERE p.stichtag IN ('2022-09-30', '2023-09-30', '2024-09-30', '2025-09-30')
      AND p.status IN ('Laufend', 'Rückstand')
      AND k.produkt IN ('Ratenkredit', 'Autokredit')
    GROUP BY k.ratingklasse
),
lgd_tab AS (
    SELECT 1 - SUM(v.verwertungserloes) / SUM(v.ead) AS lgd
    FROM verwertung v JOIN kredite k ON k.kredit_id = v.kredit_id
    WHERE v.status = 'abgeschlossen' AND k.produkt IN ('Ratenkredit', 'Autokredit')
),
neugeschaeft AS (   -- Neugeschäft ab 2024 (aktuelles Zinsniveau)
    SELECT ratingklasse,
           COUNT(*) AS anzahl,
           SUM(kreditbetrag * zinssatz_pa) / SUM(kreditbetrag) AS zins
    FROM kredite
    WHERE produkt IN ('Ratenkredit', 'Autokredit') AND auszahlungsdatum >= '2024-01-01'
    GROUP BY ratingklasse
)
SELECT n.ratingklasse,
       n.anzahl                                                AS kredite_neugeschaeft_ab_2024,
       ROUND(n.zins, 2)                                        AS sollzins_prozent,
       3.00                                                    AS refinanzierung_prozent,
       ROUND(100 * d.pd * l.lgd, 2)                            AS risikokosten_prozent,
       ROUND(n.zins - 3.00 - 100 * d.pd * l.lgd, 2)            AS risikoadj_marge_prozent
FROM neugeschaeft n
JOIN pd_tab d ON d.ratingklasse = n.ratingklasse
CROSS JOIN lgd_tab l
ORDER BY n.ratingklasse;
