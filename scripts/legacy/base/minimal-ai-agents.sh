#!/usr/bin/env bash
set -uo pipefail

# Установка AI CLI агентов VibeCode OS в чрут минимального образа.
# Каждый агент ставится толерантно: сбой одного не ломает сборку.
# Ожидается запуск от root внутри chroot (Ubuntu 24.04).

AI_DIR="/opt/vibecode/scripts/ai"

log() { echo "[minimal-ai-agents] $*"; }

export DEBIAN_FRONTEND=noninteractive
# Обход PEP 668 (externally-managed-environment) для pip-установок
export PIP_BREAK_SYSTEM_PACKAGES=1

# --- Node.js 20+ (NodeSource): нужен для qwen-code, желательно для остальных ---
log "Проверка версии Node.js..."
node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
if [[ "${node_major}" -lt 20 ]]; then
  log "Установка Node.js 22.x из NodeSource..."
  if curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs; then
    log "OK: $(node -v)"
  else
    log "WARNING: NodeSource недоступен, остаёмся на дистрибутивном Node.js ($(node -v 2>/dev/null || echo 'нет'))"
  fi
else
  log "OK: уже установлен Node.js $(node -v)"
fi

# Страховка: у NodeSource-сборки npm встроен в пакет nodejs и может быть
# недоступен в PATH (конфликт с дистрибутивным npm). Чиним симлинки.
if ! command -v npm >/dev/null 2>&1 || ! npm -v >/dev/null 2>&1; then
  if [[ -f /usr/lib/node_modules/npm/bin/npm-cli.js ]]; then
    log "Восстановление npm из встроенной копии NodeSource..."
    ln -sf /usr/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm
    ln -sf /usr/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx
  fi
fi
command -v npm >/dev/null 2>&1 && log "npm $(npm -v) готов" || log "WARNING: npm недоступен — npm-агенты не установятся"

install_agent() {
  local name="$1"
  local script="$2"
  log "Установка: ${name}..."
  if bash "${AI_DIR}/${script}"; then
    log "OK: ${name}"
  else
    log "WARNING: ${name} не установился (сеть/репозиторий?), продолжаем без него"
  fi
}

install_agent "Claude Code"        install-claude-code.sh
install_agent "OpenAI Codex CLI"   install-codex-cli.sh
install_agent "Qwen Code"          install-qwen-code.sh
install_agent "Kimi Code CLI"      install-kimi.sh
install_agent "GitHub Copilot CLI" install-github-copilot-cli.sh
install_agent "Crush"              install-crush.sh
install_agent "OpenAI CLI"         install-openai-cli.sh
install_agent "Terminal AI (ai-chat)" install-terminal-ai.sh

log "Итог:"
for cmd in claude codex qwen kimi copilot crush ai-chat; do
  if command -v "${cmd}" >/dev/null 2>&1; then
    log "  ✓ ${cmd} -> $(command -v ${cmd})"
  else
    log "  ✗ ${cmd} отсутствует"
  fi
done

log "Готово."
