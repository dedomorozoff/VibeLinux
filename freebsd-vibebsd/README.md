# VibeBSD — FreeBSD-редакция VibeCode OS

Live-образ **KDE Plasma 6** на **FreeBSD 15** с dev- и AI-стеком «из коробки».
Docker заменён на **Podman** (опционально), контейнеры — через Linux-эмуляцию.

## Редакция

| Параметр | VibeBSD |
|----------|---------|
| База | FreeBSD 15.x (amd64) |
| GUI | KDE Plasma 6 (Wayland/X11), SDDM + autologin |
| Установщик | Пока live-образ (установка вручную через `bsdinstall`) |
| Dev-стек | Zsh, Starship, Kitty, Neovim, Zed, Git + lazygit |
| AI-стек | Ollama (сервис), Python AI-библиотеки (post-install) |
| Контейнеры | Podman (опц., вместо Docker) |
| ФС | ZFS / UFS, загрузка UEFI+BIOS |

## Сборка ISO

Только на хосте **FreeBSD** (собственно, как и все FreeBSD-образы). Порядок:

```sh
# 1) Poudriere + jail + порты
sudo ./freebsd-vibebsd/scripts/00-setup-poudriere.sh 15.1-RELEASE

# 2) Кастомизация rootfs (брендинг, пользователь vibebsd, конфиги)
sudo ./freebsd-vibebsd/scripts/10-customize-rootfs.sh

# 3) Сборка ISO
sudo ./freebsd-vibebsd/scripts/20-build-iso.sh
# Результат: out/vibebsd-live-YYYYMMDD.iso
```

Короткий путь (всё сразу):

```sh
make bsd
```

### Что делает каждый шаг

- **00-setup-poudriere.sh** — ставит `poudriere`, создаёт jail (`vibebsd`) и portstree (`vibebsd-ports`).
- **10-customize-rootfs.sh** — копирует брендинг, пишет `rc.conf` (sddm, dbus, ollama), создаёт пользователя `vibebsd` (autologin в Plasma), раскладывает конфиги Zsh/Starship/Kitty, настраивает passwordless sudo для wheel.
- **20-build-iso.sh** — объединяет `packages/*.txt` и собирает загрузочный ISO через `poudriere image -t iso`.

## Пакетные списки

- `packages/base.txt` — системные утилиты
- `packages/desktop.txt` — Xorg + KDE Plasma 6 + шрифты/иконки
- `packages/dev.txt` — shell, редакторы, языки (Python/Node/Rust/Go)
- `packages/ai.txt` — Ollama, Python, опц. Podman

## AI-стек после установки

```sh
curl -LsSf https://astral.sh/uv/install.sh | sh
uv pip install --system transformers langchain llama-index torch
uvx open-webui serve   # или: pip install open-webui && open-webui serve
# ComfyUI:
git clone https://github.com/comfyanonymous/ComfyUI ~/ComfyUI
uv pip install --system torch torchvision torchaudio
```

## Известные ограничения

- **Docker отсутствует** — используется Podman + `linux_enable` (Linux-эмуляция) для большинства контейнеров.
- **Ollama** — только amd64 (актуально для порта), GPU-бэкенд на NVIDIA опционален (Vulkan-бэкенд в порту может быть отключён).
- **Железо** — поддержка свежих Wi-Fi/GPU на FreeBSD хуже, чем на Linux; для KMS-драйверов включите `drm-kmod` в `packages/desktop.txt`.
- **CBSD/jails** — для продакшн-изоляции используйте jails вместо контейнеров.
