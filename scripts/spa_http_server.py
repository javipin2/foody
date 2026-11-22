# Servidor estatico simple con fallback SPA (index.html) para Flutter web.
# Uso: python scripts/spa_http_server.py 8080 build/web_equipo

from __future__ import annotations

import mimetypes
import os
import sys
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class SpaHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, directory: str | None = None, **kwargs):
        super().__init__(*args, directory=directory, **kwargs)

    def end_headers(self):
        # Evitar cache agresivo en demo tunel
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def do_GET(self):
        path = self.translate_path(self.path)
        if os.path.isdir(path):
            index = os.path.join(path, "index.html")
            if os.path.isfile(index):
                return super().do_GET()
        if os.path.isfile(path):
            return super().do_GET()
        # SPA fallback
        self.path = "/index.html"
        return super().do_GET()

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))


def main():
    if len(sys.argv) < 3:
        print("Uso: python spa_http_server.py <puerto> <directorio>", file=sys.stderr)
        sys.exit(1)
    port = int(sys.argv[1])
    root = Path(sys.argv[2]).resolve()
    if not (root / "index.html").is_file():
        print(f"No hay index.html en {root}", file=sys.stderr)
        sys.exit(1)
    # Bind 127.0.0.1: Cloudflare Tunnel apunta a 127.0.0.1
    handler = partial(SpaHandler, directory=str(root))
    httpd = ThreadingHTTPServer(("127.0.0.1", port), handler)
    print(f"SPA http://127.0.0.1:{port} -> {root}", flush=True)
    httpd.serve_forever()


if __name__ == "__main__":
    main()
