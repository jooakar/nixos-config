{
  description = "My config :D";

  inputs = {
    nixpkgs-unstable-darwin.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable-darwin.url = "github:nixos/nixpkgs/nixpkgs-25.05-darwin";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs-unstable-darwin";
    };

    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable-darwin";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs-unstable-darwin";
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
    in
    {
      darwinConfigurations.maxos = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit inputs;
          inherit nix-homebrew;
          inherit flakeRoot;
        };
        modules = [
          ./modules/fonts.nix
          ./modules/packages.nix
          ./modules/home-manager
          ./modules/darwin
        ];
      };
    };
}
