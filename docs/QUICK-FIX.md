# Быстрая проверка исправления kernel panic

## Что было исправлено

Критическая ошибка **"Kernel panic - not syncing: Attempted to kill init! exitcode=0x00000100"** исправлена в commit 2026-03-26.

### Изменённые файлы

1. `scripts/base/base-packages.sh` - добавлены systemd, systemd-sysv, live-tools
2. `scripts/base/minimal-packages.sh` - добавлены systemd, live-tools
3. `scripts/build-iso.sh` - добавлен `init=/lib/systemd/systemd` в GRUB + проверка systemd
4. `scripts/build-minimal-iso.sh` - добавлен `init=/lib/systemd/systemd` в GRUB + проверка systemd
5. `scripts/desktop/install-mate.sh` - защита autoremove + проверка systemd
6. `scripts/base/cleanup.sh` - удалён опасный autoremove + проверка systemd

---

## Инструкция по пересборке

### 1. Полная сборка (Full ISO)

```bash
# Очистка предыдущей сборки (если есть)
rm -rf build/

# Сборка Full ISO с MATE и dev-стеком
sudo BUILD_MODE=full ./scripts/build-iso.sh
```

### 2. Быстрая сборка (с использованием существующего chroot)

```bash
# Если chroot уже есть от предыдущей сборки
sudo KEEP_CHROOT=1 BUILD_MODE=full ./scripts/build-iso.sh
```

### 3. Сборка Minimal ISO

```bash
# Очистка
rm -rf build-minimal/

# Сборка Minimal ISO
sudo BUILD_MODE=full ./scripts/build-minimal-iso.sh
```

---

## Проверка перед загрузкой

### 1. Проверка структуры ISO

```bash
ls -lh build/image/casper/
# Должны быть: vmlinuz, initrd, filesystem.squashfs

ls -lh build/image/boot/grub/
# Должны быть: grub.cfg, bios.img, efi.img
```

### 2. Проверка GRUB конфигурации

```bash
grep "init=" build/image/boot/grub/grub.cfg
# Должно показать: init=/lib/systemd/systemd
```

### 3. Проверка squashfs (содержимое ISO)

```bash
# Монтируем ISO
sudo mount -o loop build/VibeCodeOS-alpha.iso /mnt

# Проверяем наличие systemd внутри squashfs
unsquashfs -l /mnt/casper/filesystem.squashfs | grep "lib/systemd/systemd"

# Размонтируем
sudo umount /mnt
```

---

## Тестирование в виртуальной машине

### VirtualBox

```bash
# Создаём VM
VBoxManage createvm --name "VibeCode OS Test" --register
VBoxManage modifyvm "VibeCode OS Test" --memory 4096 --cpus 2
VBoxManage createhd --filename test.vdi --size 30720
VBoxManage storagectl "VibeCode OS Test" --name "SATA Controller" --add sata
VBoxManage storageattach "VibeCode OS Test" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium test.vdi
VBoxManage storagectl "VibeCode OS Test" --name "IDE Controller" --add ide
VBoxManage storageattach "VibeCode OS Test" --storagectl "IDE Controller" --port 1 --device 0 --type dvddrive --medium build/VibeCodeOS-alpha.iso
VBoxManage modifyvm "VibeCode OS Test" --boot1 dvd --boot2 disk

# Запускаем
VBoxHeadless --startvm "VibeCode OS Test"
```

### QEMU (с выводом в консоль для отладки)

```bash
qemu-system-x86_64 \
  -cdrom build/VibeCodeOS-alpha.iso \
  -m 4096 \
  -cpus 2 \
  -serial stdio \
  -display gtk
```

---

## Если ошибка сохраняется

### 1. Отладочный режим GRUB

1. При загрузке в GRUB нажмите `e` для редактирования
2. Найдите строку, начинающуюся с `linux`
3. Удалите `quiet splash`
4. Нажмите `F10` для загрузки
5. Наблюдайте за логами

### 2. Ручной запуск systemd из busybox

Если загрузка падает до busybox:

```bash
# Проверяем наличие systemd
ls -la /lib/systemd/systemd

# Пробуем запустить вручную
exec /lib/systemd/systemd
```

### 3. Проверка chroot после сборки

```bash
# Монтируем chroot для проверки
sudo mount --bind /dev/ build/chroot/dev
sudo mount --bind /proc/ build/chroot/proc
sudo mount --bind /sys/ build/chroot/sys
sudo chroot build/chroot

# Проверяем systemd
ls -la /lib/systemd/systemd
ls -la /sbin/init
readlink /sbin/init

# Выходим и размонтируем
exit
sudo umount build/chroot/dev
sudo umount build/chroot/proc
sudo umount build/chroot/sys
```

---

## Чеклист успешной загрузки

- [ ] GRUB меню отображается
- [ ] Загрузка начинается без kernel panic
- [ ] Видно сообщение "Starting VibeCode OS..." или Plymouth splash
- [ ] Запускается LightDM (для Full версии) или появляется консоль (Minimal)
- [ ] Можно войти под пользователем `vibecode` / `vibecode`

---

## Дополнительные ресурсы

- **Полная документация:** `docs/DEBUG-LIVE-ISO.md`
- **CHANGELOG:** `CHANGELOG.md` (раздел "Critical: Kernel Panic Fix")
- **BUILD-ISO.md:** `docs/BUILD-ISO.md`
