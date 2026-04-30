#!/usr/bin/env bash
set -e

echo "=== VibeLinux customization ==="

# Hostname
echo "vibelinux" > /etc/hostname
cat > /etc/hosts << EOF
127.0.0.1 localhost
127.0.1.1 vibelinux
::1       localhost
EOF

# Locale
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
sed -i 's/#ru_RU.UTF-8/ru_RU.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Keyboard layout
cat > /etc/X11/xorg.conf.d/00-keyboard.conf << EOF
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "us,ru"
    Option "XkbModel" "pc105"
    Option "XkbOptions" "grp:alt_shift_toggle"
EndSection
EOF

# Default shell
chsh -s /usr/bin/zsh root 2>/dev/null || true

# User
if ! id vibe &>/dev/null; then
  useradd -m -G wheel -s /usr/bin/zsh vibe
  echo "vibe:vibe" | chpasswd
fi
echo "vibe ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90_vibe
chmod 440 /etc/sudoers.d/90_vibe

# Services
systemctl enable NetworkManager || true
systemctl enable systemd-timesyncd || true
systemctl enable docker || true
systemctl enable sddm || true
systemctl enable ollama || true

# SDDM autologin
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/autologin.conf << EOF
[Autologin]
User=vibe
Session=plasma.desktop
EOF

# Oh My Zsh (install via script)
if [[ ! -d /home/vibe/.oh-my-zsh ]]; then
  runuser -u vibe -- bash -c 'CI=true sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' 2>/dev/null || true
fi

# Starship prompt
if command -v starship >/dev/null 2>&1; then
  echo 'eval "$(starship init zsh)"' >> /home/vibe/.zshrc
fi

# KDE user defaults
mkdir -p /home/vibe/.config
cat > /home/vibe/.config/kglobalshortcutsrc << EOF
EOF

# Fix permissions
chown -R vibe:vibe /home/vibe

# AI Stack — Ollama models + ai-chat script
cat > /usr/local/bin/ai-chat << 'AICHATEOF'
#!/usr/bin/env bash
# VibeLinux — простой AI-чат через Ollama
MODEL="${AI_MODEL:-qwen2.5-coder}"

if ! command -v ollama &>/dev/null; then
  echo "Ollama не установлен. Запуск: sudo pacman -S ollama"
  exit 1
fi

if ! systemctl is-active --quiet ollama; then
  echo "Запуск Ollama..."
  systemctl --user start ollama || ollama serve &
  sleep 2
fi

echo "🤖 VibeLinux AI Chat (модель: $MODEL)"
echo "Команды: /help, /model <name>, /quit"
echo

while true; do
  read -rp "➜ " line
  case "$line" in
    /quit|/exit|/q) break ;;
    /help)
      echo "Доступные команды:"
      echo "  /model <name> — сменить модель"
      echo "  /quit         — выйти"
      echo "  Просто введите сообщение — AI ответит"
      ;;
    /model\ *)
      MODEL="${line#/model }"
      export AI_MODEL="$MODEL"
      echo "Модель: $MODEL"
      ;;
    "")
      continue
      ;;
    *)
      ollama run "$MODEL" "$line"
      ;;
  esac
done
echo "Пока! 👋"
AICHATEOF
chmod +x /usr/local/bin/ai-chat

# Скрипт загрузки базовых моделей
cat > /usr/local/bin/ai-setup << 'AISETUPEOF'
#!/usr/bin/env bash
# VibeLinux — загрузка AI-моделей
echo "📦 Загрузка базовых моделей Ollama..."
echo

MODELS=(
  "qwen2.5-coder:7b"
  "llama3.2:3b"
  "codellama:7b"
)

for model in "${MODELS[@]}"; do
  echo "→ $model"
  ollama pull "$model" 2>&1 | tail -1
  echo
done

echo "✅ Готово! Запустите ai-chat для общения."
echo "   Или: ollama run qwen2.5-coder"
AISETUPEOF
chmod +x /usr/local/bin/ai-setup

# Скрипт для Open WebUI через Docker
cat > /usr/local/bin/ai-webui << 'WEBUIEOF'
#!/usr/bin/env bash
# VibeLinux — запуск Open WebUI (Docker)
CONTAINER="open-webui"
PORT="${AI_WEBUI_PORT:-3000}"

if ! command -v docker &>/dev/null; then
  echo "Docker не установлен."
  exit 1
fi

if docker ps --format '{{.Names}}' | grep -q "$CONTAINER"; then
  echo "Open WebUI уже запущен: http://localhost:$PORT"
  exit 0
fi

if docker ps -a --format '{{.Names}}' | grep -q "$CONTAINER"; then
  echo "Запуск остановленного контейнера..."
  docker start "$CONTAINER"
else
  echo "Создание контейнера Open WebUI..."
  docker run -d -p "$PORT":8080 \
    --add-host=host.docker.internal:host-gateway \
    -v open-webui:/app/backend/data \
    --name "$CONTAINER" \
    --restart always \
    ghcr.io/open-webui/open-webui:main
fi

echo "✅ Open WebUI: http://localhost:$PORT"
WEBUIEOF
chmod +x /usr/local/bin/ai-webui

# Rust setup (run as user after boot)
cat >> /home/vibe/.zshrc << 'EOF'
if command -v rustup &>/dev/null && [[ ! -f "$HOME/.cargo/env" ]]; then
  rustup default stable 2>/dev/null || true
fi
EOF

echo "=== Done ==="
