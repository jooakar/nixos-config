{ config, lib, ... }:
let
  cfg = config.joona.services.jellyfin;
in
{
  options.joona.services.jellyfin.enable =
    lib.mkEnableOption "the QuickSync half of nixarr's Jellyfin";

  config = lib.mkIf cfg.enable {
    # nixarr enables Jellyfin but has no hardware acceleration options at all, so
    # the QuickSync half is configured against the upstream module directly.
    services.jellyfin = {
      hardwareAcceleration = {
        enable = true;
        type = "vaapi";
        device = "/dev/dri/renderD128";
      };

      forceEncodingConfig = true;
      transcoding = {
        hardwareDecodingCodecs = {
          h264 = true;
          hevc = true;
          hevc10bit = true;
          mpeg2 = true;
          vc1 = true;
          vp8 = true;
          vp9 = true;
        };
        hardwareEncodingCodecs.hevc = true;
        throttleTranscoding = true;
      };
    };

    users.users.jellyfin.extraGroups = [
      "render"
      "video"
    ];

    systemd.services.jellyfin.serviceConfig.PrivateUsers = lib.mkForce false;
  };
}
