"""Capturas de App Store de Ley al Blanco en un simulador iOS real.

Ejecutar con `python3 -I` (Pillow disponible, p. ej. en un venv fuera del repo).
`app/integration_test/store_ios_test.dart` navega por la app real; este script
crea su propio simulador, hace cada captura con `simctl io screenshot` cuando el
test la pide por un puente HTTP local y guarda la pantalla **tal cual**, sin
marco ni título (PNG RGB, sin alfa), en docs/store/ios/es/. El marco, el titular
y el tamaño de App Store (1290 x 2796) los pone el generador compartido
`store_shots.py` (ver docs/store/shots.json). No añade nada al punto de entrada
ni a los assets de producción. Ver tool/screenshots/LEEME.md.
"""

import argparse
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path
import signal
import subprocess
import sys
import threading
import uuid

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "app"
DEVICE_NAME = "LAB-Shots"
DEVICE_TYPE = "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max"
RUNTIME = "com.apple.CoreSimulator.SimRuntime.iOS-26-5"
RAW_SIZE = (1320, 2868)  # iPhone 17 Pro Max (6,9"): 440 x 956 pt a 3x
OUT_DIR = ROOT / "docs/store/ios/es"

# Las cinco pantallas de docs/readme/es/, en el orden de docs/store/shots.json.
NAMES = (
    "01-probabilidad",
    "02-simulacro",
    "03-fallos",
    "04-tarjetas-cifras",
    "05-glosario",
)


def simctl(*args, timeout=120):
    return subprocess.run(
        ["xcrun", "simctl", *args], cwd=ROOT, check=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout,
    ).stdout


def status_bar(udid):
    simctl("status_bar", udid, "override", "--time", "9:41",
           "--batteryState", "charged", "--batteryLevel", "100",
           "--cellularMode", "active", "--cellularBars", "4",
           "--wifiMode", "active", "--wifiBars", "3")


def check_png(path):
    with Image.open(path) as image:
        if image.format != "PNG" or image.size != RAW_SIZE or image.mode != "RGB":
            raise RuntimeError(f"{path}: se esperaba PNG RGB {RAW_SIZE}, hay "
                               f"{image.format} {image.mode} {image.size}")
        image.load()


def validate():
    for name in NAMES:
        check_png(OUT_DIR / f"{name}.png")
    print(f"OK: {len(NAMES)} PNG RGB sin alfa de {RAW_SIZE[0]}x{RAW_SIZE[1]} en {OUT_DIR}")


class Session:
    def __init__(self, udid):
        self.udid = udid
        self.pending = list(NAMES)
        self.error = None

    def capture(self, name):
        if not self.pending or name != self.pending[0]:
            raise RuntimeError(f"Captura inesperada {name}; se esperaba {self.pending[:1]}")
        status_bar(self.udid)
        OUT_DIR.mkdir(parents=True, exist_ok=True)
        tmp = OUT_DIR / f".{name}.simctl.png"
        simctl("io", self.udid, "screenshot", "--type=png", str(tmp))
        try:
            with Image.open(tmp) as image:
                if image.size != RAW_SIZE:
                    raise RuntimeError(f"El simulador devolvió {image.size}, se esperaba {RAW_SIZE}")
                # Las esquinas del simulador son transparentes: se guarda RGB
                # (el generador recorta la pantalla con sus propias esquinas).
                image.convert("RGB").save(OUT_DIR / f"{name}.png", optimize=True)
        finally:
            tmp.unlink(missing_ok=True)
        check_png(OUT_DIR / f"{name}.png")
        self.pending.pop(0)
        print(f"Capturada {name}", flush=True)


@contextmanager
def bridge(session):
    token = uuid.uuid4().hex

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def reply(self, status, data):
            self.send_response(status)
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_POST(self):
            parts = self.path.split("/")
            if len(parts) != 4 or parts[1:3] != [token, "capture"]:
                self.reply(404, b"Not found")
                return
            try:
                session.capture(parts[3])
            except Exception as error:  # el test debe parar en esta pantalla
                session.error = error
                print(f"Fallo al capturar {parts[3]}: {error}", file=sys.stderr)
                self.reply(500, str(error).encode("utf-8"))
            else:
                self.reply(200, b"Captured")

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    try:
        yield f"http://127.0.0.1:{server.server_port}/{token}/"
    finally:
        server.shutdown()
        server.server_close()
        worker.join(timeout=5)


def run_flutter(udid, url, timeout):
    command = [
        "sh", str(Path.home() / ".agents/scripts/heavy.sh"),
        "flutter", "test", "integration_test/store_ios_test.dart", "-d", udid,
        "--concurrency=1", "--timeout=30m", "--reporter=expanded",
        f"--dart-define=SCREENSHOT_BRIDGE={url}",
    ]
    process = subprocess.Popen(command, cwd=APP, start_new_session=True)
    try:
        if process.wait(timeout=timeout):
            raise RuntimeError("Falló el integration test de Flutter (ver arriba)")
    finally:
        if process.poll() is None:
            # Solo el grupo de procesos creado aquí, por su propio PID.
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()


def capture_all(timeout, udid=None):
    """Crea (o usa) un simulador, captura las cinco pantallas y lo limpia."""
    created = None
    if udid is None:
        created = udid = simctl("create", DEVICE_NAME, DEVICE_TYPE, RUNTIME).decode().strip()
        print(f"Simulador {DEVICE_NAME} creado: {udid}", flush=True)
    session = Session(udid)
    try:
        simctl("boot", udid)
        simctl("bootstatus", udid, "-b", timeout=300)
        status_bar(udid)
        with bridge(session) as url:
            run_flutter(udid, url, timeout)
        if session.error:
            raise session.error
        if session.pending:
            raise RuntimeError(f"Faltan capturas: {session.pending}")
        validate()
    finally:
        failed = False
        steps = [("status_bar", udid, "clear"), ("shutdown", udid)]
        if created:
            steps.append(("delete", udid))  # solo el simulador que creó este script
        for args in steps:
            try:
                simctl(*args)
            except (subprocess.SubprocessError, OSError) as error:
                failed = True
                print(f"Limpieza fallida ({' '.join(args)}): {error}", file=sys.stderr)
        if failed and sys.exc_info()[0] is None:
            raise RuntimeError("Limpieza del simulador fallida (ver arriba)")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--validate", action="store_true", help="Comprueba los PNG; sin simulador")
    parser.add_argument("--udid", help="Usar este simulador ya existente en vez de crear LAB-Shots (no se borra)")
    parser.add_argument("--timeout", type=int, default=7200,
                        help="Segundos para Flutter, incluida la cola de heavy.sh")
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("El tiempo límite debe ser positivo")
    try:
        if args.validate:
            validate()
        else:
            capture_all(args.timeout, args.udid)
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Capturas iOS fallidas: {error}", file=sys.stderr)
        if isinstance(error, subprocess.CalledProcessError) and error.stderr:
            print(error.stderr.decode("utf-8", errors="replace"), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
