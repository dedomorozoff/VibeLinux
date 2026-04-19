#!/usr/bin/env bash
# ============================================================================
# VibeLinux Post-Install Wizard
# ============================================================================
# Интерактивный мастер настройки для live-сессии
# Поддерживает TUI (whiptail) и GUI (zenity) режимы
# Конфигурация читается из /etc/vibe/config.json
# ============================================================================

set -euo pipefail

CONFIG="/etc/vibe/config.json"
LOG_FILE="/tmp/vibe-wizard.log"
DONE_FLAG="/home/$(whoami)/.vibe-wizard-done"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Определение режима
DETECT_MODE() {
  if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
    if command -v zenity >/dev/null 2>&1; then
      echo "gui"
      return
    fi
  fi
  if command -v whiptail >/dev/null 2>&1; then
    echo "tui"
    return
  fi
  echo "cli"
}

MODE=$(DETECT_MODE)
log() {
  local msg="[$(date '+%H:%M:%S')] $*"
  echo "$msg" >> "$LOG_FILE"
  if [[ "$MODE" == "cli" ]]; then
    printf "${BLUE}[vibe]${NC} %s\n" "$*"
  fi
}

# ============================================================================
# UI helpers
# ============================================================================

show_msgbox() {
  local title="$1" msg="$2"
  case "$MODE" in
    gui) zenity --info --title="$title" --text="$msg" --width=400 --height=200 2>/dev/null || true ;;
    tui) whiptail --title "$title" --msgbox "$msg" 12 60 2>/dev/null || true ;;
    cli) echo -e "\n${BOLD}$title${NC}\n$msg\n"; read -p "Нажмите Enter..." ;;
  esac
}

show_yesno() {
  local title="$1" msg="$2"
  case "$MODE" in
    gui) zenity --question --title="$title" --text="$msg" --width=400 --height=150 2>/dev/null ;;
    tui) whiptail --title "$title" --yesno "$msg" 12 60 2>/dev/null ;;
    cli) echo -e "\n${BOLD}$title${NC}\n$msg"; read -p "Продолжить? (y/n): " -n 1 -r; echo; [[ $REPLY =~ ^[Yy]$ ]] ;;
  esac
}

show_checklist() {
  local title="$1"
  shift
  local items=("$@")
  local result=""

  case "$MODE" in
    gui)
      # zenity --list --checklist
      local checklist_args=()
      for item in "${items[@]}"; do
        checklist_args+=("$item" "OFF")
      done
      result=$(zenity --list --checklist --title="$title" \
        --column="Выбор" --column="Компонент" --column="Описание" \
        "${checklist_args[@]}" \
        --width=500 --height=400 2>/dev/null) || true
      ;;
    tui)
      # whiptail --checklist
      local whiptail_args=("$title" "--checklist" "Выберите компоненты для установки" 20 78 10)
      for item in "${items[@]}"; do
        local key="${item%%|*}"
        local desc="${item#*|}"
        whiptail_args+=("$key" "$desc" "OFF")
      done
      result=$(whiptail "${whiptail_args[@]}" 3>&1 1>&2 2>&3) || true
      ;;
    cli)
      echo -e "\n${BOLD}$title${NC}"
      for item in "${items[@]}"; do
        local key="${item%%|*}"
        local desc="${item#*|}"
        echo "  [ ] $key - $desc"
      done
      echo ""
      read -p "Введите названия через пробел (или 'all' для всех): " result
      if [[ "$result" == "all" ]]; then
        result=""
        for item in "${items[@]}"; do
          result+="${item%%|*} "
        done
      fi
      ;;
  esac

  echo "$result"
}

# ============================================================================
# Чтение конфигурации
# ============================================================================

read_config() {
  if [[ -f "$CONFIG" ]]; then
    log "Чтение конфигурации из $CONFIG"
    if command -v jq >/dev/null 2>&1; then
      EDITORS=$(jq -r '.editors // [] | join(",")' "$CONFIG" 2>/dev/null || echo "")
      AGENTS=$(jq -r '.agents // [] | join(",")' "$CONFIG" 2>/dev/null || echo "")
      RUNTIMES=$(jq -r '.runtimes // [] | join(",")' "$CONFIG" 2>/dev/null || echo "")
      TOOLS=$(jq -r '.tools // [] | join(",")' "$CONFIG" 2>/dev/null || echo "")
      NVIDIA=$(jq -r '.nvidia // false' "$CONFIG" 2>/dev/null || echo "false")
      OLLAMA=$(jq -r '.ollama // false' "$CONFIG" 2>/dev/null || echo "false")
    else
      log "jq не найден, используем значения по умолчанию"
      EDITORS="neovim"
      AGENTS=""
      RUNTIMES="python-system"
      TOOLS="git,tmux,fzf,ripgrep"
      NVIDIA="false"
      OLLAMA="false"
    fi
  else
    log "Конфигурация не найдена, используем значения по умолчанию"
    EDITORS="neovim"
    AGENTS=""
    RUNTIMES="python-system"
    TOOLS="git,tmux,fzf,ripgrep"
    NVIDIA="false"
    OLLAMA="false"
  fi
}

# ============================================================================
# Функции установки
# ============================================================================

install_editors() {
  local selected="$1"
  log "Установка редакторов: $selected"

  # Zed
  if echo "$selected" | grep -qi "zed"; then
    log "Установка Zed..."
    curl -f https://zed.dev/install.sh | sh 2>/dev/null || log "Zed: ошибка установки"
  fi

  # VS Code
  if echo "$selected" | grep -qi "vscode\|code"; then
    if ! command -v code >/dev/null 2>&1; then
      log "Установка VS Code..."
      if command -v apt >/dev/null 2>&1; then
        rm -f /etc/apt/trusted.gpg.d/microsoft.gpg
        curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/microsoft.gpg
        echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
        apt update && apt install -y code 2>/dev/null || log "VS Code: ошибка установки"
      elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm code 2>/dev/null || log "VS Code: ошибка установки"
      fi
    fi
  fi

  # Neovim
  if echo "$selected" | grep -qi "neovim\|nvim"; then
    if ! command -v nvim >/dev/null 2>&1; then
      log "Установка Neovim..."
      if command -v apt >/dev/null 2>&1; then
        apt install -y neovim 2>/dev/null || true
      elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm neovim 2>/dev/null || true
      fi
    fi
  fi

  # Helix
  if echo "$selected" | grep -qi "helix"; then
    if ! command -v hx >/dev/null 2>&1; then
      log "Установка Helix..."
      if command -v apt >/dev/null 2>&1; then
        apt install -y helix 2>/dev/null || true
      elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm helix 2>/dev/null || true
      fi
    fi
  fi
}

install_runtimes() {
  local selected="$1"
  local user="${SUDO_USER:-$(whoami)}"
  local user_home="/home/$user"

  log "Установка рантаймов: $selected"

  # Node.js
  if echo "$selected" | grep -qi "node"; then
    if ! command -v node >/dev/null 2>&1; then
      log "Установка Node.js через fnm..."
      runuser -u "$user" -- bash -lc 'curl -fsSL https://fnm.vercel.app/install | bash' 2>/dev/null || true
      runuser -u "$user" -- bash -lc 'export PATH="$HOME/.local/share/fnm:$PATH"; eval "$(fnm env)"; fnm install --lts; fnm default lts-latest' 2>/dev/null || true
    fi
  fi

  # Bun
  if echo "$selected" | grep -qi "bun"; then
    if [[ ! -f "$user_home/.bun/bin/bun" ]]; then
      log "Установка Bun..."
      runuser -u "$user" -- bash -c 'curl -fsSL https://bun.sh/install | bash' 2>/dev/null || true
      echo 'export PATH="$HOME/.bun/bin:$PATH"' >> "$user_home/.zshrc" 2>/dev/null || true
    fi
  fi

  # Go
  if echo "$selected" | grep -qi "go"; then
    if ! command -v go >/dev/null 2>&1; then
      log "Установка Go..."
      curl -fsSL https://go.dev/dl/go1.22.0.linux-amd64.tar.gz -o /tmp/go.tgz 2>/dev/null || true
      tar -C /usr/local -xzf /tmp/go.tgz 2>/dev/null || true
      echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> "$user_home/.zshrc" 2>/dev/null || true
    fi
  fi

  # Rust
  if echo "$selected" | grep -qi "rust"; then
    if ! command -v cargo >/dev/null 2>&1; then
      log "Установка Rust..."
      runuser -u "$user" -- bash -lc 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y' 2>/dev/null || true
    fi
  fi
}

install_agents() {
  local selected="$1"
  log "Установка AI-агентов: $selected"

  # Aider
  if echo "$selected" | grep -qi "aider"; then
    if ! command -v aider >/dev/null 2>&1; then
      log "Установка aider-chat..."
      pip3 install --break-system-packages --ignore-installed aider-chat 2>/dev/null || log "Aider: ошибка установки"
    fi
  fi

  # Ollama
  if echo "$selected" | grep -qi "ollama"; then
    if ! command -v ollama >/dev/null 2>&1; then
      log "Установка Ollama..."
      curl -fsSL https://ollama.com/install.sh | sh 2>/dev/null || true
      systemctl enable ollama 2>/dev/null || true
      systemctl start ollama 2>/dev/null || true
    fi
  fi
}

install_tools() {
  local selected="$1"
  log "Установка инструментов: $selected"

  # Docker
  if echo "$selected" | grep -qi "docker"; then
    if ! command -v docker >/dev/null 2>&1; then
      log "Установка Docker..."
      if command -v apt >/dev/null 2>&1; then
        apt install -y docker.io 2>/dev/null || true
      elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm docker 2>/dev/null || true
      fi
      systemctl enable docker 2>/dev/null || true
      systemctl start docker 2>/dev/null || true
    fi
  fi

  # NVIDIA
  if echo "$selected" | grep -qi "nvidia"; then
    log "Установка драйверов NVIDIA..."
    if command -v apt >/dev/null 2>&1; then
      apt install -y ubuntu-drivers-common 2>/dev/null || true
      ubuntu-drivers autoinstall 2>/dev/null || true
    elif command -v pacman >/dev/null 2>&1; then
      pacman -Sy --noconfirm nvidia nvidia-utils 2>/dev/null || true
    fi
  fi
}

# ============================================================================
# Основной поток
# ============================================================================

main() {
  read_config

  # Шаг 1: Приветствие
  log "Запуск Vibe Wizard"
  show_msgbox "Vibe Linux Post-Install Wizard" \
    "Добро пожаловать в мастер настройки Vibe Linux!\n\n"\
"Этот мастер поможет установить дополнительные компоненты:\n"\
"• Редакторы кода (Zed, VS Code, Neovim, Helix)\n"\
"• Языки программирования (Node.js, Go, Rust, Bun)\n"\
"• AI-агенты (Ollama, Aider)\n"\
"• Инструменты (Docker, NVIDIA drivers)\n\n"\
"Нажмите OK для продолжения."

  # Шаг 2: Выбор компонентов
  log "Показ выбора компонентов"
  local components
  components=$(show_checklist "Выбор компонентов" \
    "zed|Zed editor (быстрый современный редактор)" \
    "vscode|VS Code (универсальный редактор)" \
    "neovim|Neovim (консольный редактор)" \
    "helix|Helix (модальный редактор)" \
    "node|Node.js LTS (JavaScript/TypeScript)" \
    "go|Go (язык программирования)" \
    "rust|Rust (системный язык)" \
    "bun|Bun (JavaScript runtime)" \
    "ollama|Ollama (локальные LLM)" \
    "aider|Aider (AI-ассистент в терминале)" \
    "docker|Docker (контейнеризация)" \
    "nvidia|NVIDIA drivers (проприетарные драйверы)")

  if [[ -z "$components" ]]; then
    log "Ничего не выбрано, выходим"
    show_msgbox "Vibe Wizard" "Компоненты не выбраны. Мастер завершает работу."
    exit 0
  fi

  log "Выбранные компоненты: $components"

  # Шаг 3: Подтверждение
  if ! show_yesno "Подтверждение" "Установить выбранные компоненты?\n\n$components"; then
    log "Пользователь отменил установку"
    show_msgbox "Vibe Wizard" "Установка отменена."
    exit 0
  fi

  # Шаг 4: Установка
  log "Начало установки..."
  show_msgbox "Установка" "Начинается установка выбранных компонентов.\nЭто может занять время..." &

  # Определяем категории
  local editors="" runtimes="" agents="" tools=""

  for comp in $components; do
    case "$comp" in
      zed|vscode|neovim|helix) editors+="$comp " ;;
      node|go|rust|bun) runtimes+="$comp " ;;
      ollama|aider) agents+="$comp " ;;
      docker|nvidia) tools+="$comp " ;;
    esac
  done

  # Устанавливаем по категориям
  [[ -n "$editors" ]] && install_editors "$editors"
  [[ -n "$runtimes" ]] && install_runtimes "$runtimes"
  [[ -n "$agents" ]] && install_agents "$agents"
  [[ -n "$tools" ]] && install_tools "$tools"

  # Шаг 5: Завершение
  touch "$DONE_FLAG" 2>/dev/null || true
  log "Установка завершена"

  show_msgbox "Vibe Wizard — Завершение" \
    "Установка завершена!\n\n"\
"Установленные компоненты:\n"\
"$components\n\n"\
"Рекомендуется перезагрузить систему.\n\n"\
"Лог: $LOG_FILE"

  echo ""
  echo -e "${GREEN}✓ Vibe Wizard завершил работу!${NC}"
  echo -e "${CYAN}Лог установки: $LOG_FILE${NC}"
}

main "$@"
