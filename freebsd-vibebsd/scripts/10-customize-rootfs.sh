#!/bin/sh
# VibeBSD — шаг 1: кастомизация rootfs jail (брендинг, пользователь, конфиги).
#
# Пакеты НЕ ставим здесь — их добавит poudriere image из packages/*.txt.
# Здесь только файлы: rc.conf, пользователь, темы, конфиги терминала/shell.
#
# Использование:
#   ./10-customize-rootfs.sh [JAIL_NAME]

set -eu

JAIL_NAME="${1:-vibebsd}"
JAIL="/usr/local/poudriere/jails/$JAIL_NAME"
BASE_DIR="$(dirname "$(realpath "$0")")/.."
BRANDING_DIR="$(cd "$BASE_DIR/../../branding" && pwd)"
CONF_DIR="$BASE_DIR/etc"
USER_NAME="vibebsd"
USER_SHELL="/usr/local/bin/zsh"

log() { printf '\033[1;34m[vibebsd]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[err]\033[0m %s\n' "$*" >&2; }

if [ "$(id -u)" -ne 0 ]; then
    err "Run as root"
    exit 1
fi

if [ ! -d "$JAIL/etc" ]; then
    err "Jail $JAIL_NAME not found at $JAIL — run 00-setup-poudriere.sh first"
    exit 1
fi

# ---------------------------------------------------------------
# 1) Брендинг VibeBSD
# ---------------------------------------------------------------
log "Copying branding assets..."
mkdir -p "$JAIL/usr/local/share/vibebsd"
if [ -d "$BRANDING_DIR" ]; then
    cp -r "$BRANDING_DIR/wallpapers" "$JAIL/usr/local/share/vibebsd/" 2>/dev/null || true
    cp -r "$BRANDING_DIR/logos" "$JAIL/usr/local/share/vibebsd/" 2>/dev/null || true
    # Обои доступны всем пользователям через каталог plasma
    mkdir -p "$JAIL/usr/local/share/wallpapers"
    cp "$BRANDING_DIR"/wallpapers/* "$JAIL/usr/local/share/wallpapers/" 2>/dev/null || true
else
    log "branding/ not found — skipping (reuse from archiso profile)"
fi

# ---------------------------------------------------------------
# 2) rc.conf / loader.conf
# ---------------------------------------------------------------
log "Writing /etc/rc.conf..."
cat > "$JAIL/etc/rc.conf" <<'EOF'
# VibeBSD rc.conf
hostname="vibebsd"
# Интерфейс — dhcp на первом iface (переопределяется установщиком)
ifconfig_DEFAULT="DHCP"

# Системные сервисы
dbus_enable="YES"
powerd_enable="YES"
moused_enable="YES"
# GPU KMS-драйверы — ставятся пакетом drm-kmod (опц.), модули подгружаются
# автоматически: kld_list="i915kms amdgpu"

# SDDM (дисплей-менеджер, autologin настроен в sddm.conf)
sddm_enable="YES"

# Ollama — локальные LLM
ollama_enable="YES"
EOF

log "Writing /boot/loader.conf..."
cat > "$JAIL/boot/loader.conf" <<'EOF'
# VibeBSD loader.conf
kern.vty="vt"
autoboot_delay="3"
EOF

# ---------------------------------------------------------------
# 3) Пользователь vibebsd (autologin в SDDM)
# ---------------------------------------------------------------
log "Creating user $USER_NAME..."
mkdir -p "$JAIL/home/$USER_NAME"
pw -R "$JAIL" useradd -n "$USER_NAME" -d /home/$USER_NAME -m \
    -s "$USER_SHELL" -G wheel -c "VibeBSD User" 2>/dev/null || \
    pw -R "$JAIL" user mod "$USER_NAME" -s "$USER_SHELL"
UINFO="$(pw -R "$JAIL" usershow "$USER_NAME")"
UID_N="$(echo "$UINFO" | awk -F: '{print $3}')"
GID_N="$(echo "$UINFO" | awk -F: '{print $4}')"
[ -n "$UID_N" ] && chown -R "${UID_N}:${GID_N}" "$JAIL/home/$USER_NAME" 2>/dev/null || true

log "Configuring passwordless sudo for wheel..."
mkdir -p "$JAIL/usr/local/etc/sudoers.d"
cat > "$JAIL/usr/local/etc/sudoers.d/vibebsd" <<'EOF'
%wheel ALL=(ALL) NOPASSWD: ALL
EOF
chmod 440 "$JAIL/usr/local/etc/sudoers.d/vibebsd"

log "Writing /usr/local/etc/sddm.conf (autologin)..."
mkdir -p "$JAIL/usr/local/etc"
cat > "$JAIL/usr/local/etc/sddm.conf" <<EOF
[Autologin]
User=$USER_NAME
Session=plasma

[General]
HaltCommand=/sbin/shutdown -p now
RebootCommand=/sbin/shutdown -r now
EOF

# ---------------------------------------------------------------
# 4) Конфиги shell/терминала (копируем из freebsd-vibebsd/etc)
# ---------------------------------------------------------------
if [ -d "$CONF_DIR" ]; then
    log "Copying shell/terminal configs..."
    UHOME="$JAIL/home/$USER_NAME"
    mkdir -p "$UHOME/.config/kitty" "$UHOME/.config/starship"

    [ -f "$CONF_DIR/zshrc" ]       && cp "$CONF_DIR/zshrc"       "$UHOME/.zshrc"
    [ -f "$CONF_DIR/starship.toml" ] && cp "$CONF_DIR/starship.toml" "$UHOME/.config/starship/starship.toml"
    [ -f "$CONF_DIR/kitty.conf" ]  && cp "$CONF_DIR/kitty.conf"  "$UHOME/.config/kitty/kitty.conf"
    [ -n "$UID_N" ] && chown -R "${UID_N}:${GID_N}" "$UHOME" 2>/dev/null || true
fi

# ---------------------------------------------------------------
# 5) Скрипт первого входа (опционально)
# ---------------------------------------------------------------
log "Installing first-run helper..."
mkdir -p "$JAIL/usr/local/bin"
cat > "$JAIL/usr/local/bin/vibebsd-firstrun" <<'EOF'
#!/bin/sh
# VibeBSD first-run: подсказки и установка AI-стекa (post-install)
echo "== VibeBSD =="
echo "  Ollama:  ollama run qwen2.5-coder"
echo "  АПИ:     http://localhost:11434"
echo ""
echo "Установка Python AI-библиотек (transformers, langchain, torch):"
echo "  uv pip install --system transformers langchain llama-index torch"
EOF
chmod +x "$JAIL/usr/local/bin/vibebsd-firstrun"

log "Done. Next: ./20-build-iso.sh"
