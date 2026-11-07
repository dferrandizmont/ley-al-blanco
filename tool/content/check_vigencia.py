#!/usr/bin/env python3
"""Comprueba que las fuentes de Ley al Blanco siguen vigentes y publica un
informe en markdown.

Vigila, sin modificar nada:

1. Los 14 PDF oficiales de la Guardia Civil (delega en `check_sources.py`).
2. La lista de enlaces de la pagina del programa de la prueba teorica: los
   `.pdf` y las normas del BOE que cita. Se compara la lista, no el HTML (el
   CMS la regenera a menudo).
3. Las 15 normas del BOE de `tool/content/boe/LEEME.md`: `fecha_actualizacion`
   de `/metadatos` y sha256 de `/texto` frente a `fuentes/boe/raw/`.
4. Los listados de consulta publica previa y audiencia e informacion publica
   de Interior: titulos de iniciativa que mencionan «armas».
5. La web publica (`/` y `/privacy/`): deben responder 200.
6. El dominio `mainshai.com` (RDAP de Verisign): caducidad a menos de 60 dias.

Solo lee. Los fallos de red de una comprobacion no impiden las demas.

Uso (desde la raiz del repositorio):

    python tool/content/check_vigencia.py
    python tool/content/check_vigencia.py --only gc,boe --out vigencia.md
    python tool/content/check_vigencia.py --update-baseline

Codigo de salida: 0 todo igual; 1 hay alguna diferencia; 2 solo errores
(red, 403, parseo). Si hay diferencias y errores, 1. `--update-baseline`
siempre sale 0.
"""
from __future__ import annotations

import argparse
import contextlib
import hashlib
import html as html_lib
import io
import json
import re
import shutil
import subprocess
import sys
import tempfile
import unicodedata
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urljoin
from zoneinfo import ZoneInfo

REPO = Path(__file__).resolve().parents[2]
BASELINE_PATH = Path(__file__).resolve().parent / "vigencia_baseline.json"
GC_LEEME = REPO / "fuentes" / "guardia-civil" / "LEEME.md"
GC_SRC = REPO / "fuentes" / "guardia-civil"
BOE_LEEME = REPO / "tool" / "content" / "boe" / "LEEME.md"
BOE_RAW = REPO / "fuentes" / "boe" / "raw"

GC_PROGRAMA_URL = (
    "https://web.guardiacivil.es/es/tramites/autorizaciones-de-armas-y-explosivos/"
    "controldearmas/pruebas_licenciasarmas/"
    "Programa_prueba_teorica_D__E_y_AEM/index.html"
)
INTERIOR_URLS = {
    "consulta": (
        "https://www.interior.gob.es/opencms/es/servicios-al-ciudadano/"
        "participacion-ciudadana/participacion-publica-en-proyectos-normativos/"
        "consulta-publica-previa/"
    ),
    "audiencia": (
        "https://www.interior.gob.es/opencms/es/servicios-al-ciudadano/"
        "participacion-ciudadana/participacion-publica-en-proyectos-normativos/"
        "audiencia-e-informacion-publica/"
    ),
}
WEB_URLS = (
    "https://leyalblanco.mainshai.com/",
    "https://leyalblanco.mainshai.com/privacy/",
)
RDAP_URL = "https://rdap.verisign.com/com/v1/domain/MAINSHAI.COM"
BOE_API = "https://www.boe.es/datosabiertos/api/legislacion-consolidada/id/{id}/{kind}"

TIMEOUT_SECONDS = 60
USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
BOE_ID_RE = re.compile(r"BOE-A-\d{4}-\d+")
HREF_RE = re.compile(r"""href\s*=\s*["']([^"']+)["']""", re.IGNORECASE)
CHECK_NAMES = ("gc", "programa", "boe", "interior", "web", "dominio")
CHECK_TITLES = {
    "gc": "PDF de la Guardia Civil",
    "programa": "Pagina del programa",
    "boe": "Normas del BOE",
    "interior": "Interior (participacion publica)",
    "web": "Web publica",
    "dominio": "Dominio mainshai.com",
}
QUARTERLY_MONTHS = (1, 4, 7, 10)


@dataclass
class CheckResult:
    name: str
    differences: list[str] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)

    @property
    def status(self) -> str:
        if self.differences:
            return "CAMBIO"
        if self.errors:
            return "ERROR"
        return "OK"


# ---------------------------------------------------------------------------
# Descargas (todo con timeout y User-Agent de navegador)


def fetch_bytes(url: str, accept: str | None = None) -> tuple[int, bytes]:
    headers = {"User-Agent": USER_AGENT}
    if accept:
        headers["Accept"] = accept
    request = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as error:
        # Cloudflare (Interior) bloquea la huella TLS de urllib con un 403, pero
        # deja pasar a curl con el mismo User-Agent: se reintenta con curl.
        curl = shutil.which("curl")
        if error.code != 403 or curl is None:
            raise
        return _fetch_with_curl(curl, url, headers)


def _fetch_with_curl(curl: str, url: str, headers: dict[str, str]) -> tuple[int, bytes]:
    marker = b"\n__HTTP_STATUS__:"
    command = [curl, "-sS", "-L", "--max-time", str(TIMEOUT_SECONDS), "-w", "\n__HTTP_STATUS__:%{http_code}"]
    for key, value in headers.items():
        command += ["-H", f"{key}: {value}"]
    command.append(url)
    completed = subprocess.run(command, capture_output=True, timeout=TIMEOUT_SECONDS + 10, check=False)
    body, _, status = completed.stdout.rpartition(marker)
    if completed.returncode != 0 or not status.strip().isdigit():
        raise urllib.error.URLError(f"curl fallo ({completed.returncode}): {completed.stderr.decode(errors='replace').strip()}")
    code = int(status.strip())
    if code >= 400:
        raise urllib.error.HTTPError(url, code, f"HTTP {code} (curl)", None, None)
    return code, body


def fetch_text(url: str) -> str:
    _status, body = fetch_bytes(url)
    return body.decode("utf-8", errors="replace")


# ---------------------------------------------------------------------------
# Funciones puras


def _fold(text: str) -> str:
    """Minusculas y sin acentos, para comparar «Armas» con «armas»."""
    decomposed = unicodedata.normalize("NFKD", text.lower())
    return "".join(char for char in decomposed if not unicodedata.combining(char))


def extract_programa_links(html_text: str, base_url: str = GC_PROGRAMA_URL) -> dict[str, list[str]]:
    """Lista ordenada y sin duplicados de PDF y enlaces al BOE de la pagina."""
    pdfs: list[str] = []
    boe: list[str] = []
    for raw in HREF_RE.findall(html_text):
        href = html_lib.unescape(raw).strip().split("#", 1)[0]
        if not href:
            continue
        if href.lower().endswith(".pdf"):
            pdfs.append(urljoin(base_url, href))
        if "boe.es" in href.lower():
            boe.append(urljoin(base_url, href))
    return {"pdfs": sorted(set(pdfs)), "boe": sorted(set(boe))}


def extract_interior_fragments(html_text: str) -> list[str]:
    """Titulos de iniciativa que mencionan «armas» (sin acentos ni mayusculas).

    Se queda con el texto directo de cada `<li>` (antes de una lista anidada) y
    solo acepta los que empiezan por «Audiencia...» o «Consulta publica
    previa...», que es como titula Interior sus iniciativas. Asi no entra la
    «Nota aclaratoria» ni el menu de navegacion.
    """
    without_scripts = re.sub(
        r"(?is)<(script|style|noscript)\b.*?</\1>", " ", html_text
    )
    without_scripts = re.sub(r"(?s)<!--.*?-->", " ", without_scripts)
    fragments: list[str] = []
    for segment in re.split(r"(?is)<li\b[^>]*>", without_scripts)[1:]:
        title = re.split(r"(?i)<(?:ul|ol)\b", segment, maxsplit=1)[0]
        title = re.sub(r"<[^>]+>", " ", title)
        title = re.sub(r"\s+", " ", html_lib.unescape(title)).strip()
        folded = _fold(title)
        if "armas" not in folded:
            continue
        if folded.startswith("audiencia") or folded.startswith("consulta publica previa"):
            fragments.append(title)
    return sorted(set(fragments))


def parse_boe_ids(leeme_text: str) -> list[str]:
    """IDs de la columna «ID BOE» de la tabla de `tool/content/boe/LEEME.md`."""
    header_index: int | None = None
    ids: list[str] = []
    for line in leeme_text.splitlines():
        line = line.strip()
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if header_index is None:
            for index, cell in enumerate(cells):
                if "ID BOE" in cell:
                    header_index = index
                    break
            continue
        if header_index >= len(cells):
            continue
        match = BOE_ID_RE.search(cells[header_index])
        if match and match.group(0) not in ids:
            ids.append(match.group(0))
    return ids


def days_to_expiry(expiry: datetime, now: datetime | None = None) -> int:
    """Dias completos que faltan para `expiry` (negativos si ya paso)."""
    reference = now or datetime.now(timezone.utc)
    if expiry.tzinfo is None:
        expiry = expiry.replace(tzinfo=timezone.utc)
    if reference.tzinfo is None:
        reference = reference.replace(tzinfo=timezone.utc)
    return (expiry - reference).days


def diff_sets(label: str, actual: list[str] | set[str], expected: list[str] | set[str]) -> list[str]:
    """Diferencias entre lo publicado hoy y lo guardado en la baseline."""
    actual_set = set(actual)
    expected_set = set(expected)
    differences = [f"{label}: nuevo: {item}" for item in sorted(actual_set - expected_set)]
    differences += [f"{label}: ya no aparece: {item}" for item in sorted(expected_set - actual_set)]
    return differences


def exit_code(differences: int, errors: int) -> int:
    if differences:
        return 1
    if errors:
        return 2
    return 0


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


# ---------------------------------------------------------------------------
# Comprobaciones


def check_gc() -> CheckResult:
    """PDF oficiales: reutiliza `check_sources.parse_leeme` y `check_online`."""
    result = CheckResult("gc")
    try:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import check_sources as cs  # noqa: PLC0415
    except Exception as error:  # pragma: no cover - depende del arbol
        result.errors.append(f"no se puede importar check_sources: {error}")
        return result

    try:
        sources = cs.parse_leeme(GC_LEEME.read_text(encoding="utf-8"))
    except OSError as error:
        result.errors.append(f"no se puede leer {GC_LEEME}: {error}")
        return result
    if not sources:
        result.errors.append(f"{GC_LEEME} no tiene tabla de ficheros")
        return result

    tmp = Path(tempfile.mkdtemp(prefix="check_vigencia_"))
    try:
        with contextlib.redirect_stdout(io.StringIO()):
            problems = cs.check_online(sources, GC_SRC, tmp)
    except Exception as error:  # pragma: no cover - defensa
        problems = [f"fallo inesperado al comprobar los PDF: {error}"]
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    result.differences.extend(problems)
    if not problems:
        result.notes.append(f"{len(sources)} PDF identicos a los del LEEME")
    return result


def check_programa(baseline: dict) -> CheckResult:
    result = CheckResult("programa")
    try:
        html_text = fetch_text(GC_PROGRAMA_URL)
    except (urllib.error.URLError, OSError, ValueError) as error:
        result.errors.append(f"no se pudo descargar la pagina ({error})")
        return result

    actual = extract_programa_links(html_text)
    expected = baseline.get("gc_programa") or {}
    result.differences.extend(diff_sets("PDF", actual["pdfs"], expected.get("pdfs", [])))
    result.differences.extend(diff_sets("BOE", actual["boe"], expected.get("boe", [])))
    if not result.differences:
        result.notes.append(
            f"{len(actual['pdfs'])} PDF y {len(actual['boe'])} enlaces al BOE, iguales a la baseline"
        )
    return result


def _fecha_actualizacion(data: bytes) -> str | None:
    root = ET.fromstring(data)
    return root.findtext(".//fecha_actualizacion")


def check_boe(ids: list[str] | None = None, raw_dir: Path = BOE_RAW) -> CheckResult:
    result = CheckResult("boe")
    if ids is None:
        try:
            ids = parse_boe_ids(BOE_LEEME.read_text(encoding="utf-8"))
        except OSError as error:
            result.errors.append(f"no se puede leer {BOE_LEEME}: {error}")
            return result
    if not ids:
        result.errors.append("el LEEME del BOE no tiene IDs")
        return result

    checked = 0
    for norm_id in ids:
        meta_url = BOE_API.format(id=norm_id, kind="metadatos")
        texto_url = BOE_API.format(id=norm_id, kind="texto")
        local_meta = raw_dir / f"{norm_id}.metadatos.xml"
        local_texto = raw_dir / f"{norm_id}.texto.xml"

        try:
            _status, meta_bytes = fetch_bytes(meta_url, accept="application/xml")
            published_fecha = _fecha_actualizacion(meta_bytes)
        except (urllib.error.URLError, OSError, ValueError, ET.ParseError) as error:
            result.errors.append(f"{norm_id}: no se pudieron leer los metadatos ({error})")
        else:
            if not local_meta.is_file():
                result.differences.append(f"{norm_id}: falta {local_meta.name}")
            else:
                try:
                    local_fecha = _fecha_actualizacion(local_meta.read_bytes())
                except (OSError, ET.ParseError) as error:
                    result.errors.append(f"{norm_id}: no se puede leer {local_meta.name} ({error})")
                else:
                    if published_fecha != local_fecha:
                        result.differences.append(
                            f"{norm_id}: fecha_actualizacion publicada {published_fecha}, "
                            f"local {local_fecha}"
                        )

        try:
            _status, texto_bytes = fetch_bytes(texto_url, accept="application/xml")
        except (urllib.error.URLError, OSError, ValueError) as error:
            result.errors.append(f"{norm_id}: no se pudo descargar el texto ({error})")
        else:
            if not local_texto.is_file():
                result.differences.append(f"{norm_id}: falta {local_texto.name}")
            else:
                try:
                    local_hash = _sha256(local_texto.read_bytes())
                except OSError as error:
                    result.errors.append(f"{norm_id}: no se puede leer {local_texto.name} ({error})")
                else:
                    if _sha256(texto_bytes) != local_hash:
                        result.differences.append(f"{norm_id}: el texto consolidado ha cambiado (sha256)")
        checked += 1

    if checked:
        result.notes.append(f"{checked} normas comprobadas")
    return result


def check_interior(baseline: dict) -> CheckResult:
    result = CheckResult("interior")
    stored = baseline.get("interior") or {}
    for key, url in INTERIOR_URLS.items():
        label = "consulta previa" if key == "consulta" else "audiencia e informacion publica"
        try:
            html_text = fetch_text(url)
        except (urllib.error.URLError, OSError, ValueError) as error:
            result.errors.append(f"{label}: no se pudo descargar ({error})")
            continue
        actual = extract_interior_fragments(html_text)
        expected = stored.get(key, [])
        for item in sorted(set(actual) - set(expected)):
            result.differences.append(f"{label}: nueva iniciativa: {item}")
        for gone in sorted(set(expected) - set(actual)):
            result.notes.append(f"{label}: ya no aparece: {gone}")
        result.notes.append(f"{label}: {len(actual)} iniciativas sobre armas")
    return result


def check_web() -> CheckResult:
    result = CheckResult("web")
    for url in WEB_URLS:
        try:
            status, _body = fetch_bytes(url)
        except urllib.error.HTTPError as error:
            result.differences.append(f"{url}: HTTP {error.code}")
        except (urllib.error.URLError, OSError, ValueError) as error:
            result.errors.append(f"{url}: no se pudo consultar ({error})")
        else:
            if status != 200:
                result.differences.append(f"{url}: HTTP {status}")
            else:
                result.notes.append(f"{url}: 200")
    return result


def check_dominio(now: datetime | None = None) -> CheckResult:
    result = CheckResult("dominio")
    try:
        _status, body = fetch_bytes(RDAP_URL)
        data = json.loads(body)
    except (urllib.error.URLError, OSError, ValueError) as error:
        result.errors.append(f"no se pudo consultar el RDAP ({error})")
        return result

    expiration = next(
        (event.get("eventDate") for event in data.get("events", []) if event.get("eventAction") == "expiration"),
        None,
    )
    if not expiration:
        result.errors.append("el RDAP no informa de la fecha de caducidad")
        return result
    try:
        expiry = datetime.fromisoformat(expiration.replace("Z", "+00:00"))
    except ValueError as error:
        result.errors.append(f"fecha de caducidad no valida ({expiration}): {error}")
        return result

    days = days_to_expiry(expiry, now)
    result.notes.append(f"caduca el {expiry.date().isoformat()} (faltan {days} dias)")
    if days < 60:
        result.differences.append(
            f"el dominio caduca en {days} dias (el {expiry.date().isoformat()}); renovar ya"
        )
    return result


# ---------------------------------------------------------------------------
# Baseline


def empty_baseline() -> dict:
    return {"gc_programa": {"pdfs": [], "boe": []}, "interior": {"consulta": [], "audiencia": []}}


def load_baseline(path: Path = BASELINE_PATH) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return empty_baseline()
    if not isinstance(data, dict):
        raise ValueError(f"{path} no contiene un objeto JSON")
    baseline = empty_baseline()
    programa = data.get("gc_programa") or {}
    baseline["gc_programa"]["pdfs"] = list(programa.get("pdfs") or [])
    baseline["gc_programa"]["boe"] = list(programa.get("boe") or [])
    interior = data.get("interior") or {}
    for key in ("consulta", "audiencia"):
        baseline["interior"][key] = list(interior.get(key) or [])
    return baseline


def update_baseline(baseline: dict, path: Path = BASELINE_PATH) -> dict:
    """Actualiza programa e interior con lo leido ahora; conserva lo que falle."""
    updated = {
        "gc_programa": {
            "pdfs": list(baseline["gc_programa"]["pdfs"]),
            "boe": list(baseline["gc_programa"]["boe"]),
        },
        "interior": {
            "consulta": list(baseline["interior"]["consulta"]),
            "audiencia": list(baseline["interior"]["audiencia"]),
        },
    }

    try:
        html_text = fetch_text(GC_PROGRAMA_URL)
    except (urllib.error.URLError, OSError, ValueError) as error:
        print(f"aviso: no se pudo leer la pagina del programa ({error}); se conserva la baseline", file=sys.stderr)
    else:
        updated["gc_programa"] = extract_programa_links(html_text)

    for key, url in INTERIOR_URLS.items():
        try:
            html_text = fetch_text(url)
        except (urllib.error.URLError, OSError, ValueError) as error:
            print(f"aviso: no se pudo leer Interior/{key} ({error}); se conserva la baseline", file=sys.stderr)
            continue
        updated["interior"][key] = extract_interior_fragments(html_text)

    for section in updated.values():
        for value in section.values():
            value.sort()
    path.write_text(
        json.dumps(updated, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return updated


# ---------------------------------------------------------------------------
# Informe


def _cell(text: str) -> str:
    return text.replace("|", "\\|")


def _summary(result: CheckResult) -> str:
    if result.differences:
        return f"{len(result.differences)} diferencia(s)"
    if result.errors:
        return f"{len(result.errors)} error(es)"
    return "sin cambios"


def render_report(results: list[CheckResult], generated_at: datetime, checklist: bool) -> str:
    lines = [
        f"# Vigencia de fuentes — {generated_at.isoformat(timespec='seconds')}",
        "",
        "| Comprobacion | Estado | Resumen |",
        "|---|---|---|",
    ]
    for result in results:
        lines.append(
            f"| {_cell(CHECK_TITLES.get(result.name, result.name))} "
            f"| {result.status} | {_cell(_summary(result))} |"
        )
    lines += ["", "## Detalle", ""]
    for result in results:
        lines.append(f"### {CHECK_TITLES.get(result.name, result.name)} — {result.status}")
        if not (result.differences or result.errors or result.notes):
            lines.append("- Sin cambios.")
        for item in result.differences:
            lines.append(f"- CAMBIO: {item}")
        for item in result.errors:
            lines.append(f"- ERROR: {item}")
        for item in result.notes:
            lines.append(f"- {item}")
        lines.append("")

    if checklist:
        lines += [
            "## Revision manual trimestral",
            "",
            "- [ ] Dependencias: `cd app && flutter pub outdated`; subir parches y menores en una rama y pasar `flutter analyze && flutter test`.",
            "- [ ] Google Play: revisar «Estado de la politica», el nivel de API exigido y la Seguridad de los datos en Play Console.",
            "- [ ] App Store: revisar los requisitos proximos de Apple, las etiquetas de privacidad y el manifiesto de privacidad.",
            "- [ ] Correo: enviar un correo de prueba real a leyalblanco@mainshai.com.",
            "- [ ] Enero: confirmar en el registrador la renovacion de mainshai.com y revisar el DNS.",
            "",
        ]
    return "\n".join(lines)


def run_checks(names: list[str], baseline: dict) -> list[CheckResult]:
    results: list[CheckResult] = []
    for name in names:
        try:
            if name == "gc":
                result = check_gc()
            elif name == "programa":
                result = check_programa(baseline)
            elif name == "boe":
                result = check_boe()
            elif name == "interior":
                result = check_interior(baseline)
            elif name == "web":
                result = check_web()
            else:
                result = check_dominio()
        except Exception as error:  # una comprobacion no debe tumbar las demas
            result = CheckResult(name, errors=[f"fallo inesperado: {error}"])
        results.append(result)
    return results


def parse_only(value: str) -> list[str]:
    requested = [item.strip().lower() for item in value.split(",") if item.strip()]
    unknown = [item for item in requested if item not in CHECK_NAMES]
    if unknown:
        raise argparse.ArgumentTypeError(f"comprobacion desconocida: {', '.join(unknown)}")
    return [name for name in CHECK_NAMES if name in requested]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Comprueba la vigencia de las fuentes de Ley al Blanco y genera un informe."
    )
    parser.add_argument(
        "--only",
        type=parse_only,
        default=list(CHECK_NAMES),
        help="subconjunto separado por comas: gc,programa,boe,interior,web,dominio",
    )
    parser.add_argument(
        "--update-baseline",
        action="store_true",
        help="reescribe vigencia_baseline.json con la pagina del programa y los listados de Interior",
    )
    parser.add_argument("--out", type=Path, help="escribe tambien el informe en este fichero")
    parser.add_argument(
        "--checklist",
        action="store_true",
        help="anade la revision manual trimestral (tambien en enero, abril, julio y octubre)",
    )
    args = parser.parse_args(argv)

    try:
        baseline = load_baseline()
    except (OSError, ValueError) as error:
        print(f"{BASELINE_PATH}: baseline no valida ({error})", file=sys.stderr)
        return 2

    if args.update_baseline:
        updated = update_baseline(baseline)
        total = sum(len(values) for section in updated.values() for values in section.values())
        print(f"Baseline actualizada: {BASELINE_PATH} ({total} entradas).")
        return 0

    generated_at = datetime.now(ZoneInfo("Europe/Madrid"))
    results = run_checks(args.only, baseline)
    differences = sum(len(result.differences) for result in results)
    errors = sum(len(result.errors) for result in results)
    checklist = args.checklist or generated_at.month in QUARTERLY_MONTHS
    report = render_report(results, generated_at, checklist)

    print(report)
    if args.out:
        args.out.write_text(report, encoding="utf-8")
    return exit_code(differences, errors)


if __name__ == "__main__":
    sys.exit(main())
