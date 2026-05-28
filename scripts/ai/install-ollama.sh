#!/usr/bin/env bash
set -euo pipefail

# Установка Ollama и включение сервиса.

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

echo "[install-ollama] Установка зависимостей..."
if command -v pacman >/dev/null 2>&1; then
  pacman -Sy --noconfirm --needed curl ca-certificates
elif command -v apt-get >/dev/null 2>&1; then
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates
else
  echo "[install-ollama] Неподдерживаемый пакетный менеджер (нужен pacman или apt-get)."
  exit 1
fi

if command -v ollama >/dev/null 2>&1; then
  echo "[install-ollama] Ollama уже установлена."
else
  echo "[install-ollama] Установка Ollama..."
  curl -fsSL https://ollama.com/install.sh | sh
fi

echo "[install-ollama] Включение и запуск сервиса..."
if pidof systemd >/dev/null 2>&1; then
  systemctl enable ollama || true
  systemctl restart ollama || true
else
  echo "[install-ollama] Пропуск systemctl (среда без systemd / chroot)"
fi

echo "[install-ollama] Проверка..."
if ollama --version >/dev/null 2>&1; then
  echo "[install-ollama] Готово."
else
  echo "[install-ollama] Установка завершилась, но версия не читается. Проверьте вручную."
  exit 1
fi

