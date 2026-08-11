# VibeBSD — FreeBSD-редакция VibeCode OS

> Экспериментальная редакция. Прототип. Сборка только на FreeBSD-хосте.

**VibeBSD** — порт концепции VibeLinux на **FreeBSD 15** с **KDE Plasma 6**.
Реализована как профиль сборки на базе **Poudriere** (как у NomadBSD/GhostBSD).

## Структура профиля

```
freebsd-vibebsd/
├── packages/
│   ├── base.txt       # системные утилиты
│   ├── desktop.txt    # Xorg + KDE Plasma 6 + шрифты/иконки
│   ├── dev.txt        # shell, редакторы, языки
│   └── ai.txt         # Ollama, Python, опц. Podman
├── etc/
│   ├── zshrc          # Zsh под FreeBSD (пути /usr/local, Podman-алиасы)
│   ├── starship.toml  # промпт (как в Arch-редакции)
│   └── kitty.conf     # терминал (shell /usr/local/bin/zsh)
└── scripts/
    ├── 00-setup-poudriere.sh   # poudriere + jail + порты
    ├── 10-customize-rootfs.sh  # брендинг, пользователь, конфиги
    ├── 20-build-iso.sh         # poudriere image -t iso
    └── setup-ai.sh             # AI-стек post-install (без Docker)
```

## Пайплайн сборки

```
00-setup-poudriere.sh
  ├─ pkg install poudriere
  └─ poudriere jail -c -j vibebsd -v 15.1-RELEASE -m http
     poudriere ports -c -p vibebsd-ports

10-customize-rootfs.sh  (редактирует каталог jail напрямую)
  ├─ копирует branding/ в /usr/local/share/vibebsd
  ├─ пишет /etc/rc.conf (dbus, sddm, ollama)
  ├─ создаёт пользователя vibebsd (SDDM autologin, session=plasma)
  └─ раскладывает etc/{zshrc,starship,kitty}

20-build-iso.sh
  ├─ объединяет packages/*.txt → pkglist.txt
  └─ poudriere image -j vibebsd -p vibebsd-ports -t iso -c pkglist.txt -o out
```

Результат: `out/vibebsd-live-YYYYMMDD.iso` (загрузка UEFI+BIOS, FS UFS).

## Различия с Arch-редакцией

| | Arch (VibeLinux) | FreeBSD (VibeBSD) |
|---|---|---|
| Пакеты | pacman / AUR | pkg / ports |
| ISO | mkarchiso | poudriere image |
| Установщик | Calamares | bsdinstall (в плане) |
| Контейнеры | Docker | Podman / jails / bhyve |
| Ollama | пакет (все платформы) | пакет `misc/ollama` (amd64) |
| Компилятор | gcc/clang | clang (в base) |

## Переносимые компоненты

- **Брендинг** — `branding/` копируется как есть (обои, логотипы, конфиги).
- **Конфиги** — `branding/config/*` адаптированы под FreeBSD в `etc/`.
- **Dev/AI стек** — те же инструменты, другие имена пакетов (см. списки).
- **Подход к сборке** — та же философия «профиль + скрипты + Makefile».

## AI-стек (без Docker)

```sh
./freebsd-vibebsd/scripts/setup-ai.sh   # uv + transformers/langchain/torch + Open WebUI + ComfyUI
```

Open WebUI и ComfyUI работают «напрямую» (uv/pip), Docker не требуется.

## Makefile

```sh
make bsd            # полная сборка
make bsd-setup      # только шаг 0
make bsd-customize  # только шаг 1
make bsd-build      # только шаг 2
```

## Тестирование

- Виртуализация: bhyve (родной), VirtualBox с типом гостя FreeBSD (15.x).
- Smoke-тесты: загрузка, вход в Plasma (autologin), `ollama run`, `pkg -N`.
