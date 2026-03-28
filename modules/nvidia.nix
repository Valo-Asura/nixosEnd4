{ config, lib, ... }:

let
  cfg = config.modules.nvidia;
in
{
  options.modules.nvidia = {
    enable = lib.mkEnableOption "NVIDIA PRIME offload";

    intelBusId = lib.mkOption {
      type = lib.types.str;
      default = "PCI:0:2:0";
      description = "PRIME Intel iGPU PCI bus ID";
    };

    nvidiaBusId = lib.mkOption {
      type = lib.types.str;
      default = "PCI:1:0:0";
      description = "PRIME NVIDIA dGPU PCI bus ID";
    };
  };

  config = lib.mkIf cfg.enable {
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.graphics.enable = true;

    hardware.nvidia = {
      open = true;
      modesetting.enable = true;
      nvidiaSettings = true;

      powerManagement.finegrained = true;

      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };

        # TODO: Verify bus IDs with `lspci | grep -E "VGA|3D"` before first boot.
        intelBusId = cfg.intelBusId;
        nvidiaBusId = cfg.nvidiaBusId;
      };
    };
  };
}
