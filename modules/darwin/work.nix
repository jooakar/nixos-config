{ username, ... }:
{
  homebrew.casks = [ ];

  home-manager.users.${username}.services.colima = {
    enable = true;
    profiles.default = {
      isActive = true;
      isService = true;
      setDockerHost = true;
      settings = {
        cpu = 12;
        memory = 24;
        disk = 256;
        arch = "host";
        runtime = "docker";
        # Runs the amd64-only mssql image under Rosetta instead of QEMU.
        vmType = "vz";
        rosetta = true;
        binfmt = true;
        mountType = "virtiofs";
        # Propagates host file events so nodemon/vite watchers see edits.
        mountInotify = true;
        # An empty list mounts nothing, so compose bind mounts would land in the VM.
        mounts = [
          {
            location = "/Users/${username}";
            writable = true;
          }
        ];
        # ~/.ssh/config is managed by home-manager.
        sshConfig = false;
      };
    };
  };
}
