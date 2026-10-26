"""Tests de tool/content/check_sources.py con un servidor HTTP falso (sin red)."""
from __future__ import annotations

import hashlib
import sys
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import check_sources as cs  # noqa: E402

LAST_MODIFIED = "Mon, 19 Oct 2026 08:00:00 GMT"


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


@pytest.fixture
def server():
    """Sirve `served` (ruta -> bytes) en 127.0.0.1; `served` se puede cambiar."""
    served: dict[str, bytes] = {}

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):  # noqa: N802
            body = served.get(self.path)
            if body is None:
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Last-Modified", LAST_MODIFIED)
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass

    httpd = HTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=httpd.serve_forever, daemon=True)
    thread.start()
    yield f"http://127.0.0.1:{httpd.server_port}", served
    httpd.shutdown()
    httpd.server_close()


def make_src(tmp_path: Path, base: str, files: dict[str, bytes], last_modified: str = "") -> Path:
    src = tmp_path / "src"
    src.mkdir()
    rows = ["| Fichero | URL | sha256 |", "|---|---|---|"]
    for name, data in files.items():
        (src / name).write_bytes(data)
        row = f"| `{name}` | `{base}/{name}` | `{sha(data)}` |"
        if last_modified:
            row = row + f" {last_modified} |"
        rows.append(row)
    (src / "LEEME.md").write_text("# Fuentes\n\n" + "\n".join(rows) + "\n", encoding="utf-8")
    return src


def test_parse_leeme_ignores_header_and_text():
    text = (
        "intro | con barra\n| Fichero | URL | sha256 |\n|---|---|---|\n"
        f"| `a.pdf` | `http://x/a.pdf` | `{'a' * 64}` |\n"
        f"| `b.pdf` | `http://x/b.pdf` | `{'b' * 64}` | Mon |\n"
    )
    sources = cs.parse_leeme(text)
    assert [s.name for s in sources] == ["a.pdf", "b.pdf"]
    assert sources[0].last_modified is None and sources[1].last_modified == "Mon"


def test_real_leeme_lists_all_pdfs_and_local_files_match():
    src = cs.DEFAULT_SRC
    sources = cs.parse_leeme((src / "LEEME.md").read_text(encoding="utf-8"))
    assert sorted(s.name for s in sources) == sorted(p.name for p in src.glob("*.pdf"))
    assert all(s.url.startswith("https://") for s in sources)
    assert cs.check_offline(sources, src) == []


def test_online_all_match_exit_0(server, tmp_path, capsys):
    base, served = server
    files = {"tema1.pdf": b"uno", "tema1r.pdf": b"dos"}
    served.update({f"/{n}": d for n, d in files.items()})
    src = make_src(tmp_path, base, files)
    assert cs.main(["--src", str(src)]) == 0
    assert "Todo coincide" in capsys.readouterr().out


def test_online_changed_file_exit_1_and_nothing_touched(server, tmp_path, capsys):
    base, served = server
    files = {"tema1.pdf": b"uno", "tema2.pdf": b"dos"}
    served.update({f"/{n}": d for n, d in files.items()})
    served["/tema2.pdf"] = b"dos, version nueva"
    src = make_src(tmp_path, base, files)
    before = {p.name: p.read_bytes() for p in src.iterdir()}
    assert cs.main(["--src", str(src)]) == 1
    out = capsys.readouterr().out
    assert "tema2.pdf: CAMBIADO" in out and "tema1.pdf: CAMBIADO" not in out
    assert LAST_MODIFIED in out
    assert {p.name: p.read_bytes() for p in src.iterdir()} == before


def test_online_http_error_exit_1(server, tmp_path, capsys):
    base, _served = server  # no sirve nada: 404
    src = make_src(tmp_path, base, {"tema1.pdf": b"uno"})
    assert cs.main(["--src", str(src)]) == 1
    assert "no se pudo descargar" in capsys.readouterr().out


def test_online_last_modified_differs_exit_1(server, tmp_path, capsys):
    base, served = server
    served["/tema1.pdf"] = b"uno"
    src = make_src(tmp_path, base, {"tema1.pdf": b"uno"}, last_modified="Sun, 01 Jan 2023 00:00:00 GMT")
    assert cs.main(["--src", str(src)]) == 1
    assert "Last-Modified distinto" in capsys.readouterr().out


def test_online_last_modified_matches_exit_0(server, tmp_path):
    base, served = server
    served["/tema1.pdf"] = b"uno"
    src = make_src(tmp_path, base, {"tema1.pdf": b"uno"}, last_modified=LAST_MODIFIED)
    assert cs.main(["--src", str(src)]) == 0


def test_offline_makes_no_requests_and_detects_edits(tmp_path, capsys):
    # URL que no existe: si intentara descargar, fallaria.
    src = make_src(tmp_path, "http://127.0.0.1:9", {"tema1.pdf": b"uno"})
    assert cs.main(["--src", str(src), "--offline"]) == 0
    (src / "tema1.pdf").write_bytes(b"editado")
    assert cs.main(["--src", str(src), "--offline"]) == 1
    assert "no coincide con el LEEME" in capsys.readouterr().out
    (src / "tema1.pdf").unlink()
    assert cs.main(["--src", str(src), "--offline"]) == 1


def test_missing_table_exit_2(tmp_path):
    src = tmp_path / "src"
    src.mkdir()
    (src / "LEEME.md").write_text("sin tabla\n", encoding="utf-8")
    assert cs.main(["--src", str(src), "--offline"]) == 2
