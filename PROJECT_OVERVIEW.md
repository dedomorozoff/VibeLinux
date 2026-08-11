### **VibeCode OS — обзор проекта**

**Миссия:** создать дистрибутив Linux, который из коробки даёт идеальную среду для «вайбкодинга» — продуктивной, сфокусированной и эстетичной разработки с глубокой интеграцией современных AI‑инструментов.

---

### **Быстрый старт**

#### Сборка ISO

```bash
# Проверка зависимостей
BUILD_MODE=dry-run ./scripts/legacy/build-iso.sh

# Полная сборка (требует root, legacy Ubuntu)
sudo BUILD_MODE=full ./scripts/legacy/build-iso.sh

# Быстрая пересборка (сохраняет chroot)
sudo KEEP_CHROOT=1 BUILD_MODE=full ./scripts/legacy/build-iso.sh
```

Готовый ISO будет в `build/VibeCodeOS-alpha.iso`

#### Тестирование

```bash
# В QEMU
qemu-system-x86_64 -cdrom build/VibeCodeOS-alpha.iso -m 2048 -enable-kvm

# В VirtualBox (см. docs/TESTING.md)
```

Подробнее: `docs/BUILD-ISO.md`, `docs/TESTING.md`

---

### **Целевая аудитория**

1. Разработчики на **Python / JavaScript / TypeScript / Rust / Go**.
2. AI‑энтузиасты и исследователи, которым нужен готовый стек (PyTorch, Transformers, LangChain и т.д.).
3. Студенты и начинающие разработчики, которым важен принцип «установил и пишешь код».
4. Любители кастомизации и **keyboard‑driven** интерфейсов.

---

### **Ключевые продуктовые принципы**

1. **Out‑of‑the‑box dev experience**  
   Сразу после установки доступны готовые языковые стеки, IDE, терминал, Git и контейнеры.

2. **AI‑first подход**  
   Локальные LLM (Ollama и т.п.), интеграция с редакторами и терминалом, готовый стек библиотек.

3. **Эстетика и фокус**  
   Продуманная тема, шрифты, обои, плавные анимации, минимум визуального шума.

4. **Автоматизация и воспроизводимость**  
   Всё, что можно, должно настраиваться скриптами и CI, а не ручными кликами.

---

### **Базовые технические решения**

- **Базовая система:** `Arch Linux (rolling)` — основная редакция (профиль `archiso-vibelinux/`).
- **Основное окружение рабочего стола:** `KDE Plasma 6` (вариант «Vibe‑Zen») + SDDM (autologin).
- **Legacy‑редакции:** Ubuntu 24.04 LTS (Full / Minimal / Lite) — поддерживаются, но не являются основным направлением.
- **Метод сборки дистрибутива:**
  - Основная сборка — `archiso` (Arch Linux, `make arch`).
  - Legacy‑сборки Ubuntu — `debootstrap` + инструменты для создания live‑ISO.
  - Интеграция со **GitHub Actions** для воспроизводимой сборки ISO.

---

### **Структура репозитория (черновик)**

- `docs/` — документация (брендинг, dev‑стек, AI‑стек, гайды по установке и т.д.).
- `scripts/` — скрипты сборки и настройки (cleanup, установка пакетов, сборка ISO).
- `.github/workflows/` — CI‑конвейеры для сборки и публикации ISO.
- `branding/` — логотипы, темы, иконки, обои.
- `roadmap.md` — стратегический роадмап проекта.

Эта структура будет уточняться по мере развития проекта и прохождения фаз из `roadmap.md`.

### Core OS / alpha ISO — статус

- **Сделано:**
  - [x] Основная сборка на Arch Linux (archiso) + KDE Plasma 6; legacy — debootstrap + SquashFS + GRUB + casper
  - [x] Спроектированы и реализованы базовые скрипты Core OS
  - [x] KDE Plasma desktop с автологином (SDDM)
  - [x] Установщик (Calamares; legacy — ubiquity) с ярлыком на рабочем столе
  - [x] Базовый брендинг (логотип, обои, темы, шрифты)
  - [x] Расширенный набор утилит (neofetch, firefox, network-manager и др.)
  - [x] Информация о дистрибутиве (lsb-release, os-release)

- **Команды сборки:**
```bash
# Основная сборка (Arch Linux + KDE Plasma 6)
make arch

# Legacy: полная сборка Ubuntu
sudo BUILD_MODE=full ./scripts/legacy/build-iso.sh

# Legacy: быстрая пересборка (сохраняет chroot)
sudo KEEP_CHROOT=1 BUILD_MODE=full ./scripts/legacy/build-iso.sh
```

- **Следующие шаги:** Тестирование Live-образа и установщика (см. `docs/ALPHA-STATUS.md`)
