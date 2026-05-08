{
  description = "Performance-first modular NixOS + Home Manager setup for Colorful X15 XS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland = {
      url = "github:hyprwm/Hyprland/v0.54.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    quickshell = {
      url = "git+https://git.outfoxxed.me/quickshell/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    matugen = {
      url = "github:InioX/matugen";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      hyprland,
      stylix,
      ...
    }:
    let
      lib = nixpkgs.lib;
      systems = [ "x86_64-linux" ];
      forAllSystems = lib.genAttrs systems;

      overlays = {
        default = final: prev: {
          zen-browser = inputs.zen-browser.packages.${prev.stdenv.hostPlatform.system}.default;
          matugen = inputs.matugen.packages.${prev.stdenv.hostPlatform.system}.default;
        };
      };

      mkSystem =
        {
          system,
          hostname,
        }:
        lib.nixosSystem {
          inherit system;

          specialArgs = {
            inherit inputs hostname;
          };

          modules = [
            (
              { ... }:
              {
                networking.hostName = hostname;
                nixpkgs.overlays = [
                  self.overlays.default
                ];
              }
            )
            ./hosts/x15xs
            stylix.nixosModules.stylix
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "hm-backup";
                extraSpecialArgs = {
                  inherit inputs hostname;
                };
                users.asura = import ./users/asura;
              };
            }
          ];
        };

      mkIso =
        { system }:
        lib.nixosSystem {
          inherit system;

          specialArgs = {
            inherit inputs;
            hostname = "x15xs-iso";
          };

          modules = [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares.nix"
            (
              { pkgs, ... }:
              {
                networking.hostName = "x15xs-iso";
                nixpkgs.config.allowUnfree = true;
                nixpkgs.overlays = [
                  self.overlays.default
                ];

                image.fileName = "x15xs-rescue-installer.iso";

                isoImage = {
                  volumeID = "X15XS_RESCUE";
                  makeEfiBootable = true;
                  makeUsbBootable = true;
                  squashfsCompression = "zstd -Xcompression-level 6";
                };

                boot.zfs.forceImportRoot = false;

                environment.etc."nixos".source = self;

                environment.systemPackages = with pkgs; [
                  git
                  vim
                  neovim
                  curl
                  wget
                  pciutils
                  usbutils
                  efibootmgr
                  sbctl
                  btrfs-progs
                  gptfdisk
                  parted
                  rsync
                  ripgrep
                  jq
                  yq
                  tree
                  tmux
                ];

                networking.networkmanager.enable = true;
                services.openssh.enable = true;

                nix.settings = {
                  experimental-features = [
                    "nix-command"
                    "flakes"
                  ];
                  trusted-users = [
                    "root"
                    "@wheel"
                  ];
                };

                users.users.nixos.extraGroups = [
                  "networkmanager"
                  "wheel"
                ];

                system.stateVersion = "26.05";
              }
            )
          ];
        };
    in
    {
      inherit overlays;

      nixosConfigurations = {
        x15xs = mkSystem {
          system = "x86_64-linux";
          hostname = "x15xs";
        };

        x15xsIso = mkIso {
          system = "x86_64-linux";
        };
      };

      packages = forAllSystems (system: {
        x15xs-iso = self.nixosConfigurations.x15xsIso.config.system.build.isoImage;
      });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
