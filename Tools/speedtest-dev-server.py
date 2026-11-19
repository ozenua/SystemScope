#!/usr/bin/env python3
"""Local development speed-test server for SystemScope.

DEVELOPMENT ONLY. It implements the endpoint contract the app's SpeedTest module
expects, so the client can be exercised end to end on a simulator. It is not the
production service: that needs HTTPS, regional deployment, rate limiting and
operational logging (see the Internet Speed Test development note, section 4).

    GET  /speed/config            -> {"serverRegion": "local-dev"}
    GET  /speed/ping              -> 204, no body
    GET  /speed/download?bytes=N  -> N random bytes, exact Content-Length
    POST /speed/upload            -> {"success": true, "bytesReceived": N, ...}

Uploaded bodies are read and discarded; nothing is written to disk.

Usage:
    python3 Tools/speedtest-dev-server.py [port] [mbps-per-connection]
        port                  default 8787, loopback only
        mbps-per-connection   optional throttle. Loopback is otherwise multi-gigabit,
                              which uses up the data budget before a phase can be
                              watched; 20 gives a test that behaves like a real link.
Then launch the app with:  -SpeedTestServer http://127.0.0.1:8787
"""
import json
import os
import sys
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

MAX_DOWNLOAD_BYTES = 100_000_000
CHUNK_SIZE = 16 * 1024
CHUNK = os.urandom(CHUNK_SIZE)
# Seconds to wait per chunk when throttled; 0 means unthrottled.
CHUNK_DELAY = 0.0


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        pass

    def _headers(self, status, length, content_type=None):
        self.send_response(status)
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self.send_header("Content-Length", str(length))
        if content_type:
            self.send_header("Content-Type", content_type)
        self.end_headers()

    def _json(self, payload):
        body = json.dumps(payload).encode()
        self._headers(200, len(body), "application/json")
        self.wfile.write(body)

    def do_GET(self):
        url = urlparse(self.path)
        if url.path == "/speed/ping":
            self._headers(204, 0)
        elif url.path == "/speed/config":
            self._json({"serverRegion": "local-dev"})
        elif url.path == "/speed/download":
            try:
                count = int(parse_qs(url.query).get("bytes", ["0"])[0])
            except ValueError:
                count = 0
            count = max(0, min(count, MAX_DOWNLOAD_BYTES))
            self._headers(200, count, "application/octet-stream")
            remaining = count
            try:
                while remaining > 0:
                    piece = CHUNK[: min(CHUNK_SIZE, remaining)]
                    self.wfile.write(piece)
                    remaining -= len(piece)
                    if CHUNK_DELAY:
                        time.sleep(CHUNK_DELAY)
            except (BrokenPipeError, ConnectionResetError):
                pass  # the client cancelled
        else:
            self._headers(404, 0)

    def do_POST(self):
        if urlparse(self.path).path != "/speed/upload":
            self._headers(404, 0)
            return
        remaining = int(self.headers.get("Content-Length", "0"))
        received = 0
        try:
            while remaining > 0:
                piece = self.rfile.read(min(CHUNK_SIZE, remaining))
                if not piece:
                    break
                received += len(piece)
                remaining -= len(piece)
                if CHUNK_DELAY:
                    time.sleep(CHUNK_DELAY)
        except ConnectionResetError:
            return
        self._json({
            "success": remaining == 0,
            "bytesReceived": received,
            "serverRegion": "local-dev",
            "timestamp": datetime.now(timezone.utc).isoformat(),
        })


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8787
    if len(sys.argv) > 2:
        CHUNK_DELAY = CHUNK_SIZE * 8 / (float(sys.argv[2]) * 1_000_000)
    print(f"SystemScope dev speed-test server on http://127.0.0.1:{port} (Ctrl-C to stop)")
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
