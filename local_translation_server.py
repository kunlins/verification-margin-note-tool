#!/usr/bin/env python3
"""
Local-only web and translation service for the prospectus margin note tool.

The server binds to 127.0.0.1 and exposes:
- GET /                    the HTML tool
- GET /health              translation readiness
- POST /translate          one text item
- POST /translate-batch    multiple text items
"""

from __future__ import annotations

import argparse
import json
import os
import socket
import sys
import threading
import time
import webbrowser
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent
HTML_FILE = ROOT / "margin_note_tool_v3_word_pdf.html"
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8765
LAST_ACTIVITY = time.monotonic()


def configure_certificates() -> None:
    try:
        import certifi  # type: ignore

        ca_file = certifi.where()
        os.environ.setdefault("SSL_CERT_FILE", ca_file)
        os.environ.setdefault("REQUESTS_CA_BUNDLE", ca_file)
    except Exception:
        pass


def normalize_lang(code: str) -> str:
    code = (code or "").strip().lower().replace("_", "-")
    aliases = {
        "en-us": "en",
        "en-gb": "en",
        "zh-cn": "zh",
        "zh-hans": "zh",
        "zh-sg": "zh",
        "chinese": "zh",
        "english": "en",
    }
    return aliases.get(code, code or "en")


class ArgosEngine:
    def __init__(self) -> None:
        self._translate_module = None
        self._error = ""

    def _load(self) -> bool:
        if self._translate_module:
            return True
        try:
            import argostranslate.translate as translate_module  # type: ignore

            self._translate_module = translate_module
            self._error = ""
            return True
        except Exception as exc:  # pragma: no cover - depends on local install
            self._error = str(exc)
            return False

    def get_translation(self, source: str = "en", target: str = "zh") -> Any:
        source = normalize_lang(source)
        target = normalize_lang(target)
        if not self._load():
            raise RuntimeError(
                "Argos Translate is not installed. Run install_local_translator first."
            )
        languages = self._translate_module.get_installed_languages()
        from_lang = next((lang for lang in languages if lang.code == source), None)
        to_lang = next((lang for lang in languages if lang.code == target), None)
        if not from_lang or not to_lang:
            raise RuntimeError(
                f"Translation model {source}->{target} is not installed. "
                "Run install_local_translator first."
            )
        return from_lang.get_translation(to_lang)

    def ready(self, source: str = "en", target: str = "zh") -> tuple[bool, str]:
        try:
            self.get_translation(source, target)
            return True, "ready"
        except Exception as exc:
            return False, str(exc)

    def translate(self, text: str, source: str = "en", target: str = "zh") -> str:
        text = (text or "").strip()
        if not text:
            return ""
        translation = self.get_translation(source, target)
        return translation.translate(text).strip()


ENGINE = ArgosEngine()


def install_model(source: str = "en", target: str = "zh") -> None:
    source = normalize_lang(source)
    target = normalize_lang(target)
    try:
        import argostranslate.package as package_module  # type: ignore
    except Exception as exc:
        raise RuntimeError(
            "Argos Translate is not installed. Please install requirements first."
        ) from exc

    print(f"Checking installed model {source}->{target}...")
    ready, message = ENGINE.ready(source, target)
    if ready:
        print("Model is already installed.")
        return

    print("Downloading Argos package index...")
    package_module.update_package_index()
    available_packages = package_module.get_available_packages()
    package = next(
        (
            item
            for item in available_packages
            if item.from_code == source and item.to_code == target
        ),
        None,
    )
    if not package:
        raise RuntimeError(f"No Argos package found for {source}->{target}.")

    print(f"Downloading model {source}->{target}. This can take several minutes...")
    download_path = package.download()
    print("Installing model...")
    package_module.install_from_path(download_path)
    ready, message = ENGINE.ready(source, target)
    if not ready:
        raise RuntimeError(message)
    print("Model installed successfully.")


class Handler(SimpleHTTPRequestHandler):
    server_version = "ProspectusLocalTranslator/1.0"

    def __init__(self, *args: Any, **kwargs: Any) -> None:
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def end_headers(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Private-Network", "true")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def touch_activity(self) -> None:
        global LAST_ACTIVITY
        LAST_ACTIVITY = time.monotonic()

    def log_message(self, fmt: str, *args: Any) -> None:
        sys.stderr.write("[%s] %s\n" % (self.log_date_time_string(), fmt % args))

    def do_OPTIONS(self) -> None:
        self.touch_activity()
        self.send_response(HTTPStatus.NO_CONTENT)
        self.end_headers()

    def do_GET(self) -> None:
        self.touch_activity()
        if self.path in ("/", "/index.html"):
            self.path = "/" + HTML_FILE.name
            return super().do_GET()
        if self.path.startswith("/health"):
            ready, message = ENGINE.ready("en", "zh")
            return self.write_json(
                {"ok": True, "ready": ready, "engine": "argos", "message": message}
            )
        return super().do_GET()

    def do_HEAD(self) -> None:
        self.touch_activity()
        if self.path in ("/", "/index.html"):
            self.path = "/" + HTML_FILE.name
        return super().do_HEAD()

    def do_POST(self) -> None:
        self.touch_activity()
        if self.path == "/translate":
            return self.handle_translate()
        if self.path == "/translate-batch":
            return self.handle_translate_batch()
        if self.path == "/shutdown":
            return self.handle_shutdown()
        self.write_json({"error": "not found"}, HTTPStatus.NOT_FOUND)

    def read_json(self) -> dict[str, Any]:
        length = int(self.headers.get("Content-Length", "0") or "0")
        raw = self.rfile.read(length) if length else b"{}"
        return json.loads(raw.decode("utf-8") or "{}")

    def write_json(self, data: dict[str, Any], status: int = HTTPStatus.OK) -> None:
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def handle_translate(self) -> None:
        try:
            payload = self.read_json()
            text = str(payload.get("text") or "")
            source = str(payload.get("source") or "en")
            target = str(payload.get("target") or "zh")
            translated = ENGINE.translate(text, source, target)
            self.write_json({"ok": True, "translatedText": translated})
        except Exception as exc:
            self.write_json({"ok": False, "error": str(exc)}, HTTPStatus.SERVICE_UNAVAILABLE)

    def handle_translate_batch(self) -> None:
        try:
            payload = self.read_json()
            source = str(payload.get("source") or "en")
            target = str(payload.get("target") or "zh")
            items = payload.get("items") or []
            result = []
            for item in items:
                uid = str(item.get("uid") or "")
                text = str(item.get("text") or "")
                result.append(
                    {
                        "uid": uid,
                        "translatedText": ENGINE.translate(text, source, target),
                    }
                )
            self.write_json({"ok": True, "items": result})
        except Exception as exc:
            self.write_json({"ok": False, "error": str(exc)}, HTTPStatus.SERVICE_UNAVAILABLE)

    def handle_shutdown(self) -> None:
        self.write_json({"ok": True})
        threading.Thread(target=self.server.shutdown, daemon=True).start()


def port_available(host: str, port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.settimeout(0.2)
        return sock.connect_ex((host, port)) != 0


def choose_port(host: str, preferred: int) -> int:
    for port in range(preferred, preferred + 50):
        if port_available(host, port):
            return port
    raise RuntimeError("No available local port found.")


def start_idle_monitor(server: ThreadingHTTPServer, idle_timeout: int) -> None:
    if idle_timeout <= 0:
        return

    def monitor() -> None:
        while True:
            time.sleep(min(60, max(5, idle_timeout // 4)))
            if time.monotonic() - LAST_ACTIVITY >= idle_timeout:
                print(f"No local translation activity for {idle_timeout} seconds. Stopping service...")
                server.shutdown()
                return

    threading.Thread(target=monitor, daemon=True).start()


def run_server(host: str, port: int, open_browser: bool, idle_timeout: int = 0) -> None:
    port = choose_port(host, port)
    url = f"http://{host}:{port}/"
    server = ThreadingHTTPServer((host, port), Handler)
    print(f"Local tool is running at {url}")
    ready, message = ENGINE.ready("en", "zh")
    print("Translation status:", "ready" if ready else message)
    start_idle_monitor(server, idle_timeout)
    if open_browser:
        threading.Thread(target=lambda: (time.sleep(0.5), webbrowser.open(url)), daemon=True).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping local tool...")
    finally:
        server.server_close()


def main() -> int:
    configure_certificates()
    parser = argparse.ArgumentParser(description="Run the local prospectus margin note tool.")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--no-browser", action="store_true")
    parser.add_argument("--install-model", action="store_true")
    parser.add_argument("--idle-timeout", type=int, default=0)
    parser.add_argument("--source", default="en")
    parser.add_argument("--target", default="zh")
    args = parser.parse_args()

    if args.install_model:
        install_model(args.source, args.target)
        return 0

    run_server(args.host, args.port, not args.no_browser, args.idle_timeout)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
