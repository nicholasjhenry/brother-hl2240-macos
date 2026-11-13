#!/bin/zsh
# Build the open-source brlaser CUPS driver and add a Brother HL-2240 printer on macOS.
# Run from a Terminal window: sudo needs a terminal to ask for the password.
set -euo pipefail

BRLASER_VERSION=6.2.8
BRLASER_SHA256=16dae855aa7fff0eef0c05398fab37678243d7d610fa5f9af0d3a2cc9bf08cb0
BRLASER_URL="https://github.com/Owl-Maintain/brlaser/archive/refs/tags/v$BRLASER_VERSION.tar.gz"

QUEUE=Brother_HL_2240
DEST=/Library/Printers/brlaser
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# A device URI can be passed as the first argument. Otherwise it is discovered:
# a USB connection, or a network share such as an AirPort base station.
URI=${1:-}
if [[ -z $URI ]]; then
  echo "==> Looking for the printer"
  URI=$(lpinfo -v | awk '/HL-2240/ { print $2; exit }')
fi
if [[ -z $URI ]]; then
  echo "No HL-2240 found. Check it is on and connected, or pass its device URI." >&2
  exit 1
fi
echo "==> Using $URI"

echo "==> Downloading brlaser $BRLASER_VERSION"
curl -fsSL -o "$WORK/brlaser.tar.gz" "$BRLASER_URL"
echo "$BRLASER_SHA256  $WORK/brlaser.tar.gz" | shasum -a 256 -c -
tar -xzf "$WORK/brlaser.tar.gz" -C "$WORK"
SRC=$WORK/brlaser-$BRLASER_VERSION
BUILD=$WORK/build

echo "==> Building"
command -v cmake >/dev/null || brew install cmake
cmake -S "$SRC" -B "$BUILD" -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD" --target rastertobrlaser

# SIP blocks /usr/libexec/cups/filter, so the filter lives in /Library/Printers
# and the PPD names it by absolute path.
sed "s|rastertobrlaser|$DEST/rastertobrlaser|" "$BUILD/brlaser.drv" > "$BUILD/brlaser-mac.drv"
ppdc -d "$BUILD/ppd" "$BUILD/brlaser-mac.drv"

echo "==> Installing driver to $DEST"
sudo mkdir -p "$DEST"
sudo install -o root -g wheel -m 755 "$BUILD/rastertobrlaser" "$DEST/rastertobrlaser"
sudo install -o root -g wheel -m 644 "$BUILD/ppd/br2240.ppd" "$DEST/br2240.ppd"

echo "==> Adding printer $QUEUE"
sudo lpadmin -p "$QUEUE" -E -v "$URI" -P "$DEST/br2240.ppd" \
  -D "Brother HL-2240" -o printer-is-shared=false
cupstestppd -W none "/etc/cups/ppd/$QUEUE.ppd"
lpstat -p "$QUEUE" -v "$QUEUE"

echo "==> Done. Print a test page with: echo test | lp -d $QUEUE"
