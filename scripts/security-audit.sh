#!/bin/bash
# StrongSwan security audit - permissions, algorithms, cert expiry, apt updates

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$REPO_DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
ISSUES=0
WARNINGS=0
PASSED=0

log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((PASSED++)) || true; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; ((WARNINGS++)) || true; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; ((ISSUES++)) || true; }

echo "StrongSwan Security Audit"
echo "========================="

# ipsec.secrets permissions
if [ -f /etc/ipsec.secrets ]; then
    PERMS=$(stat -c "%a" /etc/ipsec.secrets 2>/dev/null || stat -f "%OLp" /etc/ipsec.secrets 2>/dev/null)
    [ "$PERMS" = "600" ] && log_pass "ipsec.secrets has 600" || log_fail "ipsec.secrets should be 600 (got $PERMS)"
else
    log_warn "ipsec.secrets not found"
fi

# Private key permissions
for key in /etc/ipsec.d/private/*; do
    [ -f "$key" ] || continue
    PERMS=$(stat -c "%a" "$key" 2>/dev/null || stat -f "%OLp" "$key" 2>/dev/null)
    [ "$PERMS" = "600" ] && log_pass "Private key $(basename "$key") 600" || log_fail "$(basename "$key") should be 600"
done

# Strong algorithms in ipsec.conf
if [ -f /etc/ipsec.conf ]; then
    grep -q "aes256\|aes128gcm" /etc/ipsec.conf && log_pass "Strong ciphers in ipsec.conf" || log_warn "No strong ciphers detected"
    grep -qi "3des\|md5\|sha1" /etc/ipsec.conf && log_fail "Weak algorithms in ipsec.conf" || log_pass "No weak algorithms"
fi

# .gitignore has ipsec.secrets
if [ -f "$PROJECT_DIR/.gitignore" ]; then
    grep -q "ipsec.secrets" "$PROJECT_DIR/.gitignore" && log_pass "ipsec.secrets in .gitignore" || log_fail "ipsec.secrets not in .gitignore"
fi

# Certificate expiry
for cert in /etc/ipsec.d/certs/*.crt /etc/ipsec.d/certs/*.pem 2>/dev/null; do
    [ -f "$cert" ] || continue
    if command -v openssl &> /dev/null; then
        EXPIRY=$(openssl x509 -enddate -noout -in "$cert" 2>/dev/null | cut -d= -f2)
        [ -z "$EXPIRY" ] && continue
        EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y" "$EXPIRY" +%s 2>/dev/null)
        NOW=$(date +%s)
        DAYS=$(( (EXPIRY_EPOCH - NOW) / 86400 ))
        [ "$DAYS" -gt 30 ] && log_pass "Certificate $(basename "$cert") valid $DAYS days" || log_warn "Certificate $(basename "$cert") expires in $DAYS days"
    fi
done

# StrongSwan updates
if command -v apt-get &> /dev/null; then
    if apt list --upgradable 2>/dev/null | grep -q strongswan; then
        log_warn "StrongSwan updates available. Run: sudo apt update && sudo apt upgrade strongswan"
    else
        log_pass "StrongSwan up to date"
    fi
fi

echo ""
echo "Summary: Passed $PASSED, Warnings $WARNINGS, Issues $ISSUES"
[ $ISSUES -gt 0 ] && exit 1 || exit 0
