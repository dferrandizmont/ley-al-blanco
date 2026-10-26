"""Marca `cifras` del banco: preguntas cuya clave es una cifra, un plazo, una edad,
una cantidad, un calibre o un importe (las «trampas» del examen).

Capa nuestra, como las explicaciones: **no toca** enunciado, opciones ni respuesta oficial;
solo anade el flag `cifras` a `flags`. El calculo es determinista (sin fechas ni azar):

1. Heuristica sobre enunciado y opciones (`heuristic_cifras`).
2. Correcciones manuales versionadas en `tool/content/cifras/<edicion>.json`
   (`{"incluir": {"t6-041": "motivo"}, "excluir": {"t2-054": "motivo"}}`), que mandan sobre la
   heuristica. Un id desconocido, repetido o en las dos listas es un ERROR.

Heuristica (una cantidad es un numero, en cifra o en letra, seguido de una unidad: anos,
dias, euros, cartuchos, mm, julios...; los numeros de categoria «3.2» o «2.2» no cuentan):

* A. Al menos dos opciones llevan cantidades y no son las mismas (las opciones solo cambian
  en el dato).
* B. El enunciado pregunta «cuantos/cuantas» y alguna opcion empieza por un numero.
* C. El enunciado fija una medida (julios, mm, cm, metros, gramos, calibre N): la respuesta
  depende de esa cifra aunque las opciones sean una categoria o un si/no.
* D. La opcion correcta lleva una cantidad.
"""
from __future__ import annotations

import json
import re
import unicodedata
from pathlib import Path
from typing import Any, Iterable, Optional

FLAG = "cifras"

# «un/una/uno» y «medio/media» solo cuentan con unidades de tiempo o dinero (si no, son el
# articulo: «una escopeta»); los demas numeros cuentan con cualquier unidad.
SOFT_WORDS = ("un", "uno", "una", "medio", "media")
NUMBER_WORDS = (
    "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve",
    "diez", "once", "doce", "trece", "catorce", "quince", "dieciseis", "diecisiete", "dieciocho",
    "diecinueve", "veinte", "veinticuatro", "treinta", "cuarenta", "cincuenta", "sesenta",
    "setenta", "ochenta", "noventa", "cien", "ciento", "doscientos", "doscientas", "trescientos",
    "quinientos", "mil",
)

# Unidades de tiempo, dinero, medida y recuento. Sin acentos y en minusculas.
TIME_UNITS = ("ano", "anos", "mes", "meses", "dia", "dias", "hora", "horas", "semana", "semanas",
              "minuto", "minutos")
MONEY_UNITS = ("euro", "euros", "€", "_")
MEASURE_UNITS = ("mm", "cm", "km", "milimetro", "milimetros", "centimetro", "centimetros",
                 "metro", "metros", "julio", "julios", "gramo", "gramos", "kg",
                 "kilo", "kilos", "kilogramo", "kilogramos", "litro", "litros", "%")
COUNT_UNITS = ("cartucho", "cartuchos", "arma", "armas", "escopeta", "escopetas", "cargador",
               "cargadores", "licencia", "licencias", "pieza", "piezas", "unidad", "unidades",
               "persona", "personas", "proyectil", "proyectiles", "bala", "balas", "vez", "veces",
               "ejemplar", "ejemplares", "disparo", "disparos", "plaza", "plazas")

_NUM = r"(?:\d+(?:[.,´']\d+)*)"
_WORDS = "|".join(sorted(NUMBER_WORDS, key=len, reverse=True))
_SOFT = "|".join(SOFT_WORDS)
_NUMBER_RE = rf"(?:{_NUM}|\b(?:{_WORDS})\b)"


def _alt(units: Iterable[str]) -> str:
    return "|".join(re.escape(u) for u in sorted(units, key=len, reverse=True))


_UNIT_RE = _alt((*TIME_UNITS, *MONEY_UNITS, *MEASURE_UNITS, *COUNT_UNITS))
_MEASURE_RE = _alt(("mm", "cm", "milimetro", "milimetros", "centimetro", "centimetros", "metro",
                    "metros", "julio", "julios", "gramo", "gramos", "kg", "kilogramo",
                    "kilogramos"))

# Numero (cifra o letra) + unidad. El numero no puede ser el de una categoria («3.2»,
# «2ª.2») ni seguir a «categoria».
QUANTITY = re.compile(rf"(?<![\w´'.,])({_NUMBER_RE})\s*[-]?\s*({_UNIT_RE})(?![a-z0-9])")
_SOFT_UNIT_RE = _alt((*TIME_UNITS, *MONEY_UNITS))
SOFT_QUANTITY = re.compile(rf"(?<![\w´'.,])({_SOFT})\s+({_SOFT_UNIT_RE})(?![a-z0-9])")
# Opcion que es solo un numero: «Una.», «Tres», «5».
BARE_OPTION = re.compile(rf"^\W*(?:{_NUM}|{_WORDS}|{_SOFT})\W*$")
MEASURE_IN_STEM = re.compile(rf"(?<![\w´'.,])({_NUM}|\b(?:{_WORDS})\b)\s*({_MEASURE_RE})(?![a-z0-9])")
CALIBRE = re.compile(rf"\bcalibres?\s+(?:de\s+|del\s+)?\.?{_NUM}")
# Un numero «suelto» largo (un ano, 1550) o con decimales (24,2) tambien es un dato.
BARE_FIGURE = re.compile(r"(?<![\w´'.,])(?:\d{3,}|\d+[,´']\d+)(?![\w])")
STARTS_WITH_NUMBER = re.compile(rf"^\W*({_NUM}|(?:{_WORDS})\b)")
ASKS_HOW_MANY = re.compile(r"\bcuant[oa]s?\b")


def fold(text: str) -> str:
    """Minusculas y sin acentos (la ordinal «ª/º» se conserva para descartar categorias)."""
    out = []
    for ch in unicodedata.normalize("NFD", text.lower()):
        if unicodedata.category(ch) == "Mn":
            continue
        out.append(ch)
    return "".join(out)


def _strip_categories(text: str) -> str:
    """Quita los numeros de categoria («3ª», «2ª.2», «categoria 3.2», «7º 2») para que no
    cuenten como cantidad."""
    t = re.sub(r"\d+\s*[ªº°]\s*(?:[.´']?\s*\d+)?", " ", text)
    t = re.sub(r"\bcategorias?\s+\d+(?:[.´']\d+)?", " ", t)
    return t


def quantities(text: str) -> list[str]:
    """Cantidades (numero + unidad) de un texto, normalizadas, en orden de aparicion."""
    t = _strip_categories(fold(text))
    found = [f"{m.group(1)} {m.group(2)}" for m in QUANTITY.finditer(t)]
    found += [f"{m.group(1)} {m.group(2)}" for m in SOFT_QUANTITY.finditer(t)]
    if BARE_OPTION.match(t):
        found.append(t.strip(" .,;:"))
    found += [m.group(0) for m in BARE_FIGURE.finditer(t) if m.group(0) not in " ".join(found)]
    return found


def measure_in_stem(stem: str) -> bool:
    t = _strip_categories(fold(stem))
    return bool(MEASURE_IN_STEM.search(t) or CALIBRE.search(t))


def heuristic_reasons(stem: str, options: list[str], answer: Optional[int]) -> list[str]:
    """Letras (A-D) de las reglas que se cumplen; vacio = no es de cifras."""
    reasons: list[str] = []
    per_option = [quantities(o) for o in options]
    with_qty = [tuple(q) for q in per_option if q]
    if len(with_qty) >= 2 and len(set(with_qty)) >= 2:
        reasons.append("A")
    t_stem = fold(stem)
    if ASKS_HOW_MANY.search(t_stem) and any(STARTS_WITH_NUMBER.search(fold(o)) for o in options):
        reasons.append("B")
    if measure_in_stem(stem):
        reasons.append("C")
    if answer is not None and 0 <= answer < len(options) and per_option[answer]:
        reasons.append("D")
    return reasons


def heuristic_cifras(stem: str, options: list[str], answer: Optional[int]) -> bool:
    return bool(heuristic_reasons(stem, options, answer))


# ------------------------------------------------------------------ correcciones manuales


def default_cifras_path(edition: str) -> Path:
    """`tool/content/cifras/<edicion>.json` (junto a este script)."""
    return Path(__file__).resolve().parent / "cifras" / f"{edition}.json"


def load_overrides(path: Optional[Path]) -> tuple[dict[str, str], dict[str, str], list[str]]:
    """(incluir, excluir, errores). Un fichero ausente (`None`) = sin correcciones."""
    if path is None:
        return {}, {}, []
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        return {}, {}, [f"{path.name}: no se puede leer ({e})"]
    errs: list[str] = []
    if not isinstance(raw, dict):
        return {}, {}, [f"{path.name}: debe ser un objeto con 'incluir' y 'excluir'"]
    for key in raw:
        if key not in ("incluir", "excluir"):
            errs.append(f"{path.name}: campo desconocido '{key}'")
    lists: dict[str, dict[str, str]] = {}
    for key in ("incluir", "excluir"):
        value = raw.get(key, {})
        if not isinstance(value, dict):
            errs.append(f"{path.name}: '{key}' debe ser un objeto {{id: motivo}}")
            lists[key] = {}
            continue
        clean: dict[str, str] = {}
        for qid, why in value.items():
            if not isinstance(why, str) or not why.strip():
                errs.append(f"{path.name}: '{key}' {qid}: el motivo debe ser un texto no vacio")
            else:
                clean[qid] = why
        lists[key] = clean
    return lists["incluir"], lists["excluir"], errs


def compute_flags(questions: list[dict], include: dict[str, str],
                  exclude: dict[str, str]) -> tuple[dict[str, bool], list[str], dict[str, Any]]:
    """(id -> tiene el flag, errores, datos del informe). Solo lee `id`, `tema`, `stem`,
    `options` y `answer` de cada pregunta."""
    errs: list[str] = []
    ids = [q["id"] for q in questions]
    known = set(ids)
    for label, group in (("incluir", include), ("excluir", exclude)):
        for qid in group:
            if qid not in known:
                errs.append(f"'{label}': id desconocido {qid}")
    for qid in sorted(set(include) & set(exclude)):
        errs.append(f"{qid} esta a la vez en 'incluir' y en 'excluir'")

    result: dict[str, bool] = {}
    auto_yes = auto_no = 0
    added: list[str] = []
    removed: list[str] = []
    for q in questions:
        auto = heuristic_cifras(q["stem"], q["options"], q["answer"])
        qid = q["id"]
        if qid in include and qid not in exclude:
            final = True
            if not auto:
                added.append(qid)
        elif qid in exclude and qid not in include:
            final = False
            if auto:
                removed.append(qid)
        else:
            final = auto
        auto_yes += auto
        auto_no += not auto
        result[qid] = final
    per_tema: dict[str, dict[str, int]] = {}
    for q in questions:
        row = per_tema.setdefault(str(q["tema"]), {"total": 0, "cifras": 0})
        row["total"] += 1
        row["cifras"] += result[q["id"]]
    data = {
        "por_tema": [{"tema": t, **row} for t, row in sorted(per_tema.items())],
        "heuristica": auto_yes,
        "total": sum(result.values()),
        "incluidas_a_mano": added,
        "excluidas_a_mano": removed,
    }
    return result, errs, data


def apply_flags(qlist: list[dict], result: dict[str, bool]) -> None:
    """Anade `cifras` (al final, sin duplicar) a `flags` de las preguntas marcadas. No toca
    nada mas."""
    for q in qlist:
        if result.get(q["id"]) and FLAG not in q["flags"]:
            q["flags"] = [*q["flags"], FLAG]
