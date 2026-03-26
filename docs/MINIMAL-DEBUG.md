# VibeCode OS Minimal — Отладка Kernel Panic

Если вы столкнулись с kernel panic при загрузке минимальной сборки, следуйте этим инструкциям.

---

## 🔍 Симптомы

```
Kernel panic - not syncing: Attempted to kill init! exitcode=0x00000100
```

Или стек ошибки с:
- `do_user_addr_fault`
- `exc_page_fault`
- `entry_SYSCALL_64_after_hwframe`

---

## 🛠️ Причины и решения

### Причина 1: Неправильный параметр init= в GRUB

**Проблема:** В live-образах Ubuntu параметр `init=/lib/systemd/systemd` конфликтует с casper.

**Решение:** Уберите параметр `init=` из строки ядра в GRUB.

**Правильно:**
```
linux /casper/vmlinuz boot=casper noprompt quiet ---
```

**Неправильно:**
```
linux /casper/vmlinuz boot=casper init=/lib/systemd/systemd noprompt quiet ---
```

---

### Причина 2: Отсутствие пакета casper или live-config

**Проблема:** В ISO не установлены пакеты `casper`, `live-config`.

**Решение:** Убедитесь что в `scripts/base/minimal-packages.sh` есть:

```bash
casper
live-config
live-config-doc
squashfs-tools
```

---

### Причина 3: Повреждённый initramfs

**Проблема:** Initramfs не обновился после установки ядра.

**Решение:** В chroot выполните:

```bash
chroot /path/to/chroot
apt-get install -y --reinstall linux-generic initramfs-tools linux-firmware
update-initramfs -u -k all
exit
```

---

### Причина 4: Проблемы с VirtualBox

**Проблема:** `virtualbox-guest-utils` может ломать сборку в chroot.

**Решение:** Установите в опциональном режиме (уже реализовано):

```bash
if ! apt-get install -y virtualbox-guest-utils; then
  echo "WARNING: virtualbox-guest-utils не установился"
fi
```

---

## 🧪 Режимы загрузки

Новая сборка включает 5 режимов загрузки:

1. **Normal** — стандартная загрузка
2. **Safe graphics** — с `nomodeset` для проблемных видеокарт
3. **Rescue mode** — запуск в режиме спасения
4. **Text mode** — текстовый режим (multi-user.target)
5. **Debug mode** — подробные логи systemd для отладки

---

## 📋 Чек-лист перед сборкой

- [ ] В `minimal-packages.sh` установлены `casper`, `live-config`
- [ ] В GRUB-конфиге **нет** параметра `init=/lib/systemd/systemd`
- [ ] Ядро и initrd скопированы в `/casper/` и `/boot/`
- [ ] Initramfs обновлён командой `update-initramfs -u -k all`
- [ ] SquashFS создан без директорий `/boot`, `/proc`, `/sys`, `/dev`, `/run`, `/tmp`

---

## 🔬 Отладка

### 1. Проверка содержимого chroot

```bash
# Проверка ядра
ls -lh /path/to/chroot/boot/

# Проверка init
ls -la /path/to/chroot/sbin/init
readlink /path/to/chroot/sbin/init

# Проверка systemd
ls -la /path/to/chroot/lib/systemd/systemd
```

### 2. Проверка ISO

```bash
# Смонтировать ISO
mkdir /mnt/iso
sudo mount VibeCodeOS-minimal.iso /mnt/iso

# Проверить casper
ls -lh /mnt/iso/casper/
cat /mnt/iso/.disk/info

# Проверить GRUB
cat /mnt/iso/boot/grub/grub.cfg
```

### 3. Запуск в QEMU с логами

```bash
qemu-system-x86_64 \
  -cdrom VibeCodeOS-minimal.iso \
  -m 2048 \
  -serial stdio \
  -append "boot=casper systemd.log_level=debug systemd.log_target=console"
```

### 4. Запуск в QEMU с debug-shell

```bash
qemu-system-x86_64 \
  -cdrom VibeCodeOS-minimal.iso \
  -m 2048 \
  -append "boot=casper systemd.debug_shell"
```

После загрузки подключитесь через:
```bash
virsh console <vm-name>
```

Или используйте ttyS0:
```bash
screen /dev/ttyS0 115200
```

---

## 📞 Если ничего не помогло

1. Загрузитесь в **Debug mode**
2. Сделайте скриншот ошибки
3. Проверьте логи через `journalctl -xb`
4. Создайте issue на GitHub с:
   - Версией Ubuntu хоста
   - Версией debootstrap, mksquashfs, xorriso
   - Логами сборки
   - Скриншотом kernel panic

---

## 📚 Полезные команды

```bash
# Пересобрать ISO с сохранением chroot
KEEP_CHROOT=1 ./build-minimal-iso.sh full

# Очистить и собрать заново
rm -rf build-minimal
./build-minimal-iso.sh full

# Проверить зависимости
./build-minimal-iso.sh dry-run
```
