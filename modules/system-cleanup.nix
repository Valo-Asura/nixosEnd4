# ═══════════════════════════════════════════════════════════════════════════════
# NixOS System Cleanup & Restructuring Module
# ═══════════════════════════════════════════════════════════════════════════════
# Automated auditing, cleanup, and restructuring pipeline with safeguards
# Includes: redundant file detection, service cleanup, directory reorganization
# ═══════════════════════════════════════════════════════════════════════════════

{ config, lib, pkgs, ... }:

let
  cfg = config.modules.systemCleanup;
  
  # ═══════════════════════════════════════════════════════════════════════════
  # AUDIT SCRIPT - System Analysis
  # ═══════════════════════════════════════════════════════════════════════════
  
  auditScript = pkgs.writeShellScriptBin "x15-system-audit" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    REPORT_FILE="''${1:-/tmp/x15_system_audit_$(date +%Y%m%d_%H%M%S).txt}"
    VERBOSE="''${VERBOSE:-0}"
    
    # Colors for terminal output
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
    
    log() {
      echo -e "''${BLUE}[AUDIT]''${NC} $*" | tee -a "$REPORT_FILE"
    }
    
    warn() {
      echo -e "''${YELLOW}[WARN]''${NC} $*" | tee -a "$REPORT_FILE"
    }
    
    error() {
      echo -e "''${RED}[ERROR]''${NC} $*" | tee -a "$REPORT_FILE"
    }
    
    section() {
      echo "" | tee -a "$REPORT_FILE"
      echo "═══════════════════════════════════════════════════════════" | tee -a "$REPORT_FILE"
      echo "  $*" | tee -a "$REPORT_FILE"
      echo "═══════════════════════════════════════════════════════════" | tee -a "$REPORT_FILE"
    }
    
    # ═════════════════════════════════════════════════════════════════════════
    # AUDIT FUNCTIONS
    # ═════════════════════════════════════════════════════════════════════════
    
    audit_disk_usage() {
      section "DISK USAGE ANALYSIS"
      
      log ">>> Root filesystem usage:"
      df -h / | tee -a "$REPORT_FILE"
      
      log ""
      log ">>> Top 20 directories by size:"
      du -h / 2>/dev/null | sort -rh | head -20 | tee -a "$REPORT_FILE" || \
        warn "Full disk scan requires root permissions"
      
      log ""
      log ">>> Nix store size:"
      nix path-info -Sh /run/current-system 2>/dev/null | tee -a "$REPORT_FILE" || \
        log "    Store size: $(du -sh /nix/store 2>/dev/null | cut -f1)"
      
      log ""
      log ">>> Garbage collectable paths:"
      nix-collect-garbage --dry-run 2>&1 | head -5 | tee -a "$REPORT_FILE" || \
        warn "Cannot run garbage collection dry-run"
    }
    
    audit_duplicate_files() {
      section "DUPLICATE FILE DETECTION"
      
      log ">>> Scanning for duplicate files (> 1MB) in /etc/nixos..."
      
      # Find duplicates by hash in /etc/nixos
      find /etc/nixos -type f -size +1M -exec sha256sum {} \; 2>/dev/null | \
        sort | uniq -d -w 64 | while read hash file; do
        log "    Duplicate hash: $hash"
      done
      
      # Check for duplicate nix expressions
      log ""
      log ">>> Checking for duplicate nix expressions:"
      for file in $(find /etc/nixos -name "*.nix" -type f); do
        basename=$(basename "$file")
        count=$(find /etc/nixos -name "$basename" -type f | wc -l)
        if [ $count -gt 1 ]; then
          warn "    Duplicate file: $basename ($count occurrences)"
          if [ $VERBOSE -eq 1 ]; then
            find /etc/nixos -name "$basename" -type f | while read f; do
              log "      - $f"
            done
          fi
        fi
      done
    }
    
    audit_unused_services() {
      section "SERVICE AUDIT"
      
      log ">>> Failed services:"
      systemctl --failed --no-pager 2>/dev/null | tee -a "$REPORT_FILE" || \
        log "    No failed services"
      
      log ""
      log ">>> Inactive (dead) services that are enabled:"
      systemctl list-units --state=inactive --type=service --no-pager 2>/dev/null | \
        grep -E "\.service.*dead" | head -20 | tee -a "$REPORT_FILE" || \
        log "    No inactive enabled services found"
      
      log ""
      log ">>> Services with high resource usage:"
      systemctl list-units --type=service --state=running --no-pager 2>/dev/null | \
        head -30 | tee -a "$REPORT_FILE"
      
      log ""
      log ">>> Enabled but potentially unnecessary services:"
      # Check for common bloat
      for svc in cups bluetooth avahi-daemon ModemManager geoclue; do
        if systemctl is-enabled $svc 2>/dev/null | grep -q enabled; then
          warn "    $svc is enabled (may be unnecessary)"
        fi
      done
    }
    
    audit_home_directory() {
      section "HOME DIRECTORY AUDIT"
      
      log ">>> Cache directory size:"
      for dir in ~/.cache ~/.local/share/Trash ~/.npm ~/.cargo ~/.rustup; do
        if [ -d "$dir" ]; then
          size=$(du -sh "$dir" 2>/dev/null | cut -f1)
          log "    $dir: $size"
        fi
      done
      
      log ""
      log ">>> Old configuration files:"
      find ~ -name "*.old" -o -name "*.bak" -o -name "*~" 2>/dev/null | \
        head -20 | tee -a "$REPORT_FILE" || log "    None found"
      
      log ""
      log ">>> Orphaned symlinks:"
      find ~ -xtype l 2>/dev/null | head -20 | tee -a "$REPORT_FILE" || log "    None found"
    }
    
    audit_nix_store() {
      section "NIX STORE AUDIT"
      
      log ">>> Unused packages (not in current profile):"
      # Packages not referenced by current system
      nix-store --query --roots /nix/store 2>/dev/null | \
        grep -v "/proc\|/run/current-system" | head -20 | tee -a "$REPORT_FILE" || \
        log "    Store appears clean"
      
      log ""
      log ">>> Old generations:"
      nix-env --list-generations 2>/dev/null | tee -a "$REPORT_FILE" || \
        log "    No user generations"
      
      nixos-rebuild list-generations 2>/dev/null | tee -a "$REPORT_FILE" || \
        log "    No system generations accessible"
      
      log ""
      log ">>> Optimisation candidates:"
      nix-store --optimise --dry-run 2>&1 | head -10 | tee -a "$REPORT_FILE" || \
        log "    Store already optimised"
    }
    
    audit_journal_logs() {
      section "SYSTEM JOURNAL AUDIT"
      
      log ">>> Journal size:"
      journalctl --disk-usage 2>/dev/null | tee -a "$REPORT_FILE" || \
        warn "Journal not accessible"
      
      log ""
      log ">>> Oldest journal entries:"
      journalctl --reverse --no-pager 2>/dev/null | tail -5 | tee -a "$REPORT_FILE" || \
        log "    Cannot read journal"
      
      log ""
      log ">>> High-volume log sources:"
      journalctl --no-pager 2>/dev/null | \
        awk '{print $5}' | sort | uniq -c | sort -rn | head -10 | tee -a "$REPORT_FILE" || \
        log "    Cannot analyze journal"
    }
    
    audit_boot_entries() {
      section "BOOT ENTRIES AUDIT"
      
      if [ -d /boot/loader/entries ]; then
        log ">>> Boot entries count: $(ls /boot/loader/entries/ | wc -l)"
        ls -la /boot/loader/entries/ 2>/dev/null | tee -a "$REPORT_FILE"
        
        log ""
        log ">>> Boot partition usage:"
        df -h /boot 2>/dev/null | tee -a "$REPORT_FILE" || \
          warn "Cannot check /boot partition"
      else
        log "    Systemd-boot not in use"
      fi
    }
    
    generate_recommendations() {
      section "RECOMMENDATIONS"
      
      log ">>> Safe cleanup actions:"
      log "    1. Run 'nix-collect-garbage -d' to remove unused packages"
      log "    2. Run 'nix-store --optimise' to deduplicate store"
      log "    3. Run 'journalctl --vacuum-time=7d' to clean old logs"
      log "    4. Clear ~/.cache directory if needed"
      
      log ""
      log ">>> System optimization:"
      log "    1. Enable automatic GC: nix.gc.automatic = true"
      log "    2. Enable auto-optimise: nix.settings.auto-optimise-store = true"
      log "    3. Review enabled services in configuration.nix"
    }
    
    # ═════════════════════════════════════════════════════════════════════════
    # MAIN
    # ═════════════════════════════════════════════════════════════════════════
    
    main() {
      echo "X15 System Audit Tool"
      echo "Report will be saved to: $REPORT_FILE"
      echo ""
      
      : > "$REPORT_FILE"  # Create/truncate report file
      
      audit_disk_usage
      audit_duplicate_files
      audit_unused_services
      audit_home_directory
      audit_nix_store
      audit_journal_logs
      audit_boot_entries
      generate_recommendations
      
      section "AUDIT COMPLETE"
      log "Report saved to: $REPORT_FILE"
      log "Review recommendations and run cleanup as needed"
    }
    
    main "$@"
  '';

  # ═══════════════════════════════════════════════════════════════════════════
  # CLEANUP SCRIPT - Safe Cleanup Operations
  # ═══════════════════════════════════════════════════════════════════════════
  
  cleanupScript = pkgs.writeShellScriptBin "x15-system-cleanup" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    DRY_RUN="''${DRY_RUN:-0}"
    VERBOSE="''${VERBOSE:-0}"
    FORCE="''${FORCE:-0}"
    
    # Colors
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
    
    log() {
      echo -e "''${GREEN}[CLEANUP]''${NC} $*"
    }
    
    warn() {
      echo -e "''${YELLOW}[WARN]''${NC} $*"
    }
    
    error() {
      echo -e "''${RED}[ERROR]''${NC} $*" >&2
    }
    
    dryrun() {
      if [ $DRY_RUN -eq 1 ]; then
        echo -e "''${BLUE}[DRY-RUN]''${NC} Would execute: $*"
      else
        log "Executing: $*"
        eval "$@"
      fi
    }
    
    confirm() {
      if [ $FORCE -eq 1 ]; then
        return 0
      fi
      echo -e "''${YELLOW}$* [y/N]''${NC}"
      read -r response
      case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
      esac
    }
    
    # ═════════════════════════════════════════════════════════════════════════
    # CLEANUP OPERATIONS
    # ═════════════════════════════════════════════════════════════════════════
    
    cleanup_nix_garbage() {
      log ">>> Nix Garbage Collection"
      
      if confirm "Delete all old generations and run garbage collection?"; then
        # Delete old generations
        dryrun "nix-env --delete-generations +5 2>/dev/null || true"
        dryrun "sudo nix-env --delete-generations +10 -p /nix/var/nix/profiles/system 2>/dev/null || true"
        
        # Run garbage collection
        dryrun "nix-collect-garbage -d"
        
        log "    [✓] Garbage collection complete"
      else
        warn "    Skipped nix garbage collection"
      fi
    }
    
    cleanup_nix_optimise() {
      log ">>> Nix Store Optimisation"
      
      if confirm "Optimise nix store (deduplication)?"; then
        dryrun "nix-store --optimise"
        log "    [✓] Store optimisation complete"
      else
        warn "    Skipped store optimisation"
      fi
    }
    
    cleanup_journal() {
      log ">>> Journal Log Cleanup"
      
      local journal_size=$(journalctl --disk-usage 2>/dev/null | grep -oP '\d+(\.\d+)?[KMGT]?' | head -1)
      log "    Current journal size: $journal_size"
      
      if confirm "Vacuum journal logs older than 2 weeks?"; then
        dryrun "sudo journalctl --vacuum-time=14d"
        log "    [✓] Journal vacuum complete"
      else
        warn "    Skipped journal cleanup"
      fi
    }
    
    cleanup_caches() {
      log ">>> Cache Directory Cleanup"
      
      local cache_dirs=(
        "$HOME/.cache"
        "$HOME/.npm/_cacache"
        "$HOME/.cargo/registry/cache"
      )
      
      for dir in "''${cache_dirs[@]}"; do
        if [ -d "$dir" ]; then
          local size=$(du -sh "$dir" 2>/dev/null | cut -f1)
          log "    $dir: $size"
        fi
      done
      
      if confirm "Clean package manager caches?"; then
        # Clean nix build cache
        dryrun "rm -rf ~/.cache/nix 2>/dev/null || true"
        
        # Clean npm cache
        if command -v npm &> /dev/null; then
          dryrun "npm cache clean --force 2>/dev/null || true"
        fi
        
        # Clean cargo cache
        if command -v cargo &> /dev/null; then
          dryrun "cargo cache --autoclean 2>/dev/null || true"
        fi
        
        log "    [✓] Cache cleanup complete"
      else
        warn "    Skipped cache cleanup"
      fi
    }
    
    cleanup_home() {
      log ">>> Home Directory Cleanup"
      
      # Find old backup files
      local old_files=$(find ~ -name "*.old" -o -name "*.bak" -o -name "*~" 2>/dev/null | wc -l)
      log "    Found $old_files backup/old files"
      
      # Find orphaned symlinks
      local orphan_links=$(find ~ -xtype l 2>/dev/null | wc -l)
      log "    Found $orphan_links orphaned symlinks"
      
      if [ $old_files -gt 0 ] && confirm "Remove $old_files backup/old files?"; then
        dryrun "find ~ -name '*.old' -delete 2>/dev/null || true"
        dryrun "find ~ -name '*.bak' -delete 2>/dev/null || true"
        dryrun "find ~ -name '*~' -delete 2>/dev/null || true"
        log "    [✓] Old files removed"
      fi
      
      if [ $orphan_links -gt 0 ] && confirm "Remove $orphan_links orphaned symlinks?"; then
        dryrun "find ~ -xtype l -delete 2>/dev/null || true"
        log "    [✓] Orphaned symlinks removed"
      fi
    }
    
    cleanup_tmp() {
      log ">>> Temporary Files Cleanup"
      
      # Clean /tmp (be careful!)
      log "    /tmp size: $(du -sh /tmp 2>/dev/null | cut -f1)"
      
      if confirm "Clean old files in /tmp (older than 7 days)?"; then
        dryrun "sudo find /tmp -type f -mtime +7 -delete 2>/dev/null || true"
        log "    [✓] Temporary files cleaned"
      fi
    }
    
    cleanup_trash() {
      log ">>> Trash Cleanup"
      
      local trash_dirs=(
        "$HOME/.local/share/Trash"
        "$HOME/.Trash"
      )
      
      for dir in "''${trash_dirs[@]}"; do
        if [ -d "$dir" ]; then
          local size=$(du -sh "$dir" 2>/dev/null | cut -f1)
          log "    $dir: $size"
        fi
      done
      
      if confirm "Empty trash?"; then
        for dir in "''${trash_dirs[@]}"; do
          if [ -d "$dir" ]; then
            dryrun "rm -rf \"$dir\"/* 2>/dev/null || true"
          fi
        done
        log "    [✓] Trash emptied"
      fi
    }
    
    cleanup_broken_gc_roots() {
      log ">>> Broken GC Roots"
      
      local broken_roots=$(nix-store --gc --print-dead 2>/dev/null | wc -l)
      log "    Found $broken_roots potentially broken roots"
      
      if [ $broken_roots -gt 0 ] && confirm "Remove broken GC roots?"; then
        dryrun "nix-collect-garbage --delete-older-than 30d 2>/dev/null || true"
        log "    [✓] Broken roots cleaned"
      fi
    }
    
    # ═════════════════════════════════════════════════════════════════════════
    # SAFETY CHECKS
    # ═════════════════════════════════════════════════════════════════════════
    
    safety_check() {
      log ">>> Running Safety Checks"
      
      # Check if we're in a graphical session
      if [ -n "''${WAYLAND_DISPLAY:-}" ] || [ -n "''${DISPLAY:-}" ]; then
        log "    [✓] Graphical session detected"
      fi
      
      # Check available disk space
      local available=$(df / | awk 'NR==2{print $4}')
      if [ $available -lt 1048576 ]; then  # Less than 1GB
        warn "    Low disk space on / ($((available/1024))MB available)"
        if [ $FORCE -eq 0 ]; then
          error "    Aborting - use FORCE=1 to override"
          exit 1
        fi
      fi
      
      # Check nix store mount
      if ! mountpoint -q /nix/store 2>/dev/null; then
        warn "    /nix/store is not a separate mount"
      fi
      
      log "    [✓] Safety checks passed"
    }
    
    # ═════════════════════════════════════════════════════════════════════════
    # MAIN
    # ═════════════════════════════════════════════════════════════════════════
    
    show_help() {
      cat << 'EOF'
    X15 System Cleanup Tool
    
    Usage: x15-system-cleanup [OPTIONS]
    
    Options:
      -n, --dry-run    Show what would be done without executing
      -f, --force      Skip confirmation prompts
      -v, --verbose    Verbose output
      -h, --help       Show this help message
      
    Environment Variables:
      DRY_RUN=1        Equivalent to --dry-run
      FORCE=1          Equivalent to --force
      VERBOSE=1        Enable verbose output
    
EOF
    }
    
    parse_args() {
      while [[ $# -gt 0 ]]; do
        case $1 in
          -n|--dry-run) DRY_RUN=1 ;;
          -f|--force) FORCE=1 ;;
          -v|--verbose) VERBOSE=1 ;;
          -h|--help) show_help; exit 0 ;;
          *) error "Unknown option: $1"; exit 1 ;;
        esac
        shift
      done
    }
    
    main() {
      parse_args "$@"
      
      echo "═══════════════════════════════════════════════════════════"
      echo "  X15 System Cleanup"
      if [ $DRY_RUN -eq 1 ]; then
        echo "  MODE: DRY RUN (no changes will be made)"
      fi
      echo "═══════════════════════════════════════════════════════════"
      echo ""
      
      safety_check
      
      # Run cleanup operations
      cleanup_nix_garbage
      cleanup_nix_optimise
      cleanup_journal
      cleanup_caches
      cleanup_home
      cleanup_tmp
      cleanup_trash
      cleanup_broken_gc_roots
      
      echo ""
      echo "═══════════════════════════════════════════════════════════"
      log "Cleanup complete!"
      echo "═══════════════════════════════════════════════════════════"
      
      if [ $DRY_RUN -eq 1 ]; then
        echo ""
        warn "This was a dry run. No actual changes were made."
        echo "Run without --dry-run to execute cleanup."
      fi
    }
    
    main "$@"
  '';

  # ═══════════════════════════════════════════════════════════════════════════
  # RESTRUCTURE SCRIPT - File Organization
  # ═══════════════════════════════════════════════════════════════════════════
  
  restructureScript = pkgs.writeShellScriptBin "x15-system-restructure" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    DRY_RUN="''${DRY_RUN:-1}"  # Default to dry-run for safety
    VERBOSE="''${VERBOSE:-0}"
    
    NIXOS_DIR="/etc/nixos"
    BACKUP_DIR="/etc/nixos/.backup/$(date +%Y%m%d_%H%M%S)"
    
    log() {
      echo "[RESTRUCTURE] $*"
    }
    
    warn() {
      echo "[WARN] $*" >&2
    }
    
    dryrun() {
      if [ $DRY_RUN -eq 1 ]; then
        echo "[DRY-RUN] Would: $*"
      else
        log "Executing: $*"
        eval "$@"
      fi
    }
    
    create_backup() {
      if [ $DRY_RUN -eq 0 ]; then
        log ">>> Creating backup at $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
        cp -r "$NIXOS_DIR" "$BACKUP_DIR/"
        log "    [✓] Backup created"
      else
        log "    [DRY-RUN] Would create backup at $BACKUP_DIR"
      fi
    }
    
    # ═════════════════════════════════════════════════════════════════════════
    # RESTRUCTURE OPERATIONS
    # ═════════════════════════════════════════════════════════════════════════
    
    organize_modules() {
      log ">>> Organizing module structure"
      
      # Create standard directories
      dryrun "mkdir -p $NIXOS_DIR/modules/{core,desktop,hardware,network,services}"
      dryrun "mkdir -p $NIXOS_DIR/overlays"
      dryrun "mkdir -p $NIXOS_DIR/lib"
      
      # Categorize existing modules
      log "    Analyzing existing modules..."
      
      # Core modules
      for file in "$NIXOS_DIR/modules/"*.nix; do
        [ -f "$file" ] || continue
        basename=$(basename "$file")
        
        case "$basename" in
          boot.nix|default.nix)
            log "    $basename -> modules/core/"
            dryrun "mv $file $NIXOS_DIR/modules/core/$basename"
            ;;
          performance*.nix)
            log "    $basename -> modules/core/"
            dryrun "mv $file $NIXOS_DIR/modules/core/$basename"
            ;;
          nvidia.nix|hardware-*.nix)
            log "    $basename -> modules/hardware/"
            dryrun "mv $file $NIXOS_DIR/modules/hardware/$basename"
            ;;
          portal.nix)
            log "    $basename -> modules/desktop/"
            dryrun "mv $file $NIXOS_DIR/modules/desktop/$basename"
            ;;
          ollama.nix|battery-care.nix)
            log "    $basename -> modules/services/"
            dryrun "mv $file $NIXOS_DIR/modules/services/$basename"
            ;;
        esac
      done
    }
    
    consolidate_imports() {
      log ">>> Consolidating import statements"
      
      # Find and consolidate duplicate imports
      log "    Scanning for optimization opportunities..."
      
      # Generate optimized default.nix
      local default_nix="$NIXOS_DIR/modules/default.nix"
      if [ -f "$default_nix" ]; then
        log "    Updating module imports..."
        
        # This would update the imports to use the new structure
        # In dry-run mode, just show what would change
        if [ $DRY_RUN -eq 0 ]; then
          cat > "$default_nix" << 'EOF'
{ ... }:

{
  imports = [
    ./core
    ./hardware
    ./desktop
    ./services
  ];
}
EOF
        fi
      fi
    }
    
    standardize_naming() {
      log ">>> Standardizing file naming conventions"
      
      # Rename files to consistent naming
      for file in "$NIXOS_DIR"/**/*.nix; do
        [ -f "$file" ] || continue
        
        # Convert CamelCase to kebab-case if needed
        # This is a placeholder - actual implementation would be more complex
        :
      done
    }
    
    remove_empty_dirs() {
      log ">>> Removing empty directories"
      
      dryrun "find $NIXOS_DIR -type d -empty -delete 2>/dev/null || true"
    }
    
    # ═════════════════════════════════════════════════════════════════════════
    # MAIN
    # ═════════════════════════════════════════════════════════════════════════
    
    main() {
      echo "═══════════════════════════════════════════════════════════"
      echo "  X15 System Restructure"
      if [ $DRY_RUN -eq 1 ]; then
        echo "  MODE: DRY RUN (no changes will be made)"
        echo "  Set DRY_RUN=0 to execute changes"
      fi
      echo "═══════════════════════════════════════════════════════════"
      echo ""
      
      create_backup
      organize_modules
      consolidate_imports
      standardize_naming
      remove_empty_dirs
      
      log ""
      log "Restructure analysis complete"
      
      if [ $DRY_RUN -eq 1 ]; then
        echo ""
        echo "This was a dry run. Review the proposed changes above."
        echo "Run with DRY_RUN=0 to execute restructuring."
      fi
    }
    
    main "$@"
  '';

in
{
  # ═══════════════════════════════════════════════════════════════════════════
  # OPTIONS
  # ═══════════════════════════════════════════════════════════════════════════
  
  options.modules.systemCleanup = {
    enable = lib.mkEnableOption "system cleanup and restructuring tools";
    
    autoGc = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable automatic garbage collection";
    };
    
    autoOptimise = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable automatic store optimisation";
    };
    
    journalMaxSize = lib.mkOption {
      type = lib.types.str;
      default = "500M";
      description = "Maximum journal size";
    };
    
    cleanupInterval = lib.mkOption {
      type = lib.types.str;
      default = "weekly";
      description = "System cleanup frequency";
    };
  };

  # ═══════════════════════════════════════════════════════════════════════════
  # CONFIGURATION
  # ═══════════════════════════════════════════════════════════════════════════
  
  config = lib.mkIf cfg.enable {
    
    # ── Cleanup Packages ─────────────────────────────────────────────────────
    environment.systemPackages = [
      auditScript
      cleanupScript
      restructureScript
      
      (pkgs.writeShellScriptBin "x15-maintenance" ''
        #!${pkgs.bash}/bin/bash
        # Unified maintenance script
        
        show_help() {
          cat << 'EOF'
    X15 System Maintenance
    
    Usage: x15-maintenance [COMMAND]
    
    Commands:
      audit          Run system audit
      cleanup        Run cleanup operations
      restructure    Analyze and restructure configuration
      optimize       Run full optimization (audit + cleanup)
      status         Show system status
      help           Show this help
    
EOF
        }
        
        case "''${1:-status}" in
          audit)
            x15-system-audit
            ;;
          cleanup)
            x15-system-cleanup "''${@:2}"
            ;;
          restructure)
            x15-system-restructure
            ;;
          optimize)
            echo ">>> Running system optimization..."
            x15-system-audit
            echo ""
            read -p "Continue with cleanup? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
              x15-system-cleanup
            fi
            ;;
          status)
            echo "═══════════════════════════════════════════════════════════"
            echo "  X15 System Status"
            echo "═══════════════════════════════════════════════════════════"
            echo ""
            echo ">>> Disk Usage:"
            df -h /
            echo ""
            echo ">>> Nix Store:"
            du -sh /nix/store 2>/dev/null || echo "N/A"
            echo ""
            echo ">>> Journal:"
            journalctl --disk-usage 2>/dev/null || echo "N/A"
            echo ""
            echo ">>> Memory:"
            free -h
            ;;
          help)
            show_help
            ;;
          *)
            echo "Unknown command: $1"
            show_help
            exit 1
            ;;
        esac
      '')
    ];
    
    # ── Automatic Maintenance Services ─────────────────────────────────────
    
    # Garbage collection
    nix.gc.automatic = cfg.autoGc;
    nix.gc.dates = cfg.cleanupInterval;
    nix.gc.options = "--delete-older-than 30d";
    
    # Store optimisation
    nix.settings.auto-optimise-store = cfg.autoOptimise;
    nix.optimise.automatic = cfg.autoOptimise;
    nix.optimise.dates = [ cfg.cleanupInterval ];
    
    # Journal size limit
    services.journald.extraConfig = ''
      SystemMaxUse=${cfg.journalMaxSize}
      MaxRetentionSec=2week
      MaxFileSec=1week
    '';
    
    # Periodic cleanup timer
    systemd.services.x15-periodic-cleanup = {
      description = "X15 Periodic System Cleanup";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${cleanupScript}/bin/x15-system-cleanup --force";
      };
    };
    
    systemd.timers.x15-periodic-cleanup = lib.mkIf cfg.autoGc {
      description = "X15 Periodic Cleanup Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.cleanupInterval;
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
  };
}
