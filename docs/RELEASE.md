### Процесс релиза VibeCode OS

Этот документ описывает, как создавать релизы VibeCode OS.

---

### Автоматический релиз через GitHub Actions

#### Способ 1: Через Git теги (рекомендуется)

```bash
# Создаём тег с версией
git tag v0.1.0-alpha
git push origin v0.1.0-alpha

# Или для стабильного релиза
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions автоматически:
1. Соберёт ISO
2. Создаст релиз на GitHub
3. Загрузит ISO и чексуммы
4. Сгенерирует release notes

#### Способ 2: Ручной запуск через GitHub UI

1. Перейти в **Actions** → **Release VibeCode OS**
2. Нажать **Run workflow**
3. Ввести версию (например, `v0.1.0-alpha`)
4. Нажать **Run workflow**

---

### Схема версионирования

Используем [Semantic Versioning](https://semver.org/):

```
vMAJOR.MINOR.PATCH[-PRERELEASE]

Примеры:
v0.1.0-alpha    - первая alpha-версия
v0.1.1-alpha    - исправления в alpha
v0.2.0-beta     - beta-версия
v1.0.0          - первый стабильный релиз
v1.1.0          - новые фичи (обратно совместимо)
v1.1.1          - исправления багов
v2.0.0          - breaking changes
```

**Правила:**
- `alpha` - ранняя разработка, возможны серьёзные баги
- `beta` - функционал готов, идёт тестирование
- Без суффикса - стабильный релиз

---

### Подготовка к релизу

#### 1. Проверка перед релизом

```bash
# Локальная сборка
sudo BUILD_MODE=full ./scripts/build-iso.sh

# Тестирование в VM
qemu-system-x86_64 -cdrom build/VibeCodeOS-alpha.iso -m 2048 -enable-kvm

# Проверка чек-листа
# - [ ] ISO загружается
# - [ ] MATE запускается
# - [ ] Установщик работает
# - [ ] Базовые утилиты на месте
# - [ ] Брендинг применён
```

#### 2. Обновление документации

Перед релизом обновить:
- `docs/ALPHA-STATUS.md` - текущий статус
- `CHANGELOG.md` - список изменений (если есть)
- `README.md` - инструкции по установке

#### 3. Создание тега

```bash
# Убедитесь, что все изменения закоммичены
git status

# Создайте тег с аннотацией
git tag -a v0.1.0-alpha -m "Release v0.1.0-alpha: First alpha release"

# Отправьте тег на GitHub
git push origin v0.1.0-alpha
```

---

### Что происходит при релизе

1. **Сборка ISO** (~20-30 минут)
   - Bootstrap Ubuntu 24.04
   - Установка пакетов и настройка
   - Применение брендинга
   - Создание SquashFS и ISO

2. **Генерация артефактов**
   - `VibeCodeOS-vX.X.X.iso` - основной образ
   - `VibeCodeOS-vX.X.X.iso.sha256` - SHA256 чексумма
   - `VibeCodeOS-vX.X.X.iso.md5` - MD5 чексумма

3. **Создание релиза на GitHub**
   - Автоматические release notes
   - Загрузка всех файлов
   - Пометка как pre-release (для alpha/beta)

---

### После релиза

#### Проверка релиза

1. Перейти на страницу [Releases](https://github.com/yourusername/vibecodeos/releases)
2. Проверить, что ISO загружен
3. Скачать и проверить чексумму:
   ```bash
   sha256sum -c VibeCodeOS-v0.1.0-alpha.iso.sha256
   ```

#### Анонс

- Обновить README.md со ссылкой на последний релиз
- Написать пост в соцсетях/форумах (если применимо)
- Обновить документацию с известными проблемами

---

### Hotfix релизы

Для срочных исправлений:

```bash
# Создаём ветку hotfix
git checkout -b hotfix/v0.1.1-alpha

# Вносим исправления
# ... правки ...

# Коммитим
git commit -am "Fix critical bug in installer"

# Мержим в main
git checkout main
git merge hotfix/v0.1.1-alpha

# Создаём тег
git tag v0.1.1-alpha
git push origin main v0.1.1-alpha
```

---

### Ручной релиз (без GitHub Actions)

Если нужно создать релиз вручную:

```bash
# 1. Собрать ISO локально
sudo BUILD_MODE=full ./scripts/build-iso.sh

# 2. Переименовать
mv build/VibeCodeOS-alpha.iso build/VibeCodeOS-v0.1.0-alpha.iso

# 3. Создать чексуммы
cd build
sha256sum VibeCodeOS-v0.1.0-alpha.iso > VibeCodeOS-v0.1.0-alpha.iso.sha256
md5sum VibeCodeOS-v0.1.0-alpha.iso > VibeCodeOS-v0.1.0-alpha.iso.md5

# 4. Создать релиз на GitHub вручную
# - Перейти в Releases → Draft a new release
# - Создать тег v0.1.0-alpha
# - Загрузить файлы
# - Написать release notes
# - Опубликовать
```

---

### Troubleshooting

**Проблема:** Сборка падает с ошибкой "No space left on device"

**Решение:** GitHub Actions очищает диск перед сборкой, но если всё равно не хватает:
- Уменьшить размер базовой системы
- Оптимизировать список пакетов
- Использовать более агрессивное сжатие SquashFS

**Проблема:** Релиз создался, но ISO не загрузился

**Решение:** Проверить логи workflow, возможно:
- Недостаточно прав (нужен `contents: write`)
- Файл слишком большой (лимит GitHub: 2GB для релизов)

**Проблема:** Тег создан, но workflow не запустился

**Решение:** 
- Проверить, что тег соответствует паттерну `v*.*.*`
- Убедиться, что workflow файл в main ветке
- Проверить права доступа в Settings → Actions

---

### Roadmap релизов

**v0.1.0-alpha** (текущий)
- Базовая система с MATE
- Установщик
- Базовый брендинг

**v0.2.0-alpha**
- Dev-stack (языки, IDE, терминалы)
- Улучшенный брендинг
- Welcome App

**v0.3.0-beta**
- AI-стек (Ollama, Open WebUI)
- Полная документация
- Тестирование на реальном железе

**v1.0.0**
- Первый стабильный релиз
- Все фичи из roadmap.md (Фазы 1-4)
- Полное тестирование
