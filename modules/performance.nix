{ config, lib, pkgs, ... }:

let
  cfg = config.modules.performance;
  isMax = cfg.profile == "max";
  isBalanced = cfg.profile == "balanced";
  isCool = cfg.profile == "cool";
in
{
  options.modules.performance = {
    enable = lib.mkEnableOption "performance tuning stack";

    profile = lib.mkOption {
      type = lib.types.enum [
        "max"
        "balanced"
        "cool"
      ];
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
      description = "NBFC profile name used in /etc/nbfc/nbfc.json";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelParams = [
      "preempt=full"
      "threadirqs"
      "mitigations=off"
      "nvidia-drm.modeset=1"
      # Laptop eDP flicker mitigation: PSR/FBC can cause intermittent flashing
      # on some Intel panels, especially at high refresh.
      "i915.enable_psr=0"
      "i915.enable_fbc=0"
      # DC6 is required for correct iGPU runtime PM on Alder Lake hybrid;
      # i915.enable_dc=0 was removed here — restores proper package C-states on AC.
      # Skew hardware timer ticks across cores to reduce lock contention.
      "skew_tick=1"
      # Suppress noisy softlockup detector messages under heavy compile/render load.
      "nosoftlockup"
    ]
    ++ lib.optionals isMax [
      "intel_idle.max_cstate=1"
    ]
    ++ lib.optionals (!isMax) [
      "intel_idle.max_cstate=9"
    ];

    # Load BBR congestion control module at boot (required before sysctl applies).
    boot.kernelModules = [ "tcp_bbr" ];

    boot.kernel.sysctl = {
      # ── Memory ────────────────────────────────────────────────────────────
      "vm.swappiness" = 10;
      "vm.vfs_cache_pressure" = 50;

      # NVMe is fast: start writeback earlier and flush more frequently.
      # Keeps fewer dirty pages in RAM and reduces latency spikes on writes.
      "vm.dirty_background_ratio" = 5;      # default 10
      "vm.dirty_ratio" = 10;                # default 20
      "vm.dirty_writeback_centisecs" = 500; # flush every 5 s (default: 15 s)

      # Disable proactive background compaction — it causes latency spikes
      # with no benefit when RAM is plentiful (16 GB).
      "vm.compaction_proactiveness" = 0;

      # ── CPU / Scheduler ───────────────────────────────────────────────────
      "kernel.numa_balancing" = 0;

      # Autogroup groups shell pipelines/apps into their own sched groups,
      # improving interactive responsiveness under heavy background load.
      "kernel.sched_autogroup_enabled" = 1;

      # ── Networking ────────────────────────────────────────────────────────
      # BBR congestion control: reduces bufferbloat, better throughput on
      # lossy WiFi links. Requires tcp_bbr module (loaded above).
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = "bbr";

      # TCP Fast Open: eliminates a round-trip on repeated connections (3 = client+server).
      "net.ipv4.tcp_fastopen" = 3;

      # Deeper receive queue for WiFi 6E burst traffic.
      "net.core.netdev_max_backlog" = 4096;

      # Larger socket buffers for sustained NVMe/network throughput.
      "net.core.rmem_max" = 16777216;
      "net.core.wmem_max" = 16777216;
      "net.ipv4.tcp_rmem" = "4096 131072 16777216";
      "net.ipv4.tcp_wmem" = "4096 65536 16777216";
    };

    zramSwap = {
      enable = true;
      # zstd compresses ~15-25% better than lz4 on typical workloads with
      # negligible latency overhead on a 12-core CPU. Ideal for a 16 GB laptop.
      algorithm = "zstd";
      memoryPercent = 50;
    };

    services.power-profiles-daemon.enable = false;

    services.tlp = {
      enable = true;
      settings = {
        # Alder Lake on this machine exposes only: performance, powersave.
        CPU_SCALING_GOVERNOR_ON_AC = if isCool then "powersave" else "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        CPU_BOOST_ON_AC = if isCool then 0 else 1;
        CPU_BOOST_ON_BAT = 0;
        CPU_MAX_PERF_ON_AC =
          if isMax then 100
          else if isBalanced then 95
          else 70;
        CPU_MAX_PERF_ON_BAT = if isCool then 45 else 60;
        CPU_ENERGY_PERF_POLICY_ON_AC = if isCool then "power" else "performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
        PLATFORM_PROFILE_ON_AC =
          if isMax then "performance"
          else if isCool then "low-power"
          else "balanced";
        PLATFORM_PROFILE_ON_BAT = "low-power";
        RUNTIME_PM_ON_AC = if isMax then "on" else "auto";
        RUNTIME_PM_ON_BAT = "auto";
        PCIE_ASPM_ON_AC = if isCool then "powersupersave" else "default";
        PCIE_ASPM_ON_BAT = "powersupersave";

        # Kyber I/O scheduler: low-overhead, latency-aware, ideal for NVMe SSDs.
        DISK_IOSCHED = "kyber";
      };
    };

    systemd.oomd.enable = true;

    services.ananicy = {
      enable = true;
      package = pkgs.ananicy-cpp;
      rulesProvider = pkgs.ananicy-cpp;
    };

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "x15-thermals" ''
        #!/usr/bin/env bash
        set -euo pipefail
        echo "Configured profile: ${cfg.profile}"
        echo
        echo "Thermal zones (milli-C):"
        for z in /sys/class/thermal/thermal_zone*; do
          [ -e "$z/type" ] || continue
          printf '  %-20s %s\n' "$(cat "$z/type")" "$(cat "$z/temp" 2>/dev/null || echo n/a)"
        done
        echo
        echo "Top CPU consumers:"
        ps -eo pid,pcpu,pmem,comm,args --sort=-pcpu | head -n 12
        echo
        echo "GPU:"
        nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,power.draw,pstate,memory.used --format=csv,noheader 2>/dev/null || true
      '')
      (pkgs.writeShellScriptBin "x15-power-status" ''
        #!/usr/bin/env bash
        set -euo pipefail
        echo "Configured profile: ${cfg.profile}"
        echo
        tlp-stat -s 2>/dev/null || true
        echo
        echo "CPU governors:"
        cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null | sort -u | tr '\n' ' '; echo
        echo
        echo "I/O schedulers (NVMe):"
        for d in /sys/block/nvme*; do
          [ -e "$d/queue/scheduler" ] || continue
          printf '  %-12s %s\n' "$(basename "$d")" "$(cat "$d/queue/scheduler")"
        done
        echo
        echo "Network:"
        sysctl net.ipv4.tcp_congestion_control net.core.default_qdisc net.ipv4.tcp_fastopen 2>/dev/null || true
        echo
        echo "Ollama service:"
        systemctl is-active ollama 2>/dev/null || true
      '')
    ];

    # TODO: Run `sudo nbfc config --recommend` after first boot and update this profile if needed.
    environment.etc."nbfc/nbfc.json".text = builtins.toJSON {
      SelectedConfigId = cfg.nbfcProfile;
    };

    systemd.services.nbfc_service = {
      description = "Notebook FanControl service";
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.kmod ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.nbfc-linux}/bin/nbfc_service --config-file /etc/nbfc/nbfc.json";
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
}
