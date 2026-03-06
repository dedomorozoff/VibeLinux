#!/usr/bin/env bash
set -euo pipefail

# Скрипт проверки установки компонентов dev-стека для VibeCode OS

check_command() {
  local cmd="$1"
  local name="${2:-$cmd}"
  
  if command -v "$cmd" >/dev/null 2>&1; then
    local version
    version=$("$cmd" --version 2>&1 | head -n1 || echo "unknown")
    echo "[OK] $name: $version"
    return 0
  else
    echo "[MISSING] $name"
    return 1
  fi
}

check_python_package() {
  local package="$1"
  local name="${2:-$package}"
  
  if python3 -c "import $package" 2>/dev/null; then
    local version
    version=$(python3 -c "import $package; print($package.__version__)" 2>/dev/null || echo "unknown")
    echo "[OK] $name: $version"
    return 0
  else
    echo "[MISSING] $name"
    return 1
  fi
}

echo "=== Проверка dev-стека VibeCode OS ==="
echo ""

echo "--- Базовые утилиты ---"
check_command "git" "Git"
check_command "curl" "curl"
check_command "wget" "wget"
check_command "htop" "htop"
check_command "neofetch" "neofetch"
check_command "docker" "Docker"
check_command "docker-compose" "Docker Compose"
check_command "lazygit" "lazygit"
echo ""

echo "--- Оболочка и терминал ---"
check_command "zsh" "Zsh"
check_command "starship" "Starship"
check_command "kitty" "Kitty"
echo ""

echo "--- Менеджеры версий ---"
check_command "pyenv" "pyenv"
check_command "nvm" "nvm"
check_command "rustup" "rustup"
check_command "sdk" "SDKMAN!"
echo ""

echo "--- Языки ---"
check_command "python3" "Python"
check_command "node" "Node.js"
check_command "npm" "npm"
check_command "rustc" "Rust"
check_command "cargo" "cargo"
check_command "go" "Go"
check_command "java" "Java"
echo ""

echo "--- Редакторы ---"
check_command "codium" "VSCodium"
check_command "nvim" "Neovim"
check_command "zed" "Zed"
echo ""

echo "--- Python пакеты ---"
check_python_package "pip" "pip"
check_python_package "setuptools" "setuptools"
echo ""

echo "=== Проверка завершена ==="
