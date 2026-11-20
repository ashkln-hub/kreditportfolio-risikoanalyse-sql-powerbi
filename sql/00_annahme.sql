-- =====================================================================
-- 00 – Annahme: alle Modellannahmen an EINER Stelle
-- Die Analysen 07, 08 und 09 lesen ihre Parameter ausschließlich aus der
-- Tabelle "annahme". Wert hier ändern und src/02_sql_pipeline.py neu ausführen.
-- Die Werte sind gesetzte Annahmen, keine aus den Daten geschätzten Größen.
-- =====================================================================

DROP TABLE IF EXISTS annahme;
CREATE TABLE annahme (
    parameter    TEXT PRIMARY KEY,
    wert         REAL,      -- Zahlenwert (Anteil, nicht Prozent)
    datum        TEXT,      -- Datumswert (ISO), falls der Parameter ein Datum ist
    einheit      TEXT,
    beschreibung TEXT NOT NULL
);

INSERT INTO annahme (parameter, wert, datum, einheit, beschreibung) VALUES
    ('refinanzierung_pa',   0.03,   NULL,         'Anteil p. a.',
     'Refinanzierungskosten Konsumentenkredite, fest und vereinfacht (Marge nach Risikokosten)'),
    ('pd_floor',            0.0005, NULL,         'Anteil',
     'PD-Untergrenze 0,05 % je Ratingklasse, angelehnt an den Retail-PD-Floor nach Basel III final (CRR3)'),
    ('diskontsatz_pa',      0.03,   NULL,         'Anteil p. a.',
     'Diskontsatz für Verwertungserlöse über die Abwicklungsdauer (ökonomische LGD)'),
    ('workout_kosten',      0.00,   NULL,         'Anteil der EAD',
     'Interne Abwicklungskosten je Verwertung, Standard 0 % (ökonomische LGD)'),
    ('stressfenster_von',   NULL,   '2022-07-01', 'Datum',
     'Beginn des im Generator eingebauten Stressaufschlags (PD × 1,25 für Auszahlungen ab diesem Datum)'),
    ('stressfenster_bis',   NULL,   '2023-12-31', 'Datum',
     'Ende des Stressaufschlags (Auszahlungen bis einschließlich diesem Datum), Variante der Pricing-PD');

-- @ergebnis: parameter
SELECT parameter,
       wert,
       datum,
       einheit,
       beschreibung
FROM annahme
ORDER BY rowid;
