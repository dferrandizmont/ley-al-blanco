"""Genera web/legal/dist/ con los marcadores sustituidos.

Uso:
  python -I web/legal/rellenar.py --titular "Nombre Apellidos" \
      --correo "soporte@ejemplo.com" --fecha 2026-11-01 \
      [--plazo-correos "un año desde la última respuesta"]

Falla (código 1) si queda algún marcador [..] sin sustituir en dist/.
"""
import argparse
import html
import re
import shutil
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parent
DIST = BASE / "dist"
FICHEROS = ["index.html", "privacidad/index.html", "styles.css", "robots.txt"]
MARCADORES = ["[TITULAR]", "[CORREO_SOPORTE]", "[FECHA]", "[PLAZO_CORREOS]"]
RE_MARCADOR = re.compile(r"\[(?:TITULAR|CORREO_SOPORTE|FECHA|PLAZO_[A-Z_]+)\]")


def generar(valores: dict[str, str], destino: Path = DIST, origen: Path = BASE) -> list[str]:
    """Copia origen -> destino sustituyendo. Devuelve los marcadores que quedan."""
    vacios = [m for m in MARCADORES if not valores.get(m, "").strip()]
    if vacios:
        return vacios
    if destino.exists():
        shutil.rmtree(destino)
    restantes: list[str] = []
    for rel in FICHEROS:
        txt = (origen / rel).read_text(encoding="utf-8")
        for marcador, valor in valores.items():
            txt = txt.replace(marcador, html.escape(valor.strip(), quote=True))
        restantes += RE_MARCADOR.findall(txt)
        salida = destino / rel
        salida.parent.mkdir(parents=True, exist_ok=True)
        salida.write_text(txt, encoding="utf-8", newline="\n")
    return sorted(set(restantes))


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--titular")
    p.add_argument("--correo")
    p.add_argument("--fecha", help="ISO 8601, p. ej. 2026-11-01")
    p.add_argument("--plazo-correos", default="un año desde la última respuesta")
    a = p.parse_args()
    if a.fecha and not re.fullmatch(r"\d{4}-\d{2}-\d{2}", a.fecha):
        print("ERROR: --fecha debe ser ISO 8601 (AAAA-MM-DD).", file=sys.stderr)
        return 1
    valores = {
        "[TITULAR]": a.titular or "",
        "[CORREO_SOPORTE]": a.correo or "",
        "[FECHA]": a.fecha or "",
        "[PLAZO_CORREOS]": a.plazo_correos or "",
    }
    quedan = generar(valores)
    if quedan:
        print("ERROR: faltan valores / quedan marcadores sin rellenar: " + ", ".join(quedan), file=sys.stderr)
        if DIST.exists() and not any(m in quedan for m in MARCADORES if not valores[m].strip()):
            shutil.rmtree(DIST)
        return 1
    print(f"Listo: {DIST}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
