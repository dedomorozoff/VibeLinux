# VibeLinux — применить кириллическую локаль и консольный шрифт в интерактивной сессии.
# Нужно, т.к. автологин в TTY может не получить LANG из locale.conf, из-за чего
# вывод русских программ транслитом/латиницей.
if status is-interactive
    if command -v setfont >/dev/null 2>&1
        set -l font (string trim (grep '^FONT=' /etc/vconsole.conf 2>/dev/null | cut -d= -f2-))
        test -n "$font"; and setfont "$font" 2>/dev/null
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
