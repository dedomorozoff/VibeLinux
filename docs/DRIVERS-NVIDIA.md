### NVIDIA в VibeCode OS

Этот документ описывает поддержку проприетарных драйверов NVIDIA в VibeCode OS.

---

### 1. Статус

Проприетарные драйверы NVIDIA **предустановлены** во всех сборках ISO:

| Сборка | Механизм установки |
|--------|-------------------|
| **Full (Ubuntu)** | `ubuntu-drivers autoinstall` → подбирает драйвер под GPU |
| **Lite (Ubuntu)** | `ubuntu-drivers autoinstall` → подбирает драйвер под GPU |
| **Full (i3wm, `build-iso.sh`)** | `install-nvidia.sh` → `nvidia-driver-535` |
| **Arch** | Пакеты `nvidia`, `nvidia-utils`, `nvidia-settings` в составе ISO |

Для сборок на основе Ubuntu драйвер подбирается автоматически через `ubuntu-drivers autoinstall`.  
Для Arch — устанавливается последняя стабильная версия из репозитория `extra`.

---

### 2. Параметры загрузки

GRUB настроен с параметром `nvidia-drm.modeset=1` для корректного KMS.  
`nomodeset` больше **не используется по умолчанию** — он блокировал загрузку NVIDIA-драйвера и мог вызывать перезагрузки на GPU-системах.

В пункте меню «Compatibility mode / Safe graphics» доступен fallback с `nomodeset` для систем без NVIDIA или с очень старыми GPU.

---

### 3. mkinitcpio (Arch)

В Arch-сборке модули NVIDIA добавлены в `/etc/mkinitcpio.conf`:
```
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm ...)
```
Initramfs пересобирается в `customize_airootfs.sh`.

### 3a. SDDM / DE сессия

В Arch-сборке SDDM настроен на **Plasma (X11)**, а не Wayland — из-за неполной совместимости проприетарного драйвера NVIDIA с KDE Wayland.

---

### 4. Post-install fallback

Скрипт `scripts/drivers/install-nvidia.sh` сохранён как fallback для ручной доустановки/переустановки драйвера после установки системы на диск.

---

### 5. Связь с AI-стеком

AI-инструменты (Ollama, PyTorch с CUDA, ComfyUI и др.) требуют наличия драйверов NVIDIA.  
С предустановкой драйвера ISO готов к AI-нагрузкам «из коробки» — пользователю остаётся только установить CUDA-версию PyTorch при необходимости.

---

### 6. DKMS (для установленной системы)

В live-ISO используется пакет `nvidia` (монолитный модуль для одного ядра).  
При установке на диск рекомендуется установка `nvidia-dkms` — это гарантирует автоматическую пересборку модуля при обновлении ядра:

```bash
sudo pacman -S nvidia-dkms nvidia-utils nvidia-settings   # Arch
sudo apt install nvidia-dkms nvidia-driver-550             # Ubuntu
```

Скрипт `install-nvidia.sh` автоматически ставит `nvidia-dkms` при инсталляции.

---

### 7. Известные ограничения

- Драйвер занимает ~1 ГБ в образе ISO
- Не все поколения GPU покрываются `ubuntu-drivers autoinstall` — для очень старых карт (GeForce 600 series и старше) может потребоваться `nvidia-driver-470` или nouveau
- В live-сессии драйвер загружается, но для постоянной установки (на жёсткий диск) рекомендуется переустановить драйвер через `install-nvidia.sh` или `ubuntu-drivers autoinstall` после первой загрузки, чтобы привязать его к установленному ядру
