# VibeBSD — FreeBSD-редакция VibeCode OS

Live-образ **KDE Plasma 6** на **FreeBSD 15** с dev- и AI-стеком «из коробки».
Docker заменён на **Podman** (опционально), контейнеры — через Linux-эмуляцию.

> Статус: прототип. Пайплайн 00 → 20 вычитан по исходникам poudriere 3.4.8 и
> приведён в порядок, но сквозной прогон на хосте с собранным ISO ещё не
> подтверждён. Главное известное ограничение — read-only root в образе (см.
> «Известные ограничения»).

## Редакция

| Параметр | VibeBSD |
|----------|---------|
| База | FreeBSD 15.x (amd64) |
| GUI | KDE Plasma 6 (Wayland/X11), SDDM + autologin |
| Установщик | Пока live-образ (установка вручную через `bsdinstall`) |
| Dev-стек | Zsh, Starship, Kitty, Neovim, Zed, Git + lazygit |
| AI-стек | Ollama (сервис), Python AI-библиотеки (post-install) |
| Контейнеры | Podman (опц., вместо Docker) |
| ФС | iso9660 ro (root) + tmpfs /tmp; `hybridiso` — GPT+ESP для UEFI/BIOS |

## Сборка ISO

Только на хосте **FreeBSD** (собственно, как и все FreeBSD-образы). Порядок:

```sh
# 1) Poudriere + jail
sudo ./freebsd-vibebsd/scripts/00-setup-poudriere.sh 15.1-RELEASE

# 2) Кастомизация rootfs (брендинг, пользователь vibebsd, конфиги)
sudo ./freebsd-vibebsd/scripts/10-customize-rootfs.sh

# 3) Установка бинарных пакетов в jail (Plasma6, dev/AI-стек)
sudo ./freebsd-vibebsd/scripts/15-install-packages.sh

# 4) Выкинуть тяжёлое из образа: rust (~1.3 ГБ), postgresql*-client, samba*
sudo ./freebsd-vibebsd/scripts/16-drop-postinstall.sh

# 5) Утоньшение rootfs: docs/man/info, статические либы, лишние локали, тесты
sudo ./freebsd-vibebsd/scripts/17-slim-rootfs.sh

# 6) Локальные сборки из soft/ (opencode, dmcode, dmed, dmsh)
sudo ./freebsd-vibebsd/scripts/18-install-soft.sh

# 7) Сборка ISO
sudo ./freebsd-vibebsd/scripts/20-build-iso.sh
# Результат: out/vibebsd-live-YYYYMMDD.iso
```

Короткий путь (всё сразу):

```sh
make bsd
```

### Что делает каждый шаг

- **00-setup-poudriere.sh** — ставит `poudriere`, создаёт jail (`vibebsd`); portstree (`vibebsdports`) — только при `VIBEBSD_PORTS=1`, она нужна для `poudriere bulk` и занимает 2–4 ГБ.
- **10-customize-rootfs.sh** — копирует брендинг, пишет `rc.conf` (sddm, dbus, ollama), создаёт пользователя `vibebsd` (autologin в Plasma), раскладывает конфиги Zsh/Starship/Kitty, настраивает passwordless sudo для wheel.
- **15-install-packages.sh** — ставит все пакеты из `packages/*.txt` бинарником `pkg` **с хоста** (`pkg -r vibebsd install`): в jail, собранном через `poudriere jail -m http`, нет `/usr/bin/pkg`. Сверяет список запрошенного с фактически установленным и подправляет `Session=` в `sddm.conf` под реальные `xsessions/plasma*.desktop`.
- **16-drop-postinstall.sh** — удаляет `rust`, `postgresql*-client`, `samba*` (всё это ставится post-install) и чистит кэш pkg.
- **17-slim-rootfs.sh** — вырезает docs/man/info, статические библиотеки, лишние локали, тесты Go/Python. `/usr/src` не трогает: poudriere прогоняет в jail `make delete-old`, а в образ `usr/src` и так исключён.
- **18-install-soft.sh** — ставит в jail все `*.pkg` из `soft/` (`pkg -r vibebsd add -M`), сверяет ABI пакета с веткой jail и проверяет, что пакет зарегистрирован в БД jail, а бинарь лежит в `/usr/local/bin`.
- **20-build-iso.sh** — preflight (ядро в jail, загрузчик, свободное место) и `poudriere image -j vibebsd -t iso -n vibebsd -h vibebsd`. Rootfs образа — это содержимое jail, поэтому пакеты и кастомизация попадают внутрь как есть.

Опции шага 20: `VIBEBSD_IMAGE_TYPE=hybridiso` — образ, пригодный для `dd` на
USB с загрузкой по UEFI (по умолчанию `iso` — для записи на DVD/ISO).

Опции шага 18: `VIBEBSD_SOFT_OPTIONAL=1` — не падать на пустом `soft/`
(для smoke-сборок в CI; в полной сборке `soft/` обязан быть заполнен).

## Свои сборки в soft/

AI-инструменты, которых нет в репозитории FreeBSD, лежат готовыми `.pkg` в
[`../soft/`](../soft/) и ставятся шагом 18 (≈120 МБ в jail, ≈60 МБ в ISO):

| бинарь | версия | лицензия | что это |
|--------|--------|----------|---------|
| `opencode` | 0.0.0.20260805 | MIT | AI-агент в терминале (динамическая сборка) |
| `dmcode` | 0.1.3 | MIT | Терминальный агент на google/adk-go, статический Go |
| `dmed` | 0.8.3 | BSD-3-Clause | dmEd — редактор кода, где AI-агенты первоклассные участники |
| `dmsh` | 0.4.0 | MIT | Direct Model Shell: локальный LLM через вшитый llama.cpp (CGO) |

Все четыре собираются из исходников на FreeBSD-хосте, инструкции — в
[`../soft/README.md`](../soft/README.md). GGUF-модель для `dmsh` в образ не
входит: `dmsh` качает её сам при первом запуске.

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

| Компилятор | gcc/clang | clang (в base) |

## Известные ограничения

- **Root в образе read-only** — `poudriere image -t iso` кладёт в fstab `/dev/iso9660/VIBEBSD / cd9660 ro` и `tmpfs /tmp`. Запись в `/var` и `/home` в live-сессии не работает; нужен RAM-оверлей (md + union поверх `/`) — задача из бэклога, пока не реализована. Это бьёт не только по Plasma: `opencode` (`~/.config/opencode`), `dmsh` (`~/.config/dmsh/config.json`, каталог GGUF-моделей) и `dmed` (состояние сессий) пишут в `$HOME`, то есть без оверлея они не запустятся вовсе.
- **Docker отсутствует** — используется Podman + `linux_enable` (Linux-эмуляция) для большинства контейнеров.
- **Ollama** — только amd64 (актуально для порта), GPU-бэкенд на NVIDIA опционален (Vulkan-бэкенд в порту может быть отключён).
- **Железо** — поддержка свежих Wi-Fi/GPU на FreeBSD хуже, чем на Linux; для KMS-драйверов включите `drm-kmod` в `packages/desktop.txt`.
- **CBSD/jails** — для продакшн-изоляции используйте jails вместо контейнеров.
