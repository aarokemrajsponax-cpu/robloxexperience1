#!/usr/bin/env python3
"""Make the Badge Book's badges real Roblox badges (with their pictures), a few at a time.

Each badge in the game's Badge Book (src/shared/BadgeBook.luau) already has its medal picture in
assets/badge-icons (512 x 512, see MAPPING.md). This tool creates the matching badge on Roblox
through Roblox's Open Cloud badges endpoint, with that picture, name and description, checks that
Roblox really has it, and writes its new id into src/shared/Config.luau -> Badges. From then on the
game awards it (server/Achievements: as it's earned, and on the next visit to anyone who earned it
before), and it shows in the Badges of each player's Roblox inventory and profile.

Safe by default:
  * Nothing is sent unless you add --go. Without it, it only lists what it would make.
  * The Open Cloud key is read from the ROBLOX_API_KEY environment variable only. It is never
    asked for on the command line, never printed and never written to a file.
  * Roblox makes 5 badges free per game every 24 hours (GMT); after that each costs 100 Robux.
    This tool asks Roblox for the free price only (expectedCost 0): if the free ones for today are
    used up, Roblox refuses and nothing is charged. Paying is possible only with --pay, which needs
    both --robux-each (the price Roblox shows) and --max-robux (the most you'll spend this run).
  * A badge that already has an id in Config.luau (or in assets/badge-icons/created.json) is never
    made twice.

Use (in the project folder):
  1. Creator Hub -> Open Cloud -> API Keys -> Create API Key. Add the "legacy-universe.badge" API
     system with the scope legacy-universe.badge:manage-and-spend-robux (and :write), for this
     experience. Copy the key.
  2. Set it for this window only (PowerShell):   $env:ROBLOX_API_KEY = "<the key>"
     (macOS/Linux: export ROBLOX_API_KEY=...). Don't paste it anywhere else.
  3. Your experience's Universe ID: Creator Hub -> the experience -> the "..." menu -> Copy Universe ID.
  4. Look first:   python tools/badges/create_badges.py --universe 1234567890
     Then make today's five:   python tools/badges/create_badges.py --universe 1234567890 --go
  5. Sync and publish as usual (play.ps1, Rojo Connect, Publish). Run it again tomorrow for the
     next five.

Roblox marks this endpoint "experimental"; the tool re-reads each badge after making it, as
Roblox's own documentation advises, and stops at the first thing that doesn't add up.
"""

from __future__ import annotations

import argparse
import json
import mimetypes
import os
import re
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONFIG = ROOT / "src" / "shared" / "Config.luau"
ICONS = ROOT / "assets" / "badge-icons"
MAPPING = ICONS / "MAPPING.md"
LEDGER = ICONS / "created.json"

API = "https://apis.roblox.com"
PUBLIC = "https://badges.roblox.com"
FREE_PER_DAY = 5

# The order to make them in: the house's headline badges first (the ones worth showing on a
# profile), five a day, then everything else in Config.Badges' order, then the rest of the Badge
# Book. Day 1 is the welcome and each attraction's big win; day 2 the races, the auction, the
# events and the coming holidays; day 3 the fortunes.
RECOMMENDED = [
    "nights_1", "crownJewel", "basementClear", "executiveBoss", "firstFlight",
    "gpWin", "auctionWin", "abuseNight", "holiday_thanksgiving", "holiday_christmas",
    "gilt_1000000", "giltEarned_100000", "firstLastLamp", "mythic", "level_10",
]


class Stop(Exception):
    pass


def read_mapping(path: Path) -> list[dict]:
    """The Badge Book's badges, in MAPPING.md's order: key, name, description, tier, file."""
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^\|\s*`([^`]+)`\s*\|(.*)\|(.*)\|(.*)\|\s*`([^`]+)`\s*\|\s*$", line)
        if m:
            rows.append({
                "key": m.group(1).strip(),
                "name": m.group(2).strip(),
                "description": m.group(3).strip(),
                "tier": m.group(4).strip(),
                "file": m.group(5).strip(),
            })
    return rows


def badges_block(text: str) -> tuple[int, int]:
    """Where Config.luau's `Badges = { ... }` table starts and ends (character offsets)."""
    start = text.find("\tBadges = {")
    if start < 0:
        raise Stop("Couldn't find `Badges = {` in Config.luau.")
    end = text.find("\n\t},", start)
    if end < 0:
        raise Stop("Couldn't find the end of the Badges table in Config.luau.")
    return start, end


def read_config_ids(text: str) -> tuple[dict[str, int], list[str]]:
    """Each key's id in Config.Badges (0 = not made yet), and the keys in the order listed."""
    start, end = badges_block(text)
    ids: dict[str, int] = {}
    order: list[str] = []
    for m in re.finditer(r"^\t\t([A-Za-z_][A-Za-z0-9_]*) = (\d+),", text[start:end], re.M):
        ids[m.group(1)] = int(m.group(2))
        order.append(m.group(1))
    return ids, order


def write_config_id(text: str, key: str, badge_id: int) -> str:
    """Config.luau with `key = <id>` in its Badges table (replacing a 0, or added at the end)."""
    start, end = badges_block(text)
    block = text[start:end]
    pattern = re.compile(r"^(\t\t" + re.escape(key) + r" = )(\d+)(,)", re.M)
    m = pattern.search(block)
    if m:
        if int(m.group(2)) not in (0, badge_id):
            raise Stop(f"Config.luau already has a different id for {key}; not changing it.")
        block = block[: m.start(2)] + str(badge_id) + block[m.end(2):]
    else:
        marker = "\t\t-- (Older keys"
        at = block.find(marker)
        line = f"\t\t{key} = {badge_id},\n"
        block = block[:at] + line + block[at:] if at >= 0 else block + "\n" + line.rstrip("\n")
    return text[:start] + block + text[end:]


def read_ledger() -> dict:
    if LEDGER.exists():
        return json.loads(LEDGER.read_text(encoding="utf-8"))
    return {}


def plan(mapping: list[dict], ids: dict[str, int], order: list[str], ledger: dict) -> list[dict]:
    """The badges still to make: RECOMMENDED first, then those listed in Config.Badges (its order),
    then the rest of the Badge Book in MAPPING.md's order. Never one that already has an id."""
    by_key = {r["key"]: r for r in mapping}
    out, seen = [], set()
    for key in RECOMMENDED + order + [r["key"] for r in mapping]:
        if key in seen or key not in by_key:
            continue
        seen.add(key)
        if ids.get(key, 0) > 0 or key in ledger:
            continue
        out.append(by_key[key])
    return out


def multipart(fields: dict[str, str], file_field: str, file_path: Path) -> tuple[bytes, str]:
    boundary = "----maison" + uuid.uuid4().hex
    parts = []
    for name, value in fields.items():
        parts.append(
            f"--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\"\r\n\r\n{value}\r\n".encode("utf-8")
        )
    ctype = mimetypes.guess_type(file_path.name)[0] or "image/png"
    parts.append(
        (
            f"--{boundary}\r\nContent-Disposition: form-data; name=\"{file_field}\"; filename=\"{file_path.name}\"\r\n"
            f"Content-Type: {ctype}\r\n\r\n"
        ).encode("utf-8")
        + file_path.read_bytes()
        + b"\r\n"
    )
    parts.append(f"--{boundary}--\r\n".encode("utf-8"))
    return b"".join(parts), f"multipart/form-data; boundary={boundary}"


def call(method: str, url: str, key: str | None = None, body: bytes | None = None, ctype: str | None = None) -> tuple[int, dict | list | int | str | None]:
    req = urllib.request.Request(url, data=body, method=method)
    if key:
        req.add_header("x-api-key", key)
    if ctype:
        req.add_header("Content-Type", ctype)
    req.add_header("Accept", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read().decode("utf-8") or "null"
            return r.status, json.loads(raw)
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", "replace")
        try:
            return e.code, json.loads(raw)
        except ValueError:
            return e.code, raw


def explain(status: int, payload) -> str:
    text = json.dumps(payload) if not isinstance(payload, str) else payload
    hints = {
        401: "the key wasn't accepted (check ROBLOX_API_KEY, and that it hasn't expired)",
        403: "the key is missing the scope legacy-universe.badge:manage-and-spend-robux for this experience, or text was moderated",
        404: "that Universe ID isn't an experience the key can reach",
        429: "too many requests: wait a minute and run again",
    }
    if status == 400 and '"code":18' in text.replace(" ", ""):
        return "Roblox wants Robux for this one: today's free badges are used up. Nothing was charged. Run again tomorrow (or use --pay)."
    return f"HTTP {status}: {hints.get(status, 'see the message')} -- {text[:300]}"


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Create the Badge Book's badges on Roblox, with their pictures.")
    ap.add_argument("--universe", default=os.environ.get("ROBLOX_UNIVERSE_ID"), help="the experience's Universe ID")
    ap.add_argument("--count", type=int, default=FREE_PER_DAY, help="how many to make this run (default 5: one day's free badges)")
    ap.add_argument("--keys", default="", help="only these Badge Book keys, comma-separated (in this order)")
    ap.add_argument("--go", action="store_true", help="really create them (without it: a dry run)")
    ap.add_argument("--pay", action="store_true", help="allow paying Robux for badges beyond the free ones")
    ap.add_argument("--robux-each", type=int, default=0, help="with --pay: the Robux price per badge Roblox shows (e.g. 100)")
    ap.add_argument("--max-robux", type=int, default=0, help="with --pay: the most Robux this run may spend")
    ap.add_argument("--inactive", action="store_true", help="create them switched off (default: on)")
    ap.add_argument("--api-base", default=API, help=argparse.SUPPRESS)
    ap.add_argument("--public-base", default=PUBLIC, help=argparse.SUPPRESS)
    ap.add_argument("--sleep", type=float, default=1.0, help=argparse.SUPPRESS)
    args = ap.parse_args(argv)

    try:
        mapping = read_mapping(MAPPING)
        if not mapping:
            raise Stop("MAPPING.md lists no badges.")
        config_text = CONFIG.read_text(encoding="utf-8")
        ids, order = read_config_ids(config_text)
        ledger = read_ledger()
        todo = plan(mapping, ids, order, ledger)
        if args.keys:
            wanted = [k.strip() for k in args.keys.split(",") if k.strip()]
            by_key = {r["key"]: r for r in todo}
            missing = [k for k in wanted if k not in by_key]
            if missing:
                raise Stop("Not in the Badge Book, or already made: " + ", ".join(missing))
            todo = [by_key[k] for k in wanted]
        todo = todo[: max(0, args.count)]

        made_already = sum(1 for k, v in ids.items() if v > 0)
        print(f"Badge Book: {len(mapping)} badges; {made_already} already {'has' if made_already == 1 else 'have'} a Roblox id; {len(plan(mapping, ids, order, ledger))} still to make.")
        if not todo:
            print("Nothing to make.")
            return 0
        for r in todo:
            icon = ICONS / r["file"]
            if not icon.exists():
                raise Stop(f"No picture for {r['key']}: {icon}")
            print(f"  {r['key']}: {r['name']} -- {r['description']}  ({r['file']})")

        cost_each = 0
        if args.pay:
            if args.robux_each <= 0 or args.max_robux <= 0:
                raise Stop("--pay needs --robux-each (the price Roblox shows) and --max-robux (your limit for this run).")
            cost_each = args.robux_each

        if not args.go:
            print("\nDry run: nothing was sent. Add --go to create these.")
            return 0

        key = os.environ.get("ROBLOX_API_KEY", "").strip()
        if not key:
            raise Stop("Set the ROBLOX_API_KEY environment variable first (see the top of this file). Never paste it here.")
        if not args.universe or not str(args.universe).isdigit():
            raise Stop("Give the experience's Universe ID with --universe.")

        spent = 0
        made = 0

        def create(r: dict, cost: int):
            fields = {
                "name": r["name"],
                "description": r["description"],
                "paymentSourceType": "1",
                "expectedCost": str(cost),
                "isActive": "false" if args.inactive else "true",
            }
            body, ctype = multipart(fields, "files", ICONS / r["file"])
            return call("POST", f"{args.api_base}/legacy-badges/v1/universes/{args.universe}/badges", key, body, ctype)

        def wants_robux(status: int, payload) -> bool:
            text = json.dumps(payload) if not isinstance(payload, str) else payload
            return status == 400 and '"code":18' in text.replace(" ", "")

        for r in todo:
            paid = 0
            status, payload = create(r, 0)
            if wants_robux(status, payload):
                if not args.pay or spent + cost_each > args.max_robux:
                    print(f"Stopped before {r['key']}: today's free badges are used up. Nothing was charged. Run again tomorrow" + (" (or raise --max-robux)." if args.pay else " (or use --pay)."))
                    break
                status, payload = create(r, cost_each)
                paid = cost_each
            if not (status == 200 and isinstance(payload, dict) and isinstance(payload.get("id"), int) and payload["id"] > 0):
                raise Stop(f"{r['key']}: " + explain(status, payload))
            free_try = paid == 0
            spent += paid
            badge_id = int(payload["id"])
            # Roblox's advice: check the change really happened.
            time.sleep(args.sleep)
            vstatus, vpayload = call("GET", f"{args.public_base}/v1/badges/{badge_id}")
            if vstatus != 200 or not isinstance(vpayload, dict) or vpayload.get("id") != badge_id:
                raise Stop(f"{r['key']}: Roblox answered with id {badge_id}, but reading it back failed ({vstatus}). Check Creator Hub before running again.")
            config_text = write_config_id(config_text, r["key"], badge_id)
            CONFIG.write_text(config_text, encoding="utf-8")
            ledger[r["key"]] = {"id": badge_id, "name": r["name"], "file": r["file"], "robux": 0 if free_try else cost_each, "made": time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime())}
            LEDGER.write_text(json.dumps(ledger, indent=2, sort_keys=True) + "\n", encoding="utf-8")
            made += 1
            print(f"  made {r['key']}: badge {badge_id} ({'free' if free_try else str(cost_each) + ' Robux'}), checked, written to Config.luau")
            time.sleep(args.sleep)
        print(f"\n{made} made this run{f', {spent} Robux spent' if spent else ', no Robux spent'}. Sync and publish the game so it starts awarding them.")
        return 0
    except Stop as e:
        print("Stopped: " + str(e), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
