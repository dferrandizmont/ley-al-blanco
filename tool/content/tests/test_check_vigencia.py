"""Tests de tool/content/check_vigencia.py sin red (descargas simuladas)."""
from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import check_vigencia as v  # noqa: E402

PROGRAMA_HTML = """
<html><body>
<a href="https://web.guardiacivil.es/export/sites/guardiaCivil/documentos/iarmas/temarios/tema1_es.pdf">tema 1</a>
<a href='../temarios/tema2_es.pdf#page=2'>tema 2</a>
<a href="/export/sites/guardiaCivil/documentos/iarmas/temarios/tema1_es.pdf">repetido</a>
<a href="https://www.boe.es/buscar/doc.php?id=BOE-A-1998-27988#a1">Resolucion</a>
<a href="https://www.boe.es/buscar/doc.php?id=BOE-A-1998-27988">repetida</a>
<a href="/es/inicio/index.html">inicio</a>
</body></html>
"""

CONSULTA_HTML = """
<html><body>
<nav><ul><li><a href="/opencms/es/inicio/">Inicio</a></li></ul></nav>
<div class="text"><ul>
<li>Consulta p&uacute;blica previa del Proyecto de Real Decreto por el que se modifica el
Reglamento de Armas.<br />
<ul><li><a href="x.pdf">Texto del documento</a></li></ul></li>
<li>Consulta p&uacute;blica previa del proyecto de Orden Ministerial por la que se aprueban
las instrucciones para la aplicaci&oacute;n en el Cuerpo de la Guardia Civil del Reglamento de
Armas.</li>
<li>Consulta p&uacute;blica previa del proyecto de Real Decreto por el que se transpone la
Directiva (UE) 2024/325 en lo que respecta a la profundidad m&iacute;nima de los marcados en
las <strong>ARMAS</strong> de fuego.</li>
<li>Consulta p&uacute;blica previa del proyecto de modificación del Reglamento General de
Conductores.</li>
</ul></div></body></html>
"""

AUDIENCIA_HTML = """
<html><body><ul>
<li>Audiencia e informaci&oacute;n p&uacute;blica del proyecto de Real Decreto por el que se
modifica el Reglamento de Armas.</li>
<li style="list-style-type: none;"><ul>
<li>Fecha de publicaci&oacute;n: <strong>20 de octubre de 2026</strong></li>
<li><strong>Nota aclaratoria:</strong> esta publicaci&oacute;n no tiene relaci&oacute;n con la
consulta previa del Reglamento de Armas.</li>
</ul></li>
</ul></body></html>
"""


def test_extract_programa_links_sorted_unique_and_without_fragments():
    links = v.extract_programa_links(PROGRAMA_HTML, "https://web.guardiacivil.es/base/index.html")
    assert links["pdfs"] == [
        "https://web.guardiacivil.es/export/sites/guardiaCivil/documentos/iarmas/temarios/tema1_es.pdf",
        "https://web.guardiacivil.es/temarios/tema2_es.pdf",
    ]
    assert links["boe"] == ["https://www.boe.es/buscar/doc.php?id=BOE-A-1998-27988"]


def test_extract_interior_fragments_takes_titles_and_skips_notes():
    consulta = v.extract_interior_fragments(CONSULTA_HTML)
    assert len(consulta) == 3
    assert all("Armas" in title or "ARMAS" in title for title in consulta)
    assert any(title.endswith("Reglamento de Armas.") for title in consulta)
    assert not any(title.startswith("Fecha") for title in consulta)

    audiencia = v.extract_interior_fragments(AUDIENCIA_HTML)
    assert audiencia == [
        "Audiencia e información pública del proyecto de Real Decreto por el que se modifica el Reglamento de Armas."
    ]


def test_parse_boe_ids_from_real_leeme():
    text = (HERE.parent / "boe" / "LEEME.md").read_text(encoding="utf-8")
    ids = v.parse_boe_ids(text)
    assert len(ids) == 15
    assert len(ids) == len(set(ids))
    assert ids[0] == "BOE-A-1993-6202"
    assert "BOE-A-2025-387" in ids


def test_days_to_expiry():
    now = datetime(2026, 11, 5, 12, 0, tzinfo=timezone.utc)
    assert v.days_to_expiry(datetime(2027, 3, 10, 7, 39, tzinfo=timezone.utc), now) == 124
    assert v.days_to_expiry(datetime(2026, 11, 20, tzinfo=timezone.utc), now) == 14
    assert v.days_to_expiry(datetime(2026, 11, 1, tzinfo=timezone.utc), now) == -5


def test_diff_sets_reports_new_and_missing():
    differences = v.diff_sets("PDF", ["a", "b", "c"], ["b", "d"])
    assert differences == ["PDF: nuevo: a", "PDF: nuevo: c", "PDF: ya no aparece: d"]


def test_check_programa_detects_change(monkeypatch):
    baseline = v.extract_programa_links(PROGRAMA_HTML)
    monkeypatch.setattr(v, "fetch_text", lambda url: PROGRAMA_HTML)
    result = v.check_programa({"gc_programa": baseline})
    assert result.differences == [] and result.errors == []
    assert result.status == "OK"

    changed = PROGRAMA_HTML.replace("tema2_es.pdf", "tema8_es.pdf")
    monkeypatch.setattr(v, "fetch_text", lambda url: changed)
    result = v.check_programa({"gc_programa": baseline})
    assert result.status == "CAMBIO"
    assert any("nuevo" in item and "tema8" in item for item in result.differences)
    assert any("ya no aparece" in item and "tema2" in item for item in result.differences)


def test_check_programa_network_error(monkeypatch):
    def fail(_url):
        raise OSError("403 Forbidden")

    monkeypatch.setattr(v, "fetch_text", fail)
    result = v.check_programa({"gc_programa": {"pdfs": [], "boe": []}})
    assert result.differences == []
    assert result.status == "ERROR"
    assert "403" in result.errors[0]


def _write_boe_raw(tmp_path: Path, fecha: str, texto: bytes) -> Path:
    raw = tmp_path / "raw"
    raw.mkdir()
    meta = (
        '<?xml version="1.0" encoding="utf-8"?>'
        f"<response><data><metadatos><fecha_actualizacion>{fecha}"
        "</fecha_actualizacion></metadatos></data></response>"
    ).encode()
    (raw / "BOE-A-2026-1.metadatos.xml").write_bytes(meta)
    (raw / "BOE-A-2026-1.texto.xml").write_bytes(texto)
    return raw


def test_check_boe_ok_and_changed(monkeypatch, tmp_path):
    fecha = "20251217T205107Z"
    raw = _write_boe_raw(tmp_path, fecha, b"texto consolidado")
    meta = (
        '<?xml version="1.0" encoding="utf-8"?>'
        f"<response><data><metadatos><fecha_actualizacion>{fecha}"
        "</fecha_actualizacion></metadatos></data></response>"
    ).encode()

    def fake_fetch(url, accept=None):
        return (200, b"texto consolidado") if url.endswith("/texto") else (200, meta)

    monkeypatch.setattr(v, "fetch_bytes", fake_fetch)
    result = v.check_boe(["BOE-A-2026-1"], raw)
    assert result.differences == [] and result.errors == []

    def fake_fetch_changed(url, accept=None):
        return (200, b"texto nuevo") if url.endswith("/texto") else (200, meta)

    monkeypatch.setattr(v, "fetch_bytes", fake_fetch_changed)
    result = v.check_boe(["BOE-A-2026-1"], raw)
    assert result.status == "CAMBIO"
    assert any("sha256" in item for item in result.differences)


def test_check_boe_network_error_does_not_raise(monkeypatch, tmp_path):
    raw = _write_boe_raw(tmp_path, "20251217T205107Z", b"texto")

    def fail(_url, accept=None):
        raise OSError("timeout")

    monkeypatch.setattr(v, "fetch_bytes", fail)
    result = v.check_boe(["BOE-A-2026-1"], raw)
    assert result.status == "ERROR"
    assert len(result.errors) == 2  # metadatos y texto


def test_check_interior_new_and_missing(monkeypatch):
    pages = {
        v.INTERIOR_URLS["consulta"]: CONSULTA_HTML,
        v.INTERIOR_URLS["audiencia"]: AUDIENCIA_HTML,
    }
    monkeypatch.setattr(v, "fetch_text", lambda url: pages[url])
    baseline = {
        "interior": {
            "consulta": [
                "Consulta pública previa del proyecto de Ley de caza."
            ],
            "audiencia": [
                "Audiencia e información pública del proyecto de Real Decreto por el que se modifica el Reglamento de Armas."
            ],
        }
    }
    result = v.check_interior(baseline)
    assert result.status == "CAMBIO"
    assert len(result.differences) == 3  # las tres de consulta son nuevas
    assert any("Ley de caza" in item and "ya no aparece" in item for item in result.notes)


def test_check_dominio_warns_under_60_days(monkeypatch):
    now = datetime(2026, 11, 5, tzinfo=timezone.utc)
    payload = json.dumps(
        {"events": [{"eventAction": "expiration", "eventDate": "2027-03-10T07:39:47Z"}]}
    ).encode()
    monkeypatch.setattr(v, "fetch_bytes", lambda url: (200, payload))
    result = v.check_dominio(now)
    assert result.status == "OK"
    assert result.notes == ["caduca el 2027-03-10 (faltan 125 dias)"]

    payload = json.dumps(
        {"events": [{"eventAction": "expiration", "eventDate": "2026-12-01T00:00:00Z"}]}
    ).encode()
    monkeypatch.setattr(v, "fetch_bytes", lambda url: (200, payload))
    result = v.check_dominio(now)
    assert result.status == "CAMBIO"


def test_update_baseline_keeps_old_values_when_downloads_fail(monkeypatch, tmp_path):
    baseline = {
        "gc_programa": {"pdfs": ["p.pdf"], "boe": ["https://www.boe.es/x"]},
        "interior": {"consulta": ["c"], "audiencia": ["a"]},
    }

    def fail(_url):
        raise OSError("403 Forbidden")

    monkeypatch.setattr(v, "fetch_text", fail)
    out = tmp_path / "baseline.json"
    updated = v.update_baseline(baseline, out)
    assert updated == baseline
    assert json.loads(out.read_text(encoding="utf-8")) == baseline


def test_main_exit_codes(monkeypatch):
    monkeypatch.setattr(v, "load_baseline", lambda: v.empty_baseline())

    monkeypatch.setattr(v, "run_checks", lambda names, baseline: [v.CheckResult("web")])
    assert v.main(["--only", "web"]) == 0

    monkeypatch.setattr(
        v,
        "run_checks",
        lambda names, baseline: [v.CheckResult("programa", ["cambio"])],
    )
    assert v.main(["--only", "programa"]) == 1

    monkeypatch.setattr(
        v,
        "run_checks",
        lambda names, baseline: [v.CheckResult("interior", [], ["403"])],
    )
    assert v.main(["--only", "interior"]) == 2

    monkeypatch.setattr(
        v,
        "run_checks",
        lambda names, baseline: [
            v.CheckResult("boe", ["cambio"]),
            v.CheckResult("interior", [], ["403"]),
        ],
    )
    assert v.main(["--only", "boe,interior"]) == 1


def test_main_writes_report_and_checklist(monkeypatch, tmp_path):
    monkeypatch.setattr(v, "load_baseline", lambda: v.empty_baseline())
    monkeypatch.setattr(v, "run_checks", lambda names, baseline: [v.CheckResult("web")])
    out = tmp_path / "vigencia.md"
    assert v.main(["--only", "web", "--checklist", "--out", str(out)]) == 0
    report = out.read_text(encoding="utf-8")
    assert report.startswith("# Vigencia de fuentes — ")
    assert "Revision manual trimestral" in report
    assert "flutter pub outdated" in report


def test_fetch_bytes_retries_with_curl_on_403(monkeypatch):
    def blocked(request, timeout):
        raise v.urllib.error.HTTPError(request.full_url, 403, "Forbidden", None, None)

    class Completed:
        returncode = 0
        stdout = b"<html>ok</html>\n__HTTP_STATUS__:200"
        stderr = b""

    calls = []
    monkeypatch.setattr(v.urllib.request, "urlopen", blocked)
    monkeypatch.setattr(v.shutil, "which", lambda name: "/usr/bin/curl")
    monkeypatch.setattr(v.subprocess, "run", lambda cmd, **kw: calls.append(cmd) or Completed())
    assert v.fetch_bytes("https://example.test/") == (200, b"<html>ok</html>")
    assert calls and calls[0][0] == "/usr/bin/curl"


def test_fetch_bytes_does_not_retry_other_errors(monkeypatch):
    def missing(request, timeout):
        raise v.urllib.error.HTTPError(request.full_url, 404, "Not Found", None, None)

    monkeypatch.setattr(v.urllib.request, "urlopen", missing)
    monkeypatch.setattr(v.shutil, "which", lambda name: "/usr/bin/curl")
    with pytest.raises(v.urllib.error.HTTPError):
        v.fetch_bytes("https://example.test/")
