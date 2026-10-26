"""Tests del sitio legal. Ejecutar: python -m pytest web/legal"""
import re
import subprocess
import sys
from html.parser import HTMLParser
from pathlib import Path

import pytest

BASE = Path(__file__).resolve().parent
RAIZ = BASE.parents[1]
sys.path.insert(0, str(BASE))
import md2html  # noqa: E402
import rellenar  # noqa: E402

VOID = {"meta", "link", "br", "hr", "img", "input"}
PAGINAS = [BASE / "index.html", BASE / "privacidad" / "index.html"]


class Balance(HTMLParser):
    def __init__(self):
        super().__init__()
        self.pila, self.errores = [], []

    def handle_starttag(self, tag, attrs):
        if tag not in VOID:
            self.pila.append(tag)

    def handle_endtag(self, tag):
        if not self.pila or self.pila[-1] != tag:
            self.errores.append(f"cierre inesperado </{tag}> con pila {self.pila[-3:]}")
        else:
            self.pila.pop()


@pytest.mark.parametrize("ruta", PAGINAS)
def test_html_balanceado(ruta):
    p = Balance()
    p.feed(ruta.read_text(encoding="utf-8"))
    assert not p.errores and not p.pila, (p.errores, p.pila)
    assert "<script" not in ruta.read_text(encoding="utf-8")


def test_privacidad_al_dia_con_el_markdown():
    esperado = md2html.PLANTILLA.format(cuerpo=md2html.convertir(md2html.ORIGEN.read_text(encoding="utf-8")))
    assert (BASE / "privacidad" / "index.html").read_text(encoding="utf-8") == esperado, \
        "Regenera con: python -I web/legal/md2html.py"


def test_fidelidad_apartados_y_sin_notas():
    md = md2html.ORIGEN.read_text(encoding="utf-8")
    h = (BASE / "privacidad" / "index.html").read_text(encoding="utf-8")
    titulos = re.findall(r"^#{2,3} (.*)$", md.split("## Notas para el titular")[0], re.M)
    assert len(titulos) >= 14
    for t in titulos:
        assert t in h
    assert "Notas para el titular" not in h and "no publicar" not in h
    # Cada frase del markdown aparece en el HTML (sin etiquetas)
    plano = re.sub(r"<[^>]+>", "", h)
    plano = plano.replace("&gt;", ">").replace("&lt;", "<").replace("&amp;", "&")
    for linea in md.split("## Notas para el titular")[0].splitlines():
        t = re.sub(r"^(#+ |- |\d+\. |\s+- )", "", linea.strip()).replace("**", "")
        if t and t != "---" and not t.startswith("|"):
            assert t.replace("\n", " ") in plano or t in plano, t


def test_marcadores_presentes_en_fuente():
    h = (BASE / "privacidad" / "index.html").read_text(encoding="utf-8")
    for m in rellenar.MARCADORES:
        assert m in h


VALORES = {
    "[TITULAR]": "Ana & Co", "[CORREO_SOPORTE]": "a@b.es",
    "[FECHA]": "2026-11-01", "[PLAZO_CORREOS]": "un año",
}


def test_rellenar_ok(tmp_path):
    assert rellenar.generar(VALORES, tmp_path / "d") == []
    for rel in rellenar.FICHEROS:
        assert not rellenar.RE_MARCADOR.search((tmp_path / "d" / rel).read_text(encoding="utf-8"))
    assert "Ana &amp; Co" in (tmp_path / "d" / "privacidad" / "index.html").read_text(encoding="utf-8")


def test_rellenar_falla_con_marcadores_sin_rellenar(tmp_path):
    parcial = dict(VALORES, **{"[TITULAR]": ""})
    assert rellenar.generar(parcial, tmp_path / "d") == ["[TITULAR]"]
    r = subprocess.run([sys.executable, "-I", str(BASE / "rellenar.py"), "--titular", "X"],
                       capture_output=True, text=True)
    assert r.returncode == 1 and "[CORREO_SOPORTE]" in r.stderr
