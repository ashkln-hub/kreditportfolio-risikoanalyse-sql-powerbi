-- =====================================================================
-- 05 – Vintage-Analyse (Jahrgangsanalyse)
-- Kumulierte Ausfallrate je Auszahlungsjahrgang nach Monaten seit Auszahlung (MOB).
-- Ein MOB-Punkt wird nur ausgewiesen, wenn mind. 90 % des Jahrgangs ihn bereits erreicht haben
-- (sonst verzerrt die schrumpfende Stichprobe das Kurvenende).
-- =====================================================================

-- @ergebnis: vintage_kurven
WITH monatsindex AS (
    SELECT k.kredit_id,
           k.produkt,
           strftime('%Y', k.auszahlungsdatum) || '-H' ||
               CASE WHEN CAST(strftime('%m', k.auszahlungsdatum) AS INTEGER) <= 6 THEN '1' ELSE '2' END AS jahrgang,
           -- beobachtbare Monate bis zum Ende der Historie
           (CAST(strftime('%Y', '2026-09-30') AS INTEGER) * 12 + CAST(strftime('%m', '2026-09-30') AS INTEGER))
         - (CAST(strftime('%Y', k.auszahlungsdatum) AS INTEGER) * 12 + CAST(strftime('%m', k.auszahlungsdatum) AS INTEGER))
                                                                        AS mob_beobachtbar,
           (CAST(strftime('%Y', v.ausfalldatum) AS INTEGER) * 12 + CAST(strftime('%m', v.ausfalldatum) AS INTEGER))
         - (CAST(strftime('%Y', k.auszahlungsdatum) AS INTEGER) * 12 + CAST(strftime('%m', k.auszahlungsdatum) AS INTEGER))
                                                                        AS mob_ausfall
    FROM kredite k
    LEFT JOIN verwertung v ON v.kredit_id = k.kredit_id
),
mob_punkte (mob) AS (VALUES (3), (6), (9), (12), (18), (24), (30), (36), (42), (48)),
jahrgangsgroesse AS (
    SELECT jahrgang, COUNT(*) AS kredite_gesamt
    FROM monatsindex WHERE produkt IN ('Ratenkredit', 'Autokredit')
    GROUP BY jahrgang
)
SELECT m.jahrgang,
       p.mob                                                         AS monate_seit_auszahlung,
       COUNT(*)                                                      AS kredite_beobachtbar,
       SUM(CASE WHEN m.mob_ausfall <= p.mob THEN 1 ELSE 0 END)       AS ausfaelle_kumuliert,
       ROUND(100.0 * SUM(CASE WHEN m.mob_ausfall <= p.mob THEN 1 ELSE 0 END) / COUNT(*), 2)
                                                                     AS ausfallrate_kumuliert_prozent
FROM monatsindex m
JOIN mob_punkte p ON m.mob_beobachtbar >= p.mob
JOIN jahrgangsgroesse g ON g.jahrgang = m.jahrgang
WHERE m.produkt IN ('Ratenkredit', 'Autokredit')   -- Konsumentenkredite (Baufinanzierung separat zu klein)
GROUP BY m.jahrgang, p.mob
HAVING COUNT(*) >= 0.9 * MAX(g.kredite_gesamt)
ORDER BY m.jahrgang, p.mob;

-- @ergebnis: vintage_vergleich_12_24_mob
WITH kurve AS (
    SELECT k.kredit_id,
           strftime('%Y', k.auszahlungsdatum) AS jahrgang,
           (CAST(strftime('%Y', '2026-09-30') AS INTEGER) * 12 + CAST(strftime('%m', '2026-09-30') AS INTEGER))
         - (CAST(strftime('%Y', k.auszahlungsdatum) AS INTEGER) * 12 + CAST(strftime('%m', k.auszahlungsdatum) AS INTEGER)) AS mob_beobachtbar,
           (CAST(strftime('%Y', v.ausfalldatum) AS INTEGER) * 12 + CAST(strftime('%m', v.ausfalldatum) AS INTEGER))
         - (CAST(strftime('%Y', k.auszahlungsdatum) AS INTEGER) * 12 + CAST(strftime('%m', k.auszahlungsdatum) AS INTEGER)) AS mob_ausfall
    FROM kredite k
    LEFT JOIN verwertung v ON v.kredit_id = k.kredit_id
    WHERE k.produkt IN ('Ratenkredit', 'Autokredit')
)
SELECT jahrgang,
       ROUND(100.0 * SUM(CASE WHEN mob_beobachtbar >= 12 AND mob_ausfall <= 12 THEN 1 ELSE 0 END)
             / NULLIF(SUM(CASE WHEN mob_beobachtbar >= 12 THEN 1 ELSE 0 END), 0), 2) AS ausfallrate_12_mob_prozent,
       ROUND(100.0 * SUM(CASE WHEN mob_beobachtbar >= 24 AND mob_ausfall <= 24 THEN 1 ELSE 0 END)
             / NULLIF(SUM(CASE WHEN mob_beobachtbar >= 24 THEN 1 ELSE 0 END), 0), 2) AS ausfallrate_24_mob_prozent
FROM kurve
GROUP BY jahrgang
HAVING SUM(CASE WHEN mob_beobachtbar >= 12 THEN 1 ELSE 0 END) > 0
ORDER BY jahrgang;
