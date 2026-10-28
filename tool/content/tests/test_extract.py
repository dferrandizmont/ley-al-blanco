"""Tests de tool/content/extract_questions.py (ejecutar con `python -m pytest tool/content/tests`)."""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import extract_questions as ex  # noqa: E402

REPO = HERE.parents[2]
SRC = REPO / "fuentes" / "guardia-civil"


# ---------------------------------------------------------------- parser de texto

LAYOUT = (
    "                                    TEMA I\n"
    "\n"
    "   • PIEZAS FUNDAMENTALES.\n"
    "\n"
    "- Definición de todos los tipos de armas amparadas con Licencia de Armas “E” y “D”.\n"
    "\n"
    "1. Pregunta con prefijo A).-Texto pegado:\n"
    "       A).-Uno pegado.\n"
    "       B).- Dos con espacio.\n"
    "       C).- Tres\n"
    "\n"
    "2. Prefijos distintos?.\n"
    "       A.- Uno punto guion\n"
    "       B) Dos parentesis espacio\n"
    "       C). Tres punto\n"
    "\n"
    "3. Otro estilo:\n"
    "       A)Uno sin espacio\n"
    "       B).\n"
    "       - Dos con guion en la misma linea?\n"
    "       C-Tres guion\n"
    "\n"
    "4. Enunciado largo que se parte en\n"
    "       dos lineas y\n"
    "       una tercera?\n"
    "       A).- Opcion que se parte\n"
    "              en dos lineas.\n"
    "       B).-  Con   espacios   dobles.\n"
    "       C).- Normal.\n"
    "5. Sin linea en blanco antes de la siguiente\n"
    "       A).- a\n"
    "       B).- b\n"
    "       C).- c\n"
    "\n"
    "-Partes o grupos principales (Conjuntos) de las armas amparadas con Licencia de\n"
    "armas “E” y “D”.\n"
    "\n"
    "\x0c 6. Pregunta tras salto de página con espacio inicial\n"
    "       A).- uno\n"
    "       B).- dos\n"
    "       C).- tres\n"
    "\n"
    "\x0cPIEZAS FUNDAMENTALES Y MECANISMOS\n"
    "\n"
    "7. ¿Fin?\n"
    "       A).- x\n"
    "       B).- y\n"
    "       C).- z\n"
)


def test_parse_layout_variants_and_structure():
    res = ex.parse_layout_text(LAYOUT)
    qs = res.questions
    assert [q.number for q in qs] == [1, 2, 3, 4, 5, 6, 7]
    assert all(len(q.options) == 3 for q in qs)

    q1, q2, q3, q4, q5, q6, q7 = qs
    assert q1.options == ["Uno pegado.", "Dos con espacio.", "Tres"]
    assert q2.options == ["Uno punto guion", "Dos parentesis espacio", "Tres punto"]
    assert q3.options == ["Uno sin espacio", "- Dos con guion en la misma linea?", "Tres guion"] or \
        q3.options == ["Uno sin espacio", "Dos con guion en la misma linea?", "Tres guion"]
    assert q2.stem == "Prefijos distintos?."  # puntuacion original intacta


def test_parse_wrapped_stem_and_option_and_whitespace():
    q4 = ex.parse_layout_text(LAYOUT).questions[3]
    assert q4.stem == "Enunciado largo que se parte en dos lineas y una tercera?"
    assert q4.options[0] == "Opcion que se parte en dos lineas."
    assert q4.options[1] == "Con espacios dobles."


def test_parse_no_blank_line_between_questions():
    qs = ex.parse_layout_text(LAYOUT).questions
    assert qs[3].number == 4 and qs[4].number == 5
    assert qs[3].options == ["Opcion que se parte en dos lineas.", "Con espacios dobles.", "Normal."]
    assert qs[4].options == ["a", "b", "c"]


def test_parse_section_header_with_col0_continuation():
    qs = ex.parse_layout_text(LAYOUT).questions
    first = ex.collapse_ws(
        "Definición de todos los tipos de armas amparadas con Licencia de Armas “E” y “D”."
    )
    assert qs[0].section == first
    assert qs[4].section == first
    assert qs[5].section == (
        "Partes o grupos principales (Conjuntos) de las armas amparadas con Licencia de "
        "armas “E” y “D”."
    )


def test_parse_formfeed_pages_and_indented_question():
    res = ex.parse_layout_text(LAYOUT)
    q6, q7 = res.questions[5], res.questions[6]
    assert q6.number == 6 and q6.page == 2
    assert q7.page == 3
    # el titulo en mayusculas tras \f se ignora y no ensucia la pregunta 6
    assert q6.options == ["uno", "dos", "tres"]
    assert any("PIEZAS FUNDAMENTALES Y MECANISMOS" in i.text for i in res.ignored)
    assert any(i.text.startswith("•") for i in res.ignored)


def test_parse_ignores_c_dot_abbreviations_in_stem():
    text = (
        "1. Competencia de la D.G.G.C.\n"
        "       C.D.G.C. continua el enunciado\n"
        "       A).- uno\n"
        "       B).- dos\n"
        "       C).- tres\n"
    )
    q = ex.parse_layout_text(text).questions[0]
    assert "C.D.G.C. continua el enunciado" in q.stem
    assert q.options == ["uno", "dos", "tres"]


def test_parse_page_number_lines_dropped():
    text = (
        "1. Pregunta\n"
        "       A).- uno\n"
        "       B).- dos\n"
        "       C).- tres\n"
        "                    12\n"
        "2. Otra\n"
        "       A).- a\n"
        "       B).- b\n"
        "       C).- c\n"
    )
    res = ex.parse_layout_text(text)
    assert [q.options[2] for q in res.questions] == ["tres", "c"]


# ---------------------------------------------------------------- negrita


def L(x0, *spans):
    return {"x0": x0, "spans": list(spans)}


def test_bold_detection_whole_line_and_parts():
    lines = [
        L(56.8, ("TEMA II", True)),
        L(56.8, (" ", False)),
        L(56.8, ("1.", False), (" ", False)),
        L(56.8, ("Enunciado ", False)),
        L(85.1, ("A.- Su grado", False)),
        L(85.1, ("B.- Otra", False)),
        L(85.1, ("C.- Ambas respuestas son correctas", True)),
        L(56.8, (" ", False)),
        L(56.8, ("2.", False)),
        L(56.8, ("Enunciado dos ", False)),
        L(85.1, ("A).-Sí. ", False)),
        L(85.1, ("B).-Doc", False)),
        L(85.1, ("C)", True), (".-", False), ("No", True), (". ", False)),
        L(56.8, (" ", False)),
        L(56.8, ("-Cabecera de seccion", False)),
        L(56.8, (" ", False)),
        L(56.8, ("3.", False)),
        L(56.8, ("Enunciado tres", False)),
        L(85.1, ("A)", True), (".-", False), ("Si ", True)),
        L(85.1, ("B)", False), (".-", False), ("Dos que", False)),
        L(85.1, ("continua", False)),
        L(85.1, ("C)", False), (".-", False), ("Tres", False)),
    ]
    qs = ex.parse_bold_lines(lines)
    assert [q.number for q in qs] == [1, 2, 3]
    assert qs[0].bold_indices() == [2]
    assert qs[0].options[2].classification == "full"
    # q2: "C)" bold, ".-" regular, "No" bold -> full (la puntuacion no cuenta)
    assert qs[1].bold_indices() == [2]
    assert qs[1].options[2].classification == "full"
    assert qs[2].bold_indices() == [0]
    # el titulo en negrita de la cabecera de pagina no se cuela como opcion
    assert all(len(q.options) == 3 for q in qs)
    # la continuacion de B en q3 se suma a la extension de la opcion
    assert qs[2].options[1].text_alnum == len("Dosquecontinua")


def test_bold_partial_classification():
    lines = [
        L(56.8, ("1.", False)),
        L(56.8, ("Enun", False)),
        L(85.1, ("A).- ", False), ("Solo texto", True)),
        L(85.1, ("B)", True), (".- Solo letra", False)),
        L(85.1, ("C).- Mitad ", False), ("negrita", True)),
    ]
    q = ex.parse_bold_lines(lines)[0]
    assert [o.classification for o in q.options] == ["text_only", "letter_only", "partial"]
    assert all(o.is_partial for o in q.options)


def test_bold_title_after_blank_is_not_a_continuation():
    lines = [
        L(56.8, ("1.", False)),
        L(56.8, ("Enun", False)),
        L(85.1, ("A).- a", False)),
        L(85.1, ("B).- b", False)),
        L(85.1, ("C).- c", False)),
        L(56.8, (" ", False)),
        L(92.8, ("EUROPEAS DE ARMAS", True)),
    ]
    q = ex.parse_bold_lines(lines)[0]
    assert q.bold_indices() == []


def test_is_bold_font():
    assert ex.is_bold_font("ArialNarrow,Bold", 20)
    assert ex.is_bold_font("Whatever", 16)
    assert not ex.is_bold_font("ArialNarrow", 4)


# ---------------------------------------------------------------- validacion


def _td(tema, q_opts, r_bold=None):
    """TemaData sintetico: q_opts = lista de listas de opciones por pregunta."""
    qs = [ex.ParsedQuestion(i + 1, f"Enunciado {i + 1}", o, None, 1, i) for i, o in enumerate(q_opts)]
    bold = r_bold
    if bold is None:
        bold = [
            ex.BoldQuestion(
                i + 1,
                [ex.BoldOption(ex.LETTERS[k], k == 0, 5, 5 if k == 0 else 0, 5) for k in range(len(o))],
            )
            for i, o in enumerate(q_opts)
        ]
    pr = ex.ParseResult(questions=qs)
    return ex.TemaData(tema, pr, pr, [ex.BoldQuestion(b.number, [ex.BoldOption(o.letter, False, o.text_alnum, 0, o.ascii_alnum_total) for o in b.options]) for b in bold], bold)


def test_validation_detects_two_option_question():
    td = _td(1, [["a", "b", "c"], ["a", "b"]])
    c = ex.check_options([td])
    assert c.level == "ERROR"
    assert any("t1-002" in d and "2 opciones" in d for d in c.details)


def test_validation_detects_zero_and_two_bold():
    opts = [ex.BoldOption("A", True, 3, 3, 3), ex.BoldOption("B", True, 3, 3, 3), ex.BoldOption("C", False, 3, 0, 3)]
    none = [ex.BoldOption("A", False, 3, 0, 3), ex.BoldOption("B", False, 3, 0, 3), ex.BoldOption("C", False, 3, 0, 3)]
    ok = [ex.BoldOption("A", False, 3, 0, 3), ex.BoldOption("B", True, 3, 3, 3), ex.BoldOption("C", False, 3, 0, 3)]
    td = _td(2, [["aaa", "bbb", "ccc"]] * 3,
             r_bold=[ex.BoldQuestion(1, opts), ex.BoldQuestion(2, none), ex.BoldQuestion(3, ok)])
    c = ex.check_single_bold([td])
    assert c.level == "ERROR"
    assert len(c.details) == 2
    assert "t2-001" in c.details[0] and "t2-002" in c.details[1]


def _q(tema, number, stem, options, answer):
    return ex.Q(tema, number, stem, options, None, answer, [], None, None, None)


def test_validation_duplicates_real_and_conflicting():
    qs = [
        _q(1, 1, "¿Cuál es la capital?", ["Madrid", "París", "Roma"], 0),
        _q(2, 7, "Cual es la capital", ["Roma", "Madrid", "París."], 1),  # duplicado real (otro orden)
        _q(3, 1, "¿Cuál es la capital?", ["Madrid", "París", "Roma"], 2),  # misma opciones, otra respuesta
        _q(3, 2, "¿Cuál es la capital?", ["Berlín", "Lisboa", "Roma"], 2),  # opciones distintas
        _q(3, 3, "Distinta", ["x", "y", "z"], 0),
    ]
    pairs = {(p["a"], p["b"]): p["tipo"] for p in ex.duplicate_groups(qs)}
    assert pairs[("t1-001", "t2-007")] == "duplicado_real"
    assert pairs[("t1-001", "t3-001")] == "conflicto_respuesta"
    assert pairs[("t1-001", "t3-002")] == "conflicto_opciones"
    assert all("t3-003" not in k for k in pairs)
    c = ex.check_duplicate_stems(qs)
    assert c.level == "WARN"

    dup_ids = ex.check_duplicate_ids([_q(1, 1, "a", ["x", "y", "z"], 0), _q(1, 1, "b", ["x", "y", "z"], 0)])
    assert dup_ids.level == "ERROR"


def test_build_questions_leaves_answer_none_when_bold_count_is_not_one():
    opts = [["aaa", "bbb", "ccc"]] * 3
    two = [ex.BoldOption("A", True, 3, 3, 3), ex.BoldOption("B", True, 3, 3, 3), ex.BoldOption("C", False, 3, 0, 3)]
    none = [ex.BoldOption("A", False, 3, 0, 3), ex.BoldOption("B", False, 3, 0, 3), ex.BoldOption("C", False, 3, 0, 3)]
    ok = [ex.BoldOption("A", False, 3, 0, 3), ex.BoldOption("B", True, 3, 3, 3), ex.BoldOption("C", False, 3, 0, 3)]
    td = _td(2, opts, r_bold=[ex.BoldQuestion(1, two), ex.BoldQuestion(2, none), ex.BoldQuestion(3, ok)])
    qs = ex.build_questions([td])
    assert [q.answer for q in qs] == [None, None, 1]
    # ... y eso es un ERROR explicito, no un `answer: null` silencioso.
    c = ex.check_answers_present(qs)
    assert c.level == "ERROR"
    assert len(c.details) == 2
    assert "t2-001" in c.details[0] and "t2-002" in c.details[1]


def test_check_answers_present_ok_and_out_of_range():
    ok = [_q(1, 1, "a", ["x", "y", "z"], 2)]
    assert ex.check_answers_present(ok).level == "OK"
    bad = ex.check_answers_present([_q(1, 1, "a", ["x", "y", "z"], 3)])
    assert bad.level == "ERROR" and "fuera de rango" in bad.details[0]


def _fake_process_tema(bad_answer: bool):
    """Sustituye a process_tema: 3 preguntas por tema; si `bad_answer`, la primera del
    tema 1 tiene dos opciones en negrita (sin respuesta unica)."""

    def fake(src_dir, tema):
        def bold(i, marks):
            return ex.BoldQuestion(
                i + 1, [ex.BoldOption(ex.LETTERS[k], m, 3, 3 if m else 0, 3) for k, m in enumerate(marks)]
            )

        marks = [[True, False, False]] * 3
        if bad_answer and tema == 1:
            marks[0] = [True, True, False]
        td = _td(tema, [["aaa", "bbb", "ccc"]] * 3, r_bold=[bold(i, m) for i, m in enumerate(marks)])
        src = {
            "tema": tema, "doc": f"tema{tema}_es.pdf", "answers_doc": f"tema{tema}r_es.pdf",
            "sha256": "0" * 64, "answers_sha256": "1" * 64,
            "pdf_creation_date": "2020-11-01", "answers_pdf_creation_date": "2020-11-01",
        }
        return td, src

    return fake


def test_run_does_not_write_app_assets_when_there_is_an_error(tmp_path, monkeypatch, capsys):
    monkeypatch.setattr(ex, "process_tema", _fake_process_tema(bad_answer=True))
    out = tmp_path / "out"
    report = tmp_path / "rep" / "TEST"
    # Un banco valido anterior no se toca.
    out.mkdir()
    (out / "questions.json").write_bytes(b"previous questions")
    (out / "manifest.json").write_bytes(b"previous manifest")

    rc = ex.run(tmp_path, "TEST", "2026-10-18", out, report)

    assert rc == 1
    assert (out / "questions.json").read_bytes() == b"previous questions"
    assert (out / "manifest.json").read_bytes() == b"previous manifest"
    assert (report.parent / "TEST.md").is_file()
    assert (report.parent / "TEST.json").is_file()
    import json

    rep = json.loads((report.parent / "TEST.json").read_text(encoding="utf-8"))
    assert rep["errors"] >= 1
    assert any(c["id"] == "respuesta_presente" and c["level"] == "ERROR" for c in rep["checks"])
    assert "NO se han escrito" in capsys.readouterr().out


def test_run_with_error_creates_no_output_folder(tmp_path, monkeypatch):
    monkeypatch.setattr(ex, "process_tema", _fake_process_tema(bad_answer=True))
    out = tmp_path / "out"
    assert ex.run(tmp_path, "TEST", "2026-10-18", out, tmp_path / "rep" / "TEST") == 1
    assert not out.exists()


def test_run_writes_app_assets_when_clean(tmp_path, monkeypatch):
    import json

    monkeypatch.setattr(ex, "process_tema", _fake_process_tema(bad_answer=False))
    out = tmp_path / "out"
    assert ex.run(tmp_path, "TEST", "2026-10-18", out, tmp_path / "rep" / "TEST") == 0
    questions = json.loads((out / "questions.json").read_text(encoding="utf-8"))
    assert len(questions) == 21 and all(q["answer"] == 0 for q in questions)
    assert (out / "manifest.json").is_file()


def test_word_diff():
    assert ex.word_diff("a b c", "a b c") == "a b c"
    d = ex.word_diff("el arma corta", "el arma larga")
    assert "[-corta-]" in d and "{+larga+}" in d


def test_normalize_for_compare():
    assert ex.normalize_for_compare("¿Cuál  es, Esa?") == ex.normalize_for_compare("cual es esa")


def test_numbering_check_flags_gap_and_duplicate():
    qs = [ex.ParsedQuestion(n, "s", ["a", "b", "c"], None, 1, 0) for n in (1, 2, 2, 4)]
    pr = ex.ParseResult(questions=qs)
    td = ex.TemaData(1, pr, pr, [], [])
    c = ex.check_numbering([td])
    assert c.level == "ERROR"
    assert any("huecos=[3]" in d and "duplicados=[2]" in d for d in c.details)


def test_pdf_date_to_iso():
    assert ex.pdf_date_to_iso("D:20201104110446+01'00'") == "2020-11-04"
    assert ex.pdf_date_to_iso(None) is None


# ---------------------------------------------------------------- integracion

EXPECTED = {1: 68, 2: 67, 3: 66, 4: 70, 5: 66, 6: 64, 7: 22}


def _have_real_inputs() -> bool:
    try:
        ex.find_pdftotext()
    except ex.MissingToolError:
        return False
    return SRC.is_dir() and all((SRC / f"tema{n}.pdf").is_file() for n in EXPECTED)


@pytest.mark.skipif(not _have_real_inputs(), reason="falta pdftotext o los PDF de fuentes/")
def test_integration_real_pdfs(tmp_path):
    out = tmp_path / "out"
    report = tmp_path / "rep" / "GC-2020-11"
    rc = ex.run(SRC, "GC-2020-11", "2026-10-18", out, report)
    assert rc == 0

    import json

    questions = json.loads((out / "questions.json").read_text(encoding="utf-8"))
    manifest = json.loads((out / "manifest.json").read_text(encoding="utf-8"))
    assert len(questions) == 423 == manifest["question_count"]
    for tema, n in EXPECTED.items():
        assert sum(1 for q in questions if q["tema"] == tema) == n
        assert manifest["per_tema"][str(tema)] == n
    for q in questions:
        assert len(q["options"]) == 3 and all(q["options"])
        assert q["answer"] in (0, 1, 2)
        assert list(q.keys()) == [
            "id", "tema", "type", "section", "stem", "options", "answer", "explanation",
            "article", "notice", "source", "flags", "edition", "reviewed",
        ]
    assert len({q["id"] for q in questions}) == 423
    assert ex.sha256_bytes((out / "questions.json").read_bytes()) == manifest["questions_sha256"]
    assert (report.parent / "GC-2020-11.md").is_file()
    assert (report.parent / "GC-2020-11.json").is_file()


@pytest.mark.skipif(not _have_real_inputs(), reason="falta pdftotext o los PDF de fuentes/")
def test_integration_deterministic(tmp_path):
    for name in ("a", "b"):
        assert ex.run(SRC, "GC-2020-11", "2026-10-18", tmp_path / name / "o", tmp_path / name / "r" / "x") == 0
    for rel in ("o/questions.json", "o/manifest.json", "r/x.md", "r/x.json"):
        assert (tmp_path / "a" / rel).read_bytes() == (tmp_path / "b" / rel).read_bytes()


def test_typographic_errata_only_listed_ids():
    opts = ["Multa de 300´51 a 30050´61 _.", "Multa de hasta 300´51 _."]
    fixed, changed = ex.apply_typographic_errata("t5-052", opts)
    assert changed
    assert fixed == ["Multa de 300´51 a 30050´61 €.", "Multa de hasta 300´51 €."]
    same, changed_other = ex.apply_typographic_errata("t5-051", opts)
    assert not changed_other and same == opts


def test_typographic_errata_in_generated_bank():
    import json
    bank = Path(__file__).resolve().parents[3] / "app/assets/content/armas/GC-2020-11/questions.json"
    data = json.loads(bank.read_text(encoding="utf-8"))
    items = data["questions"] if isinstance(data, dict) else data
    by_id = {q["id"]: q for q in items}
    q = by_id["t5-052"]
    texts = [o if isinstance(o, str) else o["text"] for o in q["options"]]
    assert all(t.endswith(" €.") for t in texts)
    assert ex.TYPO_ERRATA_FLAG in q["flags"]
    flagged = [i for i, x in by_id.items() if ex.TYPO_ERRATA_FLAG in x.get("flags", [])]
    assert flagged == ["t5-052"]
