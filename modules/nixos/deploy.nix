{ pkgs, ... }:
let
  # What CI is allowed to do. `restrict` plus the forced command means the key
  # can do nothing else, so it does not need a login shell of its own.
  restart = unit: "sudo systemctl restart ${unit}";
  deployUnit = "podman-hundred.service";

  # Generated once with `ssh-keygen -t ed25519`; the private half lives in the
  # application repo's Actions secrets. Deliberately not in config/ssh-keys,
  # because everything there gets a full login as the user and as root.
  ciKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB9MT2KH2wYY/aXTib3Gl6Zjla+VM1fzrrvy2q/vaxhe ci-deploy";
in
{
  users.users.deploy = {
    isNormalUser = true;
    shell = pkgs.bash;
    openssh.authorizedKeys.keys = [ ''restrict,command="${restart deployUnit}" ${ciKey}'' ];
  };

  security.sudo.extraRules = [
    {
      users = [ "deploy" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/systemctl restart ${deployUnit}";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
