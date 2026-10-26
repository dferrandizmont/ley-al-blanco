"""Convierte los XML consolidados de BOE (fuentes/boe/raw/*.texto.xml) en JSON por articulo.

Uso: python -I tool/content/boe/build.py
Solo stdlib. Lee `fuentes/boe/raw/` (datos no confiables: solo se parsea) y escribe `tool/content/boe/<short>.json`.
"""
import hashlib
import json
import os
import re
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
RAW = os.path.join(ROOT, "fuentes", "boe", "raw")
RETRIEVED = "2026-10-19"
TODAY = "20261019"

NORMAS = [
    ("reglamento-armas", "BOE-A-1993-6202", "Reglamento de Armas (RD 137/1993)"),
    ("lo-4-2015", "BOE-A-2015-3442", "LO 4/2015, de protección de la seguridad ciudadana"),
    ("orden-1998-pruebas", "BOE-A-1998-7416", "Orden de 18 de marzo de 1998 (pruebas de capacitación licencias de armas)"),
    ("resolucion-1998-pruebas", "BOE-A-1998-27988", "Resolución de 19 de octubre de 1998 de la DGGC (instrucciones Orden 18-3-1998)"),
    ("ley-caza-1970", "BOE-A-1970-369", "Ley 1/1970, de 4 de abril, de caza"),
    ("lo-1-1992", "BOE-A-1992-4252", "LO 1/1992, de 21 de febrero, sobre Protección de la Seguridad Ciudadana (DEROGADA)"),
    ("reglamento-cartucheria", "BOE-A-2015-12054", "Reglamento de artículos pirotécnicos y cartuchería (RD 989/2015)"),
    ("orden-int-2202-2014", "BOE-A-2014-12249", "Orden INT/2202/2014 (régimen de reproducciones o réplicas de armas de fuego antiguas)"),
    ("resolucion-2015-reproducciones", "BOE-A-2015-3779", "Resolución de 27-3-2015 DGGC (medidas de seguridad para guardar réplicas/reproducciones de armas antiguas en domicilios)"),
    ("resolucion-2024-cajas-fuertes", "BOE-A-2025-387", "Resolución de 4-12-2024 DGGC (medidas de seguridad mínimas de cajas fuertes o armeros en domicilios)"),
    ("resolucion-2024-transporte", "BOE-A-2025-386", "Resolución de 27-11-2024 DGGC (medidas de seguridad para almacenar armas durante el transporte)"),
    ("resolucion-1998-cajas-fuertes", "BOE-A-1998-28108", "Resolución de 26-11-1998 DGGC (cajas fuertes y armarios/armeros en domicilios; DEROGADA)"),
    ("reglamento-explosivos-1998", "BOE-A-1998-5934", "Reglamento de Explosivos (RD 230/1998) (DEROGADO)"),
    ("reglamento-cartucheria-2010", "BOE-A-2010-7333", "Reglamento de artículos pirotécnicos y cartuchería (RD 563/2010) (DEROGADO)"),
    ("reglamento-explosivos", "BOE-A-2017-2313", "Reglamento de Explosivos (RD 130/2017)"),
]

# Normas derogadas: se guardan para citar las cifras del cuestionario oficial (metadatos de la API: estatus_derogacion S).
DEROGADAS = {
    "BOE-A-1998-5934": "derogado por el RD 130/2017 (Reglamento de Explosivos vigente, BOE-A-2017-2313); se conserva porque su art. 297 es la fuente de 'sanciones: 1/2/4 años'",
    "BOE-A-2010-7333": "derogado por el RD 989/2015 (BOE-A-2015-12054); se conserva porque su art. 200.1 es la fuente de 'sanciones: 1/2/4 años'",
    "BOE-A-1998-28108": "derogada (estatus_derogacion S en la API); sustituida por la Resolución de 4-12-2024 DGGC (BOE-A-2025-387)",
    "BOE-A-1992-4252": "derogada por LO 4/2015 (disposición derogatoria única), con efectos de 2015-07-01",
}

WS = re.compile(r"[ \t\r\f\v ]+")


def clean(s):
    s = WS.sub(" ", s.replace(" ", " "))
    return re.sub(r"\n\s*\n+", "\n", re.sub(r" *\n *", "\n", s)).strip()


def el_text(e):
    return clean("".join(e.itertext()))


def table_text(t):
    rows = []
    for tr in t.iter("tr"):
        cells = [el_text(c) for c in tr if c.tag in ("td", "th")]
        if any(cells):
            rows.append(" | ".join(cells))
    return "\n".join(rows)


def version_parts(v):
    """Devuelve (head, paragraphs, notas) de una <version>."""
    head, paras, notas = "", [], []
    for e in v:
        cls = e.get("class")
        if e.tag == "blockquote":
            t = el_text(e)
            if t:
                notas.append(t)
        elif e.tag == "table":
            t = table_text(e)
            if t:
                paras.append(t)
        elif e.tag == "p":
            t = el_text(e)
            if not t:
                continue
            if cls == "articulo" and not head:
                head = t
            else:
                paras.append(t)
    return head, paras, notas


LEVEL = [
    ("titulo", re.compile(r"^(T[ÍI]TULO|T[ÍI]TULO PRELIMINAR)\b", re.I)),
    ("capitulo", re.compile(r"^CAP[ÍI]TULO\b", re.I)),
    ("seccion", re.compile(r"^(SECCI[ÓO]N|SUBSECCI[ÓO]N)\b", re.I)),
]
ANEXO = re.compile(r"^(ANEXO|ITC)\b", re.I)


def norm_ref(titulo):
    t = clean(titulo or "")
    m = re.match(r"^Art[íi]culo (.+)$", t)
    if m:
        return "art. " + m.group(1)
    m = re.match(r"^Disposici[óo]n (adicional|transitoria|final|derogatoria) (.+)$", t, re.I)
    if m:
        return "disp. %s %s" % (m.group(1).lower(), m.group(2).lower())
    return t


def mod_title(mid):
    d = os.path.join(RAW, "modificadores")
    for fn, tag in ((mid + ".metadatos.xml", "titulo"), (mid + ".xml", "titulo")):
        fp = os.path.join(d, fn)
        if os.path.exists(fp):
            m = re.search(r"<titulo>(.*?)</titulo>", open(fp, encoding="utf-8").read(), re.S)
            if m:
                return clean(m.group(1))
    return None


def html_updated(nid):
    fp = os.path.join(RAW, nid + ".html")
    if not os.path.exists(fp):
        return None
    t = open(fp, encoding="utf-8", errors="replace").read()
    m = re.search(r"ltima actualizaci(?:ó|&oacute;)n,? publicada el (\d\d)/(\d\d)/(\d{4})", t)
    return "%s-%s-%s" % (m.group(3), m.group(2), m.group(1)) if m else None


def build(short, nid, nombre):
    tree = ET.parse(os.path.join(RAW, nid + ".texto.xml"))
    meta = ET.parse(os.path.join(RAW, nid + ".metadatos.xml")).getroot()
    upd = (meta.findtext("data/metadatos/fecha_actualizacion") or "").strip()
    titulo_oficial = (meta.findtext("data/metadatos/titulo") or "").strip()
    bloques = tree.getroot().find("data/texto")
    ctx = {"titulo": "", "capitulo": "", "seccion": ""}
    anexo_ctx = ""
    items = []
    seen = set()
    for b in bloques:
        vers = [v for v in b if v.tag == "version" and v.get("fecha_vigencia", "0") <= TODAY]
        if not vers:
            continue
        vers.sort(key=lambda v: v.get("fecha_vigencia", ""))
        cur = vers[-1]
        bid = b.get("id", "")
        tipo = b.get("tipo", "")
        head, paras, notas = version_parts(cur)
        full = clean("\n".join(([head] if head else []) + paras))
        mods = []
        for v in vers:
            if v.get("id_norma") != nid:
                mods.append({
                    "por": v.get("id_norma"),
                    "publicacion": v.get("fecha_publicacion"),
                    "vigencia": v.get("fecha_vigencia"),
                })
        if tipo == "encabezado":
            first = clean(re.split(r"\n", "\n".join(([head] if head else []) + paras))[0]) if full else ""
            title_attr = clean(b.get("titulo") or "")
            if ANEXO.match(title_attr) or ANEXO.match(first):
                if re.match(r"^ITC\b", title_attr, re.I) or re.match(r"^INSTRUCCI", first, re.I):
                    anexo_ctx = title_attr
                    ref = title_attr
                else:
                    ref = (anexo_ctx + ", " if anexo_ctx else "") + (title_attr if title_attr.lower().startswith("anexo") else first)
                items.append({"ref": ref, "title": first, "text": full, "url": "https://www.boe.es/buscar/act.php?id=%s#%s" % (nid, bid),
                              "anchor": bid, "contexto": "Anexos / ITC",
                              "derogado": False, "notas": notas, "modificaciones": mods})
                continue
            lines = [l for l in full.split(chr(10)) if l]
            for lvl, rx in LEVEL:
                if rx.match(first) or rx.match(title_attr):
                    ctx[lvl] = first
                    if lvl == "capitulo" and len(lines) > 1 and len(lines[1]) < 120:
                        ctx[lvl] = first + " - " + lines[1]
                    for lower in list(ctx)[list(ctx).index(lvl) + 1:]:
                        ctx[lower] = ""
                    break
            else:
                # encabezado informativo (p. ej. "Armas historicas y artisticas"): se anade como subseccion
                if full and len(full) < 400 and bid not in ("informacionrelacionada",):
                    ctx["seccion"] = first
            continue
        if tipo in ("preambulo",):
            items.append({"ref": "preámbulo", "title": "Preámbulo", "text": full, "url": "https://www.boe.es/buscar/act.php?id=%s#%s" % (nid, bid),
                          "anchor": bid, "contexto": "", "derogado": False, "notas": notas, "modificaciones": mods})
            continue
        if tipo == "precepto":
            ref = norm_ref(b.get("titulo"))
            if ref in seen:
                ref = "%s [%s]" % (ref, bid)
            seen.add(ref)
            # titulo/rubrica: resto de la linea tras "Articulo N."
            title = ""
            m = re.match(r"^[^.]*?\.\s+(.+)$", head) if head else None
            if m:
                title = m.group(1).strip()
            body = clean("\n".join(paras))
            derog = bool(re.match(r"^\(?\s*(Derogad[oa]s?|Suprimid[oa]s?)\b", body, re.I)) or (not body and "derog" in " ".join(notas).lower())
            items.append({"ref": ref, "title": title, "text": body if body else head, "url": "https://www.boe.es/buscar/act.php?id=%s#%s" % (nid, bid),
                          "anchor": bid, "contexto": " > ".join(x for x in ctx.values() if x),
                          "derogado": derog, "notas": notas, "modificaciones": mods, "encabezado": head})
    out = {
        "norma": nombre,
        "titulo_oficial": titulo_oficial,
        "id": nid,
        "url": "https://www.boe.es/buscar/act.php?id=" + nid,
        "api": "https://www.boe.es/datosabiertos/api/legislacion-consolidada/id/%s/texto" % nid,
        "consolidado_hasta": html_updated(nid),
        "consolidado_hasta_nota": "fecha 'ultima actualizacion publicada' que muestra la pagina de BOE (act.php)",
        "ultima_actualizacion_boe": upd,
        "ultima_actualizacion_boe_nota": "fecha_actualizacion de la API de datos abiertos (marca de consolidacion)",
        "modificadores": {m: mod_title(m) for m in sorted({v["por"] for it in items for v in it["modificaciones"]})},
        "derogada": nid in DEROGADAS,
        "derogada_nota": DEROGADAS.get(nid, ""),
        "retrieved": RETRIEVED,
        "sha256_texto_xml": hashlib.sha256(open(os.path.join(RAW, nid + ".texto.xml"), "rb").read()).hexdigest(),
        "articles": items,
    }
    with open(os.path.join(HERE, short + ".json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
        f.write("\n")
    return out


if __name__ == "__main__":
    for short, nid, nombre in NORMAS:
        o = build(short, nid, nombre)
        print(short, nid, len(o["articles"]), "items", o["consolidado_hasta"])
