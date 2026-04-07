# Исправления kernel panic в Live ISO

## Проблема

При загрузке ISO VibeCode OS возникал **kernel panic** из-за неправильной сборки initrd и отсутствия casper hook.

## Корневые причины

1. **Initrd без casper скриптов** — ядро не могло смонтировать squashfs как корневую файловую систему
2. **Отсутствие /conf/casper.conf** — casper не знал, где искать filesystem.squashfs
3. **Неправильные параметры ядра** — конфликтующие параметры в GRUB (nomodeset, vga=normal, fb=false)
4. **Отсутствие модулей в initrd** — модули squashfs, overlay, loop не включались в initramfs

## Внесённые исправления

### 1. `scripts/base/minimal-packages.sh`

- Изменён порядок установки: **casper устанавливается ДО ядра** для правильного hook
- Добавлен пакет `squashfs-tools`
- Создан `/etc/initramfs-tools/conf.d/casper.conf` с параметрами `BOOT=casper`
- Добавлены модули в `/etc/initramfs-tools/modules`: overlay, squashfs, loop, aufs

### 2. `scripts/base/base-packages.sh`

- Добавлена настройка casper.conf при обновлении initramfs
- Добавлены модули для live-системы

### 3. `scripts/base/setup-bootloader.sh`

- **Удалены конфликтующие параметры**: nomodeset, vga=normal, fb=false
- Оставлены только `quiet splash` для live-сессии
- Параметры live-сессии теперь задаются в GRUB config скрипта сборки

### 4. `scripts/build-minimal-iso.sh`

- Используется `mkinitramfs` вместо `update-initramfs` для явного контроля
- Добавлена проверка initrd на наличие casper скриптов
- Добавлено логирование содержимого initrd при проблемах
- **Создан `/conf/casper.conf`** в образе ISO с указанием пути к squashfs
- Добавлена финальная проверка ISO с монтированием и проверкой файлов
- Добавлены модули sr_mod, cdrom для работы с CD-ROM

### 5. `scripts/build-iso.sh`

- **Создан `/conf/casper.conf`** в образе ISO
- Добавлена финальная проверка ISO с монтированием
- Проверка наличия casper в initrd

## Структура правильного Live ISO

```
ISO файл:
├── boot/
│   ├── grub/
│   │   └── grub.cfg          # Параметры ядра: boot=casper
│   ├── vmlinuz               # Ядро
│   └── initrd.img            # Initrd с casper hook
├── casper/
│   ├── vmlinuz               # Копия ядра
│   ├── initrd                # Копия initrd
│   └── filesystem.squashfs   # Сжатая корневая ФС
├── conf/
│   └── casper.conf           # Конфиг: filesystem="casper/filesystem.squashfs"
└── .disk/
    └── info                  # Информация о дистрибутиве
```

## Критические параметры GRUB для live-сессии

```grub
menuentry "VibeCode OS (Live)" {
    linux /casper/vmlinuz boot=casper noprompt quiet username=vibecode hostname=vibecode ---
    initrd /casper/initrd
}
```

**Обязательные параметры:**
- `boot=casper` — активирует casper hook в initrd
- `noprompt` — не спрашивать о установке
- `quiet` — скрыть сообщения ядра (опционально)
- `---` — разделитель между параметрами ядра и casper

## Проверка работоспособности ISO

### 1. Проверка содержимого

```bash
# Смонтировать ISO
mount -o loop VibeCodeOS.iso /mnt

# Проверить критические файлы
ls -la /mnt/casper/vmlinuz /mnt/casper/initrd /mnt/casper/filesystem.squashfs
ls -la /mnt/conf/casper.conf
cat /mnt/conf/casper.conf

# Проверить initrd на наличие casper
lsinitramfs /mnt/casper/initrd | grep casper

umount /mnt
```

### 2. Проверка в VirtualBox/QEMU

```bash
# QEMU тест
qemu-system-x86_64 -cdrom VibeCodeOS.iso -boot d -m 2048

# VirtualBox
VBoxManage createvm --name "VibeCode Test" --register
VBoxManage storagectl "VibeCode Test" --name "IDE Controller" --add ide
VBoxManage storageattach "VibeCode Test" --storagectl "IDE Controller" \
  --port 0 --device 0 --type dvddrive --medium VibeCodeOS.iso
```

## Отладка kernel panic

Если всё ещё возникает kernel panic:

1. **Добавить `debug break=bottom` в параметры ядра:**
   ```
   linux /casper/vmlinuz boot=casper debug break=bottom ---
   ```

2. **Проверить загрузочные сообщения:**
   - Убрать `quiet` из параметров
   - Сделать скриншот ошибки

3. **Проверить initrd вручную:**
   ```bash
   mkdir /tmp/initrd
   cd /tmp/initrd
   zcat /path/to/initrd | cpio -idmv
   ls scripts/casper
   cat scripts/casper
   ```

4. **Проверить squashfs:**
   ```bash
   unsquashfs -l /path/to/filesystem.squashfs | head
   ```

## Тестирование

После сборки проверьте ISO:

```bash
# Dry-run проверка
BUILD_MODE=dry-run ./scripts/build-minimal-iso.sh

# Полная сборка
sudo BUILD_MODE=full ./scripts/build-minimal-iso.sh

# Проверка ISO
./scripts/verify-build.sh /path/to/iso
```

## Ссылки

- [Ubuntu Casper Documentation](https://wiki.ubuntu.com/Casper)
- [Initramfs Tools](https://manpages.ubuntu.com/manpages/noble/en/man7/initramfs-tools.7.html)
- [GRUB2 Live ISO](https://www.gnu.org/software/grub/manual/grub/html_node/Multiboot-with-GRUB-2.html)
