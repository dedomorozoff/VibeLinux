#!/usr/bin/env bash
set -euo pipefail

# Скрипт настройки загрузчика GRUB для VibeCode OS

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

echo "[bootloader] Настройка GRUB для VibeCode OS..."

# Обновляем конфигурацию GRUB
if [[ -f /etc/default/grub ]]; then
  # Бэкап оригинального конфига
  cp /etc/default/grub /etc/default/grub.backup

  # Настраиваем GRUB
  sed -i 's/GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="VibeCode OS"/' /etc/default/grub

  # Убираем quiet splash для отладки (можно вернуть позже)
  # sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/' /etc/default/grub

  echo "[bootloader] GRUB конфигурация обновлена."
else
  echo "[bootloader] Файл /etc/default/grub не найден, создаём новый..."
  cat > /etc/default/grub << 'EOF'
GRUB_DEFAULT=0
GRUB_TIMEOUT_STYLE=menu
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="VibeCode OS"
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_CMDLINE_LINUX=""
EOF
fi

# Обновляем GRUB (если система установлена)
if command -v update-grub &> /dev/null; then
  echo "[bootloader] Обновление GRUB..."
  update-grub || echo "[bootloader] Предупреждение: не удалось обновить GRUB (возможно, в chroot)"
fi

echo "[bootloader] Настройка Plymouth splash screen..."

# Устанавливаем Plymouth
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  plymouth \
  plymouth-themes \
  || true

# Создаём кастомную тему Plymouth
PLYMOUTH_THEME_DIR="/usr/share/plymouth/themes/vibecodeos"
mkdir -p "$PLYMOUTH_THEME_DIR"

# Создаём простую текстовую тему
cat > "$PLYMOUTH_THEME_DIR/vibecodeos.plymouth" << 'EOF'
[Plymouth Theme]
Name=VibeCode OS
Description=VibeCode OS boot splash
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/vibecodeos
ScriptFile=/usr/share/plymouth/themes/vibecodeos/vibecodeos.script
EOF

# Создаём скрипт темы Plymouth
cat > "$PLYMOUTH_THEME_DIR/vibecodeos.script" << 'EOF'
# VibeCode OS Plymouth Theme

Window.SetBackgroundTopColor(0.04, 0.06, 0.12);
Window.SetBackgroundBottomColor(0.04, 0.06, 0.12);

# Логотип (если есть)
logo.image = Image("logo.png");
logo.sprite = Sprite(logo.image);
logo.opacity_angle = 0;

# Позиционируем логотип по центру
logo.x = Window.GetX() + Window.GetWidth() / 2 - logo.image.GetWidth() / 2;
logo.y = Window.GetY() + Window.GetHeight() / 2 - logo.image.GetHeight() / 2 - 100;
logo.sprite.SetPosition(logo.x, logo.y, 0);

# Текст загрузки
message_sprite = Sprite();
message_sprite.SetPosition(Window.GetX() + Window.GetWidth() / 2, Window.GetY() + Window.GetHeight() / 2 + 100, 10000);

fun message_callback(text) {
  my_image = Image.Text(text, 0.30, 0.80, 0.94, 1);
  message_sprite.SetImage(my_image);
  message_sprite.SetX(Window.GetX() + Window.GetWidth() / 2 - my_image.GetWidth() / 2);
}

Plymouth.SetMessageFunction(message_callback);

# Анимация загрузки
progress_box.image = Image("progress_box.png");
progress_box.sprite = Sprite(progress_box.image);
progress_box.x = Window.GetX() + Window.GetWidth() / 2 - progress_box.image.GetWidth() / 2;
progress_box.y = Window.GetY() + Window.GetHeight() * 0.75;
progress_box.sprite.SetPosition(progress_box.x, progress_box.y, 0);

progress_bar.original_image = Image("progress_bar.png");
progress_bar.sprite = Sprite();
progress_bar.x = Window.GetX() + Window.GetWidth() / 2 - progress_bar.original_image.GetWidth() / 2;
progress_bar.y = Window.GetY() + Window.GetHeight() * 0.75;
progress_bar.sprite.SetPosition(progress_bar.x, progress_bar.y, 1);

fun progress_callback(duration, progress) {
  if (progress_bar.image.GetWidth() != Math.Int(progress_bar.original_image.GetWidth() * progress)) {
    progress_bar.image = progress_bar.original_image.Scale(progress_bar.original_image.GetWidth(progress_bar.original_image) * progress, progress_bar.original_image.GetHeight());
    progress_bar.sprite.SetImage(progress_bar.image);
  }
}

Plymouth.SetBootProgressFunction(progress_callback);

# Сообщение о загрузке
Plymouth.SetMessage("Starting VibeCode OS...");
EOF

# Создаём простые placeholder изображения (можно заменить на реальные)
# Для текстовой темы можно использовать bgrt или text тему как базу
echo "[bootloader] Используем текстовую тему Plymouth как fallback..."

# Устанавливаем тему (если plymouth установлен)
if command -v plymouth-set-default-theme &>/dev/null; then
  if [[ -d /usr/share/plymouth/themes/text ]]; then
    plymouth-set-default-theme text || true
    echo "[bootloader] Тема Plymouth установлена: text"
  fi
else
  echo "[bootloader] Plymouth не установлен (minimal версия), пропускаем..."
fi

# Обновляем initramfs
if command -v update-initramfs &> /dev/null; then
  echo "[bootloader] Обновление initramfs..."
  update-initramfs -u || echo "[bootloader] Предупреждение: не удалось обновить initramfs (возможно, в chroot)"
fi

echo "[bootloader] Настройка загрузчика завершена."
