# StrongSwan IPsec VPN (Ubuntu)

Production-ready StrongSwan IPsec VPN server on Ubuntu. Native installation using official packages and systemd.

## Prerequisites

- Ubuntu 22.04 LTS or 24.04 LTS (20.04 supported)
- Root or sudo access

## Quick Start

```bash
cd ubuntu
sudo ./install.sh              # Install StrongSwan, deploy config, start services
sudo ./install.sh --firewall   # Also configure UFW for IKE/NAT-T/ESP
```

See **[ubuntu/README.md](ubuntu/README.md)** for full instructions. Config is copied from `config/` to `/etc/`. You must create `/etc/ipsec.secrets` and add certificates under `/etc/ipsec.d/`.

## Configuration

### Directory Structure

```
.
├── config/
│   ├── ipsec.conf
│   ├── ipsec.secrets.example
│   ├── strongswan.conf
│   └── charon-logging.conf
├── ubuntu/
│   ├── README.md
│   ├── install.sh
│   ├── logrotate-strongswan
│   └── scripts/
│       ├── backup-etc.sh
│       └── firewall.sh
├── scripts/
│   ├── security-audit.sh
│   └── secrets-management.md
├── README.md
└── .gitignore
```

### Important Notes

- **Secrets**: Keep `ipsec.secrets` secure (chmod 600).
- **Certificates**: Place in `/etc/ipsec.d/certs`, `private`, `cacerts` after install; ensure correct permissions on private keys (600).

## Security Considerations

1. **Secrets Management**: Use external secret management (Vault, AWS Secrets Manager) in production; see `scripts/secrets-management.md`.
2. **Certificate Rotation**: Implement automated certificate rotation.
3. **Firewall Rules**: Run `sudo ./ubuntu/scripts/firewall.sh` or configure UFW/iptables for UDP 500, 4500, ESP, AH.
4. **Logging**: Monitor `/var/log/strongswan/` for suspicious activity.
5. **Updates**: Run `sudo apt update && sudo apt upgrade strongswan` regularly.

## Troubleshooting

- Check logs: `sudo journalctl -u strongswan -f` or `sudo tail -f /var/log/strongswan/charon.log`
- Verify configuration: `sudo ipsec statusall`
- Test connectivity: `sudo ipsec status`

## Production Deployment

### 1. Backup

Back up `/etc` StrongSwan config:

```bash
sudo ./ubuntu/scripts/backup-etc.sh
export BACKUP_RETENTION_DAYS=30
sudo ./ubuntu/scripts/backup-etc.sh
```

Cron example (daily): `0 2 * * * /path/to/strongswan/ubuntu/scripts/backup-etc.sh`

### 2. Log Rotation

Installer copies `ubuntu/logrotate-strongswan` to `/etc/logrotate.d/strongswan`. Main logs 30 days, error 90 days, debug 7 days.

### 3. Secrets Management

See `scripts/secrets-management.md` for HashiCorp Vault, AWS Secrets Manager, and migration guidance.

### 4. Firewall

```bash
sudo ./ubuntu/scripts/firewall.sh
# Set VPN_CLIENT_POOL and VPN_INTERFACE if needed
```

### 5. Security Audit and Updates

```bash
./scripts/security-audit.sh
sudo apt update && sudo apt upgrade strongswan
```

### Production Checklist

- [ ] `/etc/ipsec.secrets` created and chmod 600
- [ ] Certificates in `/etc/ipsec.d/`
- [ ] Backup and log rotation configured
- [ ] Firewall rules applied
- [ ] Security audit passed
- [ ] Secrets management in place (production)
# strongswan
