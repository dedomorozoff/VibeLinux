# VibeCode OS — Запуск в VirtualBox

## 🛠️ Настройки VirtualBox для корректной загрузки

### Рекомендуемые настройки VM

**Система:**
- **Base Memory (ОЗУ):** 2048 MB (минимум), 4096 MB (рекомендуется)
- **Processor(s (CPU):** 2 CPU (минимум), 4 CPU (рекомендуется)
- **Enable EFI:** ❌ **ОТКЛЮЧИТЬ** (может вызывать проблемы с загрузкой)

**Дисплей:**
- **Video Memory:** 128 MB (максимум)
- **Graphics Controller:** **VMSVGA** (для Linux)
- **Enable 3D Acceleration:** ❌ **ОТКЛЮЧИТЬ** (может вызывать чёрный экран)
- **Enable 2D Video Acceleration:** ❌ ОТКЛЮЧИТЬ

**Носители:**
- **Controller: IDE** → Выбрать ISO образ VibeCode OS

**Сеть:**
- **Attached to:** NAT (по умолчанию)

---

## 🔧 Решение проблем

### Чёрный экран при загрузке

**Причина:** Проблемы с видеодрайверами или режимом KMS (Kernel Mode Setting).

**Решение 1: Настройки GRUB**
1. При загрузке нажмите `Shift` или `Esc` для появления меню GRUB
2. Нажмите `e` для редактирования загрузочной записи
3. Найдите строку, начинающуюся с `linux` или `linuxefi`
4. Добавьте параметры: `nomodeset vga=normal fb=false`
5. Нажмите `F10` или `Ctrl+X` для загрузки

**Решение 2: Настройки VirtualBox**
1. Отключите 3D Acceleration в настройках VM
2. Уменьшите Video Memory до 64 MB
3. Попробуйте другой Graphics Controller (VMSVGA → VBoxVGA)

**Решение 3: Постоянное изменение параметров ядра**
```bash
# После установки системы
sudo nano /etc/default/grub

# Найдите строку:
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"

# Замените на:
GRUB_CMDLINE_LINUX_DEFAULT="nomodeset vga=normal fb=false"

# Обновите GRUB:
sudo update-grub
sudo reboot
```

### Загрузка не с того устройства

**Решение:**
1. File → Preferences → Input
2. Отключите "Auto Capture Keyboard"
3. При загрузке нажмите `F12` для выбора загрузочного устройства

### Ошибка "No bootable medium found"

**Решение:**
1. Проверьте, что ISO образ подключён в настройках VM
2. Settings → Storage → Controller: IDE → Add Optical Drive
3. Выберите ISO файл VibeCode OS

### Ошибка "PXE-E53: No boot filename received"

**Причина:** VM пытается загрузиться по сети.

**Решение:**
1. Settings → System → Motherboard
2. В "Boot Order" переместите "Optical" на первое место
3. Отключите "Network" в boot order

---

## 📋 Параметры ядра для отладки

| Параметр | Описание |
|----------|----------|
| `nomodeset` | Отключает KMS для видеокарт |
| `vga=normal` | Стандартный VGA режим |
| `fb=false` | Отключает framebuffer |
| `quiet` | Скрывает сообщения загрузки |
| `splash` | Показывает splash screen |
| `debug` | Включает отладочные сообщения |
| `systemd.unit=multi-user.target` | Загрузка в текстовый режим |

### Комбинации для разных сценариев

**Безопасный режим (VirtualBox):**
```
nomodeset vga=normal fb=false quiet splash
```

**Текстовый режим (без GUI):**
```
nomodeset vga=normal fb=false systemd.unit=multi-user.target
```

**Режим отладки:**
```
nomodeset vga=normal fb=false debug loglevel=7
```

**Rescue mode:**
```
nomodeset vga=normal fb=false rescue
```

---

## ✅ Проверка после установки

**1. Проверка параметров ядра:**
```bash
cat /proc/cmdline
```

**2. Проверка видеодрайвера:**
```bash
lspci -k | grep -A 2 -i vga
```

**3. Проверка GRUB конфига:**
```bash
cat /etc/default/grub
```

**4. Проверка разрешения экрана:**
```bash
xrandr
```

---

## 🔗 Дополнительные ресурсы

- [VirtualBox Manual Display Settings](https://www.virtualbox.org/manual/ch03.html#settings-display)
- [Ubuntu Kernel Mode Setting](https://wiki.ubuntu.com/Kernel/KernelModeSetting)
- [nomodeset Parameter](https://wiki.archlinux.org/title/Kernel_mode_setting)
