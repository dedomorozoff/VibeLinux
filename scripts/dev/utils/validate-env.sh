#!/usr/bin/env bash
set -euo pipefail

# Скрипт валидации dev-среды для VibeCode OS

echo "=== Валидация dev-среды VibeCode OS ==="
echo ""

ERRORS=0

# Проверка Zsh
if ! command -v zsh >/dev/null 2>&1; then
  echo "[ERROR] Zsh не установлен"
  ERRORS=$((ERRORS + 1))
else
  echo "[OK] Zsh установлен"
fi

# Проверка Oh My Zsh
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  echo "[ERROR] Oh My Zsh не установлен"
  ERRORS=$((ERRORS + 1))
else
  echo "[OK] Oh My Zsh установлен"
fi

# Проверка Starship
if ! command -v starship >/dev/null 2>&1; then
  echo "[ERROR] Starship не установлен"
  ERRORS=$((ERRORS + 1))
else
  echo "[OK] Starship установлен"
fi

# Проверка Kitty
if ! command -v kitty >/dev/null 2>&1; then
  echo "[ERROR] Kitty не установлен"
  ERRORS=$((ERRORS + 1))
else
  echo "[OK] Kitty установлен"
fi

# Проверка pyenv
if [[ ! -d "$HOME/.pyenv" ]]; then
  echo "[ERROR] pyenv не установлен"
  ERRORS=$((ERRORS + 1))
else
  echo "[OK] pyenv установлен"
fi

# Проверка nvm
if [[ ! -d "$HOME/.nvm" ]]; then
  echo "[ERROR] nvm не установлен"
  ERRORS=$((ERRORS + 1))
else
  echo "[OK] nvm установлен"
fi

# Проверка rustup
if ! command -v rustup >/dev/null 2>&1; then
  echo "[ERROR] rustup не установлен"
  ERRORS=$((ERRORS + 1))
else
  echo "[OK] rustup установлен"
fi

# Проверка SDKMAN!
if [[ ! -d "$HOME/.sdkman" ]]; then
  echo "[ERROR] SDKMAN! не установлен"
  ERRORS=$((ERRORS + 1))
else
  echo "[OK] SDKMAN! установлен"
fi

# Проверка Docker
if ! command -v docker >/dev/null 2>&1; then
  echo "[ERROR] Docker не установлен"
  ERRORS=$((ERRORS + 1))
else
  echo "[OK] Docker установлен"
  if ! docker ps >/dev/null 2>&1; then
    echo "[WARN] Docker daemon не запущен (запустите 'sudo systemctl start docker')"
  else
    echo "[OK] Docker daemon запущен"
  fi
fi

# Проверка Git
if ! command -v git >/dev/null 2>&1; then
  echo "[ERROR] Git не установлен"
  ERRORS=$((ERRORS + 1))
else
  echo "[OK] Git установлен"
fi

# Проверка VSCodium
if ! command -v codium >/dev/null 2>&1; then
  echo "[WARN] VSCodium не установлен (опционально)"
else
  echo "[OK] VSCodium установлен"
fi

# Проверка Neovim
if ! command -v nvim >/dev/null 2>&1; then
  echo "[WARN] Neovim не установлен (опционально)"
else
  echo "[OK] Neovim установлен"
fi

echo ""
echo "=== Валидация завершена ==="

if [[ $ERRORS -gt 0 ]]; then
  echo "[FAIL] Найдено ошибок: $ERRORS"
  exit 1
else
  echo "[PASS] Всё готово!"
  exit 0
fi
