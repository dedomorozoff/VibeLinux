#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# VibeCode OS — Мастер установки компонентов (Minimal → Full)
# ============================================================================
# Интерактивный скрипт для доустановки компонентов в Minimal-версии
# Запускается в установленной системе!
# ============================================================================

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Символы
CHECK="✓"
CROSS="✗"
ARROW="→"

# Состояние установки
declare -A INSTALLED=(
    [terminal]=0
    [shell]=0
    [langs]=0
    [editors]=0
    [devtools]=0
    [ai]=0
    [nvidia]=0
)

# ============================================================================
# Утилиты
# ============================================================================

print_header() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║           VibeCode OS — Мастер установки                     ║"
    echo "║                    Minimal → Full                            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

print_section() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_option() {
    local num="$1"
    local desc="$2"
    local status="$3"

    if [[ "$status" == "installed" ]]; then
        echo -e "  ${GREEN}[${CHECK}]${NC} ${num}. ${desc} ${GREEN}(установлено)${NC}"
    elif [[ "$status" == "selected" ]]; then
        echo -e "  ${YELLOW}[▶]${NC} ${num}. ${desc}"
    else
        echo -e "  ${CYAN}[ ]${NC} ${num}. ${desc}"
    fi
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Ошибка: Запустите от root (sudo)${NC}"
        exit 1
    fi
}

check_network() {
    curl -sf --connect-timeout 5 https://github.com >/dev/null 2>&1
    return $?
}

# ============================================================================
# Проверка установленных компонентов
# ============================================================================

check_installed() {
    # Терминал (Kitty)
    if command -v kitty >/dev/null 2>&1; then
        INSTALLED[terminal]=1
    fi

    # Shell (Zsh + Starship)
    if command -v zsh >/dev/null 2>&1 && command -v starship >/dev/null 2>&1; then
        INSTALLED[shell]=1
    fi

    # Языки (pyenv, nvm, rustup)
    if [[ -d "$HOME/.pyenv" ]] || [[ -d "$HOME/.nvm" ]] || [[ -d "$HOME/.cargo" ]]; then
        INSTALLED[langs]=1
    fi

    # Редакторы (VSCodium, Neovim)
    if command -v codium >/dev/null 2>&1 || command -v nvim >/dev/null 2>&1; then
        INSTALLED[editors]=1
    fi

    # Devtools (Docker, lazygit)
    if command -v docker >/dev/null 2>&1 || command -v lazygit >/dev/null 2>&1; then
        INSTALLED[devtools]=1
    fi

    # AI (Ollama)
    if command -v ollama >/dev/null 2>&1; then
        INSTALLED[ai]=1
    fi

    # NVIDIA драйверы
    if lspci | grep -i nvidia >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
        INSTALLED[nvidia]=1
    fi
}

get_status() {
    local key="$1"
    if [[ "${INSTALLED[$key]}" == "1" ]]; then
        echo "installed"
    else
        echo "pending"
    fi
}

# ============================================================================
# Установка компонентов
# ============================================================================

install_terminal() {
    print_header
    echo -e "${GREEN}📦 Установка терминала и оболочки...${NC}"
    echo ""

    echo -e "${CYAN}Установка Kitty...${NC}"
    apt-get update -qq
    apt-get install -y kitty

    echo -e "${CYAN}Установка шрифтов...${NC}"
    apt-get install -y fonts-jetbrains-mono fonts-fira-code fonts-hack

    echo -e "${CYAN}Настройка Zsh...${NC}"
    apt-get install -y zsh

    # Oh My Zsh
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        echo -e "${CYAN}Установка Oh My Zsh...${NC}"
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true
    fi

    # Starship
    if ! command -v starship &>/dev/null; then
        echo -e "${CYAN}Установка Starship...${NC}"
        curl -sS https://starship.rs/install.sh | sh -s -- -y || true
    fi

    # CLI-утилиты
    echo -e "${CYAN}Установка CLI-утилит...${NC}"
    apt-get install -y eza bat fd-find ripgrep fzf zoxide btop

    # Исправление имён (Ubuntu)
    ln -sf /usr/bin/batcat /usr/local/bin/bat 2>/dev/null || true
    ln -sf /usr/bin/fdfind /usr/local/bin/fd 2>/dev/null || true

    # Установка Zsh по умолчанию
    chsh -s $(which zsh) 2>/dev/null || true

    echo ""
    echo -e "${GREEN}${CHECK} Терминал и оболочка установлены!${NC}"
    echo ""
    read -p "Нажмите Enter для продолжения..."
}

install_langs() {
    print_header
    echo -e "${GREEN}📦 Установка языков программирования...${NC}"
    echo ""

    # Зависимости
    echo -e "${CYAN}Установка зависимостей...${NC}"
    apt-get update -qq
    apt-get install -y build-essential curl git ca-certificates libssl-dev zlib1g-dev \
        libbz2-dev libreadline-dev libsqlite3-dev wget llvm libncursesw5-dev xz-utils \
        tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

    # Pyenv
    if [[ ! -d "$HOME/.pyenv" ]]; then
        echo -e "${CYAN}Установка pyenv...${NC}"
        curl -fsSL https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash || true

        # Добавляем в .zshrc
        if [[ -f "$HOME/.zshrc" ]] && ! grep -q "pyenv init" "$HOME/.zshrc"; then
            cat >> "$HOME/.zshrc" << 'PYEOF'
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
PYEOF
        fi
    fi

    # NVM
    if [[ ! -d "$HOME/.nvm" ]]; then
        echo -e "${CYAN}Установка nvm...${NC}"
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash || true
    fi

    # Rustup
    if [[ ! -d "$HOME/.cargo" ]]; then
        echo -e "${CYAN}Установка rustup...${NC}"
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y || true
    fi

    # SDKMAN
    if [[ ! -d "$HOME/.sdkman" ]]; then
        echo -e "${CYAN}Установка SDKMAN!...${NC}"
        curl -s "https://get.sdkman.io" | bash || true
    fi

    # Go
    if ! command -v go &>/dev/null; then
        echo -e "${CYAN}Установка Go...${NC}"
        apt-get install -y golang-go || true
    fi

    echo ""
    echo -e "${GREEN}${CHECK} Языки установлены! Перезайдите в терминал для применения.${NC}"
    read -p "Нажмите Enter для продолжения..."
}

install_editors() {
    print_header
    echo -e "${GREEN}📦 Установка редакторов и IDE...${NC}"
    echo ""

    # VSCodium
    if ! command -v codium &>/dev/null; then
        echo -e "${CYAN}Установка VSCodium...${NC}"
        wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg | gpg --dearmor > /usr/share/keyrings/vscodium-archive-keyring.gpg 2>/dev/null || true
        echo 'deb [ signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg ] https://download.vscodium.com/debs vscodium main' | tee /etc/apt/sources.list.d/vscodium.list >/dev/null
        apt-get update -qq
        apt-get install -y codium || true
    fi

    # Neovim
    if ! command -v nvim &>/dev/null; then
        echo -e "${CYAN}Установка Neovim...${NC}"
        apt-get install -y neovim || true
    fi

    # AstroNvim
    if [[ ! -d "$HOME/.config/nvim" ]]; then
        echo -e "${CYAN}Установка AstroNvim...${NC}"
        git clone --depth 1 https://github.com/AstroNvim/template "$HOME/.config/nvim" 2>/dev/null && rm -rf "$HOME/.config/nvim/.git" || true
    fi

    # Zed
    if ! command -v zed &>/dev/null; then
        echo -e "${CYAN}Установка Zed...${NC}"
        curl -f https://zed.dev/install.sh | sh || true
    fi

    echo ""
    echo -e "${GREEN}${CHECK} Редакторы установлены!${NC}"
    read -p "Нажмите Enter для продолжения..."
}

install_devtools() {
    print_header
    echo -e "${GREEN}📦 Установка инструментов разработчика...${NC}"
    echo ""

    # Git
    if ! command -v git &>/dev/null; then
        echo -e "${CYAN}Установка Git...${NC}"
        apt-get install -y git || true
    fi

    # lazygit
    if ! command -v lazygit &>/dev/null; then
        echo -e "${CYAN}Установка lazygit...${NC}"
        LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -oP '"tag_name": "v\K[^"]*' 2>/dev/null || echo "")
        if [[ -n "$LAZYGIT_VERSION" ]]; then
            curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" 2>/dev/null || true
            tar xf /tmp/lazygit.tar.gz -C /tmp lazygit 2>/dev/null || true
            install /tmp/lazygit /usr/local/bin/lazygit 2>/dev/null || true
            rm -f /tmp/lazygit /tmp/lazygit.tar.gz
        fi
    fi

    # Docker
    if ! command -v docker &>/dev/null; then
        echo -e "${CYAN}Установка Docker...${NC}"
        apt-get install -y docker.io docker-compose-plugin || true
        systemctl enable docker 2>/dev/null || true
        systemctl start docker 2>/dev/null || true
    fi

    # Добавляем пользователя в группу docker
    usermod -aG docker "$USER" 2>/dev/null || true

    echo ""
    echo -e "${GREEN}${CHECK} Инструменты установлены!${NC}"
    echo -e "${YELLOW}⚠️  Для работы Docker может потребоваться перезагрузка.${NC}"
    read -p "Нажмите Enter для продолжения..."
}

install_ai() {
    print_header
    echo -e "${GREEN}📦 Установка AI-стека...${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  Внимание: AI-стек требует много места (~10-20 ГБ)${NC}"
    echo ""
    read -p "Продолжить? (y/n): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Пропущено${NC}"
        read -p "Нажмите Enter для продолжения..."
        return
    fi

    # Ollama
    if ! command -v ollama &>/dev/null; then
        echo -e "${CYAN}Установка Ollama...${NC}"
        curl -fsSL https://ollama.com/install.sh | sh || true
        systemctl enable ollama 2>/dev/null || true
        systemctl start ollama 2>/dev/null || true
    fi

    # Open WebUI (Docker)
    if command -v docker &>/dev/null; then
        echo -e "${CYAN}Установка Open WebUI...${NC}"
        docker run -d --name open-webui -p 3000:8080 --add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data --restart always ghcr.io/open-webui/open-webui:main 2>/dev/null || true
    fi

    # ai-chat (локальный скрипт)
    if [[ ! -f /usr/local/bin/ai-chat ]]; then
        echo -e "${CYAN}Установка ai-chat...${NC}"
        cat > /usr/local/bin/ai-chat << 'AIEOF'
#!/usr/bin/env bash
MODEL="${1:-llama3.2}"
echo "AI Chat (модель: $MODEL). Введите /exit для выхода."
while true; do
    read -p "> " prompt
    [[ "$prompt" == "/exit" ]] && break
    [[ -z "$prompt" ]] && continue
    ollama chat "$MODEL" -m "$prompt" 2>/dev/null || echo "Ошибка: ollama не запущена"
done
AIEOF
        chmod +x /usr/local/bin/ai-chat
    fi

    # Aider
    if ! command -v aider &>/dev/null; then
        echo -e "${CYAN}Установка Aider...${NC}"
        pip3 install aider-chat || true
    fi

    # Python AI-библиотеки
    echo -e "${CYAN}Установка Python AI-библиотек...${NC}"
    pip3 install langchain langchain-community llama-index transformers accelerate ollama 2>/dev/null || true

    # ComfyUI
    if [[ ! -d "$HOME/ComfyUI" ]]; then
        echo -e "${CYAN}Установка ComfyUI...${NC}"
        cd "$HOME" && git clone https://github.com/comfyanonymous/ComfyUI.git 2>/dev/null || true
    fi

    echo ""
    echo -e "${GREEN}${CHECK} AI-стек установлен!${NC}"
    echo ""
    echo -e "${CYAN}Быстрый старт:${NC}"
    echo "  • Open WebUI: http://localhost:3000"
    echo "  • Terminal: ai-chat"
    echo "  • ComfyUI: cd ~/ComfyUI && python main.py"
    read -p "Нажмите Enter для продолжения..."
}

install_nvidia() {
    print_header
    echo -e "${GREEN}📦 Установка драйверов NVIDIA...${NC}"
    echo ""

    # Проверка наличия NVIDIA GPU
    if ! lspci | grep -i nvidia >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Видеокарта NVIDIA не найдена. Пропускаем.${NC}"
        read -p "Нажмите Enter для продолжения..."
        return
    fi

    echo -e "${CYAN}Обнаружена видеокарта NVIDIA. Установка драйверов...${NC}"

    # Добавляем репозиторий NVIDIA
    add-apt-repository -y ppa:graphics-drivers/ppa 2>/dev/null || true
    apt-get update -qq

    # Установка драйвера
    apt-get install -y nvidia-driver-535 nvidia-utils-535 || true

    echo ""
    echo -e "${GREEN}${CHECK} Драйверы установлены!${NC}"
    echo -e "${YELLOW}⚠️  Требуется перезагрузка для применения.${NC}"
    read -p "Нажмите Enter для продолжения..."
}

install_all() {
    print_header
    echo -e "${GREEN}📦 Установка ВСЕХ компонентов (Full версия)...${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  Это займёт время и потребует много места (~20-30 ГБ)${NC}"
    echo ""
    read -p "Продолжить? (y/n): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Отменено${NC}"
        read -p "Нажмите Enter для продолжения..."
        return
    fi

    install_terminal
    install_langs
    install_editors
    install_devtools
    install_ai
    install_nvidia

    print_header
    echo -e "${GREEN}${CHECK} Все компоненты установлены!${NC}"
    echo ""
    echo "🎉 VibeCode OS Full готова к работе!"
    echo ""
    echo -e "${CYAN}Рекомендуется перезагрузить систему.${NC}"
    read -p "Нажмите Enter для продолжения..."
}

# ============================================================================
# Основная логика
# ============================================================================

main() {
    check_root

    # Определяем текущего пользователя (не root)
    if [[ -n "${SUDO_USER:-}" ]]; then
        USER="$SUDO_USER"
    else
        USER="$(whoami)"
    fi
    HOME="/home/$USER"

    # Приветствие
    print_header
    echo -e "${CYAN}Добро пожаловать в VibeCode OS Minimal!${NC}"
    echo ""
    echo "Этот мастер поможет вам доустановить компоненты до Full-версии."
    echo ""
    echo -e "${YELLOW}Совет: Сначала выберите 'R' для проверки установленных компонентов.${NC}"
    echo ""
    sleep 2

    while true; do
        check_installed
        show_main_menu

        read -r input

        case "$input" in
            1)
                install_terminal
                ;;
            2)
                install_langs
                ;;
            3)
                install_editors
                ;;
            4)
                install_devtools
                ;;
            5)
                install_ai
                ;;
            6)
                install_nvidia
                ;;
            [Aa])
                install_all
                ;;
            [Rr])
                check_installed
                echo -e "${GREEN}✓ Проверка выполнена!${NC}"
                sleep 1
                ;;
            [Qq0])
                print_header
                echo -e "${GREEN}Спасибо за использование VibeCode OS!${NC}"
                echo ""
                exit 0
                ;;
            *)
                # Обработка нескольких цифр через пробел
                for num in $input; do
                    case "$num" in
                        1) install_terminal ;;
                        2) install_langs ;;
                        3) install_editors ;;
                        4) install_devtools ;;
                        5) install_ai ;;
                        6) install_nvidia ;;
                    esac
                done
                ;;
        esac
    done
}

# Запуск
main
