-- =====================================================================
-- 07 – Expected Loss (EL = PD × LGD × EAD)
--   PD  : beobachtete 12-Monats-Ausfallrate je Produktgruppe und Ratingklasse (Kohorten 2022–2025)
--   LGD : Verlustquote aus abgeschlossenen Verwertungen je Produkt (EAD-gewichtet)
--   EAD : Restschuld der nicht ausgefallenen Kredite zum letzten Stichtag
-- =====================================================================

-- @ergebnis: pd_nach_ratingklasse
WITH kohorte AS (
    -- Nicht ausgefallene Kredite an vier Jahresstichtagen
    SELECT p.kredit_id, p.stichtag, CASE WHEN k.produkt = 'Baufinanzierung' THEN 'Immobilienkredit' ELSE 'Konsumentenkredit' END AS produktgruppe, k.ratingklasse
    FROM performance_monat p
    JOIN kredite k ON k.kredit_id = p.kredit_id
    WHERE p.stichtag IN ('2022-09-30', '2023-09-30', '2024-09-30', '2025-09-30')
      AND p.status IN ('Laufend', 'Rückstand')
),
mit_ausfall AS (
    SELECT c.produktgruppe, c.ratingklasse,
           CASE WHEN v.ausfalldatum >  c.stichtag
                 AND v.ausfalldatum <= date(c.stichtag, '+12 months') THEN 1 ELSE 0 END AS ausfall_12m
    FROM kohorte c
    LEFT JOIN verwertung v ON v.kredit_id = c.kredit_id
)
SELECT produktgruppe,
       ratingklasse,
       COUNT(*)                                  AS beobachtungen,
       SUM(ausfall_12m)                          AS ausfaelle_12m,
       ROUND(100.0 * SUM(ausfall_12m) / COUNT(*), 2) AS pd_12m_prozent
FROM mit_ausfall
GROUP BY produktgruppe, ratingklasse
ORDER BY produktgruppe DESC, ratingklasse;

-- @ergebnis: lgd_nach_produkt
SELECT k.produkt,
       COUNT(*)                                                       AS abgeschlossene_verwertungen,
       ROUND(SUM(v.ead) / 1e6, 2)                                     AS ead_mio_eur,
       ROUND(100.0 * (1 - SUM(v.verwertungserloes) / SUM(v.ead)), 1)  AS lgd_prozent
FROM verwertung v
JOIN kredite k ON k.kredit_id = v.kredit_id
WHERE v.status = 'abgeschlossen'
GROUP BY k.produkt
ORDER BY lgd_prozent DESC;

-- @ergebnis: expected_loss_nach_produkt
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
),
bestand AS (
    SELECT k.produkt, CASE WHEN k.produkt = 'Baufinanzierung' THEN 'Immobilienkredit' ELSE 'Konsumentenkredit' END AS produktgruppe, k.ratingklasse, p.restschuld AS ead
    FROM performance_monat p
    JOIN kredite k ON k.kredit_id = p.kredit_id
    WHERE p.stichtag = (SELECT MAX(stichtag) FROM performance_monat)
      AND p.status IN ('Laufend', 'Rückstand')
      AND p.restschuld > 0
)
SELECT b.produkt,
       ROUND(SUM(b.ead) / 1e6, 1)                               AS ead_mio_eur,
       ROUND(100.0 * SUM(b.ead * d.pd) / SUM(b.ead), 2)         AS pd_gewichtet_prozent,
       ROUND(100.0 * MAX(l.lgd), 1)                             AS lgd_prozent,
       ROUND(SUM(b.ead * d.pd * l.lgd) / 1e3, 0)                AS expected_loss_tsd_eur,
       ROUND(100.0 * SUM(b.ead * d.pd * l.lgd) / SUM(b.ead), 3) AS el_quote_prozent
FROM bestand b
JOIN pd_tab  d ON d.ratingklasse = b.ratingklasse AND d.produktgruppe = b.produktgruppe
JOIN lgd_tab l ON l.produkt      = b.produkt
GROUP BY b.produkt
UNION ALL
SELECT 'Gesamt',
       ROUND(SUM(b.ead) / 1e6, 1),
       ROUND(100.0 * SUM(b.ead * d.pd) / SUM(b.ead), 2),
       ROUND(100.0 * SUM(b.ead * d.pd * l.lgd) / SUM(b.ead * d.pd), 1),
       ROUND(SUM(b.ead * d.pd * l.lgd) / 1e3, 0),
       ROUND(100.0 * SUM(b.ead * d.pd * l.lgd) / SUM(b.ead), 3)
FROM bestand b
JOIN pd_tab  d ON d.ratingklasse = b.ratingklasse AND d.produktgruppe = b.produktgruppe
JOIN lgd_tab l ON l.produkt      = b.produkt;
