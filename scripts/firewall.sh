#!/bin/bash
# StrongSwan firewall - UFW or iptables (IKE, NAT-T, ESP, AH, NAT)

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

[ "$EUID" -ne 0 ] && { log_error "Run as root or with sudo"; exit 1; }

VPN_INTERFACE="${VPN_INTERFACE:-eth0}"
VPN_CLIENT_POOL="${VPN_CLIENT_POOL:-10.10.10.0/24}"
IKE_PORT=500
NAT_T_PORT=4500

log_info "Configuring firewall for StrongSwan..."

if command -v ufw &> /dev/null; then
    ufw allow $IKE_PORT/udp comment 'StrongSwan IKE'
    ufw allow $NAT_T_PORT/udp comment 'StrongSwan NAT-T'
    ufw allow proto esp comment 'StrongSwan ESP'
    ufw allow proto ah comment 'StrongSwan AH'
    ufw route allow in on $VPN_INTERFACE out on $VPN_INTERFACE from $VPN_CLIENT_POOL 2>/dev/null || true
    log_info "UFW rules added."
elif command -v iptables &> /dev/null; then
    iptables -A INPUT -p udp --dport $IKE_PORT -j ACCEPT
    iptables -A OUTPUT -p udp --sport $IKE_PORT -j ACCEPT
    iptables -A INPUT -p udp --dport $NAT_T_PORT -j ACCEPT
    iptables -A OUTPUT -p udp --sport $NAT_T_PORT -j ACCEPT
    iptables -A INPUT -p esp -j ACCEPT
    iptables -A OUTPUT -p esp -j ACCEPT
    iptables -A INPUT -p ah -j ACCEPT
    iptables -A OUTPUT -p ah -j ACCEPT
    sysctl -w net.ipv4.ip_forward=1
    grep -q 'net.ipv4.ip_forward=1' /etc/sysctl.conf 2>/dev/null || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
    iptables -t nat -A POSTROUTING -s $VPN_CLIENT_POOL -o $VPN_INTERFACE -j MASQUERADE
    iptables -A FORWARD -s $VPN_CLIENT_POOL -j ACCEPT
    iptables -A FORWARD -d $VPN_CLIENT_POOL -j ACCEPT
    command -v netfilter-persistent &> /dev/null && netfilter-persistent save
    log_info "iptables rules added."
else
    log_error "Neither UFW nor iptables found."
    exit 1
fi
log_info "Firewall configuration complete. Set VPN_CLIENT_POOL and VPN_INTERFACE if needed."
