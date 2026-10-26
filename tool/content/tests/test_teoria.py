"""Tests de build_teoria.py (validacion y empaquetado de los resumenes de teoria)."""
from __future__ import annotations

import copy
import json
import sys
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import build_teoria as bt  # noqa: E402
import extract_questions as ex  # noqa: E402

KNOWN = {"t1-001", "t1-002", "t2-001", "t2-010"}


def section(**kw):
    base = {
        "title": "Una seccion",
        "collapsed": False,
        "blocks": [{"type": "p", "text": "Parrafo corto."}],
        "articles": ["Art. 3 RD 137/1993"],
    }
    base.update(kw)
    return base


def three(**kw):
    """Tres secciones con titulos distintos (el titulo no puede repetirse)."""
    return [section(title=f"S{i}", **kw) for i in range(3)]


def doc(doc_id="t2", **kw):
    base = {
        "id": doc_id,
        "tema": None if doc_id in bt.NULL_TEMA_IDS else int(doc_id[1:]),
        "title": "Titulo",
        "summary": "Resumen.",
        "sections": [section(title=f"S{i}") for i in range(3)],
        "related_questions": ["t2-001"],
        "confidence": "alta",
        "sources": [{"norma": "BOE-A-1993-6202", "ref": "art. 3"}],
        "review_notes": "interno",
        "reviewed": False,
    }
    base.update(kw)
    return base


def check(d, doc_id="t2"):
    return bt.validate_doc(f"{doc_id}.json", d, doc_id, KNOWN)


def errors_of(d, doc_id="t2"):
    out, errs = check(d, doc_id)
    assert out is None
    assert errs
    return "\n".join(errs)


def with_block(block, **sec_kw):
    return doc(sections=three(blocks=[block], **sec_kw))


# ------------------------------------------------------------------ validacion


def test_valid_doc_drops_internal_fields():
    out, errs = check(doc())
    assert errs == []
    assert set(out) == {"id", "tema", "title", "summary", "sections", "related_questions"}
    assert set(out["sections"][0]) == {"title", "collapsed", "blocks", "articles"}


def test_every_block_type_is_accepted():
    blocks = [
        {"type": "p", "text": "x" * 400},
        {"type": "list", "items": ["a", "b"]},
        {"type": "table", "caption": "Tabla", "headers": ["A", "B"], "rows": [["1", "2"], ["3", "4"]]},
        {"type": "key", "text": "Lo que mas cae"},
        {"type": "notice", "text": "Ojo"},
        {"type": "diagram", "kind": "galeria_tiro", "caption": "Galeria"},
        {"type": "diagram", "kind": "zona_segura"},
        {"type": "diagram", "kind": "secuencia", "items": ["Uno", "Dos"]},
    ]
    out, errs = check(doc(sections=three(blocks=blocks)))
    assert errs == []
    assert out["sections"][0]["blocks"] == blocks


def test_collapsed_defaults_to_false():
    s = section()
    del s["collapsed"]
    out, errs = check(doc(sections=[{**s, "title": f"S{i}"} for i in range(3)]))
    assert errs == []
    assert out["sections"][0]["collapsed"] is False


def test_practica_has_null_tema():
    out, errs = check(doc("practica"), "practica")
    assert errs == []
    assert out["tema"] is None
    assert "debe ser null" in errors_of(doc("practica", tema=3), "practica")


def test_id_and_tema_must_match_the_file():
    assert "debe ser 't2'" in errors_of(doc("t3", sections=doc()["sections"]), "t2")
    assert "debe ser 2" in errors_of(doc(tema=3))


@pytest.mark.parametrize("n", [0, 1, 2, 7, 8])
def test_section_count_bounds(n):
    d = doc(sections=[section(title=f"S{i}") for i in range(n)])
    if 3 <= n <= 6:
        assert check(d)[1] == []
    else:
        assert "secciones" in errors_of(d)


def test_section_titles_must_be_unique_within_a_document():
    d = doc(sections=[section(title="Igual"), section(title="Otra"), section(title="Igual")])
    msg = errors_of(d)
    assert "titulo de seccion repetido" in msg and "Igual" in msg and "seccion 3" in msg


def test_section_titles_are_compared_ignoring_case_accents_and_spaces():
    d = doc(sections=[section(title="Guía  de pertenencia"), section(title="otra"),
                      section(title="guia DE pertenencia")])
    assert "titulo de seccion repetido" in errors_of(d)


def test_the_same_title_in_two_documents_is_fine():
    assert check(doc(sections=three()))[1] == []
    assert check(doc("t3", sections=three()), "t3")[1] == []


def test_paragraph_length_limit():
    assert "401 caracteres" in errors_of(with_block({"type": "p", "text": "x" * 401}))


def test_unknown_block_type_and_fields():
    assert "no valido" in errors_of(with_block({"type": "image", "src": "a.png"}))
    assert "campo desconocido" in errors_of(with_block({"type": "p", "text": "a", "color": "red"}))


def test_long_header_is_reported_once_not_once_per_row():
    long_header = "h" * 61
    block = {"type": "table", "headers": ["A", long_header],
             "rows": [["1", "2"], ["3", "4"], ["5", "6"]]}
    # with_block repite la seccion 3 veces; dentro de cada una, un error por cabecera.
    msgs = [e for e in check(with_block(block))[1] if "cabecera" in e]
    assert len(msgs) == 3
    one = [e for e in check(doc(sections=[section(blocks=[block])] + [section()] * 2))[1]
           if "cabecera" in e]
    assert len(one) == 1 and "maximo 60" in one[0]


@pytest.mark.parametrize("headers", [["A"], ["A", "B", "C", "D", "E"]])
def test_table_column_count(headers):
    block = {"type": "table", "headers": headers, "rows": [["x"] * len(headers)]}
    assert "columnas" in errors_of(with_block(block))


def test_table_rows_must_be_rectangular_and_cells_short():
    ragged = {"type": "table", "headers": ["A", "B"], "rows": [["1", "2"], ["3"]]}
    assert "fila 2 tiene 1 celdas" in errors_of(with_block(ragged))
    long_cell = {"type": "table", "headers": ["A", "B"], "rows": [["1", "x" * 61]]}
    assert "maximo 60" in errors_of(with_block(long_cell))
    ok = {"type": "table", "headers": ["A", "B"], "rows": [["1", "x" * 60]]}
    assert check(with_block(ok))[1] == []


def test_diagram_rules():
    assert "no valido" in errors_of(with_block({"type": "diagram", "kind": "arma"}))
    assert "requiere `items`" in errors_of(with_block({"type": "diagram", "kind": "secuencia"}))
    assert "solo `secuencia`" in errors_of(
        with_block({"type": "diagram", "kind": "zona_segura", "items": ["a"]}))


@pytest.mark.parametrize("article", ["", "art 3", "Articulo 3", "RD 137/1993"])
def test_bad_article_format(article):
    assert "formato" in errors_of(doc(sections=three(articles=[article])))


@pytest.mark.parametrize("article", ["Art. 3 RD 137/1993", "Arts. 3 y 4 RD 137/1993", "Anexo II Resolucion 1998"])
def test_good_article_format(article):
    assert check(doc(sections=three(articles=[article])))[1] == []


def test_empty_articles_need_review_notes():
    assert "review_notes" in errors_of(doc(sections=three(articles=[]), review_notes=""))
    assert check(doc(sections=three(articles=[]), review_notes="Tecnico, sin articulo"))[1] == []


def test_related_questions_must_exist_and_be_unique():
    assert "t2-999" in errors_of(doc(related_questions=["t2-999"]))
    assert "formato incorrecto" in errors_of(doc(related_questions=["abc"]))
    assert "repetida" in errors_of(doc(related_questions=["t2-001", "t2-001"]))
    assert check(doc(related_questions=[]))[1] == []


def test_confidence_and_unknown_and_missing_fields():
    assert "confidence" in errors_of(doc(confidence="muy alta"))
    assert "campo desconocido" in errors_of(doc(extra=1))
    d = doc()
    del d["summary"]
    assert "falta el campo obligatorio 'summary'" in errors_of(d)


def test_errors_are_all_reported():
    d = doc(confidence="x", related_questions=["t9-001"])
    d["sections"] = three(blocks=[{"type": "p", "text": "x" * 500}])
    _, errs = check(d)
    assert len(errs) >= 3


# ------------------------------------------------------------------ empaquetado


def make_env(tmp_path, docs=None):
    """src con los 8 documentos validos (o `docs`), out con questions.json y manifest.json."""
    src, out = tmp_path / "src", tmp_path / "out"
    src.mkdir()
    out.mkdir()
    for doc_id in bt.DOC_IDS:
        d = (docs or {}).get(doc_id, doc(doc_id))
        (src / f"{doc_id}.json").write_text(
            d if isinstance(d, str) else json.dumps(d), encoding="utf-8")
    questions = [{"id": i} for i in sorted(KNOWN)]
    (out / "questions.json").write_bytes(ex.dumps(questions))
    manifest = {"edition": "TEST", "question_count": 4, "questions_sha256": "abc", "sources": [{"tema": 1}]}
    (out / "manifest.json").write_bytes(ex.dumps(manifest))
    return src, out, manifest


def test_build_writes_asset_and_manifest_sha(tmp_path):
    src, out, manifest = make_env(tmp_path)
    q_before = (out / "questions.json").read_bytes()
    assert bt.build(src, "TEST", out) == 0
    data = (out / "teoria.json").read_bytes()
    assert b"\r" not in data and data.endswith(b"\n")
    parsed = json.loads(data)
    assert parsed["edition"] == "TEST"
    assert [d["id"] for d in parsed["docs"]] == ["t1", "t2", "t3", "t4", "t5", "t6", "t7", "practica"]
    assert "confidence" not in json.dumps(parsed) and "review_notes" not in json.dumps(parsed)
    new_manifest = json.loads((out / "manifest.json").read_text(encoding="utf-8"))
    assert new_manifest["teoria_sha256"] == ex.sha256_bytes(data)
    assert {k: v for k, v in new_manifest.items() if k != "teoria_sha256"} == manifest
    assert list(new_manifest)[:3] == ["edition", "question_count", "questions_sha256"]
    assert list(new_manifest).index("teoria_sha256") == list(new_manifest).index("questions_sha256") + 1
    assert (out / "questions.json").read_bytes() == q_before


@pytest.mark.parametrize("text, expected", [
    ("De 30.001 a 600.000 €", "De 30.001 a 600.000\u00a0€"),
    ("Dura 5 años y 3 meses", "Dura 5\u00a0años y 3\u00a0meses"),
    ("A 25 m de la diana", "A 25\u00a0m de la diana"),
    ("Hasta 24,2 julios y 100 %", "Hasta 24,2\u00a0julios y 100\u00a0%"),
    # Sin cifra delante, o una palabra que solo empieza por la unidad, no cambia.
    ("Cuesta €", "Cuesta €"),
    ("Art. 3 RD 137/1993; 2 mesas; 7 metros", "Art. 3 RD 137/1993; 2 mesas; 7 metros"),
    # Idempotente.
    ("5\u00a0años", "5\u00a0años"),
])
def test_units_stay_with_their_number(text, expected):
    assert bt.keep_units_with_numbers(text) == expected
    assert bt.keep_units_with_numbers(bt.keep_units_with_numbers(text)) == expected


def test_nbsp_is_applied_to_every_public_text_but_not_to_keys(tmp_path):
    table = {"type": "table", "caption": "Multas de 1 año",
             "headers": ["Infracción", "Importe"],
             "rows": [["Grave", "De 30.001 a 600.000 €"], ["Leve", "100 €"]]}
    d = doc(sections=three(blocks=[table, {"type": "list", "items": ["3 meses"]}]),
            summary="Plazo de 5 años.")
    out, errs = check(d)
    assert errs == []
    block = out["sections"][0]["blocks"][0]
    assert block["rows"] == [["Grave", "De 30.001 a 600.000\u00a0€"], ["Leve", "100\u00a0€"]]
    assert block["caption"] == "Multas de 1\u00a0año"
    assert out["sections"][0]["blocks"][1]["items"] == ["3\u00a0meses"]
    assert out["summary"] == "Plazo de 5\u00a0años."
    assert set(out) == {"id", "tema", "title", "summary", "sections", "related_questions"}


def test_build_is_deterministic_and_idempotent(tmp_path):
    src, out, _ = make_env(tmp_path)
    assert bt.build(src, "TEST", out) == 0
    first = ((out / "teoria.json").read_bytes(), (out / "manifest.json").read_bytes())
    assert bt.build(src, "TEST", out) == 0
    assert first == ((out / "teoria.json").read_bytes(), (out / "manifest.json").read_bytes())


def test_build_with_errors_writes_nothing(tmp_path, capsys):
    bad = doc("t3", confidence="nope")
    src, out, _ = make_env(tmp_path, {"t3": bad})
    manifest_before = (out / "manifest.json").read_bytes()
    assert bt.build(src, "TEST", out) == 1
    assert "confidence" in capsys.readouterr().err
    assert not (out / "teoria.json").exists()
    assert (out / "manifest.json").read_bytes() == manifest_before


def test_build_invalid_json(tmp_path):
    src, out, _ = make_env(tmp_path, {"t4": "{no es json"})
    assert bt.build(src, "TEST", out) == 1
    assert not (out / "teoria.json").exists()


def test_missing_documents_fail_unless_partial(tmp_path, capsys):
    src, out, _ = make_env(tmp_path)
    (src / "t5.json").unlink()
    assert bt.build(src, "TEST", out) == 2
    assert "t5.json" in capsys.readouterr().err
    assert not (out / "teoria.json").exists()
    assert bt.build(src, "TEST", out, partial=True) == 0
    ids = [d["id"] for d in json.loads((out / "teoria.json").read_text(encoding="utf-8"))["docs"]]
    assert "t5" not in ids and ids[0] == "t1" and ids[-1] == "practica"


def test_missing_questions_or_manifest(tmp_path, capsys):
    src, out, _ = make_env(tmp_path)
    (out / "questions.json").unlink()
    assert bt.build(src, "TEST", out) == 2
    assert "extract_questions.py" in capsys.readouterr().err


def test_edition_must_match_the_manifest(tmp_path, capsys):
    src, out, _ = make_env(tmp_path)
    manifest_before = (out / "manifest.json").read_bytes()
    assert bt.build(src, "OTRA", out) == 2
    err = capsys.readouterr().err
    assert "OTRA" in err and "TEST" in err and "--edition" in err
    assert not (out / "teoria.json").exists()
    assert (out / "manifest.json").read_bytes() == manifest_before
    assert bt.main(["--edition", "OTRA", "--src", str(src), "--out", str(out)]) == 2


def test_build_reports_reviewed_count_but_does_not_require_it(tmp_path, capsys):
    src, out, _ = make_env(tmp_path)
    assert bt.build(src, "TEST", out) == 0
    assert "0/8 documentos revisados" in capsys.readouterr().out
    docs = {"t1": doc("t1", reviewed=True), "practica": doc("practica", reviewed=True)}
    (tmp_path / "otro").mkdir()
    src2, out2, _ = make_env(tmp_path / "otro", docs)
    assert bt.build(src2, "TEST", out2) == 0
    assert "2/8 documentos revisados" in capsys.readouterr().out


def test_cli_exit_codes(tmp_path):
    src, out, _ = make_env(tmp_path)
    assert bt.main(["--edition", "TEST", "--src", str(src), "--out", str(out)]) == 0
    assert bt.main(["--edition", "TEST", "--src", str(tmp_path / "nope"), "--out", str(out)]) == 2


def test_input_docs_are_not_mutated(tmp_path):
    d = doc()
    snapshot = copy.deepcopy(d)
    check(d)
    assert d == snapshot


# ------------------------------------------------------------------ aem y glosario


def term(i, **kw):
    base = {"term": f"Termino {i:03d}", "text": f"Definicion del termino {i}."}
    base.update(kw)
    return base


def glossary(n_terms=40, n_sections=4, **kw):
    """Glosario valido: `n_terms` terminos repartidos en `n_sections` secciones."""
    per = [[] for _ in range(n_sections)]
    for i in range(n_terms):
        per[i % n_sections].append(term(i))
    sections = [section(title=f"Grupo {si}", blocks=[{"type": "terms", "items": items}])
                for si, items in enumerate(per) if items]
    return doc("glosario", sections=sections, related_questions=[], **kw)


def test_aem_follows_topic_rules_with_null_tema():
    out, errs = check(doc("aem"), "aem")
    assert errs == [] and out["tema"] is None and out["id"] == "aem"
    assert "debe ser null en aem" in errors_of(doc("aem", tema=2), "aem")
    assert "secciones (debe haber 3 a 6)" in errors_of(
        doc("aem", sections=[section(title=f"S{i}") for i in range(7)]), "aem")


def test_glosario_valid_and_public_shape():
    d = glossary(40)
    d["sections"][0]["blocks"][0]["items"][0]["article"] = "Art. 88 RD 137/1993"
    out, errs = check(d, "glosario")
    assert errs == []
    assert out["tema"] is None and out["related_questions"] == []
    first = out["sections"][0]["blocks"][0]
    assert first["type"] == "terms"
    assert first["items"][0]["article"] == "Art. 88 RD 137/1993"
    assert set(first["items"][1]) == {"term", "text"}


@pytest.mark.parametrize("n,ok", [(39, False), (40, True), (120, True), (121, False)])
def test_glosario_term_count_bounds(n, ok):
    errs = check(glossary(n), "glosario")[1]
    if ok:
        assert errs == []
    else:
        assert f"{n} terminos (debe haber 40 a 120)" in chr(10).join(errs)


@pytest.mark.parametrize("n,ok", [(3, False), (4, True), (8, True), (9, False)])
def test_glosario_section_bounds_differ_from_topics(n, ok):
    d = glossary(40, n_sections=n)
    errs = check(d, "glosario")[1]
    if ok:
        assert errs == []
    else:
        assert f"{n} secciones (debe haber 4 a 8)" in chr(10).join(errs)


def test_glosario_has_no_prose_limit_but_topics_keep_theirs():
    d = glossary(40)
    d["sections"][0]["blocks"].append({"type": "p", "text": "x" * 400})
    assert check(d, "glosario")[1] == []
    assert "terms" in bt.BLOCK_TYPES


@pytest.mark.parametrize("bad,msg", [
    ({"term": "", "text": "x"}, "falta `term`"),
    ({"term": "x" * 61, "text": "x"}, "maximo 60"),
    ({"term": "a", "text": ""}, "falta `text`"),
    ({"term": "a", "text": "x" * 241}, "maximo 240"),
    ({"term": "a", "text": "x", "article": "art 3"}, "formato"),
    ({"term": "a", "text": "x", "color": "red"}, "campo desconocido"),
])
def test_term_item_validation(bad, msg):
    d = glossary(40)
    d["sections"][0]["blocks"][0]["items"][0] = bad
    assert msg in errors_of(d, "glosario")


def test_term_limits_are_inclusive():
    d = glossary(40)
    d["sections"][0]["blocks"][0]["items"][0] = {"term": "x" * 60, "text": "y" * 240}
    assert check(d, "glosario")[1] == []


def test_terms_block_must_be_non_empty_list_of_objects():
    d = glossary(40)
    d["sections"][0]["blocks"][0]["items"] = []
    assert "lista no vacia de terminos" in errors_of(d, "glosario")
    d["sections"][0]["blocks"][0]["items"] = ["texto"]
    assert "debe ser un objeto" in errors_of(d, "glosario")


def test_duplicate_terms_rejected_across_sections_ignoring_case_and_accents():
    d = glossary(40)
    d["sections"][0]["blocks"][0]["items"][0] = {"term": "Guía de pertenencia", "text": "a"}
    d["sections"][1]["blocks"][0]["items"][0] = {"term": "  guia DE   pertenencia ", "text": "b"}
    msg = errors_of(d, "glosario")
    assert "repetido" in msg and "Guía de pertenencia" in msg


def test_glosario_term_errors_are_all_reported_with_doc_level_checks():
    d = glossary(40)
    d["sections"][0]["blocks"][0]["items"][0] = {"term": "", "text": ""}
    assert len(check(d, "glosario")[1]) >= 2


def test_build_without_optional_docs_still_has_eight(tmp_path):
    src, out, _ = make_env(tmp_path)
    assert not (src / "aem.json").exists()
    assert bt.build(src, "TEST", out) == 0
    ids = [d["id"] for d in json.loads((out / "teoria.json").read_text(encoding="utf-8"))["docs"]]
    assert ids == ["t1", "t2", "t3", "t4", "t5", "t6", "t7", "practica"]


def test_build_includes_optional_docs_in_order(tmp_path):
    src, out, _ = make_env(tmp_path)
    (src / "glosario.json").write_text(json.dumps(glossary(40)), encoding="utf-8")
    (src / "aem.json").write_text(json.dumps(doc("aem")), encoding="utf-8")
    assert bt.build(src, "TEST", out) == 0
    parsed = json.loads((out / "teoria.json").read_text(encoding="utf-8"))
    assert [d["id"] for d in parsed["docs"]] == [
        "t1", "t2", "t3", "t4", "t5", "t6", "t7", "practica", "aem", "glosario"]
    assert parsed["docs"][-1]["sections"][0]["blocks"][0]["type"] == "terms"
    new_manifest = json.loads((out / "manifest.json").read_text(encoding="utf-8"))
    assert new_manifest["teoria_sha256"] == ex.sha256_bytes((out / "teoria.json").read_bytes())


def test_build_with_invalid_optional_doc_writes_nothing(tmp_path, capsys):
    src, out, _ = make_env(tmp_path)
    (src / "glosario.json").write_text(json.dumps(glossary(10)), encoding="utf-8")
    assert bt.build(src, "TEST", out) == 1
    assert "glosario.json" in capsys.readouterr().err
    assert not (out / "teoria.json").exists()


def test_reviewed_count_includes_optional_docs(tmp_path, capsys):
    src, out, _ = make_env(tmp_path)
    (src / "aem.json").write_text(json.dumps(doc("aem", reviewed=True)), encoding="utf-8")
    assert bt.build(src, "TEST", out) == 0
    assert "1/9 documentos revisados" in capsys.readouterr().out
