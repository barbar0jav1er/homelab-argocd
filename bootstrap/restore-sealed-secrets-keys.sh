#!/bin/bash

# SealedSecrets Key Restore Script
# This script restores SealedSecrets encryption keys to the Kubernetes cluster

set -euo pipefail

# Configuration
NAMESPACE="kube-system"
BACKUP_FILE="${1:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

show_help() {
    echo "SealedSecrets Key Restore Script"
    echo ""
    echo "Usage: $0 <backup-file> [OPTIONS]"
    echo ""
    echo "Arguments:"
    echo "  backup-file   Path to the backup YAML file containing the keys"
    echo ""
    echo "Options:"
    echo "  --force       Skip confirmation prompts"
    echo "  --help, -h    Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 ./sealed-secrets-backup/sealed-secrets-keys-20240129-143022.yaml"
    echo "  $0 ./sealed-secrets-backup/sealed-secrets-keys-latest.yaml --force"
    echo ""
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
    
    if [ -z "${BACKUP_FILE}" ]; then
        log_error "No backup file specified"
        show_help
        exit 1
    fi
    
    if [ ! -f "${BACKUP_FILE}" ]; then
        log_error "Backup file does not exist: ${BACKUP_FILE}"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

validate_backup_file() {
    log_info "Validating backup file..."
    
    # Check if file contains SealedSecrets keys
    if ! grep -q "sealedsecrets.bitnami.com/sealed-secrets-key" "${BACKUP_FILE}"; then
        log_error "Backup file does not contain SealedSecrets keys"
        exit 1
    fi
    
    # Count keys in backup
    local key_count=$(grep -c "name: sealed-secrets-key" "${BACKUP_FILE}" || echo "0")
    log_info "Found ${key_count} keys in backup file"
    
    if [ "${key_count}" -eq 0 ]; then
        log_error "No valid keys found in backup file"
        exit 1
    fi
}

check_existing_keys() {
    log_info "Checking for existing keys in cluster..."
    
    local existing_keys=$(kubectl get secret -n "${NAMESPACE}" -l sealedsecrets.bitnami.com/sealed-secrets-key --no-headers 2>/dev/null | wc -l)
    
    if [ "${existing_keys}" -gt 0 ]; then
        log_warn "Found ${existing_keys} existing SealedSecrets keys in the cluster"
        log_warn "Restoring will replace these keys"
        
        if [[ "${2:-}" != "--force" ]]; then
            echo ""
            read -p "Do you want to continue? [y/N]: " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Restore cancelled by user"
                exit 0
            fi
        fi
    else
        log_info "No existing keys found - this is a fresh restore"
    fi
}

backup_existing_keys() {
    local existing_keys=$(kubectl get secret -n "${NAMESPACE}" -l sealedsecrets.bitnami.com/sealed-secrets-key --no-headers 2>/dev/null | wc -l)
    
    if [ "${existing_keys}" -gt 0 ]; then
        log_step "Backing up existing keys before restore..."
        local backup_timestamp=$(date +"%Y%m%d-%H%M%S")
        local temp_backup="./sealed-secrets-backup/pre-restore-backup-${backup_timestamp}.yaml"
        
        mkdir -p ./sealed-secrets-backup
        kubectl get secret -n "${NAMESPACE}" -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > "${temp_backup}"
        log_info "Existing keys backed up to: ${temp_backup}"
    fi
}

delete_existing_keys() {
    log_step "Removing existing SealedSecrets keys..."
    
    if kubectl delete secret -n "${NAMESPACE}" -l sealedsecrets.bitnami.com/sealed-secrets-key 2>/dev/null; then
        log_info "Existing keys removed successfully"
    else
        log_info "No existing keys to remove"
    fi
}

restore_keys() {
    log_step "Restoring SealedSecrets keys from backup..."
    
    if kubectl apply -f "${BACKUP_FILE}"; then
        log_info "Keys restored successfully"
    else
        log_error "Failed to restore keys"
        exit 1
    fi
}

restart_controller() {
    log_step "Restarting SealedSecrets controller to pick up new keys..."
    
    # Check if controller exists
    if kubectl get deployment -n "${NAMESPACE}" sealed-secrets-controller &>/dev/null; then
        kubectl rollout restart deployment/sealed-secrets-controller -n "${NAMESPACE}"
        log_info "Waiting for controller to be ready..."
        kubectl rollout status deployment/sealed-secrets-controller -n "${NAMESPACE}" --timeout=60s
    elif kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/name=sealed-secrets &>/dev/null; then
        # If it's not a deployment, delete the pods to restart
        kubectl delete pods -n "${NAMESPACE}" -l app.kubernetes.io/name=sealed-secrets
        log_info "Controller pods deleted, waiting for restart..."
        sleep 10
    else
        log_warn "Could not find SealedSecrets controller to restart"
        log_warn "You may need to restart it manually"
    fi
}

verify_restore() {
    log_step "Verifying restore..."
    
    local restored_keys=$(kubectl get secret -n "${NAMESPACE}" -l sealedsecrets.bitnami.com/sealed-secrets-key --no-headers | wc -l)
    log_info "Found ${restored_keys} keys after restore"
    
    # Wait a bit for controller to be ready
    sleep 5
    
    # Check if controller is running
    if kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/name=sealed-secrets --no-headers | grep -q "Running"; then
        log_info "SealedSecrets controller is running"
    else
        log_warn "SealedSecrets controller may not be ready yet"
    fi
}

show_next_steps() {
    log_info ""
    log_info "✓ SealedSecrets keys restored successfully!"
    log_info ""
    log_info "Next steps:"
    log_info "1. Verify controller is working:"
    log_info "   kubectl get pods -n ${NAMESPACE} -l app.kubernetes.io/name=sealed-secrets"
    log_info ""
    log_info "2. Test with a sample secret:"
    log_info "   kubectl create secret generic test-secret --from-literal=test=value --dry-run=client -o yaml | kubeseal -o yaml"
    log_info ""
    log_info "3. Check controller logs if needed:"
    log_info "   kubectl logs -n ${NAMESPACE} -l app.kubernetes.io/name=sealed-secrets"
}

main() {
    log_info "Starting SealedSecrets key restore..."
    log_info "Backup file: ${BACKUP_FILE}"
    
    check_prerequisites
    validate_backup_file
    check_existing_keys "$@"
    backup_existing_keys
    delete_existing_keys
    restore_keys
    restart_controller
    verify_restore
    show_next_steps
}

# Handle script interruption
trap 'log_error "Script interrupted"; exit 1' INT TERM

# Show help
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    show_help
    exit 0
fi

main "$@"