"""Tests de la fusion de explicaciones/avisos propios (extract_questions.py, seccion 5b)."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(HERE))

import extract_questions as ex  # noqa: E402
from test_extract import SRC, _fake_process_tema, _have_real_inputs  # noqa: E402

EXPL_ROOT = HERE.parent / "explanations"


def entry(qid="t2-001", **kw):
    base = {
        "id": qid,
        "explanation": "Explicacion propia de prueba.",
        "article": "Art. 3 RD 137/1993",
        "notice": None,
        "flags": [],
        "confidence": "alta",
        "sources": [{"norma": "BOE-A-1993-6202", "ref": "art. 3"}],
        "reviewed": False,
        "review_notes": "interno",
    }
    base.update(kw)
    return base


def write_dir(tmp_path: Path, per_tema: dict[int, object] | None = None) -> Path:
    d = tmp_path / "expl"
    d.mkdir(exist_ok=True)
    for tema in ex.TEMAS:
        content = (per_tema or {}).get(tema, [])
        text = content if isinstance(content, str) else json.dumps(content)
        (d / f"t{tema}.json").write_text(text, encoding="utf-8")
    return d


@pytest.fixture
def fake_bank(monkeypatch):
    """21 preguntas (3 por tema, ids t{N}-001..003), todas con respuesta 0."""
    monkeypatch.setattr(ex, "process_tema", _fake_process_tema(bad_answer=False))


def run_fake(tmp_path, expl_dir, name="out"):
    out = tmp_path / name
    rep = tmp_path / f"rep-{name}" / "TEST"
    rc = ex.run(tmp_path, "TEST", "2026-10-18", out, rep, expl_dir)
    return rc, out, rep


def load_questions(out: Path) -> list[dict]:
    return json.loads((out / "questions.json").read_text(encoding="utf-8"))


def report_json(rep: Path) -> dict:
    return json.loads(Path(str(rep) + ".json").read_text(encoding="utf-8"))


def expl_check(rep: Path) -> dict:
    return next(c for c in report_json(rep)["checks"] if c["id"] == "explicaciones")


# ------------------------------------------------------------------ fusion


def test_merge_sets_our_layer_and_keeps_the_official_text(fake_bank, tmp_path):
    notice = "Ojo: el cuestionario dice X; tras la reforma de 2023 el art. 5 dice Z."
    d = write_dir(tmp_path, {2: [
        entry("t2-001", notice=notice, flags=["discrepancia_reforma_2023"], reviewed=True),
    ]})
    rc, out, _ = run_fake(tmp_path, d)
    assert rc == 0
    by_id = {q["id"]: q for q in load_questions(out)}
    q = by_id["t2-001"]
    assert q["explanation"] == {"es": "Explicacion propia de prueba."}
    assert q["article"] == "Art. 3 RD 137/1993"
    assert q["notice"] == {"es": notice}
    assert q["flags"] == ["discrepancia_reforma_2023"]
    assert q["reviewed"] is True
    # Texto y respuesta oficiales intactos.
    assert q["stem"] == "Enunciado 1"
    assert q["options"] == ["aaa", "bbb", "ccc"] and q["answer"] == 0
    # Sin campos internos.
    assert set(q) == {"id", "tema", "type", "section", "stem", "options", "answer", "explanation",
                      "article", "notice", "source", "flags", "edition", "reviewed"}
    assert list(q) == ["id", "tema", "type", "section", "stem", "options", "answer", "explanation",
                       "article", "notice", "source", "flags", "edition", "reviewed"]
    text = (out / "questions.json").read_text(encoding="utf-8")
    for internal in ("confidence", "sources", "review_notes", "interno", "BOE-A-1993-6202"):
        assert internal not in text
    # Una pregunta sin entrada queda como el extractor la deja.
    other = by_id["t2-002"]
    assert other["explanation"] is None and other["article"] is None and other["notice"] is None
    assert other["flags"] == [] and other["reviewed"] is False


def test_merge_without_notice_gives_null_and_extends_flags_without_duplicates(fake_bank, tmp_path,
                                                                              monkeypatch):
    # El extractor ya habia puesto un flag: se conserva delante y no se duplica.
    real = ex.build_questions

    def with_flag(tdata):
        qs = real(tdata)
        for q in qs:
            if q.id == "t1-001":
                q.flags.append("answer_partial_bold")
        return qs

    monkeypatch.setattr(ex, "build_questions", with_flag)
    d = write_dir(tmp_path, {1: [
        entry("t1-001", flags=["sin_articulo", "answer_partial_bold", "sin_articulo"], article=None),
    ]})
    rc, out, _ = run_fake(tmp_path, d)
    assert rc == 0
    q = {q["id"]: q for q in load_questions(out)}["t1-001"]
    assert q["notice"] is None and q["article"] is None
    assert q["flags"] == ["answer_partial_bold", "sin_articulo"]


def test_empty_files_reproduce_the_bank_except_for_the_notice_key(fake_bank, tmp_path):
    rc0, out0, _ = run_fake(tmp_path, None, "none")
    rc1, out1, _ = run_fake(tmp_path, write_dir(tmp_path), "empty")
    assert rc0 == rc1 == 0
    assert (out0 / "questions.json").read_bytes() == (out1 / "questions.json").read_bytes()
    assert (out0 / "manifest.json").read_bytes() == (out1 / "manifest.json").read_bytes()
    assert all(q["notice"] is None for q in load_questions(out0))


def test_manifest_checksum_matches_the_merged_bank(fake_bank, tmp_path):
    d = write_dir(tmp_path, {3: [entry("t3-002")]})
    rc, out, _ = run_fake(tmp_path, d)
    assert rc == 0
    manifest = json.loads((out / "manifest.json").read_text(encoding="utf-8"))
    assert manifest["questions_sha256"] == ex.sha256_bytes((out / "questions.json").read_bytes())


def test_missing_files_count_as_empty(fake_bank, tmp_path):
    d = tmp_path / "expl"
    d.mkdir()
    (d / "t2.json").write_text(json.dumps([entry("t2-001")]), encoding="utf-8")
    rc, out, _ = run_fake(tmp_path, d)
    assert rc == 0
    assert {q["id"]: q for q in load_questions(out)}["t2-001"]["explanation"] is not None


# ------------------------------------------------------------------ validaciones


def assert_rejected(tmp_path, per_tema, fragment, case="case"):
    base = tmp_path / case
    base.mkdir()
    d = write_dir(base, per_tema)
    rc, out, rep = run_fake(base, d)
    assert rc == 1, "debia haber ERROR"
    assert not out.exists(), "con ERROR no se escribe ningun asset"
    check = expl_check(rep)
    assert check["level"] == "ERROR"
    assert any(fragment in det for det in check["details"]), check["details"]


def test_error_unknown_id(fake_bank, tmp_path):
    assert_rejected(tmp_path, {2: [entry("t2-099")]}, "id desconocido")


def test_error_duplicate_id(fake_bank, tmp_path):
    assert_rejected(tmp_path, {2: [entry("t2-001"), entry("t2-001")]}, "id duplicado")


def test_error_empty_explanation(fake_bank, tmp_path):
    assert_rejected(tmp_path, {2: [entry("t2-001", explanation="   ")]}, "explicacion vacia")


def test_explanation_length_limit(fake_bank, tmp_path):
    ok = "x" * ex.EXPLANATION_MAX_CHARS
    rc, out, _ = run_fake(tmp_path, write_dir(tmp_path, {2: [entry("t2-001", explanation=ok)]}))
    assert rc == 0
    assert_rejected(tmp_path / "b", {2: [entry("t2-001", explanation=ok + "x")]}, "caracteres") \
        if (tmp_path / "b").mkdir() is None else None


def test_error_notice_without_discrepancy_flag(fake_bank, tmp_path):
    assert_rejected(tmp_path, {2: [entry("t2-001", notice="Ojo: algo.", flags=["otro"])]},
                    "sin flag discrepancia_")


def test_error_discrepancy_flag_without_notice(fake_bank, tmp_path):
    assert_rejected(tmp_path, {2: [entry("t2-001", flags=["discrepancia_reforma_2023"])]},
                    "sin 'notice'")


def test_error_reviewed_without_article(fake_bank, tmp_path):
    assert_rejected(tmp_path, {2: [entry("t2-001", article=None, reviewed=True)]},
                    "reviewed=true sin 'article'")


def test_reviewed_without_article_is_allowed_with_sin_articulo(fake_bank, tmp_path):
    d = write_dir(tmp_path, {2: [entry("t2-001", article=None, reviewed=True, flags=["sin_articulo"])]})
    rc, out, _ = run_fake(tmp_path, d)
    assert rc == 0
    q = {q["id"]: q for q in load_questions(out)}["t2-001"]
    assert q["reviewed"] is True and q["article"] is None and q["flags"] == ["sin_articulo"]


def test_error_entry_in_the_wrong_tema_file(fake_bank, tmp_path):
    assert_rejected(tmp_path, {3: [entry("t2-001")]}, "esta en t3.json")


def test_error_bad_confidence_unknown_field_and_missing_required(fake_bank, tmp_path):
    assert_rejected(tmp_path, {2: [entry("t2-001", confidence="altisima")]}, "'confidence'")
    assert_rejected(tmp_path / "u", {2: [entry("t2-001", extra=1)]}, "campo desconocido") \
        if (tmp_path / "u").mkdir() is None else None
    bad = entry("t2-001")
    del bad["confidence"]
    assert_rejected(tmp_path / "m", {2: [bad]}, "campo obligatorio") \
        if (tmp_path / "m").mkdir() is None else None


def test_error_invalid_json_and_non_array(fake_bank, tmp_path):
    assert_rejected(tmp_path, {2: "{ no es json"}, "no se puede leer como JSON", "a")
    assert_rejected(tmp_path, {4: {"id": "t4-001"}}, "debe ser un array", "b")


def test_error_does_not_overwrite_a_previous_valid_bank(fake_bank, tmp_path):
    out = tmp_path / "out"
    out.mkdir()
    (out / "questions.json").write_bytes(b"previous")
    (out / "manifest.json").write_bytes(b"previous")
    d = write_dir(tmp_path, {2: [entry("t2-099")]})
    rc = ex.run(tmp_path, "TEST", "2026-10-18", out, tmp_path / "rep" / "TEST", d)
    assert rc == 1
    assert (out / "questions.json").read_bytes() == b"previous"


# ------------------------------------------------------------------ informe


def test_report_section_coverage_confidence_notices_and_low_confidence(fake_bank, tmp_path):
    d = write_dir(tmp_path, {
        1: [entry("t1-001", reviewed=True), entry("t1-002", confidence="media")],
        2: [entry("t2-003", confidence="baja", review_notes="Revisar art. 12",
                  notice="Ojo: cambio.", flags=["discrepancia_reforma_2023"])],
    })
    rc, _, rep = run_fake(tmp_path, d)
    assert rc == 0
    data = expl_check(rep)["data"]
    rows = {r["tema"]: r for r in data["cobertura"]}
    assert rows[1]["cobertura"] == "2/3" and rows[1]["revisadas"] == 1
    assert rows[2]["cobertura"] == "1/3" and rows[2]["con_aviso"] == 1
    assert rows[3]["cobertura"] == "0/3"
    assert rows["total"]["cobertura"] == "3/21"
    assert data["confianza"] == {"alta": 1, "media": 1, "baja": 1}
    assert data["avisos"] == [{"id": "t2-003", "notice": "Ojo: cambio.",
                               "flags": ["discrepancia_reforma_2023"]}]
    assert data["confianza_baja"] == [{"id": "t2-003", "review_notes": "Revisar art. 12"}]
    md = Path(str(rep) + ".md").read_text(encoding="utf-8")
    assert "## [OK] Explicaciones" in md
    assert "### Cobertura por tema" in md and "2/3" in md
    assert "t2-003 (discrepancia_reforma_2023): Ojo: cambio." in md
    assert "t2-003: Revisar art. 12" in md


def test_report_has_no_section_without_an_explanations_dir(fake_bank, tmp_path):
    _, _, rep = run_fake(tmp_path, None)
    assert all(c["id"] != "explicaciones" for c in report_json(rep)["checks"])


# ------------------------------------------------------------------ CLI y ficheros


def test_cli_default_and_explicit_directory(monkeypatch, tmp_path):
    seen = {}

    def fake_run(src, edition, retrieved, out, report, explanations_dir=None, cifras_path=None):
        seen["dir"] = explanations_dir
        return 0

    monkeypatch.setattr(ex, "run", fake_run)
    monkeypatch.setattr(ex, "find_pdftotext", lambda: "pdftotext")
    def args(edition="GC-2020-11"):
        return ["--src", str(tmp_path), "--edition", edition, "--retrieved", "2026-10-18",
                "--out", str(tmp_path / "o"), "--report", str(tmp_path / "r")]

    base = args()
    assert ex.main(base) == 0
    assert seen["dir"] == EXPL_ROOT / "GC-2020-11"  # existe en el repo
    assert ex.main(args("OTRA")) == 0
    assert seen["dir"] is None  # sin carpeta por defecto para otra edicion
    d = write_dir(tmp_path)
    assert ex.main(base + ["--explanations", str(d)]) == 0
    assert seen["dir"] == d
    assert ex.main(base + ["--explanations", str(tmp_path / "no-existe")]) == 2


def test_schema_matches_the_validator():
    schema = json.loads((EXPL_ROOT / "schema.json").read_text(encoding="utf-8"))
    entry_schema = schema["$defs"]["entry"]
    assert schema["type"] == "array"
    assert tuple(entry_schema["properties"]) == ex.ENTRY_FIELDS
    assert tuple(entry_schema["required"]) == ex.ENTRY_REQUIRED
    assert entry_schema["properties"]["explanation"]["maxLength"] == ex.EXPLANATION_MAX_CHARS
    assert tuple(entry_schema["properties"]["confidence"]["enum"]) == ex.CONFIDENCE_LEVELS
    assert entry_schema["additionalProperties"] is False


def test_committed_explanation_files_are_arrays():
    for tema in ex.TEMAS:
        data = json.loads((EXPL_ROOT / "GC-2020-11" / f"t{tema}.json").read_text(encoding="utf-8"))
        assert isinstance(data, list)


@pytest.mark.skipif(not _have_real_inputs(), reason="falta pdftotext o los PDF de fuentes/")
def test_integration_committed_explanations_validate_and_empty_equals_none(tmp_path):
    committed = EXPL_ROOT / "GC-2020-11"
    assert ex.run(SRC, "GC-2020-11", "2026-10-18", tmp_path / "a" / "o", tmp_path / "a" / "r" / "x",
                  committed) == 0
    if all(json.loads((committed / f"t{t}.json").read_text(encoding="utf-8")) == [] for t in ex.TEMAS):
        assert ex.run(SRC, "GC-2020-11", "2026-10-18", tmp_path / "b" / "o", tmp_path / "b" / "r" / "x",
                      None) == 0
        for f in ("questions.json", "manifest.json"):
            assert (tmp_path / "a" / "o" / f).read_bytes() == (tmp_path / "b" / "o" / f).read_bytes()


def test_existing_teoria_keeps_its_sha_after_questions_sha_and_warns(fake_bank, tmp_path, capsys):
    out = tmp_path / "out"
    out.mkdir()
    teoria = b'{"edition": "TEST", "docs": []}\n'
    (out / "teoria.json").write_bytes(teoria)
    rc, out, _ = run_fake(tmp_path, write_dir(tmp_path))
    assert rc == 0
    manifest = json.loads((out / "manifest.json").read_text(encoding="utf-8"))
    keys = list(manifest)
    assert manifest["teoria_sha256"] == ex.sha256_bytes(teoria)
    assert keys.index("teoria_sha256") == keys.index("questions_sha256") + 1
    assert "build_teoria.py" in capsys.readouterr().out
    # El teoria.json no se toca.
    assert (out / "teoria.json").read_bytes() == teoria


def test_without_teoria_the_manifest_has_no_teoria_sha_and_no_warning(fake_bank, tmp_path, capsys):
    rc, out, _ = run_fake(tmp_path, write_dir(tmp_path))
    assert rc == 0
    assert "teoria_sha256" not in json.loads((out / "manifest.json").read_text(encoding="utf-8"))
    assert "build_teoria.py" not in capsys.readouterr().out
