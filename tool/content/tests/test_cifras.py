"""Tests del flag `cifras` (cifras_flag.py y su paso en extract_questions.run)."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(HERE))

import cifras_flag as cf  # noqa: E402
import extract_questions as ex  # noqa: E402
from test_extract import _fake_process_tema  # noqa: E402

REPO = HERE.parents[2]
BANK_DIR = REPO / "app" / "assets" / "content" / "armas" / "GC-2020-11"


def h(stem, options, answer=0):
    return cf.heuristic_cifras(stem, options, answer)


# ------------------------------------------------------------------ heuristica


def test_options_that_only_change_a_figure_are_cifras():
    assert h("¿Cada cuántos años pasan revista las armas de la 2ª categoría?",
             ["Dos años", "Cinco años.", "Todos los años"], 1)
    assert h("¿Qué edad mínima tendrá el peticionario?", ["14 años.", "16 años.", "18 años."], 2)
    # Importes con la coma decimal rara del PDF y con el euro convertido en «_».
    assert h("¿Qué sanción?", ["Multa de 300´51 a 3005´06 euros.", "Multa de hasta 300´51 _."], 1)
    assert h("¿Qué sanción?", ["Multa de hasta 300´51 euros.", "Multa de 30050´61 a 601012´10 euros."], 0)
    assert h("¿Plazo?", ["24 horas", "5 días", "7 días"], 1)
    assert h("¿Cuándo prescriben?", ["A los 3 meses.", "Al año.", "A los 2 años."], 0)
    # Cifras en letra y bloques de años.
    assert h("¿Desde qué edad?", ["Setenta años", "Sesenta y cinco años", "Sesenta y siete años"], 2)
    assert h("¿Qué periodo?", ["1550 a 1840.", "1868 en adelante.", "1845 a 1925."], 1)


def test_how_many_with_bare_number_options_is_cifras():
    assert h("¿Cuántas licencias de armas se podrán poseer?", ["Dependerá del número.", "Una.", "Dos."], 1)
    # Sin «cuánt» ni cifra en las opciones no basta con que haya números sueltos.
    assert not h("¿Qué licencia?", ["La D.", "La E.", "Ninguna."], 1)


def test_figure_in_stem_or_correct_option_counts():
    # Calibre y medidas en el enunciado, con la respuesta en categorías.
    assert h("Un revólver, de 20 centímetros de cañón y del calibre 38, ¿a qué categoría pertenece?",
             ["No existe.", "A la 1ª categoría.", "A la 2ª categoría."], 1)
    assert h("¿Ha de pasar revista si el proyectil tiene una energía superior a 24,2 julios?",
             ["Sí", "No", "Solo si se usa para cazar"], 0)
    # La opción correcta lleva el plazo aunque las otras no.
    assert h("¿Cuándo hay que depositarlas?", ["Al día siguiente.", "Dentro de los 6 meses siguientes.", "Lo decide el interventor."], 1)


def test_categories_and_plain_numbers_are_not_cifras():
    # El número de categoría («3ª.2», «2ª.2») no es una cifra.
    assert not h("¿En qué categoría están las escopetas?", ["Categoría 3ª.1", "Categoría 3ª.2", "Categoría 2ª.2"], 1)
    assert not h("¿Dónde guardaremos las armas de la categoría 2ª.2?", ["En un armero.", "En un armario.", "En cualquier sitio."], 0)
    assert not h("¿En qué categoría están las pistolas?", ["En la 3ª.", "En la 2ª,", "En la 1ª."], 2)
    # El artículo «una» no es un número delante de un sustantivo contable.
    assert not h("¿Qué es?", ["Una escopeta de caza.", "Una pistola.", "Un rifle."], 0)
    # Una cifra solo en el enunciado, con una respuesta que no depende de ella.
    assert not h("Tengo la licencia caducada hace 20 días, ¿qué infracción es?", ["Grave.", "Leve.", "Ninguna."], 0)


def test_heuristic_is_deterministic_and_ignores_case_and_accents():
    a = h("¿CUÁNTOS AÑOS?", ["5 AÑOS", "3 AÑOS"], 0)
    b = h("¿cuántos años?", ["5 años", "3 años"], 0)
    assert a is b is True
    assert cf.quantities("Cinco AÑOS visada cada Tres años") == ["cinco anos", "tres anos"]


# ------------------------------------------------------------------ correcciones


def q(qid, stem, options, answer=0, tema=1):
    return {"id": qid, "tema": tema, "stem": stem, "options": options, "answer": answer}


def test_manual_lists_override_the_heuristic_and_are_reported():
    bank = [
        q("t1-001", "¿Qué edad?", ["14 años", "16 años", "18 años"]),       # heuristica: si
        q("t1-002", "¿Qué licencia?", ["La D.", "La E.", "La F."]),         # heuristica: no
        q("t2-001", "¿Qué edad?", ["14 años", "16 años", "18 años"], tema=2),
    ]
    result, errs, data = cf.compute_flags(bank, {"t1-002": "motivo"}, {"t1-001": "motivo"})
    assert errs == []
    assert result == {"t1-001": False, "t1-002": True, "t2-001": True}
    assert data["heuristica"] == 2 and data["total"] == 2
    assert data["incluidas_a_mano"] == ["t1-002"] and data["excluidas_a_mano"] == ["t1-001"]
    assert data["por_tema"] == [{"tema": "1", "total": 2, "cifras": 1}, {"tema": "2", "total": 1, "cifras": 1}]


def test_unknown_and_conflicting_ids_are_errors():
    bank = [q("t1-001", "a", ["x", "y", "z"])]
    _, errs, _ = cf.compute_flags(bank, {"t9-999": "m", "t1-001": "m"}, {"t1-001": "m", "t8-888": "m"})
    assert any("t9-999" in e for e in errs) and any("t8-888" in e for e in errs)
    assert any("t1-001" in e and "a la vez" in e for e in errs)


def test_load_overrides_validates_the_file(tmp_path):
    ok = tmp_path / "ok.json"
    ok.write_text(json.dumps({"incluir": {"t1-001": "porque si"}, "excluir": {}}), encoding="utf-8")
    assert cf.load_overrides(ok) == ({"t1-001": "porque si"}, {}, [])
    assert cf.load_overrides(None) == ({}, {}, [])

    bad = tmp_path / "bad.json"
    bad.write_text(json.dumps({"incluir": {"t1-001": ""}, "excluir": [], "otro": 1}), encoding="utf-8")
    _, _, errs = cf.load_overrides(bad)
    assert len(errs) == 3

    broken = tmp_path / "broken.json"
    broken.write_text("{no es json", encoding="utf-8")
    assert cf.load_overrides(broken)[2]
    assert cf.load_overrides(tmp_path / "missing.json")[2]


def test_apply_flags_appends_without_duplicating():
    qlist = [{"id": "a", "flags": ["sin_articulo"]}, {"id": "b", "flags": ["cifras"]}, {"id": "c", "flags": []}]
    cf.apply_flags(qlist, {"a": True, "b": True, "c": False})
    assert qlist == [{"id": "a", "flags": ["sin_articulo", "cifras"]},
                     {"id": "b", "flags": ["cifras"]}, {"id": "c", "flags": []}]


# ------------------------------------------------------------------ pipeline


@pytest.fixture
def fake_bank(monkeypatch):
    monkeypatch.setattr(ex, "process_tema", _fake_process_tema(bad_answer=False))


def run_fake(tmp_path, cifras_path, name="out"):
    out = tmp_path / name
    rep = tmp_path / f"rep-{name}" / "TEST"
    rc = ex.run(tmp_path, "TEST", "2026-10-18", out, rep, None, cifras_path)
    return rc, out, rep


def test_pipeline_only_adds_the_flag_and_changes_the_sha(fake_bank, tmp_path):
    rc0, out0, _ = run_fake(tmp_path, None, "none")
    path = tmp_path / "cifras.json"
    path.write_text(json.dumps({"incluir": {"t2-001": "m"}, "excluir": {}}), encoding="utf-8")
    rc1, out1, rep1 = run_fake(tmp_path, path, "with")
    assert rc0 == rc1 == 0
    before = json.loads((out0 / "questions.json").read_text(encoding="utf-8"))
    after = json.loads((out1 / "questions.json").read_text(encoding="utf-8"))
    flagged = [x["id"] for x in after if "cifras" in x["flags"]]
    assert flagged == ["t2-001"]
    for a, b in zip(before, after):
        b = dict(b, flags=[f for f in b["flags"] if f != "cifras"])
        assert a == b  # enunciado, opciones y respuesta oficiales intactos
    m0 = json.loads((out0 / "manifest.json").read_text(encoding="utf-8"))
    m1 = json.loads((out1 / "manifest.json").read_text(encoding="utf-8"))
    assert m0["questions_sha256"] != m1["questions_sha256"]
    assert {k: v for k, v in m0.items() if k != "questions_sha256"} == \
           {k: v for k, v in m1.items() if k != "questions_sha256"}
    rep = json.loads(Path(str(rep1) + ".json").read_text(encoding="utf-8"))
    check = next(c for c in rep["checks"] if c["id"] == "cifras")
    assert check["level"] == "OK" and check["data"]["total"] == 1
    assert "Cifras y plazos" in Path(str(rep1) + ".md").read_text(encoding="utf-8")


def test_pipeline_is_deterministic(fake_bank, tmp_path):
    path = tmp_path / "cifras.json"
    path.write_text(json.dumps({"incluir": {"t3-002": "m"}}), encoding="utf-8")
    _, a, _ = run_fake(tmp_path, path, "a")
    _, b, _ = run_fake(tmp_path, path, "b")
    assert (a / "questions.json").read_bytes() == (b / "questions.json").read_bytes()
    assert (a / "manifest.json").read_bytes() == (b / "manifest.json").read_bytes()


def test_pipeline_error_in_the_corrections_writes_no_bank(fake_bank, tmp_path):
    path = tmp_path / "cifras.json"
    path.write_text(json.dumps({"incluir": {"t9-999": "m"}}), encoding="utf-8")
    rc, out, rep = run_fake(tmp_path, path)
    assert rc == 1 and not out.exists()
    report = json.loads(Path(str(rep) + ".json").read_text(encoding="utf-8"))
    assert any(c["id"] == "cifras" and c["level"] == "ERROR" for c in report["checks"])


# ------------------------------------------------------------------ banco publicado


def test_committed_bank_flags_match_the_heuristic_plus_the_manual_lists():
    questions = json.loads((BANK_DIR / "questions.json").read_text(encoding="utf-8"))
    include, exclude, errs = cf.load_overrides(cf.default_cifras_path("GC-2020-11"))
    assert errs == []
    expected, errs, data = cf.compute_flags(questions, include, exclude)
    assert errs == []
    actual = {x["id"]: "cifras" in x["flags"] for x in questions}
    assert actual == expected
    assert data["total"] >= 60
    # Cada correccion manual dice por que: sin motivos vacios (load_overrides ya lo exige).
    assert all(include.values()) and all(exclude.values())


def test_committed_manifest_sha_matches_questions_json():
    import hashlib

    manifest = json.loads((BANK_DIR / "manifest.json").read_text(encoding="utf-8"))
    digest = hashlib.sha256((BANK_DIR / "questions.json").read_bytes()).hexdigest()
    assert manifest["questions_sha256"] == digest
