#!/usr/bin/env bash
set -e

echo "=== VibeLinux Minimal customization ==="

# Hostname
echo "vibelinux-mini" > /etc/hostname
cat > /etc/hosts << EOF
127.0.0.1 localhost
127.0.1.1 vibelinux-mini
::1       localhost
EOF

# MOTD
cat > /etc/motd << 'EOF'

█   █ ███ ████  █████ █     ███ █   █ █   █ █   █
█   █  █  █   █ █     █      █  ██  █ █   █  █ █
█   █  █  ████  ████  █      █  █ █ █ █   █   █
 █ █   █  █   █ █     █      █  █  ██ █   █  █ █
  █   ███ ████  █████ █████ ███ █   █  ███  █   █

 VibeLinux Minimal — CLI-only Arch Linux

 Установка на диск:  sudo vinstall

 Раскладка RU/EN:     Alt+Shift   (по умолчанию EN; Alt+Shift один раз — русский ввод)

 ── AI-агенты (уже предустановлены) ─────────────────────────
   claude, codex, qwen, kimi, kilo, mimo, cn, koda, src (SourceCraft)
   dmed, dmsh, crush, opencode            запуск: <имя> --help
   terminal AI chat:  ai-chat

 Доустановка AI-стека (после установки на диск):
   sudo /opt/vibecode/scripts/ai/setup-ai-stack.sh
   Другие сценарии: ls /opt/vibecode/scripts/ai/

 ── Инструменты ────────────────────────────────────────────
   btop (монитор), mc (файловый менеджер), tmux (мультиплексор)
   rg, fd, bat, jq | fish (шелл) | vim/nano (редакторы)

   Информация о системе: fastfetch
EOF

# OS Release
cat > /etc/os-release << 'EOF'
NAME="VibeLinux Minimal"
PRETTY_NAME="VibeLinux Minimal"
ID=vibelinux
ID_LIKE=arch
VERSION=2026.08
VERSION_CODENAME=genesis
HOME_URL="https://dmintegroff.ru"
DOCUMENTATION_URL="https://github.com/vibelinux/docs"
SUPPORT_URL="https://github.com/vibelinux"
BUG_REPORT_URL="https://github.com/vibelinux/issues"
LOGO=/usr/share/pixmaps/vibelinux.svg
EOF

# Timezone
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# Locale
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
sed -i 's/#ru_RU.UTF-8/ru_RU.UTF-8/' /etc/locale.gen
locale-gen
cat > /etc/locale.conf << 'EOF'
LANG=ru_RU.UTF-8
LANGUAGE=ru_RU:ru
EOF

# Локаль для всех systemd-сессий (agetty autologin, ssh и т.п.), чтобы даже
# процессам, запущенным ДО fish, доставалась ru_RU, а не C/English.
cat > /etc/environment << 'EOF'
LANG=ru_RU.UTF-8
LANGUAGE=ru_RU:ru
LC_CTYPE=ru_RU.UTF-8
LC_NUMERIC=ru_RU.UTF-8
LC_TIME=ru_RU.UTF-8
LC_COLLATE=C
LC_MONETARY=ru_RU.UTF-8
LC_MESSAGES=ru_RU.UTF-8
LC_PAPER=ru_RU.UTF-8
LC_NAME=ru_RU.UTF-8
LC_ADDRESS=ru_RU.UTF-8
LC_TELEPHONE=ru_RU.UTF-8
LC_MEASUREMENT=ru_RU.UTF-8
LC_IDENTIFICATION=ru_RU.UTF-8
EOF

# Console (TTY): кириллический шрифт + русская раскладка с переключением на EN
# по Alt+Shift. Всё из базового пакета kbd (терминальные шрифты + keymaps),
# поэтому отдельные пакеты не нужны.
#   FONT=cyr-sun16   — современный консольный шрифт с кириллицей и латиницей
#   KEYMAP=ruwin_alt_sh-UTF-8 — русская раскладка; Alt+Shift переключает ru/en
cat > /etc/vconsole.conf << 'EOF'
KEYMAP=ruwin_alt_sh-UTF-8
FONT=cyr-sun16
EOF

# Гарантированно применяем кириллический шрифт и раскладку при загрузке
# (systemd-vconsole-setup не всегда отрабатывает в live до getty).
systemctl enable vibelinux-console.service 2>/dev/null || true

# Default shell (fish)
# usermod -s ставит shell напрямую (без валидации /etc/shells и PAM-лока,
# из-за которых chsh в chroot молча падает). Плюс явно добавляем fish в
# /etc/shells для корректности (автодополнение, другие утилиты).
if ! grep -qx '/usr/bin/fish' /etc/shells 2>/dev/null; then
  echo '/usr/bin/fish' >> /etc/shells
fi
usermod -s /usr/bin/fish root 2>/dev/null || true

# User
if ! id vibe &>/dev/null; then
  useradd -m -G wheel -s /bin/bash vibe
  echo "vibe:vibe" | chpasswd
fi
usermod -s /usr/bin/fish vibe 2>/dev/null || true
echo "vibe ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90_vibe
chmod 440 /etc/sudoers.d/90_vibe

# Midnight Commander config for vibe (XDG-compatible)
mkdir -p /home/vibe/.config/mc/ini /home/vibe/.config/mc/history
cat > /home/vibe/.config/mc/ini/panels.ini << 'EOF'
[Panels]
show_backups=1
show_dot_files=1
fast_refresh=1
reverse_files_only=1
auto_menu=1
show_size_in_bytes=0
show_free_space=1
EOF

cat > /home/vibe/.config/mc/ini/mc.keymap << 'EOF'
# Vibelinux minimal keymap
[Browse]
# Ctrl+O opens shell in current dir (default bash binding, keep it)
shell=shell
# F9 = menu, F10 = quit, arrows = navigate (defaults)
EOF

cat > /home/vibe/.config/mc/ini/ini << 'EOF'
[Midnight-Commander]
verbose=1
auto_save_setup=1
confirm_delete=1
confirm_overwrite=1
confirm_execute=0
confirm_exit=0
confirm_directory_switch=0
confirm_resize=0
confirm_quit_cyclic_switch=0
confirm_virtual_copy_move=0
confirm_history_cleanup=0
use_internal_view=1
use_internal_edit=1
show_all_status=1
beep=0
skin=darkfar
use_links=1
EOF

chown -R vibe:vibe /home/vibe/.config

# Enable wheel group sudo
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Services
systemctl enable NetworkManager || true
systemctl enable systemd-timesyncd || true
systemctl enable sshd || true

# Getty autologin on tty1 for vibe
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin vibe --noclear %I \$TERM
EOF

# Minimal /dev
if [[ ! -e /dev/null ]]; then
  mknod /dev/null c 1 3
  mknod /dev/zero c 1 5
  mknod /dev/random c 1 8
  mknod /dev/urandom c 1 9
  chmod 666 /dev/{null,zero,random,urandom}
fi

# Kernel
if [[ ! -s /boot/vmlinuz-linux ]]; then
  KVER=$(ls /usr/lib/modules/ 2>/dev/null | grep -v 'extramodules' | sort -V | tail -1)
  if [[ -n "$KVER" && -f "/usr/lib/modules/$KVER/vmlinuz" ]]; then
    cp --sparse=never -f "/usr/lib/modules/$KVER/vmlinuz" /boot/vmlinuz-linux
    chmod 644 /boot/vmlinuz-linux
    echo "OK: copied kernel to /boot/vmlinuz-linux ($(stat -c%s /boot/vmlinuz-linux) bytes)"
  fi
fi

# mkinitcpio — minimal config (no nvidia, no Plymouth)
# NOTE: БЕЗ `autodetect`. Этот хук падает внутри archiso-chroot
# ("failed to detect root filesystem"), из-за чего initramfs собирается
# неполностью (только модули, без /init и live-хуков) и ISO не загружается.
# archiso hook обязателен для монтирования squashfs airootfs.
cat > /etc/mkinitcpio.conf << 'EOF'
MODULES=()
BINARIES=()
FILES=()
HOOKS=(base udev modconf block filesystems keyboard fsck archiso)
COMPRESSION="zstd"
COMPRESSION_OPTIONS=(-15)
EOF

if command -v mkinitcpio &>/dev/null; then
  mkinitcpio -P || echo "WARNING: mkinitcpio failed"
fi

# === AI CLI AGENTS ===
echo "Installing AI CLI agents..."

# npm agents
NPM_AGENTS=(
  "@qwen-code/qwen-code:qwen"
  "@anthropic-ai/claude-code:claude"
  "@openai/codex:codex"
  "@kilocode/cli:kilo"
  "@mimo-ai/cli:mimo"
  "@continuedev/cli:cn"
  "@moonshot-ai/kimi-code:kimi"
  "@kodadev/koda-cli:koda"
)
for entry in "${NPM_AGENTS[@]}"; do
  pkg="${entry%%:*}"; bin="${entry##*:}"
  if command -v "$bin" >/dev/null 2>&1; then
    echo "OK: $bin already installed"
  else
    echo "Installing $pkg (-> $bin)..."
    npm install -g "$pkg" 2>&1 | tail -3 || echo "WARNING: $pkg install failed"
  fi
done

# Claude Code postinstall
CLAUDE_GLOBAL="$(npm root -g)/@anthropic-ai/claude-code"
if [[ -f "$CLAUDE_GLOBAL/install.cjs" ]]; then
  echo "Running claude-code postinstall..."
  node "$CLAUDE_GLOBAL/install.cjs" || echo "WARNING: claude-code postinstall failed"
fi

# SourceCraft Code Assistant CLI (Яндекс) — официальный installer.
# Ставим глобально (-i /usr/local → /usr/local/bin) и без правки rc-файлов (-n),
# иначе установщик кладёт бинарник в $HOME/sourcecraft/bin/src (для root → /root),
# и юзер vibe его не увидит. Команда называется `src`.
if ! command -v src >/dev/null 2>&1; then
  echo "Installing SourceCraft CLI..."
  if curl -fsSL --retry 3 https://s3.yandexcloud.net/sourcecraft-cli/install.sh \
      | sh -s -- -i /usr/local -n; then
    echo "OK: sourcecraft (src) installed to /usr/local/bin"
  else
    echo "WARNING: sourcecraft install failed (offline?)"
  fi
fi

# Crush — native binary from GitHub releases
CRUSH_AA=""
case "$(uname -m)" in
  x86_64) CRUSH_AA="x86_64" ;;
  aarch64|arm64) CRUSH_AA="arm64" ;;
esac
if [[ -n "$CRUSH_AA" ]]; then
  CRUSH_VER="$(curl -fsSL --retry 3 https://api.github.com/repos/charmbracelet/crush/releases/latest 2>/dev/null | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1 || true)"
  if [[ -n "$CRUSH_VER" ]]; then
    CRUSH_TMP="$(mktemp -d)"
    if curl -fsSL --retry 3 "https://github.com/charmbracelet/crush/releases/download/${CRUSH_VER}/crush_${CRUSH_VER#v}_Linux_${CRUSH_AA}.tar.gz" -o "$CRUSH_TMP/crush.tar.gz"; then
      tar -xzf "$CRUSH_TMP/crush.tar.gz" -C "$CRUSH_TMP"
      install -Dm 755 "$CRUSH_TMP/crush_${CRUSH_VER#v}_Linux_${CRUSH_AA}/crush" /usr/local/bin/crush \
        && echo "OK: crush ${CRUSH_VER} installed"
    else
      echo "WARNING: crush download failed"
    fi
    rm -rf "$CRUSH_TMP"
  fi
fi
npm uninstall -g "@charmland/crush" >/dev/null 2>&1 || true

# dmsh — extract local package directly (pacman -U fails in archiso chroot)
if compgen -G "/root/dmsh/*.pkg.tar.zst" >/dev/null; then
  mkdir -p /tmp/dmsh-extract
  bsdtar -xf /root/dmsh/*.pkg.tar.zst -C /tmp/dmsh-extract
  cp -a /tmp/dmsh-extract/. / 2>/dev/null
  rm -rf /tmp/dmsh-extract
  # register in pacman db so it shows up in -Q
  mkdir -p /var/lib/pacman/local
  DMSH_VER="$(ls /root/dmsh/*.pkg.tar.zst | grep -oP '\d+\.\d+\.\d+-\d+' | head -1)"
  mkdir -p "/var/lib/pacman/local/dmsh-${DMSH_VER}"
  echo -e "DESC=dmsh\nNAME=dmsh\nVERSION=${DMSH_VER}\nBASE=dmsh\nDEPENDS=\nPROVIDES=\nCONFLICTS=\nREPLACES=\nGROUPS=\nINSTALLDATE=$(date +%s)\nSIZE=11707392\nLICENSE=MIT\nARCH=x86_64\nBUILDDATE=$(date +%s)\nPACKAGER=VibeLinux\nDESCRIPTION=dmsh — AI agent CLI" > "/var/lib/pacman/local/dmsh-${DMSH_VER}/desc"
  echo "OK: dmsh ${DMSH_VER} installed"
else
  echo "WARNING: dmsh package not found in /root/dmsh/"
fi

# Wrapper scripts: redirect cache/tmp to /tmp (tmpfs) to avoid filling overlay
for agent_bin in claude kilo mimo qwen codex opencode dmsh crush kimi dmed src sourcecraft koda; do
  REAL_BIN="$(type -p "$agent_bin" 2>/dev/null || true)"
  if [[ -z "$REAL_BIN" || -f "${REAL_BIN}.real" ]]; then
    continue
  fi
  mv "$REAL_BIN" "${REAL_BIN}.real"
  # Не полагаемся на сохранение exec-бита при copy-up в overlayfs — ставм явно.
  # Иначе dmed (в /usr/local на нижнем слое) получает 644 и "Permission denied".
  chmod +x "${REAL_BIN}.real"
  cat > "$REAL_BIN" << WRAPPEREOF
#!/usr/bin/env bash
export TMPDIR=/tmp
export XDG_CACHE_HOME=/tmp/\${USER:-root}/.cache
export XDG_CONFIG_HOME=/tmp/\${USER:-root}/.config
mkdir -p "\$XDG_CACHE_HOME" "\$XDG_CONFIG_HOME"
exec "${REAL_BIN}.real" "\$@"
WRAPPEREOF
  chmod +x "$REAL_BIN"
done

echo "AI CLI agents installed."

# Fix permissions
chown -R vibe:vibe /home/vibe

echo "=== VibeLinux Minimal customization done ==="
