{ lib, ... }:
{
  # nixarr enables Jellyfin but has no hardware acceleration options at all, so
  # the QuickSync half is configured against the upstream module directly.
  services.jellyfin = {
    # VAAPI rather than the qsv backend: this is a Gen9.5 iGPU, which the
    # oneVPL runtime has dropped, while intel-media-driver still covers it.
    hardwareAcceleration = {
      enable = true;
      type = "vaapi";
      device = "/dev/dri/renderD128";
    };

    # Without this the options below only apply until the first start, and the
    # dashboard becomes the source of truth instead.
    forceEncodingConfig = true;
    transcoding = {
      # What Kaby Lake decodes in fixed function. AV1 is Gen12 and up.
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
      # Four cores, and a transcode that runs ahead is a transcode competing
      # with the next one.
      throttleTranscoding = true;
    };
  };

  users.users.jellyfin.extraGroups = [
    "render"
    "video"
  ];

  # The upstream module hardens the unit with PrivateUsers, which maps only the
  # service's own uid and gid. The render membership above lands outside that
  # map as nogroup, and /dev/dri/renderD128 is then unopenable.
  systemd.services.jellyfin.serviceConfig.PrivateUsers = lib.mkForce false;
}
