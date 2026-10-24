"""
Schritt 3 – Grafiken für das README aus den SQL-Ergebnissen erzeugen.
Ausgabe: ergebnisse/grafiken/*.png
"""

from pathlib import Path

import matplotlib.pyplot as plt
import matplotlib.ticker as mtick
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
ERG = ROOT / "ergebnisse"
OUT = ERG / "grafiken"
PBI = ROOT / "powerbi" / "daten"

BLAU, ORANGE, AQUA = "#2a78d6", "#eb6834", "#1baf7a"
ROT = "#e34948"
TEXT, TEXT2, GRID, FLAECHE = "#0b0b0b", "#52514e", "#e4e3df", "#fcfcfb"

plt.rcParams.update({
    "font.family": "DejaVu Sans", "font.size": 10,
    "axes.facecolor": FLAECHE, "figure.facecolor": FLAECHE,
    "axes.edgecolor": GRID, "axes.labelcolor": TEXT2, "xtick.color": TEXT2, "ytick.color": TEXT2,
    "axes.grid": True, "grid.color": GRID, "grid.linewidth": 0.8, "axes.axisbelow": True,
    "axes.spines.top": False, "axes.spines.right": False, "axes.titleweight": "bold",
    "axes.titlesize": 12, "axes.titlelocation": "left", "axes.titlecolor": TEXT,
})


def lies(name: str) -> pd.DataFrame:
    return pd.read_csv(ERG / f"{name}.csv", sep=";", decimal=",", encoding="utf-8-sig")


def speichern(fig, name: str) -> None:
    fig.tight_layout()
    fig.savefig(OUT / f"{name}.png", dpi=160)
    plt.close(fig)
    print(f"  {name}.png")


def npl_verlauf() -> None:
    df = lies("04_rueckstaende_npl__npl_entwicklung_monatlich")
    df["stichtag"] = pd.to_datetime(df["stichtag"])
    fig, ax = plt.subplots(figsize=(9, 4))
    ax.plot(df["stichtag"], df["quote_30_plus_prozent"], color=ORANGE, lw=2, label="30+ Tage Verzug")
    ax.plot(df["stichtag"], df["npl_quote_prozent"], color=BLAU, lw=2, label="NPL-Quote (90+ Tage)")
    for spalte, farbe in [("quote_30_plus_prozent", ORANGE), ("npl_quote_prozent", BLAU)]:
        letzter = df.iloc[-1]
        ax.annotate(f"{letzter[spalte]:.2f} %".replace(".", ","), (letzter["stichtag"], letzter[spalte]),
                    xytext=(6, 0), textcoords="offset points", va="center", color=TEXT, fontsize=9)
    ax.yaxis.set_major_formatter(mtick.FuncFormatter(lambda v, _: f"{v:.1f} %".replace(".", ",")))
    ax.set_title("Verzugs- und NPL-Quote des Portfolios (in % der Restschuld)")
    ax.legend(frameon=False, loc="upper left")
    ax.set_xlim(df["stichtag"].min(), df["stichtag"].max() + pd.Timedelta(days=120))
    speichern(fig, "01_npl_quote")


def vintage_kurven() -> None:
    df = pd.read_csv(PBI / "fact_vintage.csv")
    df = df[df["produkt"].isin(["Ratenkredit", "Autokredit"])]
    agg = df.groupby(["jahrgang", "monate_seit_auszahlung"])[["kredite_beobachtbar", "ausfaelle_kumuliert"]].sum()
    agg = agg.reset_index()
    # nur MOB-Punkte, die mind. 90 % des Jahrgangs erreicht haben
    groesse = agg.groupby("jahrgang")["kredite_beobachtbar"].transform("max")
    agg = agg[(agg["kredite_beobachtbar"] >= 0.9 * groesse) & (agg["jahrgang"] <= 2025)]
    agg["rate"] = 100 * agg["ausfaelle_kumuliert"] / agg["kredite_beobachtbar"]
    jahre = sorted(agg["jahrgang"].unique())
    fig, ax = plt.subplots(figsize=(9, 4.4))
    for j in jahre:
        d = agg[agg["jahrgang"] == j]
        hervor = j == 2023
        ax.plot(d["monate_seit_auszahlung"], d["rate"], lw=2.6 if hervor else 1.6,
                color=ORANGE if hervor else BLAU, alpha=1 if hervor else 0.35 + 0.12 * (j - 2021),
                marker="o", ms=4, label=f"Jahrgang {j}")
        ax.annotate(str(j), (d["monate_seit_auszahlung"].iloc[-1], d["rate"].iloc[-1]),
                    xytext=(5, 0), textcoords="offset points", va="center", fontsize=9,
                    color=TEXT, fontweight="bold" if hervor else "normal")
    ax.set_xlabel("Monate seit Auszahlung")
    ax.yaxis.set_major_formatter(mtick.FuncFormatter(lambda v, _: f"{v:.0f} %"))
    ax.set_title("Vintage-Analyse Konsumentenkredite: kumulierte Ausfallrate je Jahrgang")
    ax.legend(frameon=False, loc="upper left", ncol=2)
    speichern(fig, "02_vintage_kurven")


def pd_nach_rating() -> None:
    df = lies("07_expected_loss__pd_nach_ratingklasse")
    klassen = np.arange(1, 11)
    k = df[df["produktgruppe"] == "Konsumentenkredit"].set_index("ratingklasse").reindex(klassen)
    i = df[df["produktgruppe"] == "Immobilienkredit"].set_index("ratingklasse").reindex(klassen)
    fig, ax = plt.subplots(figsize=(9, 4))
    b = 0.38
    ax.bar(klassen - b / 2 - 0.01, k["pd_12m_prozent"], width=b, color=BLAU, label="Konsumentenkredite")
    ax.bar(klassen + b / 2 + 0.01, i["pd_12m_prozent"], width=b, color=AQUA, label="Baufinanzierung")
    for x, v in zip(klassen, k["pd_12m_prozent"]):
        if x >= 7:
            ax.annotate(f"{v:.1f} %".replace(".", ","), (x - b / 2, v), xytext=(0, 3),
                        textcoords="offset points", ha="center", fontsize=8.5, color=TEXT)
    ax.set_xticks(klassen)
    ax.set_xlabel("Ratingklasse (1 = beste Bonität)")
    ax.yaxis.set_major_locator(mtick.MultipleLocator(5))
    ax.yaxis.set_major_formatter(mtick.FuncFormatter(lambda v, _: f"{v:.0f} %"))
    ax.set_title("Beobachtete 12-Monats-Ausfallrate (PD) je Ratingklasse")
    ax.legend(frameon=False, loc="upper left")
    speichern(fig, "03_pd_nach_rating")


def marge_nach_rating() -> None:
    df = lies("08_risikoadjustierte_marge__marge_nach_rating_konsumentenkredite")
    fig, ax = plt.subplots(figsize=(9, 4))
    farben = [ROT if v < 0 else BLAU for v in df["risikoadj_marge_prozent"]]
    ax.bar(df["ratingklasse"], df["risikoadj_marge_prozent"], color=farben, width=0.6)
    ax.axhline(0, color=TEXT2, lw=1)
    for x, v in zip(df["ratingklasse"], df["risikoadj_marge_prozent"]):
        ax.annotate(f"{v:+.2f}".replace(".", ","), (x, v), xytext=(0, 3 if v >= 0 else -12),
                    textcoords="offset points", ha="center", fontsize=8.5, color=TEXT)
    ax.set_xticks(df["ratingklasse"])
    ax.set_xlabel("Ratingklasse")
    ax.set_ylabel("Prozentpunkte p. a.")
    ax.set_title("Risikoadjustierte Marge Konsumentenkredite (Neugeschäft ab 2024)")
    ax.set_ylim(df["risikoadj_marge_prozent"].min() - 1.2, df["risikoadj_marge_prozent"].max() + 0.8)
    ax.text(0.99, 0.97, "rot = Zins deckt Refinanzierung + Risikokosten nicht", transform=ax.transAxes,
            ha="right", va="top", fontsize=8.5, color=TEXT2)
    speichern(fig, "04_risikoadjustierte_marge")


def roll_rates() -> None:
    df = lies("06_roll_rates__uebergangsmatrix")
    m = df.pivot(index="von_status", columns="nach_status", values="anteil_prozent").fillna(0)
    zeilen = [z.split(" | ")[1] for z in m.index]
    spalten = [s.split(" | ")[1] for s in m.columns]
    fig, ax = plt.subplots(figsize=(9, 3.4))
    ax.imshow(m.values, cmap="Blues", vmin=0, vmax=100, aspect="auto")
    ax.grid(False)
    ax.set_xticks(range(len(spalten)), spalten)
    ax.set_yticks(range(len(zeilen)), zeilen)
    ax.set_xlabel("Status im Folgemonat")
    for r in range(m.shape[0]):
        for c in range(m.shape[1]):
            v = m.values[r, c]
            ax.text(c, r, f"{v:.1f} %".replace(".", ","), ha="center", va="center", fontsize=9,
                    color="white" if v > 55 else TEXT)
    ax.set_title("Roll Rates: Übergänge pro Monat, 10/2025–09/2026")
    speichern(fig, "05_roll_rates")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    npl_verlauf()
    vintage_kurven()
    pd_nach_rating()
    marge_nach_rating()
    roll_rates()


if __name__ == "__main__":
    main()
