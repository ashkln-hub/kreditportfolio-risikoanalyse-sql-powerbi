-- =====================================================================
-- 06 – Roll-Rate-Analyse (Übergangsmatrix)
-- Mit welcher Wahrscheinlichkeit wechselt ein Kredit von einem Verzugsstatus
-- in den nächsten Monat? Basis: Übergänge der letzten 12 Monate.
-- =====================================================================

-- @ergebnis: uebergangsmatrix
WITH mit_folgemonat AS (
    SELECT kredit_id,
           stichtag,
           CASE WHEN status = 'Laufend'                THEN '1 | vertragsgemäß'
                WHEN tage_ueberfaellig BETWEEN 1 AND 30  THEN '2 | 30 Tage'
                WHEN tage_ueberfaellig BETWEEN 31 AND 89 THEN '3 | 60 Tage'
           END AS von_status,
           LEAD(CASE WHEN status IN ('Getilgt', 'Vorzeitig getilgt') THEN '5 | getilgt'
                     WHEN status = 'Ausfall'                          THEN '4 | Ausfall (90+)'
                     WHEN status = 'Laufend'                          THEN '1 | vertragsgemäß'
                     WHEN tage_ueberfaellig BETWEEN 1 AND 30          THEN '2 | 30 Tage'
                     ELSE '3 | 60 Tage' END)
               OVER (PARTITION BY kredit_id ORDER BY stichtag) AS nach_status
    FROM performance_monat
)
SELECT von_status,
       nach_status,
       COUNT(*)                                                           AS uebergaenge,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY von_status), 2) AS anteil_prozent
FROM mit_folgemonat
WHERE von_status IS NOT NULL
  AND nach_status IS NOT NULL
  AND stichtag BETWEEN '2025-09-30' AND '2026-08-31'
GROUP BY von_status, nach_status
ORDER BY von_status, nach_status;
