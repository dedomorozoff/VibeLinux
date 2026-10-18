# VibeLinux — локаль и консоль для интерактивной сессии fish.
#
# 1) Шрифт/раскладка: делегируем в vibelinux-console-setup (единая логика с
#    systemd-юнитом — подбор Unicode-шрифта под разрешение). Нужно, потому что
#    fbcon может сбросить шрифт на дефолтный уже после загрузки KMS.
# 2) Локаль: автологин в TTY может не получить LANG из locale.conf, из-за чего
#    вывод русских программ идёт транслитом/латиницей.
if status is-interactive
    if test -x /usr/local/bin/vibelinux-console-setup
        command /usr/local/bin/vibelinux-console-setup >/dev/null 2>&1
    end
end

# Локаль для сессии (если login не подхватил locale.conf)
if test -r /etc/locale.conf
    for line in (grep -v '^#' /etc/locale.conf)
        set -l k (string split -m1 '=' -- "$line")[1]
        set -l v (string split -m1 '=' -- "$line")[2]
        test -n "$k"; and set -gx "$k" "$v"
    end
end
