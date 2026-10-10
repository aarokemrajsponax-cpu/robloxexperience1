#!/usr/bin/env bash
# Fetches the house's faces (Michroma, Playfair Display, Poppins, Lora; SIL Open Font License) from
# Google Fonts into tools/ui/fonts, so the UI previews are set in the same type as the game, with
# Montserrat standing in for Gotham SSm (Roblox's own) and Luckiest Guy for the shows' loud words.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p fonts
base=https://raw.githubusercontent.com/google/fonts/main/ofl
for f in "playfairdisplay/PlayfairDisplay%5Bwght%5D.ttf" "playfairdisplay/PlayfairDisplay-Italic%5Bwght%5D.ttf" \
         "lora/Lora%5Bwght%5D.ttf" poppins/Poppins-Light.ttf poppins/Poppins-Regular.ttf poppins/Poppins-Medium.ttf poppins/Poppins-SemiBold.ttf \
         michroma/Michroma-Regular.ttf "montserrat/Montserrat%5Bwght%5D.ttf"; do
  out="fonts/$(basename "$f" | sed 's/%5B/[/; s/%5D/]/')"
  [ -s "$out" ] || curl -sSfL -o "$out" "$base/$f"
done
[ -s fonts/LuckiestGuy-Regular.ttf ] || curl -sSfL -o fonts/LuckiestGuy-Regular.ttf https://raw.githubusercontent.com/google/fonts/main/apache/luckiestguy/LuckiestGuy-Regular.ttf
echo "fonts: ok"
