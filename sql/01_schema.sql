-- =====================================================================
-- 01 – Datenbankschema (SQLite)
-- Vier Tabellen: Kunden, Kredite, monatliche Performance, Verwertung
-- =====================================================================

PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS verwertung;
DROP TABLE IF EXISTS performance_monat;
DROP TABLE IF EXISTS kredite;
DROP TABLE IF EXISTS kunden;

CREATE TABLE kunden (
    kunden_id               TEXT    PRIMARY KEY,
    alter_bei_antrag        INTEGER NOT NULL CHECK (alter_bei_antrag BETWEEN 18 AND 100),
    beschaeftigung          TEXT    NOT NULL,
    netto_einkommen_monat   REAL    NOT NULL CHECK (netto_einkommen_monat > 0),
    region                  TEXT    NOT NULL
);

CREATE TABLE kredite (
    kredit_id               TEXT    PRIMARY KEY,
    kunden_id               TEXT    NOT NULL REFERENCES kunden (kunden_id),
    produkt                 TEXT    NOT NULL CHECK (produkt IN ('Ratenkredit', 'Autokredit', 'Baufinanzierung')),
    auszahlungsdatum        TEXT    NOT NULL,              -- ISO-Datum YYYY-MM-DD
    kreditbetrag            REAL    NOT NULL CHECK (kreditbetrag > 0),
    laufzeit_monate         INTEGER NOT NULL,              -- Baufinanzierung: Zinsbindung
    zinssatz_pa             REAL    NOT NULL,              -- Sollzins in % p. a.
    rate_monat              REAL    NOT NULL,
    ratingklasse            INTEGER NOT NULL CHECK (ratingklasse BETWEEN 1 AND 10),
    kapitaldienstquote      REAL    NOT NULL,              -- Rate / Nettoeinkommen
    beleihungsauslauf       REAL,                          -- nur Baufinanzierung (LTV)
    sicherheit              TEXT    NOT NULL
);

CREATE TABLE performance_monat (
    kredit_id               TEXT    NOT NULL REFERENCES kredite (kredit_id),
    stichtag                TEXT    NOT NULL,              -- Monatsultimo
    monate_seit_auszahlung  INTEGER NOT NULL,
    restschuld              REAL    NOT NULL,
    tage_ueberfaellig       INTEGER NOT NULL,              -- Days Past Due (DPD)
    status                  TEXT    NOT NULL,              -- Laufend | Rückstand | Ausfall | Getilgt | Vorzeitig getilgt
    PRIMARY KEY (kredit_id, stichtag)
);

CREATE TABLE verwertung (
    kredit_id               TEXT    PRIMARY KEY REFERENCES kredite (kredit_id),
    ausfalldatum            TEXT    NOT NULL,              -- Stichtag, an dem 90 DPD erreicht wurden
    ead                     REAL    NOT NULL,              -- Exposure at Default
    verwertungserloes       REAL,                          -- NULL, solange die Verwertung läuft
    abschlussdatum          TEXT,
    status                  TEXT    NOT NULL               -- laufend | abgeschlossen
);

CREATE INDEX idx_perf_stichtag ON performance_monat (stichtag);
CREATE INDEX idx_kredite_kunde ON kredite (kunden_id);
