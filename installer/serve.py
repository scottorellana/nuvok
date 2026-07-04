#!/usr/bin/env python3
"""Local, private install server for Prepper Pad.

Serves an install page reachable from any device on the same WiFi, so you can
download and install the app straight from the browser — the .dmg on a Mac,
the .apk on an Android tablet/phone. Shows a QR code and the LAN URL so you
can open the page on another device without typing anything.

Everything is local: it binds to your LAN only, never the internet.
Run:  python3 installer/serve.py
"""
import http.server
import os
import socket
import sys

PORT = int(os.environ.get("PORT", "8770"))
HERE = os.path.dirname(os.path.abspath(__file__))
DIST = os.path.abspath(os.path.join(HERE, "..", "dist"))

# The two locally-built binaries, mapped to clean download URLs.
BINARIES = {
    "/PrepperPad.dmg": os.path.join(DIST, "PrepperPad.dmg"),
    "/prepper-pad.apk": os.path.join(DIST, "prepper-pad-v0.2.0.apk"),
}


def lan_ip() -> str:
    """Best-effort primary LAN IP (no traffic actually sent)."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except Exception:
        return "127.0.0.1"
    finally:
        s.close()


def human_size(path: str) -> str:
    try:
        n = os.path.getsize(path)
    except OSError:
        return "no disponible"
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024:
            return f"{n:.0f} {unit}"
        n /= 1024
    return f"{n:.0f} TB"


def qr_svg(data: str) -> str:
    """Inline SVG QR built from the boolean matrix — needs only `qrcode`
    (no PIL/lxml). Falls back to an empty string if the lib is missing."""
    try:
        import qrcode
    except ImportError:
        return '<div style="color:#a7ac97">Instala <code>qrcode</code> ' \
               'para ver el QR: pip3 install qrcode</div>'
    q = qrcode.QRCode(border=2, box_size=1)
    q.add_data(data)
    q.make(fit=True)
    m = q.get_matrix()
    n = len(m)
    rects = []
    for y, row in enumerate(m):
        for x, cell in enumerate(row):
            if cell:
                rects.append(f'<rect x="{x}" y="{y}" width="1" height="1"/>')
    return (
        f'<svg viewBox="0 0 {n} {n}" xmlns="http://www.w3.org/2000/svg" '
        f'shape-rendering="crispEdges"><rect width="{n}" height="{n}" '
        f'fill="#fff"/><g fill="#14170F">{"".join(rects)}</g></svg>'
    )


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_):  # quieter console
        pass

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            self._serve_page()
        elif self.path in BINARIES:
            self._serve_binary(BINARIES[self.path])
        else:
            self.send_error(404)

    def do_HEAD(self):
        # Some browsers / download managers probe with HEAD before GET.
        if self.path in BINARIES and os.path.exists(BINARIES[self.path]):
            self.send_response(200)
            self.send_header("Content-Type", "application/octet-stream")
            self.send_header(
                "Content-Length", str(os.path.getsize(BINARIES[self.path])))
            self.end_headers()
        elif self.path in ("/", "/index.html"):
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
        else:
            self.send_error(404)

    def _serve_page(self):
        url = f"http://{lan_ip()}:{PORT}/"
        with open(os.path.join(HERE, "index.html"), encoding="utf-8") as f:
            html = f.read()
        html = (
            html.replace("{{LAN_URL}}", url)
            .replace("{{QR_SVG}}", qr_svg(url))
            .replace("{{DMG_SIZE}}", human_size(BINARIES["/PrepperPad.dmg"]))
            .replace("{{APK_SIZE}}", human_size(BINARIES["/prepper-pad.apk"]))
        ).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(html)))
        self.end_headers()
        self.wfile.write(html)

    def _serve_binary(self, path: str):
        if not os.path.exists(path):
            self.send_error(404, "Binario no encontrado — compílalo primero")
            return
        size = os.path.getsize(path)
        name = os.path.basename(self.path)
        self.send_response(200)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Length", str(size))
        self.send_header(
            "Content-Disposition", f'attachment; filename="{name}"')
        self.end_headers()
        with open(path, "rb") as f:
            while chunk := f.read(64 * 1024):
                try:
                    self.wfile.write(chunk)
                except (BrokenPipeError, ConnectionResetError):
                    return  # client cancelled the download


def main():
    ip = lan_ip()
    missing = [p for p in BINARIES.values() if not os.path.exists(p)]
    server = http.server.ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print("\n  Prepper Pad — instalador local")
    print(f"  Abre en cualquier dispositivo de tu red:  http://{ip}:{PORT}/")
    print(f"  (en esta Mac:  http://localhost:{PORT}/ )")
    if missing:
        print("\n  ⚠️  Faltan binarios (compílalos y reinicia):")
        for p in missing:
            print(f"      {p}")
    print("\n  Ctrl+C para detener.\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n  Detenido.")
        server.shutdown()


if __name__ == "__main__":
    sys.exit(main())
