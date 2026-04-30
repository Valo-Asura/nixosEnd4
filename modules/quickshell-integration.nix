# ═══════════════════════════════════════════════════════════════════════════════
# NixOS Quickshell Integration Module
# ═══════════════════════════════════════════════════════════════════════════════
# Integrates real-time system monitoring into Quickshell bar
# Provides ResourceWidget for CPU/GPU/Fan/Memory display
# ═══════════════════════════════════════════════════════════════════════════════

{ config, lib, pkgs, ... }:

let
  cfg = config.modules.quickshellIntegration;
  
  # Path to the ResourceWidget QML file
  resourceWidgetPath = 
    if cfg.customWidgetPath != null then cfg.customWidgetPath
    else "${toString ./.}/home/desktop/end4/overrides/ResourceWidget.qml";

  # Python helper for data aggregation
  quickshellDataProvider = pkgs.writeScriptBin "x15-quickshell-provider" ''
    #!${pkgs.python3.withPackages (ps: with ps; [
      ps.psutil
    ])}/bin/python3
    
    import os
    import sys
    import json
    import time
    from pathlib import Path
    
    DATA_DIR = Path(os.environ.get('XDG_RUNTIME_DIR', '/tmp')) / 'x15-hwmon'
    
    def get_cpu_info():
        """Get CPU information using psutil"""
        try:
            import psutil
            
            # CPU temperature
            temps = psutil.sensors_temperatures()
            cpu_temp = 0
            if 'coretemp' in temps:
                cpu_temp = max(t.current for t in temps['coretemp'])
            elif 'acpitz' in temps:
                cpu_temp = temps['acpitz'][0].current
            
            # CPU usage and frequency
            cpu_percent = psutil.cpu_percent(interval=0.1)
            cpu_freq = psutil.cpu_freq()
            
            # Load average
            load1, load5, load15 = os.getloadavg()
            
            return {
                'temperature': cpu_temp,
                'usage_percent': cpu_percent,
                'frequency': {
                    'current': cpu_freq.current if cpu_freq else 0,
                    'min': cpu_freq.min if cpu_freq else 0,
                    'max': cpu_freq.max if cpu_freq else 0
                },
                'load': {
                    '1min': load1,
                    '5min': load5,
                    '15min': load15
                },
                'core_count': psutil.cpu_count()
            }
        except Exception as e:
            return {
                'temperature': 0,
                'usage_percent': 0,
                'frequency': {'current': 0, 'min': 0, 'max': 0},
                'load': {'1min': 0, '5min': 0, '15min': 0},
                'error': str(e)
            }
    
    def get_memory_info():
        """Get memory information"""
        try:
            import psutil
            mem = psutil.virtual_memory()
            swap = psutil.swap_memory()
            
            return {
                'total': mem.total / (1024 * 1024),  # MiB
                'available': mem.available / (1024 * 1024),
                'used': mem.used / (1024 * 1024),
                'free': mem.free / (1024 * 1024),
                'percent': mem.percent,
                'buffers': mem.buffers / (1024 * 1024),
                'cached': mem.cached / (1024 * 1024),
                'swap_total': swap.total / (1024 * 1024),
                'swap_used': swap.used / (1024 * 1024),
                'swap_percent': swap.percent
            }
        except Exception as e:
            return {'error': str(e)}
    
    def get_gpu_info():
        """Get GPU information via nvidia-smi"""
        import subprocess
        try:
            result = subprocess.run(
                ['nvidia-smi', '--query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw',
                 '--format=csv,noheader,nounits'],
                capture_output=True, text=True, timeout=2
            )
            if result.returncode == 0:
                parts = result.stdout.strip().split(',')
                if len(parts) >= 4:
                    return {
                        'temperature': float(parts[0].strip()),
                        'utilization': float(parts[1].strip()),
                        'memory_used': float(parts[2].strip()),
                        'memory_total': float(parts[3].strip()),
                        'power_draw': float(parts[4].strip()) if len(parts) > 4 else 0
                    }
        except:
            pass
        return {'temperature': 0, 'utilization': 0, 'memory_used': 0, 'memory_total': 0}
    
    def get_fan_info():
        """Get fan speeds from hwmon"""
        fans = {}
        hwmon_path = Path('/sys/class/hwmon')
        
        if hwmon_path.exists():
            for hwmon in hwmon_path.glob('hwmon*'):
                try:
                    name_file = hwmon / 'name'
                    if name_file.exists():
                        name = name_file.read_text().strip()
                        
                        for fan_file in hwmon.glob('fan*_input'):
                            label_file = fan_file.with_suffix('').with_name(fan_file.stem + '_label')
                            label = label_file.read_text().strip() if label_file.exists() else fan_file.stem
                            speed = int(fan_file.read_text().strip())
                            fans[f"{name}_{label}"] = speed
                except:
                    pass
        
        return fans
    
    def get_disk_info():
        """Get disk I/O statistics"""
        try:
            import psutil
            io = psutil.disk_io_counters()
            return {
                'read_bytes': io.read_bytes,
                'write_bytes': io.write_bytes,
                'read_count': io.read_count,
                'write_count': io.write_count
            }
        except:
            return {}
    
    def get_network_info():
        """Get network I/O statistics"""
        try:
            import psutil
            net = psutil.net_io_counters()
            return {
                'bytes_sent': net.bytes_sent,
                'bytes_recv': net.bytes_recv,
                'packets_sent': net.packets_sent,
                'packets_recv': net.packets_recv
            }
        except:
            return {}
    
    def collect_all():
        """Collect all metrics"""
        return {
            'timestamp': time.time(),
            'cpu': get_cpu_info(),
            'memory': get_memory_info(),
            'gpu': get_gpu_info(),
            'fans': get_fan_info(),
            'disk': get_disk_info(),
            'network': get_network_info()
        }
    
    def main():
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        
        if len(sys.argv) > 1 and sys.argv[1] == 'daemon':
            # Run as daemon
            while True:
                data = collect_all()
                json_file = DATA_DIR / 'hwmon.json'
                json_file.write_text(json.dumps(data, indent=2))
                time.sleep(2)
        else:
            # Single run output
            data = collect_all()
            print(json.dumps(data, indent=2))
    
    if __name__ == '__main__':
        main()
  '';

in
{
  # ═══════════════════════════════════════════════════════════════════════════
  # OPTIONS
  # ═══════════════════════════════════════════════════════════════════════════
  
  options.modules.quickshellIntegration = {
    enable = lib.mkEnableOption "Quickshell resource monitoring integration";
    
    updateInterval = lib.mkOption {
      type = lib.types.int;
      default = 2000;
      description = "Widget update interval in milliseconds";
    };
    
    showGpu = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show GPU temperature in widget";
    };
    
    showFan = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show fan speed in widget";
    };
    
    customWidgetPath = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to custom ResourceWidget.qml file";
    };
  };

  # ═══════════════════════════════════════════════════════════════════════════
  # CONFIGURATION
  # ═══════════════════════════════════════════════════════════════════════════
  
  config = lib.mkIf cfg.enable {
    
    # ── Quickshell Data Provider Service ─────────────────────────────────────
    systemd.user.services.x15-quickshell-provider = {
      description = "X15 Quickshell Data Provider";
      wantedBy = [ "default.target" ];
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${quickshellDataProvider}/bin/x15-quickshell-provider daemon";
        Restart = "on-failure";
        RestartSec = 5;
        
        # Resource access
        PrivateTmp = false;
        ProtectSystem = false;
        ProtectHome = false;
      };
    };
    
    # ── Environment Packages ─────────────────────────────────────────────────
    home.packages = [
      quickshellDataProvider
      
      (pkgs.writeShellScriptBin "quickshell-reload" ''
        #!${pkgs.bash}/bin/bash
        # Reload Quickshell configuration
        
        if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
          echo ">>> Reloading Quickshell..."
          
          # Kill existing quickshell
          pkill -f "quickshell" 2>/dev/null || true
          
          # Restart (usually triggered by session manager)
          sleep 1
          
          # Check status
          if pgrep -f "quickshell" > /dev/null; then
            echo "    [✓] Quickshell reloaded"
          else
            echo "    [!] Quickshell not running - may need manual restart"
          fi
        else
          echo "    [!] Not in Hyprland session"
        fi
      '')
    ];
    
    # ── Home Manager Configuration ───────────────────────────────────────────
    home.file = lib.mkIf cfg.enable {
      
      # Copy ResourceWidget to Quickshell config directory
      ".config/quickshell/ii/modules/ii/bar/ResourceWidget.qml".source = 
        if cfg.customWidgetPath != null then cfg.customWidgetPath
        else ./home/desktop/end4/overrides/ResourceWidget.qml;
      
      # Configuration override for end4 settings
      ".config/quickshell/ii/services/ResourceService.qml".text = ''
        pragma Singleton
        import Quickshell
        import Quickshell.Io
        import QtQuick
        
        Singleton {
            id: resourceService
            
            property var cpuData: ({temp: 0, usage: 0, freq: 0, load: "0.00"})
            property var memoryData: ({used: 0, total: 1, percent: 0})
            property var gpuData: ({temp: 0, usage: 0})
            property var fanData: ({speed: 0})
            
            property string dataPath: "/run/user/" + Quickshell.userId + "/x15-hwmon/hwmon.json"
            
            Timer {
                interval: ${toString cfg.updateInterval}
                running: true
                repeat: true
                onTriggered: dataProcess.running = true
            }
            
            Process {
                id: dataProcess
                command: ["cat", resourceService.dataPath]
                
                stdout: SplitParser {
                    onRead: data => {
                        try {
                            var json = JSON.parse(data)
                            
                            // Update CPU data
                            if (json.cpu) {
                                cpuData = {
                                    temp: json.cpu.temperature || 0,
                                    usage: (json.cpu.load?.["1min"] || 0) * 100 / (json.cpu.core_count || 12),
                                    freq: json.cpu.frequency?.avg || 0,
                                    load: (json.cpu.load?.["1min"] || 0).toFixed(2)
                                }
                            }
                            
                            // Update memory data
                            if (json.memory) {
                                memoryData = {
                                    used: json.memory.used || 0,
                                    total: json.memory.total || 1,
                                    percent: json.memory.percent || 0
                                }
                            }
                            
                            // Update GPU data
                            if (json.gpu) {
                                gpuData = {
                                    temp: json.gpu.temperature || 0,
                                    usage: json.gpu.utilization || 0
                                }
                            }
                            
                            // Update fan data
                            if (json.fans) {
                                var firstFan = Object.values(json.fans)[0]
                                fanData = { speed: firstFan || 0 }
                            }
                            
                        } catch (e) {
                            console.log("ResourceService: Failed to parse data")
                        }
                    }
                }
            }
        }
      '';
    };
  };
}
