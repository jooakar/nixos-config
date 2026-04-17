{
  programs.git = {
    enable = true;
    ignores = [
      "*.swp"
      ".DS_STORE"
    ];
    signing.format = null;
    settings = {
      user = {
        name = "Joona Kärkkäinen";
        email = "joona.karkkainen@gmail.com";
      };
      init.defaultBranch = "main";
      core.autocrlf = "input";
      branch.sort = "-committerdate";
      merge.conflictstyle = "zdiff3";
      pull.ff = "only";
      rerere.enabled = true;
    };
    lfs.enable = true;
  };
}
