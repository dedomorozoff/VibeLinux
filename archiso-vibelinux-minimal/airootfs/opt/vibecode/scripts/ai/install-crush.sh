#!/usr/bin/env bash
set -euo pipefail

# Установка Crush (Charm — AI coding agent с LSP + MCP).
#
# Ставим нативный бинарник из GitHub-релизов. npm-пакет @charmland/crush
# при первом запуске скачивает бинарник в глобальный node_modules
# (/usr/lib/node_modules) и у обычного пользователя падает с EACCES.

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

case "$(uname -m)" in
  x86_64)        ASSET_ARCH="x86_64" ;;
  aarch64|arm64) ASSET_ARCH="arm64" ;;
  *)
    echo "[install-crush] Неподдерживаемая архитектура: $(uname -m)"
    exit 1
    ;;
esac

echo "[install-crush] Определяю последнюю версию..."
CRUSH_VER="$(curl -fsSL --retry 3 https://api.github.com/repos/charmbracelet/crush/releases/latest \
  | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1 || true)"
if [[ -z "$CRUSH_VER" ]]; then
  echo "[install-crush] Не удалось получить версию релиза (сеть?)."
  exit 1
fi

URL="https://github.com/charmbracelet/crush/releases/download/${CRUSH_VER}/crush_${CRUSH_VER#v}_Linux_${ASSET_ARCH}.tar.gz"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "[install-crush] Скачиваю crush ${CRUSH_VER} (${ASSET_ARCH})..."
curl -fsSL --retry 3 "$URL" -o "$TMP/crush.tar.gz"

tar -xzf "$TMP/crush.tar.gz" -C "$TMP"
install -Dm 755 "$TMP/crush_${CRUSH_VER#v}_Linux_${ASSET_ARCH}/crush" /usr/local/bin/crush

echo "[install-crush] Готово: crush ${CRUSH_VER} -> /usr/local/bin/crush"

cat <<'EOF'

Быстрый старт:
  crush

Аутентификация:
  - запустите `crush`, нажмите ctrl+l для выбора модели;
  - или задайте ANTHROPIC_API_KEY / OPENAI_API_KEY в окружении.
EOF
