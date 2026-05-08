#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# X15 NixOS Optimization Workflow
# ═══════════════════════════════════════════════════════════════════════════════
# Comprehensive system optimization, validation, and monitoring deployment
# For Colorful X15 XS with Intel i5-12500H + NVIDIA RTX 3050 Ti
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Configuration
readonly VERSION="1.1.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly NIXOS_DIR="/etc/nixos"
readonly LOG_FILE="/tmp/x15-optimization-$(date +%Y%m%d_%H%M%S).log"
readonly BACKUP_DIR="/etc/nixos/.backup/$(date +%Y%m%d_%H%M%S)"
readonly FLAKE_TARGET="/etc/nixos#x15xs"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Global flags
DRY_RUN=0
VERBOSE=0
SKIP_TESTS=0
PROFILE="balanced"

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

log() {
    echo -e "${GREEN}[OPTIMIZE]${NC} $*" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE" >&2
}

section() {
    echo "" | tee -a "$LOG_FILE"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}${BOLD}  $*${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}" | tee -a "$LOG_FILE"
}

step() {
    echo -e "${BLUE}  → $*${NC}" | tee -a "$LOG_FILE"
}

dryrun() {
    if [ $DRY_RUN -eq 1 ]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would: $*" | tee -a "$LOG_FILE"
        return 0
    fi
    log "Executing: $*"
    eval "$@"
}

run_logged() {
    local label="$1"
    shift

    step "$label"
    if "$@" 2>&1 | tee -a "$LOG_FILE"; then
        checkpoint "$label"
    else
        error "$label failed"
        return 1
    fi
}

checkpoint() {
    local name="$1"
    local status="${2:-PASS}"
    
    if [ "$status" = "PASS" ]; then
        echo -e "    ${GREEN}[✓]${NC} $name" | tee -a "$LOG_FILE"
    else
        echo -e "    ${RED}[✗]${NC} $name" | tee -a "$LOG_FILE"
        return 1
    fi
}

confirm() {
    if [ $DRY_RUN -eq 1 ]; then
        return 0
    fi
    echo -e "${YELLOW}$* [y/N]${NC}"
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════════════
# VALIDATION FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

validate_environment() {
    section "Environment Validation"
    
    # Check if running on NixOS
    if [ ! -f /etc/NIXOS ]; then
        error "Not running on NixOS. This script is NixOS-specific."
        return 1
    fi
    checkpoint "NixOS detected"
    
    # Check root privileges
    if [ "$EUID" -ne 0 ] && [ $DRY_RUN -eq 0 ]; then
        warn "Script not running as root. Some operations may fail."
    fi
    checkpoint "Root check"
    
    # Check NixOS configuration directory
    if [ ! -d "$NIXOS_DIR" ]; then
        error "NixOS configuration directory not found: $NIXOS_DIR"
        return 1
    fi
    checkpoint "NixOS config directory"
    
    # Check available disk space
    local available=$(df / | awk 'NR==2{print $4}')
    if [ $available -lt 524288 ]; then  # 512MB
        error "Insufficient disk space ($(($available/1024))MB available)"
        return 1
    fi
    checkpoint "Disk space sufficient"
    
    # Check hardware compatibility
    local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
    info "Detected CPU: $cpu_model"
    
    # Check for NVIDIA GPU
    if lspci | grep -qi nvidia; then
        info "NVIDIA GPU detected"
        checkpoint "NVIDIA GPU detected"
    fi
    
    return 0
}

validate_backup() {
    section "Backup Validation"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        info "Creating backup directory..."
        mkdir -p "$BACKUP_DIR/source"
    fi
    
    # Create backup of current configuration
    info "Creating configuration backup..."
    if [ $DRY_RUN -eq 0 ]; then
        tar \
            --exclude='.backup' \
            --exclude='.git' \
            -C "$NIXOS_DIR" \
            -cf - . | tar -C "$BACKUP_DIR/source" -xf -
        log "Backup saved to: $BACKUP_DIR"
    else
        log "Would create backup at: $BACKUP_DIR"
    fi
    checkpoint "Backup created"
    
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# OPTIMIZATION PHASES
# ═══════════════════════════════════════════════════════════════════════════════

phase_kernel_optimization() {
    section "Phase 1: Kernel Optimization"
    
    step "Configuring kernel parameters..."
    
    # The configuration is handled by the NixOS module
    # This phase validates the configuration can be applied
    
    if [ -f "$NIXOS_DIR/modules/performance/default.nix" ]; then
        info "Performance module found"
        checkpoint "Performance module present"
    else
        warn "Performance modules not found"
        return 1
    fi

    if grep -q "linuxPackages_latest" "$NIXOS_DIR/modules/core/boot.nix"; then
        checkpoint "Latest kernel package path configured"
    else
        warn "Latest kernel package path not found in boot module"
    fi
    
    # Validate kernel parameters
    info "Validating kernel configuration..."
    local required_params=("preempt=full" "threadirqs" "skew_tick=1")
    for param in "${required_params[@]}"; do
        if grep -q "$param" "$NIXOS_DIR/modules/performance/default.nix"; then
            checkpoint "Kernel param: $param"
        else
            warn "Kernel param not found: $param"
        fi
    done
    
    return 0
}

phase_hardware_monitoring() {
    section "Phase 2: Hardware Monitoring Setup"
    
    step "Validating sensor detection..."
    
    # Check lm-sensors
    if command -v sensors &>/dev/null; then
        info "lm-sensors is available"
        checkpoint "lm-sensors available"
    else
        warn "lm-sensors not installed"
    fi
    
    # Check for thermal zones
    local thermal_zones=$(find /sys/class/thermal -name "thermal_zone*" 2>/dev/null | wc -l)
    info "Detected $thermal_zones thermal zones"
    if [ $thermal_zones -gt 0 ]; then
        checkpoint "Thermal zones detected"
    fi
    
    # Check for hwmon devices
    local hwmon_count=$(find /sys/class/hwmon -name "hwmon*" 2>/dev/null | wc -l)
    info "Detected $hwmon_count hwmon devices"
    
    # Validate NBFC if using
    if [ -f "/etc/nbfc/nbfc.json" ]; then
        info "NBFC configuration found"
        checkpoint "NBFC configured"
    fi
    
    step "Testing fan control..."
    if command -v x15-fan-validate &>/dev/null; then
        info "Fan validator available"
        checkpoint "Fan validator available"
    else
        warn "Fan validator not in PATH"
    fi
    
    return 0
}

phase_quickshell_integration() {
    section "Phase 3: Quickshell Integration"
    
    step "Validating Quickshell configuration..."
    
    if [ -f "$NIXOS_DIR/home/desktop/quickshell/profiles/end4/ii/services/ResourceService.qml" ]; then
        info "ResourceService override present"
        checkpoint "ResourceService present"
    else
        warn "ResourceService override missing"
    fi
    
    if [ -f "$NIXOS_DIR/home/desktop/quickshell/profiles/end4/ii/modules/ii/bar/Resources.qml" ] && \
       [ -f "$NIXOS_DIR/home/desktop/quickshell/profiles/end4/ii/modules/ii/bar/ResourcesPopup.qml" ]; then
        info "Resources bar files present"
        checkpoint "Resources overrides present"
    else
        warn "Resources bar overrides missing"
    fi
    
    # Validate data directory
    local data_dir="${XDG_RUNTIME_DIR:-/tmp}/x15-hwmon"
    if [ -d "$data_dir" ]; then
        info "Hardware monitoring data directory exists"
        checkpoint "Data directory exists"
    else
        info "Data directory will be created on first run"
    fi
    
    return 0
}

phase_display_sessions() {
    section "Phase 4: Display Sessions"

    step "Validating greetd, Hyprland, and i3 session wiring..."

    if grep -q "uwsm start -e -D Hyprland hyprland.desktop" "$NIXOS_DIR/hosts/x15xs/default.nix"; then
        checkpoint "Hyprland UWSM launcher configured"
    else
        warn "Hyprland UWSM launcher not found"
    fi

    if grep -q -- "--sessions" "$NIXOS_DIR/hosts/x15xs/default.nix" && \
       grep -q -- "--xsessions" "$NIXOS_DIR/hosts/x15xs/default.nix"; then
        checkpoint "greetd session chooser configured"
    else
        warn "greetd session chooser flags missing"
    fi

    if [ -f "$NIXOS_DIR/modules/desktop/i3-session.nix" ] && [ -f "$NIXOS_DIR/home/desktop/i3/config" ]; then
        info "i3 fallback session files present"
        checkpoint "i3 session present"
    else
        warn "i3 fallback session files missing"
    fi

    return 0
}

phase_system_cleanup() {
    section "Phase 5: System Cleanup"
    
    step "Running system audit..."
    
    if command -v x15-system-audit &>/dev/null; then
        info "System audit tool available"
        checkpoint "Audit tool available"
        
        if [ $DRY_RUN -eq 0 ] && confirm "Run system audit now?"; then
            x15-system-audit
        fi
    else
        warn "System audit tool not available"
    fi
    
    step "Analyzing cleanup opportunities..."
    
    # Check Nix store size
    local nix_size=$(du -sm /nix/store 2>/dev/null | cut -f1)
    info "Nix store size: ${nix_size}MB"
    if [ $nix_size -gt 10000 ]; then  # 10GB
        warn "Nix store is larger than 10GB, consider garbage collection"
    fi
    
    # Check journal size
    local journal_size=$(journalctl --disk-usage 2>/dev/null | grep -oP '\d+\.?\d*[KMGT]iB' | head -1)
    if [ -n "$journal_size" ]; then
        info "Journal size: $journal_size"
    fi
    
    checkpoint "Cleanup analysis complete"
    
    return 0
}

phase_dry_build_validation() {
    section "Phase 6: Dry Build Validation"

    run_logged "Workflow script shell syntax" bash -n "$SCRIPT_DIR/x15-optimize-workflow.sh" || return 1
    run_logged "Kernel dry-build" bash -lc "cd '$NIXOS_DIR' && nix build .#nixosConfigurations.x15xs.config.system.build.kernel --dry-run --show-trace" || return 1
    run_logged "NixOS toplevel dry-build" bash -lc "cd '$NIXOS_DIR' && nix build .#nixosConfigurations.x15xs.config.system.build.toplevel --dry-run --show-trace" || return 1

    if [ -f "$NIXOS_DIR/tests/test_migration.py" ]; then
        if command -v pytest >/dev/null 2>&1; then
            run_logged "Pytest structural checks" bash -lc "cd '$NIXOS_DIR' && pytest -q tests/test_migration.py" || return 1
        else
            run_logged \
                "Pytest structural checks (ephemeral nix shell)" \
                bash -lc "cd '$NIXOS_DIR' && nix-shell -p python3Packages.pytest python3Packages.hypothesis --run 'pytest -q tests/test_migration.py'" || return 1
        fi
    else
        warn "tests/test_migration.py missing"
    fi

    return 0
}

phase_nixos_rebuild() {
    section "Phase 7: NixOS Rebuild"
    
    if [ $DRY_RUN -eq 1 ]; then
        info "Dry-run mode: Skipping rebuild"
        return 0
    fi
    
    if ! confirm "Rebuild NixOS configuration with optimizations?"; then
        info "Skipping rebuild"
        return 0
    fi
    
    step "Running nixos-rebuild switch..."
    
    # Build and switch
    if nixos-rebuild switch --flake "$FLAKE_TARGET" 2>&1 | tee -a "$LOG_FILE"; then
        log "Rebuild successful"
        checkpoint "NixOS rebuild successful"
    else
        error "Rebuild failed"
        return 1
    fi
    
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# TEST FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

run_benchmarks() {
    section "Performance Benchmarks"
    
    if [ $SKIP_TESTS -eq 1 ]; then
        info "Skipping benchmarks"
        return 0
    fi
    
    if command -v x15-performance-benchmark &>/dev/null; then
        info "Running performance benchmarks..."
        x15-performance-benchmark
    else
        warn "Benchmark tool not available"
    fi
    
    return 0
}

run_thermal_validation() {
    section "Thermal Validation"
    
    if [ $SKIP_TESTS -eq 1 ]; then
        info "Skipping thermal validation"
        return 0
    fi
    
    if command -v x15-thermal-validation &>/dev/null; then
        if confirm "Run 5-minute thermal stress test?"; then
            x15-thermal-validation 300
        fi
    else
        warn "Thermal validator not available"
    fi
    
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN WORKFLOW
# ═══════════════════════════════════════════════════════════════════════════════

show_help() {
    cat << EOF
X15 NixOS Optimization Workflow v${VERSION}

Usage: $0 [OPTIONS] [COMMAND]

Commands:
  full           Run complete optimization workflow (default)
  kernel         Kernel optimization only
  monitor        Hardware monitoring setup only
  quickshell     Quickshell integration only
  sessions       Display manager / window manager validation only
  cleanup        System cleanup only
  dry-build      Run the dry build / validation pipeline
  rebuild        NixOS rebuild only
  test           Run validation tests only
  status         Show system status
  help           Show this help message

Options:
  -n, --dry-run  Show what would be done without executing
  -v, --verbose  Enable verbose output
  -s, --skip-tests  Skip benchmark and validation tests
  -p, --profile  Set performance profile (max|balanced|cool)

Environment Variables:
  DRY_RUN=1      Equivalent to --dry-run
  VERBOSE=1      Enable verbose output
  SKIP_TESTS=1   Skip tests
  PROFILE        Performance profile setting

Examples:
  $0                    # Full optimization
  $0 --dry-run          # Preview changes
  $0 kernel --profile=max  # Kernel optimization with max profile
  $0 test               # Run validation tests

EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--dry-run)
                DRY_RUN=1
                shift
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -s|--skip-tests)
                SKIP_TESTS=1
                shift
                ;;
            -p|--profile)
                PROFILE="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            full|kernel|monitor|quickshell|sessions|cleanup|dry-build|rebuild|test|status)
                COMMAND="$1"
                shift
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Set default command
    COMMAND="${COMMAND:-full}"
}

main() {
    parse_args "$@"
    
    # Initialize log
    touch "$LOG_FILE"
    
    # Header
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║     X15 NixOS Optimization Workflow v${VERSION}               ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo "Log file: $LOG_FILE"
    echo "Profile: $PROFILE"
    if [ $DRY_RUN -eq 1 ]; then
        echo -e "${YELLOW}Mode: DRY RUN${NC}"
    fi
    echo ""
    
    # Execute based on command
    case $COMMAND in
        full)
            validate_environment || exit 1
            validate_backup || exit 1
            phase_kernel_optimization || true
            phase_hardware_monitoring || true
            phase_quickshell_integration || true
            phase_display_sessions || true
            phase_system_cleanup || true
            phase_dry_build_validation || exit 1
            phase_nixos_rebuild || exit 1
            run_benchmarks || true
            run_thermal_validation || true
            ;;
        kernel)
            validate_environment || exit 1
            phase_kernel_optimization || exit 1
            ;;
        monitor)
            validate_environment || exit 1
            phase_hardware_monitoring || exit 1
            ;;
        quickshell)
            validate_environment || exit 1
            phase_quickshell_integration || exit 1
            ;;
        sessions)
            validate_environment || exit 1
            phase_display_sessions || exit 1
            ;;
        cleanup)
            validate_environment || exit 1
            phase_system_cleanup || exit 1
            ;;
        dry-build)
            validate_environment || exit 1
            phase_dry_build_validation || exit 1
            ;;
        rebuild)
            validate_environment || exit 1
            validate_backup || exit 1
            phase_nixos_rebuild || exit 1
            ;;
        test)
            validate_environment || exit 1
            phase_dry_build_validation || exit 1
            run_benchmarks || true
            run_thermal_validation || true
            ;;
        status)
            section "System Status"
            info "Kernel: $(uname -r)"
            info "Uptime: $(uptime -p)"
            info "Profile: $PROFILE"
            echo ""
            df -h /
            echo ""
            free -h
            ;;
    esac
    
    # Summary
    section "Workflow Complete"
    log "Optimization workflow completed successfully"
    log "Log saved to: $LOG_FILE"
    
    if [ $DRY_RUN -eq 1 ]; then
        echo ""
        echo -e "${YELLOW}This was a dry run. No changes were made.${NC}"
        echo "Run without --dry-run to apply changes."
    fi
}

# Run main function
main "$@"
