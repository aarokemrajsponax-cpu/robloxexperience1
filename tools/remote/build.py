#!/usr/bin/env python3
"""The Owner Remote's commands, made from the game's own lists (src/shared/HouseEvents.luau and
Config.Admin), so the remote can never offer something the game doesn't know.

Writes:
  tools/remote/commands.json          every command: its label, group and JSON
  .github/workflows/owner-remote.yml  GitHub's "Run workflow" remote (any phone or computer)
  remote.ps1                          the PowerShell remote (a computer, instant)
  tools/remote/owner-remote.html      the Owner Remote page's list of powers (then republish it)

Every message carries "rid", an id of its own (the GitHub run's, or a fresh one), and "at", when it
was sent: every server ends an Admin Abuse night at the same moment, carries each command out once,
and never lets an older command undo a newer one. After sending, the remote also writes the command
down in the game's own record (the DataStore "MaisonSchedule", key "live", its "log"), so servers
that weren't open to hear it (even when none was) carry it out when they open. That needs the key's
data store permission; without it the command is still sent to every open server.

Run from the repository's root:  python3 tools/remote/build.py
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UNIVERSE = "10768398256"  # Maison Noir's universe id (public: roblox.com/games/70855377319192)
TOPIC = "MaisonRemote"     # Config.Admin.remoteTopic
STORE = "MaisonSchedule"   # the DataStore AdminService keeps what's on everywhere in
STORE_KEY = "live"         # ...under this key (its "log" is the remote's list)
LOG_MAX = 40               # AdminService LOG_MAX
REPO = "aarokemrajsponax-cpu/robloxexperience1"
BRANCH = "claude/nice-brown-a88p9r"

def read(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        return f.read()

events_src = read("src/shared/HouseEvents.luau")

def block(name):
    m = re.search(r"HouseEvents\." + name + r" = \{(.*?)\n\}", events_src, re.S)
    if not m:
        sys.exit("HouseEvents." + name + " not found")
    return m.group(1)

ENTRY = re.compile(r'\{ id = "(\w+)", name = "([^"]+)", line = "([^"]*)", glyph = "([^"]+)"(, holiday = true)? \}')
events = [dict(id=m[0], name=m[1], line=m[2], glyph=m[3], holiday=bool(m[4])) for m in ENTRY.findall(block("List"))]
effects = [dict(id=m[0], name=m[1], line=m[2], glyph=m[3]) for m in ENTRY.findall(block("Effects"))]
headlines = re.findall(r'^\t"([^"]+)",$', block("Headlines"), re.M)
if len(events) < 20 or len(effects) < 20 or len(headlines) < 8:
    sys.exit(f"lists look wrong: {len(events)} events, {len(effects)} effects, {len(headlines)} headlines")

# Admin Abuse's nights (src/shared/AbuseNights.luau): the remote can choose one, or leave it to the
# seed (a different night every time, the same in every server).
nights_src = read("src/shared/AbuseNights.luau")
NIGHT = re.compile(r'\{ id = "(\w+)", name = "([^"]+)", glyph = "([^"]+)", line = "([^"]*)"')
nights = [dict(id=m[0], name=m[1], glyph=m[2], line=m[3]) for m in NIGHT.findall(nights_src)]
if len(nights) < 50:
    sys.exit(f"the nights look wrong: {len(nights)}")
SURPRISE = "🎲 Surprise me (a different night every time)"
def night_label(n):
    return f"{n['glyph']} {n['name']}"

commands = []
def add(group, label, cmd, line=""):
    commands.append({"group": group, "label": label, "line": line, "command": cmd})

for m in (15, 30, 60):
    add("Abuse", f"💥 Admin Abuse Night · {m} min", {"op": "abuse", "minutes": m}, f"One of {len(nights)} nights, the same in every server: its own opening, realm, surprises and finale.")
for m in (15, 30, 60):
    add("Abuse", f"🌋 MEGA ABUSE · {m} min", {"op": "mega", "minutes": m}, "The night and more: extra surprises, realm after realm, giveaways, the Mega Abuse Medal.")
for what, name in (("abuse", "Admin Abuse"), ("mega", "MEGA ABUSE"), ("giveaway", "a giveaway"), ("surprise", "a surprise effect")):
    add("Abuse", f"⏱️ Countdown, then {name} (10s)", {"op": "countdown", "id": what, "seconds": 10}, "Ten seconds counted down on every screen first.")
add("Abuse", "🛑 Stop everything", {"op": "stopAll"}, "Every event, surprise, countdown and effect, back to normal.")
for e in effects:
    add("Effects", f"{e['glyph']} {e['name']} ON", {"op": "fx", "id": e["id"], "on": True}, e["line"] + " Stays on until it's switched off.")
add("Effects", "🧹 Every effect OFF", {"op": "fxAllOff"}, "Every effect switched off, in every server.")
for e in events:
    if e["holiday"]:
        add("Holidays", f"{e['glyph']} {e['name']} · 15 min", {"op": "event", "id": e["id"], "minutes": 15}, e["line"])
for e in events:
    if not e["holiday"]:
        add("Events", f"{e['glyph']} {e['name']} · 15 min", {"op": "event", "id": e["id"], "minutes": 15}, e["line"])
for amount in (250, 1000, 5000):
    add("Players", f"🎁 Giveaway · {amount} Gilt", {"op": "giveaway", "amount": amount}, "One guest in each server wins, drawn on every screen.")
for amount in (100, 500, 1000):
    add("Players", f"🪙 Gilt for everyone · {amount}", {"op": "giftAll", "amount": amount}, "Every guest in every server.")
add("Players", "👑 The Owner's Token", {"op": "token"}, "A curio from you for every guest (once a day each).")
for i, h in enumerate(headlines, 1):
    add("Message", f"📣 {h}", {"op": "headline", "preset": i}, "Across the top of every screen.")
for clock, glyph in (("midnight", "🌙"), ("dawn", "🌄"), ("noon", "☀️"), ("sunset", "🌇")):
    add("World", f"{glyph} Time of day: {clock.title()}", {"op": "clock", "id": clock}, "Every server's sky.")
# The remote's own test: nothing happens in the game; every open server says it heard it (in the
# record), and the remote reads the answers back.
TEST = "🔔 Test the remote (nothing happens in the game)"
add("Test", TEST, {"op": "ping"}, "Every open server answers; nothing happens in the game. The answer shows on GitHub's run (Owner Remote → the latest run).")

CUSTOM = "📣 Headline: my own words (type them in Words)"
ADVANCED = "⚙️ Advanced: the command box"

with open(os.path.join(ROOT, "tools/remote/commands.json"), "w", encoding="utf-8") as f:
    json.dump({"universe": UNIVERSE, "topic": TOPIC, "repo": REPO, "branch": BRANCH, "custom": CUSTOM, "advanced": ADVANCED, "surprise": SURPRISE, "nights": nights, "commands": commands}, f, ensure_ascii=False, indent=1)

# The GitHub workflow ------------------------------------------------------------------------------
def yaml_str(s):
    return json.dumps(s, ensure_ascii=False)

lines = []
lines.append("# The Owner Remote: Maison Noir's admin abuse in every server, from anywhere (made by")
lines.append("# tools/remote/build.py; change the game's lists, then run it again, never this file by hand).")
lines.append("#")
lines.append("# GitHub → Actions → Owner Remote → Run workflow → choose → Run. Only people who can write to")
lines.append("# this repository can run it. It needs one secret, ROBLOX_OPEN_CLOUD_KEY: an Open Cloud API key")
lines.append("# with the Messaging Service's Publish for Maison Noir, and (so servers that open later join in)")
lines.append("# the Data Stores' read, create and update entry for it (README: The Owner Remote).")
lines.append("name: Owner Remote")
lines.append("on:")
lines.append("  workflow_dispatch:")
lines.append("    inputs:")
lines.append("      power:")
lines.append("        description: \"What happens in every server\"")
lines.append("        type: choice")
lines.append("        required: true")
lines.append("        default: " + yaml_str(commands[0]["label"]))
lines.append("        options:")
for c in commands:
    lines.append("          - " + yaml_str(c["label"]))
lines.append("          - " + yaml_str(CUSTOM))
lines.append("          - " + yaml_str(ADVANCED))
lines.append("      night:")
lines.append("        description: \"Admin Abuse or Mega Abuse: which night (or a surprise)\"")
lines.append("        type: choice")
lines.append("        required: false")
lines.append("        default: " + yaml_str(SURPRISE))
lines.append("        options:")
lines.append("          - " + yaml_str(SURPRISE))
for n in nights:
    lines.append("          - " + yaml_str(night_label(n)))
lines.append("      words:")
lines.append("        description: \"Your headline, for 'my own words' (140 letters; Roblox's filter checks it)\"")
lines.append("        type: string")
lines.append("        required: false")
lines.append("      style:")
lines.append("        description: \"How a headline looks\"")
lines.append("        type: choice")
lines.append("        required: false")
lines.append("        default: rainbow")
lines.append("        options: [gold, red, rainbow, ice, green]")
lines.append("      command:")
lines.append("        description: \"Advanced: one command as JSON, for the command box\"")
lines.append("        type: string")
lines.append("        required: false")
lines.append("permissions: {}")
lines.append("concurrency:")
lines.append("  group: owner-remote")
lines.append("  cancel-in-progress: false")
lines.append("jobs:")
lines.append("  send:")
lines.append("    runs-on: ubuntu-latest")
lines.append("    timeout-minutes: 3")
lines.append("    steps:")
lines.append("      - name: Send it to every server")
lines.append("        env:")
lines.append("          KEY: ${{ secrets.ROBLOX_OPEN_CLOUD_KEY }}")
lines.append("          POWER: ${{ inputs.power }}")
lines.append("          NIGHT: ${{ inputs.night }}")
lines.append("          WORDS: ${{ inputs.words }}")
lines.append("          STYLE: ${{ inputs.style }}")
lines.append("          RAW: ${{ inputs.command }}")
lines.append("          UNIVERSE: \"" + UNIVERSE + "\"")
lines.append("          TOPIC: \"" + TOPIC + "\"")
lines.append("          STORE: \"" + STORE + "\"")
lines.append("          ENTRY: \"" + STORE_KEY + "\"")
lines.append("          API: \"https://apis.roblox.com\"")
lines.append("        run: |")
script = []
script.append("set -euo pipefail")
script.append("if [ -z \"${KEY}\" ]; then")
script.append("  echo \"::error::Add the ROBLOX_OPEN_CLOUD_KEY secret first: Settings → Secrets and variables → Actions → New repository secret (README: The Owner Remote).\"")
script.append("  exit 1")
script.append("fi")
script.append("STYLE=\"${STYLE:-rainbow}\"")
script.append("case \"${POWER}\" in")
for c in commands:
    cmd = dict(c["command"])
    if cmd.get("op") == "headline":
        # The preset's style comes from the style box.
        script.append("  " + json.dumps(c["label"], ensure_ascii=False) + ") CMD=$(jq -cn --arg s \"$STYLE\" --argjson p " + str(cmd["preset"]) + " '{op:\"headline\",preset:$p,style:$s}') ;;")
    else:
        script.append("  " + json.dumps(c["label"], ensure_ascii=False) + ") CMD='" + json.dumps(cmd, separators=(",", ":")) + "' ;;")
script.append("  " + json.dumps(CUSTOM, ensure_ascii=False) + ")")
script.append("    if [ -z \"${WORDS}\" ]; then echo \"::error::Type your headline in Words.\"; exit 1; fi")
script.append("    CMD=$(jq -cn --arg t \"${WORDS:0:140}\" --arg s \"$STYLE\" '{op:\"headline\",text:$t,style:$s}') ;;")
script.append("  " + json.dumps(ADVANCED, ensure_ascii=False) + ")")
script.append("    if ! printf '%s' \"${RAW}\" | jq -e 'type == \"object\" and (.op | type == \"string\")' >/dev/null; then echo \"::error::The command box needs one command as JSON, like {\\\"op\\\":\\\"fx\\\",\\\"id\\\":\\\"meteor\\\"}.\"; exit 1; fi")
script.append("    CMD=$(printf '%s' \"${RAW}\" | jq -c .) ;;")
script.append("  *) echo \"::error::Unknown choice.\"; exit 1 ;;")
script.append("esac")
script.append("# The night chosen, for Admin Abuse or Mega Abuse (a surprise: none, the command's id decides).")
script.append("case \"${NIGHT:-}\" in")
for n in nights:
    script.append("  " + json.dumps(night_label(n), ensure_ascii=False) + ") NIGHT_ID=\"" + n["id"] + "\" ;;")
script.append("  *) NIGHT_ID=\"\" ;;")
script.append("esac")
script.append("if [ -n \"$NIGHT_ID\" ] && printf '%s' \"$CMD\" | jq -e '.op == \"abuse\" or .op == \"mega\" or (.op == \"countdown\" and (.id == \"abuse\" or .id == \"mega\"))' >/dev/null; then")
script.append("  CMD=$(printf '%s' \"$CMD\" | jq -c --arg n \"$NIGHT_ID\" '. + {night: $n}')")
script.append("fi")
script.append("if [ \"${#CMD}\" -gt 900 ]; then echo \"::error::That command is too long.\"; exit 1; fi")
script.append("# Its own id (a re-run is a new command) and when it was sent.")
script.append("RID=\"${GITHUB_RUN_ID:-0}-${GITHUB_RUN_ATTEMPT:-1}\"")
script.append("AT=$(date +%s.%3N)")
script.append("NOW=$(date +%s)")
script.append("CMD=$(printf '%s' \"$CMD\" | jq -c --arg r \"$RID\" --argjson at \"$AT\" '. + {rid: $r, at: $at}')")
script.append("BODY=$(jq -cn --arg m \"$CMD\" '{message:$m}')")
script.append("CODE=$(curl -sS -o /tmp/reply -w '%{http_code}' -X POST \"${API}/messaging-service/v1/universes/${UNIVERSE}/topics/${TOPIC}\" -H \"x-api-key: ${KEY}\" -H \"Content-Type: application/json\" --data \"$BODY\" || true)")
script.append("if [ \"$CODE\" != \"200\" ]; then")
script.append("  echo \"::error::Roblox said ${CODE}: $(cat /tmp/reply 2>/dev/null | head -c 300). 401/403: the key is wrong or lacks the Messaging Service's Publish for Maison Noir.\"")
script.append("  exit 1")
script.append("fi")
script.append("echo \"Sent to every open server: ${CMD}\"")
script.append("echo \"### Sent to every server\" >> \"$GITHUB_STEP_SUMMARY\"")
script.append("echo \"${POWER}\" >> \"$GITHUB_STEP_SUMMARY\"")
script.append("# Written down too, in the game's own record, for the servers that weren't open to hear it")
script.append("# (they carry it out when they open). Read, add to the list, write back only if nobody wrote")
script.append("# in between (else again).")
script.append("URL=\"${API}/datastores/v1/universes/${UNIVERSE}/standard-datastores/datastore/entries/entry?datastoreName=${STORE}&entryKey=${ENTRY}\"")
script.append("ITEM=$(jq -cn --argjson c \"$CMD\" --argjson at \"$AT\" --arg r \"$RID\" '{cmd: $c, at: $at, rid: $r}')")
script.append("WROTE=\"\"")
script.append("for TRY in 1 2 3 4 5; do")
script.append("  GOT=$(curl -sS -D /tmp/head -o /tmp/live.json -w '%{http_code}' -H \"x-api-key: ${KEY}\" \"$URL\" || echo 000)")
script.append("  case \"$GOT\" in")
script.append("    200) VERSION=$(tr -d '\\r' < /tmp/head | awk 'tolower($1) == \"roblox-entry-version:\" { v = $2 } END { print v }'); MODE=\"matchVersion=${VERSION}\"; RECORD=$(cat /tmp/live.json) ;;")
script.append("    204|404) MODE=\"exclusiveCreate=true\"; RECORD='{}' ;;")
script.append("    401|403) WROTE=\"denied\"; break ;;")
script.append("    *) sleep \"$TRY\"; continue ;;")
script.append("  esac")
script.append("  # (Only the remote's list changes: what the servers wrote stays as it was.)")
script.append("  if ! NEW=$(printf '%s' \"$RECORD\" | jq -c --argjson e \"$ITEM\" --argjson now \"$NOW\" '(if type == \"object\" then . else {} end) | .log = ([(.log // [])[] | select(type == \"object\" and (.at | type) == \"number\" and .at > ($now - 86400))] + [$e])[-" + str(LOG_MAX) + ":]'); then WROTE=\"unreadable\"; break; fi")
script.append("  MD5=$(printf '%s' \"$NEW\" | openssl dgst -md5 -binary | base64)")
script.append("  PUT=$(curl -sS -o /tmp/put -w '%{http_code}' -X POST \"${URL}&${MODE}\" -H \"x-api-key: ${KEY}\" -H \"Content-Type: application/json\" -H \"content-md5: ${MD5}\" --data-binary \"$NEW\" || echo 000)")
script.append("  case \"$PUT\" in")
script.append("    200) WROTE=\"yes\"; break ;;")
script.append("    401|403) WROTE=\"denied\"; break ;;")
script.append("    *) sleep \"$TRY\" ;;")
script.append("  esac")
script.append("done")
script.append("if [ \"$WROTE\" = \"yes\" ]; then")
script.append("  echo \"Written down: servers that open later join in too.\"")
script.append("  echo \"Written down: servers that open later join in too.\" >> \"$GITHUB_STEP_SUMMARY\"")
script.append("elif [ \"$WROTE\" = \"denied\" ]; then")
script.append("  echo \"::warning::Sent to every open server, but not written down: the key can't use Maison Noir's data stores, so a server that opens later won't join in. Creator Hub → Open Cloud → API Keys → your key → Edit → Add API System: universe-datastores → Maison Noir → Read Entry, Create Entry, Update Entry → Save (README: The Owner Remote).\"")
script.append("else")
script.append("  echo \"::warning::Sent to every open server, but Roblox's data stores didn't answer, so a server that opens later may not join in. Send it again if that matters.\"")
script.append("fi")
script.append("# The remote's own test: every open server that heard it says so in the record. Read the answers.")
script.append("if printf '%s' \"$CMD\" | jq -e '.op == \"ping\"' >/dev/null; then")
script.append("  HEARD=0")
script.append("  for TRY in 1 2 3 4 5 6 7 8 9 10; do")
script.append("    sleep \"${PING_WAIT:-3}\"")
script.append("    GOT=$(curl -sS -o /tmp/live.json -w '%{http_code}' -H \"x-api-key: ${KEY}\" \"$URL\" || echo 000)")
script.append("    if [ \"$GOT\" = \"200\" ]; then")
script.append("      N=$(jq -r --arg r \"$RID\" '(.pong // {}) | if ((.rid // \"\") | tostring) == $r then (.servers // 0) else 0 end' /tmp/live.json 2>/dev/null || echo 0)")
script.append("      N=$(printf '%s' \"$N\" | tr -cd '0-9')")
script.append("      HEARD=${N:-0}")
script.append("      # (Once one has answered, a moment more for the others.)")
script.append("      if [ \"$HEARD\" -gt 0 ] && [ \"$TRY\" -ge 3 ]; then break; fi")
script.append("    fi")
script.append("  done")
script.append("  if [ \"$HEARD\" -gt 0 ]; then")
script.append("    echo \"The test arrived: ${HEARD} open server(s) heard it. The remote works in every server, whether or not you're in the game.\"")
script.append("    echo \"**The test arrived: ${HEARD} open server(s) heard it.** The remote works in every server, whether or not you're in the game.\" >> \"$GITHUB_STEP_SUMMARY\"")
script.append("  else")
script.append("    echo \"::warning::Roblox took the test, but no server answered within 30 seconds. If nobody is playing right now there's no server to answer, and that's fine: what you send is also written down for the next server that opens. If someone is playing, publish the game again (Studio: File → Publish to Roblox) so its servers know the test, then try again.\"")
script.append("    echo \"Roblox took the test; no server answered (none open right now, or the game needs publishing).\" >> \"$GITHUB_STEP_SUMMARY\"")
script.append("  fi")
script.append("fi")
for s in script:
    lines.append("          " + s)
os.makedirs(os.path.join(ROOT, ".github/workflows"), exist_ok=True)
with open(os.path.join(ROOT, ".github/workflows/owner-remote.yml"), "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")

# The PowerShell remote ----------------------------------------------------------------------------
ps = []
ps.append("# The Owner Remote for a computer: Maison Noir's admin abuse in every server, at once.")
ps.append("# (Made by tools/remote/build.py.) Run it in PowerShell:")
ps.append("#   irm https://raw.githubusercontent.com/" + REPO + "/" + BRANCH + "/remote.ps1 | iex")
ps.append("# The first time, it asks for your Open Cloud API key (README: The Owner Remote) and keeps it,")
ps.append("# encrypted for your Windows account, in %APPDATA%\\MaisonNoir\\remote.key.")
ps.append("$ErrorActionPreference = 'Stop'")
ps.append("$Universe = '" + UNIVERSE + "'")
ps.append("$Topic = '" + TOPIC + "'")
ps.append("$Store = '" + STORE + "'")
ps.append("$Entry = '" + STORE_KEY + "'")
ps.append("# (MAISON_REMOTE_TEST: tests/remote.py tries it against a pretend Roblox; never set it yourself.)")
ps.append("$Testing = [bool]$env:MAISON_REMOTE_TEST")
ps.append("$Api = if ($Testing -and $env:MAISON_REMOTE_API) { $env:MAISON_REMOTE_API } else { 'https://apis.roblox.com' }")
ps.append("$Folder = Join-Path $env:APPDATA 'MaisonNoir'")
ps.append("$KeyFile = Join-Path $Folder 'remote.key'")
ps.append("function Get-Key {")
ps.append("    if ($Testing -and $env:MAISON_REMOTE_KEY) { return $env:MAISON_REMOTE_KEY }")
ps.append("    if (Test-Path $KeyFile) {")
ps.append("        $secure = Get-Content $KeyFile | ConvertTo-SecureString")
ps.append("        return [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))")
ps.append("    }")
ps.append("    $secure = Read-Host 'Paste your Open Cloud API key (it stays on this computer)' -AsSecureString")
ps.append("    New-Item -ItemType Directory -Force -Path $Folder | Out-Null")
ps.append("    $secure | ConvertFrom-SecureString | Set-Content $KeyFile")
ps.append("    return [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))")
ps.append("}")
ps.append("# One request to Roblox: its status, what came back and the entry's version (0 if no answer).")
ps.append("function Invoke-Roblox([string]$Method, [string]$Uri, $Body) {")
ps.append("    $params = @{ Method = $Method; Uri = $Uri; Headers = @{ 'x-api-key' = (Get-Key) }; UseBasicParsing = $true }")
ps.append("    if ($null -ne $Body) {")
ps.append("        $params.Body = [Text.Encoding]::UTF8.GetBytes($Body)")
ps.append("        $params.ContentType = 'application/json; charset=utf-8'")
ps.append("    }")
ps.append("    try {")
ps.append("        $r = Invoke-WebRequest @params")
ps.append("        $version = $r.Headers['roblox-entry-version']")
ps.append("        if ($version -is [array]) { $version = $version[0] }")
ps.append("        $content = $r.Content")
ps.append("        if ($content -is [byte[]]) { $content = [Text.Encoding]::UTF8.GetString($content) }")
ps.append("        return @{ Code = [int]$r.StatusCode; Content = [string]$content; Version = [string]$version }")
ps.append("    } catch {")
ps.append("        $code = 0")
ps.append("        try { $code = [int]$_.Exception.Response.StatusCode } catch { }")
ps.append("        return @{ Code = $code; Content = ''; Version = '' }")
ps.append("    }")
ps.append("}")
ps.append("# Writes the command down in the game's own record (its list), so servers that weren't open")
ps.append("# carry it out when they open: read, add, write back only if nobody wrote in between.")
ps.append("function Write-Down($Command, [double]$At, [string]$Rid) {")
ps.append("    $uri = \"$Api/datastores/v1/universes/$Universe/standard-datastores/datastore/entries/entry?datastoreName=$Store&entryKey=$Entry\"")
ps.append("    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()")
ps.append("    for ($try = 1; $try -le 5; $try++) {")
ps.append("        $got = Invoke-Roblox 'GET' $uri $null")
ps.append("        if ($got.Code -eq 401 -or $got.Code -eq 403) { return 'denied' }")
ps.append("        if ($got.Code -eq 200) {")
ps.append("            try { $record = $got.Content | ConvertFrom-Json } catch { return 'unreadable' }")
ps.append("            if ($null -eq $record -or $record -isnot [pscustomobject]) { $record = [pscustomobject]@{} }")
ps.append("            $mode = 'matchVersion=' + $got.Version")
ps.append("        } elseif ($got.Code -eq 404 -or $got.Code -eq 204) {")
ps.append("            $record = [pscustomobject]@{}")
ps.append("            $mode = 'exclusiveCreate=true'")
ps.append("        } else {")
ps.append("            Start-Sleep -Seconds $try")
ps.append("            continue")
ps.append("        }")
ps.append("        $log = @()")
ps.append("        if ($record.PSObject.Properties['log']) { $log = @($record.log | Where-Object { $_ -and ($_.at -as [double]) -gt ($now - 86400) }) }")
ps.append("        $log += [pscustomobject]@{ cmd = $Command; at = $At; rid = $Rid }")
ps.append("        if ($log.Count -gt " + str(LOG_MAX) + ") { $log = $log[($log.Count - " + str(LOG_MAX) + ")..($log.Count - 1)] }")
ps.append("        $record | Add-Member -NotePropertyName log -NotePropertyValue $log -Force")
ps.append("        $put = Invoke-Roblox 'POST' ($uri + '&' + $mode) (ConvertTo-Json -InputObject $record -Depth 20 -Compress)")
ps.append("        if ($put.Code -eq 200) { return 'yes' }")
ps.append("        if ($put.Code -eq 401 -or $put.Code -eq 403) { return 'denied' }")
ps.append("        Start-Sleep -Seconds $try")
ps.append("    }")
ps.append("    return 'no'")
ps.append("}")
ps.append("function Send-Command([string]$Json) {")
ps.append("    $obj = $Json | ConvertFrom-Json")
ps.append("    $rid = [guid]::NewGuid().ToString('N')")
ps.append("    $at = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() / 1000.0")
ps.append("    $obj | Add-Member -NotePropertyName rid -NotePropertyValue $rid -Force")
ps.append("    $obj | Add-Member -NotePropertyName at -NotePropertyValue $at -Force")
ps.append("    $message = ConvertTo-Json -InputObject $obj -Depth 10 -Compress")
ps.append("    $sent = Invoke-Roblox 'POST' \"$Api/messaging-service/v1/universes/$Universe/topics/$Topic\" (ConvertTo-Json -InputObject @{ message = $message } -Compress)")
ps.append("    if ($sent.Code -ne 200) {")
ps.append("        Write-Host ('  Roblox said no (' + $sent.Code + ').') -ForegroundColor Red")
ps.append("        Write-Host '  (401/403: the key is wrong or lacks the Messaging Service''s Publish for Maison Noir. Delete the key file to paste a new one.)' -ForegroundColor Yellow")
ps.append("        return")
ps.append("    }")
ps.append("    Write-Host '  Sent to every open server.' -ForegroundColor Green")
ps.append("    switch (Write-Down $obj $at $rid) {")
ps.append("        'yes' { Write-Host '  Written down: servers that open later join in too.' -ForegroundColor Green }")
ps.append("        'denied' { Write-Host '  Not written down: the key can''t use Maison Noir''s data stores, so a server that opens later won''t join in. Creator Hub > Open Cloud > API Keys > your key > Edit > Add API System: universe-datastores > Maison Noir > Read Entry, Create Entry, Update Entry > Save.' -ForegroundColor Yellow }")
ps.append("        default { Write-Host '  Not written down (Roblox''s data stores didn''t answer): a server that opens later may not join in.' -ForegroundColor Yellow }")
ps.append("    }")
ps.append("    # The remote's own test: every open server that heard it says so in the record.")
ps.append("    if ($obj.op -eq 'ping') {")
ps.append("        $uri = \"$Api/datastores/v1/universes/$Universe/standard-datastores/datastore/entries/entry?datastoreName=$Store&entryKey=$Entry\"")
ps.append("        $wait = if ($Testing -and $env:MAISON_REMOTE_PING_WAIT) { [double]$env:MAISON_REMOTE_PING_WAIT } else { 3 }")
ps.append("        $heard = 0")
ps.append("        for ($try = 1; $try -le 10; $try++) {")
ps.append("            Start-Sleep -Milliseconds ([int]($wait * 1000))")
ps.append("            $got = Invoke-Roblox 'GET' $uri $null")
ps.append("            if ($got.Code -eq 200) {")
ps.append("                try { $rec = $got.Content | ConvertFrom-Json } catch { $rec = $null }")
ps.append("                if ($rec -and $rec.PSObject.Properties['pong'] -and [string]$rec.pong.rid -eq $rid) { $heard = [int]$rec.pong.servers }")
ps.append("                if ($heard -gt 0 -and $try -ge 3) { break }")
ps.append("            }")
ps.append("        }")
ps.append("        if ($heard -gt 0) { Write-Host ('  The test arrived: ' + $heard + ' open server(s) heard it.') -ForegroundColor Green }")
ps.append("        else { Write-Host '  No server answered within 30 seconds: nobody may be playing right now (that''s fine), or the game needs publishing again.' -ForegroundColor Yellow }")
ps.append("    }")
ps.append("}")
ps.append("$Commands = @(")
for c in commands:
    label = c["label"].replace("'", "''")
    cmd = json.dumps(c["command"], separators=(",", ":"), ensure_ascii=False)
    if c["command"].get("op") == "headline":
        cmd = json.dumps(dict(c["command"], style="rainbow"), separators=(",", ":"), ensure_ascii=False)
    ps.append("    @{ Label = '" + label + "'; Json = '" + cmd.replace("'", "''") + "' }")
ps.append(")")
ps.append("$Nights = @(")
for n in nights:
    ps.append("    @{ Id = '" + n["id"] + "'; Name = '" + n["name"].replace("'", "''") + "' }")
ps.append(")")
ps.append("# Admin Abuse or Mega Abuse: which night (Enter for a surprise: the same in every server either way).")
ps.append("function Add-Night([string]$Json, [string]$Asked) {")
ps.append("    $obj = $Json | ConvertFrom-Json")
ps.append("    $abuse = $obj.op -eq 'abuse' -or $obj.op -eq 'mega' -or ($obj.op -eq 'countdown' -and ($obj.id -eq 'abuse' -or $obj.id -eq 'mega'))")
ps.append("    if (-not $abuse -or -not $Asked) { return $Json }")
ps.append("    $n = 0")
ps.append("    $pick = $null")
ps.append("    if ([int]::TryParse($Asked, [ref]$n) -and $n -ge 1 -and $n -le $Nights.Count) { $pick = $Nights[$n - 1] }")
ps.append("    else { $pick = $Nights | Where-Object { $_.Name -like ('*' + $Asked + '*') } | Select-Object -First 1 }")
ps.append("    if (-not $pick) { return $Json }")
ps.append("    $obj | Add-Member -NotePropertyName night -NotePropertyValue $pick.Id -Force")
ps.append("    return ($obj | ConvertTo-Json -Compress)")
ps.append("}")
ps.append("if ($Testing) { return }")
ps.append("[Console]::OutputEncoding = [Text.Encoding]::UTF8")
ps.append("while ($true) {")
ps.append("    Write-Host ''")
ps.append("    Write-Host '  MAISON NOIR  ·  THE OWNER REMOTE  ·  every server, at once' -ForegroundColor Yellow")
ps.append("    for ($i = 0; $i -lt $Commands.Count; $i++) { Write-Host ('  {0,3}  {1}' -f ($i + 1), $Commands[$i].Label) }")
ps.append("    Write-Host '    h  A headline in your own words'")
ps.append("    Write-Host '    q  Quit'")
ps.append("    $choice = Read-Host '  Choose'")
ps.append("    if ($choice -eq 'q') { break }")
ps.append("    if ($choice -eq 'h') {")
ps.append("        $words = Read-Host '  Your headline (140 letters; Roblox''s filter checks it)'")
ps.append("        if ($words) { Send-Command (@{ op = 'headline'; text = $words.Substring(0, [Math]::Min(140, $words.Length)); style = 'rainbow' } | ConvertTo-Json -Compress) }")
ps.append("        continue")
ps.append("    }")
ps.append("    $n = 0")
ps.append("    if ([int]::TryParse($choice, [ref]$n) -and $n -ge 1 -and $n -le $Commands.Count) {")
ps.append("        Write-Host ('  ' + $Commands[$n - 1].Label)")
ps.append("        $json = $Commands[$n - 1].Json")
ps.append("        if ($json -match '\\\"op\\\":\\\"(abuse|mega|countdown)\\\"') {")
ps.append("            for ($i = 0; $i -lt $Nights.Count; $i++) { Write-Host ('  {0,3}  {1}' -f ($i + 1), $Nights[$i].Name) -ForegroundColor DarkYellow }")
ps.append("            $asked = Read-Host '  Which night? (Enter for a surprise, or its number or name)'")
ps.append("            $json = Add-Night $json $asked")
ps.append("        }")
ps.append("        Send-Command $json")
ps.append("    }")
ps.append("}")
with open(os.path.join(ROOT, "remote.ps1"), "w", encoding="utf-8-sig") as f:
    f.write("\r\n".join(ps) + "\r\n")

# The Owner Remote page --------------------------------------------------------------------------
page_path = os.path.join(ROOT, "tools/remote/owner-remote.html")
if os.path.exists(page_path):
    page = read("tools/remote/owner-remote.html")
    data = json.dumps({"universe": UNIVERSE, "topic": TOPIC, "repo": REPO, "branch": BRANCH, "custom": CUSTOM, "advanced": ADVANCED, "surprise": SURPRISE, "nights": nights, "commands": commands}, ensure_ascii=False)
    page, n = re.subn(r"^const DATA = .*;$", lambda _m: "const DATA = " + data + ";", page, count=1, flags=re.M)
    if n != 1:
        sys.exit("the page's DATA line wasn't found")
    with open(page_path, "w", encoding="utf-8") as f:
        f.write(page)

print(f"{len(commands)} commands ({len(effects)} effects, {len(events)} events, {len(headlines)} headlines, {len(nights)} nights)")
