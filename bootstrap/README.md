# Bootstrap Scripts

This directory contains scripts to help with cluster bootstrap and maintenance operations.

## SealedSecrets Key Management

### backup-sealed-secrets-keys.sh

Backs up SealedSecrets encryption keys from the cluster to prevent data loss.

**Usage:**
```bash
# Basic backup
./bootstrap/backup-sealed-secrets-keys.sh

# Custom backup directory
BACKUP_DIR=/path/to/secure/backup ./bootstrap/backup-sealed-secrets-keys.sh

# Show help
./bootstrap/backup-sealed-secrets-keys.sh --help
```

**Features:**
- Creates timestamped backups
- Validates cluster connectivity
- Checks controller status
- Creates symlink to latest backup
- Provides verification commands

### restore-sealed-secrets-keys.sh

Restores SealedSecrets encryption keys to recover cluster secret decryption capabilities.

**Usage:**
```bash
# Interactive restore
./bootstrap/restore-sealed-secrets-keys.sh /path/to/backup.yaml

# Force restore (skip confirmations)
./bootstrap/restore-sealed-secrets-keys.sh /path/to/backup.yaml --force

# Show help
./bootstrap/restore-sealed-secrets-keys.sh --help
```

**Features:**
- Validates backup file integrity
- Backs up existing keys before restore
- Safely replaces keys
- Restarts controller automatically
- Verifies restore completion

## Security Considerations

1. **Backup Storage**: Store key backups in a secure location outside the cluster
2. **Access Control**: Limit access to backup files - they contain encryption keys
3. **Regular Backups**: Run backups regularly, especially before cluster maintenance
4. **Test Restores**: Periodically test restore procedures in non-production environments

## Automation

Consider integrating these scripts into your CI/CD pipeline or cluster maintenance procedures:

```bash
# Example: Weekly backup cron job
0 2 * * 0 /path/to/homelab-argocd/bootstrap/backup-sealed-secrets-keys.sh

# Example: Pre-maintenance backup
./bootstrap/backup-sealed-secrets-keys.sh && echo "Keys backed up, proceeding with maintenance"
```