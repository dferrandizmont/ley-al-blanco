"""Convierte docs/legal/politica-privacidad.md en web/legal/privacidad/index.html.

Solo biblioteca estándar. Corta el documento en la regla horizontal que precede
a «Notas para el titular (no publicar)», que nunca se publica.
Uso: python -I web/legal/md2html.py
"""
import html
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
ORIGEN = RAIZ / "docs" / "legal" / "politica-privacidad.md"
DESTINO = Path(__file__).resolve().parent / "privacidad" / "index.html"
CORTE = "## Notas para el titular"

PLANTILLA = """<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light dark">
<title>Política de privacidad de Ley al Blanco</title>
<meta name="description" content="Política de privacidad de Ley al Blanco, app independiente y no oficial.">
<link rel="stylesheet" href="../styles.css">
</head>
<body>
<main>
{cuerpo}
<footer><a href="../">Ley al Blanco</a></footer>
</main>
</body>
</html>
"""


def inline(texto: str) -> str:
    t = html.escape(texto, quote=False)
    t = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", t)
    t = re.sub(r"(https?://[^\s<]+)", r'<a href="\1">\1</a>', t)
    t = t.replace(
        "[CORREO_SOPORTE]",
        '<a href="mailto:[CORREO_SOPORTE]">[CORREO_SOPORTE]</a>',
    )
    return t


def celdas(linea: str) -> list[str]:
    return [c.strip() for c in linea.strip().strip("|").split("|")]


def convertir(md: str) -> str:
    if CORTE in md:
        md = md.split(CORTE)[0]
        md = md.rstrip()
        if md.endswith("---"):
            md = md[:-3].rstrip()
    lineas = md.split("\n")
    out: list[str] = []
    i = 0
    n = len(lineas)
    while i < n:
        l = lineas[i]
        if not l.strip():
            i += 1
            continue
        m = re.match(r"(#{1,3}) (.*)", l)
        if m:
            k = len(m.group(1))
            out.append(f"<h{k}>{inline(m.group(2))}</h{k}>")
            i += 1
            continue
        if l.strip() == "---":
            out.append("<hr>")
            i += 1
            continue
        if l.startswith("|"):
            filas = []
            while i < n and lineas[i].startswith("|"):
                filas.append(lineas[i])
                i += 1
            cab = celdas(filas[0])
            t = ['<div class="tabla"><table>', "<thead><tr>"]
            t += [f"<th>{inline(c)}</th>" for c in cab]
            t.append("</tr></thead><tbody>")
            for f in filas[2:]:
                t.append("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in celdas(f)) + "</tr>")
            t.append("</tbody></table></div>")
            out.append("".join(t))
            continue
        if re.match(r"(- |\d+\. )", l):
            i = lista(lineas, i, out)
            continue
        # párrafo (una o varias líneas hasta hueco)
        par = [l]
        i += 1
        while i < n and lineas[i].strip() and not re.match(r"(#|\||- |\d+\. |---)", lineas[i]):
            par.append(lineas[i])
            i += 1
        texto = " ".join(p.strip() for p in par)
        out.append(f"<p>{inline(texto)}</p>")
    return "\n".join(out)


def lista(lineas, i, out):
    """Lista de primer nivel con sublistas y párrafos de continuación."""
    n = len(lineas)
    ordenada = bool(re.match(r"\d+\. ", lineas[i]))
    etq = "ol" if ordenada else "ul"
    out.append(f"<{etq}>")
    while i < n:
        m = re.match(r"(?:- |\d+\. )(.*)", lineas[i])
        if not m:
            break
        partes = [f"{inline(m.group(1))}"]
        i += 1
        sub: list[str] = []
        extra: list[str] = []
        while i < n:
            s = lineas[i]
            if not s.strip():
                # hueco: continúa solo si lo siguiente está sangrado
                j = i + 1
                if j < n and lineas[j].startswith("   "):
                    i += 1
                    continue
                break
            if not s.startswith("   "):
                break
            c = s[3:]
            ms = re.match(r"- (.*)", c)
            if ms:
                sub.append(f"<li>{inline(ms.group(1))}</li>")
            else:
                extra.append(f"<p>{inline(c.strip())}</p>")
            i += 1
        item = "<li>" + partes[0]
        if sub:
            item += "<ul>" + "".join(sub) + "</ul>"
        item += "".join(extra) + "</li>"
        out.append(item)
        # siguiente elemento de lista inmediatamente (o tras hueco)
        if i < n and not lineas[i].strip():
            j = i
            while j < n and not lineas[j].strip():
                j += 1
            if j < n and re.match(r"(?:- |\d+\. )", lineas[j]):
                i = j
    out.append(f"</{etq}>")
    return i


def main() -> int:
    md = ORIGEN.read_text(encoding="utf-8")
    cuerpo = convertir(md)
    DESTINO.parent.mkdir(parents=True, exist_ok=True)
    DESTINO.write_text(PLANTILLA.format(cuerpo=cuerpo), encoding="utf-8", newline="\n")
    print(f"Escrito {DESTINO}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
