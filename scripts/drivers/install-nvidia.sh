#!/usr/bin/env bash
set -euo pipefail

# Draft script to install NVIDIA proprietary drivers for VibeCode OS.
# Target: Ubuntu 24.04 (noble) or compatible, running with root privileges.
#
# Strategy for alpha:
#   - Основной сценарий — post-install: запуск скрипта после установки системы.
#   - Интеграция с установщиком (выбор проприетарных драйверов) будет рассматриваться позже.
#
# Profiles:
#   - desktop — стандартный драйвер для рабочего стола.
#   - ai      — драйвер + базовый набор CUDA/compute-компонентов (в будущем).

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

PROFILE="${PROFILE:-desktop}" # desktop|ai
DRIVER_VERSION="${NVIDIA_DRIVER_VERSION:-535}" # 535 for LTS stability, can be overridden via env

echo "[drivers/nvidia] Обновление списка пакетов..."
apt-get update -y

echo "[drivers/nvidia] Установка проприетарных драйверов NVIDIA (версия ${DRIVER_VERSION})..."

case "$PROFILE" in
  ai)
    # Для AI-профиля: драйвер + CUDA toolkit
    DEBIAN_FRONTEND=noninteractive apt-get install -y\
      "nvidia-driver-${DRIVER_VERSION}" \
      nvidia-cuda-toolkit
    ;;
  desktop|*)
    DEBIAN_FRONTEND=noninteractive apt-get install -y\
      "nvidia-driver-${DRIVER_VERSION}"
    ;;
esac

echo "[drivers/nvidia] Готово. Для применения драйвера может потребоваться перезагрузка."
echo "[drivers/nvidia] Расширенная поддержка (CUDA, AI-профили) будет оформлена отдельными шагами и докой."

