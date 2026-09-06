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

    disko = {
      url = "github:nix-community/disko";
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
            ./modules/packages.nix
            ./modules/home-manager
            ./modules/darwin
          ];
        };
      mkNixos =
        {
          profile,
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
            inherit profile;
            inherit hostname;
            inherit username;
            inherit email;
            inherit diskDevice;
            isDarwin = false;
          };
          modules = [
            ./modules/packages.nix
            ./modules/home-manager
            ./modules/nixos
          ];
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
        profile = "server";
        hostname = "vps";
        username = "joona";
        email = "joona.karkkainen@gmail.com";
        diskDevice = "/dev/vda";
      };
    };
}
