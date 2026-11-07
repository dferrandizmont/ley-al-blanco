#!/usr/bin/env python3
"""Capturas de App Store de Ley al Blanco en un simulador iOS real.

Ejecutar con `python3 -I` (Pillow disponible, p. ej. en un venv fuera del repo).
`app/integration_test/store_ios_test.dart` navega por la app real; este script
crea su propio simulador, hace cada captura con `simctl io screenshot` cuando el
test la pide por un puente HTTP local, la enmarca en un iPhone (Dynamic Island,
barra de estado 09:41) bajo el título, y escribe PNG opacos (RGB, sin alfa) en
app/build/store/ios69, ios65 e ios63. No añade nada al punto de entrada ni a
los assets de producción. Ver tool/screenshots/LEEME.md.
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

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "app"
DEVICE_NAME = "LAB-Shots"
DEVICE_TYPE = "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max"
RUNTIME = "com.apple.CoreSimulator.SimRuntime.iOS-26-5"
RAW_SIZE = (1320, 2868)  # iPhone 17 Pro Max: 440 x 956 pt a 3x
BUILD = APP / "build/store"
RAW_DIR = BUILD / "ios-raw"  # capturas sin marco, para --reframe
FONT = APP / "assets/fonts/PublicSans-Variable.ttf"

# Destinos de App Store: carpeta -> tamaño.
TARGETS = {
    "ios69": (1320, 2868),
    "ios65": (1284, 2778),
    "ios63": (1206, 2622),
}

# Esquema de color del test store_screenshots_test.dart (tema claro, tokens de
# lib/core/theme/apto_colors.dart): arena, texto principal y secundario, verde.
BACKGROUND = (0xEF, 0xE9, 0xDD)
TEXT_PRIMARY = (0x1D, 0x24, 0x20)
TEXT_SECONDARY = (0x4F, 0x5A, 0x54)
PRIMARY = (0x2F, 0x5D, 0x50)
FRAME = (0x11, 0x11, 0x11)
WASH = False  # True: velo verde suave bajo el título, como en las capturas de Play

# (nombre, título con \n donde cambia de línea, subtítulo opcional). Mismos que
# test/store/store_screenshots_test.dart.
SHOTS = (
    ("01-preguntas-explicadas", "Las 423 preguntas,\nexplicadas", "Con su artículo del BOE"),
    ("02-simulacro", "Simulacro real:\n20 preguntas,\napto con 16", None),
    ("03-probabilidad", "Tu probabilidad\nde aprobar", None),
    ("04-fallos", "Repasa tus fallos", None),
    ("05-gratis", "Gratis.\nSin anuncios.", None),
)
NAMES = tuple(name for name, _, _ in SHOTS)

# Forma del iPhone, como fracción del ancho de pantalla (Ink Lab / iPhone 17 Pro).
BEZEL, RADIUS = 0.022, 0.14
ISLAND = (126 / 440, 37 / 440, 11 / 440)  # ancho, alto, distancia al borde
LINE = 1.12


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


def font(size):
    f = ImageFont.truetype(str(FONT), size)
    f.set_variation_by_axes([700])  # Public Sans bold, como AptoTypography
    return f


def centered(draw, y, text, fnt, fill, width):
    draw.text(((width - draw.textlength(text, font=fnt)) / 2, y), text,
              font=fnt, fill=fill)


def compose(raw, title, sub, size):
    """Título + iPhone con la captura real. Mismo reparto que el test de Flutter."""
    w, h = size
    canvas = Image.new("RGB", size, BACKGROUND)
    draw = ImageDraw.Draw(canvas)
    cap_size = round(w * .078)
    sub_size = round(cap_size * .5)
    bezel = round(w * .016)  # estimación; se ajusta con el ancho final
    top_pad = h * .04
    caption_block = cap_size * LINE * 3 + 20 + sub_size * 1.3
    gap = h * .02
    top_zone = top_pad + caption_block + gap
    bottom = h * .035
    avail_h = h - top_zone - bottom - 2 * bezel
    avail_w = w * .78 - 2 * bezel
    aspect = raw.height / raw.width
    sw = min(avail_h / aspect, avail_w)
    sw = int(sw // 2 * 2)
    sh = round(sw * aspect)
    bezel = round(BEZEL * sw)
    room = h - top_zone - bottom
    frame_top = round(top_zone + (room - (sh + 2 * bezel)) / 2)

    if WASH:
        wash_h = round(top_zone + sh * .18)
        for y in range(wash_h):
            alpha = .20 * (1 - y / wash_h)
            colour = tuple(round(p * alpha + b * (1 - alpha)) for p, b in zip(PRIMARY, BACKGROUND))
            draw.line((0, y, w, y), fill=colour)

    cap_font, sub_font = font(cap_size), font(sub_size)
    lines = title.split("\n")
    text_h = len(lines) * cap_size * LINE + (20 + sub_size if sub else 0)
    y = top_pad + (top_zone - top_pad - gap - text_h) / 2
    for line in lines:
        centered(draw, y, line, cap_font, TEXT_PRIMARY, w)
        y += cap_size * LINE
    if sub:
        centered(draw, y + 20 - 6, sub, sub_font, TEXT_SECONDARY, w)

    x = (w - sw - 2 * bezel) // 2
    radius = round(RADIUS * sw)
    draw.rounded_rectangle((x, frame_top, x + sw + 2 * bezel, frame_top + sh + 2 * bezel),
                           radius=radius + bezel, fill=FRAME)
    screen = raw.convert("RGB").resize((sw, sh), Image.Resampling.LANCZOS)
    mask = Image.new("L", screen.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *screen.size), radius=radius, fill=255)
    canvas.paste(screen, (x + bezel, frame_top + bezel), mask)
    iw, ih, it = (round(v * sw) for v in ISLAND)
    ix, iy = x + bezel + (sw - iw) // 2, frame_top + bezel + it
    draw.rounded_rectangle((ix, iy, ix + iw, iy + ih), radius=ih // 2, fill=(0, 0, 0))
    return canvas


def check_png(path, size):
    with Image.open(path) as image:
        if image.format != "PNG" or image.size != size or image.mode != "RGB":
            raise RuntimeError(f"{path}: se esperaba PNG RGB {size}, hay "
                               f"{image.format} {image.mode} {image.size}")
        image.load()


def frame_all(only=NAMES):
    """Enmarca las capturas crudas de RAW_DIR en todos los destinos."""
    for target, size in TARGETS.items():
        for name, title, sub in SHOTS:
            if name not in only:
                continue
            with Image.open(RAW_DIR / f"{name}.png") as raw:
                if raw.size != RAW_SIZE:
                    raise RuntimeError(f"{name}: captura de {raw.size}, se esperaba {RAW_SIZE}")
                out = BUILD / target / f"{name}.png"
                out.parent.mkdir(parents=True, exist_ok=True)
                compose(raw, title, sub, size).save(out, optimize=True)
            check_png(out, size)


def validate():
    for target, size in TARGETS.items():
        for name in NAMES:
            check_png(BUILD / target / f"{name}.png", size)
    print(f"OK: {len(TARGETS)} juegos x {len(NAMES)} PNG, RGB sin alfa "
          f"({', '.join(f'{t} {w}x{h}' for t, (w, h) in TARGETS.items())})")


class Session:
    def __init__(self, udid):
        self.udid = udid
        self.pending = list(NAMES)
        self.error = None

    def capture(self, name):
        if not self.pending or name != self.pending[0]:
            raise RuntimeError(f"Captura inesperada {name}; se esperaba {self.pending[:1]}")
        status_bar(self.udid)
        RAW_DIR.mkdir(parents=True, exist_ok=True)
        raw = RAW_DIR / f"{name}.png"
        simctl("io", self.udid, "screenshot", "--type=png", str(raw))
        with Image.open(raw) as image:
            if image.size != RAW_SIZE:
                raise RuntimeError(f"El simulador devolvió {image.size}, se esperaba {RAW_SIZE}")
        frame_all([name])
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
    parser.add_argument("--reframe", action="store_true",
                        help="Reenmarca las capturas crudas de app/build/store/ios-raw; sin simulador")
    parser.add_argument("--udid", help="Usar este simulador ya existente en vez de crear LAB-Shots (no se borra)")
    parser.add_argument("--timeout", type=int, default=7200,
                        help="Segundos para Flutter, incluida la cola de heavy.sh")
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("El tiempo límite debe ser positivo")
    try:
        if args.reframe:
            frame_all()
            validate()
        elif args.validate:
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
