#!/usr/bin/env bash
# Fetches the house's faces (Playfair Display, Poppins, Lora; SIL Open Font License) from Google
# Fonts into tools/ui/fonts, so the UI previews are set in the same type as the game.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p fonts
base=https://raw.githubusercontent.com/google/fonts/main/ofl
for f in "playfairdisplay/PlayfairDisplay%5Bwght%5D.ttf" "playfairdisplay/PlayfairDisplay-Italic%5Bwght%5D.ttf" \
         "lora/Lora%5Bwght%5D.ttf" poppins/Poppins-Light.ttf poppins/Poppins-Regular.ttf poppins/Poppins-Medium.ttf poppins/Poppins-SemiBold.ttf; do
  out="fonts/$(basename "$f" | sed 's/%5B/[/; s/%5D/]/')"
  [ -s "$out" ] || curl -sSfL -o "$out" "$base/$f"
done
echo "fonts: ok"
