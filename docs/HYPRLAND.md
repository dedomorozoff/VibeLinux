# VibeCode OS — Hyprland Edition

## 🚀 Что такое Hyprland?

**Hyprland** — это современный Wayland композитор с:
- ✨ Красивыми анимациями "из коробки"
- 🎯 Тайлингом окон (dwl-style)
- 🎨 Гибкой кастомизацией
- ⌨️ Keyboard-first подходом
- 🔥 Отличной производительностью

Для "вайбкодинга" это идеальный выбор — ничто не отвлекает от потока.

## 📦 Что включено

### Базовые компоненты
- **Hyprland** — Wayland композитор
- **SDDM** — дисплей менеджер с темой
- **PipeWire + WirePlumber** — аудио система
- **XDG Portals** — интеграция с приложениями

### Пользовательский интерфейс
- **Waybar** — стильная панель с системными модулями
- **Wofi** — лаунчер приложений (аналог rofi для Wayland)
- **Dunst** — система уведомлений
- **Kitty** — GPU-ускоренный терминал

### Утилиты
- **grim + slurp + swappy** — скриншоты
- **wl-clipboard** — буфер обмена
- **brightnessctl** — управление яркостью
- **pavucontrol** — управление звуком
- **Thunar** — файловый менеджер

### Шрифты и иконки
- JetBrains Mono
- Fira Code
- Hack
- Noto Color Emoji
- Papirus Icon Theme

## ⌨️ Горячие клавиши

### Основные
| Клавиша | Действие |
|---------|----------|
| `SUPER + Return` | Открыть терминал (Kitty) |
| `SUPER + Space` | Лаунчер приложений (Wofi) |
| `SUPER + E` | Файловый менеджер (Thunar) |
| `SUPER + Q` | Закрыть окно |
| `SUPER + P` | Скриншот |

### Управление окнами
| Клавиша | Действие |
|---------|----------|
| `SUPER + F` | Полноэкранный режим |
| `SUPER + G` | Плавающее окно |
| `SUPER + стрелки` | Переместить фокус |
| `SUPER + CTRL + стрелки` | Изменить размер окна |

### Рабочие пространства
| Клавиша | Действие |
|---------|----------|
| `SUPER + 1-9` | Переключение на workspace |
| `SUPER + SHIFT + 1-9` | Переместить окно на workspace |
| `SUPER + S` | Special workspace (scratchpad) |
| `SUPER + scroll` | Прокрутка workspace |

### Мультимедиа
| Клавиша | Действие |
|---------|----------|
| `XF86AudioRaise/Lower` | Громкость +/- |
| `XF86AudioMute` | Mute |
| `XF86AudioPlay/Next/Prev` | Управление плеером |
| `XF86MonBrightness` | Яркость |

### Системные
| Клавиша | Действие |
|---------|----------|
| `SUPER + Escape` | Блокировка экрана |
| `SUPER + SHIFT + Q` | Меню питания |

## 🎨 Цветовая схема VibeCode

```
Background:  #0B1020 (тёмный сине-чёрный)
Primary:     #4CC9F0 (неоновый голубой)
Accent:      #7209B7 (фиолетовый)
Success:     #2EC4B6 (мятный)
Warning:     #FFE066 (жёлтый)
Error:       #ff6b6b (красный)
```

Активная рамка окна имеет градиент от голубого к фиолетовому с анимацией!

## ⚙️ Настройка

### Конфигурационные файлы

Все конфиги находятся в `~/.config/`:

```
~/.config/
├── hypr/
│   └── hyprland.conf      # Основной конфиг Hyprland
├── waybar/
│   ├── config.jsonc       # Конфиг панели
│   └── style.css          # Стили панели
├── wofi/
│   ├── config             # Конфиг лаунчера
│   └── style.css          # Стили лаунчера
├── dunst/
│   └── dunstrc            # Конфиг уведомлений
└── kitty/
    └── kitty.conf          # Конфиг терминала
```

### Быстрые изменения

#### Изменить раскладку клавиатуры
```bash
# В ~/.config/hypr/hyprland.conf
input {
    kb_layout = us,ru
    kb_options = grp:alt_shift_toggle
}
```

#### Изменить размер шрифта
```bash
# В ~/.config/hypr/hyprland.conf
general {
    gaps_in = 5      # Внутренние отступы
    gaps_out = 10    # Внешние отступы
    border_size = 2  # Размер рамки
}
```

#### Отключить анимации
```bash
# В ~/.config/hypr/hyprland.conf
animations {
    enabled = false
}
```

## 🐛 Решение проблем

### Hyprland не запускается
```bash
# Проверь логи
journalctl -u sddm
cat ~/.local/share/hyprland/hyprland.log

# Проверь что Wayland поддерживается
echo $XDG_SESSION_TYPE
```

### Нет звука
```bash
# Перезапусти PipeWire
systemctl --user restart pipewire pipewire-pulse wireplumber
```

### Не работает лаунчер
```bash
# Проверь что wofi установлен
which wofi

# Запусти вручную
wofi --show drun
```

### Скриншоты не работают
```bash
# Убедись что grim и slurp установлены
which grim slurp

# Проверь скрипт
cat /usr/local/bin/vibe-screenshot
```

## 🔗 Полезные ссылки

- [Hyprland Wiki](https://wiki.hyprland.org/)
- [Hyprland конфиги сообщества](https://github.com/hyprland-community/hyprland-configs)
- [Waybar документация](https://github.com/Alexays/Waybar/wiki)
- [Wofi документация](https://hg.sr.ht/~scoopta/wofi)

## 💡 Советы для вайбкодинга

1. **Используй special workspace** как scratchpad для заметок
2. **Настрой autostart** для часто используемых приложений
3. **Используй pseudotiling** для быстрого ресайза
4. **Горячие клавиши можно кастомизировать** под себя
5. **Создай свой стиль** в waybar/style.css

---

**Наслаждайся вайбкодингом! 🚀✨**
