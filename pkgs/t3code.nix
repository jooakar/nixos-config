# The server has to match the desktop app's version, which nixpkgs lags behind.
{
  lib,
  t3code,
  fetchFromGitHub,
}:
let
  version = "0.1.10";
  unwrapped =
    if lib.versionAtLeast t3code.version version then
      t3code.unwrapped
    else
      t3code.unwrapped.overrideAttrs (
        finalAttrs: old: {
          inherit version;
          src = fetchFromGitHub {
            owner = "pingdotgg";
            repo = "t3code";
            tag = "v${finalAttrs.version}";
            hash = "sha256-zhScbDGW+bD2T7++YRUPY/y83SGE2080LxcGw3Txrso=";
          };
          pnpmDeps = old.pnpmDeps.overrideAttrs {
            outputHash = "sha256-27Ljt2lY4J1Fi3ddVIflPQ5erRqmgaZ8+YBH9fhCLzo=";
          };
        }
      );
in
# Provider CLIs and gh come from the agent's own PATH instead.
t3code.override {
  t3code-unwrapped = unwrapped;
  enableCodex = false;
  enableGitHub = false;
}
