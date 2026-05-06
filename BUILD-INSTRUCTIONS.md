# Сборка VibeCode OS ISO

## Быстрый старт

```bash
# 1. Проверка зависимостей
make check
make check-mini

# 2. Сборка
make mini    # минимальная версия (CLI, Ubuntu)
make full    # полная версия (GUI + dev + AI, Ubuntu)
make arch    # Arch Linux (KDE Plasma + полный стек)
```

---

## Редакции

| Параметр | **Full (Ubuntu)** | **Minimal (Ubuntu)** | **Arch** |
|----------|-------------------|----------------------|----------|
| **База** | Ubuntu 24.04 LTS | Ubuntu 24.04 LTS | Arch Linux (rolling) |
| **GUI** | MATE Desktop | Нет (CLI) | KDE Plasma |
| **Установщик** | Ubiquity | Текстовый скрипт | Calamares |
| **Dev-стек** | Полный | Базовый | Полный |
| **AI-стек** | ✅ | ❌ | ✅ |
| **Размер ISO** | ~3-4 ГБ | ~600-800 МБ | ~3-4 ГБ |

## Состав сборок

### Minimal (scripts/build-minimal-iso.sh)
**Скрипт:** `scripts/build-minimal-iso.sh`  
**Chroot скрипт:** `scripts/base/minimal-packages-chroot.sh`

**Пакеты (согласно PACKAGES.md):**
- Ядро: `linux-image-virtual`
- Live: `casper`, `squashfs-tools`
- Оболочка: `zsh`, `tmux`
- Редакторы: `nano`, `vim-tiny`
- Утилиты: `mc`, `htop`, `curl`, `wget`, `unzip`, `zip`, `git`
- Dev: `build-essential`
- Сеть: `network-manager`, `iputils-ping`, `net-tools`, `traceroute`
- Дополнительно: `tree`, `p7zip-full`, `neofetch`, `virtualbox-guest-utils`

**Размер ISO:** ~600-800 МБ

### Full (scripts/build-iso.sh)
**Скрипт:** `scripts/build-iso.sh`  
**Chroot скрипт:** `scripts/base/full-packages-chroot.sh`

**Компоненты:**
- **MATE Desktop** + LightDM (autologin)
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
├── build-minimal-iso.sh    # Сборка Minimal ISO
├── build-iso.sh            # Сборка Full ISO
└── base/
    ├── minimal-packages-chroot.sh  # Настройка chroot для Minimal
    └── full-packages-chroot.sh     # Настройка chroot для Full
```

## Как это работает

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
