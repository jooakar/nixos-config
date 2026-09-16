# One file per application, all of them imported on every NixOS host. Each
# declares `joona.apps.<name>.enable` and does nothing until that is set.
{
  imports = [ ./hundred.nix ];
}
