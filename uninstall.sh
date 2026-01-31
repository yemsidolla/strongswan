#!/bin/bash
# Remove StrongSwan config (and optionally packages). Run as root: sudo ./uninstall.sh [--purge]
# Then reinstall with: sudo ./install.sh

set -euo pipefail

PURGE=false
for arg in "$@"; do
    case "$arg" in
        --purge) PURGE=true ;;
        -h|--help)
            echo "Usage: $0 [--purge]"
            echo "  (no args)  Remove config only. Packages stay installed."
            echo "  --purge    Also purge strongswan packages."
            exit 0
            ;;
    esac
done

[ "$EUID" -eq 0 ] || { echo "Run as root: sudo $0"; exit 1; }

echo "[*] Stopping strongswan-starter..."
systemctl stop strongswan-starter 2>/dev/null || true

echo "[*] Removing StrongSwan config..."
rm -f /etc/ipsec.conf /etc/ipsec.secrets
rm -rf /etc/ipsec.d
rm -f /etc/strongswan.conf
rm -rf /etc/strongswan.d
rm -rf /etc/strongswan

if [ "$PURGE" = true ]; then
    echo "[*] Purging packages..."
    apt-get purge -y strongswan strongswan-pki libcharon-extra-plugins 2>/dev/null || true
    apt-get autoremove -y 2>/dev/null || true
    echo "[*] Packages purged. Run: sudo ./install.sh to reinstall."
else
    echo "[*] Config removed. Packages still installed. Run: sudo ./install.sh to redeploy config."
fi

echo "[*] Done."
