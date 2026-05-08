{ lib, ... }:

{
  options.modules.hardware.x15xs = {
    enable = lib.mkEnableOption "Colorful X15 XS hardware inventory";

    cpu = {
      model = lib.mkOption {
        type = lib.types.str;
        default = "Intel Core i5-12500H";
        readOnly = true;
        description = "Detected CPU model.";
      };
      threads = lib.mkOption {
        type = lib.types.int;
        default = 16;
        readOnly = true;
        description = "Detected logical CPU thread count.";
      };
    };

    graphics = {
      intelBusId = lib.mkOption {
        type = lib.types.str;
        default = "PCI:0:2:0";
        description = "Intel iGPU PRIME bus ID.";
      };
      nvidiaBusId = lib.mkOption {
        type = lib.types.str;
        default = "PCI:1:0:0";
        description = "NVIDIA dGPU PRIME bus ID.";
      };
      nvidiaModel = lib.mkOption {
        type = lib.types.str;
        default = "NVIDIA GA107M GeForce RTX 3050 Mobile";
        readOnly = true;
        description = "Detected NVIDIA GPU model.";
      };
    };

    storage = {
      rootUuid = lib.mkOption {
        type = lib.types.str;
        default = "849c9003-4f3f-4444-9039-6cf885a8f320";
        description = "NixOS root filesystem UUID.";
      };
      bootUuid = lib.mkOption {
        type = lib.types.str;
        default = "BB34-5262";
        description = "Active Limine EFI system partition UUID.";
      };
      windowsEspPartUuid = lib.mkOption {
        type = lib.types.str;
        default = "2e64ad33-87cf-49fc-971a-ef00da61c67b";
        description = "Windows EFI GPT partition UUID on the second NVMe drive.";
      };
    };

    nbfcProfile = lib.mkOption {
      type = lib.types.str;
      default = "Colorful X15 AT 22";
      description = "NBFC profile used for declarative fan control.";
    };
  };
}
