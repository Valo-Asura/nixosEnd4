# ═══════════════════════════════════════════════════════════════════════════════
# NixOS Performance Optimization Module - CachyOS-Style Kernel 7+ Configuration
# ═══════════════════════════════════════════════════════════════════════════════
# Expert-level system tuning for Colorful X15 XS with Intel i5-12500H
# Includes: Kernel 7.x optimization, scheduler tuning, memory management, I/O
# ═══════════════════════════════════════════════════════════════════════════════

{ config, lib, pkgs, ... }:

let
  cfg = config.modules.performanceEnhanced;
  isMax = cfg.profile == "max";
  isBalanced = cfg.profile == "balanced";
  isCool = cfg.profile == "cool";

  # ═══════════════════════════════════════════════════════════════════════════
  # CACHYOS-STYLE KERNEL 7+ CONFIGURATION
  # ═══════════════════════════════════════════════════════════════════════════
  
  # BORE Scheduler parameters (Burst-Oriented Response Enhancer)
  # Superior to CFS for desktop workloads with better latency under load
  boreSchedulerParams = {
    "sched_bore" = "1";
    "sched_burst_penalty_scale" = if isMax then "32" else "24";
    "sched_burst_granularity" = if isMax then "4" else "6";
    "sched_burst_smoothness" = if isMax then "1" else "2";
  };

  # Memory compaction and reclaim tuning for low-latency workloads
  memoryOptimizerParams = {
    # Aggressive proactive compaction for 16GB systems
    "vm.compaction_proactiveness" = if isMax then "50" else "20";
    "vm.compaction_effort" = if isMax then "100" else "75";
    
    # Watermark scaling for better memory pressure handling
    "vm.watermark_scale_factor" = "200";
    "vm.zone_reclaim_mode" = "0";
    
    # Page reclaim tuning
    "vm.page-cluster" = "2";
    "vm.oom_dump_tasks" = "1";
    
    # Huge page optimization
    "vm.nr_hugepages" = if isMax then "64" else "0";
    "vm.hugetlb_optimize_vmemmap" = "1";
    
    # Per-CPU page cache batch sizing
    "vm.percpu_pagelist_fraction" = "8";
  };

  # Intel P-State / CPUFreq governor optimization
  cpufreqOptimizerParams = {
    # HWP dynamic boost for Alder Lake
    "intel_pstate.hwp_dynamic_boost" = if isMax then "1" else "0";
    
    # P/E core migration cost (hybrid CPU optimization)
    "sched_migration_cost_ns" = "500000";
    "sched_nr_migrate" = if isMax then "128" else "32";
    
    # Idle injection control for thermal management
    "sched_idle_next_timeslice" = "2";
    
    # CPU frequency stats
    "cpufreq.default_governor" = if isMax then "performance" else "schedutil";
  };

  # I/O and block layer optimization for NVMe SSDs
  ioOptimizerParams = {
    # NVMe queue depth and polling
    "nvme.poll_queue" = if isMax then "8" else "0";
    
    # Block layer read-ahead
    "block.read_ahead_kb" = "256";
    
    # Deadline scheduler tunables for NVMe
    "sched_slice" = if isMax then "2" else "5";
    "sched_batch_wakeup_gran" = if isMax then "1" else "2";
    
    # Async I/O limits
    "fs.aio-max-nr" = "1048576";
    "fs.aio-nr" = "0";
    
    # File-max for high-connection workloads
    "fs.file-max" = "2097152";
    "fs.nr_open" = "2097152";
  };

  # Network stack optimization (BBR v2 ready + advanced tuning)
  networkOptimizerParams = {
    # BBR congestion control
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc" = "fq";
    
    # TCP buffer auto-tuning
    "net.ipv4.tcp_moderate_rcvbuf" = "1";
    "net.ipv4.tcp_rmem" = "4096 87380 16777216";
    "net.ipv4.tcp_wmem" = "4096 65536 16777216";
    "net.core.rmem_default" = "131072";
    "net.core.wmem_default" = "131072";
    "net.core.rmem_max" = "16777216";
    "net.core.wmem_max" = "16777216";
    
    # Connection tracking optimization
    "net.netfilter.nf_conntrack_max" = "1048576";
    "net.netfilter.nf_conntrack_tcp_timeout_established" = "600";
    "net.netfilter.nf_conntrack_tcp_timeout_time_wait" = "30";
    
    # TCP performance features
    "net.ipv4.tcp_fastopen" = "3";
    "net.ipv4.tcp_tw_reuse" = "1";
    "net.ipv4.tcp_fin_timeout" = "10";
    "net.ipv4.tcp_keepalive_time" = "60";
    "net.ipv4.tcp_keepalive_intvl" = "10";
    "net.ipv4.tcp_keepalive_probes" = "6";
    "net.ipv4.tcp_no_metrics_save" = "1";
    "net.ipv4.tcp_slow_start_after_idle" = "0";
    
    # IPv6 optimization
    "net.ipv6.conf.all.disable_ipv6" = if cfg.disableIPv6 then "1" else "0";
    
    # Network device backlog
    "net.core.netdev_max_backlog" = if isMax then "65536" else "16384";
    "net.core.somaxconn" = "65535";
    "net.ipv4.tcp_max_syn_backlog" = "65536";
    
    # Socket buffer optimization
    "net.core.optmem_max" = "65536";
    
    # Timestamps for RTT measurement (BBR)
    "net.ipv4.tcp_timestamps" = "1";
  };

  # Virtual memory and swap optimization with zram
  vmOptimizerParams = {
    # Swappiness tuned for 16GB with zram
    "vm.swappiness" = if isMax then "33" else "10";
    "vm.vfs_cache_pressure" = if isMax then "75" else "50";
    
    # Dirty page tuning for NVMe
    "vm.dirty_background_ratio" = if isMax then "10" else "5";
    "vm.dirty_ratio" = if isMax then "20" else "10";
    "vm.dirty_background_bytes" = "0";
    "vm.dirty_bytes" = "0";
    "vm.dirty_writeback_centisecs" = if isMax then "250" else "500";
    "vm.dirty_expire_centisecs" = if isMax then "2000" else "3000";
    
    # Page reclaim
    "vm.min_free_kbytes" = if isMax then "131072" else "65536";
    "vm.page_lock_unfairness" = if isMax then "4" else "8";
    
    # Transparent hugepage
    "vm.transparent_hugepage.enabled" = if isMax then "always" else "madvise";
    "vm.transparent_hugepage.defrag" = if isMax then "always" else "defer+madvise";
    "vm.transparent_hugepage.shmem_enabled" = "advise";
  };

  # Kernel security vs performance trade-offs
  securityParams = {
    # Spectre/Meltdown mitigations (single-user trusted environment)
    "kernel.nmi_watchdog" = if isMax then "0" else "1";
    "kernel.soft_watchdog" = if isMax then "0" else "1";
    "kernel.hung_task_timeout_secs" = if isMax then "0" else "120";
    "kernel.hung_task_warnings" = if isMax then "0" else "10";
    
    # Disable KSM for predictable latency (can be enabled if needed)
    "kernel.ksm.run" = "0";
    "kernel.ksm.sleep_millisecs" = "100";
    
    # Kernel pointer restrictions
    "kernel.kptr_restrict" = if cfg.debugMode then "0" else "1";
    
    # BPF JIT for eBPF performance
    "net.core.bpf_jit_enable" = "1";
    "net.core.bpf_jit_harden" = if cfg.debugMode then "2" else "0";
    "net.core.bpf_jit_kallsyms" = if cfg.debugMode then "1" else "0";
  };

  # Combine all sysctl parameters
  allSysctl = lib.mkMerge [
    boreSchedulerParams
    memoryOptimizerParams
    cpufreqOptimizerParams
    ioOptimizerParams
    networkOptimizerParams
    vmOptimizerParams
    securityParams
  ];

  # ═══════════════════════════════════════════════════════════════════════════
  # FAN CONTROL WITH ENHANCED NBFC CONFIGURATION
  # ═══════════════════════════════════════════════════════════════════════════
  
  nbfcEnhancedConfig = builtins.toJSON {
    NotebookModel = cfg.nbfcProfile;
    Author = "nixos-performance-enhanced";
    EcPollInterval = if isMax then 500 else 1000;
    ReadWriteWords = false;
    CriticalTemperature = 95;
    CriticalTemperatureOffset = 3;
    
    FanConfigurations = [
      {
        ReadRegister = 207;
        WriteRegister = 231;
        MinSpeedValue = 20;
        MaxSpeedValue = 100;
        IndependentReadMinMaxValues = false;
        MinSpeedValueRead = 0;
        MaxSpeedValueRead = 0;
        ResetRequired = false;
        FanSpeedResetValue = 50;
        FanDisplayName = "CPU Fan";
        
        # Dynamic temperature thresholds based on profile
        TemperatureThresholds = 
          if isMax then [
            # MAX: Aggressive cooling, higher fan speeds
            { UpThreshold = 45; DownThreshold = 0;  FanSpeed = 0.0; }
            { UpThreshold = 55; DownThreshold = 40; FanSpeed = 25.0; }
            { UpThreshold = 65; DownThreshold = 50; FanSpeed = 45.0; }
            { UpThreshold = 72; DownThreshold = 60; FanSpeed = 70.0; }
            { UpThreshold = 80; DownThreshold = 68; FanSpeed = 90.0; }
            { UpThreshold = 90; DownThreshold = 75; FanSpeed = 100.0; }
          ]
          else if isCool then [
            # COOL: Prioritize silence
            { UpThreshold = 50; DownThreshold = 0;  FanSpeed = 0.0; }
            { UpThreshold = 60; DownThreshold = 45; FanSpeed = 20.0; }
            { UpThreshold = 70; DownThreshold = 55; FanSpeed = 40.0; }
            { UpThreshold = 78; DownThreshold = 65; FanSpeed = 65.0; }
            { UpThreshold = 85; DownThreshold = 72; FanSpeed = 85.0; }
            { UpThreshold = 92; DownThreshold = 80; FanSpeed = 100.0; }
          ]
          else [
            # BALANCED: Default progressive curve
            { UpThreshold = 42; DownThreshold = 0;  FanSpeed = 0.0; }
            { UpThreshold = 55; DownThreshold = 38; FanSpeed = 20.0; }
            { UpThreshold = 65; DownThreshold = 50; FanSpeed = 40.0; }
            { UpThreshold = 72; DownThreshold = 60; FanSpeed = 65.0; }
            { UpThreshold = 80; DownThreshold = 68; FanSpeed = 85.0; }
            { UpThreshold = 90; DownThreshold = 75; FanSpeed = 100.0; }
          ];
        
        FanSpeedPercentageOverrides = [
          { FanSpeedPercentage = 100.0; FanSpeedValue = 100; TargetOperation = "ReadWrite"; }
        ];
      }
    ];
    
    RegisterWriteConfigurations = [
      {
        WriteMode = "Set";
        WriteOccasion = "OnInitialization";
        Register = 44;
        Value = 8;
        ResetRequired = true;
        ResetValue = 5;
        ResetWriteMode = "Set";
        Description = "EC Override Enable";
      }
    ];
  };

in
{
  # ═══════════════════════════════════════════════════════════════════════════
  # OPTIONS
  # ═══════════════════════════════════════════════════════════════════════════
  
  options.modules.performanceEnhanced = {
    enable = lib.mkEnableOption "enhanced performance tuning with kernel 7+ optimization";
    
    profile = lib.mkOption {
      type = lib.types.enum [ "max" "balanced" "cool" ];
      default = "balanced";
      description = ''
        Performance profile:
        - max: Maximum performance, aggressive cooling, lowest latency
        - balanced: Optimal performance with reasonable thermals
        - cool: Prioritize silence and battery life
      '';
    };
    
    nbfcProfile = lib.mkOption {
      type = lib.types.str;
      default = "Colorful X15 AT 22";
      description = "NBFC laptop profile for fan control";
    };
    
    disableIPv6 = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Disable IPv6 for reduced network stack overhead";
    };
    
    debugMode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable kernel debugging features (reduces performance)";
    };
    
    kernelVersion = lib.mkOption {
      type = lib.types.enum [ "latest" "zen" "cachyos" "xanmod" ];
      default = "latest";
      description = ''
        Kernel flavor:
        - latest: Latest stable kernel from nixpkgs
        - zen: Zen kernel (good balance)
        - cachyos: CachyOS kernel patches (best desktop performance)
        - xanmod: XanMod kernel (gaming focused)
      '';
    };
  };

  # ═══════════════════════════════════════════════════════════════════════════
  # CONFIGURATION
  # ═══════════════════════════════════════════════════════════════════════════
  
  config = lib.mkIf cfg.enable {
    
    # ── Kernel Package Selection ─────────────────────────────────────────────
    boot.kernelPackages = 
      if cfg.kernelVersion == "zen" then pkgs.linuxPackages_zen
      else if cfg.kernelVersion == "cachyos" then 
        if pkgs ? linuxPackages_cachyos then pkgs.linuxPackages_cachyos
        else pkgs.linuxPackages_zen
      else if cfg.kernelVersion == "xanmod" then
        if pkgs ? linuxPackages_xanmod then pkgs.linuxPackages_xanmod
        else pkgs.linuxPackages_zen
      else if pkgs ? linuxPackages_7_0 then pkgs.linuxPackages_7_0
      else pkgs.linuxPackages_latest;

    # ── Kernel Parameters (CachyOS-style) ────────────────────────────────────
    boot.kernelParams = [
      # Scheduler and preemption
      "preempt=full"
      "threadirqs"
      "skew_tick=1"
      "irqthread"
      
      # Intel CPU optimizations
      "intel_pstate=passive"
      "intel_idle.max_cstate=${if isMax then "1" else "9"}"
      "processor.max_cstate=${if isMax then "1" else "9"}"
      "idle=${if isMax then "halt" else "poll"}"
      
      # Memory management
      "transparent_hugepage=${if isMax then "always" else "madvise"}"
      "hugepagesz=2M"
      "hugepages=${if isMax then "64" else "0"}"
      "vm.vfs_cache_pressure=${toString (if isMax then 75 else 50)}"
      
      # I/O optimization
      "nvme.poll_queues=${if isMax then "8" else "4"}"
      "scsi_mod.use_blk_mq=1"
      
      # Security mitigations (single-user optimization)
      "mitigations=off"
      "spectre_v2=off"
      "nopti"
      
      # Disable debug features
      "nowatchdog"
      "nmi_watchdog=0"
      "soft_watchdog=0"
      "nosoftlockup"
      "nohz_full=all"
      
      # Intel graphics
      "i915.enable_psr=0"
      "i915.enable_fbc=0"
      "i915.fastboot=1"
      "nvidia-drm.modeset=1"
      
      # Boot performance
      "quiet"
      "loglevel=3"
      "rd.systemd.show_status=auto"
      "rd.udev.log_level=3"
      "systemd.show_status=0"
      "udev.log_priority=3"
    ] 
    ++ lib.optionals isMax [
      "isolcpus=domain,managed_irq,11"
      "rcu_nocbs=all"
      "rcutree.enable_rcu_lazy=1"
      "no_hz_full=all"
      "tick_nohz_full=all"
      "timer_migration=1"
    ];

    # ── Kernel Modules ───────────────────────────────────────────────────────
    boot.kernelModules = [
      "tcp_bbr"
      "zstd"
      "lz4"
    ] ++ lib.optionals isMax [
      "cpufreq_performance"
      "cpufreq_schedutil"
    ];
    
    boot.initrd.kernelModules = [ "zstd" "lz4" ];

    # ── sysctl Configuration ─────────────────────────────────────────────────
    boot.kernel.sysctl = allSysctl;

    # ── Zram Swap with Enhanced Configuration ──────────────────────────────────
    zramSwap = {
      enable = true;
      algorithm = "zstd";
      memoryPercent = if isMax then 75 else 50;
      priority = 100;
    };

    # ── TLP Power Management ─────────────────────────────────────────────────
    services.power-profiles-daemon.enable = false;
    
    services.tlp = {
      enable = true;
      settings = {
        # CPU governors
        CPU_SCALING_GOVERNOR_ON_AC = if isMax then "performance" else if isCool then "powersave" else "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        
        # Energy Performance Preference (Intel HWP)
        CPU_ENERGY_PERF_POLICY_ON_AC = if isMax then "performance" else if isCool then "balance_power" else "balance_performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
        
        # CPU boost
        CPU_BOOST_ON_AC = if isCool then 0 else 1;
        CPU_BOOST_ON_BAT = 0;
        
        # Performance limits
        CPU_MIN_PERF_ON_AC = 0;
        CPU_MAX_PERF_ON_AC = if isMax then 100 else if isCool then 70 else 95;
        CPU_MIN_PERF_ON_BAT = 0;
        CPU_MAX_PERF_ON_BAT = if isCool then 35 else 50;
        
        # Platform profile
        PLATFORM_PROFILE_ON_AC = if isMax then "performance" else if isCool then "low-power" else "balanced";
        PLATFORM_PROFILE_ON_BAT = "low-power";
        
        # Runtime PM
        RUNTIME_PM_ON_AC = if isMax then "on" else "auto";
        RUNTIME_PM_ON_BAT = "auto";
        
        # PCIe ASPM
        PCIE_ASPM_ON_AC = if isCool then "powersupersave" else "default";
        PCIE_ASPM_ON_BAT = "powersupersave";
        
        # Disk I/O scheduler
        DISK_IOSCHED = "kyber";
        
        # USB autosuspend
        USB_AUTOSUSPEND = if isMax then 0 else 1;
        USB_EXCLUDE_WWAN = 1;
        
        # Battery care thresholds
        START_CHARGE_THRESH_BAT0 = if isCool then 60 else 75;
        STOP_CHARGE_THRESH_BAT0 = if isCool then 80 else 90;
        
        # Sleep
        MEM_SLEEP_ON_AC = "deep";
        MEM_SLEEP_ON_BAT = "deep";
        
        # Wake-on-LAN
        WOL_DISABLE = "Y";
      };
    };

    # ── Intel Thermald ─────────────────────────────────────────────────────────
    services.thermald.enable = true;
    
    # ── Ananicy-CPP Process Prioritization ───────────────────────────────────
    services.ananicy = {
      enable = true;
      package = pkgs.ananicy-cpp;
      rulesProvider = pkgs.ananicy-cpp;
    };

    # ── systemd-oomd Memory Protection ───────────────────────────────────────
    systemd.oomd = {
      enable = true;
      enableRootSlice = true;
      enableSystemSlice = true;
      enableUserSlices = true;
    };
    
    # Dedicated nix-daemon slice for build isolation
    systemd.slices."nix-daemon" = {
      sliceConfig = {
        ManagedOOMMemoryPressure = "kill";
        ManagedOOMMemoryPressureLimit = if isMax then "70%" else "60%";
        CPUShares = if isMax then 2048 else 1024;
        IOWeight = if isMax then 200 else 100;
      };
    };
    systemd.services.nix-daemon.serviceConfig.Slice = "nix-daemon.slice";

    # ── Enhanced NBFC Fan Control ───────────────────────────────────────────
    environment.etc."nbfc/nbfc.json".text = nbfcEnhancedConfig;
    
    systemd.services.nbfc_service = {
      description = "Notebook FanControl Service (Enhanced)";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-udevd.service" "sysinit.target" ];
      path = [ pkgs.kmod pkgs.coreutils ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.nbfc-linux}/bin/nbfc_service --config-file /etc/nbfc/nbfc.json";
        Restart = "on-failure";
        RestartSec = 3;
        StartLimitInterval = 60;
        StartLimitBurst = 3;
        # Raw EC access required
        PrivateTmp = true;
        ProtectSystem = false;
        ProtectHome = false;
      };
    };

    # ── Enhanced Diagnostic Tools ────────────────────────────────────────────
    environment.systemPackages = [
      # Benchmarking tools
      pkgs.sysbench
      pkgs.stress-ng
      pkgs.fio
      pkgs.iozone
      pkgs.phoronix-test-suite
      pkgs.perf-linux
      pkgs.turbostat
      pkgs.msrtools
      
      # Hardware monitoring
      pkgs.lm_sensors
      pkgs.pciutils
      pkgs.usbutils
      pkgs.dmidecode
      pkgs.smartmontools
      pkgs.nvme-cli
      
      # System diagnostics
      pkgs.btop
      pkgs.htop
      pkgs.iotop
      pkgs.powertop
      pkgs.cpupower-gui
      pkgs.linuxKernel.packages.linux_latest_libre.cpupower
      pkgs.tlp
      
      # Custom diagnostic scripts
      (pkgs.writeShellScriptBin "x15-performance-benchmark" ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail
        
        PROFILE="${cfg.profile}"
        OUTPUT_DIR="$HOME/.local/share/x15-benchmarks"
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        RESULT_FILE="$OUTPUT_DIR/benchmark_$TIMESTAMP.json"
        
        mkdir -p "$OUTPUT_DIR"
        
        echo "═══════════════════════════════════════════════════════════"
        echo "  X15 Performance Benchmark - Profile: $PROFILE"
        echo "  Timestamp: $(date)"
        echo "═══════════════════════════════════════════════════════════"
        
        declare -A RESULTS
        
        # CPU Benchmark
        echo -e "\n>>> CPU Benchmark (sysbench CPU)..."
        CPU_RESULT=$(sysbench cpu --threads=12 --time=30 --cpu-max-prime=20000 run 2>/dev/null | 
          grep "events per second:" | awk '{print $4}')
        RESULTS[cpu_events_per_sec]=$CPU_RESULT
        echo "    Events/sec: $CPU_RESULT"
        
        # Memory Benchmark
        echo -e "\n>>> Memory Benchmark (sysbench Memory)..."
        MEM_READ=$(sysbench memory --memory-block-size=1M --memory-total-size=8G --memory-oper=read run 2>/dev/null |
          grep "transferred" | awk '{print $1}')
        MEM_WRITE=$(sysbench memory --memory-block-size=1M --memory-total-size=8G --memory-oper=write run 2>/dev/null |
          grep "transferred" | awk '{print $1}')
        RESULTS[mem_read_mib_sec]=$MEM_READ
        RESULTS[mem_write_mib_sec]=$MEM_WRITE
        echo "    Read: $MEM_READ MiB/s | Write: $MEM_WRITE MiB/s"
        
        # Disk I/O Benchmark
        echo -e "\n>>> Disk I/O Benchmark (fio)..."
        FIO_RESULT=$(fio --name=randread --ioengine=libaio --iodepth=32 --rw=randread \
          --bs=4k --direct=1 --size=1G --runtime=30 --gtod_reduce=1 2>/dev/null |
          grep "IOPS=" | head -1 | grep -oP 'IOPS=\K[0-9]+')
        RESULTS[disk_iops]=${FIO_RESULT:-0}
        echo "    Random Read IOPS: ''${FIO_RESULT:-N/A}"
        
        # Latency Test
        echo -e "\n>>> Latency Test (cyclictest if available)..."
        if command -v cyclictest &> /dev/null; then
          LATENCY=$(cyclictest -l10000 -m -Sp90 -i200 -h400 2>/dev/null | 
            grep "Avg Latencies" | awk '{print $4}')
          RESULTS[avg_latency_us]=${LATENCY:-0}
          echo "    Avg Latency: ''${LATENCY:-N/A} us"
        else
          echo "    cyclictest not available - skipping"
        fi
        
        # Thermal reading
        echo -e "\n>>> Thermal State..."
        for temp_file in /sys/class/thermal/thermal_zone*/temp; do
          if [ -r "$temp_file" ]; then
            zone=$(basename $(dirname $temp_file))
            temp=$(cat "$temp_file" 2>/dev/null | awk '{print $1/1000}')
            echo "    $zone: ''${temp}°C"
          fi
        done
        
        # Generate JSON output
        cat > "$RESULT_FILE" << EOF
        {
          "profile": "$PROFILE",
          "timestamp": "$TIMESTAMP",
          "kernel": "$(uname -r)",
          "results": {
            "cpu_events_per_sec": ${RESULTS[cpu_events_per_sec]:-0},
            "mem_read_mib_sec": "${RESULTS[mem_read_mib_sec]:-0}",
            "mem_write_mib_sec": "${RESULTS[mem_write_mib_sec]:-0}",
            "disk_iops": ${RESULTS[disk_iops]:-0},
            "avg_latency_us": ${RESULTS[avg_latency_us]:-0}
          }
        }
        EOF
        
        echo -e "\n═══════════════════════════════════════════════════════════"
        echo "  Results saved to: $RESULT_FILE"
        echo "═══════════════════════════════════════════════════════════"
      '')
      
      (pkgs.writeShellScriptBin "x15-thermal-stress-test" ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail
        
        DURATION="''${1:-300}"
        CORES=$(nproc)
        
        echo "═══════════════════════════════════════════════════════════"
        echo "  Thermal Stress Test - Duration: ''${DURATION}s"
        echo "  Cores: $CORES | Profile: ${cfg.profile}"
        echo "═══════════════════════════════════════════════════════════"
        
        cleanup() {
          echo -e "\n>>> Stopping stress test..."
          pkill -f stress-ng 2>/dev/null || true
          exit 0
        }
        trap cleanup SIGINT SIGTERM
        
        # Start monitoring in background
        (
          echo "time,cpu_temp,fan_rpm,cpu_freq,throttle" > /tmp/thermal_log.csv
          for ((i=0; i<DURATION; i+=2)); do
            TEMP=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -1 | awk '{print $1/1000}')
            FAN=$(cat /sys/class/hwmon/hwmon*/fan1_input 2>/dev/null | head -1 || echo 0)
            FREQ=$(cat /proc/cpuinfo | grep "cpu MHz" | head -1 | awk '{print $4}')
            THROTTLE=$(cat /sys/devices/system/cpu/cpu0/thermal_throttle/throttle_count 2>/dev/null || echo 0)
            echo "$i,$TEMP,$FAN,$FREQ,$THROTTLE" >> /tmp/thermal_log.csv
            sleep 2
          done
        ) &
        MONITOR_PID=$!
        
        # Run stress test
        echo ">>> Starting CPU stress (all cores)..."
        stress-ng --cpu $CORES --cpu-method all --timeout ''${DURATION}s --metrics-brief 2>&1 &
        STRESS_PID=$!
        
        # Wait for completion
        wait $STRESS_PID 2>/dev/null || true
        kill $MONITOR_PID 2>/dev/null || true
        
        echo -e "\n>>> Thermal data saved to: /tmp/thermal_log.csv"
        echo ">>> Summary:"
        tail -n +2 /tmp/thermal_log.csv | awk -F',' '
          NR==1 {min_temp=max_temp=$2; sum_temp=0; count=1}
          {
            sum_temp+=$2; count++
            if ($2 < min_temp) min_temp=$2
            if ($2 > max_temp) max_temp=$2
          }
          END {
            print "  Min Temp: " min_temp "°C"
            print "  Max Temp: " max_temp "°C"  
            print "  Avg Temp: " sum_temp/count "°C"
          }'
      '')
      
      (pkgs.writeShellScriptBin "x15-system-optimizer" ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail
        
        ACTION="''${1:-status}"
        
        case "$ACTION" in
          apply)
            echo ">>> Applying performance optimizations..."
            
            # Drop caches
            echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null
            echo "    [✓] Dropped page cache"
            
            # Compact memory
            echo 1 | sudo tee /proc/sys/vm/compact_memory > /dev/null 2>/dev/null || true
            echo "    [✓] Memory compaction triggered"
            
            # Clear swap
            sudo swapoff -a && sudo swapon -a 2>/dev/null || true
            echo "    [✓] Swap cleared"
            
            # Network optimization
            sudo sysctl -w net.ipv4.tcp_tw_reuse=1 > /dev/null
            echo "    [✓] TCP optimizations applied"
            
            echo ">>> Optimizations complete"
            ;;
            
          status)
            echo "═══════════════════════════════════════════════════════════"
            echo "  System Optimization Status"
            echo "═══════════════════════════════════════════════════════════"
            echo ""
            echo ">>> CPU Information:"
            echo "    Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo N/A)"
            echo "    EPP: $(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null || echo N/A)"
            echo "    Max Freq: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null | awk '{print $1/1000000}') GHz"
            echo ""
            echo ">>> Memory Status:"
            free -h
            echo ""
            echo ">>> Zram Status:"
            zramctl 2>/dev/null || echo "    zramctl not available"
            echo ""
            echo ">>> I/O Scheduler:"
            for dev in /sys/block/nvme*/queue/scheduler 2>/dev/null; do
              [ -r "$dev" ] && echo "    $(basename $(dirname $dev)): $(cat $dev)"
            done
            ;;
            
          *)
            echo "Usage: x15-system-optimizer {apply|status}"
            exit 1
            ;;
        esac
      '')
    ];
  };
}
