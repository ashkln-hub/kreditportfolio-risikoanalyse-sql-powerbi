"""
Schritt 2 – SQL-Pipeline

1. Legt die SQLite-Datenbank data/kreditportfolio.db nach sql/01_schema.sql an
2. Lädt die CSV-Rohdaten aus data/raw/
3. Führt die Analysen sql/02 … 08 aus und speichert jedes Ergebnis als CSV in ergebnisse/
   sowie eine Übersicht in ergebnisse/ERGEBNISSE.md
4. Baut das Power-BI-Datenmodell (sql/09) und exportiert es nach powerbi/daten/
"""

import re
import sqlite3
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
SQL = ROOT / "sql"
RAW = ROOT / "data" / "raw"
DB = ROOT / "data" / "kreditportfolio.db"
ERG = ROOT / "ergebnisse"
PBI = ROOT / "powerbi" / "daten"

TABELLEN = ["kunden", "kredite", "performance_monat", "verwertung"]  # Ladereihenfolge (Fremdschlüssel)
MARKER = re.compile(r"^--\s*@ergebnis:\s*(\w+)\s*$", re.MULTILINE)


def lade_rohdaten(con: sqlite3.Connection) -> None:
    for tabelle in TABELLEN:
        df = pd.read_csv(RAW / f"{tabelle}.csv")
        spalten = ", ".join(df.columns)
        platzhalter = ", ".join("?" * len(df.columns))
        werte = df.astype(object).where(df.notna(), None).itertuples(index=False, name=None)
        con.executemany(f"INSERT INTO {tabelle} ({spalten}) VALUES ({platzhalter})", werte)
        print(f"  geladen: {tabelle:<18} {len(df):>9,} Zeilen")
    con.commit()


def fuehre_analysen_aus(con: sqlite3.Connection) -> list[tuple[str, str, pd.DataFrame]]:
    ergebnisse = []
    for datei in sorted(SQL.glob("0[2-8]_*.sql")):
        text = datei.read_text(encoding="utf-8")
        teile = MARKER.split(text)
        # teile = [Kopf, name1, sql1, name2, sql2, …]
        for name, abfrage in zip(teile[1::2], teile[2::2]):
            df = pd.read_sql_query(abfrage.strip().rstrip(";"), con)
            ziel = ERG / f"{datei.stem}__{name}.csv"
            df.to_csv(ziel, index=False, encoding="utf-8-sig", sep=";", decimal=",")
            ergebnisse.append((datei.stem, name, df))
            print(f"  {datei.stem} → {name}: {len(df)} Zeilen")
    return ergebnisse


def schreibe_uebersicht(ergebnisse) -> None:
    zeilen = ["# Ergebnisse der SQL-Analysen", "",
              "Automatisch erzeugt von `src/02_sql_pipeline.py`. "
              "Alle Werte basieren auf synthetischen Daten.", ""]
    for datei, name, df in ergebnisse:
        zeilen += [f"## {datei} · {name}", ""]
        anzeige = df if len(df) <= 25 else df.head(25)
        zeilen.append(anzeige.to_markdown(index=False))
        if len(df) > 25:
            zeilen.append(f"\n*… {len(df) - 25} weitere Zeilen in `{datei}__{name}.csv`*")
        zeilen.append("")
    (ERG / "ERGEBNISSE.md").write_text("\n".join(zeilen), encoding="utf-8")


def exportiere_powerbi(con: sqlite3.Connection) -> None:
    con.executescript((SQL / "09_powerbi_datenmodell.sql").read_text(encoding="utf-8"))
    namen = [r[0] for r in con.execute(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND (name LIKE 'dim_%' OR name LIKE 'fact_%')")]
    for name in sorted(namen):
        df = pd.read_sql_query(f"SELECT * FROM {name}", con)
        df.to_csv(PBI / f"{name}.csv", index=False, encoding="utf-8")
        print(f"  exportiert: {name:<22} {len(df):>7,} Zeilen")


def main() -> None:
    ERG.mkdir(exist_ok=True)
    PBI.mkdir(parents=True, exist_ok=True)
    DB.unlink(missing_ok=True)

    con = sqlite3.connect(DB)
    print("1) Schema anlegen")
    con.executescript((SQL / "01_schema.sql").read_text(encoding="utf-8"))
    print("2) Rohdaten laden")
    lade_rohdaten(con)
    print("3) Analysen ausführen")
    ergebnisse = fuehre_analysen_aus(con)
    schreibe_uebersicht(ergebnisse)
    print("4) Power-BI-Datenmodell exportieren")
    exportiere_powerbi(con)
    con.close()

    dq = next(df for d, n, df in ergebnisse if n == "pruefungen")
    fehler = int(dq["fehler"].sum())
    print(f"\nDatenqualität: {len(dq)} Prüfungen, {fehler} Fehler")


if __name__ == "__main__":
    main()
