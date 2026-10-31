{
  config,
  lib,
  options,
  pkgs,
  username,
  ...
}:
let
  cfg = config.joona.services.agents;

  port = 3773;
  t3code = pkgs.callPackage ../../../../pkgs/t3code.nix { };

  pair = pkgs.writeShellApplication {
    name = "t3-pair";
    text = ''
      ${t3code}/bin/t3 pair "$@" |
        sed -n 's|^Pairing URL: http://[^/]*|https://${cfg.domain}|p'
    '';
  };

  # The agents get the same tools as my own shell, sudo included.
  path = [
    "/run/wrappers"
    "/etc/profiles/per-user/${username}"
    "/run/current-system/sw"
  ];
  service = {
    User = username;
    WorkingDirectory = "~";
  };
in
{
  options.joona.services.agents = {
    enable = lib.mkEnableOption "T3 Code and the coding agents it runs, as my own user";

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Tailnet-only hostname T3 is paired and reached through.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${username} = {
      extraGroups = [ "docker" ];
      packages = [
        pair
        pkgs.nodejs
      ];
    };

    home-manager.users.${username}.programs = {
      # git pushes with gh's credentials, from a one-time `gh auth login`.
      gh = {
        enable = true;
        settings.git_protocol = "https";
      };
      # With carbon's own ~/.ssh/id_ed25519, a GitHub signing key.
      git.signing.signByDefault = true;
    };

    # Installed once with the vendors' installers, then left to update themselves.
    systemd.services.agent-providers = {
      description = "Install the provider CLIs";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      inherit path;
      serviceConfig = service // {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        [ -x ~/.local/bin/claude ] || curl -fsSL https://claude.ai/install.sh | bash
        [ -x ~/.local/bin/codex ] || npm install --global --prefix ~/.local @openai/codex
      '';
    };

    systemd.services.t3code = {
      description = "T3 Code server";
      wantedBy = [ "multi-user.target" ];
      wants = [ "agent-providers.service" ];
      after = [ "agent-providers.service" ];
      inherit path;
      environment = {
        # Claude's bundled ripgrep is a generic Linux binary.
        USE_BUILTIN_RIPGREP = "0";
        # Playwright checks the browsers' libraries with ldd, which cannot see
        # the nix-ld ones, and refuses to launch browsers that run fine.
        PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
      };
      serviceConfig = service // {
        ExecStart = pkgs.writeShellScript "t3code" ''
          export PATH="$HOME/.local/bin:$PATH"
          exec ${t3code}/bin/t3 serve --host 127.0.0.1 --port ${toString port}
        '';
        Restart = "on-failure";
        RestartSec = 5;
        UMask = "0077";
        # Headless startup prints a pairing credential; keep it out of the journal.
        StandardOutput = "null";
        # Throttle agent builds before they starve the media stack, and on OOM
        # kill only the offending process rather than every session.
        MemoryHigh = "6G";
        MemoryMax = "8G";
        OOMPolicy = "continue";
        CPUWeight = 50;
      };
    };

    virtualisation.docker.enable = true;

    joona.services.web.enable = true;
    joona.vhosts.${cfg.domain} = {
      inherit port;
      extraConfig = ''
        proxy_buffering off;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
      '';
    };

    # Prebuilt binaries (the provider CLIs, Playwright's browsers, npm and LSP
    # downloads) expect a generic Linux loader and libraries.
    programs.nix-ld = {
      enable = true;
      # Setting the list replaces the defaults (libstdc++, zlib, openssl, ...).
      libraries =
        options.programs.nix-ld.libraries.default
        ++ (with pkgs; [
          # Playwright Chromium and Firefox.
          alsa-lib
          at-spi2-atk
          at-spi2-core
          atk
          cairo
          cups
          dbus
          dbus-glib
          expat
          fontconfig
          freetype
          gdk-pixbuf
          glib
          gtk3
          libdrm
          libgbm
          libxkbcommon
          mesa
          nspr
          nss
          pango
          systemd
          libx11
          libxcomposite
          libxcursor
          libxdamage
          libxext
          libxfixes
          libxi
          libxrandr
          libxrender
          libxtst
          libxcb
          libxshmfence
          libxscrnsaver
        ]);
    };
  };
}
