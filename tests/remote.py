#!/usr/bin/env python3
"""The Owner Remote's own scripts, run against a pretend Roblox (no key, no network): the GitHub
workflow's script (from .github/workflows/owner-remote.yml) and the PowerShell remote (remote.ps1,
when pwsh is at hand). Each sends a command to every server (the Messaging Service), then writes it
down in the game's record (Data Stores v1: read, add to the "log", write back only if the version
read is still the latest), so servers that weren't open carry it out when they open.

Checked: the message carries the command, its id and when it was sent; the record is created when
there is none; what the servers wrote is left as it was; a write that crosses another server's is
tried again (nothing lost); the list keeps the last 40 and lets day-old ones go; a key without data
store permission still sends (and says how to fix it); a key that can't publish fails.

Usage (from the repo root):  python3 tests/remote.py [path/to/pwsh]
"""
import base64, hashlib, http.server, json, os, shutil, subprocess, sys, tempfile, threading, time, urllib.parse

import yaml

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UNIVERSE, TOPIC, STORE, KEY_NAME = "10768398256", "MaisonRemote", "MaisonSchedule", "live"
passed = failed = 0


def check(name, ok, detail=""):
    global passed, failed
    if ok:
        passed += 1
    else:
        failed += 1
        print(f"FAIL  {name}" + (f"  -> {detail}" if detail else ""))


class Roblox:
    """A pretend apis.roblox.com: the Messaging Service and one data store entry."""

    def __init__(self):
        self.messages = []
        self.value = None  # the entry's JSON text, or None
        self.version = 0
        self.deny_store = False
        self.deny_publish = False
        self.cross_once = False  # another server writes between this read and write, once
        self.writes = 0
        self.bad_md5 = 0


def handler_for(rb):
    class H(http.server.BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def reply(self, code, body=b"", headers=None):
            self.send_response(code)
            for k, v in (headers or {}).items():
                self.send_header(k, v)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def entry_path(self, u):
            return u.path == f"/datastores/v1/universes/{UNIVERSE}/standard-datastores/datastore/entries/entry"

        def do_GET(self):
            u = urllib.parse.urlparse(self.path)
            q = urllib.parse.parse_qs(u.query)
            if self.headers.get("x-api-key") != "test-key":
                return self.reply(401)
            if not self.entry_path(u) or q.get("datastoreName") != [STORE] or q.get("entryKey") != [KEY_NAME]:
                return self.reply(404)
            if rb.deny_store:
                return self.reply(403, b'{"error":"PERMISSION_DENIED"}')
            if rb.value is None:
                return self.reply(404, b'{"error":"NOT_FOUND"}')
            body = rb.value.encode()
            md5 = base64.b64encode(hashlib.md5(body).digest()).decode()
            return self.reply(200, body, {"roblox-entry-version": f"08D9E6A3F2188CFF.{rb.version:010d}.08D9E6A3F2188CFF.01", "content-md5": md5, "Content-Type": "application/json"})

        def do_POST(self):
            u = urllib.parse.urlparse(self.path)
            q = urllib.parse.parse_qs(u.query)
            body = self.rfile.read(int(self.headers.get("Content-Length") or 0))
            if self.headers.get("x-api-key") != "test-key":
                return self.reply(401)
            if u.path == f"/messaging-service/v1/universes/{UNIVERSE}/topics/{TOPIC}":
                if rb.deny_publish:
                    return self.reply(403, b'{"error":"PERMISSION_DENIED"}')
                rb.messages.append(json.loads(body))
                return self.reply(200)
            if not self.entry_path(u):
                return self.reply(404)
            if rb.deny_store:
                return self.reply(403, b'{"error":"PERMISSION_DENIED"}')
            md5 = base64.b64encode(hashlib.md5(body).digest()).decode()
            if self.headers.get("content-md5") and self.headers.get("content-md5") != md5:
                rb.bad_md5 += 1
                return self.reply(400, b'{"error":"INVALID_ARGUMENT"}')
            if rb.cross_once:
                # Another server writes first: what it wrote is kept, and this write is refused.
                rb.cross_once = False
                rec = json.loads(rb.value) if rb.value else {}
                rec.setdefault("fx", {})["galaxy"] = {"since": time.time(), "by": "another server"}
                rb.value = json.dumps(rec)
                rb.version += 1
            current = f"08D9E6A3F2188CFF.{rb.version:010d}.08D9E6A3F2188CFF.01"
            if q.get("exclusiveCreate") == ["true"]:
                if rb.value is not None:
                    return self.reply(409, b'{"error":"ALREADY_EXISTS"}')
            elif q.get("matchVersion") != [current]:
                return self.reply(409, b'{"error":"PRECONDITION_FAILED"}')
            json.loads(body)  # (must be JSON)
            rb.value = body.decode()
            rb.version += 1
            rb.writes += 1
            return self.reply(200, json.dumps({"version": f"v{rb.version}"}).encode())

    return H


def serve(rb):
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler_for(rb))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server, f"http://127.0.0.1:{server.server_address[1]}"


def workflow():
    with open(os.path.join(ROOT, ".github/workflows/owner-remote.yml"), encoding="utf-8") as f:
        wf = yaml.safe_load(f)
    step = wf["jobs"]["send"]["steps"][0]
    return step["run"], step["env"]


def run_workflow(api, power, words="", style="rainbow", raw="", key="test-key", run_id="777", night=""):
    script, env = workflow()
    tmp = tempfile.mkdtemp()
    summary = os.path.join(tmp, "summary.md")
    e = dict(os.environ)
    e.update({k: str(v) for k, v in env.items() if not str(v).startswith("${{")})
    e.update({"KEY": key, "POWER": power, "WORDS": words, "STYLE": style, "RAW": raw, "NIGHT": night, "API": api, "GITHUB_STEP_SUMMARY": summary, "GITHUB_RUN_ID": run_id, "GITHUB_RUN_ATTEMPT": "1"})
    p = subprocess.run(["bash", "-c", script], env=e, capture_output=True, text=True, timeout=120)
    out = p.stdout + p.stderr
    text = open(summary).read() if os.path.exists(summary) else ""
    shutil.rmtree(tmp, ignore_errors=True)
    return p.returncode, out, text


def last_message(rb):
    return json.loads(rb.messages[-1]["message"]) if rb.messages else {}


def record(rb):
    return json.loads(rb.value) if rb.value else {}


def test_workflow():
    rb = Roblox()
    server, api = serve(rb)
    try:
        before = time.time()
        code, out, summary = run_workflow(api, "☄️ Meteor shower ON")
        m = last_message(rb)
        check("the workflow sends the command to every server", code == 0 and m.get("op") == "fx" and m.get("id") == "meteor" and m.get("on") is True, out)
        check("...with its own id and when it was sent", m.get("rid") == "777-1" and isinstance(m.get("at"), (int, float)) and abs(m["at"] - before) < 30, m)
        rec = record(rb)
        log = rec.get("log") or []
        check("with no record yet, it makes one, the command in its list", len(log) == 1 and log[0]["cmd"]["id"] == "meteor" and log[0]["rid"] == "777-1" and log[0]["at"] == m["at"], rec)
        check("and says it's written down", "Written down" in summary, summary)
        check("the record is sent with its checksum (and it matches)", rb.bad_md5 == 0)

        # What the servers wrote is left alone.
        server_part = {"abuse": {"id": "night-1", "ends": time.time() + 600, "mega": False, "by": "X"}, "fx": {"aurora": {"since": time.time(), "by": "X"}}, "events": {}, "marks": {"fx:aurora": time.time()}}
        server_part["log"] = log
        rb.value = json.dumps(server_part)
        rb.version += 1
        code, out, _ = run_workflow(api, "🧹 Every effect OFF", run_id="778")
        rec = record(rb)
        check("a second command joins the list...", code == 0 and len(rec["log"]) == 2 and rec["log"][-1]["cmd"]["op"] == "fxAllOff", rec)
        check("...and what the servers wrote is untouched", rec.get("abuse", {}).get("id") == "night-1" and "aurora" in rec.get("fx", {}) and "fx:aurora" in rec.get("marks", {}), rec)

        # Another server writes in between: tried again, nothing lost.
        rb.cross_once = True
        code, out, summary = run_workflow(api, "🌋 MEGA ABUSE · 15 min", run_id="779")
        rec = record(rb)
        check("a write crossing another server's is tried again, and nothing is lost", code == 0 and rec["log"][-1]["cmd"]["op"] == "mega" and "galaxy" in rec.get("fx", {}) and "Written down" in summary, out)

        # The list keeps the last 40, and lets day-old ones go.
        old = [{"cmd": {"op": "token"}, "at": time.time() - 90000, "rid": "old"}]
        recent = [{"cmd": {"op": "token"}, "at": time.time() - 100 + i, "rid": f"r{i}"} for i in range(45)]
        rb.value = json.dumps({"log": old + recent})
        rb.version += 1
        code, out, _ = run_workflow(api, "👑 The Owner's Token", run_id="780")
        log = record(rb)["log"]
        check("the list keeps the last forty", len(log) == 40 and log[-1]["rid"] == "780-1", len(log))
        check("...and lets the day-old ones go", all(e["rid"] != "old" for e in log))

        # Admin Abuse's night: chosen (sent with it), or a surprise (none sent: the id decides).
        catalog = json.load(open(os.path.join(ROOT, "tools/remote/commands.json"), encoding="utf-8"))
        midas = next(n for n in catalog["nights"] if n["id"] == "midasHeist")
        code, out, _ = run_workflow(api, "💥 Admin Abuse Night · 15 min", night=midas["glyph"] + " " + midas["name"], run_id="790")
        m = last_message(rb)
        check("Admin Abuse with a night chosen sends that night", code == 0 and m.get("op") == "abuse" and m.get("night") == "midasHeist", m)
        code, out, _ = run_workflow(api, "💥 Admin Abuse Night · 15 min", night=catalog["surprise"], run_id="791")
        m = last_message(rb)
        check("...and a surprise sends none (every server works the same one out of the command's id)", code == 0 and m.get("op") == "abuse" and "night" not in m, m)
        code, out, _ = run_workflow(api, "☄️ Meteor shower ON", night=midas["glyph"] + " " + midas["name"], run_id="792")
        check("...and a night never rides along on anything else", code == 0 and "night" not in last_message(rb), last_message(rb))
        check("fifty-odd nights to choose from", len(catalog["nights"]) >= 50, len(catalog["nights"]))

        # Own words, filtered in the game.
        code, out, _ = run_workflow(api, "📣 Headline: my own words (type them in Words)", words="WELCOME TO ADMIN ABUSE", style="gold", run_id="781")
        m = last_message(rb)
        check("a headline in the owner's own words is sent as words (the game filters them)", code == 0 and m.get("op") == "headline" and m.get("text") == "WELCOME TO ADMIN ABUSE" and m.get("style") == "gold", m)

        # A key that can't use the data stores: still sent, and says how to fix it.
        rb.deny_store = True
        n = len(rb.messages)
        code, out, summary = run_workflow(api, "🪐 Galaxy sky ON", run_id="782")
        check("a key without data store permission still sends to every open server", code == 0 and len(rb.messages) == n + 1 and last_message(rb).get("id") == "galaxy", out)
        check("...and says what to add to the key", "universe-datastores" in out and "::warning::" in out, out)
        rb.deny_store = False

        # A key that can't publish: it fails, plainly.
        rb.deny_publish = True
        code, out, _ = run_workflow(api, "🪐 Galaxy sky ON", run_id="783")
        check("a key that can't publish fails, saying so", code != 0 and "::error::" in out and "403" in out, out)
        rb.deny_publish = False

        # Every power on the list runs.
        catalog = json.load(open(os.path.join(ROOT, "tools/remote/commands.json"), encoding="utf-8"))
        bad = []
        for i, c in enumerate(catalog["commands"][:12]):
            code, out, _ = run_workflow(api, c["label"], run_id=str(900 + i))
            sent = last_message(rb)
            if code != 0 or sent.get("op") != c["command"]["op"]:
                bad.append(c["label"])
        check("each power on the list sends its own command", not bad, bad)
    finally:
        server.shutdown()


def test_powershell(pwsh):
    rb = Roblox()
    server, api = serve(rb)
    try:
        script = os.path.join(ROOT, "remote.ps1")
        tmp = tempfile.mkdtemp()
        env = dict(os.environ)
        env.update({"MAISON_REMOTE_TEST": "1", "MAISON_REMOTE_API": api, "MAISON_REMOTE_KEY": "test-key", "APPDATA": tmp})
        cmd = '. "' + script + '"; Send-Command \'{"op":"fx","id":"ufo","on":true}\'; Send-Command \'{"op":"abuse","minutes":15}\''
        p = subprocess.run([pwsh, "-NoProfile", "-NonInteractive", "-Command", cmd], env=env, capture_output=True, text=True, timeout=120)
        out = p.stdout + p.stderr
        check("the PowerShell remote sends to every server", len(rb.messages) == 2 and last_message(rb).get("op") == "abuse" and isinstance(last_message(rb).get("at"), (int, float)) and len(str(last_message(rb).get("rid", ""))) >= 16, out)
        log = record(rb).get("log") or []
        check("...and writes both down, in order", len(log) == 2 and log[0]["cmd"]["id"] == "ufo" and log[1]["cmd"]["op"] == "abuse", out)
        check("...with matching checksums", rb.bad_md5 == 0, out)
        rb.cross_once = True
        p = subprocess.run([pwsh, "-NoProfile", "-NonInteractive", "-Command", '. "' + script + '"; Send-Command \'{"op":"token"}\''], env=env, capture_output=True, text=True, timeout=120)
        rec = record(rb)
        check("...trying again when another server wrote in between", rec["log"][-1]["cmd"]["op"] == "token" and "galaxy" in rec.get("fx", {}), p.stdout + p.stderr)
        rb.deny_store = True
        p = subprocess.run([pwsh, "-NoProfile", "-NonInteractive", "-Command", '. "' + script + '"; Send-Command \'{"op":"token"}\''], env=env, capture_output=True, text=True, timeout=120)
        out = p.stdout + p.stderr
        check("...and without data store permission it still sends, and says what to add", last_message(rb).get("op") == "token" and "universe-datastores" in out, out)
        rb.deny_store = False
        p = subprocess.run([pwsh, "-NoProfile", "-NonInteractive", "-Command", '. "' + script + '"; Send-Command (Add-Night \'{"op":"mega","minutes":15}\' \'midas\'); Send-Command (Add-Night \'{"op":"token"}\' \'midas\')'], env=env, capture_output=True, text=True, timeout=120)
        sent = [json.loads(x["message"]) for x in rb.messages[-2:]]
        check("the PowerShell remote sends the night asked for with Mega Abuse (and never with anything else)", sent[0].get("op") == "mega" and sent[0].get("night") == "midasHeist" and "night" not in sent[1], p.stdout + p.stderr)
        shutil.rmtree(tmp, ignore_errors=True)
    finally:
        server.shutdown()


if __name__ == "__main__":
    test_workflow()
    pwsh = sys.argv[1] if len(sys.argv) > 1 else shutil.which("pwsh")
    if pwsh and os.path.exists(pwsh):
        test_powershell(pwsh)
    else:
        print("(no pwsh: the PowerShell remote wasn't tried)")
    print(f"remote: {passed} passed, {failed} failed")
    sys.exit(1 if failed else 0)
