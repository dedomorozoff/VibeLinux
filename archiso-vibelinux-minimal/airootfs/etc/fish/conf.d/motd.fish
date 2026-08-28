# Show VibeLinux MOTD on interactive shell start (fish ignores /etc/motd)
if status is-interactive
    if test -r /etc/motd
        cat /etc/motd
    end
end
