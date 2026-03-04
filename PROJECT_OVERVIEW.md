### **VibeCode OS — обзор проекта**

**Миссия:** создать дистрибутив Linux, который из коробки даёт идеальную среду для «вайбкодинга» — продуктивной, сфокусированной и эстетичной разработки с глубокой интеграцией современных AI‑инструментов.

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

- **Базовая система:** `Ubuntu 24.04 LTS (Noble Numbat)` — свежие пакеты и долгосрочная поддержка.
- **Основное окружение рабочего стола:** `MATE` (вариант «Vibe‑Zen»).
- **Планируемая community‑версия:** тайловый WM (например, `Hyprland`, вариант «Vibe‑Flow») после стабилизации основной редакции.
- **Метод сборки дистрибутива:**
  - Автоматизированная сборка через скрипты на базе `debootstrap` + инструментов для создания live‑ISO.
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
  - [x] Выбран стек сборки ISO (debootstrap + SquashFS + GRUB + casper).
  - [x] Спроектированы и реализованы базовые скрипты Core OS:
    - `scripts/base/*` (base-packages, cleanup)
    - `scripts/desktop/install-mate.sh` (MATE + LightDM)
    - `scripts/drivers/install-nvidia.sh` (post-install NVIDIA)
    - `scripts/build/build-iso.sh` (`dry-run` + `full` + `KEEP_CHROOT=1`).
  - [x] Описаны пакеты и стратегия драйверов:
    - `docs/CORE-OS-PACKAGES.md`
    - `docs/DRIVERS-NVIDIA.md`
  - [x] Собирается `vibecode-alpha.iso` на целевой машине, ISO содержит:
    - `boot/vmlinuz`, `boot/initrd.img`
    - `casper/filesystem.squashfs`
    - EFI-загрузчик.

- **Текущее состояние загрузки ISO:**
  - Ядро и initramfs стартуют, casper видит ISO и `casper/filesystem.squashfs`.
  - При обычной загрузке после init возникает `Kernel panic - not syncing: Attempted to kill init` — т.е. init/casper падает на раннем этапе (live-сессия MATE пока не поднимается).

- **Следующие шаги по Core OS / alpha ISO:**
  - [ ] Додебажить падение init/casper до рабочей live-сессии MATE.
  - [ ] После успешной загрузки прогнать smoke-тесты:
    - Загрузка live MATE в VM.
    - Проверка сети и браузера.
    - Ручной запуск ключевых скриптов dev/ai (по мере появления).

**Команда для сборки на Ubuntu (хост):**

```bash
sudo apt install -y debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools
git clone <repo-url> VibeLinux
cd VibeLinux
sudo BUILD_MODE=full ./scripts/build/build-iso.sh
```

**Быстрая пересборка ISO без пересоздания chroot:**

```bash
cd VibeLinux
sudo KEEP_CHROOT=1 BUILD_MODE=full ./scripts/build/build-iso.sh
```
