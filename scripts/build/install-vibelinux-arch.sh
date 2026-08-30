#!/usr/bin/env bash
# VibeLinux host installer — установка софта VibeLinux на работающий Arch Linux.
# Аналог scripts/dev/setup-dev-env.sh и scripts/ai/setup-ai-stack.sh для Arch.
#
# Использование:
#   sudo ./scripts/build/install-vibelinux-arch.sh [options]
#
# Опции:
#   --full         установить всё (по умолчанию)
#   --minimal      только базовые CLI-инструменты (без GUI/языков/AI)
#   --no-ai        пропустить AI-стек
#   --no-dev       пропустить dev-стек (языки, редакторы, docker)
#   --no-shell     пропустить настройку оболочки (zsh/starship/конфиги)
#   --no-aur       пропустить AUR-пакеты (только официальный репозиторий)
#   --kde          установить KDE Plasma (для систем без DE)
#   --nvidia       установить NVIDIA-драйверы (nvidia-open)
#   --models       скачать модели Ollama после установки
#   --user NAME    пользователь для настройки конфигов (по умолчанию SUDO_USER)
#   --help         показать справку

set -euo pipefail

# ---------- Параметры ----------
INSTALL_AI=1
INSTALL_DEV=1
INSTALL_SHELL=1
INSTALL_AUR=1
INSTALL_KDE=0
INSTALL_NVIDIA=0
INSTALL_MODELS=0
MINIMAL=0

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_USER="$(logname 2>/dev/null || echo "${TARGET_USER}")"
if [[ "${TARGET_USER}" == "root" ]]; then
  TARGET_USER="$(logname 2>/dev/null || echo root)"
fi

# ---------- Вспомогательные функции ----------
log() { printf "\033[1;34m[vibe]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[err]\033[0m %s\n" "$*" >&2; }

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

need_root() {
  if [[ $EUID -ne 0 ]]; then
    err "Запустите с sudo или от root."
    exit 1
  fi
}

check_pacman() {
  if ! command -v pacman >/dev/null 2>&1; then
    err "pacman не найден — скрипт предназначен только для Arch Linux."
    exit 1
  fi
}

pac() { pacman -S --noconfirm --needed "$@"; }

user_home() {
  local h
  h="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
  [[ -z "${h}" ]] && h="/home/${TARGET_USER}"
  echo "${h}"
}

run_as_user() {
  if command -v sudo >/dev/null 2>&1; then
    sudo -u "${TARGET_USER}" bash -lc "$1"
  else
    su - "${TARGET_USER}" -c "$1"
  fi
}

check_network() {
  curl -sf --connect-timeout 5 https://archlinux.org >/dev/null 2>&1
}

# ---------- Аргументы ----------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --full)    INSTALL_AI=1; INSTALL_DEV=1; INSTALL_SHELL=1; INSTALL_AUR=1; MINIMAL=0 ;;
    --minimal) MINIMAL=1; INSTALL_AI=0; INSTALL_DEV=0; INSTALL_SHELL=0; INSTALL_AUR=0 ;;
    --no-ai)    INSTALL_AI=0 ;;
    --no-dev)   INSTALL_DEV=0 ;;
    --no-shell) INSTALL_SHELL=0 ;;
    --no-aur)   INSTALL_AUR=0 ;;
    --kde)      INSTALL_KDE=1 ;;
    --nvidia)   INSTALL_NVIDIA=1 ;;
    --models)   INSTALL_MODELS=1 ;;
    --user)     TARGET_USER="$2"; shift ;;
    --help|-h)  usage ;;
    *) warn "Неизвестная опция: $1"; usage ;;
  esac
  shift
done

# ---------- Проверки ----------
check_pacman
need_root
USER_HOME="$(user_home)"
if [[ "${TARGET_USER}" != "root" ]] && [[ ! -d "${USER_HOME}" ]]; then
  err "Домашний каталог ${USER_HOME} не найден для пользователя ${TARGET_USER}."
  exit 1
fi

log "VibeLinux host installer"
log "Пользователь для конфигов: ${TARGET_USER} (${USER_HOME})"
log "AI-стек: $( ((INSTALL_AI)) && echo да || echo нет ) | Dev-стек: $( ((INSTALL_DEV)) && echo да || echo нет ) | Shell: $( ((INSTALL_SHELL)) && echo да || echo нет ) | AUR: $( ((INSTALL_AUR)) && echo да || echo нет )"
echo

# ---------- Обновление базы пакетов ----------
log "Обновление баз данных pacman..."
pacman -Sy --noconfirm

# ---------- Базовые пакеты ----------
if [[ "${MINIMAL}" -eq 1 ]]; then
  log "Минимальный набор пакетов..."
  pac base-devel git curl wget unzip zstd p7zip jq rsync tmux btop fastfetch \
      zsh starship eza bat fd zoxide fzf ripgrep lazygit kitty \
      python python-pip nodejs npm docker docker-compose
else
  log "Установка базовых пакетов и CLI-утилит..."
  pac base-devel git curl wget unzip zstd p7zip jq rsync mc tmux btop fastfetch \
      zsh starship eza bat fd zoxide fzf ripgrep lazygit kitty \
      xdg-user-dirs xdg-utils networkmanager firefox \
      noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra \
      ttf-fira-code ttf-jetbrains-mono ttf-jetbrains-mono-nerd \
      ttf-cascadia-code ttf-hack ttf-dejavu ttf-liberation \
      spectacle ark flameshot gparted sqlite3 sqlitebrowser \
      virtualbox-guest-utils

  if [[ "${INSTALL_DEV}" -eq 1 ]]; then
    log "Установка языков и редакторов..."
    pac python python-pip pyenv php go rustup nodejs npm nvm \
        zed helix kate \
        docker docker-compose
  fi

  if [[ "${INSTALL_AI}" -eq 1 ]]; then
    log "Установка AI-инструментов (ollama, opencode)..."
    pac ollama opencode python-virtualenv python-pipx
  fi
fi

# ---------- KDE Plasma (опционально) ----------
if [[ "${INSTALL_KDE}" -eq 1 ]]; then
  log "Установка KDE Plasma..."
  pac plasma-desktop plasma-workspace plasma-nm plasma-pa plasma-systemmonitor \
      kdeconnect dolphin konsole sddm xorg-server wayland \
      discover packagekit-qt6 qt6-multimedia-ffmpeg \
      pipewire pipewire-pulse pipewire-jack wireplumber
fi

# ---------- NVIDIA (опционально) ----------
if [[ "${INSTALL_NVIDIA}" -eq 1 ]]; then
  log "Установка NVIDIA-драйверов (nvidia-open)..."
  pac nvidia-open nvidia-utils nvidia-settings
  mkdir -p /etc/modprobe.d
  grep -q 'nvidia_drm' /etc/modprobe.d/nvidia.conf 2>/dev/null || \
    printf 'options nvidia_drm modeset=1\noptions nvidia NVreg_EnableBacklightHandler=1\n' >> /etc/modprobe.d/nvidia.conf
fi

# ---------- AUR-пакеты ----------
if [[ "${INSTALL_AUR}" -eq 1 ]]; then
  if command -v yay >/dev/null 2>&1; then
    log "AUR-хелпер yay уже установлен."
    AUR="yay"
  elif command -v paru >/dev/null 2>&1; then
    log "AUR-хелпер paru уже установлен."
    AUR="paru"
  elif check_network; then
    log "Установка yay (AUR-хелпер)..."
    pac base-devel git
    if ! id aur_builder &>/dev/null; then
      useradd -m aur_builder
    fi
    echo "aur_builder ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-aur_builder
    runuser -u aur_builder -- bash -lc '
      git clone --depth 1 https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
      cd /tmp/yay-bin && makepkg --noconfirm --skippgpcheck -si
      rm -rf /tmp/yay-bin
    '
    rm -f /etc/sudoers.d/90-aur_builder
    AUR="yay"
  else
    warn "Нет сети — пропуск AUR-пакетов."
    AUR=""
  fi

  if [[ -n "${AUR:-}" ]]; then
    log "Установка AUR-пакетов (bruno, pinta)..."
    runuser -u "${TARGET_USER}" -- "${AUR}" -S --noconfirm --needed \
      bruno-bin pinta 2>/dev/null || warn "Не удалось установить AUR-пакеты (возможно, уже установлены)."
  fi
fi

# ---------- Настройка оболочки ----------
if [[ "${INSTALL_SHELL}" -eq 1 ]] && [[ "${MINIMAL}" -eq 0 ]]; then
  log "Настройка оболочки Zsh + Starship для ${TARGET_USER}..."

  if check_network && [[ ! -d "${USER_HOME}/.oh-my-zsh" ]]; then
    run_as_user 'git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"' 2>/dev/null || true
  fi

  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  BRANDING="${ROOT_DIR}/archiso-vibelinux/airootfs/root/branding/config"
  mkdir -p "${USER_HOME}/.config"

  if [[ -f "${BRANDING}/zsh/zshrc" ]]; then
    cp "${BRANDING}/zsh/zshrc" "${USER_HOME}/.zshrc"
    log "zshrc скопирован из branding"
  else
    warn "zshrc не найден в branding"
  fi

  if [[ -f "${BRANDING}/starship/starship.toml" ]]; then
    cp "${BRANDING}/starship/starship.toml" "${USER_HOME}/.config/starship.toml"
    log "starship.toml скопирован из branding"
  fi

  if [[ -f "${BRANDING}/kitty/kitty.conf" ]]; then
    mkdir -p "${USER_HOME}/.config/kitty"
    cp "${BRANDING}/kitty/kitty.conf" "${USER_HOME}/.config/kitty/kitty.conf"
    log "kitty.conf скопирован из branding"
  fi

  cat >> "${USER_HOME}/.zshrc" << 'EOF'

# VibeLinux — nvm (Arch)
export NVM_DIR="$HOME/.nvm"
[ -s "/usr/share/nvm/init-nvm.sh" ] && . "/usr/share/nvm/init-nvm.sh"

# VibeLinux — pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)" 2>/dev/null || true

# VibeLinux — rustup
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

# VibeLinux — Docker alias
alias dc='docker compose'
EOF

  chown -R "${TARGET_USER}:${TARGET_USER}" "${USER_HOME}/.zshrc" "${USER_HOME}/.config" 2>/dev/null || true

  log "Установка Zsh по умолчанию для ${TARGET_USER}..."
  chsh -s /usr/bin/zsh "${TARGET_USER}" 2>/dev/null || warn "Не удалось сменить shell для ${TARGET_USER}"
fi

# ---------- Dev-стек: docker, rustup ----------
if [[ "${INSTALL_DEV}" -eq 1 ]] && [[ "${MINIMAL}" -eq 0 ]]; then
  log "Настройка Docker..."
  usermod -aG docker "${TARGET_USER}" 2>/dev/null || true
  systemctl enable docker 2>/dev/null || true
  systemctl start docker 2>/dev/null || true

  if command -v rustup >/dev/null 2>&1; then
    log "Установка стабильного Rust toolchain (minimal profile)..."
    run_as_user 'rustup set profile minimal && rustup default stable' 2>/dev/null || true
  fi
fi

# ---------- AI-стек ----------
if [[ "${INSTALL_AI}" -eq 1 ]] && [[ "${MINIMAL}" -eq 0 ]]; then
  log "Включение сервиса Ollama..."
  systemctl enable ollama 2>/dev/null || true
  systemctl start ollama 2>/dev/null || true

  log "Установка Python AI-окружения (~/.venv-ai)..."
  run_as_user '
    if [ ! -d "$HOME/.venv-ai" ]; then
      python3 -m venv "$HOME/.venv-ai"
    fi
    source "$HOME/.venv-ai/bin/activate"
    pip install --upgrade pip setuptools wheel >/dev/null
    pip install --quiet torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
    pip install --quiet transformers accelerate sentencepiece protobuf
    pip install --quiet langchain langchain-community langchain-core
    pip install --quiet llama-index chromadb ollama
    pip install --quiet numpy pandas matplotlib jupyter ipython
    alias ai-env="source $HOME/.venv-ai/bin/activate" 2>/dev/null || true
  ' || warn "Python AI-стек не установился (проверьте интернет/права)"

  if ! grep -q "alias ai-env" "${USER_HOME}/.zshrc" 2>/dev/null; then
    printf '\n# AI environment\nalias ai-env='"'"'source ~/.venv-ai/bin/activate'"'"'\n' >> "${USER_HOME}/.zshrc"
    chown "${TARGET_USER}:${TARGET_USER}" "${USER_HOME}/.zshrc" 2>/dev/null || true
  fi

  if command -v npm >/dev/null 2>&1 && ! command -v qwen >/dev/null 2>&1; then
    log "Установка qwen-code (AI coding agent)..."
    run_as_user 'npm install -g @qwen-code/qwen-code' 2>/dev/null || true
  fi

  if ! command -v sourcecraft >/dev/null 2>&1; then
    log "Установка SourceCraft CLI (Яндекс Code Assistant)..."
    curl -fsSL https://s3.yandexcloud.net/sourcecraft-cli/install.sh | sh 2>/dev/null || warn "SourceCraft CLI не установился (проверьте интернет)"
  fi

  if command -v npm >/dev/null 2>&1 && ! command -v koda >/dev/null 2>&1; then
    log "Установка Koda CLI (AI coding assistant)..."
    run_as_user 'npm install -g @kodadev/koda-cli' 2>/dev/null || warn "Koda CLI не установился (проверьте npm)"
  fi

  log "Установка ai-chat (терминальный AI-чат)..."
  cat > /usr/local/bin/ai-chat << 'AICHATEOF'
#!/usr/bin/env bash
MODEL="${AI_MODEL:-qwen2.5-coder}"
if ! command -v ollama &>/dev/null; then
  echo "Ollama not installed. Run: sudo pacman -S ollama"
  exit 1
fi
echo "VibeLinux AI Chat (model: $MODEL)"
echo "Commands: /help, /model <name>, /quit"
echo
while true; do
  read -rp "> " line
  case "$line" in
    /quit|/exit|/q) break ;;
    /help)
      echo "Commands:"
      echo "  /model <name> - change model"
      echo "  /quit         - exit"
      ;;
    /model\ *)
      MODEL="${line#/model }"
      export AI_MODEL="$MODEL"
      echo "Model: $MODEL"
      ;;
    "") continue ;;
    *) ollama run "$MODEL" "$line" ;;
  esac
done
AICHATEOF
  chmod +x /usr/local/bin/ai-chat

  log "Установка ai-setup (загрузчик моделей)..."
  cat > /usr/local/bin/ai-setup << 'AISETUPEOF'
#!/usr/bin/env bash
echo "Downloading base Ollama models..."
echo
for model in qwen2.5-coder:7b llama3.2:3b codellama:7b; do
  echo "-> $model"
  ollama pull "$model" 2>&1 | tail -1
  echo
done
echo "Done! Run: ai-chat"
AISETUPEOF
  chmod +x /usr/local/bin/ai-setup

  if command -v docker >/dev/null 2>&1; then
    log "Запуск Open WebUI (http://localhost:3000)..."
    docker volume create open-webui >/dev/null 2>&1 || true
    docker container inspect open-webui >/dev/null 2>&1 && docker rm -f open-webui >/dev/null 2>&1 || true
    docker run -d \
      --name open-webui \
      --restart unless-stopped \
      --add-host=host.docker.internal:host-gateway \
      -p 3000:8080 \
      -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
      -v open-webui:/app/backend/data \
      ghcr.io/open-webui/open-webui:main 2>/dev/null || warn "Open WebUI не запустился (проверьте Docker)"
  fi

  if [[ "${INSTALL_MODELS}" -eq 1 ]] && command -v ollama >/dev/null 2>&1; then
    log "Загрузка моделей Ollama (может занять много времени)..."
    ai-setup
  fi
fi

# ---------- Итог ----------
echo
log "════════════════════════════════════════"
log " Установка VibeLinux завершена!"
log "════════════════════════════════════════"
log "Быстрый старт:"
log "  fastfetch   — информация о системе"
log "  ai-chat     — чат с локальной LLM (после ai-setup)"
log "  ai-setup    — скачать модели Ollama"
log "  opencode    — AI coding agent"
log "  sourcecraft — SourceCraft Code Assistant (Яндекс)"
log "  koda        — Koda CLI (AI coding assistant)"
log "  qwen        — Qwen AI coding agent"
log "  ai-env      — активация Python AI-окружения (~/.venv-ai)"
log "  Open WebUI  — http://localhost:3000"
log ""
log "Настройки:"
log "  ./scripts/ai/install-ollama-models.sh — модели Ollama"
log "  ./scripts/ai/install-open-webui.sh    — Open WebUI"
log "  ./scripts/ai/setup-python-ai-stack.sh — Python AI-стек"
log "  ./scripts/ai/install-qwen-code.sh     — qwen-code"
log ""
log "Перезапустите терминал или выполните: source ~/.zshrc"
