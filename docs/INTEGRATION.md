# Интеграция из temp/custom-linux-iso

## Что было перенесено

Из проекта `temp/custom-linux-iso` были перенесены и адаптированы следующие компоненты:

### 1. ✅ Скрипты сборки ISO

**Расположение:** `scripts/build/`

- `build-vibe-lite-ubuntu.sh` — Lite-сборка (Ubuntu 24.04, минимальный набор)
- `build-vibe-full-ubuntu.sh` — Full-сборка (Ubuntu 24.04, все инструменты)
- `build-vibe-arch.sh` — Arch Linux сборка (rolling release)

**Отличия от оригинала:**
- Улучшена обработка ошибок
- Добавлена поддержка кэширования rootfs
- Интеграция с Vibe Wizard
- Более чистая структура

### 2. ✅ Vibe Wizard (пост-установочный мастер)

**Расположение:** `scripts/base/vibe-wizard.sh`

**Улучшения:**
- Поддержка трёх режимов: GUI (zenity), TUI (whiptail), CLI
- Чтение конфигурации из JSON
- Логирование установок
- Флаг завершения (`~/.vibe-wizard-done`)

### 3. ✅ Система конфигурации

**Расположение:** `scripts/base/vibe-config-template.json`

**Возможности:**
- Описание редакторов, агентов, рантаймов, инструментов
- Настройка NVIDIA, Ollama, Flatpak
- Локаль, клавиатура, autologin

### 4. ✅ Генератор скриптов

**Расположение:** `scripts/base/generate-build-script.sh`

**Использование:**
```bash
# Отредактируйте конфиг
nano scripts/base/vibe-config-template.json

# Сгенерируйте скрипт
make generate

# Запустите сборку
sudo bash scripts/build/build-vibe-generated.sh
```

### 5. ✅ Обновлённый Makefile

**Новые цели:**
- `make lite` — быстрая Lite-сборка
- `make full-vibe` — полная сборка со всеми инструментами
- `make arch` — сборка на базе Arch Linux
- `make generate` — генерация скрипта из JSON
- `make wizard` — запуск пост-установочного мастера

## Архитектура интеграции

```
scripts/
├── base/
│   ├── vibe-wizard.sh              # Пост-установочный мастер
│   ├── vibe-config-template.json   # Шаблон конфигурации
│   └── generate-build-script.sh    # Генератор скриптов
├── build/
│   ├── build-vibe-lite-ubuntu.sh   # Lite-сборка
│   ├── build-vibe-full-ubuntu.sh   # Full-сборка
│   ├── build-vibe-arch.sh          # Arch Linux
│   └── README.md                   # Документация
└── ... (остальные скрипты)
```

## Как использовать

### Быстрая сборка

```bash
# Lite (быстро, только базовое)
make lite

# Full (все инструменты)
make full-vibe

# Arch Linux
make arch
```

### Кастомная сборка

1. Отредактируйте `scripts/base/vibe-config-template.json`
2. Запустите `make generate`
3. Запустите сгенерированный скрипт

### Пост-установочная настройка

В live-сессии автоматически запускается Vibe Wizard.

Или вручную:
```bash
sudo /usr/local/bin/vibe-wizard
```

## Что НЕ было перенесено

- ❌ React-приложение (веб-конфигуратор) — это отдельный продукт
- ❌ Скрипты деплоя на GitHub Pages — не нужны для сборки ISO
- ❌ Node.js зависимости веб-приложения

## Преимущества интеграции

1. **Модульность** — отдельные скрипты для разных сценариев
2. **Гибкость** — конфигурация через JSON
3. **Автоматизация** — генерация скриптов из конфига
4. **Удобство** — Vibe Wizard для пост-установки
5. **Мультиплатформенность** — Ubuntu, Debian, Arch, Fedora

## Документация

- `scripts/build/README.md` — подробная документация по скриптам сборки
- `README.md` — общая информация о проекте
- `roadmap.md` — план развития проекта
