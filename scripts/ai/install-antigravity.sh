#!/usr/bin/env bash
set -euo pipefail

# Установка Google Antigravity CLI (agy) — агентный AI-инструмент.
#
# Бинарник нативный (не npm), самообновляется при запусках из
# ~/.local/bin/agy. Ставим официальным установщиком в /usr/local/bin.

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "[install-antigravity] Не установлен curl."
  exit 1
fi

if command -v agy >/dev/null 2>&1; then
  echo "[install-antigravity] agy уже установлен: $(agy --version 2>/dev/null || echo '?')"
  exit 0
fi

echo "[install-antigravity] Установка Google Antigravity CLI (official installer)..."

if curl -fsSL --retry 3 https://antigravity.google/cli/install.sh | bash -s -- --dir /usr/local/bin; then
  echo "[install-antigravity] Готово: agy -> /usr/local/bin/agy"
else
  echo "[install-antigravity] ОШИБКА: не удалось установить Antigravity CLI."
  exit 1
fi

cat <<'EOF'

Быстрый старт:
  agy

Аутентификация:
  - запустите `agy` внутри проекта — первый запуск проведёт по настройке;
  - CLI подключается через Google-аккаунт (нужен доступ к Antigravity).
EOF