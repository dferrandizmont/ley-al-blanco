"""Busqueda por palabras clave (sin acentos ni mayusculas) en los JSON de legislacion BOE.

Uso:
  python -I tool/content/boe/buscar.py "revista armas cinco anos"
  python -I tool/content/boe/buscar.py -n 5 "guia pertenencia"        # max. 5 resultados
  python -I tool/content/boe/buscar.py -a "tarjeta europea"           # imprime el articulo completo
  python -I tool/content/boe/buscar.py -r "reglamento-armas:art. 3"    # imprime un articulo por referencia

Un articulo coincide si contiene TODAS las palabras (prefijos: "revist" casa "revista"/"revistas").
Se ordena por numero de apariciones. Solo stdlib.
"""
import glob
import json
import os
import re
import sys
import unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))


def fold(s):
    s = unicodedata.normalize("NFD", s.lower())
    return "".join(c for c in s if unicodedata.category(c) != "Mn")


def load():
    for fp in sorted(glob.glob(os.path.join(HERE, "*.json"))):
        with open(fp, encoding="utf-8") as f:
            d = json.load(f)
        yield os.path.basename(fp)[:-5], d


def snippet(text, ftext, words, width=160):
    pos = min((ftext.find(w) for w in words if ftext.find(w) >= 0), default=0)
    a = max(0, pos - width // 3)
    return re.sub(r"\s+", " ", text[a:a + width]).strip()


def main(argv):
    limit, full, ref = 15, False, None
    args = []
    it = iter(argv)
    for a in it:
        if a == "-n":
            limit = int(next(it))
        elif a == "-a":
            full = True
        elif a == "-r":
            ref = next(it)
        else:
            args.append(a)
    if ref:
        short, _, r = ref.partition(":")
        for s, d in load():
            if s == short:
                for x in d["articles"]:
                    if fold(x["ref"]) == fold(r.strip()):
                        print_item(d, x, full=True)
        return 0
    words = [w for w in fold(" ".join(args)).split() if w]
    if not words:
        print(__doc__)
        return 1
    hits = []
    for s, d in load():
        for x in d["articles"]:
            ft = fold(x["ref"] + " " + x.get("title", "") + " " + x["text"])
            if all(w in ft for w in words):
                score = sum(ft.count(w) for w in words)
                hits.append((score, s, d, x, ft))
    hits.sort(key=lambda h: -h[0])
    print("%d articulos coinciden (se muestran %d)" % (len(hits), min(limit, len(hits))))
    for score, s, d, x, ft in hits[:limit]:
        print_item(d, x, full, snippet(x["text"], fold(x["text"]), words) if not full else None)
    return 0


def print_item(d, x, full=False, snip=None):
    flag = " [DEROGADO]" if x.get("derogado") else ""
    print("\n== %s | %s%s %s" % (d["norma"], x["ref"], flag, ("- " + x["title"]) if x.get("title") else ""))
    if x.get("contexto"):
        print("   (%s)" % x["contexto"])
    print("   " + x["url"])
    if full:
        print(x["text"])
        for n in x.get("notas", []):
            print("   NOTA: " + re.sub(r"\s+", " ", n))
        for m in x.get("modificaciones", []):
            print("   MODIFICADO por %s (vigencia %s)" % (m["por"], m["vigencia"]))
    elif snip:
        print("   ..." + snip + "...")


if __name__ == "__main__":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    sys.exit(main(sys.argv[1:]))
