#!/bin/sh
set -eu
APP_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ ! -f "$APP_DIR/build/web/index.html" ]; then
  echo "Build the offline web release first; see README.md."
  exit 1
fi
echo "Open http://127.0.0.1:5188 in your browser. Keep this terminal open."
exec python3 -m http.server 5188 --bind 127.0.0.1 --directory "$APP_DIR/build/web"
