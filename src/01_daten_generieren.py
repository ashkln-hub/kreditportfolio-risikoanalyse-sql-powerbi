"""
Schritt 1 – Synthetische Daten für ein Retail-Kreditportfolio erzeugen.

Fiktive Bank: "Musterbank Niedersachsen" (keine realen Kundendaten).
Ergebnis: vier CSV-Dateien in data/raw/

    kunden.csv            – Kundenstammdaten
    kredite.csv           – Kreditverträge bei Auszahlung
    performance_monat.csv – Monatliche Zahlungs- und Risikohistorie je Kredit
    verwertung.csv        – Ausgefallene Kredite und Verwertungserlöse

Alle Annahmen stehen in der Konfiguration unten und im README.
Der Zufallsgenerator hat einen festen Seed → die Daten sind reproduzierbar.
"""

from pathlib import Path

import numpy as np
import pandas as pd

# ---------------------------------------------------------------------------
# Konfiguration (Annahmen)
# ---------------------------------------------------------------------------
SEED = 42
ANZAHL_KREDITE = 20_000
ERSTE_AUSZAHLUNG = "2021-01-01"
LETZTE_AUSZAHLUNG = "2026-08-01"
BEOBACHTUNGSENDE = "2026-09-30"  # letzter Monatsultimo der Historie

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "data" / "raw"

PRODUKTE = {
    # Anteil, Laufzeiten (Monate), Median-Betrag, Streuung (log), Basis-PD-Faktor,
    # vorzeitige Rückzahlung p.M., Verwertungsdauer (Monate), mittlere LGD
    "Ratenkredit":     dict(anteil=0.55, laufzeiten=[24, 36, 48, 60, 72, 84], median=12_000,
                            sigma=0.60, min=2_000, max=60_000, pd_faktor=1.30,
                            prepay=0.009, workout=18, lgd=0.65),
    "Autokredit":      dict(anteil=0.30, laufzeiten=[24, 36, 48, 60, 72], median=26_000,
                            sigma=0.50, min=6_000, max=120_000, pd_faktor=1.00,
                            prepay=0.008, workout=6, lgd=0.40),
    "Baufinanzierung": dict(anteil=0.15, laufzeiten=[120], median=290_000,
                            sigma=0.40, min=80_000, max=900_000, pd_faktor=0.45,
                            prepay=0.002, workout=24, lgd=0.15),
}

# Jährliche Ausfallwahrscheinlichkeit (PD) je Ratingklasse 1 (beste) … 10 (schlechteste)
PD_JAHR = np.array([0.10, 0.20, 0.35, 0.60, 1.00, 1.60, 2.60, 4.20, 7.00, 12.0]) / 100

REGIONEN = {  # Anteil, Risikofaktor
    "Region Hannover": (0.30, 1.00),
    "Braunschweig":    (0.15, 0.95),
    "Göttingen":       (0.10, 1.05),
    "Oldenburg":       (0.15, 0.90),
    "Osnabrück":       (0.15, 0.90),
    "Lüneburg":        (0.15, 1.00),
}

BESCHAEFTIGUNG = {  # Anteil, Median-Nettoeinkommen, Risikofaktor
    "Angestellt":  (0.68, 2_900, 1.00),
    "Beamtet":     (0.10, 3_400, 0.50),
    "Selbständig": (0.10, 3_600, 1.35),
    "Rentner":     (0.12, 2_100, 0.90),
}


def zinsumfeld(produkt: str, datum: pd.Timestamp) -> float:
    """Basiszins je Produkt nach Auszahlungsdatum (vereinfachter Verlauf der
    Zinswende 2022/23 und leichter Rückgang ab 2024)."""
    t = (datum.year - 2021) * 12 + datum.month - 1  # Monate seit 01/2021
    if t < 15:            # bis 03/2022: Niedrigzins
        anstieg = 0.0
    elif t < 33:          # 04/2022 – 09/2023: Zinswende
        anstieg = (t - 15) / 18
    elif t < 42:          # 10/2023 – 06/2024: Plateau
        anstieg = 1.0
    else:                 # ab 07/2024: leichter Rückgang
        anstieg = max(0.75, 1.0 - (t - 42) / 72)
    basis, hub = {"Ratenkredit": (3.4, 3.6), "Autokredit": (2.8, 3.0),
                  "Baufinanzierung": (1.1, 2.9)}[produkt]
    return basis + hub * anstieg


def neugeschaeft_gewicht(produkt: str, datum: pd.Timestamp) -> float:
    """Relatives Neugeschäftsvolumen je Monat (Baufinanzierung bricht 2023 ein)."""
    t = (datum.year - 2021) * 12 + datum.month - 1
    w = 1.0 + 0.006 * t
    if produkt == "Baufinanzierung":
        if 18 <= t < 36:
            w *= 0.55
        elif t >= 36:
            w *= 0.80
    return w


def annuitaet(betrag, zins_pa, monate):
    r = zins_pa / 100 / 12
    return betrag * r / (1 - (1 + r) ** -monate)


def saisonalitaet(mob: int) -> float:
    """Seasoning: Ausfälle konzentrieren sich auf die Monate 6–30 nach Auszahlung."""
    if mob < 3:
        return 0.3
    if mob < 6:
        return 0.8
    if mob <= 30:
        return 1.3
    return 0.8


def main() -> None:
    rng = np.random.default_rng(SEED)
    OUT.mkdir(parents=True, exist_ok=True)
    beob_ende = pd.Timestamp(BEOBACHTUNGSENDE)

    # --- Auszahlungsmonate und Produkte -------------------------------------
    monate = pd.date_range(ERSTE_AUSZAHLUNG, LETZTE_AUSZAHLUNG, freq="MS")
    paare = [(p, m) for p in PRODUKTE for m in monate]
    gewichte = np.array([PRODUKTE[p]["anteil"] * neugeschaeft_gewicht(p, m) for p, m in paare])
    gewichte /= gewichte.sum()
    auswahl = rng.choice(len(paare), size=ANZAHL_KREDITE, p=gewichte)

    regionen = list(REGIONEN)
    reg_p = np.array([REGIONEN[r][0] for r in regionen])
    besch = list(BESCHAEFTIGUNG)
    besch_p = np.array([BESCHAEFTIGUNG[b][0] for b in besch])

    kunden, kredite, perf, verwertung = [], [], [], []

    for i, idx in enumerate(auswahl):
        produkt, monat = paare[idx]
        cfg = PRODUKTE[produkt]
        auszahlung = monat + pd.Timedelta(days=int(rng.integers(0, 28)))

        # --- Kunde -----------------------------------------------------------
        b = besch[rng.choice(len(besch), p=besch_p)]
        region = regionen[rng.choice(len(regionen), p=reg_p)]
        alter = int(rng.integers(66, 80)) if b == "Rentner" else int(np.clip(rng.normal(41, 10), 21, 65))
        if produkt == "Baufinanzierung":
            alter = min(alter, 58) if b != "Rentner" else alter
        einkommen = BESCHAEFTIGUNG[b][1] * np.exp(rng.normal(0, 0.35))
        if produkt == "Baufinanzierung":
            einkommen *= 1.45  # Baufinanzierung: höhere Einkommen
        einkommen = round(float(einkommen), -1)

        # --- Kredit ----------------------------------------------------------
        betrag = float(np.clip(cfg["median"] * np.exp(rng.normal(0, cfg["sigma"])), cfg["min"], cfg["max"]))
        betrag = round(betrag, -2)
        laufzeit = int(rng.choice(cfg["laufzeiten"]))

        # Bonitätsscore → Ratingklasse (1 = beste, 10 = schlechteste)
        latent = rng.normal(0, 1) - 0.8 * np.log(einkommen / 2_900) + (0.6 if b == "Selbständig" else 0) \
            - (0.5 if b == "Beamtet" else 0)
        rating = int(np.clip(np.round(4.6 + 1.7 * latent), 1, 10))
        if produkt == "Baufinanzierung" and rating > 7:
            rating = int(rng.integers(4, 8))  # Kreditrichtlinie: keine Baufinanzierung ab Rating 8

        zins = zinsumfeld(produkt, auszahlung)
        zins += (0.30 if produkt != "Baufinanzierung" else 0.06) * (rating - 1)
        zins = round(float(zins + rng.normal(0, 0.15)), 2)

        if produkt == "Baufinanzierung":
            rate = betrag * (zins / 100 + 0.02) / 12  # 2 % anfängliche Tilgung
            ltv = round(float(np.clip(rng.normal(0.78, 0.12), 0.40, 1.05)), 2)
            sicherheit = "Grundschuld"
        else:
            rate = annuitaet(betrag, zins, laufzeit)
            ltv = None
            sicherheit = "Sicherungsübereignung Kfz" if produkt == "Autokredit" else "ohne"
        # Kreditrichtlinie: maximale Kapitaldienstquote (Rate / Nettoeinkommen).
        # Liegt die Rate darüber, wird nur ein entsprechend niedrigerer Betrag bewilligt.
        max_quote = 0.45 if produkt == "Baufinanzierung" else 0.35
        if rate > max_quote * einkommen:
            faktor = max_quote * einkommen / rate
            betrag = round(betrag * faktor, -2)
            rate *= faktor
        rate = round(float(rate), 2)
        dsti = round(rate / einkommen, 3)

        # Ausfallrisiko pro Monat
        pd_jahr = PD_JAHR[rating - 1] * cfg["pd_faktor"] * BESCHAEFTIGUNG[b][2] * REGIONEN[region][1]
        if dsti > 0.30:
            pd_jahr *= 1.5
        elif dsti > 0.20:
            pd_jahr *= 1.2
        if pd.Timestamp("2022-07-01") <= auszahlung < pd.Timestamp("2024-01-01"):
            pd_jahr *= 1.25  # Jahrgänge mit Inflations-/Energiepreisschock
        pd_jahr = min(pd_jahr, 0.5)
        h_monat = 1 - (1 - pd_jahr) ** (1 / 12)

        kunde_id = f"K{i + 1:06d}"
        kredit_id = f"KR{i + 1:06d}"
        kunden.append(dict(kunden_id=kunde_id, alter_bei_antrag=alter, beschaeftigung=b,
                           netto_einkommen_monat=einkommen, region=region))
        kredite.append(dict(kredit_id=kredit_id, kunden_id=kunde_id, produkt=produkt,
                            auszahlungsdatum=auszahlung.date().isoformat(), kreditbetrag=betrag,
                            laufzeit_monate=laufzeit, zinssatz_pa=zins, rate_monat=rate,
                            ratingklasse=rating, kapitaldienstquote=dsti, beleihungsauslauf=ltv,
                            sicherheit=sicherheit))

        # --- Monatliche Historie --------------------------------------------
        restschuld = betrag
        r = zins / 100 / 12
        stichtage = pd.date_range(auszahlung + pd.offsets.MonthEnd(1), beob_ende, freq="ME")
        rueckstand_bis = -1      # Monatsindex, bis zu dem ein Zahlungsrückstand läuft
        rueckstand_start = -1
        ausfall_monat = None
        ead = None
        endet_im_ausfall = False

        for mob, stichtag in enumerate(stichtage, start=1):
            if ausfall_monat is not None:
                # Kredit im Ausfall: bleibt bis Ende der Verwertung im Bestand
                if mob - ausfall_monat >= cfg["workout"]:
                    break
                perf.append((kredit_id, stichtag.date().isoformat(), mob, round(ead, 2),
                             90 + 30 * (mob - ausfall_monat), "Ausfall"))
                continue

            # Planmäßige Tilgung
            zinsanteil = restschuld * r
            tilgung = max(0.0, rate - zinsanteil)
            restschuld = max(0.0, restschuld - tilgung)

            # Ausfall-Ereignis: Rückstand baut sich über 3 Monate auf
            if rueckstand_bis < 0 and rng.random() < h_monat * saisonalitaet(mob):
                rueckstand_start, rueckstand_bis = mob, mob + 2
                endet_im_ausfall = True
            elif rueckstand_bis < 0 and rng.random() < h_monat * saisonalitaet(mob) * 3.0:
                # vorübergehender Rückstand, der geheilt wird (1–2 Monate)
                rueckstand_start, rueckstand_bis = mob, mob + int(rng.integers(0, 2))
                endet_im_ausfall = False

            if rueckstand_start <= mob <= rueckstand_bis and rueckstand_start > 0:
                dpd = 30 * (mob - rueckstand_start + 1)
                if dpd >= 90 and endet_im_ausfall:
                    ausfall_monat = mob
                    ead = restschuld + 3 * rate
                    perf.append((kredit_id, stichtag.date().isoformat(), mob, round(ead, 2), 90, "Ausfall"))
                    lgd = float(np.clip(rng.beta(4, 4 / cfg["lgd"] - 4), 0.0, 1.0))
                    if produkt == "Baufinanzierung":
                        lgd = float(np.clip(lgd + 0.6 * (ltv - 0.78), 0.0, 0.9))
                    abschluss = stichtag + pd.offsets.MonthEnd(cfg["workout"])
                    abgeschlossen = abschluss <= beob_ende
                    verwertung.append(dict(
                        kredit_id=kredit_id, ausfalldatum=stichtag.date().isoformat(),
                        ead=round(ead, 2),
                        verwertungserloes=round(ead * (1 - lgd), 2) if abgeschlossen else None,
                        abschlussdatum=abschluss.date().isoformat() if abgeschlossen else None,
                        status="abgeschlossen" if abgeschlossen else "laufend"))
                    continue
                perf.append((kredit_id, stichtag.date().isoformat(), mob, round(restschuld + dpd / 30 * rate, 2),
                             dpd, "Rückstand"))
                if mob == rueckstand_bis and not endet_im_ausfall:
                    rueckstand_start, rueckstand_bis = -1, -1
                continue

            # Reguläres Laufzeitende / vorzeitige Rückzahlung
            if produkt != "Baufinanzierung" and mob >= laufzeit:
                perf.append((kredit_id, stichtag.date().isoformat(), mob, 0.0, 0, "Getilgt"))
                break
            if rng.random() < cfg["prepay"]:
                perf.append((kredit_id, stichtag.date().isoformat(), mob, 0.0, 0, "Vorzeitig getilgt"))
                break
            perf.append((kredit_id, stichtag.date().isoformat(), mob, round(restschuld, 2), 0, "Laufend"))

    pd.DataFrame(kunden).to_csv(OUT / "kunden.csv", index=False)
    pd.DataFrame(kredite).to_csv(OUT / "kredite.csv", index=False)
    pd.DataFrame(perf, columns=["kredit_id", "stichtag", "monate_seit_auszahlung", "restschuld",
                                "tage_ueberfaellig", "status"]).to_csv(OUT / "performance_monat.csv", index=False)
    pd.DataFrame(verwertung).to_csv(OUT / "verwertung.csv", index=False)

    print(f"Kunden: {len(kunden):,} | Kredite: {len(kredite):,} | "
          f"Monatssätze: {len(perf):,} | Ausfälle: {len(verwertung):,}")


if __name__ == "__main__":
    main()
