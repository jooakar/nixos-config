{
  programs.git = {
    enable = true;
    ignores = [
      "*.swp"
      ".DS_STORE"
    ];
    delta = {
      enable = true;
      options.navigate = true;
    };
    userName = "Joona Kärkkäinen";
    userEmail = "joona.karkkainen@gmail.com";
    lfs.enable = true;
    extraConfig = {
      init.defaultBranch = "main";
      core.autocrlf = "input";
      branch.sort = "-committerdate";
      merge.conflictstyle = "zdiff3";
      pull.ff = "only";
      rerere.enabled = true;
    };
  };
}
