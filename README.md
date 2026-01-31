# StrongSwan IPsec VPN (Ubuntu)

Production-ready StrongSwan IPsec VPN server on Ubuntu. Single install from repo root.

## Prerequisites

- Ubuntu 22.04 LTS or 24.04 LTS (20.04 supported)
- Root or sudo access

## Quick Start

```bash
sudo ./install.sh              # Install StrongSwan, deploy config, start services
sudo ./install.sh --firewall   # Also configure UFW for IKE, NAT-T, ESP
```

Config is copied from `config/` to `/etc/`. You must create or edit `/etc/ipsec.secrets` and add certificates under `/etc/ipsec.d/`.

### Remove and reinstall

```bash
sudo ./uninstall.sh              # Remove config only; packages stay
sudo ./uninstall.sh --purge     # Remove config and purge packages
sudo ./install.sh               # Reinstall / redeploy
```

## Directory Structure

```
.
├── README.md
├── .gitignore
├── install.sh
├── uninstall.sh
├── config/
│   ├── ipsec.conf
│   ├── ipsec.secrets.example
│   ├── strongswan.conf
│   └── charon-logging.conf
└── scripts/
    ├── backup-etc.sh
    ├── firewall.sh
    ├── logrotate-strongswan
    ├── security-audit.sh
    └── SECRETS.md
```

## Configuration

### 1. ipsec.secrets

If the installer created `/etc/ipsec.secrets` from the example, edit it and add your private key reference and optional EAP users:

```bash
sudo nano /etc/ipsec.secrets
sudo chmod 600 /etc/ipsec.secrets
```

### 2. Certificates

Place server cert, private key, and CA certs under `/etc/ipsec.d/`:

```bash
sudo cp your-server.crt /etc/ipsec.d/certs/
sudo cp your-server.key /etc/ipsec.d/private/
sudo cp your-ca.crt /etc/ipsec.d/cacerts/
sudo chmod 600 /etc/ipsec.d/private/*.key
```

#### Generating the server key and certificate

If you don’t have a server cert yet, generate the private key and certificate with OpenSSL. Use a FQDN that matches `leftid` in `ipsec.conf` (e.g. `vpn-strongswan.bongloy.asia`).

**1. Generate the private key** (`vpn-server.key`):

```bash
openssl genrsa -out vpn-server.key 4096
chmod 600 vpn-server.key
```

**2a. Get a cert from your CA** (recommended for production): create a CSR and submit it to your CA:

```bash
openssl req -new -key vpn-server.key -out vpn-server.csr -subj "/CN=vpn-strongswan.bongloy.asia"
```

**2b. Or self-sign** (testing or internal use):

```bash
openssl req -x509 -key vpn-server.key -out vpn-server.crt -days 3650 -subj "/CN=vpn-strongswan.bongloy.asia"
```

**3. Deploy** on the server: copy `vpn-server.key` to `/etc/ipsec.d/private/`, `vpn-server.crt` to `/etc/ipsec.d/certs/`, and any CA cert to `/etc/ipsec.d/cacerts/`. In `ipsec.secrets` use `: RSA vpn-server.key`; in `ipsec.conf` use `leftcert=vpn-server.crt` and `leftid=@vpn-strongswan.bongloy.asia`.

### 3. ipsec.conf

Update identities and subnets for your environment:

```bash
sudo nano /etc/ipsec.conf
# Set leftid=@vpn-strongswan.bongloy.asia, rightsourceip, rightdns, etc.
```

### 4. Reload

```bash
sudo ipsec reload
```

## Troubleshooting

- Logs: `sudo journalctl -u strongswan-starter -f` or `sudo tail -f /var/log/strongswan/charon.log`
- Status: `sudo ipsec statusall` and `sudo ipsec status`
- Service (Ubuntu): `systemctl status strongswan-starter`

## Production

Run these from the repo root.

### Backup

```bash
sudo ./scripts/backup-etc.sh
export BACKUP_RETENTION_DAYS=30
sudo ./scripts/backup-etc.sh
```

Cron example (daily): `0 2 * * * /path/to/strongswan/scripts/backup-etc.sh`

### Log rotation

Installer copies `scripts/logrotate-strongswan` to `/etc/logrotate.d/strongswan`. Main logs 30 days, error 90 days.

### Firewall

```bash
sudo ./scripts/firewall.sh
# Set VPN_CLIENT_POOL and VPN_INTERFACE if needed
```

### Security audit and updates

```bash
./scripts/security-audit.sh
sudo apt update && sudo apt upgrade strongswan
```

### Secrets management

See `scripts/SECRETS.md` for Vault, AWS Secrets Manager, and migration from plain text.

## Production checklist

- [ ] `/etc/ipsec.secrets` created and chmod 600
- [ ] Certificates in `/etc/ipsec.d/certs`, `private`, `cacerts`
- [ ] Backup and log rotation configured
- [ ] Firewall rules applied
- [ ] Security audit passed
- [ ] Secrets management in place (production)
