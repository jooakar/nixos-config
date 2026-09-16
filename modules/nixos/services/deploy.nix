{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.joona.services.deploy;

  # What CI is allowed to do
  restart = unit: "sudo systemctl restart ${unit}";
  deployUnit = "podman-hundred.service";

  # The private half lives in an application's Actions secrets
  ciKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB9MT2KH2wYY/aXTib3Gl6Zjla+VM1fzrrvy2q/vaxhe ci-deploy";
in
{
  options.joona.services.deploy.enable =
    lib.mkEnableOption "the restricted SSH identity CI deploys with";

  config = lib.mkIf cfg.enable {
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
  };
}
