#!/usr/bin/env bash
# Type-checks every script against Roblox's API and runs the pure-rule tests.
# Needs: rojo, luau-lsp, luau (standalone), lune and globalTypes.d.luau in $TOOLS.
set -euo pipefail
cd "$(dirname "$0")/.."
TOOLS="${TOOLS:?set TOOLS to the folder holding rojo, luau-lsp, luau and globalTypes.d.luau}"
"$TOOLS/rojo" sourcemap default.project.json -o sourcemap.json >/dev/null
"$TOOLS/luau-lsp" analyze --sourcemap=sourcemap.json --definitions="$TOOLS/globalTypes.d.luau" \
  --platform=roblox --ignore="src/server/Vendor/**" --flag:LuauSolverV2=false src
python3 tests/bundle.py > "$TOOLS/bundle.luau"
"$TOOLS/luau" "$TOOLS/bundle.luau"
"$TOOLS/lune" run tests/smoke.luau
"$TOOLS/lune" run tests/duel.luau
"$TOOLS/rojo" build default.project.json -o "$TOOLS/MaisonNoir.rbxl" >/dev/null
echo "check: ok"
