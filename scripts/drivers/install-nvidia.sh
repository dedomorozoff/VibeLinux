#!/usr/bin/env bash
set -euo pipefail

# Install NVIDIA proprietary drivers for VibeLinux.
# Supports Ubuntu (24.04+) and Debian-based distros.
#
# Profiles:
#   desktop  — стандартный драйвер для рабочего стола.
#   ai       — драйвер + CUDA toolkit + nvidia-container-toolkit.
#
# Overrides:
#   NVIDIA_DRIVER_VERSION=550  — принудительная версия драйвера.
#   PROFILE=ai                — AI-профиль.

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

PROFILE="${PROFILE:-desktop}"
ARCH=$(uname -m)

echo "[drivers/nvidia] Определение рекомендуемой версии драйвера..."

DRIVER_VERSION=""
if command -v ubuntu-drivers &>/dev/null; then
  DRIVER_VERSION=$(ubuntu-drivers list 2>/dev/null | grep -oP 'nvidia-driver-\K[0-9]+' | sort -V | tail -1 || true)
fi
if [[ -z "$DRIVER_VERSION" ]]; then
  DRIVER_VERSION="${NVIDIA_DRIVER_VERSION:-550}"
fi
echo "[drivers/nvidia] Версия драйвера: $DRIVER_VERSION"

echo "[drivers/nvidia] Установка проприетарных драйверов NVIDIA..."
case "${PROFILE}" in
  ai)
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      "nvidia-driver-${DRIVER_VERSION}" \
      nvidia-dkms \
      nvidia-cuda-toolkit \
      nvidia-container-toolkit 2>/dev/null || \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      "nvidia-driver-${DRIVER_VERSION}" \
      nvidia-dkms \
      nvidia-cuda-toolkit
    ;;
  desktop|*)
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      "nvidia-driver-${DRIVER_VERSION}" \
      nvidia-dkms
    ;;
esac

# nvidia-persistenced — keep GPU active (avoids GPU reset on idle)
systemctl enable nvidia-persistenced 2>/dev/null || true

echo "[drivers/nvidia] Готово. Перезагрузите систему для применения драйвера."
echo "[drivers/nvidia] Проверка: nvidia-smi"
