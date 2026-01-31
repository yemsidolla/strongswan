#!/bin/bash
# StrongSwan /etc backup - backs up /etc/ipsec*, /etc/strongswan*, /etc/ipsec.d

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/strongswan}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="strongswan-etc-${TIMESTAMP}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

[ "$EUID" -ne 0 ] && { log_error "Run as root or with sudo"; exit 1; }

mkdir -p "$BACKUP_PATH"
log_info "Backing up StrongSwan /etc to $BACKUP_PATH"

[ -f /etc/ipsec.conf ]    && cp -a /etc/ipsec.conf "$BACKUP_PATH/"
[ -f /etc/ipsec.secrets ] && cp -a /etc/ipsec.secrets "$BACKUP_PATH/"
[ -d /etc/strongswan ]    && cp -a /etc/strongswan "$BACKUP_PATH/"
[ -d /etc/ipsec.d ]       && cp -a /etc/ipsec.d "$BACKUP_PATH/"

cat > "$BACKUP_PATH/manifest.txt" <<EOF
StrongSwan /etc backup
Timestamp: $(date)
Paths: /etc/ipsec.conf, /etc/ipsec.secrets, /etc/strongswan, /etc/ipsec.d
EOF

cd "$BACKUP_DIR"
tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"
rm -rf "$BACKUP_NAME"
log_info "Created ${BACKUP_NAME}.tar.gz"

[ "$RETENTION_DAYS" -gt 0 ] && find "$BACKUP_DIR" -name "strongswan-etc-*.tar.gz" -type f -mtime +$RETENTION_DAYS -delete
log_info "Backup complete."
