#!/usr/bin/env python3
"""Valida los resumenes de teoria y los empaqueta en `teoria.json`.

Lee `tool/content/teoria/<edicion>/t1.json .. t7.json`, `practica.json` y, si existen,
`aem.json` y `glosario.json` (esquema en docs/teoria-guia.md), los valida de forma estricta
y escribe `app/assets/content/armas/<edicion>/teoria.json` (todos juntos, orden estable
t1..t7, practica, aem, glosario). `aem` y `glosario` son opcionales: si faltan, el build
sale bien con los demas. Anade `teoria_sha256` (sha256 de los bytes exactos del fichero) al
`manifest.json` ya existente, sin tocar el resto del manifiesto ni `questions.json`.

Los campos internos (`confidence`, `sources`, `review_notes`, `reviewed`) sirven para la
revision y NO se copian al asset.

Uso, desde la raiz del repositorio (extract_questions.py conserva `teoria_sha256` al
regenerar el banco):

    python tool/content/build_teoria.py --edition GC-2020-11 \\
        --out app/assets/content/armas/GC-2020-11

Codigo de salida: 0 correcto; 1 si algun documento no valida (no se escribe nada);
2 si falta un fichero de entrada (o questions.json / manifest.json en --out).
`--partial` permite construir con solo parte de los documentos (desarrollo); no usar
para publicar.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
from pathlib import Path
from typing import Any, Optional

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from extract_questions import CONFIDENCE_LEVELS, ID_RE, TEMAS, dumps, sha256_bytes  # noqa: E402

GENERATED_BY = "tool/content/build_teoria.py"
DOC_IDS = tuple(f"t{t}" for t in TEMAS) + ("practica",)
# Documentos que pueden faltar sin que falle el build (se incluyen si existe su fichero).
OPTIONAL_DOC_IDS = ("aem", "glosario")
ALL_DOC_IDS = DOC_IDS + OPTIONAL_DOC_IDS
# Documentos sin tema (tema = null): se abren desde la lista de teoria, no desde un tema.
NULL_TEMA_IDS = ("practica", "aem", "glosario")
MANIFEST_KEY = "teoria_sha256"

P_MAX_CHARS = 400
CELL_MAX_CHARS = 60
TABLE_MIN_COLS, TABLE_MAX_COLS = 2, 4
SECTIONS_MIN, SECTIONS_MAX = 3, 6
# Limites de secciones por documento cuando no son los generales.
SECTIONS_BOUNDS = {"glosario": (4, 8)}
TERM_MAX_CHARS, TERM_TEXT_MAX_CHARS = 60, 240
GLOSSARY_TERMS_MIN, GLOSSARY_TERMS_MAX = 40, 120
BLOCK_TYPES = ("p", "list", "table", "key", "notice", "diagram", "terms")
DIAGRAM_KINDS = ("galeria_tiro", "zona_segura", "secuencia")
ARTICLE_RE = re.compile(r"^(Arts?\.|Anexo|Apdo\.|Disp\.)\s+\S")

DOC_FIELDS = (
    "id", "tema", "title", "summary", "sections", "related_questions",
    "confidence", "sources", "review_notes", "reviewed",
)
DOC_REQUIRED = ("id", "tema", "title", "summary", "sections", "related_questions", "confidence")
SECTION_FIELDS = ("title", "collapsed", "blocks", "articles")
SECTION_REQUIRED = ("title", "blocks", "articles")

# Lo que de cada nivel llega al asset (todo lo demas es interno).
BLOCK_PUBLIC = {
    "p": ("type", "text"),
    "list": ("type", "items"),
    "table": ("type", "caption", "headers", "rows"),
    "key": ("type", "text"),
    "notice": ("type", "text"),
    "diagram": ("type", "kind", "caption", "items"),
    "terms": ("type", "items"),
}
BLOCK_ALLOWED = {
    "p": {"type", "text"},
    "list": {"type", "items"},
    "table": {"type", "caption", "headers", "rows"},
    "key": {"type", "text"},
    "notice": {"type", "text"},
    "diagram": {"type", "kind", "caption", "items"},
    "terms": {"type", "items"},
}
TERM_FIELDS = {"term", "text", "article"}


# Espacio duro (U+00A0) entre una cifra y su unidad, para que el simbolo o la unidad no se
# quede solo al principio de una linea («30.001 a 600.000 / €»).
NBSP = "\u00a0"
_UNIT_AFTER_NUMBER = re.compile(
    r"(?<=\d) (?=\u20ac|%|(?:cm|mm|km|m|kg|g|J|julios|a\u00f1os?|d\u00edas?|meses|mes|euros)\b)"
)


def keep_units_with_numbers(value: Any) -> Any:
    """Cambia, en todos los textos de `value`, el espacio entre una cifra y su unidad por un
    espacio duro. Idempotente; no toca nada mas (ni las claves)."""
    if isinstance(value, str):
        return _UNIT_AFTER_NUMBER.sub(NBSP, value)
    if isinstance(value, list):
        return [keep_units_with_numbers(v) for v in value]
    if isinstance(value, dict):
        return {k: keep_units_with_numbers(v) for k, v in value.items()}
    return value


def _is_text(x: Any) -> bool:
    return isinstance(x, str) and bool(x.strip())


def _validate_block(where: str, block: Any, errs: list[str]) -> Optional[dict]:
    if not isinstance(block, dict):
        errs.append(f"{where}: el bloque debe ser un objeto JSON")
        return None
    kind = block.get("type")
    if kind not in BLOCK_TYPES:
        errs.append(f"{where}: tipo de bloque {kind!r} no valido (usa {', '.join(BLOCK_TYPES)})")
        return None
    where = f"{where} ({kind})"
    for k in block:
        if k not in BLOCK_ALLOWED[kind]:
            errs.append(f"{where}: campo desconocido {k!r}")
    n0 = len(errs)

    if kind in ("p", "key", "notice"):
        text = block.get("text")
        if not _is_text(text):
            errs.append(f"{where}: falta `text` o esta vacio")
        elif kind == "p" and len(text) > P_MAX_CHARS:
            errs.append(f"{where}: el parrafo tiene {len(text)} caracteres (maximo {P_MAX_CHARS})")
    elif kind == "list":
        items = block.get("items")
        if not isinstance(items, list) or not items or not all(_is_text(i) for i in items):
            errs.append(f"{where}: `items` debe ser una lista no vacia de textos no vacios")
    elif kind == "table":
        headers, rows = block.get("headers"), block.get("rows")
        if "caption" in block and not _is_text(block["caption"]):
            errs.append(f"{where}: `caption`, si esta, debe ser un texto no vacio")
        if not isinstance(headers, list) or not all(_is_text(h) for h in headers):
            errs.append(f"{where}: `headers` debe ser una lista de textos no vacios")
        else:
            if not TABLE_MIN_COLS <= len(headers) <= TABLE_MAX_COLS:
                errs.append(f"{where}: {len(headers)} columnas (debe haber {TABLE_MIN_COLS} a {TABLE_MAX_COLS})")
            for h in headers:
                if len(h) > CELL_MAX_CHARS:
                    errs.append(f"{where}: cabecera de {len(h)} caracteres (maximo {CELL_MAX_CHARS}): {h[:30]!r}...")
        if not isinstance(rows, list) or not rows:
            errs.append(f"{where}: `rows` debe ser una lista no vacia")
        else:
            width = len(headers) if isinstance(headers, list) else None
            for ri, row in enumerate(rows):
                if not isinstance(row, list) or not all(isinstance(c, str) for c in row):
                    errs.append(f"{where}: fila {ri + 1} debe ser una lista de textos")
                    continue
                if width is not None and len(row) != width:
                    errs.append(f"{where}: fila {ri + 1} tiene {len(row)} celdas y hay {width} columnas")
                for c in row:
                    if len(c) > CELL_MAX_CHARS:
                        errs.append(f"{where}: celda de la fila {ri + 1} con {len(c)} caracteres "
                                    f"(maximo {CELL_MAX_CHARS}): {c[:30]!r}...")
    elif kind == "terms":
        items = block.get("items")
        if not isinstance(items, list) or not items:
            errs.append(f"{where}: `items` debe ser una lista no vacia de terminos")
        else:
            for ti, it in enumerate(items):
                tw = f"{where} termino {ti + 1}"
                if not isinstance(it, dict):
                    errs.append(f"{tw}: debe ser un objeto {{term, text, article?}}")
                    continue
                for k in it:
                    if k not in TERM_FIELDS:
                        errs.append(f"{tw}: campo desconocido {k!r}")
                term, text = it.get("term"), it.get("text")
                if not _is_text(term):
                    errs.append(f"{tw}: falta `term` o esta vacio")
                elif len(term) > TERM_MAX_CHARS:
                    errs.append(f"{tw}: `term` tiene {len(term)} caracteres (maximo {TERM_MAX_CHARS}): {term[:30]!r}...")
                if not _is_text(text):
                    errs.append(f"{tw}: falta `text` o esta vacio")
                elif len(text) > TERM_TEXT_MAX_CHARS:
                    errs.append(f"{tw}: `text` tiene {len(text)} caracteres (maximo {TERM_TEXT_MAX_CHARS})")
                if "article" in it:
                    art = it["article"]
                    if not isinstance(art, str) or not ARTICLE_RE.match(art):
                        errs.append(f"{tw}: articulo {art!r} no tiene el formato "
                                    "«Art. N ...», «Anexo ...», «Apdo. ...» o «Disp. ...»")
    elif kind == "diagram":
        dk = block.get("kind")
        if dk not in DIAGRAM_KINDS:
            errs.append(f"{where}: `kind` {dk!r} no valido (usa {', '.join(DIAGRAM_KINDS)})")
        if "caption" in block and not _is_text(block["caption"]):
            errs.append(f"{where}: `caption`, si esta, debe ser un texto no vacio")
        items = block.get("items")
        if dk == "secuencia":
            if not isinstance(items, list) or not items or not all(_is_text(i) for i in items):
                errs.append(f"{where}: `secuencia` requiere `items` (lista no vacia de textos)")
        elif dk in DIAGRAM_KINDS and "items" in block:
            errs.append(f"{where}: solo `secuencia` lleva `items`")

    if len(errs) > n0:
        return None
    return {k: block[k] for k in BLOCK_PUBLIC[kind] if k in block}


def _validate_section(where: str, sec: Any, review_notes: str, errs: list[str]) -> Optional[dict]:
    if not isinstance(sec, dict):
        errs.append(f"{where}: la seccion debe ser un objeto JSON")
        return None
    n0 = len(errs)
    for k in sec:
        if k not in SECTION_FIELDS:
            errs.append(f"{where}: campo desconocido {k!r}")
    for k in SECTION_REQUIRED:
        if k not in sec:
            errs.append(f"{where}: falta el campo obligatorio {k!r}")
    title = sec.get("title")
    if "title" in sec and not _is_text(title):
        errs.append(f"{where}: `title` vacio")
    if "collapsed" in sec and not isinstance(sec["collapsed"], bool):
        errs.append(f"{where}: `collapsed` debe ser booleano")
    label = f"{where} {title!r}" if _is_text(title) else where

    blocks_out: list[dict] = []
    blocks = sec.get("blocks")
    if "blocks" in sec:
        if not isinstance(blocks, list) or not blocks:
            errs.append(f"{label}: `blocks` debe ser una lista no vacia")
        else:
            for bi, block in enumerate(blocks):
                b = _validate_block(f"{label} bloque {bi + 1}", block, errs)
                if b is not None:
                    blocks_out.append(b)

    arts = sec.get("articles")
    if "articles" in sec:
        if not isinstance(arts, list) or not all(isinstance(a, str) for a in arts):
            errs.append(f"{label}: `articles` debe ser una lista de textos")
        else:
            for a in arts:
                if not ARTICLE_RE.match(a):
                    errs.append(f"{label}: articulo {a!r} no tiene el formato «Art. N ...», «Anexo ...», «Apdo. ...» o «Disp. ...»")
            if not arts and not review_notes.strip():
                errs.append(f"{label}: sin `articles` (y `review_notes` no lo justifica)")

    if len(errs) > n0:
        return None
    return {
        "title": title,
        "collapsed": bool(sec.get("collapsed", False)),
        "blocks": blocks_out,
        "articles": list(arts),
    }


def _term_key(term: str) -> str:
    """Clave para detectar terminos repetidos: sin tildes, sin mayusculas ni espacios de mas."""
    nfd = unicodedata.normalize("NFD", term)
    plain = "".join(c for c in nfd if unicodedata.category(c) != "Mn")
    return " ".join(plain.casefold().split())


def _check_terms(file_name: str, doc_id: str, sections: list[dict]) -> list[str]:
    """Reglas del bloque `terms` a nivel de documento (ya validadas las secciones)."""
    errs: list[str] = []
    seen: dict[str, str] = {}
    total = 0
    for sec in sections:
        for block in sec["blocks"]:
            if block.get("type") != "terms":
                continue
            for it in block["items"]:
                total += 1
                key = _term_key(it["term"])
                if key in seen:
                    errs.append(f"{file_name}: termino repetido {it['term']!r} "
                                f"(ya esta como {seen[key]!r}); cada termino va una sola vez")
                else:
                    seen[key] = it["term"]
    if doc_id == "glosario" and not GLOSSARY_TERMS_MIN <= total <= GLOSSARY_TERMS_MAX:
        errs.append(f"{file_name}: {total} terminos (debe haber {GLOSSARY_TERMS_MIN} a {GLOSSARY_TERMS_MAX})")
    return errs


def validate_doc(file_name: str, doc: Any, expected_id: str,
                 known_questions: set[str]) -> tuple[Optional[dict], list[str]]:
    """Valida un documento. Devuelve (documento publico | None, errores)."""
    errs: list[str] = []
    if not isinstance(doc, dict):
        return None, [f"{file_name}: el documento debe ser un objeto JSON"]
    for k in doc:
        if k not in DOC_FIELDS:
            errs.append(f"{file_name}: campo desconocido {k!r}")
    for k in DOC_REQUIRED:
        if k not in doc:
            errs.append(f"{file_name}: falta el campo obligatorio {k!r}")

    doc_id = doc.get("id")
    if doc_id != expected_id:
        errs.append(f"{file_name}: `id` es {doc_id!r} y debe ser {expected_id!r}")
    tema = doc.get("tema")
    if expected_id in NULL_TEMA_IDS:
        if "tema" in doc and tema is not None:
            errs.append(f"{file_name}: `tema` debe ser null en {expected_id}")
    else:
        want = int(expected_id[1:])
        if "tema" in doc and (type(tema) is not int or tema != want):
            errs.append(f"{file_name}: `tema` es {tema!r} y debe ser {want}")
    for k in ("title", "summary"):
        if k in doc and not _is_text(doc[k]):
            errs.append(f"{file_name}: `{k}` vacio")
    conf = doc.get("confidence")
    if "confidence" in doc and conf not in CONFIDENCE_LEVELS:
        errs.append(f"{file_name}: `confidence` {conf!r} no valida (usa {'|'.join(CONFIDENCE_LEVELS)})")
    notes = doc.get("review_notes", "")
    if not isinstance(notes, str):
        errs.append(f"{file_name}: `review_notes` debe ser un texto")
        notes = ""
    if "reviewed" in doc and not isinstance(doc["reviewed"], bool):
        errs.append(f"{file_name}: `reviewed` debe ser booleano")
    srcs = doc.get("sources")
    if "sources" in doc:
        if not isinstance(srcs, list) or not all(
                isinstance(s, dict) and _is_text(s.get("norma")) and _is_text(s.get("ref"))
                and set(s) <= {"norma", "ref"} for s in srcs):
            errs.append(f"{file_name}: `sources` debe ser una lista de {{norma, ref}}")

    rq = doc.get("related_questions")
    if "related_questions" in doc:
        if not isinstance(rq, list) or not all(isinstance(q, str) for q in rq):
            errs.append(f"{file_name}: `related_questions` debe ser una lista de ids")
        else:
            seen: set[str] = set()
            for q in rq:
                if not ID_RE.match(q):
                    errs.append(f"{file_name}: id de pregunta {q!r} con formato incorrecto (tN-NNN)")
                elif q not in known_questions:
                    errs.append(f"{file_name}: la pregunta {q!r} no existe en questions.json")
                if q in seen:
                    errs.append(f"{file_name}: pregunta {q!r} repetida en `related_questions`")
                seen.add(q)

    sections_out: list[dict] = []
    sections = doc.get("sections")
    if "sections" in doc:
        if not isinstance(sections, list):
            errs.append(f"{file_name}: `sections` debe ser una lista")
        else:
            lo, hi = SECTIONS_BOUNDS.get(expected_id, (SECTIONS_MIN, SECTIONS_MAX))
            if not lo <= len(sections) <= hi:
                errs.append(f"{file_name}: {len(sections)} secciones (debe haber {lo} a {hi})")
            titles: dict[str, int] = {}
            for si, sec in enumerate(sections):
                s = _validate_section(f"{file_name} seccion {si + 1}", sec, notes, errs)
                if s is not None:
                    sections_out.append(s)
                    # La app identifica cada seccion plegable por su posicion, pero un
                    # titulo repetido confunde al lector y al lector de pantalla.
                    key = _term_key(s["title"])
                    if key in titles:
                        errs.append(f"{file_name} seccion {si + 1}: titulo de seccion repetido "
                                    f"{s['title']!r} (ya es el de la seccion {titles[key]})")
                    else:
                        titles[key] = si + 1

    errs.extend(_check_terms(file_name, expected_id, sections_out))
    if errs:
        return None, errs
    return keep_units_with_numbers({
        "id": doc["id"],
        "tema": doc["tema"],
        "title": doc["title"],
        "summary": doc["summary"],
        "sections": sections_out,
        "related_questions": list(rq),
    }), []


def load_known_questions(questions_path: Path) -> set[str]:
    data = json.loads(questions_path.read_text(encoding="utf-8"))
    return {q["id"] for q in data}


def build(src_dir: Path, edition: str, out_dir: Path, partial: bool = False) -> int:
    questions_path = out_dir / "questions.json"
    manifest_path = out_dir / "manifest.json"
    for p in (questions_path, manifest_path):
        if not p.is_file():
            print(f"ERROR: falta {p} (ejecuta antes extract_questions.py)", file=sys.stderr)
            return 2
    try:
        known = load_known_questions(questions_path)
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, ValueError, KeyError, TypeError) as e:
        print(f"ERROR: no se puede leer questions.json / manifest.json: {e}", file=sys.stderr)
        return 2
    if not isinstance(manifest, dict) or manifest.get("edition") != edition:
        found = manifest.get("edition") if isinstance(manifest, dict) else None
        print(f"ERROR: --edition {edition!r} no coincide con la edicion del manifiesto de {out_dir} "
              f"({found!r}); revisa --edition y --out", file=sys.stderr)
        return 2

    docs: list[dict] = []
    reviewed = 0
    all_errs: list[str] = []
    missing: list[str] = []
    for doc_id in ALL_DOC_IDS:
        path = src_dir / f"{doc_id}.json"
        if not path.is_file():
            if doc_id in DOC_IDS:
                missing.append(path.name)
            continue
        try:
            raw = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError) as e:
            all_errs.append(f"{path.name}: no se puede leer como JSON: {e}")
            continue
        doc, errs = validate_doc(path.name, raw, doc_id, known)
        all_errs.extend(errs)
        if doc is not None:
            docs.append(doc)
            if raw.get("reviewed") is True:
                reviewed += 1

    if missing and not partial:
        print(f"ERROR: faltan ficheros en {src_dir}: {', '.join(missing)} "
              "(usa --partial solo para desarrollo)", file=sys.stderr)
        return 2
    if all_errs:
        for e in all_errs:
            print(f"ERROR: {e}", file=sys.stderr)
        print(f"\n{len(all_errs)} errores: no se ha escrito nada.", file=sys.stderr)
        return 1

    out = {"edition": edition, "generated_by": GENERATED_BY, "docs": docs}
    data = dumps(out)
    new_manifest: dict[str, Any] = {}
    for k, v in manifest.items():
        if k == MANIFEST_KEY:
            continue
        new_manifest[k] = v
        if k == "questions_sha256":
            new_manifest[MANIFEST_KEY] = sha256_bytes(data)
    new_manifest.setdefault(MANIFEST_KEY, sha256_bytes(data))

    (out_dir / "teoria.json").write_bytes(data)
    manifest_path.write_bytes(dumps(new_manifest))
    print(f"Teoria: {len(docs)} documentos ({', '.join(d['id'] for d in docs)})")
    print(f"Teoria: {reviewed}/{len(docs) + len(missing)} documentos revisados")
    if missing:
        print(f"AVISO (--partial): faltan {', '.join(missing)}")
    print(f"Escrito: {out_dir / 'teoria.json'} y {MANIFEST_KEY} en {manifest_path}")
    return 0


def main(argv: Optional[list[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--edition", required=True)
    ap.add_argument("--src", type=Path, default=None,
                    help="carpeta con t1..t7.json, practica.json y, opcionales, aem.json y glosario.json (por defecto tool/content/teoria/<edicion>)")
    ap.add_argument("--out", required=True, type=Path,
                    help="carpeta del asset (con questions.json y manifest.json; aqui se escribe teoria.json)")
    ap.add_argument("--partial", action="store_true", help="permite que falten documentos (solo desarrollo)")
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    args = ap.parse_args(argv)
    src = args.src or HERE / "teoria" / args.edition
    if not src.is_dir():
        print(f"ERROR: no existe la carpeta {src}", file=sys.stderr)
        return 2
    return build(src, args.edition, args.out, args.partial)


if __name__ == "__main__":
    sys.exit(main())
