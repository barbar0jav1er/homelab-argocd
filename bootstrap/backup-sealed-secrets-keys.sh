#!/bin/bash

# SealedSecrets Key Backup Script
# This script backs up the SealedSecrets encryption keys from the Kubernetes cluster

set -euo pipefail

# Configuration
NAMESPACE="kube-system"
BACKUP_DIR="${BACKUP_DIR:-./sealed-secrets-backup}"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/sealed-secrets-keys-${TIMESTAMP}.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

check_sealed_secrets_controller() {
    log_info "Checking if SealedSecrets controller is running..."
    
    if ! kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/name=sealed-secrets --no-headers | grep -q "Running"; then
        log_error "SealedSecrets controller is not running in namespace ${NAMESPACE}"
        log_info "Make sure the controller is deployed before backing up keys"
        exit 1
    fi
    
    log_info "SealedSecrets controller is running"
}

backup_keys() {
    log_info "Creating backup directory: ${BACKUP_DIR}"
    mkdir -p "${BACKUP_DIR}"
    
    log_info "Backing up SealedSecrets keys..."
    
    # Get all sealed-secrets keys
    if kubectl get secret -n "${NAMESPACE}" -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > "${BACKUP_FILE}"; then
        log_info "Keys backed up successfully to: ${BACKUP_FILE}"
        
        # Show backup file info
        local file_size=$(du -h "${BACKUP_FILE}" | cut -f1)
        local key_count=$(kubectl get secret -n "${NAMESPACE}" -l sealedsecrets.bitnami.com/sealed-secrets-key --no-headers | wc -l)
        
        log_info "Backup summary:"
        log_info "  - File: ${BACKUP_FILE}"
        log_info "  - Size: ${file_size}"
        log_info "  - Keys: ${key_count}"
        
    else
        log_error "Failed to backup keys"
        exit 1
    fi
}

create_latest_symlink() {
    local latest_link="${BACKUP_DIR}/sealed-secrets-keys-latest.yaml"
    
    log_info "Creating latest backup symlink..."
    ln -sf "$(basename "${BACKUP_FILE}")" "${latest_link}"
    log_info "Latest backup available at: ${latest_link}"
}

show_verification_command() {
    log_info ""
    log_info "To verify the backup, you can check the keys with:"
    log_info "  kubectl get secret -n ${NAMESPACE} -l sealedsecrets.bitnami.com/sealed-secrets-key"
    log_info ""
    log_info "To restore these keys later, use the companion restore script:"
    log_info "  ./bootstrap/restore-sealed-secrets-keys.sh ${BACKUP_FILE}"
}

main() {
    log_info "Starting SealedSecrets key backup..."
    log_info "Timestamp: ${TIMESTAMP}"
    
    check_prerequisites
    check_sealed_secrets_controller
    backup_keys
    create_latest_symlink
    show_verification_command
    
    log_info ""
    log_info "✓ SealedSecrets key backup completed successfully!"
    log_warn "⚠ Store this backup file securely - it contains encryption keys!"
}

# Handle script interruption
trap 'log_error "Script interrupted"; exit 1' INT TERM

# Show help
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "SealedSecrets Key Backup Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Environment Variables:"
    echo "  BACKUP_DIR    Directory to store backups (default: ./sealed-secrets-backup)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Backup with default settings"
    echo "  BACKUP_DIR=/secure/backup $0          # Backup to custom directory"
    echo ""
    exit 0
fi

main "$@"