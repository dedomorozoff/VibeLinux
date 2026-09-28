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
    ├── 00-setup-poudriere.sh   # poudriere + jail (+ portstree по VIBEBSD_PORTS=1)
    ├── 10-customize-rootfs.sh  # брендинг, пользователь, конфиги
    ├── 15-install-packages.sh  # бинарные пакеты в jail (офиц. репозиторий)
    ├── 16-drop-postinstall.sh  # выкинуть тяжёлое: rust, pg-client, samba
    ├── 17-slim-rootfs.sh       # утоньшение: docs, man, локали, тесты
    ├── 18-install-soft.sh      # локальные сборки из soft/ (AI-агенты)
    ├── 20-build-iso.sh         # poudriere image -t iso
    └── setup-ai.sh             # AI-стек post-install (без Docker)
```

## Пайплайн сборки

```
00-setup-poudriere.sh
  ├─ pkg install poudriere
  └─ poudriere jail -c -j vibebsd -v 15.1-RELEASE -m http
     (portstree — только VIBEBSD_PORTS=1, нужен для bulk, 2–4 ГБ)

10-customize-rootfs.sh  (редактирует каталог jail напрямую)
  ├─ копирует branding/ в /usr/local/share/vibebsd
  ├─ пишет /etc/rc.conf (dbus, sddm, ollama)
  ├─ создаёт пользователя vibebsd (SDDM autologin, session=plasma)
  └─ раскладывает etc/{zshrc,starship,kitty}

15-install-packages.sh  (pkg с ХОСТА: pkg -r jail, офиц. репозиторий)
  ├─ определяет ABI jail (repos → newvers.sh → ветка хоста)
  ├─ пишет /usr/local/etc/pkg/repos, если jail собран без конфига
  ├─ pkg -r vibebsd install -y <packages/*.txt>
  ├─ сверяет список запрошенных пакетов с установленными, падает на непокрытых
  └─ чинит Session= в sddm.conf по фактическим xsessions/plasma*.desktop

16-drop-postinstall.sh  (до утоньшения — не чистим то, что сейчас удалим)
  └─ pkg -r vibebsd delete {rust, postgresql*-client, samba*}

17-slim-rootfs.sh
  └─ кэш pkg, docs/man/info, статические либы, лишние локали,
     тесты Go/Python (__pycache__, site-packages/tests)
     /usr/src НЕ трогаем: poudriere делает в jail `make delete-old`,
     в образ usr/src всё равно исключён excludelist

18-install-soft.sh  (локальные сборки из soft/, ~120 МБ в jail)
  ├─ сверяет ABI каждого .pkg с веткой jail (FreeBSD:15)
  ├─ pkg -r vibebsd add -M <soft/*.pkg>
  └─ проверяет: пакет в БД jail + исполняемый /usr/local/bin/<имя>

20-build-iso.sh
  ├─ preflight: boot/kernel/kernel, boot/loader.efi, свободное место
  └─ poudriere image -j vibebsd -t iso -n vibebsd -h vibebsd -o out
```

> **Как работает `poudriere image`** (проверено по исходникам 3.4.8,
> `share/poudriere/image.sh`): `install_world()` распаковывает **содержимое
> jail** в `$WRKDIR/world` (`tar -C <jail> … | tar -xf -`). Поэтому пакеты из
> шага 15 и кастомизация из шага 10 попадают в образ как есть.
>
> Опция `-f` (список пакетов) **не используется**: она ставит пакеты из
> poudriere-репозитория (`$POUDRIERE_DATA/packages/<master>`), который у
> прототипа пуст — bulk не запускался. Список пакетов собирается только для
> отчёта (`.work/pkglist.txt`).
>
> `-h vibebsd` обязателен: по умолчанию poudrière подставляет
> `hostname="poudriere-image"` в `/etc/rc.conf` готового образа.

> Продакшн-путь — свой репозиторий через `poudriere bulk -j vibebsd -f pkglist`
> и image с `-p vibebsdports` (как у GhostBSD); для прототипа используются
> бинарные пакеты FreeBSD — это часы vs сутки сборки. Пакеты, отсутствующие
> в репозитории (`nvm`), вынесены в post-install.

Результат: `out/vibebsd-live-YYYYMMDD.iso`.

## Известное ограничение: root в образе read-only

`-t iso` и `-t hybridiso` кладут в образ fstab вида:

```
/dev/iso9660/VIBEBSD / cd9660 ro 0 0
tmpfs /tmp tmpfs rw,mode=1777 0 0
```

То есть `/` — только для чтения, писать можно лишь в `/tmp`. Для полноценной
live-сессии нужен RAM-оверлей (md + union поверх `/`, чтобы `/var` и `/home`
стали доступны на запись) — это **не сделано**, и является главным пунктом
бэклога (см. `roadmap.md`).

Особенно это бьёт по инструментам из `soft/`: `opencode` пишет
`~/.config/opencode`, `dmsh` — `~/.config/dmsh/config.json` и каталог
GGUF-моделей, `dmed` — состояние сессий. В read-only live они не запустятся,
поэтому RAM-оверлей для VibeBSD — не «улучшение», а условие работоспособности
штатного AI-стека.

Вариант `-t iso+mfs` (root в памяти) не подходит для образа такого размера:
`mfs` упирается в ~256 МБ, poudriere сам предупреждает «MFSROOT too large,
boot failure likely».

`iso` vs `hybridiso`: `hybridiso` дополнительно пишет в System Area образа
GPT + ESP, поэтому загрузка с USB, залитого через `dd`, работает и по UEFI.
Собирается по умолчанию `iso` (пригоден для записи на DVD/ISO-образ), для
USB-флешки — `VIBEBSD_IMAGE_TYPE=hybridiso`.

## Свои сборки: soft/

AI-инструменты, которых нет в репозитории FreeBSD, поставляются готовыми
`.pkg` из каталога `soft/` (в git не лежат — это артефакты, ~60 МБ) и ставятся
шагом `18-install-soft.sh` уже после утоньшения rootfs.

| бинарь | версия | лицензия | сборка | размер |
|--------|--------|----------|--------|--------|
| `opencode` | 0.0.0.20260805 | MIT | Go + koffi, динамический | 212 МБ |
| `dmcode` | 0.1.3 | MIT | Go, CGO выключен, статический | 36 МБ |
| `dmed` | 0.8.3 | BSD-3-Clause | Go, CGO выключен, статический | 17 МБ |
| `dmsh` | 0.4.0 | MIT | Go + llama.cpp (CGO, `-lomp`) | 12 МБ |

Тонкости, из-за которых шаг 18 написан именно так:

- `pkg add` требует `-M` (`--accept-missing`). В jail из `poudriere jail -m http`
  в `shlibs_required` лежат `libc++.so.1`, `libcxxrt.so.1`, `libexecinfo.so.1` —
  они приезжают файлами из base-сета и pkg-пакетами **не являются**. Без `-M`
  установка `opencode` падает с `Missing shlib libc++.so.1 required by opencode`.
  Ставить пакет `libc++` не нужно: он перезаписал бы файлы base-системы.
- Проверяется ABI пакета (`FreeBSD:15:amd64`) против ветки jail — иначе pkg
  поставит бинарь под другую мажорную версию и он упадёт на запуске.
- `pkg info -q <name>` на FreeBSD 15 в режиме pattern молчит, версия берётся
  через `pkg query -a '%n-%v'`.
- У всех четырёх `go.mod` требует Go ≥1.25 (dmcode/dmed — 1.26), поэтому
  сборка идёт с `GOTOOLCHAIN=auto` и `gmake` (на FreeBSD `make` — это bmake,
  а все три Makefile'а написаны под GNU make).

Пересборка любого из них — в [`soft/README.md`](../soft/README.md)
(`soft/mkfreebsd-pkg.sh` упаковывает бинарь в `.pkg`).

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
make bsd            # полная сборка: 00 → 10 → 15 → 16 → 17 → 18 → 20
make bsd-setup      # только шаг 00 (Poudriere + jail)
make bsd-customize  # только шаг 10 (брендинг, пользователь, конфиги)
make bsd-packages   # только шаг 15 (пакеты в jail)
make bsd-drop       # только шаг 16 (rust/pg-client/samba наружу)
make bsd-slim       # только шаг 17 (docs, man, локали, тесты)
make bsd-soft       # только шаг 18 (локальные сборки из soft/)
make bsd-build      # только шаг 20 (ISO)
```

Переменные окружения: `VIBEBSD_PORTS=1` (portstree для bulk),
`VIBEBSD_IMAGE_TYPE=iso|hybridiso`, `VIBEBSD_KEEP_MAN=1` (оставить man),
`VIBEBSD_ALLOW_MISSING=1` (не падать на непокрытых пакетах), `VIBEBSD_SOFT_OPTIONAL=1` (пустой soft/ — не ошибка).

## Тестирование

- Виртуализация: bhyve (родной), VirtualBox с типом гостя FreeBSD (15.x).
- Smoke-тесты: загрузка, вход в Plasma (autologin), `ollama run`, `pkg -N`.
- Ожидаемое поведение в live: root read-only → запись в `/tmp` работает,
  в `/var` и `/home` — нет (см. «Известное ограничение»).
