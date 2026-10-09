#!/usr/bin/env python3
"""The Owner Remote's commands, made from the game's own lists (src/shared/HouseEvents.luau and
Config.Admin), so the remote can never offer something the game doesn't know.

Writes:
  tools/remote/commands.json          every command: its label, group and JSON
  .github/workflows/owner-remote.yml  GitHub's "Run workflow" remote (any phone or computer)
  remote.ps1                          the PowerShell remote (a computer, instant)

Run from the repository's root:  python3 tools/remote/build.py
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UNIVERSE = "10768398256"  # Maison Noir's universe id (public: roblox.com/games/70855377319192)
TOPIC = "MaisonRemote"     # Config.Admin.remoteTopic
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

commands = []
def add(group, label, cmd, line=""):
    commands.append({"group": group, "label": label, "line": line, "command": cmd})

for m in (15, 30, 60):
    add("Abuse", f"💥 Admin Abuse Night · {m} min", {"op": "abuse", "minutes": m}, "Every event at once, with a surprise effect every minute.")
for m in (15, 30, 60):
    add("Abuse", f"🌋 MEGA ABUSE · {m} min", {"op": "mega", "minutes": m}, "Every effect as a surprise, giveaways, and the Mega Abuse Medal.")
for what, name in (("abuse", "Admin Abuse"), ("mega", "MEGA ABUSE"), ("giveaway", "a giveaway"), ("surprise", "a surprise effect")):
    add("Abuse", f"⏱️ Countdown, then {name} (10s)", {"op": "countdown", "id": what, "seconds": 10}, "Ten seconds counted down on every screen first.")
add("Abuse", "🛑 Stop everything", {"op": "stopAll"}, "Every event, surprise and countdown, back to normal.")
for e in effects:
    add("Effects", f"{e['glyph']} {e['name']}", {"op": "fx", "id": e["id"]}, e["line"])
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

CUSTOM = "📣 Headline: my own words (type them in Words)"
ADVANCED = "⚙️ Advanced: the command box"

with open(os.path.join(ROOT, "tools/remote/commands.json"), "w", encoding="utf-8") as f:
    json.dump({"universe": UNIVERSE, "topic": TOPIC, "repo": REPO, "branch": BRANCH, "custom": CUSTOM, "advanced": ADVANCED, "commands": commands}, f, ensure_ascii=False, indent=1)

# The GitHub workflow ------------------------------------------------------------------------------
def yaml_str(s):
    return json.dumps(s, ensure_ascii=False)

lines = []
lines.append("# The Owner Remote: Maison Noir's admin abuse in every server, from anywhere (made by")
lines.append("# tools/remote/build.py; change the game's lists, then run it again, never this file by hand).")
lines.append("#")
lines.append("# GitHub → Actions → Owner Remote → Run workflow → choose → Run. Only people who can write to")
lines.append("# this repository can run it. It needs one secret, ROBLOX_OPEN_CLOUD_KEY: an Open Cloud API key")
lines.append("# with the Messaging Service's Publish for Maison Noir (README: The Owner Remote).")
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
lines.append("          WORDS: ${{ inputs.words }}")
lines.append("          STYLE: ${{ inputs.style }}")
lines.append("          RAW: ${{ inputs.command }}")
lines.append("          UNIVERSE: \"" + UNIVERSE + "\"")
lines.append("          TOPIC: \"" + TOPIC + "\"")
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
script.append("if [ \"${#CMD}\" -gt 900 ]; then echo \"::error::That command is too long.\"; exit 1; fi")
script.append("BODY=$(jq -cn --arg m \"$CMD\" '{message:$m}')")
script.append("CODE=$(curl -sS -o /tmp/reply -w '%{http_code}' -X POST \"https://apis.roblox.com/messaging-service/v1/universes/${UNIVERSE}/topics/${TOPIC}\" -H \"x-api-key: ${KEY}\" -H \"Content-Type: application/json\" --data \"$BODY\" || true)")
script.append("if [ \"$CODE\" = \"200\" ]; then")
script.append("  echo \"Sent to every server: ${CMD}\"")
script.append("  echo \"### Sent to every server\" >> \"$GITHUB_STEP_SUMMARY\"")
script.append("  echo \"${POWER}\" >> \"$GITHUB_STEP_SUMMARY\"")
script.append("else")
script.append("  echo \"::error::Roblox said ${CODE}: $(cat /tmp/reply 2>/dev/null | head -c 300). 401/403: the key is wrong or lacks the Messaging Service's Publish for Maison Noir.\"")
script.append("  exit 1")
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
ps.append("$Folder = Join-Path $env:APPDATA 'MaisonNoir'")
ps.append("$KeyFile = Join-Path $Folder 'remote.key'")
ps.append("function Get-Key {")
ps.append("    if (Test-Path $KeyFile) {")
ps.append("        $secure = Get-Content $KeyFile | ConvertTo-SecureString")
ps.append("        return [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))")
ps.append("    }")
ps.append("    $secure = Read-Host 'Paste your Open Cloud API key (it stays on this computer)' -AsSecureString")
ps.append("    New-Item -ItemType Directory -Force -Path $Folder | Out-Null")
ps.append("    $secure | ConvertFrom-SecureString | Set-Content $KeyFile")
ps.append("    return [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))")
ps.append("}")
ps.append("function Send-Command([string]$Json) {")
ps.append("    $body = @{ message = $Json } | ConvertTo-Json -Compress")
ps.append("    try {")
ps.append("        Invoke-RestMethod -Method Post -Uri \"https://apis.roblox.com/messaging-service/v1/universes/$Universe/topics/$Topic\" -Headers @{ 'x-api-key' = (Get-Key) } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null")
ps.append("        Write-Host '  Sent to every server.' -ForegroundColor Green")
ps.append("    } catch {")
ps.append("        Write-Host ('  Roblox said no: ' + $_.Exception.Message) -ForegroundColor Red")
ps.append("        Write-Host '  (401/403: the key is wrong or lacks the Messaging Service''s Publish for Maison Noir. Delete the key file to paste a new one.)' -ForegroundColor Yellow")
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
ps.append("        Send-Command $Commands[$n - 1].Json")
ps.append("    }")
ps.append("}")
with open(os.path.join(ROOT, "remote.ps1"), "w", encoding="utf-8-sig") as f:
    f.write("\r\n".join(ps) + "\r\n")

print(f"{len(commands)} commands ({len(effects)} effects, {len(events)} events, {len(headlines)} headlines)")
