#!/usr/bin/env python3
"""Comprueba que los PDF oficiales de `fuentes/guardia-civil/` siguen siendo
los publicados hoy por la Guardia Civil.

Lee la tabla de `fuentes/guardia-civil/LEEME.md` (fichero, URL, sha256 y,
opcionalmente, una cuarta columna con la cabecera `Last-Modified`), descarga
cada URL a una carpeta temporal, compara sha256 y `Last-Modified`, e imprime
un informe. No modifica `fuentes/` ni el banco: solo lee.

Uso (desde la raiz del repositorio):

    python tool/content/check_sources.py            # descarga y compara
    python tool/content/check_sources.py --offline  # solo ficheros locales vs LEEME

Codigo de salida: 0 todo coincide; 1 hay diferencias o errores de descarga;
2 el LEEME no se puede leer o no tiene tabla.
"""
from __future__ import annotations

import argparse
import hashlib
import re
import shutil
import sys
import tempfile
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
DEFAULT_SRC = REPO / "fuentes" / "guardia-civil"
SHA_RE = re.compile(r"^[0-9a-f]{64}$")
TIMEOUT_SECONDS = 60


@dataclass(frozen=True)
class Source:
    name: str
    url: str
    sha256: str
    last_modified: str | None = None


def _cell(value: str) -> str:
    return value.strip().strip("`").strip()


def parse_leeme(text: str) -> list[Source]:
    """Filas `| fichero | URL | sha256 [| Last-Modified] |` de la tabla."""
    sources: list[Source] = []
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("|"):
            continue
        cells = [_cell(c) for c in line.strip("|").split("|")]
        if len(cells) < 3 or not SHA_RE.match(cells[2].lower()):
            continue  # cabecera, separador u otra tabla
        last_modified = cells[3] if len(cells) > 3 and cells[3] else None
        sources.append(Source(cells[0], cells[1], cells[2].lower(), last_modified))
    return sources


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 16), b""):
            digest.update(chunk)
    return digest.hexdigest()


def check_offline(sources: list[Source], src_dir: Path) -> list[str]:
    problems: list[str] = []
    for s in sources:
        path = src_dir / s.name
        if not path.is_file():
            problems.append(f"{s.name}: falta el fichero local")
        elif (actual := sha256_file(path)) != s.sha256:
            problems.append(
                f"{s.name}: el fichero local no coincide con el LEEME "
                f"(LEEME {s.sha256[:12]}..., local {actual[:12]}...)"
            )
    return problems


def download(url: str, dest: Path) -> str | None:
    """Descarga `url` en `dest`; devuelve la cabecera Last-Modified (o None)."""
    request = urllib.request.Request(url, headers={"User-Agent": "apto-armas-check-sources/1"})
    with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
        dest.write_bytes(response.read())
        return response.headers.get("Last-Modified")


def check_online(sources: list[Source], src_dir: Path, tmp: Path) -> list[str]:
    problems: list[str] = []
    for s in sources:
        dest = tmp / s.name
        try:
            last_modified = download(s.url, dest)
        except (urllib.error.URLError, OSError, ValueError) as error:
            problems.append(f"{s.name}: no se pudo descargar {s.url} ({error})")
            continue
        actual = sha256_file(dest)
        local = src_dir / s.name
        local_note = ""
        if local.is_file() and sha256_file(local) != s.sha256:
            local_note = " (ademas, la copia local ya no coincide con el LEEME)"
        if actual != s.sha256:
            problems.append(
                f"{s.name}: CAMBIADO en la web. sha256 LEEME {s.sha256[:12]}..., "
                f"publicado hoy {actual[:12]}...; Last-Modified publicado: "
                f"{last_modified or 'no informado'}{local_note}"
            )
        elif s.last_modified and last_modified and s.last_modified != last_modified:
            problems.append(
                f"{s.name}: mismo sha256 pero Last-Modified distinto "
                f"(LEEME {s.last_modified}, publicado {last_modified})"
            )
        elif local_note:
            problems.append(f"{s.name}: igual que la web{local_note}")
        else:
            print(f"ok   {s.name}  Last-Modified: {last_modified or 'no informado'}")
    return problems


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--src", type=Path, default=DEFAULT_SRC, help="carpeta con los PDF y el LEEME.md")
    parser.add_argument("--leeme", type=Path, default=None, help="LEEME.md (por defecto <src>/LEEME.md)")
    parser.add_argument("--offline", action="store_true", help="no descarga: solo verifica los ficheros locales contra el LEEME")
    args = parser.parse_args(argv)

    leeme = args.leeme or args.src / "LEEME.md"
    try:
        sources = parse_leeme(leeme.read_text(encoding="utf-8"))
    except OSError as error:
        print(f"No se puede leer {leeme}: {error}", file=sys.stderr)
        return 2
    if not sources:
        print(f"{leeme} no tiene tabla de ficheros (nombre, URL, sha256).", file=sys.stderr)
        return 2

    if args.offline:
        problems = check_offline(sources, args.src)
    else:
        tmp = Path(tempfile.mkdtemp(prefix="check_sources_"))
        try:
            problems = check_online(sources, args.src, tmp)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    if problems:
        print(f"\nHAY DIFERENCIAS ({len(problems)} de {len(sources)}):")
        for problem in problems:
            print(f"  - {problem}")
        if not args.offline:
            print("\nNo se ha tocado nada. Revisar el cambio en la web antes de regenerar el banco.")
        return 1
    print(f"\nTodo coincide ({len(sources)} ficheros{', solo local' if args.offline else ''}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
