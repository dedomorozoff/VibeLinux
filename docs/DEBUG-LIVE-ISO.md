# Отладка kernel panic в VibeCode OS

Этот документ описывает процесс диагностики и исправления ошибок загрузки live ISO.

## Типичная ошибка

```
Kernel panic - not syncing: Attempted to kill init! exitcode=0x00000100
```

Эта ошибка означает, что **init-процесс** (PID 1) завершился с кодом ошибки сразу после запуска.

---

## Причины и решения

### 1. Отсутствует systemd

**Проблема:** Ubuntu 24.04 использует systemd как init-систему. Без него ядро не может запустить init.

**Проверка:**
```bash
# В chroot после установки пакетов
ls -la /lib/systemd/systemd
ls -la /sbin/init
```

**Решение:**
- Убедитесь, что `systemd` и `systemd-sysv` установлены в `base-packages.sh`
- Проверьте, что `/sbin/init` — symlink на `/lib/systemd/systemd`
- Добавьте явную проверку в `build-iso.sh` после установки пакетов

### 2. Неправильные параметры ядра GRUB

**Проблема:** Casper не может найти правильный init-процесс.

**Решение:** Добавьте `init=/lib/systemd/systemd` в параметры ядра:

```grub
menuentry "VibeCode OS (Live)" {
    linux /casper/vmlinuz boot=casper init=/lib/systemd/systemd noprompt nomodeset ...
    initrd /casper/initrd
}
```

### 3. Повреждённый initrd

**Проблема:** Initrd образ не содержит необходимых модулей для запуска systemd.

**Проверка:**
```bash
# После сборки ISO проверьте размер initrd
ls -lh build/image/casper/initrd
```

**Решение:**
- Убедитесь, что `update-initramfs -u` вызывается после установки ядра
- Проверьте, что `initramfs-tools` установлен

### 4. Проблемы с casper

**Проблема:** Casper не правильно монтирует squashfs.

**Проверка логов:**
1. Загрузитесь в GRUB
2. Нажмите `e` для редактирования записи
3. Удалите `quiet splash` из параметров ядра
4. Нажмите `F10` для загрузки
5. Наблюдайте за логами загрузки

**Решение:**
- Убедитесь, что `casper` и `live-tools` установлены
- Проверьте, что `filesystem.squashfs` создан корректно

### 5. Autoremove удалил критические пакеты

**Проблема:** `apt-get autoremove` может удалить systemd, если он считается "ненужным".

**Решение:**
- Используйте `apt-get autoremove --important`
- Добавьте проверку systemd после каждого `autoremove`
- Восстанавливайте systemd если он удалён:
  ```bash
  apt-get install -y systemd systemd-sysv
  ln -sf /lib/systemd/systemd /sbin/init
  ```

---

## Чеклист для проверки сборки

### В chroot (после установки пакетов):

```bash
# 1. Проверка systemd
[ -f /lib/systemd/systemd ] && echo "OK: systemd exists"
[ -L /sbin/init ] && echo "OK: /sbin/init is symlink"
readlink /sbin/init  # Должен показать /lib/systemd/systemd

# 2. Проверка ядра
ls -la /boot/vmlinuz-*
ls -la /boot/initrd.img-*

# 3. Проверка casper
dpkg -l | grep casper
dpkg -l | grep live-tools

# 4. Проверка локали
locale

# 5. Проверка пакетов
dpkg -l | grep -E 'systemd|linux-image|initramfs'
```

### В собранном ISO:

```bash
# 1. Проверка структуры
ls -la build/image/casper/
# Должны быть: vmlinuz, initrd, filesystem.squashfs

# 2. Проверка GRUB
cat build/image/boot/grub/grub.cfg
# Проверьте наличие init=/lib/systemd/systemd

# 3. Проверка squashfs
unsquashfs -l build/image/casper/filesystem.squashfs | head -20
# Проверьте что /lib/systemd/systemd существует внутри squashfs
```

---

## Отладка в реальном времени

### Метод 1: Виртуальная машина с логами

```bash
# Запуск QEMU с выводом в консоль
qemu-system-x86_64 \
  -cdrom build/VibeCodeOS-alpha.iso \
  -m 4096 \
  -serial stdio \
  -display none
```

### Метод 2: GRUB debug mode

1. В GRUB нажмите `c` для входа в консоль
2. Введите команды для ручной загрузки:
   ```
   set root=(iso)
   linux /casper/vmlinuz boot=casper init=/lib/systemd/systemd noprompt nomodeset
   initrd /casper/initrd
   boot
   ```

### Метод 3: Busybox shell

Если загрузка падает до busybox:
```bash
# Попробуйте вручную запустить systemd
exec /lib/systemd/systemd
```

---

## Внесённые исправления (commit 2026-03-26)

### Файл: `scripts/base/base-packages.sh`
- ✅ Добавлены пакеты `systemd` и `systemd-sysv`
- ✅ Добавлен пакет `live-tools` для live-сессии

### Файл: `scripts/build-iso.sh`
- ✅ Добавлена проверка systemd и `/sbin/init` после установки пакетов
- ✅ Добавлен параметр `init=/lib/systemd/systemd` в GRUB конфигурацию
- ✅ Добавлены комментарии для отладки (удаление `quiet splash`)

### Файл: `scripts/desktop/install-kde.sh`
- ✅ Использован флаг `--important` для `autoremove`
- ✅ Добавлена проверка systemd после `autoremove`
- ✅ Добавлено восстановление symlink `/sbin/init`

### Файл: `scripts/base/cleanup.sh`
- ✅ Удалён опасный `autoremove`
- ✅ Добавлена проверка systemd в конце скрипта

---

## Следующие шаги

1. Пересоберите ISO:
   ```bash
   sudo BUILD_MODE=full ./scripts/build-iso.sh
   ```

2. Протестируйте в VirtualBox/QEMU

3. Если ошибка сохраняется:
   - Удалите `quiet splash` из GRUB
   - Сделайте скриншот полной ошибки
   - Проверьте логи через `journalctl` (если удаётся загрузиться в rescue mode)

4. Для быстрой отладки используйте `KEEP_CHROOT=1`:
   ```bash
   sudo KEEP_CHROOT=1 BUILD_MODE=full ./scripts/build-iso.sh
   ```
