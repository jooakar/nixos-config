{
  description = "My config :D";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
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
    {
      darwinConfigurations.maxos = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit inputs;
          inherit nix-homebrew;
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
