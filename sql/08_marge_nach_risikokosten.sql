-- =====================================================================
-- 08 – Marge nach Risikokosten (Risk-based Pricing), Konsumentenkredite
-- Deckt der Zinsaufschlag je Ratingklasse Refinanzierung und erwartete Verluste?
--   Risikokosten p. a.       = PD (12 Monate, mit Floor) × ökonomische LGD (Raten + Auto gepoolt)
--   Die PD ist die jährliche Ausfallrate aller nicht ausgefallenen Kredite (inkl. Rückstand),
--   denn jeder Ausfall läuft über 30 und 60 Tage Rückstand. Ohne diese Kredite wäre die
--   jährliche Ausfallrate eines neuen Kredits über seine Laufzeit zu niedrig.
--   Marge nach Risikokosten  = Sollzins − Refinanzierung − Risikokosten
-- NICHT enthalten: Betriebskosten und Eigenkapitalkosten. Die Kennzahl ist daher
-- keine vollständige Deckungsbeitragsrechnung.
-- Variante "ohne Stressfenster": Pricing-PD ohne Kredite, die im Stressfenster
-- (Auszahlung 07/2022–12/2023, Tabelle "annahme") ausgezahlt wurden.
-- Refinanzierung, PD-Floor, Diskontsatz und Stressfenster stehen in sql/00_annahme.sql.
-- =====================================================================

-- @ergebnis: stressfenster_test
-- Test vor der Variante: Haben Kredite aus dem Stressfenster eine höhere 12-Monats-PD?
-- (nicht ausgefallene Kredite an vier Jahresstichtagen, wie die Pricing-PD in sql/07)
WITH kohorte AS (
    SELECT CASE WHEN k.produkt = 'Baufinanzierung' THEN 'Immobilienkredit' ELSE 'Konsumentenkredit' END AS produktgruppe,
           CASE WHEN k.auszahlungsdatum BETWEEN (SELECT datum FROM annahme WHERE parameter = 'stressfenster_von')
                                            AND (SELECT datum FROM annahme WHERE parameter = 'stressfenster_bis')
                THEN '2 Auszahlung im Stressfenster' ELSE '1 Auszahlung außerhalb' END AS fenster,
           k.ratingklasse,
           CASE WHEN v.ausfalldatum >  p.stichtag
                 AND v.ausfalldatum <= date(p.stichtag, '+12 months') THEN 1 ELSE 0 END AS ausfall_12m
    FROM performance_monat p
    JOIN kredite k ON k.kredit_id = p.kredit_id
    LEFT JOIN verwertung v ON v.kredit_id = p.kredit_id
    WHERE p.stichtag IN ('2022-09-30', '2023-09-30', '2024-09-30', '2025-09-30')
      AND p.status IN ('Laufend', 'Rückstand')
)
SELECT produktgruppe,
       fenster,
       COUNT(*)                                       AS beobachtungen,
       SUM(ausfall_12m)                               AS ausfaelle_12m,
       ROUND(100.0 * SUM(ausfall_12m) / COUNT(*), 2)  AS pd_12m_prozent,
       ROUND(AVG(ratingklasse), 2)                    AS durchschn_ratingklasse
FROM kohorte
GROUP BY produktgruppe, fenster
ORDER BY produktgruppe DESC, fenster;

-- @ergebnis: marge_nach_rating_konsumentenkredite
WITH lgd_konsum AS (
    SELECT 1 - SUM(erloes_netto_barwert) / SUM(ead) AS lgd
    FROM v_verwertung_bewertet
    WHERE produktgruppe = 'Konsumentenkredit'
),
neugeschaeft AS (   -- Neugeschäft ab 2024 (aktuelles Zinsniveau)
    SELECT ratingklasse,
           COUNT(*)                                            AS anzahl,
           SUM(kreditbetrag * zinssatz_pa) / SUM(kreditbetrag) AS zins
    FROM kredite
    WHERE produkt IN ('Ratenkredit', 'Autokredit') AND auszahlungsdatum >= '2024-01-01'
    GROUP BY ratingklasse
)
SELECT n.ratingklasse,
       n.anzahl                                                                   AS kredite_neugeschaeft_ab_2024,
       ROUND(n.zins, 2)                                                           AS sollzins_prozent,
       ROUND(100 * a.wert, 2)                                                     AS refinanzierung_prozent,
       ROUND(100 * d.pd, 2)                                                       AS pd_12m_prozent,
       ROUND(100 * d.pd_ohne_stress, 2)                                           AS pd_12m_ohne_stress_prozent,
       ROUND(100 * l.lgd, 1)                                                      AS lgd_oekonomisch_prozent,
       ROUND(100 * d.pd * l.lgd, 2)                                               AS risikokosten_prozent,
       ROUND(n.zins - 100 * a.wert - 100 * d.pd * l.lgd, 2)                       AS marge_nach_risikokosten_prozent,
       ROUND(n.zins - 100 * a.wert - 100 * d.pd_ohne_stress * l.lgd, 2)           AS marge_ohne_stressfenster_prozent
FROM neugeschaeft n
JOIN v_pd_rating d ON d.ratingklasse = n.ratingklasse AND d.produktgruppe = 'Konsumentenkredit'
CROSS JOIN lgd_konsum l
CROSS JOIN (SELECT wert FROM annahme WHERE parameter = 'refinanzierung_pa') a
ORDER BY n.ratingklasse;
