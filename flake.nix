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

    illogical-flake = {
      url = "github:soymou/illogical-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.quickshell.follows = "quickshell";
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
            ./configuration.nix
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
                sharedModules = [
                  ./home/illogical-impulse-module.nix
                ];
                users.asura = import ./home/home.nix;
              };
            }
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
      };

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
