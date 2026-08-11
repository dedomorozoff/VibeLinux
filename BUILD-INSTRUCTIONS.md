# Сборка VibeCode OS ISO

## Быстрый старт

```bash
# 1. Проверка зависимостей (legacy Ubuntu)
make legacy-check
make legacy-check-mini

# 2. Сборка
make arch           # основная версия (Arch Linux, KDE Plasma 6 + полный стек)
make legacy-full    # legacy (Ubuntu 24.04, KDE Plasma + dev)
make legacy-mini    # legacy (Ubuntu, CLI-only)
```

---

## Редакции

| Параметр | **Arch (основная)** | **Full (Ubuntu, legacy)** | **Minimal (Ubuntu, legacy)** |
|----------|---------------------|----------------------------|------------------------------|
| **База** | Arch Linux (rolling) | Ubuntu 24.04 LTS | Ubuntu 24.04 LTS |
| **GUI** | KDE Plasma 6 | KDE Plasma | Нет (CLI) |
| **Установщик** | Calamares | Ubiquity | Текстовый скрипт |
| **Dev-стек** | Полный | Полный | Базовый |
| **AI-стек** | ✅ | ✅ | ❌ |
| **Размер ISO** | ~3-4 ГБ | ~3-4 ГБ | ~600-800 МБ |

## Состав сборок

### Minimal (scripts/legacy/build-minimal-iso.sh) — Ubuntu, legacy
**Скрипт:** `scripts/legacy/build-minimal-iso.sh`  
**Chroot скрипт:** `scripts/legacy/base/minimal-packages-chroot.sh`

**Пакеты (согласно PACKAGES.md):**
- Ядро: `linux-image-virtual`
- Live: `casper`, `squashfs-tools`
- Оболочка: `zsh`, `tmux`
- Редакторы: `nano`, `vim-tiny`
- Утилиты: `mc`, `btop`, `curl`, `wget`, `unzip`, `zip`, `git`
- Dev: `build-essential`
- Сеть: `network-manager`, `iputils-ping`, `net-tools`, `traceroute`
- Дополнительно: `tree`, `p7zip-full`, `neofetch`, `virtualbox-guest-utils`

**Размер ISO:** ~600-800 МБ

### Full (scripts/legacy/build-iso.sh) — Ubuntu, legacy
**Скрипт:** `scripts/legacy/build-iso.sh`  
**Chroot скрипт:** `scripts/legacy/base/full-packages-chroot.sh`

**Компоненты:**
- **KDE Plasma** + SDDM (autologin)
- **Терминал:** Kitty, Zsh, Oh My Zsh, Starship
- **CLI утилиты:** eza, bat, fd, rg, fzf, zoxide, btop
- **Языки:** Python3, Node.js, Go, Rust, Java 17
- **Редакторы:** VSCodium, Neovim
- **Dev:** Git, Docker, cmake, build-essential
- **AI:** Ollama, Python AI-библиотеки (torch, transformers, langchain)
- **Шрифты:** JetBrains Mono, Fira Code, Cascadia Code

**Размер ISO:** ~3-4 ГБ

### Arch (scripts/build/build-vibe-arch.sh)
**Скрипт:** `scripts/build/build-vibe-arch.sh`
**Профиль:** `archiso-vibelinux/`
**Кастомизация:** `archiso-vibelinux/airootfs/root/customize_airootfs.sh`

**Компоненты:**
- **KDE Plasma** + SDDM (autologin)
- **Установщик:** Calamares (графический, ярлык на рабочем столе)
- **Терминал:** Kitty, Konsole, Zsh + Oh My Zsh + Starship
- **CLI утилиты:** eza, bat, fd, rg, fzf, zoxide, btop
- **Языки:** Python + pyenv, Node.js + nvm, Rust + rustup, Go, Java (SDKMAN!), PHP
- **Редакторы:** VS Code, Zed, Neovim + AstroNvim, Kate
- **AI:** Ollama, opencode, qwen-code, Python AI-библиотеки (torch, transformers, llama-index)
- **Графика:** Pinta, Spectacle, Flameshot
- **API:** Bruno
- **БД:** sqlite3 + sqliteman
- **Контейнеры:** Docker + docker-compose
- **Браузер:** Firefox
- **AUR-пакеты:** yay, zed-editor-bin, visual-studio-code-bin, bruno-bin, calamares

**Размер ISO:** ~3-4 ГБ

**Установка на диск:**
1. Загрузиться с ISO
2. На рабочем столе KDE — ярлык **Install VibeLinux**
3. Calamares проведёт через: язык → раскладка → разметка → пользователь → установка
4. После завершения — перезагрузка

## Структура скриптов

```
scripts/
├── build/                        # Основная линия (Arch Linux)
│   ├── build-vibe-arch.sh        # Arch Linux + KDE Plasma 6
│   ├── install-vibelinux-arch.sh # Установка VibeLinux на хост Arch
│   └── prepare-aur.sh            # Подготовка AUR
├── legacy/                       # Ubuntu-редакции (legacy)
│   ├── build-minimal-iso.sh      # Сборка Minimal ISO
│   ├── build-iso.sh              # Сборка Full ISO
│   ├── minimal-upgrade.sh        # Мастер доустановки (vibecode-upgrade)
│   ├── base/                     # Ubuntu-специфичные пакетные скрипты
│   └── desktop/                  # DE-скрипты (KDE, i3wm, Hyprland)
└── base/
    ├── generate-build-script.sh  # Генератор скриптов из JSON
    └── vibe-wizard.sh            # Пост-установочный мастер
```

## Как это работает

**Основная сборка (Arch Linux)** — `archiso` (профиль `archiso-vibelinux/`):
`pacstrap` → `customize_airootfs.sh` → `mksquashfs` → `xorriso`.

**Legacy-сборки (Ubuntu):**
1. **debootstrap** разворачивает базовую Ubuntu 24.04
2. **chroot скрипт** устанавливает пакеты и настраивает систему
3. **mkinitramfs** создаёт initrd с casper hook
4. **mksquashfs** упаковывает rootfs в filesystem.squashfs
5. **grub-mkrescue** создаёт загрузочный ISO

## Структура ISO

```
ISO:
├── boot/
│   ├── grub/grub.cfg      # Параметры: boot=casper
│   ├── vmlinuz            # Ядро
│   └── initrd.img         # Initrd с casper
├── casper/
│   └── filesystem.squashfs
└── .disk/
    └── info
```

## Отладка

### Если kernel panic:
```bash
# Добавить debug в GRUB параметры:
linux /boot/vmlinuz boot=casper debug break=bottom ---

# Проверить initrd:
lsinitramfs /path/to/initrd.img | grep casper

# Проверить squashfs:
unsquashfs -l filesystem.squashfs | head
```

### Если не загружается:
```bash
# QEMU тест:
qemu-system-x86_64 -cdrom VibeCodeOS.iso -boot d -m 4096

# VirtualBox:
VBoxManage createvm --name "VibeCode Test" --register
VBoxManage storagectl "VibeCode Test" --name "IDE" --add ide
VBoxManage storageattach "VibeCode Test" --storagectl IDE \
  --port 0 --medium VibeCodeOS.iso --type dvddrive
```

## Документация

- `PACKAGES.md` — полный список пакетов
- `docs/LIVE-ISO-FIXES.md` — исправления kernel panic
- `docs/DEVSTACK.md` — dev-стек
- `docs/AI-STACK.md` — AI-инструменты
