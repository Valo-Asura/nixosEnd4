{ config, lib, pkgs, ... }:

let
  cfg = config.modules.boot;
  windowsEspPartUuid = "2e64ad33-87cf-49fc-971a-ef00da61c67b";
  windowsBootManagerPath = "/EFI/Microsoft/Boot/bootmgfw.efi";
  # Live disk layout on this machine:
  #   boot drive / active Limine ESP -> nvme0n1p1 (BB34-5262, PARTUUID 1f3afb71-0cd4-4f31-8138-6ce2b0878e55)
  #   Windows ESP                    -> nvme1n1p1 (D85E-0D8D, PARTUUID ${windowsEspPartUuid})
  #
  # Limine's boot() resource only addresses partitions on the boot drive that
  # contains the active config file. Because Windows is on a different NVMe,
  # target the Windows ESP directly by its GPT partition GUID.
  windowsLimineEntry = ''
    /Windows
      protocol: efi
      path: guid(${windowsEspPartUuid}):${windowsBootManagerPath}
  '';
in
{
  options.modules.boot = {
    enable = lib.mkEnableOption "bootloader and kernel stack";
  };

  config = lib.mkIf cfg.enable {
    boot.kernelPackages = pkgs.linuxPackages_zen;

    boot.loader = {
      grub.enable = false;
      systemd-boot.enable = false;

      efi.canTouchEfiVariables = true;

      limine = {
        enable = true;
        efiSupport = true;
        maxGenerations = 7;
        extraEntries = windowsLimineEntry;
      };
    };
  };
}
