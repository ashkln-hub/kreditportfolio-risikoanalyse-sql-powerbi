"""
Schritt 3 – Grafiken für das README aus den SQL-Ergebnissen erzeugen.
Ausgabe: ergebnisse/grafiken/*.png
"""

import sys
from pathlib import Path

import matplotlib.pyplot as plt
import matplotlib.ticker as mtick
import numpy as np
import pandas as pd


# Konsolenausgabe in UTF-8 (verhindert UnicodeEncodeError in der Windows-Konsole)
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

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
    """NPL-Quote immer zusammen mit dem NPL-Volumen zeigen (die Quote allein verdeckt den Nennereffekt)."""
    df = lies("04_rueckstaende_npl__npl_entwicklung_monatlich")
    df["stichtag"] = pd.to_datetime(df["stichtag"])
    fig, (ax, ax2) = plt.subplots(2, 1, figsize=(9, 6.4), sharex=True, gridspec_kw={"height_ratios": [1.15, 1]})
    ax.plot(df["stichtag"], df["quote_30_plus_prozent"], color=ORANGE, lw=2, label="30+ Tage Verzug")
    ax.plot(df["stichtag"], df["npl_quote_prozent"], color=BLAU, lw=2, label="NPL-Quote (90+ Tage)")
    letzter = df.iloc[-1]
    for spalte in ["quote_30_plus_prozent", "npl_quote_prozent"]:
        ax.annotate(f"{letzter[spalte]:.2f} %".replace(".", ","), (letzter["stichtag"], letzter[spalte]),
                    xytext=(6, 0), textcoords="offset points", va="center", color=TEXT, fontsize=9)
    ax.yaxis.set_major_formatter(mtick.FuncFormatter(lambda v, _: f"{v:.1f} %".replace(".", ",")))
    ax.set_title("Verzugs- und NPL-Quote (in % der Restschuld)")
    ax.legend(frameon=False, loc="upper left")

    ax2.fill_between(df["stichtag"], df["npl_mio_eur"], color=BLAU, alpha=0.25, lw=0)
    ax2.plot(df["stichtag"], df["npl_mio_eur"], color=BLAU, lw=2, label="NPL-Volumen (Mio. €, links)")
    ax2.set_ylabel("NPL-Volumen, Mio. €")
    ax2.annotate(f"{letzter['npl_mio_eur']:.2f} Mio. €".replace(".", ","), (letzter["stichtag"], letzter["npl_mio_eur"]),
                 xytext=(0, -14), textcoords="offset points", ha="right", va="center", color=TEXT, fontsize=9)
    ax3 = ax2.twinx()
    ax3.plot(df["stichtag"], df["bestand_mio_eur"], color=TEXT2, lw=1.4, ls="--", label="Bestand (Mio. €, rechts)")
    ax3.set_ylabel("Bestand, Mio. €")
    ax3.grid(False)
    ax3.spines["right"].set_visible(True)
    linien = ax2.get_legend_handles_labels()[0] + ax3.get_legend_handles_labels()[0]
    ax2.legend(linien, [l.get_label() for l in linien], frameon=False, loc="upper left")
    ax2.set_title("NPL-Volumen steigt weiter, der Bestand wächst schneller (Nennereffekt)")
    ax2.set_xlim(df["stichtag"].min(), df["stichtag"].max() + pd.Timedelta(days=150))
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
    ax.text(0.99, 0.03, "Synthetische Daten: Der Generator erhöht die PD für Auszahlungen 07/2022–12/2023 um den Faktor 1,25",
            transform=ax.transAxes, ha="right", va="bottom", fontsize=8, color=TEXT2)
    speichern(fig, "02_vintage_kurven")


def pd_nach_rating() -> None:
    df = lies("07_expected_loss__pd_nach_ratingklasse")
    klassen = np.arange(1, 11)
    k = df[df["produktgruppe"] == "Konsumentenkredit"].set_index("ratingklasse").reindex(klassen)
    i = df[df["produktgruppe"] == "Immobilienkredit"].set_index("ratingklasse").reindex(klassen)
    fig, ax = plt.subplots(figsize=(9, 4))
    b = 0.38
    # Balken = beobachtete (rohe) PD, ungeglättet; Raute = PD nach Floor, falls der Floor greift
    ax.bar(klassen - b / 2 - 0.01, k["pd_12m_roh_prozent"], width=b, color=BLAU, label="Konsumentenkredite")
    ax.bar(klassen + b / 2 + 0.01, i["pd_12m_roh_prozent"], width=b, color=AQUA, label="Baufinanzierung")
    for x, v in zip(klassen, k["pd_12m_roh_prozent"]):
        if x >= 7:
            ax.annotate(f"{v:.1f} %".replace(".", ","), (x - b / 2, v), xytext=(0, 3),
                        textcoords="offset points", ha="center", fontsize=8.5, color=TEXT)
    gefloort = i[i["floor_greift"] == "ja"]
    ax.scatter(gefloort.index + b / 2 + 0.01, gefloort["pd_12m_prozent"], marker="D", s=22, color=ROT, zorder=3,
               label="PD nach Floor 0,05 % (Annahme)")
    ax.set_xticks(klassen)
    ax.set_xlabel("Ratingklasse (1 = beste Bonität)")
    ax.yaxis.set_major_locator(mtick.MultipleLocator(5))
    ax.yaxis.set_major_formatter(mtick.FuncFormatter(lambda v, _: f"{v:.0f} %"))
    ax.set_title("Beobachtete 12-Monats-Ausfallrate (PD) je Ratingklasse, ungeglättet")
    ax.legend(frameon=False, loc="upper left")
    ax.set_ylim(0, k["pd_12m_roh_prozent"].max() * 1.15)
    ax.text(0.34, 0.97, "Baufinanzierung ab Rating 8 nicht vergeben (Kreditrichtlinie)\n"
            "Konsum: Klasse 1 > Klasse 2 bei 3 vs. 2 Ausfällen = statistisches Rauschen",
            transform=ax.transAxes, ha="left", va="top", fontsize=8, color=TEXT2)
    speichern(fig, "03_pd_nach_rating")


def marge_nach_rating() -> None:
    df = lies("08_marge_nach_risikokosten__marge_nach_rating_konsumentenkredite")
    fig, ax = plt.subplots(figsize=(9, 4.2))
    b = 0.38
    basis, ohne = df["marge_nach_risikokosten_prozent"], df["marge_ohne_stressfenster_prozent"]
    ax.bar(df["ratingklasse"] - b / 2 - 0.01, basis, width=b,
           color=[ROT if v < 0 else BLAU for v in basis], label="Pricing-PD alle Kohorten")
    ax.bar(df["ratingklasse"] + b / 2 + 0.01, ohne, width=b, color=[ROT if v < 0 else AQUA for v in ohne],
           alpha=0.75, label="Pricing-PD ohne Stressfenster 07/2022–12/2023")
    ax.axhline(0, color=TEXT2, lw=1)
    for x, v in zip(df["ratingklasse"], basis):
        ax.annotate(f"{v:+.2f}".replace(".", ","), (x - b / 2, v), xytext=(0, 3 if v >= 0 else -12),
                    textcoords="offset points", ha="center", fontsize=8, color=TEXT)
    ax.set_xticks(df["ratingklasse"])
    ax.set_xlabel("Ratingklasse")
    ax.set_ylabel("Prozentpunkte p. a.")
    ax.set_title("Marge nach Risikokosten Konsumentenkredite (Neugeschäft ab 2024)")
    ax.set_ylim(min(basis.min(), ohne.min()) - 1.2, max(basis.max(), ohne.max()) + 1.6)
    ax.legend(frameon=False, loc="upper right", fontsize=8.5)
    ax.text(0.01, 0.97, "Zins − Refinanzierung 3 % (Annahme) − PD × LGD\nohne Betriebs- und Eigenkapitalkosten · rot = negativ",
            transform=ax.transAxes, ha="left", va="top", fontsize=8, color=TEXT2)
    speichern(fig, "04_marge_nach_risikokosten")


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
