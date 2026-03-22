# VibeCode OS — Решение проблем

## 🔧 Ошибка: `/usr/bin/env: 'bash\r': No such file or directory`

### Причина
Скрипты имеют окончания строк Windows (CRLF `\r\n`) вместо Unix (LF `\n`).

### Решение

#### При сборке на Windows

1. **Настройте Git:**
   ```bash
   git config --global core.autocrlf false
   git config --global core.eol lf
   ```

2. **Конвертируйте скрипты:**
   ```bash
   # PowerShell
   Get-ChildItem -Recurse -Filter *.sh | ForEach-Object {
     (Get-Content $_.FullName -Raw) -replace "`r`n", "`n" | Set-Content $_.FullName -NoNewline
   }
   ```

3. **Или используйте WSL:**
   ```bash
   # В WSL
   dos2unix scripts/*.sh
   dos2unix scripts/*/*.sh
   ```

#### При сборке в chroot

Скрипты сборки автоматически конвертируют окончания строк в chroot:
- `build-iso.sh` — конвертирует все скрипты
- `build-minimal-iso.sh` — конвертирует все скрипты

Если проблема сохраняется, проверьте, что `sed` установлен в chroot.

---

## 🔧 Ошибка: `plymouth-set-default-theme: command not found`

### Причина
В minimal-версии Plymouth не установлен.

### Решение
Скрипт `setup-bootloader.sh` теперь проверяет наличие команды и пропускает настройку Plymouth, если он не установлен.

**Обновите скрипт:**
```bash
# Если используете старую версию
git pull origin main
```

Или вручную исправьте `scripts/base/setup-bootloader.sh`:
```bash
# Найдите строку с plymouth-set-default-theme
# Замените на:
if command -v plymouth-set-default-theme &>/dev/null; then
  plymouth-set-default-theme text || true
fi
```

---

## 🔧 Ошибка: `Не удалось запустить hello-world. Проверьте Docker вручную`

### Причина
Docker не может запуститься в chroot-среде (нет systemd).

### Решение
Это **нормальное поведение** при сборке ISO. Docker будет работать в установленной системе.

Сообщение обновлено в `setup-devtools.sh`:
```
[setup-devtools] Chroot среда: Docker будет доступен после установки
```

---

## 🔧 Ошибка: `DEBIAN_FRONTEND=noninteractive: command not found`

### Причина
Переменная окружения не экспортирована.

### Решение
Убедитесь, что скрипт запускается с `sudo`:
```bash
sudo BUILD_MODE=full ./scripts/build-iso.sh
```

---

## 🔧 Ошибка: `debootstrap: command not found`

### Причина
Не установлены зависимости для сборки.

### Решение
```bash
# Ubuntu/Debian
sudo apt install -y debootstrap mksquashfs xorriso grub-pc-bin grub-efi-amd64-bin mtools

# Или через Makefile
make check
```

---

## 🔧 Ошибка: `No space left on device`

### Причина
Недостаточно места для сборки.

### Требования к месту
- **Minimal:** ~5 ГБ свободно
- **Full:** ~15-20 ГБ свободно

### Решение
```bash
# Очистка кэша
sudo apt clean
sudo apt autoremove

# Проверка места
df -h

# Удаление старых chroot
sudo rm -rf build/chroot build-minimal/chroot
```

---

## 🔧 Ошибка: `Failed to update initramfs`

### Причина
initramfs не может обновиться в chroot.

### Решение
Это **предупреждение**, а не ошибка. Сборка продолжится.

Если ошибка критична, убедитесь, что в chroot установлены:
- `initramfs-tools`
- `linux-image-generic`

---

## 📞 Дополнительные ресурсы

- [docs/BUILD-ISO.md](docs/BUILD-ISO.md) — процесс сборки
- [docs/TESTING.md](docs/TESTING.md) — тестирование
- [docs/MINIMAL-UPGRADE.md](docs/MINIMAL-UPGRADE.md) — доустановка
- [GitHub Issues](https://github.com/yourusername/vibecodeos/issues) — сообщить о проблеме
