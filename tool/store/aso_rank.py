"""Posición de Ley al Blanco en la búsqueda de la App Store (España).

    python3 tool/store/aso_rank.py [--note TEXTO]

Consulta la API pública de búsqueda de Apple (sin clave ni datos del usuario),
https://itunes.apple.com/search?country=es&entity=software&limit=25&term=...,
para cada término de TERMS, busca la app por su id y añade una fila por término
a docs/tienda/aso-posiciones.csv (fecha ISO, término, posición 1-25 o vacía si
no sale entre las 25 primeras, nota). Plan de medida: sección 6 de
docs/tienda/aso-appstore-2026-11.md.
"""

import argparse
import csv
import datetime as dt
import json
from pathlib import Path
import urllib.parse
import urllib.request

APP_ID = 6831621176
TERMS = (
    "licencia de armas",
    "test armas",
    "permiso de armas",
    "licencia armas D",
    "examen armas",
)
URL = "https://itunes.apple.com/search?country=es&entity=software&limit=25&term="
OUT = Path(__file__).resolve().parents[2] / "docs/tienda/aso-posiciones.csv"


def position(term: str) -> int | None:
    request = urllib.request.Request(
        URL + urllib.parse.quote(term), headers={"User-Agent": "aso-rank/1.0"}
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        results = json.load(response)["results"]
    for index, app in enumerate(results, start=1):
        if app.get("trackId") == APP_ID:
            return index
    return None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--note", default="")
    args = parser.parse_args()
    today = dt.date.today().isoformat()
    rows = [(today, term, position(term), args.note) for term in TERMS]
    new = not OUT.exists()
    with OUT.open("a", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        if new:
            writer.writerow(["fecha", "termino", "posicion", "nota"])
        for date, term, pos, note in rows:
            writer.writerow([date, term, "" if pos is None else pos, note])
    for _, term, pos, _ in rows:
        print(f"{term:20} {pos if pos else '-'}")


if __name__ == "__main__":
    main()
