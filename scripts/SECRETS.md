# Secrets Management for StrongSwan

Production options for managing StrongSwan secrets (native Ubuntu).

## HashiCorp Vault

1. Store secret: `vault kv put secret/strongswan/ipsec_secrets @/path/to/ipsec.secrets`
2. Use Vault Agent to render to `/etc/ipsec.secrets` (chmod 600), then run `ipsec reload`.

## AWS Secrets Manager

1. Store: `aws secretsmanager create-secret --name strongswan/ipsec-secrets --secret-string file://ipsec.secrets`
2. Use cron or systemd timer to fetch and write to `/etc/ipsec.secrets`, then `ipsec reload`. Ensure file is chmod 600.

## Best Practices

- Never commit secrets to version control.
- Use encryption at rest and in transit.
- Rotate secrets regularly.
- Use least privilege and audit access.

## Migration from plain text

1. Backup current `/etc/ipsec.secrets`.
2. Choose a secret manager (Vault, AWS, etc.).
3. Store secrets there.
4. Deploy mechanism to write to `/etc/ipsec.secrets` and run `ipsec reload`.
5. Test; remove or restrict plain-text copies.
