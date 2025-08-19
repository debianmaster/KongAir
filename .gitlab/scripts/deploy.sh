#!/bin/bash

# KongAir GitLab CI/CD Deployment Script
# This script handles Kong Gateway deployments to different environments

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
KONG_CONFIG_DIR="$PROJECT_ROOT/platform/kong"
PRD_CONFIG_DIR="$PROJECT_ROOT/PRD/kong"

# Default values
ENVIRONMENT="staging"
KONNECT_TOKEN=""
RUNTIME_GROUP=""
DRY_RUN=false
VERBOSE=false

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy Kong Gateway configurations to specified environment.

OPTIONS:
    -e, --environment ENV    Environment to deploy to (staging, production)
    -t, --token TOKEN        Kong Konnect Personal Access Token
    -g, --runtime-group GRP  Kong Konnect Runtime Group name
    -d, --dry-run           Perform dry-run deployment (no actual changes)
    -v, --verbose           Enable verbose output
    -h, --help              Show this help message

EXAMPLES:
    # Deploy to staging with dry-run
    $0 -e staging -t \$KONNECT_PAT -g KongAir-Staging -d

    # Deploy to production
    $0 -e production -t \$KONNECT_PAT -g KongAir-PRD

ENVIRONMENT VARIABLES:
    KONNECT_PAT             Kong Konnect Personal Access Token
    KONNECT_RUNTIME_GROUP  Kong Konnect Runtime Group name

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -t|--token)
            KONNECT_TOKEN="$2"
            shift 2
            ;;
        -g|--runtime-group)
            RUNTIME_GROUP="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(staging|production)$ ]]; then
    log_error "Invalid environment: $ENVIRONMENT. Must be 'staging' or 'production'"
    exit 1
fi

# Set default runtime group if not specified
if [[ -z "$RUNTIME_GROUP" ]]; then
    case "$ENVIRONMENT" in
        staging)
            RUNTIME_GROUP="${KONNECT_RUNTIME_GROUP:-KongAir-Staging}"
            ;;
        production)
            RUNTIME_GROUP="${KONNECT_RUNTIME_GROUP:-KongAir-PRD}"
            ;;
    esac
fi

# Get Kong Konnect token
if [[ -z "$KONNECT_TOKEN" ]]; then
    KONNECT_TOKEN="${KONNECT_PAT:-}"
    if [[ -z "$KONNECT_TOKEN" ]]; then
        log_error "Kong Konnect token not provided. Use -t option or set KONNECT_PAT environment variable."
        exit 1
    fi
fi

# Validate required tools
check_requirements() {
    log_info "Checking deployment requirements..."
    
    if ! command -v deck &> /dev/null; then
        log_error "Kong Deck CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v git &> /dev/null; then
        log_error "Git is not installed. Please install it first."
        exit 1
    fi
    
    log_success "All requirements satisfied"
}

# Validate Kong configuration
validate_config() {
    local config_file="$1"
    
    log_info "Validating Kong configuration: $config_file"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        exit 1
    fi
    
    if ! deck validate -s "$config_file"; then
        log_error "Kong configuration validation failed"
        exit 1
    fi
    
    log_success "Configuration validation passed"
}

# Perform deployment
deploy() {
    local config_file="$1"
    local runtime_group="$2"
    local token="$3"
    local dry_run="$4"
    
    log_info "Starting deployment to $ENVIRONMENT environment"
    log_info "Runtime Group: $runtime_group"
    log_info "Configuration: $config_file"
    
    if [[ "$dry_run" == "true" ]]; then
        log_warning "DRY RUN MODE - No actual changes will be made"
        log_info "Performing dry-run deployment..."
        
        if deck diff --select-tag platform-repo-managed \
            -s "$config_file" \
            --konnect-runtime-group-name "$runtime_group" \
            --konnect-token "$token"; then
            log_success "Dry-run deployment completed successfully"
        else
            log_warning "Dry-run deployment completed with differences"
        fi
    else
        log_info "Performing actual deployment..."
        
        if deck sync --select-tag platform-repo-managed \
            -s "$config_file" \
            --konnect-runtime-group-name "$runtime_group" \
            --konnect-token "$token"; then
            log_success "Deployment completed successfully"
        else
            log_error "Deployment failed"
            exit 1
        fi
    fi
}

# Main deployment logic
main() {
    log_info "Starting KongAir deployment process"
    log_info "Environment: $ENVIRONMENT"
    log_info "Runtime Group: $RUNTIME_GROUP"
    log_info "Dry Run: $DRY_RUN"
    
    # Check requirements
    check_requirements
    
    # Determine configuration file based on environment
    local config_file
    case "$ENVIRONMENT" in
        staging)
            config_file="$KONG_CONFIG_DIR/.generated/kong.yaml"
            ;;
        production)
            config_file="$PRD_CONFIG_DIR/kong.yaml"
            ;;
    esac
    
    # Validate configuration
    validate_config "$config_file"
    
    # Perform deployment
    deploy "$config_file" "$RUNTIME_GROUP" "$KONNECT_TOKEN" "$DRY_RUN"
    
    log_success "Deployment process completed successfully"
}

# Handle script errors
trap 'log_error "Script failed at line $LINENO"' ERR

# Run main function
main "$@"
