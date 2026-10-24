-- =====================================================================
-- 02 – Datenqualitätsprüfung
-- Jede Prüfung liefert die Anzahl fehlerhafter Datensätze (Soll: 0).
-- =====================================================================

-- @ergebnis: pruefungen
SELECT 'Kredite ohne gültigen Kunden' AS pruefung, COUNT(*) AS fehler
FROM kredite k LEFT JOIN kunden c ON c.kunden_id = k.kunden_id
WHERE c.kunden_id IS NULL

UNION ALL
SELECT 'Doppelte Kredit-IDs', COUNT(*) - COUNT(DISTINCT kredit_id) FROM kredite

UNION ALL
SELECT 'Zinssatz außerhalb 0–20 %', COUNT(*) FROM kredite WHERE zinssatz_pa NOT BETWEEN 0 AND 20

UNION ALL
SELECT 'Baufinanzierung ohne Beleihungsauslauf', COUNT(*)
FROM kredite WHERE produkt = 'Baufinanzierung' AND beleihungsauslauf IS NULL

UNION ALL
SELECT 'Kapitaldienstquote über 100 %', COUNT(*) FROM kredite WHERE kapitaldienstquote > 1

UNION ALL
SELECT 'Performance-Sätze ohne Kredit', COUNT(*)
FROM performance_monat p LEFT JOIN kredite k ON k.kredit_id = p.kredit_id
WHERE k.kredit_id IS NULL

UNION ALL
SELECT 'Stichtag vor Auszahlung', COUNT(*)
FROM performance_monat p JOIN kredite k ON k.kredit_id = p.kredit_id
WHERE p.stichtag < k.auszahlungsdatum

UNION ALL
SELECT 'Negative Restschuld', COUNT(*) FROM performance_monat WHERE restschuld < 0

UNION ALL
SELECT 'Status und Tage überfällig widersprüchlich', COUNT(*)
FROM performance_monat
WHERE (status = 'Laufend'   AND tage_ueberfaellig <> 0)
   OR (status = 'Rückstand' AND tage_ueberfaellig NOT BETWEEN 1 AND 89)
   OR (status = 'Ausfall'   AND tage_ueberfaellig < 90)

UNION ALL
SELECT 'Ausfall ohne Verwertungsdatensatz', COUNT(DISTINCT p.kredit_id)
FROM performance_monat p LEFT JOIN verwertung v ON v.kredit_id = p.kredit_id
WHERE p.status = 'Ausfall' AND v.kredit_id IS NULL

UNION ALL
SELECT 'Verwertungserlös größer als EAD', COUNT(*) FROM verwertung WHERE verwertungserloes > ead

UNION ALL
SELECT 'Lücken in der Monatshistorie', COUNT(*)
FROM (
    SELECT kredit_id,
           monate_seit_auszahlung
             - LAG(monate_seit_auszahlung) OVER (PARTITION BY kredit_id ORDER BY stichtag) AS abstand
    FROM performance_monat
) WHERE abstand <> 1;

-- @ergebnis: tabellenumfang
SELECT 'kunden' AS tabelle, COUNT(*) AS datensaetze FROM kunden
UNION ALL SELECT 'kredite', COUNT(*) FROM kredite
UNION ALL SELECT 'performance_monat', COUNT(*) FROM performance_monat
UNION ALL SELECT 'verwertung', COUNT(*) FROM verwertung;
