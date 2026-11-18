#!/usr/bin/env python3
"""Checks tools/badges/create_badges.py against a stand-in for Roblox's badges API on this machine
(no request ever leaves it): the dry run sends nothing; no key, no calls; the free ones are made
with their pictures, read back and written into Config.luau; when the free ones run out it stops
without paying; --pay spends only what's allowed; nothing is made twice; the key is never written.

Run:  python tools/badges/test_create_badges.py
"""

from __future__ import annotations

import io
import json
import os
import re
import shutil
import sys
import tempfile
import threading
from contextlib import redirect_stderr, redirect_stdout
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import create_badges as tool  # noqa: E402

FAKE_KEY = "test-key-not-real-0123456789"
failures = 0


def check(name: str, ok: bool, detail: str = "") -> None:
    global failures
    print(("PASS  " if ok else "FAIL  ") + name + (f"  -> {detail}" if detail and not ok else ""))
    if not ok:
        failures += 1


class Roblox:
    free_left = 2
    next_id = 9001
    made: list[dict] = []
    keys_seen: list[str] = []


def parse_multipart(body: bytes, ctype: str) -> dict:
    boundary = ctype.split("boundary=")[1].encode()
    out = {}
    for part in body.split(b"--" + boundary):
        if b"Content-Disposition" not in part:
            continue
        head, _, data = part.partition(b"\r\n\r\n")
        data = data[:-2] if data.endswith(b"\r\n") else data
        name = re.search(rb'name="([^"]+)"', head).group(1).decode()
        if b"filename=" in head:
            out[name] = {"filename": re.search(rb'filename="([^"]+)"', head).group(1).decode(), "bytes": data}
        else:
            out[name] = data.decode()
    return out


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def reply(self, status: int, payload) -> None:
        raw = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_POST(self):
        Roblox.keys_seen.append(self.headers.get("x-api-key", ""))
        m = re.match(r"^/legacy-badges/v1/universes/(\d+)/badges$", self.path)
        if not m:
            return self.reply(404, {"errors": [{"code": 3}]})
        body = self.rfile.read(int(self.headers["Content-Length"]))
        form = parse_multipart(body, self.headers["Content-Type"])
        cost = int(form.get("expectedCost", "0"))
        actual = 0 if Roblox.free_left > 0 else 100
        if cost != actual:
            return self.reply(400, {"errors": [{"code": 18, "message": "Expected badge cost is different from the actual badge cost."}]})
        if Roblox.free_left > 0:
            Roblox.free_left -= 1
        Roblox.next_id += 1
        Roblox.made.append({"id": Roblox.next_id, "form": form, "cost": cost})
        return self.reply(200, {"id": Roblox.next_id, "name": form["name"], "description": form["description"], "enabled": form["isActive"] == "true"})

    def do_GET(self):
        m = re.match(r"^/v1/badges/(\d+)$", self.path)
        ids = [b["id"] for b in Roblox.made]
        if m and int(m.group(1)) in ids:
            return self.reply(200, {"id": int(m.group(1))})
        return self.reply(404, {})


def run(args: list[str], key: str | None) -> tuple[int, str]:
    if key is None:
        os.environ.pop("ROBLOX_API_KEY", None)
    else:
        os.environ["ROBLOX_API_KEY"] = key
    out = io.StringIO()
    with redirect_stdout(out), redirect_stderr(out):
        code = tool.main(args)
    return code, out.getvalue()


def main() -> int:
    tmp = Path(tempfile.mkdtemp(prefix="badges-test-"))
    try:
        (tmp / "icons").mkdir()
        shutil.copy(tool.CONFIG, tmp / "Config.luau")
        for f in tool.ICONS.iterdir():
            shutil.copy(f, tmp / "icons" / f.name)
        tool.CONFIG = tmp / "Config.luau"
        tool.ICONS = tmp / "icons"
        tool.MAPPING = tmp / "icons" / "MAPPING.md"
        tool.LEDGER = tmp / "icons" / "created.json"
        server = HTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        base = f"http://127.0.0.1:{server.server_port}"
        common = ["--universe", "123", "--api-base", base, "--public-base", base, "--sleep", "0"]
        before = tool.CONFIG.read_text(encoding="utf-8")

        code, out = run(common, FAKE_KEY)
        check("a dry run sends nothing and changes nothing", code == 0 and not Roblox.made and not Roblox.keys_seen and tool.CONFIG.read_text(encoding="utf-8") == before and "Dry run" in out, out)
        check("...and lists the house's headline badges first", out.index("nights_1") < out.index("crownJewel") < out.index("executiveBoss"), out)

        code, out = run(common + ["--go"], None)
        check("without ROBLOX_API_KEY: stops, no request", code == 1 and not Roblox.keys_seen and "ROBLOX_API_KEY" in out, out)

        code, out = run(common + ["--go"], FAKE_KEY)
        made = [b["form"]["name"] for b in Roblox.made]
        check("the free ones are made (two left today here), then it stops without paying", code == 0 and made == ["Welcome to the Maison", "The Crown Jewel"] and all(b["cost"] == 0 for b in Roblox.made) and "free badges are used up" in out, out)
        first = Roblox.made[0]["form"]
        icon = (tool.ICONS / "nights_1.png").read_bytes()
        check("...each with its picture, name, description, switched on", first["files"]["bytes"] == icon and first["files"]["filename"] == "nights_1.png" and first["description"].startswith("Join the Maison") and first["isActive"] == "true", str({k: v for k, v in first.items() if k != "files"}))
        check("...the key sent only in the x-api-key header", all(k == FAKE_KEY for k in Roblox.keys_seen))
        cfg = tool.CONFIG.read_text(encoding="utf-8")
        ids, _ = tool.read_config_ids(cfg)
        check("...their ids written into Config.Badges (replacing the 0, or added)", ids.get("nights_1") == 9002 and ids.get("crownJewel") == 9003, f"{ids.get('nights_1')} {ids.get('crownJewel')}")
        check("...the existing id kept", ids.get("basementSecrets") == 2281422215983983)
        ledger = json.loads(tool.LEDGER.read_text(encoding="utf-8"))
        check("...and in the ledger, with what each cost", ledger["nights_1"]["id"] == 9002 and ledger["crownJewel"]["robux"] == 0)
        written = cfg + tool.LEDGER.read_text(encoding="utf-8")
        check("the key is never written to a file", FAKE_KEY not in written)

        code, out = run(common + ["--go", "--pay"], FAKE_KEY)
        check("--pay without a price and a limit: refused", code == 1 and "--robux-each" in out and len(Roblox.made) == 2, out)

        code, out = run(common + ["--go", "--pay", "--robux-each", "100", "--max-robux", "100", "--count", "3"], FAKE_KEY)
        check("--pay: spends only up to the limit (one badge at 100), then stops", code == 0 and len(Roblox.made) == 3 and Roblox.made[2]["cost"] == 100 and Roblox.made[2]["form"]["name"] == "The Treasury" and "100 Robux spent" in out, out)

        code, out = run(common + ["--keys", "nights_1"], FAKE_KEY)
        check("never made twice", code == 1 and "already made" in out, out)

        code, out = run(common + ["--go", "--keys", "nope"], FAKE_KEY)
        check("a key that isn't in the Badge Book: refused", code == 1 and len(Roblox.made) == 3, out)
        server.shutdown()
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print(f"\n{'all passed' if failures == 0 else str(failures) + ' failed'}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
