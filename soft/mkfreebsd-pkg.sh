#!/bin/sh
# Упаковывает один бинарь в FreeBSD .pkg (формат, совместимый с pkg add).
# Использование: mkfreebsd-pkg.sh <бинарь> <имя> <версия> <лицензия> <www> <desc> [commit]
set -eu

BIN=$1; NAME=$2; VERSION=$3; LICENSE=$4; WWW=$5; DESC=$6; COMMIT=${7:-}

[ -f "$BIN" ] || { echo "no such file: $BIN" >&2; exit 1; }
ABI=$(pkg -vv 2>/dev/null | sed -n 's/^ABI: \(.*\)/\1/p' | head -1)
[ -n "$ABI" ] || ABI="FreeBSD:15:amd64"
ARCH=$(pkg -vv 2>/dev/null | sed -n 's/^ABI arc: \(.*\)/\1/p' | head -1)
[ -n "$ARCH" ] || ARCH="amd64"

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/root/usr/local/bin"
install -m 0755 "$BIN" "$STAGE/root/usr/local/bin/$NAME"

SUM=$(sha256 -q "$STAGE/root/usr/local/bin/$NAME")
SIZE=$(stat -f %z "$STAGE/root/usr/local/bin/$NAME")
COMMIT_PART=""
[ -n "$COMMIT" ] && COMMIT_PART=" at $COMMIT"

cat > "$STAGE/manifest.json" <<EOF
{
  "name": "$NAME",
  "origin": "vibebsd/$NAME",
  "version": "$VERSION",
  "comment": "VibeBSD bundled tool",
  "maintainer": "vibebsd@localhost",
  "www": "$WWW",
  "abi": "$ABI",
  "arch": "freebsd:15:x86:64",
  "prefix": "/usr/local",
  "flatsize": $SIZE,
  "licenselogic": "single",
  "licenses": ["$LICENSE"],
  "desc": "$DESC$COMMIT_PART.",
  "messages": [
    { "message": "$NAME $VERSION installed to /usr/local/bin/$NAME." }
  ],
  "files": {
    "/usr/local/bin/$NAME": {
      "sum": "1$SUM",
      "uname": "root",
      "gname": "wheel",
      "perm": "0755",
      "mtime": 1790408760
    }
  }
}
EOF

pkg create -M "$STAGE/manifest.json" -r "$STAGE/root" -o "$(dirname "$BIN")" -f tzst -T 0 >/dev/null
ls -la "$(dirname "$BIN")/$NAME-$VERSION.pkg"
