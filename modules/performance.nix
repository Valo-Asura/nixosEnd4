{ config, lib, pkgs, ... }:

let
  cfg = config.modules.performance;
  isMax = cfg.profile == "max";
  isBalanced = cfg.profile == "balanced";
  isCool = cfg.profile == "cool";

  # ── Custom NBFC fan curve for Colorful X15 AT 22 ──────────────────────────
  # Smoother than upstream: starts quiet, ramps progressively, avoids
  # constant full-blast by giving more headroom before hitting 100%.
  # Critical is set to 90°C (BIOS emergency kicks in at ~95°C).
  nbfcConfig = builtins.toJSON {
    NotebookModel = "Colorful X15 AT 22";
    Author = "nixos-asura";
    EcPollInterval = 1000; # Poll every 1 s (upstream: 100 ms — needless CPU wake)
    ReadWriteWords = false;
    CriticalTemperature = 90;
    CriticalTemperatureOffset = 5;
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
        TemperatureThresholds = [
          # <= 40°C: fans off / silent idle
          { UpThreshold = 40; DownThreshold = 0;  FanSpeed = 0.0; }
          # 40-55°C: low hum — enough for passive + a little airflow
          { UpThreshold = 55; DownThreshold = 38; FanSpeed = 20.0; }
          # 55-65°C: moderate — typical sustained load
          { UpThreshold = 65; DownThreshold = 50; FanSpeed = 40.0; }
          # 65-72°C: active — gaming / compiling
          { UpThreshold = 72; DownThreshold = 60; FanSpeed = 65.0; }
          # 72-80°C: aggressive — heavy sustained load
          { UpThreshold = 80; DownThreshold = 68; FanSpeed = 85.0; }
          # > 80°C: full blast — thermal emergency
          { UpThreshold = 90; DownThreshold = 75; FanSpeed = 100.0; }
        ];
        FanSpeedPercentageOverrides = [
          {
            FanSpeedPercentage = 100.0;
            FanSpeedValue = 100;
            TargetOperation = "ReadWrite";
          }
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
        Description = "Override";
      }
    ];
  };
in
{
  options.modules.performance = {
    enable = lib.mkEnableOption "performance tuning stack";

    profile = lib.mkOption {
      type = lib.types.enum [ "max" "balanced" "cool" ];
      default = "balanced";
      description = ''
        Thermal and power profile:
        - max: highest performance, hottest idle/load behavior
        - balanced: reduced heat with strong performance
        - cool: lowest thermals/noise, reduced peak performance
      '';
    };

    nbfcProfile = lib.mkOption {
      type = lib.types.str;
      default = "Colorful X15 AT 22";
      description = "NBFC profile name (used in display; config is now declarative).";
    };
  };

  config = lib.mkIf cfg.enable {

    # ── Kernel parameters ─────────────────────────────────────────────────────
    boot.kernelParams = [
      "preempt=full"   # Full preemption — best desktop latency
      "threadirqs"     # Force threaded IRQs — reduces IRQ latency jitter
      "mitigations=off" # Disable Spectre/Meltdown mitigations (trusted single-user)
      "nvidia-drm.modeset=1"

      # Intel eDP: PSR causes flickering on some Alder Lake panels at high refresh.
      "i915.enable_psr=0"
      "i915.enable_fbc=0"
      # Do NOT set i915.enable_dc=0 — DC6 is needed for iGPU runtime PM.
      # Removing it restores proper C10 package states on AC.

      # Reduce cross-core timer lock contention on hybrid CPUs.
      "skew_tick=1"

      # Suppress noisy softlockup messages during heavy compile/render loads.
      "nosoftlockup"
    ]
    ++ lib.optionals isMax  [ "intel_idle.max_cstate=1" ]
    ++ lib.optionals (!isMax) [ "intel_idle.max_cstate=9" ];

    # Load BBR congestion control module at early boot.
    boot.kernelModules = [ "tcp_bbr" ];

    # ── Kernel sysctl ─────────────────────────────────────────────────────────
    boot.kernel.sysctl = {

      # ── Memory ──────────────────────────────────────────────────────────────
      # Low swappiness: keep working set in RAM; only offload cold pages to zram.
      "vm.swappiness" = 10;
      # Reduce pressure to drop dentry/inode cache; good for dev workloads.
      "vm.vfs_cache_pressure" = 50;

      # NVMe writeback tuning: flush smaller, more frequent batches.
      # Reduces peak dirty-memory spikes and cuts worst-case write latency.
      "vm.dirty_background_ratio" = 5;      # Start async writeback at 5% RAM dirty
      "vm.dirty_ratio" = 10;                # Block new writes at 10% RAM dirty
      "vm.dirty_writeback_centisecs" = 500; # Flush every 5 s (kernel default: 15 s)
      "vm.dirty_expire_centisecs" = 3000;   # Expire dirty pages after 30 s

      # Disable proactive background compaction on 16 GB machines.
      # It causes latency spikes with no real benefit when RAM is plentiful.
      "vm.compaction_proactiveness" = 0;

      # Reduce minimum free memory held in reserve (default is too conservative).
      # 64 MB is sufficient on 16 GB with zram as a safety net.
      "vm.min_free_kbytes" = 65536;

      # ── CPU / Scheduler ──────────────────────────────────────────────────────
      # Disable NUMA balancing (single NUMA node on this CPU).
      "kernel.numa_balancing" = 0;
      # Autogroup: shell pipelines and app groups get their own sched group,
      # keeping interactive latency low even under background compile load.
      "kernel.sched_autogroup_enabled" = 1;
      # Increase migration cost threshold — reduces cross-core cache thrashing
      # on the P-core / E-core hybrid topology of the i5-12500H.
      "kernel.sched_migration_cost_ns" = 500000;

      # ── Networking ──────────────────────────────────────────────────────────
      # BBR v1 congestion control: lower bufferbloat on WiFi 6 / fast links.
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = "bbr";

      # TCP Fast Open (3 = client + server): saves a round-trip on retries.
      "net.ipv4.tcp_fastopen" = 3;

      # Larger receive queue for WiFi 6 burst / USB-C dock scenarios.
      "net.core.netdev_max_backlog" = 4096;

      # Socket buffer auto-tuning ceilings (16 MiB).
      "net.core.rmem_max" = 16777216;
      "net.core.wmem_max" = 16777216;
      "net.ipv4.tcp_rmem" = "4096 131072 16777216";
      "net.ipv4.tcp_wmem" = "4096 65536 16777216";
    };

    # ── Zram swap ─────────────────────────────────────────────────────────────
    zramSwap = {
      enable = true;
      # zstd: ~15-25 % better compression than lz4 at negligible CPU cost
      # on a 12-core CPU. Ideal for keeping 16 GB feeling like 20 GB.
      algorithm = "zstd";
      memoryPercent = 50;   # 8 GB compressed swap headroom
      priority = 100;       # Always prefer zram over disk swap
    };

    # ── TLP power management ─────────────────────────────────────────────────
    services.power-profiles-daemon.enable = false;

    services.tlp = {
      enable = true;
      settings = {
        # Intel pstate HWP governor selection.
        CPU_SCALING_GOVERNOR_ON_AC  = if isCool then "powersave" else "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

        # Energy Performance Preference — the real lever for HWP on Alder Lake.
        CPU_ENERGY_PERF_POLICY_ON_AC  = if isCool then "balance_power" else "performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

        CPU_BOOST_ON_AC  = if isCool then 0 else 1;
        CPU_BOOST_ON_BAT = 0;

        CPU_MAX_PERF_ON_AC =
          if isMax then 100 else if isBalanced then 95 else 70;
        CPU_MAX_PERF_ON_BAT = if isCool then 45 else 60;

        PLATFORM_PROFILE_ON_AC =
          if isMax then "performance" else if isCool then "low-power" else "balanced";
        PLATFORM_PROFILE_ON_BAT = "low-power";

        RUNTIME_PM_ON_AC  = if isMax then "on" else "auto";
        RUNTIME_PM_ON_BAT = "auto";

        PCIE_ASPM_ON_AC  = if isCool then "powersupersave" else "default";
        PCIE_ASPM_ON_BAT = "powersupersave";

        # Kyber I/O scheduler: latency-aware, low-overhead for NVMe SSDs.
        DISK_IOSCHED = "kyber";

        # USB autosuspend on battery; keep awake on AC for peripherals.
        USB_AUTOSUSPEND = 0;

        # S2idle (modern standby) is configured via mem_sleep_default below.
        MEM_SLEEP_ON_BAT = "deep";
        MEM_SLEEP_ON_AC  = "deep";
      };
    };

    # ── Intel thermald ────────────────────────────────────────────────────────
    # Works alongside TLP: TLP controls governors/EPP, thermald controls
    # thermal throttling via MSR / RAPL when temps approach critical levels.
    # They do not conflict as they manage different layers.
    services.thermald.enable = true;

    # ── systemd-oomd: memory pressure protection ──────────────────────────────
    systemd.oomd = {
      enable = true;
      # Kill memory-hungry cgroups before the kernel OOM killer fires.
      enableRootSlice = true;
      enableSystemSlice = true;
      enableUserSlices = true;
    };

    # Put nix-daemon builds in their own slice so OOM pressure from large
    # builds (e.g. rebuilding LLVM) gets handled without killing the desktop.
    systemd.slices."nix-daemon" = {
      sliceConfig = {
        ManagedOOMMemoryPressure = "kill";
        ManagedOOMMemoryPressureLimit = "60%";
      };
    };
    systemd.services.nix-daemon.serviceConfig.Slice = "nix-daemon.slice";

    # ── Ananicy-cpp process priority daemon ───────────────────────────────────
    services.ananicy = {
      enable = true;
      package = pkgs.ananicy-cpp;
      rulesProvider = pkgs.ananicy-cpp;
    };

    # ── Fan control: custom NBFC curve ───────────────────────────────────────
    # Smoother and quieter than upstream "Colorful X15 AT 22" config:
    # - Polls EC every 1 s instead of 100 ms (10× fewer wakeups)
    # - Fan off below 40°C for silent idle
    # - Progressive ramp with 5°C hysteresis on each step
    # - Full-blast threshold raised to 80°C (upstream: 76°C)
    # - Critical raised to 90°C (BIOS emergency kicks in at ~95°C)
    environment.etc."nbfc/nbfc.json".text = nbfcConfig;

    systemd.services.nbfc_service = {
      description = "Notebook FanControl service";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-udevd.service" ];
      path = [ pkgs.kmod ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.nbfc-linux}/bin/nbfc_service --config-file /etc/nbfc/nbfc.json";
        Restart = "on-failure";
        RestartSec = 3;
        # Harden: fan daemon only needs minimal capabilities.
        CapabilityBoundingSet = [ "CAP_SYS_RAWIO" "CAP_DAC_OVERRIDE" ];
        NoNewPrivileges = false; # needs rawio
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ "/etc/nbfc" "/run" "/sys" "/dev/ec" "/dev/port" ];
      };
    };

    # ── Diagnostic utilities ─────────────────────────────────────────────────
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "x15-thermals" ''
        #!/usr/bin/env bash
        set -euo pipefail
        echo "=== Profile: ${cfg.profile} ==="
        echo
        echo "CPU Temps (milli-C → °C):"
        for z in /sys/class/hwmon/hwmon*/; do
          name=$(cat "$z/name" 2>/dev/null || true)
          for t in "$z"temp*_input; do
            [ -e "$t" ] || continue
            label=$(cat "''${t%_input}_label" 2>/dev/null || basename "$t")
            val=$(cat "$t" 2>/dev/null || echo 0)
            printf "  %-20s %s °C\n" "[$name] $label" "$((val / 1000))"
          done
        done
        echo
        echo "Fan speeds:"
        for z in /sys/class/hwmon/hwmon*/; do
          for f in "$z"fan*_input; do
            [ -e "$f" ] || continue
            name=$(cat "$(dirname "$f")/name" 2>/dev/null)
            label=$(cat "''${f%_input}_label" 2>/dev/null || basename "$f")
            printf "  %-20s %s RPM\n" "[$name] $label" "$(cat "$f")"
          done
        done
        echo
        echo "EPP:"
        cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference
        echo
        echo "Top consumers:"
        ps -eo pid,pcpu,pmem,comm --sort=-pcpu | head -n 10
        echo
        echo "GPU:"
        nvidia-smi --query-gpu=name,temp.gpu,utilization.gpu,power.draw,pstate,memory.used \
          --format=csv,noheader 2>/dev/null || echo "(nvidia-smi unavailable)"
      '')

      (pkgs.writeShellScriptBin "x15-power-status" ''
        #!/usr/bin/env bash
        set -euo pipefail
        echo "=== Profile: ${cfg.profile} ==="
        echo
        tlp-stat -s 2>/dev/null || true
        echo
        echo "CPU governors:"
        cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null \
          | sort -u | tr '\n' ' '; echo
        echo
        echo "CPU EPP:"
        cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference
        echo
        echo "I/O schedulers (NVMe):"
        for d in /sys/block/nvme*; do
          [ -e "$d/queue/scheduler" ] || continue
          printf "  %-12s %s\n" "$(basename "$d")" "$(cat "$d/queue/scheduler")"
        done
        echo
        echo "Zram:"
        cat /proc/swaps
        echo
        echo "Network:"
        sysctl net.ipv4.tcp_congestion_control net.core.default_qdisc \
              net.ipv4.tcp_fastopen 2>/dev/null || true
        echo
        echo "Memory:"
        free -h
        echo
        echo "NBFC fan service:"
        systemctl is-active nbfc_service 2>/dev/null || true
        echo
        echo "Ollama:"
        systemctl is-active ollama 2>/dev/null || true
      '')
    ];
  };
}
