#!/bin/bash
# StrongSwan Ubuntu Installer - production-ready
# Run from repo root: sudo ./install.sh [--firewall] [--no-start]

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="${REPO_DIR}/config"
SCRIPTS_DIR="${REPO_DIR}/scripts"
INSTALL_FIREWALL=false
NO_START=false

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

for arg in "$@"; do
    case "$arg" in
        --firewall) INSTALL_FIREWALL=true ;;
        --no-start) NO_START=true ;;
        -h|--help)
            echo "Usage: $0 [--firewall] [--no-start]"
            echo "  --firewall   Configure UFW for StrongSwan (IKE, NAT-T, ESP)"
            echo "  --no-start   Do not start or enable services"
            exit 0
            ;;
    esac
done

[ "$EUID" -ne 0 ] && { log_error "Run as root or with sudo"; exit 1; }

if [ ! -f /etc/os-release ]; then
    log_error "Cannot detect OS"
    exit 1
fi
. /etc/os-release
if [ "${ID:-}" != "ubuntu" ]; then
    log_warn "This script targets Ubuntu. Detected: ${ID:-unknown}"
    read -p "Continue anyway? [y/N] " -n 1 -r; echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

log_info "Installing StrongSwan on Ubuntu..."

# 1. Packages
log_info "Installing packages..."
apt-get update -qq
apt-get install -y strongswan strongswan-pki libcharon-extra-plugins

# 2. Directories
log_info "Creating directories..."
mkdir -p /var/log/strongswan
chown root:root /var/log/strongswan
chmod 755 /var/log/strongswan
mkdir -p /etc/ipsec.d/certs /etc/ipsec.d/private /etc/ipsec.d/cacerts
chmod 755 /etc/ipsec.d /etc/ipsec.d/certs /etc/ipsec.d/cacerts
chmod 700 /etc/ipsec.d/private
mkdir -p /etc/strongswan/strongswan.d

# 3. Deploy config from repo
if [ -d "$CONFIG_SRC" ]; then
    log_info "Deploying configuration from $CONFIG_SRC ..."
    [ -f "$CONFIG_SRC/ipsec.conf" ]          && cp "$CONFIG_SRC/ipsec.conf" /etc/ipsec.conf
    [ -f "$CONFIG_SRC/strongswan.conf" ]     && cp "$CONFIG_SRC/strongswan.conf" /etc/strongswan/strongswan.conf
    [ -f "$CONFIG_SRC/charon-logging.conf" ] && cp "$CONFIG_SRC/charon-logging.conf" /etc/strongswan/strongswan.d/charon-logging.conf
    if [ -f "$CONFIG_SRC/ipsec.secrets.example" ]; then
        if [ ! -f /etc/ipsec.secrets ]; then
            cp "$CONFIG_SRC/ipsec.secrets.example" /etc/ipsec.secrets
            chmod 600 /etc/ipsec.secrets
            log_warn "Created /etc/ipsec.secrets from example. Edit and add your keys!"
        else
            log_info "Leaving existing /etc/ipsec.secrets unchanged"
        fi
    fi
else
    log_warn "Config directory not found: $CONFIG_SRC. Skipping config deploy."
fi

# 4. Logrotate
log_info "Installing logrotate..."
LOGROTATE_SRC="${SCRIPTS_DIR}/logrotate-strongswan"
if [ -f "$LOGROTATE_SRC" ]; then
    cp "$LOGROTATE_SRC" /etc/logrotate.d/strongswan
    chmod 644 /etc/logrotate.d/strongswan
else
    log_warn "logrotate-strongswan not found in $SCRIPTS_DIR"
fi

# 5. IP forwarding
if ! grep -q 'net.ipv4.ip_forward=1' /etc/sysctl.conf 2>/dev/null; then
    log_info "Enabling IP forwarding..."
    echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
    sysctl -w net.ipv4.ip_forward=1
fi

# 6. Systemd
if [ "$NO_START" = false ]; then
    log_info "Enabling and starting services..."
    systemctl enable strongswan 2>/dev/null || true
    systemctl enable ipsec     2>/dev/null || true
    systemctl restart strongswan
    systemctl restart ipsec
    sleep 2
    systemctl is-active --quiet strongswan && log_info "StrongSwan is running" || log_warn "Check: systemctl status strongswan"
else
    log_info "Skipping start (--no-start). Run: systemctl enable --now strongswan ipsec"
fi

# 7. Optional firewall
if [ "$INSTALL_FIREWALL" = true ]; then
    log_info "Configuring firewall..."
    FIREWALL_SCRIPT="${SCRIPTS_DIR}/firewall.sh"
    if [ -x "$FIREWALL_SCRIPT" ]; then
        "$FIREWALL_SCRIPT"
    else
        ufw allow 500/udp comment 'StrongSwan IKE'  2>/dev/null || true
        ufw allow 4500/udp comment 'StrongSwan NAT-T' 2>/dev/null || true
        ufw allow proto esp comment 'StrongSwan ESP' 2>/dev/null || true
        ufw allow proto ah comment 'StrongSwan AH'   2>/dev/null || true
        log_info "UFW rules added. Run 'ufw enable' if needed."
    fi
fi

log_info "StrongSwan install complete."
log_info "Next: edit /etc/ipsec.secrets and /etc/ipsec.conf, add certs to /etc/ipsec.d/, then: sudo ipsec reload"
