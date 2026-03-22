#!/usr/bin/env bash\nset -euo pipefail\n\n# Р§РµСЂРЅРѕРІРѕР№ СЃРєСЂРёРїС‚ РѕС‡РёСЃС‚РєРё СЃРёСЃС‚РµРјС‹ РѕС‚ РїСЂРµРґСѓСЃС‚Р°РЅРѕРІР»РµРЅРЅРѕРіРѕ "РјСѓСЃРѕСЂР°".\n# Р—Р°РґР°С‡Р°: РїРѕРєР°Р·Р°С‚СЊ РЅР°РјРµСЂРµРЅРёРµ, Р° РЅРµ Р±С‹С‚СЊ РѕРєРѕРЅС‡Р°С‚РµР»СЊРЅРѕ РІС‹Р»РёР·Р°РЅРЅС‹Рј.\n\nif [[ $EUID -ne 0 ]]; then\n  echo "РџРѕР¶Р°Р»СѓР№СЃС‚Р°, Р·Р°РїСѓСЃС‚РёС‚Рµ СЌС‚РѕС‚ СЃРєСЂРёРїС‚ СЃ sudo РёР»Рё РѕС‚ root."\n  exit 1\nfi\n\necho "[cleanup] РЈРґР°Р»РµРЅРёРµ С‚РёРїРёС‡РЅС‹С… РїСЂРµРґСѓСЃС‚Р°РЅРѕРІР»РµРЅРЅС‹С… РїР°РєРµС‚РѕРІ (С‡РµСЂРЅРѕРІРѕР№ СЃРїРёСЃРѕРє)..."

TO_REMOVE=(
  libreoffice-core
  libreoffice-common
  libreoffice-writer
  libreoffice-calc
  libreoffice-impress
  thunderbird
  gnome-games
  ubuntu-games-*
  example-content
  simple-scan
  totem
  cheese
  rhythmbox
  shotwell
)

apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y "${TO_REMOVE[@]}" || true
DEBIAN_FRONTEND=noninteractive apt-get autoremove -y

echo "[cleanup] РћС‡РёСЃС‚РєР° РєСЌС€Р° APT Рё РІСЂРµРјРµРЅРЅС‹С… С„Р°Р№Р»РѕРІ..."
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/*
rm -rf /var/tmp/*
rm -rf /root/.cache/*
rm -rf /home/vibecode/.cache/* 2>/dev/null || true

echo "[cleanup] Р“РѕС‚РѕРІРѕ."
\n