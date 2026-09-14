{
  description = "My config :D";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      nix-homebrew,
      ...
    }@inputs:

    let
      flakeRoot = ./.;

      # Tooling for the terraform half of this repo.
      devSystems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs devSystems;
      mkDarwin =
        {
          profile,
          hostname,
          username,
          email,
        }:
        nix-darwin.lib.darwinSystem {
          specialArgs = {
            inherit inputs;
            inherit nix-homebrew;
            inherit flakeRoot;
            inherit profile;
            inherit hostname;
            inherit username;
            inherit email;
            isDarwin = true;
          };
          modules = [
            ./modules/fonts.nix
            ./modules/packages/common.nix
            ./modules/packages/workstation.nix
            ./modules/home-manager
            ./modules/darwin
          ];
        };
      # The host file under ./hosts is the only place that picks modules.
      mkNixos =
        {
          hostname,
          username,
          email,
          diskDevice,
        }:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit inputs;
            inherit flakeRoot;
            inherit hostname;
            inherit username;
            inherit email;
            inherit diskDevice;
            isDarwin = false;
          };
          modules = [ (./hosts + "/${hostname}.nix") ];
        };
    in
    {
      darwinConfigurations.maxos = mkDarwin {
        profile = "personal";
        hostname = "maxos";
        username = "joona";
        email = "joona.karkkainen@gmail.com";
      };
      darwinConfigurations.maxos-work = mkDarwin {
        profile = "work";
        hostname = "maxos-work";
        username = "jook";
        email = "jook@netlight.com";
      };
      nixosConfigurations.vps = mkNixos {
        hostname = "vps";
        username = "joona";
        email = "joona.karkkainen@gmail.com";
        diskDevice = "/dev/vda";
      };
      nixosConfigurations.carbon = mkNixos {
        hostname = "carbon";
        username = "joona";
        email = "joona.karkkainen@gmail.com";
        diskDevice = "/dev/nvme0n1";
      };

      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true; # terraform is BSL
          };
        in
        {
          default = pkgs.mkShell {
            packages = [
              inputs.agenix.packages.${system}.default
              pkgs.terraform
              pkgs.age
              pkgs.upcloud-cli
            ];
            shellHook = ''
              export RULES="$PWD/secrets/secrets.nix"
            '';
          };
        }
      );
    };
}
