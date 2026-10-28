#!/usr/bin/env python3
"""Extraccion y validacion del cuestionario oficial de la Guardia Civil
(prueba teorica licencias D, E y AEM) para la app "Ley al Blanco".

Pipeline HIBRIDO:
  * TEXTO: `pdftotext -layout -enc UTF-8` (xpdf/poppler) sobre `temaN.pdf`.
    Es el unico extractor que decodifica bien acentos y comillas de estos PDF.
  * RESPUESTA CORRECTA: PyMuPDF sobre `temaNr.pdf`, donde la opcion correcta
    esta en NEGRITA. PyMuPDF solo se usa para estructura (numero de pregunta,
    letra de opcion) y para saber que spans son negrita; su texto no ASCII
    nunca se usa.
  * Ambos analizadores se alinean por (numero de pregunta, letra de opcion) y
    se comprueba que ven las mismas preguntas y 3 opciones cada una.

REGLA LEGAL: el texto se conserva VERBATIM. Solo se unen lineas partidas con un
espacio, se colapsan espacios y se recorta. No se corrige nada del contenido.

Uso:
  python tool/content/extract_questions.py --src fuentes/guardia-civil \
      --edition GC-2020-11 --retrieved 2026-10-18 \
      --out app/assets/content/armas/GC-2020-11 \
      --report tool/content/reports/GC-2020-11 \
      [--explanations tool/content/explanations/GC-2020-11]       [--cifras tool/content/cifras/GC-2020-11.json]

Las explicaciones y avisos propios (capa nuestra, nunca el texto oficial) se fusionan
por `id` desde `tool/content/explanations/<edicion>/t{1..7}.json` (ver README).

El flag `cifras` (preguntas de cifras, plazos, edades, cantidades, calibres e importes) se calcula
con una heuristica determinista y las correcciones manuales de `tool/content/cifras/<edicion>.json`
(ver `cifras_flag.py`); solo anade el flag, nunca toca el texto oficial.

Codigo de salida: 0 si no hay ERROR de validacion; 1 si hay alguno; 2 si falta
una dependencia o fichero de entrada.
"""
from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import re
import shutil
import subprocess
import sys
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable, Optional

import cifras_flag

# --------------------------------------------------------------------------
# Constantes
# --------------------------------------------------------------------------

SOURCE_URL = (
    "https://web.guardiacivil.es/es/tramites/autorizaciones-de-armas-y-explosivos/"
    "controldearmas/pruebas_licenciasarmas/Programa_prueba_teorica_D__E_y_AEM/index.html"
)
PDF_BASE_URL = (
    "https://web.guardiacivil.es/export/sites/guardiaCivil/documentos/iarmas/temarios/"
)
TEMAS = (1, 2, 3, 4, 5, 6, 7)
LETTERS = ("A", "B", "C")

# Recuentos esperados por edicion (de la propia web / inspeccion manual).
EXPECTED_COUNTS: dict[str, dict[int, int]] = {
    "GC-2020-11": {1: 68, 2: 67, 3: 66, 4: 70, 5: 66, 6: 64, 7: 22},
}

GENERATED_BY = "tool/content/extract_questions.py"

# Pregunta: empieza en col 0 (hasta 2 espacios de sangria) con "N." o "N. texto".
Q_RE = re.compile(r"^(\d{1,3})\.(?:\s+(.*))?$")
# Opcion: A).-Texto | A).- Texto | A.- Texto | A) Texto | A). Texto | A-Texto
OPT_RE = re.compile(r"^([ABC])\s*(?:\)\s*\.?\s*-?|\.\s*-?|-)\s*(.*)$")

# Una linea con sangria >= esto no es "col 0" (cabecera/titulo/pregunta).
MAX_COL0_INDENT = 2
# Opciones y continuaciones reales van sangradas ~7 espacios; mas de esto son
# titulos centrados que se ignoran.
MAX_CONT_INDENT = 19
MIN_CONT_INDENT = 3

FORM_FEED = "\x0c"

# Erratas tipográficas del PDF oficial que se corrigen a propósito (decisión del
# dueño, 28-oct-2026; excepción documentada en CLAUDE.md). En t5-052 la DGGC
# escribe el euro con la fuente Symbol, que no tiene ese glifo: el PDF dibuja «_»
# (comprobado renderizando tema5.pdf, pág. 7). Las cantidades son la conversión
# exacta de pesetas a euros (300,51 / 30.050,61 / 601.012,10) y el mismo PDF las
# escribe con «euros» en otra pregunta. Solo se tocan los ids listados.
TYPOGRAPHIC_ERRATA: dict[str, tuple[tuple[str, str], ...]] = {
    "t5-052": ((" _.", " €."),),
}
TYPO_ERRATA_FLAG = "errata_tipografica"


def apply_typographic_errata(qid_: str, options: list[str]) -> tuple[list[str], bool]:
    """Devuelve las opciones corregidas y si se aplicó alguna errata."""
    fixes = TYPOGRAPHIC_ERRATA.get(qid_)
    if not fixes:
        return options, False
    out = []
    for option in options:
        new = option
        for old, repl in fixes:
            if new.endswith(old):
                new = new[: -len(old)] + repl
        out.append(new)
    return out, out != options


# --------------------------------------------------------------------------
# Utilidades de texto
# --------------------------------------------------------------------------


def collapse_ws(text: str) -> str:
    """Colapsa runs de espacios (incluye NBSP) a un unico espacio y recorta."""
    return re.sub(r"\s+", " ", text).strip()


def normalize_for_compare(text: str) -> str:
    """minusculas, sin acentos, sin puntuacion ni espacios (solo alfanumerico)."""
    decomposed = unicodedata.normalize("NFKD", text.lower())
    stripped = "".join(c for c in decomposed if not unicodedata.combining(c))
    return re.sub(r"[\W_]+", "", stripped)


def ascii_alnum_count(text: str) -> int:
    return sum(1 for c in text if c.isascii() and c.isalnum())


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def pdf_date_to_iso(raw: Optional[str]) -> Optional[str]:
    """'D:20201104110446+01'00'' -> '2020-11-04'."""
    if not raw:
        return None
    m = re.match(r"^D:(\d{4})(\d{2})(\d{2})", raw)
    return f"{m.group(1)}-{m.group(2)}-{m.group(3)}" if m else None


# --------------------------------------------------------------------------
# 1) Analisis del texto de pdftotext -layout
# --------------------------------------------------------------------------


@dataclass
class ParsedOption:
    letter: str
    text: str


@dataclass
class ParsedQuestion:
    number: int
    stem: str
    options: list[str]
    section: Optional[str]
    page: int  # 1-based
    line: int  # 1-based, linea donde empieza la pregunta


@dataclass
class IgnoredLine:
    line: int
    page: int
    text: str
    reason: str
    adjacent: bool  # sin linea en blanco tras contenido de una pregunta


@dataclass
class ParseResult:
    questions: list[ParsedQuestion] = field(default_factory=list)
    ignored: list[IgnoredLine] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)


class _QBuilder:
    """Acumulador mutable de una pregunta mientras se analiza."""

    def __init__(self, number: int, section: Optional[str], page: int, line: int):
        self.number = number
        self.section = section
        self.page = page
        self.line = line
        self.stem_parts: list[str] = []
        self.opts: list[list[str]] = []  # cada opcion = lista de fragmentos

    def build(self) -> ParsedQuestion:
        return ParsedQuestion(
            number=self.number,
            stem=collapse_ws(" ".join(self.stem_parts)),
            options=[collapse_ws(" ".join(p)) for p in self.opts],
            section=self.section,
            page=self.page,
            line=self.line,
        )


def _indent_of(line: str) -> int:
    expanded = line.expandtabs(8)
    return len(expanded) - len(expanded.lstrip(" "))


def _has_lower(text: str) -> bool:
    return any(c.islower() for c in text)


def parse_layout_text(text: str) -> ParseResult:
    """Convierte la salida de `pdftotext -layout` de un tema en preguntas.

    Funcion pura (sin E/S). Reglas:
      - `\\f` separa paginas; se elimina y se cuenta la pagina.
      - Pregunta: linea con sangria <= 2 que casa `N.` / `N. texto`.
      - Cabecera de seccion: linea con sangria <= 2 que empieza por `-`; puede
        continuar en la(s) linea(s) siguiente(s) en col 0 sin linea en blanco.
      - Opciones: A/B/C secuenciales en lineas sangradas (3..19).
      - Lineas sangradas que no son opcion continúan el enunciado o la ultima
        opcion (union con un espacio). Titulos (centrados, en mayusculas, vinetas)
        se ignoran y se registran en `ignored`.
    """
    result = ParseResult()
    cur: Optional[_QBuilder] = None
    section: Optional[str] = None
    header_open = False  # la ultima linea consumida fue cabecera (o su continuacion)
    blank_pending = False  # ha habido linea en blanco desde el ultimo contenido
    q_last = False  # la ultima linea no vacia fue contenido de una pregunta
    page = 1

    def close_current() -> None:
        nonlocal cur
        if cur is not None:
            result.questions.append(cur.build())
            cur = None

    for lineno, raw in enumerate(text.split("\n"), start=1):
        if FORM_FEED in raw:
            page += raw.count(FORM_FEED)
            raw = raw.replace(FORM_FEED, "")
            q_last = False  # un salto de pagina rompe la adyacencia
        raw = raw.rstrip("\r")
        stripped = raw.strip()
        if not stripped:
            blank_pending = True
            header_open = False
            q_last = False
            continue

        # Numeros de pagina sueltos / pies
        if re.fullmatch(r"\d{1,3}", stripped) and _indent_of(raw) > MAX_COL0_INDENT:
            result.ignored.append(
                IgnoredLine(lineno, page, stripped, "numero_de_pagina", False)
            )
            continue
        if re.fullmatch(r"(?i)p[aá]gina\s+\d+(\s+de\s+\d+)?", stripped):
            result.ignored.append(
                IgnoredLine(lineno, page, stripped, "numero_de_pagina", False)
            )
            continue

        indent = _indent_of(raw)

        if indent <= MAX_COL0_INDENT:
            qm = Q_RE.match(stripped)
            if qm:
                close_current()
                header_open = False
                cur = _QBuilder(int(qm.group(1)), section, page, lineno)
                first = qm.group(2)
                if first:
                    cur.stem_parts.append(first)
                blank_pending = False
                q_last = True
                continue
            if stripped.startswith("-"):
                close_current()
                section = collapse_ws(stripped[1:])
                header_open = True
                blank_pending = False
                q_last = False
                continue
            # linea en col 0 que no es pregunta ni cabecera con guion
            if header_open and not blank_pending and section is not None and _has_lower(stripped):
                section = collapse_ws(section + " " + stripped)
                continue
            result.ignored.append(
                IgnoredLine(lineno, page, stripped, "col0_no_cabecera", q_last)
            )
            header_open = False
            blank_pending = False
            q_last = False
            continue

        if indent > MAX_CONT_INDENT or indent < MIN_CONT_INDENT:
            result.ignored.append(
                IgnoredLine(lineno, page, stripped, "sangria_fuera_de_rango", q_last)
            )
            blank_pending = False
            header_open = False
            q_last = False
            continue

        # Linea sangrada (3..19): opcion, continuacion o titulo
        header_open = False
        if cur is None:
            result.ignored.append(
                IgnoredLine(lineno, page, stripped, "fuera_de_pregunta", False)
            )
            blank_pending = False
            continue

        n_opts = len(cur.opts)
        if blank_pending and n_opts >= len(LETTERS):
            # Tras linea en blanco y con las 3 opciones completas: titulo suelto.
            result.ignored.append(
                IgnoredLine(lineno, page, stripped, "tras_blanco_con_opciones_completas", False)
            )
            blank_pending = False
            q_last = False
            continue
        if blank_pending:
            result.warnings.append(
                f"linea {lineno}: texto tras linea en blanco dentro de la pregunta "
                f"{cur.number} (opciones={n_opts}); se trata como continuacion: {stripped[:60]!r}"
            )
        blank_pending = False
        q_last = True

        om = OPT_RE.match(stripped)
        if om and n_opts < len(LETTERS) and om.group(1) == LETTERS[n_opts]:
            cur.opts.append([om.group(2)])
            continue
        if n_opts == 0:
            cur.stem_parts.append(stripped)
        else:
            cur.opts[-1].append(stripped)

    close_current()
    return result


# --------------------------------------------------------------------------
# 2) Deteccion de negrita (PyMuPDF) sobre temaNr.pdf / temaN.pdf
# --------------------------------------------------------------------------

# Una "linea" PyMuPDF: x0 (puntos) y spans (texto, es_negrita).
BoldLine = dict  # {"x0": float, "spans": [(str, bool), ...]}


@dataclass
class BoldOption:
    letter: str
    letter_bold: bool
    text_alnum: int  # alfanumericos ASCII del texto (sin prefijo)
    text_bold_alnum: int  # de ellos, en negrita
    ascii_alnum_total: int  # igual que text_alnum, para contraste con pdftotext

    @property
    def classification(self) -> str:
        """none | full | letter_only | text_only | partial"""
        n, nb = self.text_alnum, self.text_bold_alnum
        if not self.letter_bold and nb == 0:
            return "none"
        if self.letter_bold and nb == 0:
            return "letter_only"
        if not self.letter_bold and nb > 0:
            return "text_only" if nb == n else "partial"
        # letra en negrita y algo de texto en negrita
        return "full" if nb == n else "partial"

    @property
    def is_bold(self) -> bool:
        return self.classification != "none"

    @property
    def is_partial(self) -> bool:
        return self.classification in ("letter_only", "text_only", "partial")


@dataclass
class BoldQuestion:
    number: int
    options: list[BoldOption]

    def bold_indices(self) -> list[int]:
        return [i for i, o in enumerate(self.options) if o.is_bold]


class _BoldBuilder:
    def __init__(self, number: int, x0: float):
        self.number = number
        self.x0 = x0
        # cada opcion: dict(letter, letter_bold, chars=[(ch,bold)], x0)
        self.opts: list[dict] = []

    def build(self) -> BoldQuestion:
        out: list[BoldOption] = []
        for o in self.opts:
            n = sum(1 for ch, _ in o["chars"] if ch.isascii() and ch.isalnum())
            nb = sum(1 for ch, b in o["chars"] if b and ch.isascii() and ch.isalnum())
            out.append(BoldOption(o["letter"], o["letter_bold"], n, nb, n))
        return BoldQuestion(self.number, out)


def is_bold_font(font: str, flags: int) -> bool:
    return "bold" in (font or "").lower() or bool(flags & 16)


def parse_bold_lines(lines: Iterable[BoldLine]) -> list[BoldQuestion]:
    """Detecta preguntas/opciones y su negrita a partir de lineas PyMuPDF.

    Funcion pura: `lines` es una lista de dicts `{"x0": float, "spans": [(texto,
    negrita_bool), ...]}` en orden de lectura. Solo se usan caracteres ASCII
    alfanumericos (los demas se ignoran porque PyMuPDF los decodifica mal).

    Una linea es continuacion de la ultima opcion si no hay linea en blanco
    desde ella y su x0 no esta mas a la izquierda que la opcion; asi se
    descartan titulos y cabeceras (que van tras linea en blanco o en col 0).
    """
    questions: list[BoldQuestion] = []
    cur: Optional[_BoldBuilder] = None
    blank_since_option = False

    def close() -> None:
        nonlocal cur
        if cur is not None:
            questions.append(cur.build())
            cur = None

    for line in lines:
        chars: list[tuple[str, bool]] = []
        for text, bold in line["spans"]:
            chars.extend((ch, bool(bold)) for ch in text)
        full = "".join(ch for ch, _ in chars)
        stripped = full.strip()
        if not stripped:
            blank_since_option = True
            continue
        x0 = float(line["x0"])
        lead = len(full) - len(full.lstrip())
        opt_x0 = cur.opts[-1]["x0"] if cur is not None and cur.opts else None

        # Nueva pregunta: "N." en el margen de las preguntas (a la izquierda de las opciones)
        qm = Q_RE.match(stripped)
        if qm and (opt_x0 is None or x0 < opt_x0 - 1):
            close()
            cur = _BoldBuilder(int(qm.group(1)), x0)
            blank_since_option = False
            continue
        if cur is None:
            continue

        # Cabecera de seccion "-..." en el margen izquierdo: cierra la pregunta
        if stripped.startswith("-") and x0 < (opt_x0 - 1 if opt_x0 is not None else cur.x0 + 6):
            close()
            blank_since_option = False
            continue

        n_opts = len(cur.opts)
        om = OPT_RE.match(stripped)
        if om and n_opts < len(LETTERS) and om.group(1) == LETTERS[n_opts]:
            text_start = len(full.rstrip()) - len(om.group(2)) if om.group(2) else len(full)
            cur.opts.append(
                {
                    "letter": om.group(1),
                    "letter_bold": chars[lead][1],
                    "chars": chars[text_start:],
                    "x0": x0,
                }
            )
            blank_since_option = False
            continue
        if cur.opts and not blank_since_option and x0 >= cur.opts[-1]["x0"] - 1:
            cur.opts[-1]["chars"].extend(chars)
        # En otro caso: continuacion del enunciado, titulo o similar -> se ignora.

    close()
    return questions


def lines_from_pymupdf(path: Path) -> list[BoldLine]:
    """Extrae las lineas (x0 + spans con negrita) de un PDF con PyMuPDF."""
    import fitz  # type: ignore  # pymupdf

    lines: list[BoldLine] = []
    with fitz.open(str(path)) as doc:
        for page in doc:
            for block in page.get_text("dict")["blocks"]:
                for ln in block.get("lines", []):
                    spans = [
                        (s["text"], is_bold_font(s.get("font", ""), int(s.get("flags", 0))))
                        for s in ln["spans"]
                    ]
                    lines.append({"x0": ln["bbox"][0], "spans": spans})
    return lines


def pdf_creation_date(path: Path) -> Optional[str]:
    import fitz  # type: ignore

    with fitz.open(str(path)) as doc:
        return pdf_date_to_iso((doc.metadata or {}).get("creationDate"))


# --------------------------------------------------------------------------
# 3) pdftotext
# --------------------------------------------------------------------------


class MissingToolError(RuntimeError):
    pass


def find_pdftotext() -> str:
    exe = shutil.which("pdftotext")
    if not exe:
        raise MissingToolError(
            "No se encuentra 'pdftotext' en el PATH. Instala xpdf-tools o poppler "
            "(macOS: `brew install poppler`; Debian/Ubuntu: `apt install poppler-utils`; "
            "Windows: xpdf command line tools o poppler)."
        )
    return exe


def run_pdftotext(path: Path) -> str:
    exe = find_pdftotext()
    proc = subprocess.run(
        [exe, "-layout", "-enc", "UTF-8", str(path), "-"],
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(
            f"pdftotext fallo en {path} (codigo {proc.returncode}): "
            f"{proc.stderr.decode('utf-8', 'replace')}"
        )
    return proc.stdout.decode("utf-8")


# --------------------------------------------------------------------------
# 4) Modelo de validacion
# --------------------------------------------------------------------------


@dataclass
class Check:
    id: str
    title: str
    level: str  # OK | WARN | ERROR
    summary: str
    details: list[str] = field(default_factory=list)
    data: Any = None

    def as_dict(self) -> dict:
        d = {
            "id": self.id,
            "title": self.title,
            "level": self.level,
            "summary": self.summary,
            "details": self.details,
        }
        if self.data is not None:
            d["data"] = self.data
        return d


def _level(errors: bool, warns: bool = False) -> str:
    return "ERROR" if errors else ("WARN" if warns else "OK")


def qid(tema: int, number: int) -> str:
    return f"t{tema}-{number:03d}"


def word_diff(a: str, b: str) -> str:
    """Diff a nivel de palabra: [-solo en A-] {+solo en B+}."""
    wa, wb = a.split(), b.split()
    sm = difflib.SequenceMatcher(a=wa, b=wb, autojunk=False)
    out: list[str] = []
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == "equal":
            out.append(" ".join(wa[i1:i2]))
        else:
            if i2 > i1:
                out.append("[-" + " ".join(wa[i1:i2]) + "-]")
            if j2 > j1:
                out.append("{+" + " ".join(wb[j1:j2]) + "+}")
    return " ".join(out)


@dataclass
class TemaData:
    tema: int
    q_text: ParseResult  # temaN.pdf (pdftotext)
    r_text: ParseResult  # temaNr.pdf (pdftotext)
    q_bold: list[BoldQuestion]  # temaN.pdf (PyMuPDF)
    r_bold: list[BoldQuestion]  # temaNr.pdf (PyMuPDF)


def check_counts(tdata: list[TemaData], expected: Optional[dict[int, int]]) -> Check:
    errs: list[str] = []
    rows: list[dict] = []
    for t in tdata:
        srcs = {
            f"tema{t.tema}.pdf (texto)": [q.number for q in t.q_text.questions],
            f"tema{t.tema}r.pdf (texto)": [q.number for q in t.r_text.questions],
            f"tema{t.tema}.pdf (negrita)": [q.number for q in t.q_bold],
            f"tema{t.tema}r.pdf (negrita)": [q.number for q in t.r_bold],
        }
        exp = expected.get(t.tema) if expected else None
        for name, nums in srcs.items():
            count, hi = len(nums), (max(nums) if nums else 0)
            rows.append({"fuente": name, "analizadas": count, "numero_maximo": hi, "esperadas": exp})
            if exp is not None and (count != exp or hi != exp):
                errs.append(f"{name}: analizadas={count}, numero maximo={hi}, esperadas={exp}")
            elif exp is None and count != hi:
                errs.append(f"{name}: analizadas={count} != numero maximo={hi}")
        if len({tuple(v) for v in srcs.values()}) != 1:
            errs.append(f"tema {t.tema}: las cuatro fuentes no ven la misma secuencia de numeros")
    summary = (
        f"{sum(len(t.q_text.questions) for t in tdata)} preguntas en total"
        + ("" if expected else " (sin recuentos esperados para esta edicion)")
    )
    return Check("preguntas_por_tema", "Preguntas por tema (analizadas / maximo / esperadas)",
                 _level(bool(errs)), summary if not errs else f"{len(errs)} discrepancias",
                 errs, rows)


def check_numbering(tdata: list[TemaData]) -> Check:
    errs: list[str] = []
    for t in tdata:
        for name, nums in (
            ("texto temaN", [q.number for q in t.q_text.questions]),
            ("texto temaNr", [q.number for q in t.r_text.questions]),
            ("negrita temaNr", [q.number for q in t.r_bold]),
        ):
            expected_seq = list(range(1, len(nums) + 1))
            if nums != expected_seq:
                missing = sorted(set(range(1, (max(nums) if nums else 0) + 1)) - set(nums))
                dups = sorted({n for n in nums if nums.count(n) > 1})
                errs.append(
                    f"tema {t.tema} [{name}]: numeracion no continua 1..{len(nums)}; "
                    f"huecos={missing}; duplicados={dups}"
                )
    return Check("numeracion", "Numeracion continua 1..n sin huecos ni duplicados",
                 _level(bool(errs)), "OK" if not errs else f"{len(errs)} problemas", errs)


def check_options(tdata: list[TemaData]) -> Check:
    errs: list[str] = []
    for t in tdata:
        for label, qs in (("temaN", t.q_text.questions), ("temaNr", t.r_text.questions)):
            for q in qs:
                if len(q.options) != 3:
                    errs.append(f"{qid(t.tema, q.number)} [{label}]: {len(q.options)} opciones (se esperan 3)")
                elif any(not o for o in q.options):
                    errs.append(f"{qid(t.tema, q.number)} [{label}]: opcion vacia")
                if not q.stem:
                    errs.append(f"{qid(t.tema, q.number)} [{label}]: enunciado vacio")
        for q in t.r_bold:
            if len(q.options) != 3:
                errs.append(f"{qid(t.tema, q.number)} [negrita temaNr]: {len(q.options)} opciones (se esperan 3)")
    return Check("tres_opciones", "Exactamente 3 opciones no vacias por pregunta",
                 _level(bool(errs)), "OK" if not errs else f"{len(errs)} problemas", errs)


def check_single_bold(tdata: list[TemaData]) -> Check:
    errs: list[str] = []
    for t in tdata:
        for q in t.r_bold:
            n = len(q.bold_indices())
            if n != 1:
                errs.append(f"{qid(t.tema, q.number)}: {n} opciones en negrita (se espera 1)")
    return Check("una_negrita", "Exactamente 1 opcion correcta (negrita) por pregunta en temaNr",
                 _level(bool(errs)), "OK" if not errs else f"{len(errs)} preguntas", errs)


def check_no_bold_in_questions(tdata: list[TemaData]) -> Check:
    warns: list[str] = []
    for t in tdata:
        for q in t.q_bold:
            if q.bold_indices():
                warns.append(f"{qid(t.tema, q.number)}: tema{t.tema}.pdf tiene opcion(es) en negrita "
                             f"({[LETTERS[i] for i in q.bold_indices()]})")
    return Check("sin_negrita_en_preguntas", "El PDF de preguntas (temaN) no contiene opciones en negrita",
                 _level(False, bool(warns)), "OK" if not warns else f"{len(warns)} preguntas", warns)


def check_bold_alignment(tdata: list[TemaData]) -> Check:
    """Contrasta pdftotext y PyMuPDF sobre temaNr.pdf: mismas preguntas y misma
    extension (alfanumericos ASCII) de cada opcion."""
    errs: list[str] = []
    for t in tdata:
        tq = {q.number: q for q in t.r_text.questions}
        bq = {q.number: q for q in t.r_bold}
        if set(tq) != set(bq):
            errs.append(f"tema {t.tema}: numeros distintos entre texto y negrita: "
                        f"solo texto={sorted(set(tq) - set(bq))}, solo negrita={sorted(set(bq) - set(tq))}")
        for n in sorted(set(tq) & set(bq)):
            if len(tq[n].options) != len(bq[n].options):
                errs.append(f"{qid(t.tema, n)}: numero de opciones distinto (texto={len(tq[n].options)}, "
                            f"negrita={len(bq[n].options)})")
                continue
            for i, (txt, b) in enumerate(zip(tq[n].options, bq[n].options)):
                a = ascii_alnum_count(txt)
                if a != b.ascii_alnum_total:
                    errs.append(f"{qid(t.tema, n)} opcion {LETTERS[i]}: alfanumericos ASCII texto={a} "
                                f"vs negrita={b.ascii_alnum_total}")
    return Check("alineacion_texto_negrita",
                 "Alineacion pdftotext <-> PyMuPDF en temaNr (mismas preguntas y misma extension por opcion)",
                 _level(bool(errs)), "OK" if not errs else f"{len(errs)} desalineaciones", errs)


@dataclass
class Q:
    """Pregunta final ya alineada (para validacion e informe)."""
    tema: int
    number: int
    stem: str
    options: list[str]
    section: Optional[str]
    answer: Optional[int]
    flags: list[str]
    r_stem: Optional[str]
    r_options: Optional[list[str]]
    partial_class: Optional[str]

    @property
    def id(self) -> str:
        return qid(self.tema, self.number)


def build_questions(tdata: list[TemaData]) -> list[Q]:
    out: list[Q] = []
    for t in tdata:
        r_text = {q.number: q for q in t.r_text.questions}
        r_bold = {q.number: q for q in t.r_bold}
        for q in t.q_text.questions:
            rt = r_text.get(q.number)
            rb = r_bold.get(q.number)
            answer: Optional[int] = None
            partial: Optional[str] = None
            flags: list[str] = []
            if rt is not None and (rt.stem != q.stem or rt.options != q.options):
                flags.append("pdf_text_mismatch")
            if rb is not None:
                idx = rb.bold_indices()
                if len(idx) == 1:
                    answer = idx[0]
                    if rb.options[answer].is_partial:
                        flags.append("answer_partial_bold")
                        partial = rb.options[answer].classification
            options, fixed = apply_typographic_errata(qid(t.tema, q.number), list(q.options))
            r_options = list(rt.options) if rt else None
            if fixed:
                flags.append(TYPO_ERRATA_FLAG)
                if r_options is not None:
                    r_options, _ = apply_typographic_errata(qid(t.tema, q.number), r_options)
            out.append(Q(t.tema, q.number, q.stem, options, q.section, answer, flags,
                         rt.stem if rt else None, r_options, partial))
    return out


def check_duplicate_ids(questions: list[Q]) -> Check:
    seen: dict[str, int] = {}
    for q in questions:
        seen[q.id] = seen.get(q.id, 0) + 1
    dups = [f"{i} aparece {n} veces" for i, n in sorted(seen.items()) if n > 1]
    return Check("ids_duplicados", "Ids duplicados exactos", _level(bool(dups)),
                 "OK" if not dups else f"{len(dups)} ids duplicados", dups)


def duplicate_groups(questions: list[Q]) -> list[dict]:
    """Agrupa por enunciado normalizado; clasifica cada par."""
    groups: dict[str, list[Q]] = {}
    for q in questions:
        groups.setdefault(normalize_for_compare(q.stem), []).append(q)
    pairs: list[dict] = []
    for key in sorted(groups, key=lambda k: (groups[k][0].tema, groups[k][0].number)):
        g = groups[key]
        if len(g) < 2:
            continue
        for i in range(len(g)):
            for j in range(i + 1, len(g)):
                a, b = g[i], g[j]
                na = [normalize_for_compare(o) for o in a.options]
                nb = [normalize_for_compare(o) for o in b.options]
                same_opts = sorted(na) == sorted(nb)
                ans_a = na[a.answer] if a.answer is not None and a.answer < len(na) else None
                ans_b = nb[b.answer] if b.answer is not None and b.answer < len(nb) else None
                if same_opts and ans_a is not None and ans_a == ans_b:
                    kind = "duplicado_real"
                elif same_opts:
                    kind = "conflicto_respuesta"
                else:
                    kind = "conflicto_opciones"
                pairs.append({
                    "a": a.id, "b": b.id, "tipo": kind,
                    "mismo_orden_opciones": na == nb,
                    "stem": a.stem,
                })
    return pairs


def check_duplicate_stems(questions: list[Q]) -> Check:
    pairs = duplicate_groups(questions)
    labels = {
        "duplicado_real": "duplicado real (mismo enunciado, mismas opciones y misma respuesta)",
        "conflicto_respuesta": "IMPORTANTE conflicto: mismas opciones pero DISTINTA respuesta correcta",
        "conflicto_opciones": "mismo enunciado con opciones distintas (conflictivo/posible pregunta distinta)",
    }
    details = [f"{p['a']} <-> {p['b']}: {labels[p['tipo']]}" for p in pairs]
    counts = {k: sum(1 for p in pairs if p["tipo"] == k) for k in labels}
    summary = ("OK" if not pairs else
               f"{len(pairs)} pares ({counts['duplicado_real']} duplicados reales, "
               f"{counts['conflicto_respuesta']} conflicto de respuesta, "
               f"{counts['conflicto_opciones']} mismo enunciado con opciones distintas)")
    return Check("enunciados_duplicados",
                 "Enunciados duplicados tras normalizar (dentro y entre temas)",
                 _level(False, bool(pairs)), summary, details, pairs)


def text_discrepancies(questions: list[Q]) -> list[dict]:
    out: list[dict] = []
    for q in questions:
        if "pdf_text_mismatch" not in q.flags or q.r_stem is None or q.r_options is None:
            continue
        diffs: dict[str, str] = {}
        if q.stem != q.r_stem:
            diffs["enunciado"] = word_diff(q.stem, q.r_stem)
        for i in range(max(len(q.options), len(q.r_options))):
            a = q.options[i] if i < len(q.options) else ""
            b = q.r_options[i] if i < len(q.r_options) else ""
            if a != b:
                diffs[f"opcion {LETTERS[i] if i < 3 else i}"] = word_diff(a, b)
        out.append({"id": q.id, "diffs": diffs})
    return out


def check_discrepancies(questions: list[Q]) -> Check:
    items = text_discrepancies(questions)
    details = []
    for it in items:
        for part, d in it["diffs"].items():
            details.append(f"{it['id']} [{part}]: {d}")
    return Check("discrepancias_temaN_temaNr",
                 "Discrepancias de texto entre temaN y temaNr (diff por palabras: [-temaN-] {+temaNr+})",
                 _level(False, bool(items)),
                 "OK" if not items else f"{len(items)} preguntas con diferencias", details, items)


def check_answers_present(questions: list[Q]) -> Check:
    """Toda pregunta debe salir con una respuesta oficial valida (indice dentro de sus
    opciones). Una pregunta sin respuesta nunca se serializa como `answer: null`."""
    errs = [f"{q.id}: sin respuesta oficial (no se pudo determinar una unica opcion en negrita)"
            for q in questions if q.answer is None]
    errs += [f"{q.id}: respuesta {q.answer} fuera de rango ({len(q.options)} opciones)"
             for q in questions if q.answer is not None and not 0 <= q.answer < len(q.options)]
    return Check("respuesta_presente", "Toda pregunta tiene una respuesta oficial valida",
                 _level(bool(errs)), "OK" if not errs else f"{len(errs)} preguntas", errs)


def check_partial_bold(questions: list[Q]) -> Check:
    items = [{"id": q.id, "tipo": q.partial_class} for q in questions if q.partial_class]
    names = {"letter_only": "solo la letra en negrita", "text_only": "solo el texto en negrita",
             "partial": "negrita parcial dentro del texto"}
    details = [f"{i['id']}: {names.get(i['tipo'], i['tipo'])}" for i in items]
    return Check("negrita_parcial", "Respuestas con negrita parcial (letra sola, texto solo o parcial)",
                 _level(False, bool(items)), "OK" if not items else f"{len(items)} preguntas", details, items)


def check_answer_distribution(questions: list[Q], temas: list[int]) -> Check:
    rows = []
    for tema in temas:
        qs = [q for q in questions if q.tema == tema]
        c = {L: sum(1 for q in qs if q.answer == i) for i, L in enumerate(LETTERS)}
        none = sum(1 for q in qs if q.answer is None)
        rows.append({"tema": tema, "total": len(qs), **c, "sin_respuesta": none})
    tot = {"tema": "total", "total": sum(r["total"] for r in rows),
           **{L: sum(r[L] for r in rows) for L in LETTERS},
           "sin_respuesta": sum(r["sin_respuesta"] for r in rows)}
    rows.append(tot)
    return Check("distribucion_respuestas", "Distribucion de respuestas correctas por tema (A/B/C)",
                 "OK", "tabla informativa", [], rows)


def check_characters(tdata: list[TemaData], questions: list[Q]) -> Check:
    errs: list[str] = []
    counts: dict[str, int] = {}
    for q in questions:
        for part in [q.stem] + q.options + ([q.section] if q.section else []):
            for ch in part:
                if ord(ch) > 127:
                    counts[ch] = counts.get(ch, 0) + 1
                if ch == "\ufffd" or (ord(ch) < 32) or ch == "\x7f":
                    errs.append(f"{q.id}: caracter no valido U+{ord(ch):04X}")
    rows = [{"caracter": ch, "codepoint": f"U+{ord(ch):04X}", "nombre": unicodedata.name(ch, "?"), "apariciones": n}
            for ch, n in sorted(counts.items(), key=lambda kv: ord(kv[0]))]
    return Check("caracteres", "Caracteres no ASCII presentes y caracteres invalidos (U+FFFD, control)",
                 _level(bool(errs)), "OK" if not errs else f"{len(errs)} caracteres invalidos",
                 sorted(set(errs)), rows)


def check_odd_starts(questions: list[Q]) -> Check:
    """Enunciados/opciones que empiezan por un caracter raro (posible errata de origen
    o prefijo mal reconocido). Se informa, no se corrige."""
    allowed = set("¿¡(“\"'‘«")
    warns: list[str] = []
    for q in questions:
        for label, text in [("enunciado", q.stem)] + [(f"opcion {LETTERS[i]}", o) for i, o in enumerate(q.options)]:
            if text and not text[0].isalnum() and text[0] not in allowed:
                warns.append(f"{q.id} [{label}]: empieza por {text[0]!r}: {text[:60]!r}")
    return Check("inicios_raros", "Textos que empiezan por un caracter no alfanumerico (posibles erratas de origen)",
                 _level(False, bool(warns)), "OK" if not warns else f"{len(warns)} textos", warns)


def check_parse_notes(tdata: list[TemaData]) -> Check:
    warns: list[str] = []
    info: list[dict] = []
    for t in tdata:
        for label, pr in (("temaN", t.q_text), ("temaNr", t.r_text)):
            for w in pr.warnings:
                warns.append(f"tema{t.tema} [{label}] {w}")
            for ig in pr.ignored:
                info.append({"tema": t.tema, "doc": label, "linea": ig.line, "pagina": ig.page,
                             "motivo": ig.reason, "adyacente_a_pregunta": ig.adjacent, "texto": ig.text})
                if ig.adjacent:
                    warns.append(f"tema{t.tema} [{label}] linea {ig.line}: linea ignorada pegada a una pregunta "
                                 f"({ig.reason}): {ig.text[:70]!r}")
    return Check("lineas_ignoradas",
                 "Lineas ignoradas por el analizador (titulos, vinetas...) y avisos de formato",
                 _level(False, bool(warns)),
                 f"{len(info)} lineas ignoradas, {len(warns)} avisos", warns, info)


def check_dates(sources: list[dict]) -> Check:
    dates = {s["pdf_creation_date"] for s in sources} | {s["answers_pdf_creation_date"] for s in sources}
    dates.discard(None)
    warns: list[str] = []
    if len(dates) > 1:
        for s in sources:
            warns.append(f"tema {s['tema']}: {s['doc']} creado {s['pdf_creation_date']}; "
                         f"{s['answers_doc']} creado {s['answers_pdf_creation_date']}")
    return Check("fechas_pdf", "Fechas de creacion de los PDF (metadatos)",
                 _level(False, bool(warns)),
                 "todas iguales: " + ", ".join(sorted(dates)) if not warns
                 else "fechas distintas entre PDF: " + ", ".join(sorted(dates)), warns)


def check_sha(sources: list[dict]) -> Check:
    rows = []
    for s in sources:
        rows.append({"fichero": s["doc"], "sha256": s["sha256"]})
        rows.append({"fichero": s["answers_doc"], "sha256": s["answers_sha256"]})
    return Check("sha256", "SHA-256 de los 14 PDF", "OK", f"{len(rows)} ficheros", [], rows)


def run_validation(tdata: list[TemaData], questions: list[Q], sources: list[dict],
                   expected: Optional[dict[int, int]]) -> list[Check]:
    return [
        check_counts(tdata, expected),
        check_numbering(tdata),
        check_options(tdata),
        check_single_bold(tdata),
        check_no_bold_in_questions(tdata),
        check_bold_alignment(tdata),
        check_answers_present(questions),
        check_duplicate_ids(questions),
        check_duplicate_stems(questions),
        check_discrepancies(questions),
        check_partial_bold(questions),
        check_answer_distribution(questions, [t.tema for t in tdata]),
        check_characters(tdata, questions),
        check_odd_starts(questions),
        check_parse_notes(tdata),
        check_dates(sources),
        check_sha(sources),
    ]


# --------------------------------------------------------------------------
# 5) Salida: questions.json / manifest.json / informe
# --------------------------------------------------------------------------


def dumps(obj: Any) -> bytes:
    return (json.dumps(obj, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def question_to_dict(q: Q, edition: str, retrieved: str, src: dict) -> dict:
    return {
        "id": q.id,
        "tema": q.tema,
        "type": "mc3",
        "section": q.section,
        "stem": q.stem,
        "options": q.options,
        "answer": q.answer,
        "explanation": None,
        "article": None,
        "notice": None,
        "source": {
            "doc": src["doc"],
            "answers_doc": src["answers_doc"],
            "number": q.number,
            "retrieved": retrieved,
            "sha256": src["sha256"],
            "answers_sha256": src["answers_sha256"],
        },
        "flags": q.flags,
        "edition": edition,
        "reviewed": False,
    }


def build_manifest(edition: str, retrieved: str, questions: list[Q], questions_bytes: bytes,
                   sources: list[dict]) -> dict:
    per_tema: dict[str, int] = {}
    for q in questions:
        per_tema[str(q.tema)] = per_tema.get(str(q.tema), 0) + 1
    return {
        "edition": edition,
        "retrieved": retrieved,
        "source_url": SOURCE_URL,
        "generated_by": GENERATED_BY,
        "question_count": len(questions),
        "per_tema": per_tema,
        "questions_sha256": sha256_bytes(questions_bytes),
        "sources": [
            {
                "tema": s["tema"],
                "doc": s["doc"],
                "answers_doc": s["answers_doc"],
                "sha256": s["sha256"],
                "answers_sha256": s["answers_sha256"],
                "pdf_creation_date": s["pdf_creation_date"],
                "answers_pdf_creation_date": s["answers_pdf_creation_date"],
            }
            for s in sources
        ],
    }


def _md_cell(x: Any) -> str:
    return str(x).replace("|", "\\|").replace("\n", " ")


def _md_table(rows: list[dict]) -> list[str]:
    if not rows:
        return []
    cols = list(rows[0].keys())
    out = ["| " + " | ".join(cols) + " |", "|" + "|".join("---" for _ in cols) + "|"]
    for r in rows:
        out.append("| " + " | ".join(_md_cell(r.get(c, "")) for c in cols) + " |")
    return out


def render_markdown(edition: str, retrieved: str, checks: list[Check], n_questions: int,
                    per_tema: dict[str, int]) -> str:
    n_err = sum(1 for c in checks if c.level == "ERROR")
    n_warn = sum(1 for c in checks if c.level == "WARN")
    L: list[str] = [
        f"# Informe de validacion de contenido - {edition}",
        "",
        f"- Fuente: {SOURCE_URL}",
        f"- Descargado: {retrieved}",
        f"- Generado por: `{GENERATED_BY}`",
        f"- Preguntas extraidas: **{n_questions}** ("
        + ", ".join(f"T{k}: {v}" for k, v in per_tema.items()) + ")",
        f"- Resultado: **{n_err} comprobaciones con ERROR**, {n_warn} con AVISO (WARN)",
        "",
        "## Resumen",
        "",
        "| Comprobacion | Estado | Resumen |",
        "|---|---|---|",
    ]
    for c in checks:
        L.append(f"| {_md_cell(c.title)} | {c.level} | {_md_cell(c.summary)} |")
    L.append("")
    for c in checks:
        L.append(f"## [{c.level}] {c.title}")
        L.append("")
        L.append(c.summary)
        L.append("")
        if c.id in ("preguntas_por_tema", "distribucion_respuestas", "sha256", "caracteres") and c.data:
            L.extend(_md_table(c.data))
            L.append("")
        if c.id == "lineas_ignoradas":
            L.append(f"Lineas ignoradas en total: {len(c.data or [])} (titulos, vinetas, cabeceras sin guion). "
                     "Solo se listan abajo las pegadas a una pregunta y los avisos de formato; el detalle completo "
                     "esta en el JSON.")
            L.append("")
        if c.id == "enunciados_duplicados" and c.data:
            L.extend(_md_table([{"a": p["a"], "b": p["b"], "tipo": p["tipo"],
                                 "mismo_orden": p["mismo_orden_opciones"],
                                 "enunciado": p["stem"][:90]} for p in c.data]))
            L.append("")
        elif c.details and c.id not in ("sha256",):
            for d in c.details:
                L.append(f"- {d}")
            L.append("")
        if c.id == "sha256":
            L.extend(_md_table(c.data))
            L.append("")
        if c.id == "cifras" and c.data:
            L.extend(_md_table(c.data["por_tema"]))
            L.append("")
            L.append(f"Incluidas a mano (la heuristica no las marca): "
                     f"{', '.join(c.data['incluidas_a_mano']) or '(ninguna)'}")
            L.append("")
            L.append(f"Excluidas a mano (la heuristica las marcaba): "
                     f"{', '.join(c.data['excluidas_a_mano']) or '(ninguna)'}")
            L.append("")
        if c.id == "explicaciones" and c.data:
            L.append("### Cobertura por tema")
            L.append("")
            L.extend(_md_table(c.data["cobertura"]))
            L.append("")
            L.append("### Confianza")
            L.append("")
            L.extend(_md_table([{"confianza": k, "entradas": v} for k, v in c.data["confianza"].items()]))
            L.append("")
            L.append(f"### Avisos de reforma ({len(c.data['avisos'])})")
            L.append("")
            L.extend([f"- {a['id']} ({', '.join(a['flags'])}): {a['notice']}" for a in c.data["avisos"]]
                     or ["- (ninguno)"])
            L.append("")
            L.append(f"### Confianza baja ({len(c.data['confianza_baja'])})")
            L.append("")
            L.extend([f"- {b['id']}: {b['review_notes'] or '(sin notas)'}" for b in c.data["confianza_baja"]]
                     or ["- (ninguna)"])
            L.append("")
    return "\n".join(L).rstrip("\n") + "\n"


# --------------------------------------------------------------------------
# 5b) Explicaciones y avisos propios (capa nuestra; nunca toca el texto oficial)
# --------------------------------------------------------------------------

EXPLANATION_MAX_CHARS = 320
CONFIDENCE_LEVELS = ("alta", "media", "baja")
DISCREPANCY_PREFIX = "discrepancia_"
NO_ARTICLE_FLAG = "sin_articulo"
# Campos permitidos de una entrada. Los internos (`confidence`, `sources`,
# `review_notes`) sirven para la revision y NO se publican en questions.json.
ENTRY_FIELDS = (
    "id", "explanation", "article", "notice", "flags", "confidence", "sources",
    "reviewed", "review_notes",
)
ENTRY_REQUIRED = ("id", "explanation", "confidence")
ID_RE = re.compile(r"^t([1-7])-(\d{3})$")


def default_explanations_dir(edition: str) -> Path:
    """`tool/content/explanations/<edicion>` (junto a este script)."""
    return Path(__file__).resolve().parent / "explanations" / edition


def load_explanation_files(directory: Path) -> tuple[list[tuple[int, int, Any]], list[str]]:
    """Lee `t{1..7}.json`. Devuelve [(tema_del_fichero, posicion, entrada_cruda)] y los
    errores de lectura. Un fichero ausente cuenta como vacio."""
    raw: list[tuple[int, int, Any]] = []
    errors: list[str] = []
    for tema in TEMAS:
        path = directory / f"t{tema}.json"
        if not path.is_file():
            continue
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError) as e:
            errors.append(f"{path.name}: no se puede leer como JSON: {e}")
            continue
        if not isinstance(data, list):
            errors.append(f"{path.name}: debe ser un array JSON de entradas")
            continue
        raw.extend((tema, i, entry) for i, entry in enumerate(data))
    return raw, errors


def _validate_entry(label: str, tema_file: int, entry: Any,
                    known_ids: set[str]) -> tuple[Optional[dict], list[str]]:
    """Valida una entrada. Devuelve (entrada normalizada | None, errores)."""
    if not isinstance(entry, dict):
        return None, [f"{label}: la entrada debe ser un objeto JSON"]
    errs: list[str] = []
    entry_id = entry.get("id")
    where = f"{label} ({entry_id})" if isinstance(entry_id, str) else label
    for k in entry:
        if k not in ENTRY_FIELDS:
            errs.append(f"{where}: campo desconocido {k!r}")
    for k in ENTRY_REQUIRED:
        if k not in entry:
            errs.append(f"{where}: falta el campo obligatorio {k!r}")
    if "id" in entry and not isinstance(entry_id, str):
        errs.append(f"{where}: 'id' debe ser una cadena")
    elif isinstance(entry_id, str):
        if entry_id not in known_ids:
            errs.append(f"{where}: id desconocido (no existe esa pregunta en el banco)")
        else:
            m = ID_RE.match(entry_id)
            if m and int(m.group(1)) != tema_file:
                errs.append(f"{where}: el id es del tema {m.group(1)} pero esta en t{tema_file}.json")

    explanation = entry.get("explanation")
    if "explanation" in entry:
        if not isinstance(explanation, str):
            errs.append(f"{where}: 'explanation' debe ser una cadena")
        elif not explanation.strip():
            errs.append(f"{where}: explicacion vacia")
        elif len(explanation.strip()) > EXPLANATION_MAX_CHARS:
            errs.append(f"{where}: explicacion de {len(explanation.strip())} caracteres "
                        f"(maximo {EXPLANATION_MAX_CHARS})")

    article = entry.get("article")
    if article is not None and (not isinstance(article, str) or not article.strip()):
        errs.append(f"{where}: 'article' debe ser una cadena no vacia o null")
    notice = entry.get("notice")
    if notice is not None and (not isinstance(notice, str) or not notice.strip()):
        errs.append(f"{where}: 'notice' debe ser una cadena no vacia o null")

    flags = entry.get("flags", [])
    if not isinstance(flags, list) or not all(isinstance(f, str) and f for f in flags):
        errs.append(f"{where}: 'flags' debe ser un array de cadenas no vacias")
        flags = []
    has_discrepancy = any(f.startswith(DISCREPANCY_PREFIX) for f in flags)
    if notice is not None and not has_discrepancy:
        errs.append(f"{where}: 'notice' sin flag {DISCREPANCY_PREFIX}* (todo aviso lleva su flag)")
    if has_discrepancy and notice is None:
        errs.append(f"{where}: flag {DISCREPANCY_PREFIX}* sin 'notice' (toda discrepancia lleva su aviso)")

    confidence = entry.get("confidence")
    if "confidence" in entry and confidence not in CONFIDENCE_LEVELS:
        errs.append(f"{where}: 'confidence' debe ser una de {', '.join(CONFIDENCE_LEVELS)}")

    sources = entry.get("sources", [])
    if not isinstance(sources, list) or not all(
        isinstance(s, dict) and isinstance(s.get("norma"), str) and isinstance(s.get("ref"), str)
        and set(s) <= {"norma", "ref"} for s in sources
    ):
        errs.append(f"{where}: 'sources' debe ser un array de objetos {{norma, ref}} (cadenas)")

    reviewed = entry.get("reviewed", False)
    if not isinstance(reviewed, bool):
        errs.append(f"{where}: 'reviewed' debe ser booleano")
    elif reviewed and article is None and NO_ARTICLE_FLAG not in flags:
        errs.append(f"{where}: reviewed=true sin 'article' (solo se admite con el flag {NO_ARTICLE_FLAG})")
    if not isinstance(entry.get("review_notes", ""), str):
        errs.append(f"{where}: 'review_notes' debe ser una cadena")

    if errs:
        return None, errs
    return {
        "id": entry_id,
        "explanation": explanation.strip(),
        "article": article.strip() if article is not None else None,
        "notice": notice.strip() if notice is not None else None,
        "flags": list(dict.fromkeys(flags)),
        "confidence": confidence,
        "reviewed": reviewed,
        "review_notes": entry.get("review_notes", ""),
    }, []


def check_explanations(questions: list[Q], raw: list[tuple[int, int, Any]],
                       load_errors: list[str]) -> tuple[Check, dict[str, dict]]:
    """Valida las entradas y calcula el informe. Devuelve (Check, entradas validas por id).
    Si hay algun ERROR, el dict de entradas esta vacio (no se fusiona nada)."""
    known = {q.id for q in questions}
    errs: list[str] = list(load_errors)
    valid: dict[str, dict] = {}
    seen: dict[str, str] = {}
    for tema_file, idx, entry in raw:
        label = f"t{tema_file}.json[{idx}]"
        norm, e = _validate_entry(label, tema_file, entry, known)
        errs.extend(e)
        entry_id = entry.get("id") if isinstance(entry, dict) else None
        if isinstance(entry_id, str):
            if entry_id in seen:
                errs.append(f"{label} ({entry_id}): id duplicado (ya aparece en {seen[entry_id]})")
                norm = None
            else:
                seen[entry_id] = label
        if norm is not None:
            valid[norm["id"]] = norm

    by_tema: dict[int, list[str]] = {}
    for q in questions:
        by_tema.setdefault(q.tema, []).append(q.id)
    rows: list[dict] = []
    for tema in sorted(by_tema):
        ids = by_tema[tema]
        have = [valid[i] for i in ids if i in valid]
        rows.append({
            "tema": tema,
            "con_explicacion": len(have),
            "total": len(ids),
            "cobertura": f"{len(have)}/{len(ids)}",
            "revisadas": sum(1 for v in have if v["reviewed"]),
            "con_aviso": sum(1 for v in have if v["notice"]),
        })
    n_have = sum(r["con_explicacion"] for r in rows)
    n_total = sum(r["total"] for r in rows)
    rows.append({
        "tema": "total",
        "con_explicacion": n_have,
        "total": n_total,
        "cobertura": f"{n_have}/{n_total}",
        "revisadas": sum(r["revisadas"] for r in rows),
        "con_aviso": sum(r["con_aviso"] for r in rows),
    })
    ordered = [valid[q.id] for q in questions if q.id in valid]
    confidence = {c: sum(1 for v in ordered if v["confidence"] == c) for c in CONFIDENCE_LEVELS}
    notices = [
        {"id": v["id"], "notice": v["notice"],
         "flags": [f for f in v["flags"] if f.startswith(DISCREPANCY_PREFIX)]}
        for v in ordered if v["notice"]
    ]
    low = [{"id": v["id"], "review_notes": v["review_notes"]}
           for v in ordered if v["confidence"] == "baja"]
    data = {"cobertura": rows, "confianza": confidence, "avisos": notices, "confianza_baja": low}
    summary = (
        f"{n_have}/{n_total} preguntas con explicacion, {rows[-1]['revisadas']} revisadas, "
        f"{len(notices)} avisos, {len(low)} de confianza baja"
        if not errs else f"{len(errs)} problemas en las explicaciones"
    )
    check = Check("explicaciones", "Explicaciones", _level(bool(errs)), summary, errs, data)
    return check, ({} if errs else valid)


def merge_explanations(qlist: list[dict], entries: dict[str, dict]) -> None:
    """Fusiona por id (in situ) la capa propia en las preguntas ya serializadas. Solo se
    tocan `explanation`, `article`, `notice`, `flags` (se amplia sin duplicar y
    conservando los del extractor) y `reviewed`. Los campos internos no se publican."""
    for q in qlist:
        e = entries.get(q["id"])
        if e is None:
            continue
        q["explanation"] = {"es": e["explanation"]}
        q["article"] = e["article"]
        q["notice"] = {"es": e["notice"]} if e["notice"] else None
        q["flags"] = list(dict.fromkeys([*q["flags"], *e["flags"]]))
        q["reviewed"] = e["reviewed"]


# --------------------------------------------------------------------------
# 5c) Marca `cifras` (cifras y plazos; ver cifras_flag.py)
# --------------------------------------------------------------------------


def check_cifras(qlist: list[dict], path: Optional[Path]) -> tuple[Check, dict[str, bool]]:
    include, exclude, errs = cifras_flag.load_overrides(path)
    result, more, data = cifras_flag.compute_flags(qlist, include, exclude)
    errs = [*errs, *more]
    summary = (
        f"{data['total']} preguntas con el flag `cifras` ({data['heuristica']} por heuristica, "
        f"{len(data['incluidas_a_mano'])} incluidas y {len(data['excluidas_a_mano'])} excluidas a mano)"
        if not errs else f"{len(errs)} problemas en las correcciones de cifras"
    )
    check = Check("cifras", "Cifras y plazos", _level(bool(errs)), summary, errs, data)
    return check, ({} if errs else result)


# --------------------------------------------------------------------------
# 6) Orquestacion
# --------------------------------------------------------------------------


def process_tema(src_dir: Path, tema: int) -> tuple[TemaData, dict]:
    q_pdf = src_dir / f"tema{tema}.pdf"
    r_pdf = src_dir / f"tema{tema}r.pdf"
    for p in (q_pdf, r_pdf):
        if not p.is_file():
            raise FileNotFoundError(f"No existe {p}")
    tdata = TemaData(
        tema=tema,
        q_text=parse_layout_text(run_pdftotext(q_pdf)),
        r_text=parse_layout_text(run_pdftotext(r_pdf)),
        q_bold=parse_bold_lines(lines_from_pymupdf(q_pdf)),
        r_bold=parse_bold_lines(lines_from_pymupdf(r_pdf)),
    )
    src = {
        "tema": tema,
        "doc": f"tema{tema}_es.pdf",
        "answers_doc": f"tema{tema}r_es.pdf",
        "sha256": sha256_file(q_pdf),
        "answers_sha256": sha256_file(r_pdf),
        "pdf_creation_date": pdf_creation_date(q_pdf),
        "answers_pdf_creation_date": pdf_creation_date(r_pdf),
    }
    return tdata, src


def run(src_dir: Path, edition: str, retrieved: str, out_dir: Path, report_base: Path,
        explanations_dir: Optional[Path] = None, cifras_path: Optional[Path] = None) -> int:
    tdata: list[TemaData] = []
    sources: list[dict] = []
    for tema in TEMAS:
        td, src = process_tema(src_dir, tema)
        tdata.append(td)
        sources.append(src)

    questions = build_questions(tdata)
    src_by_tema = {s["tema"]: s for s in sources}
    expected = EXPECTED_COUNTS.get(edition)
    checks = run_validation(tdata, questions, sources, expected)
    expl_entries: dict[str, dict] = {}
    if explanations_dir is not None:
        raw_entries, load_errors = load_explanation_files(explanations_dir)
        expl_check, expl_entries = check_explanations(questions, raw_entries, load_errors)
        checks.append(expl_check)

    qlist = [question_to_dict(q, edition, retrieved, src_by_tema[q.tema]) for q in questions]
    cifras_check, cifras_result = check_cifras(qlist, cifras_path)
    checks.append(cifras_check)
    n_err = sum(1 for c in checks if c.level == "ERROR")
    merge_explanations(qlist, expl_entries)
    cifras_flag.apply_flags(qlist, cifras_result)
    q_bytes = dumps(qlist)
    manifest = build_manifest(edition, retrieved, questions, q_bytes, sources)

    # Los ficheros que consume la app (questions.json, manifest.json) solo se escriben si
    # no hay ningun ERROR: con errores se escribe unicamente el informe y se sale con 1,
    # dejando intactos los de una ejecucion anterior valida.
    if not n_err:
        out_dir.mkdir(parents=True, exist_ok=True)
        # Conserva el sha de teoria.json (lo genera build_teoria.py) si ya existe, para
        # que regenerar el banco no deje la teoria fuera del manifiesto.
        teoria = out_dir / "teoria.json"
        if teoria.exists():
            t_sha = hashlib.sha256(teoria.read_bytes()).hexdigest()
            with_teoria: dict = {}
            for key, value in manifest.items():
                with_teoria[key] = value
                if key == "questions_sha256":
                    with_teoria["teoria_sha256"] = t_sha
            manifest = with_teoria
            print("Teoria: si cambian los ids del banco, vuelve a ejecutar build_teoria.py "
                  "(valida related_questions contra questions.json).")
        (out_dir / "questions.json").write_bytes(q_bytes)
        (out_dir / "manifest.json").write_bytes(dumps(manifest))

    report_base.parent.mkdir(parents=True, exist_ok=True)
    md = render_markdown(edition, retrieved, checks, len(questions), manifest["per_tema"])
    Path(str(report_base) + ".md").write_bytes(md.encode("utf-8"))
    report_json = {
        "edition": edition,
        "retrieved": retrieved,
        "question_count": len(questions),
        "per_tema": manifest["per_tema"],
        "errors": n_err,
        "warnings": sum(1 for c in checks if c.level == "WARN"),
        "checks": [c.as_dict() for c in checks],
    }
    Path(str(report_base) + ".json").write_bytes(dumps(report_json))

    print(f"Preguntas: {len(questions)} {manifest['per_tema']}")
    for c in checks:
        print(f"[{c.level:5}] {c.title}: {c.summary}")
    if n_err:
        print(f"Escrito solo el informe: {report_base}.md/.json "
              "(questions.json y manifest.json NO se han escrito)")
        print(f"\n{n_err} comprobaciones con ERROR: revisa el informe.", file=sys.stderr)
        return 1
    print(f"Escrito: {out_dir / 'questions.json'}, {out_dir / 'manifest.json'}, {report_base}.md/.json")
    return 0


def main(argv: Optional[list[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--src", required=True, type=Path, help="carpeta con temaN.pdf y temaNr.pdf")
    ap.add_argument("--edition", required=True)
    ap.add_argument("--retrieved", required=True, help="fecha de descarga AAAA-MM-DD")
    ap.add_argument("--out", required=True, type=Path, help="carpeta de salida (questions.json, manifest.json)")
    ap.add_argument("--report", required=True, type=Path,
                    help="ruta base del informe (sin extension; se escriben .md y .json)")
    ap.add_argument("--explanations", type=Path, default=None,
                    help="carpeta con t1.json..t7.json de explicaciones y avisos propios "
                         "(por defecto tool/content/explanations/<edicion> si existe)")
    ap.add_argument("--cifras", type=Path, default=None,
                    help="JSON con las correcciones manuales del flag `cifras` "
                         "(por defecto tool/content/cifras/<edicion>.json si existe)")
    args = ap.parse_args(argv)
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", args.retrieved):
        print("--retrieved debe tener formato AAAA-MM-DD", file=sys.stderr)
        return 2
    try:
        find_pdftotext()
        import fitz  # noqa: F401  # type: ignore
    except MissingToolError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2
    except ImportError:
        print("ERROR: falta PyMuPDF. Instala con `pip install -r tool/content/requirements.txt`.",
              file=sys.stderr)
        return 2
    explanations_dir = args.explanations
    if explanations_dir is None:
        default = default_explanations_dir(args.edition)
        explanations_dir = default if default.is_dir() else None
    elif not explanations_dir.is_dir():
        print(f"ERROR: --explanations: no existe la carpeta {explanations_dir}", file=sys.stderr)
        return 2
    cifras_path = args.cifras
    if cifras_path is None:
        default = cifras_flag.default_cifras_path(args.edition)
        cifras_path = default if default.is_file() else None
    elif not cifras_path.is_file():
        print(f"ERROR: --cifras: no existe el fichero {cifras_path}", file=sys.stderr)
        return 2
    try:
        return run(args.src, args.edition, args.retrieved, args.out, args.report, explanations_dir,
                   cifras_path)
    except (FileNotFoundError, RuntimeError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
